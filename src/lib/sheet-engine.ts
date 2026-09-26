// Moteur de calcul du tableur : références A1, formules Excel (fonctions FR et EN),
// séparateur « ; » accepté, détection des références circulaires.
import FormulaParser, { FormulaError } from "fast-formula-parser";
import type { SheetContent, SheetData } from "./drive";

export function colName(i: number) {
  let s = "";
  let n = i + 1;
  while (n > 0) {
    const m = (n - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    n = Math.floor((n - 1) / 26);
  }
  return s;
}

export function colIndex(name: string) {
  let n = 0;
  for (const ch of name.toUpperCase()) n = n * 26 + (ch.charCodeAt(0) - 64);
  return n - 1;
}

export function ref(r: number, c: number) {
  return `${colName(c)}${r + 1}`;
}

export function parseRef(a1: string): { r: number; c: number } | null {
  const m = /^([A-Z]+)(\d+)$/i.exec(a1.trim());
  if (!m) return null;
  return { c: colIndex(m[1]), r: Number(m[2]) - 1 };
}

// Noms de fonctions français → anglais (compatibilité Excel FR)
const FR: Record<string, string> = {
  "SOMME": "SUM", "MOYENNE": "AVERAGE", "SI": "IF", "SI.ERREUR": "IFERROR", "NB": "COUNT", "NBVAL": "COUNTA",
  "ARRONDI": "ROUND", "ARRONDI.SUP": "ROUNDUP", "ARRONDI.INF": "ROUNDDOWN", "RECHERCHEV": "VLOOKUP", "RECHERCHEH": "HLOOKUP",
  "CONCATENER": "CONCATENATE", "CONCAT": "CONCAT", "AUJOURDHUI": "TODAY", "MAINTENANT": "NOW", "SOMME.SI": "SUMIF",
  "SOMME.SI.ENS": "SUMIFS", "NB.SI": "COUNTIF", "MOYENNE.SI": "AVERAGEIF", "ET": "AND", "OU": "OR", "NON": "NOT",
  "ENT": "INT", "MOD": "MOD", "PRODUIT": "PRODUCT", "MEDIANE": "MEDIAN", "GAUCHE": "LEFT", "DROITE": "RIGHT",
  "STXT": "MID", "NBCAR": "LEN", "MAJUSCULE": "UPPER", "MINUSCULE": "LOWER", "SUPPRESPACE": "TRIM", "ANNEE": "YEAR",
  "MOIS": "MONTH", "JOUR": "DAY", "PUISSANCE": "POWER", "RACINE": "SQRT", "EQUIV": "MATCH", "INDEX": "INDEX", "TEXTE": "TEXT",
};

export function normalizeFormula(input: string) {
  // Syntaxe française (« ; » séparateur, « , » décimale) si un « ; » apparaît hors des chaînes.
  let french = false;
  let inStr = false;
  for (const ch of input) {
    if (ch === '"') inStr = !inStr;
    else if (!inStr && ch === ";") { french = true; break; }
  }
  let out = "";
  inStr = false;
  for (let i = 0; i < input.length; i++) {
    const ch = input[i];
    if (ch === '"') inStr = !inStr;
    if (!inStr && french && ch === ",") { out += "."; continue; }
    if (!inStr && ch === ";") { out += ","; continue; }
    out += ch;
  }
  out = out.replace(/(^|[^A-Za-z0-9_."])(VRAI|FAUX)(?![A-Za-z0-9_(])/gi, (_m, pre: string, w: string) => pre + (w.toUpperCase() === "VRAI" ? "TRUE" : "FALSE"));
  return out.replace(/([A-ZÀ-Ü][A-ZÀ-Ü.]*)\s*\(/gi, (m, name: string) => {
    const key = name.toUpperCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    return (FR[key] ?? name.toUpperCase()) + "(";
  });
}

export type CellValue = number | string | boolean | null | { error: string };

function coerce(raw: string): CellValue {
  const t = raw.trim();
  if (t === "") return null;
  const n = t.replace(/\s/g, "").replace(",", ".");
  if (/^-?\d+(\.\d+)?%$/.test(n)) return Number(n.slice(0, -1)) / 100;
  if (/^-?\d+(\.\d+)?(e-?\d+)?$/i.test(n)) return Number(n);
  if (/^(vrai|true)$/i.test(t)) return true;
  if (/^(faux|false)$/i.test(t)) return false;
  return raw;
}

function isErr(v: unknown): v is { error: string } {
  return typeof v === "object" && v !== null && "error" in v;
}

// Fonctions absentes ou incomplètes dans la bibliothèque de calcul
type Param = { value: unknown };
function flat(args: Param[]): unknown[] {
  const out: unknown[] = [];
  const push = (v: unknown) => (Array.isArray(v) ? v.forEach(push) : out.push(v));
  args.forEach((a) => push(a?.value));
  return out;
}
const nums = (args: Param[]) => flat(args).filter((v): v is number => typeof v === "number");
const EXTRA: Record<string, (...args: Param[]) => unknown> = {
  MAX: (...a) => { const n = nums(a); return n.length ? Math.max(...n) : 0; },
  MIN: (...a) => { const n = nums(a); return n.length ? Math.min(...n) : 0; },
  MEDIAN: (...a) => {
    const n = nums(a).sort((x, y) => x - y);
    if (!n.length) return new FormulaError("#NUM!");
    const m = Math.floor(n.length / 2);
    return n.length % 2 ? n[m] : (n[m - 1] + n[m]) / 2;
  },
  COUNTA: (...a) => flat(a).filter((v) => v !== undefined && v !== null && v !== "").length,
  COUNTBLANK: (...a) => flat(a).filter((v) => v === undefined || v === null || v === "").length,
  LEN: (a) => String(a?.value ?? "").length,
  UPPER: (a) => String(a?.value ?? "").toUpperCase(),
  MATCH: (lookup, range, type) => {
    const list = flat([range]);
    const target = lookup?.value;
    const mode = type?.value === undefined ? 1 : Number(type.value);
    if (mode === 0) {
      const i = list.findIndex((v) => (typeof v === "string" && typeof target === "string" ? v.toLowerCase() === target.toLowerCase() : v === target));
      return i >= 0 ? i + 1 : new FormulaError("#N/A");
    }
    let best = -1;
    list.forEach((v, i) => { if (typeof v === "number" && typeof target === "number" && (mode > 0 ? v <= target : v >= target)) best = i; });
    return best >= 0 ? best + 1 : new FormulaError("#N/A");
  },
};

/** Crée un évaluateur pour un classeur : getValue(feuille, ligne, colonne) avec cache. */
export function createEvaluator(content: SheetContent) {
  const cache = new Map<string, CellValue>();
  const evaluating = new Set<string>();
  const byName = new Map(content.sheets.map((s, i) => [s.name.toLowerCase(), i]));

  const sheetIdx = (name?: string) => (name ? byName.get(name.toLowerCase()) ?? -1 : 0);

  // L'analyseur n'est pas réentrant : une instance par niveau d'imbrication des formules.
  const parsers: FormulaParser[] = [];
  const parserAt = (depth: number) => (parsers[depth] ??= makeParser());
  const makeParser = () => new FormulaParser({
    functions: EXTRA as unknown as Record<string, (...args: unknown[]) => unknown>,
    onCell: ({ sheet, row, col }: { sheet: string; row: number; col: number }) => toParser(getValue(sheetIdx(sheet), row - 1, col - 1)),
    onRange: (r: { sheet: string; from: { row: number; col: number }; to: { row: number; col: number } }) => {
      const si = sheetIdx(r.sheet);
      const sh = content.sheets[si];
      if (!sh) return [[]];
      const toRow = Math.min(r.to.row, sh.rows);
      const toCol = Math.min(r.to.col, sh.cols);
      const out: unknown[][] = [];
      for (let row = r.from.row; row <= toRow; row++) {
        const line: unknown[] = [];
        for (let col = r.from.col; col <= toCol; col++) {
          const v = getValue(si, row - 1, col - 1);
          line.push(v === null ? "" : toParser(v));
        }
        out.push(line);
      }
      return out;
    },
  });

  function toParser(v: CellValue) {
    if (isErr(v)) return new FormulaError(v.error);
    return v;
  }

  function getValue(si: number, r: number, c: number): CellValue {
    const sheet: SheetData | undefined = content.sheets[si];
    if (!sheet) return { error: "#REF!" };
    const key = `${si}:${r}:${c}`;
    if (cache.has(key)) return cache.get(key)!;
    const raw = sheet.cells[ref(r, c)]?.v ?? "";
    let value: CellValue;
    if (raw.startsWith("=") && raw.length > 1) {
      if (evaluating.has(key)) return { error: "#CIRC!" };
      evaluating.add(key);
      try {
        const res = parserAt(evaluating.size - 1).parse(normalizeFormula(raw.slice(1)), { sheet: sheet.name, row: r + 1, col: c + 1 });
        value = normalizeResult(res);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        value = { error: /#[A-Z/0!?]+/.exec(msg)?.[0] ?? "#ERREUR" };
      } finally {
        evaluating.delete(key);
      }
    } else {
      value = coerce(raw);
    }
    cache.set(key, value);
    return value;
  }

  function normalizeResult(res: unknown): CellValue {
    if (res === undefined || res === null) return 0;
    if (Array.isArray(res)) return normalizeResult(Array.isArray(res[0]) ? res[0][0] : res[0]);
    if (typeof res === "object") {
      const s = String(res);
      return { error: s.startsWith("#") ? s : "#VALEUR!" };
    }
    if (typeof res === "number" && !Number.isFinite(res)) return { error: "#NUM!" };
    return res as CellValue;
  }

  return { getValue };
}

const nf2 = new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 10 });

export function formatValue(v: CellValue, fmt?: string) {
  if (v === null) return "";
  if (isErr(v)) return v.error;
  if (typeof v === "boolean") return v ? "VRAI" : "FAUX";
  if (typeof v === "number") {
    switch (fmt) {
      case "number": return new Intl.NumberFormat("fr-FR", { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(v);
      case "currency": return new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 0 }).format(v) + " FCFA";
      case "percent": return new Intl.NumberFormat("fr-FR", { style: "percent", maximumFractionDigits: 2 }).format(v);
      case "date": {
        // Numéro de série Excel → date
        const d = new Date(Math.round((v - 25569) * 86400000));
        return Number.isNaN(d.getTime()) ? String(v) : d.toLocaleDateString("fr-FR", { timeZone: "UTC" });
      }
      default: return nf2.format(v);
    }
  }
  return String(v);
}

export function isError(v: CellValue) {
  return isErr(v);
}

/** Décale les références relatives d'une formule (copier-coller, recopie). */
export function shiftFormula(raw: string, dr: number, dc: number) {
  if (!raw.startsWith("=")) return raw;
  let inStr = false;
  let out = "";
  const re = /(\$?)([A-Z]{1,3})(\$?)(\d{1,6})(?![A-Z0-9(])/gy;
  for (let i = 0; i < raw.length; ) {
    const ch = raw[i];
    if (ch === '"') { inStr = !inStr; out += ch; i++; continue; }
    if (!inStr) {
      re.lastIndex = i;
      const prev = raw[i - 1] ?? "";
      const m = /[A-Z0-9_.!]/i.test(prev) ? null : re.exec(raw);
      if (m) {
        const [, dCol, col, dRow, row] = m;
        const c = dCol ? col : colName(Math.max(0, colIndex(col) + dc));
        const r = dRow ? row : String(Math.max(1, Number(row) + dr));
        out += `${dCol}${c}${dRow}${r}`;
        i += m[0].length;
        continue;
      }
    }
    out += ch;
    i++;
  }
  return out;
}

/**
 * Ajuste les références d'une formule après insertion / suppression de lignes ou colonnes.
 * axis = "row" | "col", at = index (0-based) à partir duquel décaler, delta = +n / -n.
 */
export function insertShift(raw: string, axis: "row" | "col", at: number, delta: number) {
  if (!raw.startsWith("=")) return raw;
  let inStr = false;
  let out = "";
  const re = /(\$?)([A-Z]{1,3})(\$?)(\d{1,6})(?![A-Z0-9(])/gy;
  for (let i = 0; i < raw.length; ) {
    const ch = raw[i];
    if (ch === '"') { inStr = !inStr; out += ch; i++; continue; }
    if (!inStr) {
      re.lastIndex = i;
      const prev = raw[i - 1] ?? "";
      const m = /[A-Z0-9_.]/i.test(prev) ? null : re.exec(raw);
      if (m) {
        const [, dCol, col, dRow, row] = m;
        let c = colIndex(col);
        let r = Number(row) - 1;
        if (axis === "row" && r >= at) r = r + delta;
        if (axis === "col" && c >= at) c = c + delta;
        out += r < 0 || c < 0 ? "#REF!" : `${dCol}${colName(c)}${dRow}${r + 1}`;
        i += m[0].length;
        continue;
      }
    }
    out += ch;
    i++;
  }
  return out;
}
