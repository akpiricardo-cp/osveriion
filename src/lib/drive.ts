// Types et utilitaires partagés de l'espace documentaire (client et serveur).
import type { DocCategory, DocClassification } from "./types";

export type FolderSpace = "personal" | "unit" | "project" | "company";
export type ShareRole = "viewer" | "editor" | "manager";
export type DocKind = "file" | "doc" | "sheet" | "slides";

export interface Folder {
  id: string;
  parent_id: string | null;
  space: FolderSpace;
  name: string;
  owner_id: string | null;
  unit_id: string | null;
  project_id: string | null;
  color: string | null;
  path: string[];
  depth: number;
  is_root: boolean;
  created_by: string | null;
  deleted_at: string | null;
  created_at: string;
  updated_at: string;
  access?: number;
  items?: number;
  shared?: boolean;
}

export interface DriveDoc {
  id: string;
  title: string;
  description: string | null;
  category: DocCategory;
  classification: DocClassification;
  folder_id: string | null;
  kind: DocKind;
  owner_id: string | null;
  updated_by: string | null;
  storage_path: string | null;
  file_name: string | null;
  mime_type: string | null;
  size_bytes: number | null;
  version: number;
  revision: number;
  tags: string[];
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
  access?: number;
  shared?: boolean;
}

export interface Share {
  id: string;
  folder_id: string | null;
  document_id: string | null;
  profile_id: string | null;
  unit_id: string | null;
  role: ShareRole;
  expires_at: string | null;
  created_by: string | null;
  created_at: string;
}

export interface Listing {
  access: number;
  folder: Folder;
  breadcrumb: { id: string; name: string }[];
  folders: Folder[];
  documents: DriveDoc[];
  shares: Share[];
}

export interface Space {
  id: string;
  space: FolderSpace;
  name: string;
  unit_id: string | null;
  project_id: string | null;
  access: number;
  color: string | null;
}

export const ACCESS_LABEL: Record<number, string> = { 0: "Aucun accès", 1: "Lecture", 2: "Modification", 3: "Gestion" };
export const ROLE_LABEL: Record<ShareRole, string> = { viewer: "Lecteur", editor: "Éditeur", manager: "Gestionnaire" };
export const KIND_LABEL: Record<DocKind, string> = { file: "Fichier", doc: "Document", sheet: "Tableur", slides: "Présentation" };

/** Détermine l'aperçu possible d'un fichier déposé. */
export function fileFamily(mime?: string | null, name?: string | null) {
  const ext = (name ?? "").split(".").pop()?.toLowerCase() ?? "";
  const m = mime ?? "";
  if (m === "application/pdf" || ext === "pdf") return "pdf";
  if (m.startsWith("image/")) return "image";
  if (m.startsWith("video/")) return "video";
  if (m.startsWith("audio/")) return "audio";
  if (["docx", "doc", "odt", "rtf"].includes(ext) || m.includes("wordprocessingml") || m.includes("msword")) return "word";
  if (["xlsx", "xls", "ods", "csv"].includes(ext) || m.includes("spreadsheetml") || m.includes("excel") || m === "text/csv") return "excel";
  if (["pptx", "ppt", "odp", "key"].includes(ext) || m.includes("presentationml") || m.includes("powerpoint")) return "powerpoint";
  if (m.startsWith("text/") || ["txt", "md", "json", "log"].includes(ext)) return "text";
  if (["zip", "rar", "7z", "tar", "gz"].includes(ext)) return "archive";
  return "other";
}

export function humanSize(b?: number | null) {
  if (!b) return "—";
  if (b < 1024) return `${b} o`;
  if (b < 1024 ** 2) return `${Math.round(b / 1024)} Ko`;
  if (b < 1024 ** 3) return `${(b / 1024 ** 2).toFixed(1).replace(".", ",")} Mo`;
  return `${(b / 1024 ** 3).toFixed(1).replace(".", ",")} Go`;
}

export function safeFileName(name: string) {
  return name.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-zA-Z0-9._-]+/g, "-").slice(-120) || "fichier";
}

export function storageUrl(bucket: string, path: string, opts?: { download?: boolean; name?: string }) {
  const q = new URLSearchParams();
  if (opts?.download) q.set("telecharger", "1");
  if (opts?.name) q.set("nom", opts.name);
  const qs = q.toString();
  return `/api/storage/${bucket}/${path.split("/").map(encodeURIComponent).join("/")}${qs ? `?${qs}` : ""}`;
}

// ─── Contenus par défaut des documents natifs ───────────────────────────────
export function emptyDoc() {
  return { type: "doc", content: [{ type: "paragraph" }] };
}

export interface SheetCell { v: string; s?: CellStyle }
export interface CellStyle { b?: boolean; i?: boolean; u?: boolean; align?: "left" | "center" | "right"; fmt?: "general" | "number" | "currency" | "percent" | "date"; color?: string; bg?: string }
export interface SheetData { id: string; name: string; cells: Record<string, SheetCell>; rows: number; cols: number; colWidths: Record<string, number> }
export interface SheetContent { sheets: SheetData[] }

export function emptySheet(): SheetContent {
  return { sheets: [{ id: crypto.randomUUID(), name: "Feuille 1", cells: {}, rows: 60, cols: 16, colWidths: {} }] };
}

export type SlideLayout = "title" | "content" | "two" | "image" | "section" | "quote";
export interface Slide { id: string; layout: SlideLayout; title: string; subtitle?: string; body?: string; body2?: string; image?: string | null; notes?: string }
export interface SlidesContent { theme: "nuit" | "clair" | "indigo"; slides: Slide[] }

export function emptySlides(title = "Nouvelle présentation"): SlidesContent {
  return {
    theme: "nuit",
    slides: [
      { id: crypto.randomUUID(), layout: "title", title, subtitle: "VERIION · " + new Date().toLocaleDateString("fr-FR", { month: "long", year: "numeric" }) },
      { id: crypto.randomUUID(), layout: "content", title: "Ordre du jour", body: "Contexte\nObjectifs\nPlan d'action\nProchaines étapes" },
    ],
  };
}

export function defaultContent(kind: DocKind, title?: string) {
  if (kind === "doc") return emptyDoc();
  if (kind === "sheet") return emptySheet();
  if (kind === "slides") return emptySlides(title);
  return null;
}
