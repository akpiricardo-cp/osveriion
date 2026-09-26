"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { EditorContent, useEditor, useEditorState, type Editor, type JSONContent } from "@tiptap/react";
import { getSchema } from "@tiptap/core";
import Collaboration from "@tiptap/extension-collaboration";
import CollaborationCaret from "@tiptap/extension-collaboration-caret";
import { prosemirrorJSONToYXmlFragment } from "@tiptap/y-tiptap";
import * as Y from "yjs";
import {
  AlignCenter, AlignJustify, AlignLeft, AlignRight, Bold, Code2, FileDown, FileText, Heading1, Heading2, Heading3, Highlighter, ImagePlus,
  Italic, Link2, List, ListChecks, ListOrdered, Minus, Palette, Pilcrow, Printer, Quote, Redo2, RemoveFormatting, Strikethrough, Table2,
  Underline as UnderlineIcon, Undo2,
} from "lucide-react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import { exportDocx, download, safeTitle } from "@/lib/converters";
import { uploadDocAsset } from "@/components/drive/upload";
import { editorExtensions } from "./doc-extensions";
import { EditorShell, ExportItem, type EditorMeta } from "./editor-shell";
import { useDocSync } from "./use-doc-sync";
import { createClient } from "@/lib/supabase/client";
import { applyEncoded, encodeDoc, SupabaseYjsProvider } from "@/lib/collab/yjs-provider";

const COLORS = ["#0b1020", "#e11d48", "#ea580c", "#d97706", "#059669", "#0284c7", "#4f46e5", "#9333ea", "#6b7280"];

const EMPTY: JSONContent = { type: "doc", content: [{ type: "paragraph" }] };
const FIELD = "default";

/**
 * Construit l'état Yjs initial. Sans état enregistré, on le dérive du JSON avec un
 * identifiant client fixe : deux personnes qui ouvrent le document au même moment
 * produisent exactement les mêmes éléments, que Yjs fusionne sans doublon.
 */
function buildYDoc(initial: JSONContent | null, stored: string | null) {
  const doc = new Y.Doc();
  if (stored) {
    try { applyEncoded(doc, stored); return doc; } catch { /* état illisible : reconstruit depuis le JSON */ }
  }
  const seed = new Y.Doc();
  seed.clientID = 0;
  const schema = getSchema(editorExtensions("", { collab: true }));
  try {
    prosemirrorJSONToYXmlFragment(schema, initial && initial.type === "doc" ? initial : EMPTY, seed.getXmlFragment(FIELD));
  } catch {
    prosemirrorJSONToYXmlFragment(schema, EMPTY, seed.getXmlFragment(FIELD));
  }
  Y.applyUpdate(doc, Y.encodeStateAsUpdate(seed));
  seed.destroy();
  return doc;
}

export function DocEditor({ meta, initial, ydoc: stored, me }: { meta: EditorMeta; initial: JSONContent | null; ydoc: string | null; me: { id: string; name: string; avatar: string | null } }) {
  const canEdit = meta.access >= 2;
  const [ydoc] = useState(() => buildYDoc(initial, stored));
  const [provider, setProvider] = useState<SupabaseYjsProvider | null>(null);
  useEffect(() => {
    const p = new SupabaseYjsProvider(createClient(), meta.doc.id, ydoc, !canEdit);
    setProvider(p);
    return () => { p.destroy(); };
  }, [meta.doc.id, ydoc, canEdit]);
  if (!provider) return null;
  return <CollabDocEditor meta={meta} ydoc={ydoc} provider={provider} me={me} />;
}

function CollabDocEditor({ meta, ydoc, provider, me }: { meta: EditorMeta; ydoc: Y.Doc; provider: SupabaseYjsProvider; me: { id: string; name: string; avatar: string | null } }) {
  const canEdit = meta.access >= 2;
  const editorRef = useRef<Editor | null>(null);

  const sync = useDocSync({
    docId: meta.doc.id,
    initialRevision: meta.doc.revision,
    canEdit,
    me,
    collab: true,
    getContent: () => ({ content: editorRef.current?.getJSON() ?? EMPTY, text: editorRef.current?.getText() ?? "", ydoc: encodeDoc(ydoc) }),
    onRemote: () => {},
  });

  const insertImage = useCallback(async (file: File) => {
    const ed = editorRef.current;
    if (!ed) return;
    const tid = toast.loading("Insertion de l'image…");
    try {
      const src = await uploadDocAsset(file, meta.doc.id);
      ed.chain().focus().setImage({ src, alt: file.name }).run();
      toast.dismiss(tid);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Échec", { id: tid });
    }
  }, [meta.doc.id]);

  const editor = useEditor({
    extensions: [
      ...editorExtensions(canEdit ? "Commencez à écrire…" : "", { collab: true }),
      Collaboration.configure({ document: ydoc, field: FIELD }),
      CollaborationCaret.configure({
        provider,
        user: { name: me.name, color: sync.color },
        render: (user) => {
          const caret = document.createElement("span");
          caret.className = "vrn-caret";
          caret.style.borderColor = user.color;
          const label = document.createElement("span");
          label.className = "vrn-caret__label";
          label.style.backgroundColor = user.color;
          label.textContent = String(user.name ?? "").split(" ")[0] || "Invité";
          caret.append(label);
          return caret;
        },
        selectionRender: (user) => ({ nodeName: "span", class: "vrn-caret__selection", style: `background-color: ${user.color}33` }),
      }),
    ],
    editable: canEdit,
    immediatelyRender: false,
    editorProps: {
      attributes: { class: "vrn-prose focus:outline-none", spellcheck: "true" },
      handlePaste: (_view, event) => {
        const file = Array.from(event.clipboardData?.files ?? []).find((f) => f.type.startsWith("image/"));
        if (file && canEdit) { insertImage(file); return true; }
        return false;
      },
      handleDrop: (_view, event) => {
        const file = Array.from((event as DragEvent).dataTransfer?.files ?? []).find((f) => f.type.startsWith("image/"));
        if (file && canEdit) { event.preventDefault(); insertImage(file); return true; }
        return false;
      },
    },
    onCreate: ({ editor }) => { editorRef.current = editor; },
  }, [provider]);

  // Toute modification réelle du document partagé (locale ou reçue d'un collaborateur) est à enregistrer ;
  // le meneur s'en charge. L'ouverture du document ne produit aucune mise à jour Yjs.
  const markDirty = sync.markDirty;
  useEffect(() => {
    const onUpdate = () => markDirty();
    ydoc.on("update", onUpdate);
    return () => ydoc.off("update", onUpdate);
  }, [ydoc, markDirty]);

  const imageInput = useRef<HTMLInputElement>(null);
  const [colorOpen, setColorOpen] = useState(false);
  const tracked = useEditorState({ editor, selector: (s) => ({ words: s.editor?.storage.characterCount?.words?.() ?? 0, chars: s.editor?.storage.characterCount?.characters?.() ?? 0 }) });
  // En lecture seule aucune transaction ne déclenche le calcul : on compte directement le contenu
  const plain = editor && !tracked?.chars ? editor.state.doc.textBetween(0, editor.state.doc.content.size, " ", " ") : "";
  const counts = tracked?.chars ? tracked : { words: plain.split(/\s+/).filter(Boolean).length, chars: plain.length };

  const exportHtml = () => {
    if (!editor) return;
    const html = `<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>${meta.doc.title}</title><style>body{font-family:Calibri,Arial,sans-serif;max-width:800px;margin:40px auto;line-height:1.6;color:#111}table{border-collapse:collapse}td,th{border:1px solid #ccc;padding:6px 10px}img{max-width:100%}</style></head><body><h1>${meta.doc.title}</h1>${editor.getHTML()}</body></html>`;
    download(new Blob([html], { type: "text/html;charset=utf-8" }), `${safeTitle(meta.doc.title)}.html`);
  };

  return (
    <EditorShell
      meta={meta}
      status={sync.status}
      viewers={sync.viewers}
      lastSaved={sync.lastSaved}
      remoteEditor={sync.remoteEditor}
      onReload={sync.reload}
      onForceSave={() => sync.save({ force: true })}
      onRestored={() => { sync.announceReset(); window.location.reload(); }}
      live={sync.connected}
      onSnapshot={(note) => sync.save({ snapshot: true, note })}
      exportItems={
        <>
          <ExportItem icon={<FileDown className="h-4 w-4 text-blue-600" />} label="Word (.docx)" onSelect={() => editor && exportDocx(editor.getJSON(), meta.doc.title).catch(() => toast.error("Export impossible"))} />
          <ExportItem icon={<Printer className="h-4 w-4 text-rose-600" />} label="PDF (impression)" onSelect={() => window.print()} />
          <ExportItem icon={<FileText className="h-4 w-4 text-subtle" />} label="Page web (.html)" onSelect={exportHtml} />
        </>
      }
      toolbar={canEdit && editor ? (
        <Toolbar editor={editor} onImage={() => imageInput.current?.click()} colorOpen={colorOpen} setColorOpen={setColorOpen} />
      ) : undefined}
    >
      <input ref={imageInput} type="file" accept="image/*" className="hidden" onChange={(e) => { const f = e.target.files?.[0]; if (f) insertImage(f); e.target.value = ""; }} />
      <div className="mx-auto max-w-[850px] rounded-sm bg-surface px-6 py-10 shadow-[0_1px_3px_rgba(0,0,0,0.08),0_8px_24px_-12px_rgba(0,0,0,0.15)] ring-1 ring-border sm:px-16 sm:py-14 print:max-w-none print:p-0 print:shadow-none print:ring-0">
        <h1 className="mb-6 hidden text-3xl font-semibold print:block">{meta.doc.title}</h1>
        <EditorContent editor={editor} className="min-h-[60vh]" />
      </div>
      <p className="mx-auto mt-3 max-w-[850px] text-right text-xs text-subtle print:hidden">{counts?.words ?? 0} mots · {counts?.chars ?? 0} caractères</p>
    </EditorShell>
  );
}

function Toolbar({ editor, onImage, colorOpen, setColorOpen }: { editor: Editor; onImage: () => void; colorOpen: boolean; setColorOpen: (o: boolean) => void }) {
  const s = useEditorState({
    editor,
    selector: ({ editor: e }) => ({
      bold: e.isActive("bold"), italic: e.isActive("italic"), underline: e.isActive("underline"), strike: e.isActive("strike"),
      highlight: e.isActive("highlight"), code: e.isActive("codeBlock"), h1: e.isActive("heading", { level: 1 }), h2: e.isActive("heading", { level: 2 }),
      h3: e.isActive("heading", { level: 3 }), bullet: e.isActive("bulletList"), ordered: e.isActive("orderedList"), task: e.isActive("taskList"),
      quote: e.isActive("blockquote"), link: e.isActive("link"), table: e.isActive("table"),
      left: e.isActive({ textAlign: "left" }), center: e.isActive({ textAlign: "center" }), right: e.isActive({ textAlign: "right" }), justify: e.isActive({ textAlign: "justify" }),
      canUndo: e.can().undo(), canRedo: e.can().redo(),
    }),
  });
  const c = () => editor.chain().focus();
  const setLink = () => {
    const prev = editor.getAttributes("link").href as string | undefined;
    const url = prompt("Adresse du lien (laisser vide pour retirer) :", prev ?? "https://");
    if (url === null) return;
    if (url === "" || url === "https://") c().extendMarkRange("link").unsetLink().run();
    else c().extendMarkRange("link").setLink({ href: /^(https?:|mailto:|\/)/.test(url) ? url : `https://${url}` }).run();
  };

  return (
    <div className="scrollbar-thin flex items-center gap-0.5 overflow-x-auto py-1.5">
      <TB title="Annuler (Ctrl+Z)" onClick={() => c().undo().run()} disabled={!s.canUndo}><Undo2 /></TB>
      <TB title="Rétablir (Ctrl+Y)" onClick={() => c().redo().run()} disabled={!s.canRedo}><Redo2 /></TB>
      <Sep />
      <TB title="Texte normal" onClick={() => c().setParagraph().run()}><Pilcrow /></TB>
      <TB title="Titre 1" active={s.h1} onClick={() => c().toggleHeading({ level: 1 }).run()}><Heading1 /></TB>
      <TB title="Titre 2" active={s.h2} onClick={() => c().toggleHeading({ level: 2 }).run()}><Heading2 /></TB>
      <TB title="Titre 3" active={s.h3} onClick={() => c().toggleHeading({ level: 3 }).run()}><Heading3 /></TB>
      <Sep />
      <TB title="Gras (Ctrl+B)" active={s.bold} onClick={() => c().toggleBold().run()}><Bold /></TB>
      <TB title="Italique (Ctrl+I)" active={s.italic} onClick={() => c().toggleItalic().run()}><Italic /></TB>
      <TB title="Souligné (Ctrl+U)" active={s.underline} onClick={() => c().toggleUnderline().run()}><UnderlineIcon /></TB>
      <TB title="Barré" active={s.strike} onClick={() => c().toggleStrike().run()}><Strikethrough /></TB>
      <TB title="Surligner" active={s.highlight} onClick={() => c().toggleHighlight().run()}><Highlighter /></TB>
      <div className="relative">
        <TB title="Couleur du texte" onClick={() => setColorOpen(!colorOpen)}><Palette /></TB>
        {colorOpen && (
          <div className="absolute left-0 top-9 z-30 grid grid-cols-5 gap-1.5 rounded-xl border border-border bg-surface p-2 shadow-xl">
            {COLORS.map((col) => (
              <button key={col} aria-label={col} onClick={() => { c().setColor(col).run(); setColorOpen(false); }} className="h-6 w-6 rounded-full ring-1 ring-border" style={{ background: col }} />
            ))}
            <button onClick={() => { c().unsetColor().run(); setColorOpen(false); }} className="col-span-5 mt-1 rounded-md px-2 py-1 text-xs text-muted hover:bg-surface-2">Par défaut</button>
          </div>
        )}
      </div>
      <TB title="Lien" active={s.link} onClick={setLink}><Link2 /></TB>
      <Sep />
      <TB title="Aligner à gauche" active={s.left} onClick={() => c().setTextAlign("left").run()}><AlignLeft /></TB>
      <TB title="Centrer" active={s.center} onClick={() => c().setTextAlign("center").run()}><AlignCenter /></TB>
      <TB title="Aligner à droite" active={s.right} onClick={() => c().setTextAlign("right").run()}><AlignRight /></TB>
      <TB title="Justifier" active={s.justify} onClick={() => c().setTextAlign("justify").run()}><AlignJustify /></TB>
      <Sep />
      <TB title="Liste à puces" active={s.bullet} onClick={() => c().toggleBulletList().run()}><List /></TB>
      <TB title="Liste numérotée" active={s.ordered} onClick={() => c().toggleOrderedList().run()}><ListOrdered /></TB>
      <TB title="Liste de tâches" active={s.task} onClick={() => c().toggleTaskList().run()}><ListChecks /></TB>
      <TB title="Citation" active={s.quote} onClick={() => c().toggleBlockquote().run()}><Quote /></TB>
      <TB title="Bloc de code" active={s.code} onClick={() => c().toggleCodeBlock().run()}><Code2 /></TB>
      <TB title="Séparateur" onClick={() => c().setHorizontalRule().run()}><Minus /></TB>
      <Sep />
      <TB title="Insérer une image" onClick={onImage}><ImagePlus /></TB>
      <TB title="Insérer un tableau" onClick={() => c().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run()}><Table2 /></TB>
      {s.table && (
        <div className="ml-1 flex items-center gap-0.5 rounded-lg bg-surface-2 px-1">
          <TT onClick={() => c().addRowAfter().run()}>+ Ligne</TT>
          <TT onClick={() => c().addColumnAfter().run()}>+ Colonne</TT>
          <TT onClick={() => c().deleteRow().run()}>− Ligne</TT>
          <TT onClick={() => c().deleteColumn().run()}>− Colonne</TT>
          <TT onClick={() => c().mergeOrSplit().run()}>Fusionner</TT>
          <TT onClick={() => c().toggleHeaderRow().run()}>En-tête</TT>
          <TT danger onClick={() => c().deleteTable().run()}>Supprimer</TT>
        </div>
      )}
      <Sep />
      <TB title="Effacer la mise en forme" onClick={() => c().unsetAllMarks().clearNodes().run()}><RemoveFormatting /></TB>
    </div>
  );
}

function TB({ children, active, disabled, onClick, title }: { children: React.ReactElement; active?: boolean; disabled?: boolean; onClick: () => void; title: string }) {
  return (
    <button type="button" title={title} aria-label={title} disabled={disabled} onMouseDown={(e) => e.preventDefault()} onClick={onClick}
      className={cn("grid h-8 w-8 shrink-0 place-items-center rounded-md text-muted transition [&>svg]:h-4 [&>svg]:w-4 hover:bg-surface-2 hover:text-fg disabled:opacity-30",
        active && "bg-primary/10 text-primary hover:bg-primary/15 hover:text-primary")}>
      {children}
    </button>
  );
}
function TT({ children, onClick, danger }: { children: React.ReactNode; onClick: () => void; danger?: boolean }) {
  return <button type="button" onMouseDown={(e) => e.preventDefault()} onClick={onClick} className={cn("whitespace-nowrap rounded px-1.5 py-1 text-xs hover:bg-surface", danger ? "text-danger" : "text-muted hover:text-fg")}>{children}</button>;
}
function Sep() {
  return <span className="mx-1 h-5 w-px shrink-0 bg-border" />;
}
