"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Download, ExternalLink, FileText, Loader2, Pencil, Upload } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { DocIcon } from "@/components/drive/icons";
import { uploadNewVersion } from "@/components/drive/upload";
import { fileFamily, humanSize, storageUrl } from "@/lib/drive";
import { createNativeDocument } from "@/app/(app)/documents/actions";
import { EditorShell, type EditorMeta } from "./editor-shell";

export function FileViewer({ meta }: { meta: EditorMeta }) {
  const { doc, access } = meta;
  const router = useRouter();
  const family = fileFamily(doc.mime_type, doc.file_name);
  const url = doc.storage_path ? storageUrl("documents", doc.storage_path, { name: doc.file_name ?? doc.title }) : null;
  const dl = doc.storage_path ? storageUrl("documents", doc.storage_path, { download: true, name: doc.file_name ?? doc.title }) : null;
  const [text, setText] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const input = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (family === "text" && url) fetch(url).then((r) => r.text()).then((t) => setText(t.slice(0, 200000))).catch(() => setText(null));
  }, [family, url]);

  async function convert() {
    if (!url || !meta.folder) return;
    setBusy(true);
    const tid = toast.loading("Conversion en document éditable…");
    try {
      const blob = await (await fetch(url)).blob();
      const file = new File([blob], doc.file_name ?? "fichier", { type: blob.type });
      let r;
      if (family === "word") {
        const [{ docxToHtml }, { generateJSON }, { editorExtensions }] = await Promise.all([import("@/lib/converters"), import("@tiptap/react"), import("./doc-extensions")]);
        const html = await docxToHtml(file);
        r = await createNativeDocument(meta.folder.id, "doc", doc.title, generateJSON(html, editorExtensions()), new DOMParser().parseFromString(html, "text/html").body.textContent ?? "");
      } else {
        const { spreadsheetToContent } = await import("@/lib/converters");
        const content = await spreadsheetToContent(file);
        r = await createNativeDocument(meta.folder.id, "sheet", doc.title, content, content.sheets.flatMap((s) => Object.values(s.cells).map((c) => c.v)).join(" "));
      }
      if (!r.ok) throw new Error(r.error);
      toast.success("Copie éditable créée dans le même dossier. Le fichier d'origine est conservé.", { id: tid });
      router.push(`/documents/d/${(r.data as { id: string }).id}`);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Conversion impossible", { id: tid });
    } finally {
      setBusy(false);
    }
  }

  async function newVersion(file: File) {
    setBusy(true);
    try {
      await uploadNewVersion(file, doc.id, meta.userId);
      toast.success("Nouvelle version publiée. L'ancienne reste dans l'historique.");
      router.refresh();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Échec");
    } finally {
      setBusy(false);
    }
  }

  return (
    <EditorShell meta={meta} wide>
      <input ref={input} type="file" className="hidden" onChange={(e) => { const f = e.target.files?.[0]; if (f) newVersion(f); e.target.value = ""; }} />
      <div className="mb-4 flex flex-wrap items-center gap-2">
        {dl && <a href={dl}><Button size="sm"><Download className="h-4 w-4" /> Télécharger</Button></a>}
        {url && <a href={url} target="_blank" rel="noreferrer"><Button size="sm" variant="outline"><ExternalLink className="h-4 w-4" /> Ouvrir dans un onglet</Button></a>}
        {access >= 2 && <Button size="sm" variant="outline" loading={busy} onClick={() => input.current?.click()}><Upload className="h-4 w-4" /> Nouvelle version</Button>}
        {access >= 2 && (family === "word" || family === "excel") && (
          <Button size="sm" variant="outline" loading={busy} onClick={convert}>
            <Pencil className="h-4 w-4" /> Modifier en ligne ({family === "word" ? "document" : "tableur"})
          </Button>
        )}
        <span className="ml-auto text-xs text-subtle">{doc.file_name} · {humanSize(doc.size_bytes)} · version {doc.version}</span>
      </div>

      <div className="overflow-hidden rounded-2xl border border-border bg-surface shadow-card">
        {!url ? (
          <Empty />
        ) : family === "pdf" ? (
          <iframe src={url} title={doc.title} className="h-[calc(100dvh-15rem)] w-full" />
        ) : family === "image" ? (
          <div className="grid min-h-[60vh] place-items-center bg-[repeating-conic-gradient(var(--surface-2)_0_25%,transparent_0_50%)] bg-[length:20px_20px] p-6">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={url} alt={doc.title} className="max-h-[75vh] max-w-full rounded-lg shadow-lg" />
          </div>
        ) : family === "video" ? (
          <video src={url} controls className="max-h-[75vh] w-full bg-black" />
        ) : family === "audio" ? (
          <div className="p-10"><audio src={url} controls className="w-full" /></div>
        ) : family === "text" ? (
          text === null ? <div className="grid h-64 place-items-center"><Loader2 className="h-5 w-5 animate-spin text-subtle" /></div>
            : <pre className="scrollbar-thin max-h-[75vh] overflow-auto whitespace-pre-wrap p-6 font-mono text-[13px] text-fg">{text}</pre>
        ) : (
          <div className="flex flex-col items-center gap-4 px-6 py-16 text-center">
            <DocIcon kind="file" mime={doc.mime_type} name={doc.file_name} size="lg" />
            <div>
              <p className="text-base font-semibold text-fg">{doc.file_name}</p>
              <p className="mt-1 max-w-md text-sm text-muted">
                {family === "word" || family === "excel"
                  ? "Aperçu non disponible pour ce format. Téléchargez-le, ou créez une copie modifiable directement dans VERIION OS."
                  : family === "powerpoint"
                    ? "Les présentations PowerPoint se téléchargent pour être ouvertes. Pour travailler en ligne, créez une présentation VERIION (Nouveau → Présentation)."
                    : "Aperçu non disponible pour ce type de fichier."}
              </p>
            </div>
          </div>
        )}
      </div>
    </EditorShell>
  );
}

function Empty() {
  return <div className="flex flex-col items-center gap-2 py-16 text-muted"><FileText className="h-8 w-8" />Aucun fichier associé.</div>;
}
