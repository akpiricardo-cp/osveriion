import { describe, expect, it } from "vitest";
import { colIndex, colName, createEvaluator, normalizeFormula, parseRef, shiftFormula } from "@/lib/sheet-engine";
import type { SheetContent } from "@/lib/drive";

function sheet(cells: Record<string, string>): SheetContent {
  return { sheets: [{ id: "s1", name: "Feuille 1", rows: 20, cols: 10, colWidths: {}, cells: Object.fromEntries(Object.entries(cells).map(([k, v]) => [k, { v }])) }] } as unknown as SheetContent;
}

describe("références", () => {
  it("convertit colonnes et références A1", () => {
    expect(colName(0)).toBe("A");
    expect(colName(27)).toBe("AB");
    expect(colIndex("AB")).toBe(27);
    expect(parseRef("C5")).toEqual({ r: 4, c: 2 });
  });

  it("décale les références relatives et garde les absolues", () => {
    expect(shiftFormula("=A1+$B$2", 1, 1)).toBe("=B2+$B$2");
  });
});

describe("formules", () => {
  it("comprend la syntaxe française", () => {
    expect(normalizeFormula("SOMME(A1;A2)")).toBe("SUM(A1,A2)");
    expect(normalizeFormula("SI(A1>1,5;VRAI;FAUX)")).toBe("IF(A1>1.5,TRUE,FALSE)");
  });

  it("calcule une somme et une condition", () => {
    const ev = createEvaluator(sheet({ A1: "10", A2: "32", A3: "=SOMME(A1:A2)", B1: '=SI(A3>40;"ok";"non")' }));
    expect(ev.getValue(0, 2, 0)).toBe(42);
    expect(ev.getValue(0, 0, 1)).toBe("ok");
  });

  it("détecte les références circulaires", () => {
    const ev = createEvaluator(sheet({ A1: "=B1", B1: "=A1" }));
    expect(ev.getValue(0, 0, 0)).toEqual({ error: "#CIRC!" });
  });
});
