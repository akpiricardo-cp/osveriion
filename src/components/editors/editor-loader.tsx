"use client";

import dynamic from "next/dynamic";
import { Loader2 } from "lucide-react";
import type { EditorMeta } from "./editor-shell";

const Loading = () => (
  <div className="grid h-[60vh] place-items-center text-sm text-muted">
    <span className="flex items-center gap-2"><Loader2 className="h-5 w-5 animate-spin text-primary" /> Ouverture de l&apos;éditeur…</span>
  </div>
);

// Chaque éditeur est chargé à la demande pour garder la navigation légère.
const DocEditor = dynamic(() => import("./doc-editor").then((m) => m.DocEditor), { ssr: false, loading: Loading });
const SheetEditor = dynamic(() => import("./sheet-editor").then((m) => m.SheetEditor), { ssr: false, loading: Loading });
const SlidesEditor = dynamic(() => import("./slides-editor").then((m) => m.SlidesEditor), { ssr: false, loading: Loading });
const FileViewer = dynamic(() => import("./file-viewer").then((m) => m.FileViewer), { ssr: false, loading: Loading });

export function EditorLoader({ kind, meta, initial, ydoc, me }: { kind: string; meta: EditorMeta; initial: unknown; ydoc: string | null; me: { id: string; name: string; avatar: string | null } }) {
  switch (kind) {
    case "doc": return <DocEditor meta={meta} initial={initial as never} ydoc={ydoc} me={me} />;
    case "sheet": return <SheetEditor meta={meta} initial={initial} me={me} />;
    case "slides": return <SlidesEditor meta={meta} initial={initial} me={me} />;
    default: return <FileViewer meta={meta} />;
  }
}
