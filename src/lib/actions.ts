import "server-only";
import type { PostgrestError } from "@supabase/supabase-js";
import type { ActionResult } from "./types";

/** Traduit une erreur Postgres/PostgREST en message compréhensible. */
export function explain(error: PostgrestError | Error | null | undefined): string {
  if (!error) return "Erreur inconnue.";
  const e = error as PostgrestError;
  switch (e.code) {
    case "42501":
      return e.message && !e.message.startsWith("new row violates") && !e.message.startsWith("permission denied")
        ? e.message
        : "Action non autorisée pour votre rôle.";
    case "23505":
      return "Cet élément existe déjà.";
    case "23503":
      return "Élément lié introuvable ou encore utilisé ailleurs.";
    case "23514":
      return "Une des valeurs saisies n'est pas valide.";
    case "22P02":
      return "Format de donnée invalide.";
    case "PGRST116":
      return "Élément introuvable ou inaccessible.";
    default:
      return e.message || "Une erreur est survenue.";
  }
}

export function ok(message?: string, data?: unknown): ActionResult {
  return { ok: true, message, data };
}

export function fail(error: PostgrestError | Error | string | null | undefined): ActionResult {
  return { ok: false, error: typeof error === "string" ? error : explain(error) };
}

export function str(fd: FormData, key: string): string | null {
  const v = fd.get(key);
  if (v === null) return null;
  const s = String(v).trim();
  return s === "" ? null : s;
}

export function numVal(fd: FormData, key: string): number | null {
  const s = str(fd, key);
  if (s === null) return null;
  const n = Number(s.replace(/\s/g, "").replace(",", "."));
  return Number.isFinite(n) ? n : null;
}

export function bool(fd: FormData, key: string) {
  const v = fd.get(key);
  return v === "on" || v === "true" || v === "1";
}
