import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
import { format, formatDistanceToNowStrict, isToday, isYesterday, parseISO } from "date-fns";
import { fr } from "date-fns/locale";
import { tz } from "@date-fns/tz";

/** Fuseau de référence de l'entreprise (affichage identique serveur et navigateur). */
export const APP_TZ = process.env.NEXT_PUBLIC_TIMEZONE ?? "Africa/Porto-Novo";
const inTz = tz(APP_TZ);

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

const currencyFmt = new Map<string, Intl.NumberFormat>();

/** Formate un montant (XOF par défaut, sans décimales). */
export function money(value: number | string | null | undefined, currency = "XOF", compact = false) {
  const n = Number(value ?? 0);
  const key = `${currency}-${compact}`;
  if (!currencyFmt.has(key)) {
    currencyFmt.set(
      key,
      new Intl.NumberFormat("fr-FR", {
        style: "currency",
        currency,
        maximumFractionDigits: currency === "XOF" || compact ? (compact ? 1 : 0) : 2,
        notation: compact ? "compact" : "standard",
      }),
    );
  }
  return currencyFmt.get(key)!.format(n).replace(/F\s?CFA/u, "FCFA");
}

export function num(value: number | string | null | undefined, compact = false) {
  return new Intl.NumberFormat("fr-FR", {
    notation: compact ? "compact" : "standard",
    maximumFractionDigits: compact ? 1 : 0,
  }).format(Number(value ?? 0));
}

export function pct(value: number, digits = 0) {
  return `${value.toFixed(digits).replace(".", ",")} %`;
}

function toDate(d: string | Date) {
  return typeof d === "string" ? parseISO(d) : d;
}

export function dateFr(d: string | Date | null | undefined, pattern = "d MMM yyyy") {
  if (!d) return "—";
  return format(toDate(d), pattern, { locale: fr, in: inTz });
}

export function dateTimeFr(d: string | Date | null | undefined) {
  if (!d) return "—";
  return format(toDate(d), "d MMM yyyy 'à' HH:mm", { locale: fr, in: inTz });
}

export function relative(d: string | Date | null | undefined) {
  if (!d) return "—";
  const date = toDate(d);
  // En dessous d'une minute : libellé stable (évite aussi les écarts serveur/navigateur à l'hydratation)
  if (Math.abs(Date.now() - date.getTime()) < 60_000) return "à l'instant";
  return formatDistanceToNowStrict(date, { locale: fr, addSuffix: true });
}

export function chatTime(d: string) {
  const date = toDate(d);
  if (isToday(date, { in: inTz })) return format(date, "HH:mm", { in: inTz });
  if (isYesterday(date, { in: inTz })) return "Hier " + format(date, "HH:mm", { in: inTz });
  return format(date, "d MMM HH:mm", { locale: fr, in: inTz });
}

export function initials(name?: string | null) {
  if (!name) return "?";
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0]!.toUpperCase())
    .join("");
}

export function isOverdue(due?: string | null, done = false) {
  if (!due || done) return false;
  return due < todayISO();
}

export function todayISO() {
  return new Date().toLocaleDateString("fr-CA", { timeZone: APP_TZ });
}

export function randomRoom() {
  const chars = "abcdefghjkmnpqrstuvwxyz23456789";
  let s = "";
  for (let i = 0; i < 10; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return s;
}

/** Transforme une valeur de formulaire vide en null. */
export function nullable(v: FormDataEntryValue | null) {
  if (v === null) return null;
  const s = String(v).trim();
  return s === "" ? null : s;
}
