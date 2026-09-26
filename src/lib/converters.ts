// Conversions d'import / export (exécutées dans le navigateur, bibliothèques chargées à la demande).
import type { JSONContent } from "@tiptap/react";
import type { SheetContent, SheetData, SlidesContent, Slide } from "./drive";
import { colIndex, colName, createEvaluator, parseRef } from "./sheet-engine";

export function download(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 4000);
}

export function safeTitle(t: string) {
  return (t || "document").replace(/[\\/:*?"<>|]+/g, "-").slice(0, 120);
}

// ─── Word → document natif ──────────────────────────────────────────────────
export async function docxToHtml(file: File) {
  const mammoth = await import("mammoth");
  const { value } = await mammoth.convertToHtml(
    { arrayBuffer: await file.arrayBuffer() },
    { convertImage: mammoth.images.imgElement(async (img) => ({ src: `data:${img.contentType};base64,${await img.readAsBase64String()}` })) },
  );
  return value;
}

// ─── Document natif → Word ──────────────────────────────────────────────────
export async function exportDocx(doc: JSONContent, title: string) {
  const d = await import("docx");
  type Run = InstanceType<typeof d.TextRun> | InstanceType<typeof d.ExternalHyperlink>;

  const runs = (nodes: JSONContent[] = []): Run[] =>
    nodes.flatMap((n): Run[] => {
      if (n.type === "hardBreak") return [new d.TextRun({ text: "", break: 1 })];
      if (n.type !== "text") return [];
      const marks = n.marks ?? [];
      const has = (t: string) => marks.some((m) => m.type === t);
      const color = marks.find((m) => m.type === "textStyle")?.attrs?.color as string | undefined;
      const link = marks.find((m) => m.type === "link")?.attrs?.href as string | undefined;
      const run = new d.TextRun({
        text: n.text ?? "",
        bold: has("bold"), italics: has("italic"), underline: has("underline") || link ? {} : undefined,
        strike: has("strike"), color: link ? "4F46E5" : color?.replace("#", ""),
        highlight: has("highlight") ? "yellow" : undefined, font: has("code") ? "Consolas" : undefined,
      });
      return link ? [new d.ExternalHyperlink({ link, children: [run] })] : [run];
    });

  const align = (n: JSONContent) => {
    const a = n.attrs?.textAlign;
    return a === "center" ? d.AlignmentType.CENTER : a === "right" ? d.AlignmentType.RIGHT : a === "justify" ? d.AlignmentType.JUSTIFIED : undefined;
  };

  const blocks = (nodes: JSONContent[] = [], level = 0, listType?: "bullet" | "number"): (InstanceType<typeof d.Paragraph> | InstanceType<typeof d.Table>)[] =>
    nodes.flatMap((n) => {
      switch (n.type) {
        case "heading": {
          const lv = [d.HeadingLevel.HEADING_1, d.HeadingLevel.HEADING_2, d.HeadingLevel.HEADING_3][(n.attrs?.level ?? 1) - 1] ?? d.HeadingLevel.HEADING_3;
          return [new d.Paragraph({ heading: lv, alignment: align(n), children: runs(n.content) })];
        }
        case "paragraph":
          return [new d.Paragraph({
            alignment: align(n), children: runs(n.content),
            ...(listType === "bullet" ? { bullet: { level } } : listType === "number" ? { numbering: { reference: "num", level } } : {}),
          })];
        case "bulletList":
        case "orderedList":
        case "taskList":
          return (n.content ?? []).flatMap((item) => blocks(item.content, level + (listType ? 1 : 0), n.type === "orderedList" ? "number" : "bullet"));
        case "blockquote":
          return (n.content ?? []).map((p) => new d.Paragraph({ children: runs(p.content), indent: { left: 720 }, border: { left: { style: d.BorderStyle.SINGLE, size: 12, color: "6366F1", space: 12 } } }));
        case "codeBlock":
          return [new d.Paragraph({ children: [new d.TextRun({ text: (n.content ?? []).map((t) => t.text).join(""), font: "Consolas" })], shading: { type: d.ShadingType.CLEAR, fill: "F3F4F8", color: "auto" } })];
        case "horizontalRule":
          return [new d.Paragraph({ border: { bottom: { style: d.BorderStyle.SINGLE, size: 6, color: "CCCCCC", space: 1 } } })];
        case "table": {
          const rows = (n.content ?? []).map((row) => new d.TableRow({
            children: (row.content ?? []).map((cell) => new d.TableCell({
              children: blocks(cell.content).filter((b) => b instanceof d.Paragraph) as InstanceType<typeof d.Paragraph>[],
              shading: cell.type === "tableHeader" ? { type: d.ShadingType.CLEAR, fill: "EEF0F6", color: "auto" } : undefined,
            })),
          }));
          return rows.length ? [new d.Table({ rows, width: { size: 100, type: d.WidthType.PERCENTAGE } })] : [];
        }
        default:
          return n.content ? blocks(n.content, level, listType) : [];
      }
    });

  const document = new d.Document({
    creator: "VERIION OS",
    title,
    styles: { default: { document: { run: { font: "Calibri", size: 22 } } } },
    numbering: { config: [{ reference: "num", levels: [0, 1, 2, 3].map((l) => ({ level: l, format: d.LevelFormat.DECIMAL, text: `%${l + 1}.`, alignment: d.AlignmentType.LEFT, style: { paragraph: { indent: { left: 720 * (l + 1), hanging: 360 } } } })) }] },
    sections: [{ children: blocks(doc.content) }],
  });
  download(await d.Packer.toBlob(document), `${safeTitle(title)}.docx`);
}

// ─── Excel / CSV → tableur natif ────────────────────────────────────────────
export async function spreadsheetToContent(file: File): Promise<SheetContent> {
  const name = file.name.toLowerCase();
  if (name.endsWith(".csv") || file.type === "text/csv") {
    const text = await file.text();
    const sep = (text.split("\n")[0].match(/;/g)?.length ?? 0) > (text.split("\n")[0].match(/,/g)?.length ?? 0) ? ";" : ",";
    const cells: SheetData["cells"] = {};
    const lines = parseCsv(text, sep);
    lines.forEach((cols, r) => cols.forEach((v, c) => { if (v !== "") cells[`${colName(c)}${r + 1}`] = { v }; }));
    return { sheets: [{ id: crypto.randomUUID(), name: "Feuille 1", cells, rows: Math.max(60, lines.length + 10), cols: Math.max(16, Math.max(0, ...lines.map((l) => l.length)) + 2), colWidths: {} }] };
  }
  const ExcelJS = (await import("exceljs")).default;
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.load(await file.arrayBuffer());
  const sheets: SheetData[] = [];
  wb.eachSheet((ws) => {
    const cells: SheetData["cells"] = {};
    let maxR = 0, maxC = 0;
    ws.eachRow({ includeEmpty: false }, (row, r) => {
      row.eachCell({ includeEmpty: false }, (cell, c) => {
        maxR = Math.max(maxR, r); maxC = Math.max(maxC, c);
        const v = cell.value;
        let raw = "";
        if (v && typeof v === "object" && "formula" in v && v.formula) raw = "=" + v.formula;
        else if (v && typeof v === "object" && "sharedFormula" in v) raw = String((v as { result?: unknown }).result ?? "");
        else if (v instanceof Date) raw = v.toLocaleDateString("fr-FR");
        else if (v && typeof v === "object" && "richText" in v) raw = v.richText.map((t) => t.text).join("");
        else if (v && typeof v === "object" && "text" in v) raw = String(v.text);
        else if (v !== null && v !== undefined) raw = String(v);
        if (raw === "") return;
        const f = cell.font ?? {};
        const numFmt = cell.numFmt ?? "";
        cells[`${colName(c - 1)}${r}`] = {
          v: raw,
          s: {
            b: f.bold || undefined, i: f.italic || undefined, u: f.underline ? true : undefined,
            align: (cell.alignment?.horizontal as "left" | "center" | "right" | undefined) ?? undefined,
            fmt: numFmt.includes("%") ? "percent" : /[€$]|CFA|XOF/.test(numFmt) ? "currency" : undefined,
          },
        };
      });
    });
    const colWidths: Record<string, number> = {};
    ws.columns?.forEach((col, i) => { if (col?.width) colWidths[colName(i)] = Math.round(col.width * 7.5); });
    sheets.push({ id: crypto.randomUUID(), name: ws.name.slice(0, 40), cells, rows: Math.max(60, maxR + 10), cols: Math.max(16, maxC + 2), colWidths });
  });
  return { sheets: sheets.length ? sheets : [{ id: crypto.randomUUID(), name: "Feuille 1", cells: {}, rows: 60, cols: 16, colWidths: {} }] };
}

function parseCsv(text: string, sep: string) {
  const rows: string[][] = [];
  let row: string[] = [];
  let cur = "";
  let q = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (q) {
      if (ch === '"' && text[i + 1] === '"') { cur += '"'; i++; }
      else if (ch === '"') q = false;
      else cur += ch;
    } else if (ch === '"') q = true;
    else if (ch === sep) { row.push(cur); cur = ""; }
    else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && text[i + 1] === "\n") i++;
      row.push(cur); rows.push(row); row = []; cur = "";
    } else cur += ch;
  }
  if (cur !== "" || row.length) { row.push(cur); rows.push(row); }
  return rows;
}

// ─── Tableur natif → Excel / CSV ────────────────────────────────────────────
export async function exportXlsx(content: SheetContent, title: string) {
  const ExcelJS = (await import("exceljs")).default;
  const wb = new ExcelJS.Workbook();
  wb.creator = "VERIION OS";
  const ev = createEvaluator(content);
  content.sheets.forEach((sh, si) => {
    const ws = wb.addWorksheet(sh.name.replace(/[\\/?*[\]:]/g, "-").slice(0, 31) || `Feuille ${si + 1}`);
    Object.entries(sh.colWidths).forEach(([c, w]) => { ws.getColumn(colIndex(c) + 1).width = Math.max(6, w / 7.5); });
    Object.entries(sh.cells).forEach(([a1, cell]) => {
      const p = parseRef(a1);
      if (!p) return;
      const target = ws.getCell(p.r + 1, p.c + 1);
      const computed = ev.getValue(si, p.r, p.c);
      if (cell.v.startsWith("=")) {
        const result = typeof computed === "object" && computed !== null ? undefined : (computed as string | number | boolean | undefined);
        target.value = { formula: cell.v.slice(1).replace(/;/g, ","), result } as never;
      } else {
        target.value = (typeof computed === "object" && computed !== null ? cell.v : computed ?? "") as never;
      }
      const s = cell.s;
      if (s) {
        target.font = { bold: s.b, italic: s.i, underline: s.u, color: s.color ? { argb: "FF" + s.color.replace("#", "") } : undefined };
        if (s.align) target.alignment = { horizontal: s.align };
        if (s.bg) target.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF" + s.bg.replace("#", "") } };
        if (s.fmt === "percent") target.numFmt = "0.00%";
        if (s.fmt === "currency") target.numFmt = '#,##0 "FCFA"';
        if (s.fmt === "number") target.numFmt = "#,##0.00";
      }
    });
  });
  const buf = await wb.xlsx.writeBuffer();
  download(new Blob([buf], { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }), `${safeTitle(title)}.xlsx`);
}

export function exportCsv(content: SheetContent, sheetIndex: number, title: string) {
  const sh = content.sheets[sheetIndex];
  const ev = createEvaluator(content);
  let maxR = 0, maxC = 0;
  Object.keys(sh.cells).forEach((k) => { const p = parseRef(k); if (p) { maxR = Math.max(maxR, p.r); maxC = Math.max(maxC, p.c); } });
  const lines: string[] = [];
  for (let r = 0; r <= maxR; r++) {
    const cols: string[] = [];
    for (let c = 0; c <= maxC; c++) {
      const v = ev.getValue(sheetIndex, r, c);
      const s = v === null ? "" : typeof v === "object" ? v.error : String(v);
      cols.push(/[;"\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s);
    }
    lines.push(cols.join(";"));
  }
  download(new Blob(["﻿" + lines.join("\n")], { type: "text/csv;charset=utf-8" }), `${safeTitle(title)} - ${sh.name}.csv`);
}

// ─── Présentation native → PowerPoint ───────────────────────────────────────
export const SLIDE_THEMES = {
  nuit: { bg: "050816", title: "FFFFFF", text: "C9CEE3", accent: "818CF8", muted: "6E7699" },
  clair: { bg: "FFFFFF", title: "0B1020", text: "3F475C", accent: "4F46E5", muted: "8A93A8" },
  indigo: { bg: "312E81", title: "FFFFFF", text: "E0E7FF", accent: "F0ABFC", muted: "A5B4FC" },
} as const;

async function toDataUrl(src: string) {
  const res = await fetch(src);
  const blob = await res.blob();
  return await new Promise<string>((resolve) => {
    const r = new FileReader();
    r.onload = () => resolve(String(r.result));
    r.readAsDataURL(blob);
  });
}

export async function exportPptx(content: SlidesContent, title: string) {
  const PptxGenJS = (await import("pptxgenjs")).default;
  const pptx = new PptxGenJS();
  pptx.layout = "LAYOUT_WIDE"; // 13,33 × 7,5 pouces
  pptx.title = title;
  pptx.company = "VERIION";
  const t = SLIDE_THEMES[content.theme] ?? SLIDE_THEMES.nuit;
  const bullets = (s?: string) => (s ?? "").split("\n").filter((l) => l.trim()).map((l) => ({ text: l.replace(/^[-•]\s*/, ""), options: { bullet: { code: "25CF" }, color: t.text, fontSize: 20, paraSpaceAfter: 8 } }));

  for (const s of content.slides as Slide[]) {
    const slide = pptx.addSlide();
    slide.background = { color: t.bg };
    if (s.notes) slide.addNotes(s.notes);
    const img = s.image ? await toDataUrl(s.image).catch(() => null) : null;
    switch (s.layout) {
      case "title":
        slide.addShape(pptx.ShapeType.rect, { x: 0.8, y: 3.05, w: 0.12, h: 1.3, fill: { color: t.accent } });
        slide.addText(s.title || " ", { x: 1.1, y: 2.4, w: 11, h: 1.6, fontSize: 44, bold: true, color: t.title, fontFace: "Calibri" });
        if (s.subtitle) slide.addText(s.subtitle, { x: 1.1, y: 3.9, w: 11, h: 0.8, fontSize: 20, color: t.muted });
        break;
      case "section":
        slide.addText(s.title || " ", { x: 0.8, y: 2.8, w: 11.7, h: 1.4, fontSize: 40, bold: true, color: t.title, align: "center" });
        if (s.subtitle) slide.addText(s.subtitle, { x: 0.8, y: 4.1, w: 11.7, h: 0.7, fontSize: 18, color: t.accent, align: "center" });
        break;
      case "quote":
        slide.addText(`« ${s.body ?? ""} »`, { x: 1.2, y: 1.8, w: 10.9, h: 3, fontSize: 30, italic: true, color: t.title, align: "center" });
        if (s.title) slide.addText(s.title, { x: 1.2, y: 5, w: 10.9, h: 0.6, fontSize: 16, color: t.accent, align: "center" });
        break;
      case "two":
        slide.addText(s.title || " ", { x: 0.8, y: 0.5, w: 11.7, h: 1, fontSize: 32, bold: true, color: t.title });
        slide.addText(bullets(s.body), { x: 0.8, y: 1.8, w: 5.6, h: 4.9, valign: "top" });
        slide.addText(bullets(s.body2), { x: 6.9, y: 1.8, w: 5.6, h: 4.9, valign: "top" });
        break;
      case "image":
        slide.addText(s.title || " ", { x: 0.8, y: 0.5, w: 5.8, h: 1, fontSize: 30, bold: true, color: t.title });
        slide.addText(bullets(s.body), { x: 0.8, y: 1.7, w: 5.6, h: 5, valign: "top" });
        if (img) slide.addImage({ data: img, x: 6.9, y: 0.9, w: 5.6, h: 5.7, sizing: { type: "contain", w: 5.6, h: 5.7 } });
        break;
      default:
        slide.addText(s.title || " ", { x: 0.8, y: 0.5, w: 11.7, h: 1, fontSize: 32, bold: true, color: t.title });
        slide.addShape(pptx.ShapeType.rect, { x: 0.8, y: 1.45, w: 1.2, h: 0.06, fill: { color: t.accent } });
        slide.addText(bullets(s.body), { x: 0.8, y: 1.8, w: 11.7, h: 4.9, valign: "top" });
    }
    slide.addText("VERIION", { x: 11.2, y: 7, w: 1.6, h: 0.3, fontSize: 9, color: t.muted, align: "right", charSpacing: 3 });
  }
  await pptx.writeFile({ fileName: `${safeTitle(title)}.pptx` });
}
