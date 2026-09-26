declare module "fast-formula-parser" {
  export class FormulaError extends Error {
    constructor(error: string, msg?: string);
    toString(): string;
  }
  export default class FormulaParser {
    constructor(config?: {
      onCell?: (ref: { sheet: string; row: number; col: number }) => unknown;
      onRange?: (ref: { sheet: string; from: { row: number; col: number }; to: { row: number; col: number } }) => unknown[][];
      onVariable?: (name: string, sheet: string) => unknown;
      functions?: Record<string, (...args: unknown[]) => unknown>;
    });
    parse(formula: string, position: { sheet: string; row: number; col: number }, allowReturnArray?: boolean): unknown;
    static FormulaError: typeof FormulaError;
  }
}
