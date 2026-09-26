"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  ArrowDown, ArrowUp, Copy, FileDown, ImagePlus, Play, Plus, Printer, Trash2, X,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Dropdown, DropdownContent, DropdownItem, DropdownTrigger } from "@/components/ui/dropdown";
import { cn } from "@/lib/utils";
import type { Slide, SlideLayout, SlidesContent } from "@/lib/drive";
import { exportPptx } from "@/lib/converters";
import { uploadDocAsset } from "@/components/drive/upload";
import { EditorShell, ExportItem, type EditorMeta } from "./editor-shell";
import { useDocSync, type Viewer } from "./use-doc-sync";
import { applySlidesOp, diffSlides, type SlidesOp } from "@/lib/collab/ops";
import { Avatar } from "@/components/ui/avatar";

const LAYOUTS: Record<SlideLayout, string> = {
  title: "Titre", content: "Titre et contenu", two: "Deux colonnes", image: "Texte et image", section: "Intercalaire", quote: "Citation",
};
const THEMES = {
  nuit: { label: "Nuit VERIION", bg: "#050816", glow: "radial-gradient(ellipse at 15% 0%, rgba(99,102,241,.35), transparent 55%), radial-gradient(ellipse at 100% 100%, rgba(168,85,247,.22), transparent 50%)", title: "#ffffff", text: "#c9cee3", accent: "#818cf8", muted: "#6e7699" },
  clair: { label: "Clair", bg: "#ffffff", glow: "radial-gradient(ellipse at 100% 0%, rgba(79,70,229,.08), transparent 55%)", title: "#0b1020", text: "#3f475c", accent: "#4f46e5", muted: "#8a93a8" },
  indigo: { label: "Indigo", bg: "#312e81", glow: "radial-gradient(ellipse at 0% 100%, rgba(240,171,252,.25), transparent 55%)", title: "#ffffff", text: "#e0e7ff", accent: "#f0abfc", muted: "#a5b4fc" },
} as const;

function normalize(c: unknown): SlidesContent {
  const x = c as SlidesContent | null;
  if (x && Array.isArray(x.slides) && x.slides.length) return { theme: x.theme in THEMES ? x.theme : "nuit", slides: x.slides };
  return { theme: "nuit", slides: [{ id: crypto.randomUUID(), layout: "title", title: "Nouvelle présentation", subtitle: "VERIION" }] };
}
const plainText = (c: SlidesContent) => c.slides.map((s) => [s.title, s.subtitle, s.body, s.body2, s.notes].filter(Boolean).join(" ")).join("\n");

export function SlidesEditor({ meta, initial, me }: { meta: EditorMeta; initial: unknown; me: { id: string; name: string; avatar: string | null } }) {
  const canEdit = meta.access >= 2;
  const [content, setContent] = useState<SlidesContent>(() => normalize(initial));
  const [index, setIndex] = useState(0);
  const [presenting, setPresenting] = useState(false);
  const contentRef = useRef(content);
  contentRef.current = content;
  const imageInput = useRef<HTMLInputElement>(null);

  const sync = useDocSync({
    docId: meta.doc.id, initialRevision: meta.doc.revision, canEdit, me,
    collab: true,
    getContent: () => ({ content: contentRef.current, text: plainText(contentRef.current) }),
    onRemote: (c) => setContent(normalize(c)),
    onOp: (op) => applyRemote((cur) => applySlidesOp(cur, op as SlidesOp)),
    onSnapshot: (c) => applyRemote(() => normalize(c)),
  });

  // Une modification reçue peut ajouter ou déplacer des diapositives : on reste sur la même diapositive.
  const currentId = useRef<string | null>(null);
  const applyRemote = (fn: (cur: SlidesContent) => SlidesContent) => {
    const next = fn(contentRef.current);
    contentRef.current = next;
    setContent(next);
    const j = next.slides.findIndex((x) => x.id === currentId.current);
    setIndex((i) => (j >= 0 ? j : Math.min(i, next.slides.length - 1)));
  };

  const { markDirty, sendOp, setFocus: shareFocus } = sync;
  const update = useCallback((next: SlidesContent) => {
    const ops = diffSlides(contentRef.current, next);
    if (!ops.length) return;
    contentRef.current = next;
    setContent(next);
    ops.forEach(sendOp);
    markDirty();
  }, [markDirty, sendOp]);
  const slide = content.slides[Math.min(index, content.slides.length - 1)];
  currentId.current = slide?.id ?? null;
  useEffect(() => { shareFocus(slide?.id ?? null); }, [shareFocus, slide?.id]);
  const watchers = useMemo(() => {
    const m = new Map<string, Viewer[]>();
    sync.presence.forEach((v) => { if (v.focus && v.id !== me.id) m.set(v.focus, [...(m.get(v.focus) ?? []), v]); });
    return m;
  }, [sync.presence, me.id]);
  const patchSlide = (patch: Partial<Slide>) => update({ ...content, slides: content.slides.map((s, i) => (i === index ? { ...s, ...patch } : s)) });

  const addSlide = (layout: SlideLayout) => {
    const s: Slide = { id: crypto.randomUUID(), layout, title: layout === "quote" ? "— Auteur" : "Titre de la diapositive", body: layout === "quote" ? "Votre citation" : layout === "section" || layout === "title" ? undefined : "Premier point\nDeuxième point\nTroisième point", body2: layout === "two" ? "Premier point\nDeuxième point" : undefined, subtitle: layout === "section" || layout === "title" ? "Sous-titre" : undefined };
    const slides = [...content.slides];
    slides.splice(index + 1, 0, s);
    update({ ...content, slides });
    setIndex(index + 1);
  };
  const move = (d: -1 | 1) => {
    const j = index + d;
    if (j < 0 || j >= content.slides.length) return;
    const slides = [...content.slides];
    [slides[index], slides[j]] = [slides[j], slides[index]];
    update({ ...content, slides });
    setIndex(j);
  };
  const duplicate = () => {
    const slides = [...content.slides];
    slides.splice(index + 1, 0, { ...slide, id: crypto.randomUUID() });
    update({ ...content, slides });
    setIndex(index + 1);
  };
  const remove = () => {
    if (content.slides.length === 1) return toast.info("Une présentation contient au moins une diapositive.");
    update({ ...content, slides: content.slides.filter((_, i) => i !== index) });
    setIndex(Math.max(0, index - 1));
  };

  const addImage = async (file: File) => {
    const tid = toast.loading("Envoi de l'image…");
    try {
      const src = await uploadDocAsset(file, meta.doc.id);
      patchSlide({ image: src, layout: slide.layout === "image" ? "image" : "image" });
      toast.dismiss(tid);
    } catch (e) { toast.error(e instanceof Error ? e.message : "Échec", { id: tid }); }
  };

  useEffect(() => {
    if (presenting) return;
    const onKey = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement).tagName;
      if (tag === "TEXTAREA" || tag === "INPUT") return;
      if (e.key === "ArrowDown" || e.key === "PageDown") setIndex((i) => Math.min(content.slides.length - 1, i + 1));
      if (e.key === "ArrowUp" || e.key === "PageUp") setIndex((i) => Math.max(0, i - 1));
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [presenting, content.slides.length]);

  const toolbar = (
    <div className="scrollbar-thin flex items-center gap-1.5 overflow-x-auto py-1.5">
      {canEdit && (
        <>
          <Dropdown>
            <DropdownTrigger asChild><Button size="sm" variant="outline"><Plus className="h-4 w-4" /> Diapositive</Button></DropdownTrigger>
            <DropdownContent align="start">
              {(Object.keys(LAYOUTS) as SlideLayout[]).map((l) => <DropdownItem key={l} onSelect={() => addSlide(l)}>{LAYOUTS[l]}</DropdownItem>)}
            </DropdownContent>
          </Dropdown>
          <select value={slide.layout} onChange={(e) => patchSlide({ layout: e.target.value as SlideLayout })} className="h-8 rounded-md border border-border bg-surface px-2 text-[13px] text-fg">
            {(Object.keys(LAYOUTS) as SlideLayout[]).map((l) => <option key={l} value={l}>{LAYOUTS[l]}</option>)}
          </select>
          <select value={content.theme} onChange={(e) => update({ ...content, theme: e.target.value as SlidesContent["theme"] })} className="h-8 rounded-md border border-border bg-surface px-2 text-[13px] text-fg">
            {(Object.keys(THEMES) as (keyof typeof THEMES)[]).map((t) => <option key={t} value={t}>Thème : {THEMES[t].label}</option>)}
          </select>
          <span className="mx-1 h-5 w-px bg-border" />
          <IconBtn title="Image" onClick={() => imageInput.current?.click()}><ImagePlus /></IconBtn>
          <IconBtn title="Dupliquer" onClick={duplicate}><Copy /></IconBtn>
          <IconBtn title="Monter" onClick={() => move(-1)}><ArrowUp /></IconBtn>
          <IconBtn title="Descendre" onClick={() => move(1)}><ArrowDown /></IconBtn>
          <IconBtn title="Supprimer la diapositive" onClick={remove}><Trash2 /></IconBtn>
          <span className="mx-1 h-5 w-px bg-border" />
        </>
      )}
      <Button size="sm" onClick={() => { setPresenting(true); document.documentElement.requestFullscreen?.().catch(() => {}); }}><Play className="h-4 w-4" /> Présenter</Button>
    </div>
  );

  return (
    <EditorShell
      meta={meta}
      wide
      status={sync.status}
      viewers={sync.viewers}
      lastSaved={sync.lastSaved}
      remoteEditor={sync.remoteEditor}
      onReload={sync.reload}
      onForceSave={() => sync.save({ force: true })}
      onRestored={() => { sync.announceReset(); window.location.reload(); }}
      live={sync.connected}
      onSnapshot={(note) => sync.save({ snapshot: true, note })}
      toolbar={toolbar}
      exportItems={
        <>
          <ExportItem icon={<FileDown className="h-4 w-4 text-orange-600" />} label="PowerPoint (.pptx)" onSelect={() => exportPptx(content, meta.doc.title).catch(() => toast.error("Export impossible"))} />
          <ExportItem icon={<Printer className="h-4 w-4 text-rose-600" />} label="PDF (impression)" onSelect={() => window.print()} />
        </>
      }
    >
      <input ref={imageInput} type="file" accept="image/*" className="hidden" onChange={(e) => { const f = e.target.files?.[0]; if (f) addImage(f); e.target.value = ""; }} />
      <div className="flex gap-5 print:hidden">
        <ol className="scrollbar-thin hidden max-h-[calc(100dvh-13rem)] w-52 shrink-0 space-y-3 overflow-y-auto pr-1 md:block">
          {content.slides.map((s, i) => (
            <li key={s.id} className="flex gap-2">
              <span className="w-4 pt-1 text-right text-xs text-subtle">{i + 1}</span>
              <button onClick={() => setIndex(i)} className={cn("relative block w-full overflow-hidden rounded-lg ring-2 transition", i === index ? "ring-primary" : "ring-transparent hover:ring-border")}>
                <SlideView slide={s} theme={content.theme} />
                {(watchers.get(s.id) ?? []).length > 0 && (
                  <span className="absolute bottom-1 right-1 flex -space-x-1.5" title={(watchers.get(s.id) ?? []).map((v) => v.name).join(", ")}>
                    {(watchers.get(s.id) ?? []).slice(0, 3).map((v) => (
                      <span key={v.session} className="rounded-full ring-2" style={{ ["--tw-ring-color" as string]: v.color }}><Avatar name={v.name} src={v.avatar} size="xs" /></span>
                    ))}
                  </span>
                )}
              </button>
            </li>
          ))}
          {canEdit && (
            <li className="pl-6"><button onClick={() => addSlide("content")} className="grid aspect-video w-full place-items-center rounded-lg border-2 border-dashed border-border text-subtle hover:border-primary/40 hover:text-primary"><Plus className="h-5 w-5" /></button></li>
          )}
        </ol>
        <div className="min-w-0 flex-1">
          <div className="mx-auto max-w-[1100px] overflow-hidden rounded-xl shadow-[0_10px_40px_-12px_rgba(0,0,0,0.35)] ring-1 ring-border">
            <SlideView slide={slide} theme={content.theme} editable={canEdit} onChange={patchSlide} onImage={() => imageInput.current?.click()} />
          </div>
          <div className="mx-auto mt-4 max-w-[1100px]">
            <label className="mb-1 block text-xs font-medium text-muted">Notes de l&apos;orateur</label>
            <textarea value={slide.notes ?? ""} readOnly={!canEdit} onChange={(e) => patchSlide({ notes: e.target.value })} rows={3}
              placeholder="Points à dire pendant cette diapositive (non visibles en présentation)…"
              className="w-full rounded-xl border border-border bg-surface px-3 py-2 text-sm text-fg outline-none focus:border-primary" />
            <p className="mt-1 text-right text-xs text-subtle">Diapositive {index + 1} / {content.slides.length}</p>
          </div>
        </div>
      </div>

      {/* Impression / PDF : une diapositive par page */}
      <div className="hidden print:block">
        {content.slides.map((s) => (
          <div key={s.id} className="mb-4 break-after-page overflow-hidden"><SlideView slide={s} theme={content.theme} /></div>
        ))}
      </div>

      {presenting && <Presenter content={content} start={index} onClose={() => { setPresenting(false); if (document.fullscreenElement) document.exitFullscreen().catch(() => {}); }} />}
    </EditorShell>
  );
}

function IconBtn({ children, title, onClick }: { children: React.ReactElement; title: string; onClick: () => void }) {
  return <button type="button" title={title} aria-label={title} onClick={onClick} className="grid h-8 w-8 shrink-0 place-items-center rounded-md text-muted hover:bg-surface-2 hover:text-fg [&>svg]:h-4 [&>svg]:w-4">{children}</button>;
}

/** Rendu d'une diapositive 16:9 — toutes les tailles sont relatives à la largeur (unités cqw). */
export function SlideView({ slide: s, theme, editable, onChange, onImage }: { slide: Slide; theme: SlidesContent["theme"]; editable?: boolean; onChange?: (p: Partial<Slide>) => void; onImage?: () => void }) {
  const t = THEMES[theme] ?? THEMES.nuit;
  const field = (key: "title" | "subtitle" | "body" | "body2", cls: string, style: React.CSSProperties, opts?: { bullets?: boolean; placeholder?: string }) => (
    <Editable value={s[key] ?? ""} editable={editable} onChange={(v) => onChange?.({ [key]: v })} className={cls} style={style} bullets={opts?.bullets} placeholder={opts?.placeholder} accent={t.accent} />
  );
  return (
    <div className="@container relative aspect-video w-full select-none overflow-hidden" style={{ background: t.bg, containerType: "inline-size" }}>
      <div className="pointer-events-none absolute inset-0" style={{ background: t.glow }} />
      <div className="absolute inset-0" style={{ padding: "6cqw 7cqw" }}>
        {s.layout === "title" && (
          <div className="flex h-full flex-col justify-center" style={{ gap: "1.5cqw" }}>
            <div className="flex items-stretch" style={{ gap: "2cqw" }}>
              <span className="shrink-0 rounded-full" style={{ width: "0.7cqw", background: t.accent }} />
              <div className="min-w-0 flex-1">
                {field("title", "font-semibold leading-tight tracking-tight", { fontSize: "5.4cqw", color: t.title }, { placeholder: "Titre de la présentation" })}
                {field("subtitle", "mt-[1.2cqw]", { fontSize: "2.1cqw", color: t.muted }, { placeholder: "Sous-titre" })}
              </div>
            </div>
          </div>
        )}
        {s.layout === "section" && (
          <div className="flex h-full flex-col items-center justify-center text-center">
            <span className="rounded-full" style={{ width: "6cqw", height: "0.5cqw", background: t.accent, marginBottom: "2.5cqw" }} />
            {field("title", "font-semibold tracking-tight", { fontSize: "5cqw", color: t.title }, { placeholder: "Titre de section" })}
            {field("subtitle", "mt-[1.2cqw]", { fontSize: "2cqw", color: t.accent }, { placeholder: "Sous-titre" })}
          </div>
        )}
        {s.layout === "quote" && (
          <div className="flex h-full flex-col items-center justify-center text-center">
            <span className="font-serif leading-none" style={{ fontSize: "10cqw", color: t.accent, opacity: 0.6 }}>“</span>
            {field("body", "font-medium italic leading-snug", { fontSize: "3.4cqw", color: t.title }, { placeholder: "Votre citation" })}
            {field("title", "mt-[2cqw]", { fontSize: "1.8cqw", color: t.accent }, { placeholder: "— Auteur" })}
          </div>
        )}
        {(s.layout === "content" || s.layout === "two" || s.layout === "image") && (
          <div className="flex h-full flex-col">
            {field("title", "font-semibold tracking-tight", { fontSize: "3.6cqw", color: t.title }, { placeholder: "Titre" })}
            <span className="rounded-full" style={{ width: "5cqw", height: "0.4cqw", background: t.accent, margin: "1.6cqw 0 2.6cqw" }} />
            <div className="flex min-h-0 flex-1" style={{ gap: "4cqw" }}>
              <div className="min-w-0 flex-1">{field("body", "", { fontSize: "2.2cqw", color: t.text, lineHeight: 1.55 }, { bullets: true, placeholder: "Un point par ligne" })}</div>
              {s.layout === "two" && <div className="min-w-0 flex-1">{field("body2", "", { fontSize: "2.2cqw", color: t.text, lineHeight: 1.55 }, { bullets: true, placeholder: "Un point par ligne" })}</div>}
              {s.layout === "image" && (
                <div className="relative min-w-0 flex-1 overflow-hidden rounded-[1cqw]" style={{ background: "rgba(127,127,127,.12)" }}>
                  {s.image ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={s.image} alt="" className="h-full w-full object-cover" />
                  ) : (
                    <button type="button" onClick={onImage} disabled={!editable} className="grid h-full w-full place-items-center" style={{ color: t.muted, fontSize: "1.6cqw" }}>
                      {editable ? "Cliquez pour ajouter une image" : ""}
                    </button>
                  )}
                  {editable && s.image && (
                    <button type="button" onClick={() => onChange?.({ image: null })} className="absolute right-[1cqw] top-[1cqw] grid place-items-center rounded-full bg-black/60 text-white" style={{ width: "3cqw", height: "3cqw" }} aria-label="Retirer l'image">
                      <X style={{ width: "1.6cqw", height: "1.6cqw" }} />
                    </button>
                  )}
                </div>
              )}
            </div>
          </div>
        )}
      </div>
      <span className="absolute font-semibold" style={{ right: "3cqw", bottom: "2.4cqw", fontSize: "1cqw", letterSpacing: "0.3em", color: t.muted }}>VERIION</span>
    </div>
  );
}

function Editable({
  value, editable, onChange, className, style, bullets, placeholder, accent,
}: { value: string; editable?: boolean; onChange: (v: string) => void; className: string; style: React.CSSProperties; bullets?: boolean; placeholder?: string; accent: string }) {
  const [editing, setEditing] = useState(false);
  const ref = useRef<HTMLTextAreaElement>(null);
  useEffect(() => {
    if (editing && ref.current) { ref.current.focus(); ref.current.style.height = "auto"; ref.current.style.height = ref.current.scrollHeight + "px"; }
  }, [editing]);

  if (editable && editing) {
    return (
      <textarea
        ref={ref}
        value={value}
        onChange={(e) => { onChange(e.target.value); e.target.style.height = "auto"; e.target.style.height = e.target.scrollHeight + "px"; }}
        onBlur={() => setEditing(false)}
        onKeyDown={(e) => { if (e.key === "Escape") setEditing(false); if (!bullets && e.key === "Enter") { e.preventDefault(); setEditing(false); } }}
        className={cn("block w-full resize-none overflow-hidden rounded-[0.4cqw] bg-white/5 outline outline-2 outline-offset-4 outline-indigo-400/70", className)}
        style={style}
        placeholder={placeholder}
      />
    );
  }
  const empty = !value.trim();
  return (
    <div onClick={() => editable && setEditing(true)} className={cn(className, editable && "cursor-text rounded-[0.4cqw] hover:outline hover:outline-1 hover:outline-offset-4 hover:outline-white/25")} style={style}>
      {empty ? (
        editable ? <span style={{ opacity: 0.4 }}>{placeholder}</span> : null
      ) : bullets ? (
        <ul style={{ display: "grid", gap: "0.9cqw" }}>
          {value.split("\n").filter((l) => l.trim()).map((l, i) => (
            <li key={i} className="flex" style={{ gap: "1.2cqw" }}>
              <span className="shrink-0 rounded-full" style={{ width: "0.7cqw", height: "0.7cqw", marginTop: "0.95cqw", background: accent }} />
              <span>{l.replace(/^[-•]\s*/, "")}</span>
            </li>
          ))}
        </ul>
      ) : (
        <span className="whitespace-pre-wrap">{value}</span>
      )}
    </div>
  );
}

function Presenter({ content, start, onClose }: { content: SlidesContent; start: number; onClose: () => void }) {
  const [i, setI] = useState(start);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (["ArrowRight", "ArrowDown", "PageDown", " ", "Enter"].includes(e.key)) { e.preventDefault(); setI((x) => Math.min(content.slides.length - 1, x + 1)); }
      if (["ArrowLeft", "ArrowUp", "PageUp", "Backspace"].includes(e.key)) { e.preventDefault(); setI((x) => Math.max(0, x - 1)); }
      if (e.key === "Escape") onClose();
      if (e.key === "Home") setI(0);
      if (e.key === "End") setI(content.slides.length - 1);
    };
    const onFs = () => { if (!document.fullscreenElement) onClose(); };
    window.addEventListener("keydown", onKey);
    document.addEventListener("fullscreenchange", onFs);
    return () => { window.removeEventListener("keydown", onKey); document.removeEventListener("fullscreenchange", onFs); };
  }, [content.slides.length, onClose]);
  return (
    <div className="fixed inset-0 z-[100] grid place-items-center bg-black" onClick={() => setI((x) => Math.min(content.slides.length - 1, x + 1))}>
      <div className="w-full max-w-[177.78vh]"><SlideView slide={content.slides[i]} theme={content.theme} /></div>
      <div className="absolute inset-x-0 bottom-0 h-1 bg-white/10"><div className="h-full bg-indigo-500 transition-all" style={{ width: `${((i + 1) / content.slides.length) * 100}%` }} /></div>
      <button onClick={(e) => { e.stopPropagation(); onClose(); }} className="absolute right-4 top-4 rounded-full bg-white/10 p-2 text-white opacity-40 hover:opacity-100" aria-label="Quitter"><X className="h-5 w-5" /></button>
      <span className="absolute bottom-4 right-6 text-xs text-white/40">{i + 1} / {content.slides.length}</span>
    </div>
  );
}
