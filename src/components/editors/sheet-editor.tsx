"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  AlignCenter, AlignLeft, AlignRight, Bold, FileSpreadsheet, FileText, Italic, PaintBucket, Plus, Redo2, Sigma, Trash2, Type,
  Underline as UnderlineIcon, Undo2,
} from "lucide-react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import type { CellStyle, SheetContent, SheetData } from "@/lib/drive";
import { exportCsv, exportXlsx } from "@/lib/converters";
import { colName, createEvaluator, formatValue, insertShift, isError, parseRef, ref, shiftFormula } from "@/lib/sheet-engine";
import { EditorShell, ExportItem, type EditorMeta } from "./editor-shell";
import { useDocSync, type Viewer } from "./use-doc-sync";
import { applySheetOp, diffSheets, type SheetOp } from "@/lib/collab/ops";

type Pos = { r: number; c: number };
const DEFAULT_W = 110;
const ROW_H = 28;
const PALETTE = ["", "#0b1020", "#e11d48", "#ea580c", "#d97706", "#059669", "#0284c7", "#4f46e5", "#9333ea", "#6b7280"];
const FILLS = ["", "#fef3c7", "#dcfce7", "#dbeafe", "#ede9fe", "#fce7f3", "#fee2e2", "#e5e7eb", "#0b1f3a", "#4f46e5"];

function normalize(c: unknown): SheetContent {
  const x = c as SheetContent | null;
  if (x && Array.isArray(x.sheets) && x.sheets.length) return x;
  return { sheets: [{ id: crypto.randomUUID(), name: "Feuille 1", cells: {}, rows: 60, cols: 16, colWidths: {} }] };
}

function plainText(c: SheetContent) {
  return c.sheets.map((s) => `${s.name} ${Object.values(s.cells).map((x) => x.v).join(" ")}`).join("\n").slice(0, 150000);
}

export function SheetEditor({ meta, initial, me }: { meta: EditorMeta; initial: unknown; me: { id: string; name: string; avatar: string | null } }) {
  const canEdit = meta.access >= 2;
  const [content, setContent] = useState<SheetContent>(() => normalize(initial));
  const [active, setActive] = useState(0);
  const [anchor, setAnchor] = useState<Pos>({ r: 0, c: 0 });
  const [focus, setFocus] = useState<Pos>({ r: 0, c: 0 });
  const [editing, setEditing] = useState<{ pos: Pos; value: string; bar?: boolean } | null>(null);
  const [menu, setMenu] = useState<null | "color" | "fill">(null);
  const contentRef = useRef(content);
  contentRef.current = content;
  // Historique d'annulation par opérations : on n'annule que ses propres modifications
  const undo = useRef<{ forward: SheetOp[]; inverse: SheetOp[] }[]>([]);
  const redo = useRef<{ forward: SheetOp[]; inverse: SheetOp[] }[]>([]);
  const grid = useRef<HTMLDivElement>(null);
  const dragging = useRef(false);

  const sync = useDocSync({
    docId: meta.doc.id,
    initialRevision: meta.doc.revision,
    canEdit,
    me,
    collab: true,
    getContent: () => ({ content: contentRef.current, text: plainText(contentRef.current) }),
    onRemote: (c) => { setContent(normalize(c)); undo.current = []; redo.current = []; },
    onOp: (op) => setContent((cur) => applySheetOp(cur, op as SheetOp)),
    onSnapshot: (c) => setContent(normalize(c)),
  });

  const sheet: SheetData = content.sheets[Math.min(active, content.sheets.length - 1)];
  const ev = useMemo(() => createEvaluator(content), [content]);

  const { markDirty, sendOp, setFocus: shareFocus } = sync;
  const commit = useCallback((next: SheetContent) => {
    const d = diffSheets(contentRef.current, next);
    if (!d.forward.length) return;
    undo.current.push(d);
    if (undo.current.length > 80) undo.current.shift();
    redo.current = [];
    contentRef.current = next;
    setContent(next);
    d.forward.forEach(sendOp);
    markDirty();
  }, [markDirty, sendOp]);

  const replay = useCallback((ops: SheetOp[]) => {
    const next = ops.reduce(applySheetOp, contentRef.current);
    contentRef.current = next;
    setContent(next);
    ops.forEach(sendOp);
    markDirty();
  }, [markDirty, sendOp]);

  const mutateSheet = (fn: (s: SheetData) => SheetData) => {
    const next = { ...content, sheets: content.sheets.map((s, i) => (i === active ? fn(structuredClone(s)) : s)) };
    commit(next);
  };

  const range = useMemo(() => ({
    r1: Math.min(anchor.r, focus.r), r2: Math.max(anchor.r, focus.r), c1: Math.min(anchor.c, focus.c), c2: Math.max(anchor.c, focus.c),
  }), [anchor, focus]);
  const inRange = (r: number, c: number) => r >= range.r1 && r <= range.r2 && c >= range.c1 && c <= range.c2;

  const setCell = (s: SheetData, a1: string, v: string, style?: CellStyle) => {
    const prev = s.cells[a1];
    if (v === "" && !style && !prev?.s) delete s.cells[a1];
    else s.cells[a1] = { v, ...(style ?? prev?.s ? { s: style ?? prev?.s } : {}) };
  };

  const commitEdit = (value: string, move?: Pos) => {
    if (!editing) return;
    const a1 = ref(editing.pos.r, editing.pos.c);
    if ((sheet.cells[a1]?.v ?? "") !== value) mutateSheet((s) => { setCell(s, a1, value); return s; });
    setEditing(null);
    if (move) { const p = clamp(move); setAnchor(p); setFocus(p); requestAnimationFrame(() => grid.current?.focus()); }
  };

  const clamp = (p: Pos) => ({ r: Math.max(0, Math.min(sheet.rows - 1, p.r)), c: Math.max(0, Math.min(sheet.cols - 1, p.c)) });

  const applyStyle = (patch: Partial<CellStyle>) => {
    if (!canEdit) return;
    mutateSheet((s) => {
      for (let r = range.r1; r <= range.r2; r++) for (let c = range.c1; c <= range.c2; c++) {
        const a1 = ref(r, c);
        const cell = s.cells[a1] ?? { v: "" };
        const st = { ...(cell.s ?? {}), ...patch };
        (Object.keys(st) as (keyof CellStyle)[]).forEach((k) => { if (st[k] === undefined || st[k] === "" || st[k] === false) delete st[k]; });
        s.cells[a1] = Object.keys(st).length ? { v: cell.v, s: st } : { v: cell.v };
        if (!s.cells[a1].v && !s.cells[a1].s) delete s.cells[a1];
      }
      return s;
    });
  };

  const focusStyle = sheet.cells[ref(focus.r, focus.c)]?.s ?? {};
  const toggle = (k: "b" | "i" | "u") => applyStyle({ [k]: !focusStyle[k] });

  const clearRange = () => mutateSheet((s) => {
    for (let r = range.r1; r <= range.r2; r++) for (let c = range.c1; c <= range.c2; c++) {
      const a1 = ref(r, c);
      if (s.cells[a1]?.s) s.cells[a1] = { v: "", s: s.cells[a1].s }; else delete s.cells[a1];
    }
    return s;
  });

  const copyText = () => {
    const lines: string[] = [];
    for (let r = range.r1; r <= range.r2; r++) {
      const cols: string[] = [];
      for (let c = range.c1; c <= range.c2; c++) cols.push(sheet.cells[ref(r, c)]?.v ?? "");
      lines.push(cols.join("\t"));
    }
    return lines.join("\n");
  };

  const paste = (text: string) => {
    if (!canEdit) return;
    const rows = text.replace(/\r/g, "").replace(/\n$/, "").split("\n").map((l) => l.split("\t"));
    // Formules : références relatives décalées depuis la cellule d'origine si la copie vient de ce tableur
    const src = copiedFrom.current;
    mutateSheet((s) => {
      rows.forEach((cols, i) => cols.forEach((v, j) => {
        const r = focus.r + i, c = focus.c + j;
        if (r >= s.rows) s.rows = r + 1;
        if (c >= s.cols) s.cols = c + 1;
        const val = src && v.startsWith("=") ? shiftFormula(v, focus.r - src.r, focus.c - src.c) : v;
        setCell(s, ref(r, c), val);
      }));
      return s;
    });
    setAnchor(focus);
    setFocus({ r: focus.r + rows.length - 1, c: focus.c + Math.max(...rows.map((r) => r.length)) - 1 });
  };
  const copiedFrom = useRef<Pos | null>(null);

  const insertRowCol = (axis: "row" | "col", at: number, delta: number) => {
    mutateSheet((s) => {
      const cells: SheetData["cells"] = {};
      Object.entries(s.cells).forEach(([a1, cell]) => {
        const p = parseRef(a1)!;
        const idx = axis === "row" ? p.r : p.c;
        if (delta < 0 && idx >= at && idx < at - delta) return; // supprimé
        const np = { ...p };
        if (idx >= at) { if (axis === "row") np.r += delta; else np.c += delta; }
        cells[ref(np.r, np.c)] = { ...cell, v: insertShift(cell.v, axis, at, delta) };
      });
      s.cells = cells;
      if (axis === "row") s.rows = Math.max(1, s.rows + delta); else s.cols = Math.max(1, s.cols + delta);
      return s;
    });
    // les autres feuilles qui référencent celle-ci ne sont pas ajustées (limite connue, comme les références externes)
  };

  const autoSum = () => {
    if (!canEdit) return;
    const c = focus.c;
    let r = focus.r - 1;
    while (r >= 0 && typeof ev.getValue(active, r, c) === "number") r--;
    if (r === focus.r - 1) return toast.info("Sélectionnez la cellule sous une colonne de nombres.");
    mutateSheet((s) => { setCell(s, ref(focus.r, c), `=SOMME(${ref(r + 1, c)}:${ref(focus.r - 1, c)})`); return s; });
  };

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (editing) return;
    const mod = e.metaKey || e.ctrlKey;
    const move = (dr: number, dc: number) => {
      e.preventDefault();
      const p = clamp({ r: focus.r + dr, c: focus.c + dc });
      setFocus(p);
      if (!e.shiftKey) setAnchor(p);
    };
    if (mod && (e.key.toLowerCase() === "y" || (e.shiftKey && e.key.toLowerCase() === "z"))) { e.preventDefault(); const n = redo.current.pop(); if (n) { undo.current.push(n); replay(n.forward); } return; }
    if (mod && e.key.toLowerCase() === "z") { e.preventDefault(); const prev = undo.current.pop(); if (prev) { redo.current.push(prev); replay(prev.inverse); } return; }
    if (mod && e.key.toLowerCase() === "b") { e.preventDefault(); toggle("b"); return; }
    if (mod && e.key.toLowerCase() === "i") { e.preventDefault(); toggle("i"); return; }
    if (mod && e.key.toLowerCase() === "u") { e.preventDefault(); toggle("u"); return; }
    if (mod && e.key.toLowerCase() === "a") { e.preventDefault(); setAnchor({ r: 0, c: 0 }); setFocus({ r: sheet.rows - 1, c: sheet.cols - 1 }); return; }
    switch (e.key) {
      case "ArrowUp": return move(-1, 0);
      case "ArrowDown": return move(1, 0);
      case "ArrowLeft": return move(0, -1);
      case "ArrowRight": return move(0, 1);
      case "Tab": return move(0, e.shiftKey ? -1 : 1);
      case "Enter": e.preventDefault(); if (canEdit) setEditing({ pos: focus, value: sheet.cells[ref(focus.r, focus.c)]?.v ?? "" }); return;
      case "F2": e.preventDefault(); if (canEdit) setEditing({ pos: focus, value: sheet.cells[ref(focus.r, focus.c)]?.v ?? "" }); return;
      case "Delete":
      case "Backspace": e.preventDefault(); if (canEdit) clearRange(); return;
    }
    if (canEdit && !mod && e.key.length === 1) {
      e.preventDefault();
      setEditing({ pos: focus, value: e.key });
    }
  };

  useEffect(() => {
    const el = grid.current;
    if (!el) return;
    const onCopy = (e: ClipboardEvent) => { if (editing || document.activeElement !== el) return; e.preventDefault(); e.clipboardData?.setData("text/plain", copyText()); copiedFrom.current = { r: range.r1, c: range.c1 }; };
    const onCut = (e: ClipboardEvent) => { if (editing || document.activeElement !== el || !canEdit) return; onCopy(e); clearRange(); };
    const onPaste = (e: ClipboardEvent) => { if (editing || document.activeElement !== el) return; e.preventDefault(); paste(e.clipboardData?.getData("text/plain") ?? ""); };
    document.addEventListener("copy", onCopy);
    document.addEventListener("cut", onCut);
    document.addEventListener("paste", onPaste);
    return () => { document.removeEventListener("copy", onCopy); document.removeEventListener("cut", onCut); document.removeEventListener("paste", onPaste); };
  });

  useEffect(() => { const up = () => { dragging.current = false; }; window.addEventListener("mouseup", up); return () => window.removeEventListener("mouseup", up); }, []);

  // Redimensionnement des colonnes
  const startResize = (e: React.MouseEvent, c: number) => {
    e.preventDefault();
    e.stopPropagation();
    const startX = e.clientX;
    const name = colName(c);
    const startW = sheet.colWidths[name] ?? DEFAULT_W;
    let w = startW;
    const onMove = (ev: MouseEvent) => {
      w = Math.max(40, Math.min(600, startW + ev.clientX - startX));
      const th = document.querySelector<HTMLElement>(`[data-col="${c}"]`);
      if (th) th.style.width = `${w}px`;
    };
    const onUp = () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("mouseup", onUp);
      if (w !== startW) mutateSheet((s) => { s.colWidths[name] = w; return s; });
    };
    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onUp);
  };

  // Position partagée avec les collaborateurs, et affichage de la leur
  useEffect(() => { shareFocus(`${sheet.id}!${ref(focus.r, focus.c)}`); }, [shareFocus, sheet.id, focus.r, focus.c]);
  const others = useMemo(() => {
    const m = new Map<string, Viewer>();
    sync.presence.forEach((v) => { if (v.focus && v.id !== me.id) m.set(v.focus, v); });
    return m;
  }, [sync.presence, me.id]);

  const focusRaw = sheet.cells[ref(focus.r, focus.c)]?.v ?? "";
  const selectionStats = useMemo(() => {
    if (range.r1 === range.r2 && range.c1 === range.c2) return null;
    const nums: number[] = [];
    let count = 0;
    for (let r = range.r1; r <= range.r2; r++) for (let c = range.c1; c <= range.c2; c++) {
      const v = ev.getValue(active, r, c);
      if (v !== null && v !== "") count++;
      if (typeof v === "number") nums.push(v);
    }
    const sum = nums.reduce((a, b) => a + b, 0);
    return { count, sum, avg: nums.length ? sum / nums.length : 0, n: nums.length };
  }, [range, ev, active]);

  const toolbar = canEdit ? (
    <div className="scrollbar-thin flex items-center gap-0.5 overflow-x-auto py-1.5">
      <TB title="Annuler" onClick={() => onKeyDown({ key: "z", ctrlKey: true, preventDefault() {} } as unknown as React.KeyboardEvent)}><Undo2 /></TB>
      <TB title="Rétablir" onClick={() => onKeyDown({ key: "y", ctrlKey: true, preventDefault() {} } as unknown as React.KeyboardEvent)}><Redo2 /></TB>
      <Sep />
      <TB title="Gras" active={!!focusStyle.b} onClick={() => toggle("b")}><Bold /></TB>
      <TB title="Italique" active={!!focusStyle.i} onClick={() => toggle("i")}><Italic /></TB>
      <TB title="Souligné" active={!!focusStyle.u} onClick={() => toggle("u")}><UnderlineIcon /></TB>
      <div className="relative">
        <TB title="Couleur du texte" onClick={() => setMenu(menu === "color" ? null : "color")}><Type /></TB>
        {menu === "color" && <Swatches colors={PALETTE} onPick={(c) => { applyStyle({ color: c || undefined }); setMenu(null); }} />}
      </div>
      <div className="relative">
        <TB title="Couleur de remplissage" onClick={() => setMenu(menu === "fill" ? null : "fill")}><PaintBucket /></TB>
        {menu === "fill" && <Swatches colors={FILLS} onPick={(c) => { applyStyle({ bg: c || undefined }); setMenu(null); }} />}
      </div>
      <Sep />
      <TB title="Aligner à gauche" active={focusStyle.align === "left"} onClick={() => applyStyle({ align: "left" })}><AlignLeft /></TB>
      <TB title="Centrer" active={focusStyle.align === "center"} onClick={() => applyStyle({ align: "center" })}><AlignCenter /></TB>
      <TB title="Aligner à droite" active={focusStyle.align === "right"} onClick={() => applyStyle({ align: "right" })}><AlignRight /></TB>
      <Sep />
      <select value={focusStyle.fmt ?? "general"} onChange={(e) => applyStyle({ fmt: e.target.value === "general" ? undefined : (e.target.value as CellStyle["fmt"]) })}
        className="h-8 rounded-md border border-border bg-surface px-2 text-[13px] text-fg">
        <option value="general">Standard</option>
        <option value="number">Nombre (0,00)</option>
        <option value="currency">Monétaire (FCFA)</option>
        <option value="percent">Pourcentage</option>
        <option value="date">Date</option>
      </select>
      <TB title="Somme automatique" onClick={autoSum}><Sigma /></TB>
      <Sep />
      <TT onClick={() => insertRowCol("row", focus.r, 1)}>+ Ligne</TT>
      <TT onClick={() => insertRowCol("col", focus.c, 1)}>+ Colonne</TT>
      <TT onClick={() => insertRowCol("row", range.r1, -(range.r2 - range.r1 + 1))}>− Ligne</TT>
      <TT onClick={() => insertRowCol("col", range.c1, -(range.c2 - range.c1 + 1))}>− Colonne</TT>
    </div>
  ) : undefined;

  return (
    <EditorShell
      meta={meta}
      wide
      status={sync.status}
      viewers={sync.viewers}
      lastSaved={sync.lastSaved}
      remoteEditor={sync.remoteEditor}
      onReload={sync.reload}
      onForceSave={() => sync.save({ force: true })}
      onRestored={() => { sync.announceReset(); window.location.reload(); }}
      live={sync.connected}
      onSnapshot={(note) => sync.save({ snapshot: true, note })}
      toolbar={toolbar}
      exportItems={
        <>
          <ExportItem icon={<FileSpreadsheet className="h-4 w-4 text-green-600" />} label="Excel (.xlsx)" onSelect={() => exportXlsx(content, meta.doc.title).catch(() => toast.error("Export impossible"))} />
          <ExportItem icon={<FileText className="h-4 w-4 text-subtle" />} label="CSV (feuille active)" onSelect={() => exportCsv(content, active, meta.doc.title)} />
        </>
      }
    >
      <div className="overflow-hidden rounded-xl border border-border bg-surface shadow-card">
        <div className="flex items-center gap-2 border-b border-border px-2 py-1.5">
          <span className="w-16 shrink-0 rounded-md bg-surface-2 px-2 py-1 text-center font-mono text-xs text-muted">{ref(focus.r, focus.c)}</span>
          <span className="font-serif text-sm italic text-subtle">fx</span>
          <input
            value={editing && editing.pos.r === focus.r && editing.pos.c === focus.c ? editing.value : focusRaw}
            readOnly={!canEdit}
            onFocus={() => canEdit && !editing && setEditing({ pos: focus, value: focusRaw, bar: true })}
            onChange={(e) => setEditing({ pos: focus, value: e.target.value, bar: true })}
            onBlur={(e) => { if (editing?.bar) commitEdit(e.target.value); }}
            onKeyDown={(e) => {
              if (e.key === "Enter") { e.preventDefault(); commitEdit((e.target as HTMLInputElement).value, { r: focus.r + 1, c: focus.c }); }
              if (e.key === "Escape") { setEditing(null); grid.current?.focus(); }
            }}
            placeholder={canEdit ? "Valeur ou formule, ex. =SOMME(A1:A10) ou =SI(B2>0;\"OK\";\"—\")" : ""}
            className="h-8 flex-1 rounded-md bg-transparent px-2 font-mono text-[13px] text-fg outline-none focus:bg-surface-2"
          />
        </div>

        <div
          ref={grid}
          tabIndex={0}
          onKeyDown={onKeyDown}
          className="scrollbar-thin relative max-h-[calc(100dvh-19rem)] overflow-auto outline-none"
        >
          <table className="border-separate border-spacing-0 text-[13px]" style={{ tableLayout: "fixed", width: 46 + Array.from({ length: sheet.cols }).reduce<number>((w, _, c) => w + (sheet.colWidths[colName(c)] ?? DEFAULT_W), 0) }}>
            <colgroup>
              <col style={{ width: 46 }} />
              {Array.from({ length: sheet.cols }).map((_, c) => <col key={c} style={{ width: sheet.colWidths[colName(c)] ?? DEFAULT_W }} />)}
            </colgroup>
            <thead>
              <tr>
                <th className="sticky left-0 top-0 z-30 border-b border-r border-border bg-surface-2" style={{ height: ROW_H }}
                  onClick={() => { setAnchor({ r: 0, c: 0 }); setFocus({ r: sheet.rows - 1, c: sheet.cols - 1 }); }} />
                {Array.from({ length: sheet.cols }).map((_, c) => (
                  <th key={c} data-col={c}
                    onMouseDown={() => { setAnchor({ r: 0, c }); setFocus({ r: sheet.rows - 1, c }); grid.current?.focus(); }}
                    className={cn("sticky top-0 z-20 select-none border-b border-r border-border bg-surface-2 text-center text-[11px] font-medium text-muted",
                      c >= range.c1 && c <= range.c2 && "bg-primary/15 text-primary")}>
                    {colName(c)}
                    {canEdit && <span onMouseDown={(e) => startResize(e, c)} className="absolute -right-1 top-0 z-10 h-full w-2 cursor-col-resize" />}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {Array.from({ length: sheet.rows }).map((_, r) => (
                <tr key={r} style={{ height: ROW_H }}>
                  <th onMouseDown={() => { setAnchor({ r, c: 0 }); setFocus({ r, c: sheet.cols - 1 }); grid.current?.focus(); }}
                    className={cn("sticky left-0 z-10 select-none border-b border-r border-border bg-surface-2 text-center text-[11px] font-medium text-muted",
                      r >= range.r1 && r <= range.r2 && "bg-primary/15 text-primary")}>{r + 1}</th>
                  {Array.from({ length: sheet.cols }).map((_, c) => {
                    const a1 = ref(r, c);
                    const cell = sheet.cells[a1];
                    const isFocus = focus.r === r && focus.c === c;
                    const isEditing = editing && editing.pos.r === r && editing.pos.c === c;
                    const st = cell?.s ?? {};
                    const val = cell ? ev.getValue(active, r, c) : null;
                    const text = formatValue(val, st.fmt);
                    const err = val !== null && isError(val);
                    const align = st.align ?? (typeof val === "number" ? "right" : typeof val === "boolean" || err ? "center" : "left");
                    const peer = others.get(`${sheet.id}!${a1}`);
                    return (
                      <td key={c}
                        onMouseDown={(e) => {
                          if (isEditing) return;
                          dragging.current = true;
                          if (e.shiftKey) setFocus({ r, c }); else { setAnchor({ r, c }); setFocus({ r, c }); }
                          grid.current?.focus();
                        }}
                        onMouseEnter={() => { if (dragging.current) setFocus({ r, c }); }}
                        onDoubleClick={() => canEdit && setEditing({ pos: { r, c }, value: cell?.v ?? "" })}
                        className={cn("relative overflow-hidden whitespace-nowrap border-b border-r border-border/70 px-1.5",
                          inRange(r, c) && !isFocus && "bg-primary/[0.07]",
                          isFocus && "outline outline-2 -outline-offset-2 outline-primary",
                          peer && !isFocus && "outline outline-2 -outline-offset-2")}
                        style={{ outlineColor: peer && !isFocus ? peer.color : undefined, background: st.bg && !inRange(r, c) ? st.bg : undefined, color: err ? "var(--danger)" : st.color, textAlign: align,
                          fontWeight: st.b ? 600 : undefined, fontStyle: st.i ? "italic" : undefined, textDecoration: st.u ? "underline" : undefined }}
                        title={err ? "Erreur de formule" : undefined}
                      >
                        {isEditing && !editing.bar ? (
                          <CellInput
                            value={editing.value}
                            onChange={(v) => setEditing({ pos: { r, c }, value: v })}
                            onCommit={(v, dr, dc, blur) => commitEdit(v, blur ? undefined : { r: r + dr, c: c + dc })}
                            onCancel={() => { setEditing(null); grid.current?.focus(); }}
                          />
                        ) : isEditing ? editing.value : text}
                        {peer && !isFocus && (
                          <span className="pointer-events-none absolute right-0 top-0 z-10 rounded-bl px-1 text-[9px] font-semibold leading-3 text-white" style={{ background: peer.color }}>
                            {peer.name.split(" ")[0]}
                          </span>
                        )}
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="flex items-center gap-1 border-t border-border bg-surface-2/60 px-2 py-1.5">
          <div className="scrollbar-thin flex flex-1 items-center gap-1 overflow-x-auto">
            {content.sheets.map((s, i) => (
              <button key={s.id}
                onClick={() => { setActive(i); setAnchor({ r: 0, c: 0 }); setFocus({ r: 0, c: 0 }); setEditing(null); }}
                onDoubleClick={() => {
                  if (!canEdit) return;
                  const name = prompt("Nom de la feuille :", s.name)?.trim();
                  if (name && !content.sheets.some((x, j) => j !== i && x.name.toLowerCase() === name.toLowerCase())) {
                    commit({ ...content, sheets: content.sheets.map((x, j) => (j === i ? { ...x, name: name.slice(0, 40) } : x)) });
                  }
                }}
                className={cn("group flex items-center gap-1.5 whitespace-nowrap rounded-md px-3 py-1 text-[13px] transition",
                  i === active ? "bg-surface font-medium text-fg shadow-sm" : "text-muted hover:text-fg")}>
                {s.name}
                {canEdit && content.sheets.length > 1 && i === active && (
                  <Trash2 className="h-3 w-3 opacity-50 hover:text-danger hover:opacity-100" onClick={(e) => {
                    e.stopPropagation();
                    if (!confirm(`Supprimer la feuille « ${s.name} » ?`)) return;
                    commit({ ...content, sheets: content.sheets.filter((_, j) => j !== i) });
                    setActive(Math.max(0, i - 1));
                  }} />
                )}
              </button>
            ))}
            {canEdit && (
              <button aria-label="Nouvelle feuille" className="grid h-7 w-7 place-items-center rounded-md text-muted hover:bg-surface hover:text-fg"
                onClick={() => {
                  let n = content.sheets.length + 1;
                  while (content.sheets.some((s) => s.name === `Feuille ${n}`)) n++;
                  commit({ ...content, sheets: [...content.sheets, { id: crypto.randomUUID(), name: `Feuille ${n}`, cells: {}, rows: 60, cols: 16, colWidths: {} }] });
                  setActive(content.sheets.length);
                }}>
                <Plus className="h-4 w-4" />
              </button>
            )}
          </div>
          {canEdit && <button className="rounded-md px-2 py-1 text-xs text-muted hover:bg-surface hover:text-fg" onClick={() => mutateSheet((s) => { s.rows += 20; return s; })}>+ 20 lignes</button>}
          {selectionStats && (
            <span className="hidden whitespace-nowrap px-2 text-xs text-muted md:inline">
              Nombre : {selectionStats.count}{selectionStats.n > 0 && ` · Somme : ${formatValue(selectionStats.sum)} · Moyenne : ${formatValue(Math.round(selectionStats.avg * 100) / 100)}`}
            </span>
          )}
        </div>
      </div>
      <p className="mt-3 text-xs text-subtle">
        Formules Excel en français ou en anglais (SOMME, MOYENNE, SI, RECHERCHEV, NB.SI…) · références entre feuilles : <span className="font-mono">=Feuille2!A1</span> · Double-clic sur un onglet pour le renommer.
      </p>
    </EditorShell>
  );
}

function CellInput({ value, onChange, onCommit, onCancel }: { value: string; onChange: (v: string) => void; onCommit: (v: string, dr: number, dc: number, blur?: boolean) => void; onCancel: () => void }) {
  const ref = useRef<HTMLInputElement>(null);
  useEffect(() => { const el = ref.current; if (el) { el.focus(); el.setSelectionRange(el.value.length, el.value.length); } }, []);
  return (
    <input
      ref={ref}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      onBlur={(e) => onCommit(e.target.value, 0, 0, true)}
      onKeyDown={(e) => {
        e.stopPropagation();
        if (e.key === "Enter") { e.preventDefault(); onCommit(value, e.shiftKey ? -1 : 1, 0); }
        else if (e.key === "Tab") { e.preventDefault(); onCommit(value, 0, e.shiftKey ? -1 : 1); }
        else if (e.key === "Escape") { e.preventDefault(); onCancel(); }
      }}
      className="absolute inset-0 z-10 w-full bg-surface px-1.5 font-mono text-[13px] text-fg outline outline-2 -outline-offset-2 outline-primary"
    />
  );
}

function Swatches({ colors, onPick }: { colors: string[]; onPick: (c: string) => void }) {
  return (
    <div className="absolute left-0 top-9 z-40 grid w-44 grid-cols-5 gap-1.5 rounded-xl border border-border bg-surface p-2 shadow-xl">
      {colors.map((c) => (
        <button key={c || "none"} onClick={() => onPick(c)} aria-label={c || "Aucune"}
          className={cn("h-6 w-6 rounded-md ring-1 ring-border", !c && "bg-[linear-gradient(45deg,transparent_45%,#e11d48_45%,#e11d48_55%,transparent_55%)]")} style={c ? { background: c } : undefined} />
      ))}
    </div>
  );
}

function TB({ children, active, onClick, title }: { children: React.ReactElement; active?: boolean; onClick: () => void; title: string }) {
  return (
    <button type="button" title={title} aria-label={title} onMouseDown={(e) => e.preventDefault()} onClick={onClick}
      className={cn("grid h-8 w-8 shrink-0 place-items-center rounded-md text-muted transition [&>svg]:h-4 [&>svg]:w-4 hover:bg-surface-2 hover:text-fg",
        active && "bg-primary/10 text-primary")}>
      {children}
    </button>
  );
}
function TT({ children, onClick }: { children: React.ReactNode; onClick: () => void }) {
  return <button type="button" onMouseDown={(e) => e.preventDefault()} onClick={onClick} className="whitespace-nowrap rounded px-2 py-1 text-xs text-muted hover:bg-surface-2 hover:text-fg">{children}</button>;
}
function Sep() {
  return <span className="mx-1 h-5 w-px shrink-0 bg-border" />;
}
