import type { SheetContent, SheetData, Slide, SlidesContent } from "@/lib/drive";

/*
 * Opérations de co-édition du tableur et des présentations.
 * Principe : les modifications courantes sont fines (une cellule, un champ de diapositive)
 * et se fusionnent naturellement ; les changements de structure (lignes, colonnes, feuilles,
 * ordre des diapositives, thème) remplacent la structure entière — le dernier arrivé l'emporte.
 */

type Cell = SheetData["cells"][string];
export type SheetOp =
  | { t: "cells"; sheet: string; set: Record<string, Cell | null> }
  | { t: "sheets"; sheets: SheetData[] };

const same = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);

export function diffSheets(prev: SheetContent, next: SheetContent): { forward: SheetOp[]; inverse: SheetOp[] } {
  const structural =
    prev.sheets.length !== next.sheets.length ||
    prev.sheets.some((s, i) => {
      const n = next.sheets[i];
      return s.id !== n.id || s.name !== n.name || s.rows !== n.rows || s.cols !== n.cols || !same(s.colWidths, n.colWidths);
    });
  if (structural) return { forward: [{ t: "sheets", sheets: next.sheets }], inverse: [{ t: "sheets", sheets: prev.sheets }] };

  const forward: SheetOp[] = [];
  const inverse: SheetOp[] = [];
  next.sheets.forEach((n, i) => {
    const p = prev.sheets[i];
    if (p.cells === n.cells) return;
    const set: Record<string, Cell | null> = {};
    const back: Record<string, Cell | null> = {};
    for (const k of new Set([...Object.keys(p.cells), ...Object.keys(n.cells)])) {
      if (!same(p.cells[k], n.cells[k])) { set[k] = n.cells[k] ?? null; back[k] = p.cells[k] ?? null; }
    }
    if (Object.keys(set).length) { forward.push({ t: "cells", sheet: n.id, set }); inverse.push({ t: "cells", sheet: n.id, set: back }); }
  });
  return { forward, inverse };
}

export function applySheetOp(content: SheetContent, op: SheetOp): SheetContent {
  if (op.t === "sheets") return { ...content, sheets: op.sheets };
  return {
    ...content,
    sheets: content.sheets.map((s) => {
      if (s.id !== op.sheet) return s;
      const cells = { ...s.cells };
      for (const [k, v] of Object.entries(op.set)) { if (v) cells[k] = v; else delete cells[k]; }
      return { ...s, cells };
    }),
  };
}

export type SlidesOp =
  | { t: "patch"; id: string; patch: Partial<Slide> }
  | { t: "all"; content: SlidesContent };

export function diffSlides(prev: SlidesContent, next: SlidesContent): SlidesOp[] {
  const structural = prev.theme !== next.theme || prev.slides.length !== next.slides.length || prev.slides.some((s, i) => s.id !== next.slides[i].id);
  if (structural) return [{ t: "all", content: next }];
  const ops: SlidesOp[] = [];
  next.slides.forEach((n, i) => {
    const p = prev.slides[i];
    if (p === n) return;
    const patch: Partial<Slide> = {};
    for (const k of new Set([...Object.keys(p), ...Object.keys(n)]) as Set<keyof Slide>) {
      if (!same(p[k], n[k])) (patch as Record<string, unknown>)[k] = n[k] ?? null;
    }
    if (Object.keys(patch).length) ops.push({ t: "patch", id: n.id, patch });
  });
  return ops;
}

export function applySlidesOp(content: SlidesContent, op: SlidesOp): SlidesContent {
  if (op.t === "all") return op.content;
  return { ...content, slides: content.slides.map((s) => (s.id === op.id ? { ...s, ...op.patch } as Slide : s)) };
}
