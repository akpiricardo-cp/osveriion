import {
  File, FileArchive, FileAudio, FileImage, FileSpreadsheet, FileText, FileVideo, Folder, FolderLock, Presentation, Sheet, type LucideIcon,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { fileFamily, type DocKind } from "@/lib/drive";

const STYLES: Record<string, { icon: LucideIcon; cls: string }> = {
  doc: { icon: FileText, cls: "bg-sky-500/12 text-sky-600 dark:text-sky-400" },
  sheet: { icon: Sheet, cls: "bg-emerald-500/12 text-emerald-600 dark:text-emerald-400" },
  slides: { icon: Presentation, cls: "bg-orange-500/12 text-orange-600 dark:text-orange-400" },
  pdf: { icon: FileText, cls: "bg-rose-500/12 text-rose-600 dark:text-rose-400" },
  image: { icon: FileImage, cls: "bg-violet-500/12 text-violet-600 dark:text-violet-400" },
  video: { icon: FileVideo, cls: "bg-pink-500/12 text-pink-600 dark:text-pink-400" },
  audio: { icon: FileAudio, cls: "bg-fuchsia-500/12 text-fuchsia-600 dark:text-fuchsia-400" },
  word: { icon: FileText, cls: "bg-blue-600/12 text-blue-700 dark:text-blue-400" },
  excel: { icon: FileSpreadsheet, cls: "bg-green-600/12 text-green-700 dark:text-green-400" },
  powerpoint: { icon: Presentation, cls: "bg-amber-600/12 text-amber-700 dark:text-amber-400" },
  text: { icon: FileText, cls: "bg-slate-500/12 text-slate-600 dark:text-slate-300" },
  archive: { icon: FileArchive, cls: "bg-yellow-500/12 text-yellow-700 dark:text-yellow-400" },
  other: { icon: File, cls: "bg-slate-500/12 text-slate-600 dark:text-slate-300" },
};

export function docStyle(kind: DocKind, mime?: string | null, name?: string | null) {
  return STYLES[kind === "file" ? fileFamily(mime, name) : kind] ?? STYLES.other;
}

export function DocIcon({ kind, mime, name, size = "md", className }: { kind: DocKind; mime?: string | null; name?: string | null; size?: "sm" | "md" | "lg"; className?: string }) {
  const { icon: Icon, cls } = docStyle(kind, mime, name);
  const box = { sm: "h-8 w-8 rounded-lg", md: "h-10 w-10 rounded-xl", lg: "h-14 w-14 rounded-2xl" }[size];
  const ic = { sm: "h-4 w-4", md: "h-5 w-5", lg: "h-7 w-7" }[size];
  return <span className={cn("grid shrink-0 place-items-center", box, cls, className)}><Icon className={ic} /></span>;
}

export function FolderIcon({ color, locked, size = "md" }: { color?: string | null; locked?: boolean; size?: "sm" | "md" | "lg" }) {
  const Icon = locked ? FolderLock : Folder;
  const box = { sm: "h-8 w-8 rounded-lg", md: "h-10 w-10 rounded-xl", lg: "h-14 w-14 rounded-2xl" }[size];
  const ic = { sm: "h-4 w-4", md: "h-5 w-5", lg: "h-7 w-7" }[size];
  return (
    <span className={cn("grid shrink-0 place-items-center", box)} style={{ background: `color-mix(in srgb, ${color ?? "#6366f1"} 14%, transparent)`, color: color ?? "#6366f1" }}>
      <Icon className={ic} />
    </span>
  );
}
