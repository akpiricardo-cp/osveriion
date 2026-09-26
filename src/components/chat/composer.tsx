"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { AtSign, FileIcon, Loader2, Paperclip, SendHorizontal, X } from "lucide-react";
import { toast } from "sonner";
import { createClient } from "@/lib/supabase/client";
import { Avatar } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { humanSize, safeFileName } from "@/lib/drive";
import { decodeMentions, encodeMentions, MAX_CHAT_FILE, type ChannelPerson } from "@/lib/chat";
import type { ChatAttachment, Message } from "@/lib/types";
import { cn } from "@/lib/utils";

type Pending = { key: string; file: File; preview?: string };

const norm = (s: string) => s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();

export function Composer({
  channelId, parentId, userId, people, placeholder, editing, onCancelEdit, onSent, onTyping, autoFocus, compact,
}: {
  channelId: string;
  parentId?: string | null;
  userId: string;
  people: ChannelPerson[];
  placeholder: string;
  editing?: Message | null;
  onCancelEdit?: () => void;
  onSent?: (m: Message) => void;
  onTyping?: () => void;
  autoFocus?: boolean;
  compact?: boolean;
}) {
  const [text, setText] = useState("");
  const [files, setFiles] = useState<Pending[]>([]);
  const [sending, setSending] = useState(false);
  const [mention, setMention] = useState<{ q: string; start: number } | null>(null);
  const [hi, setHi] = useState(0);
  const picked = useRef(new Map<string, string>());
  const area = useRef<HTMLTextAreaElement>(null);
  const fileInput = useRef<HTMLInputElement>(null);
  const draftKey = `vrn-draft:${channelId}:${parentId ?? "root"}`;

  // Brouillon conservé par conversation (confort local, facultatif)
  useEffect(() => {
    if (editing) return;
    try { const d = localStorage.getItem(draftKey); if (d) setText(d); } catch { /* stockage indisponible */ }
  }, [draftKey, editing]);
  useEffect(() => {
    if (editing) return;
    try { if (text) localStorage.setItem(draftKey, text); else localStorage.removeItem(draftKey); } catch { /* stockage indisponible */ }
  }, [text, draftKey, editing]);

  useEffect(() => {
    if (!editing) return;
    const d = decodeMentions(editing.body);
    picked.current = d.picked;
    setText(d.text);
    requestAnimationFrame(() => { area.current?.focus(); area.current?.setSelectionRange(d.text.length, d.text.length); });
  }, [editing]);

  // Hauteur automatique
  useEffect(() => {
    const el = area.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = `${Math.min(el.scrollHeight, 200)}px`;
  }, [text]);

  useEffect(() => () => files.forEach((f) => f.preview && URL.revokeObjectURL(f.preview)), [files]);

  const suggestions = useMemo(() => {
    if (!mention) return [];
    const q = norm(mention.q);
    return people.filter((p) => p.id !== userId && norm(p.full_name).includes(q)).slice(0, 6);
  }, [mention, people, userId]);

  function detectMention(value: string, caret: number) {
    const before = value.slice(0, caret);
    const m = /(^|\s)@([^\s@]{0,30}(?: [^\s@]{0,30})?)$/.exec(before);
    if (m) { setMention({ q: m[2], start: caret - m[2].length - 1 }); setHi(0); } else setMention(null);
  }

  function pick(p: ChannelPerson) {
    if (!mention || !area.current) return;
    const caret = area.current.selectionStart;
    const next = `${text.slice(0, mention.start)}@${p.full_name} ${text.slice(caret)}`;
    picked.current.set(p.full_name, p.id);
    setText(next);
    setMention(null);
    const pos = mention.start + p.full_name.length + 2;
    requestAnimationFrame(() => { area.current?.focus(); area.current?.setSelectionRange(pos, pos); });
  }

  function addFiles(list: FileList | File[]) {
    const arr = Array.from(list);
    const tooBig = arr.filter((f) => f.size > MAX_CHAT_FILE);
    if (tooBig.length) toast.error(`${tooBig.map((f) => f.name).join(", ")} : 25 Mo maximum par fichier.`);
    const ok = arr.filter((f) => f.size <= MAX_CHAT_FILE).slice(0, 10 - files.length);
    setFiles((prev) => [...prev, ...ok.map((file) => ({ key: crypto.randomUUID(), file, preview: file.type.startsWith("image/") ? URL.createObjectURL(file) : undefined }))]);
  }

  async function send() {
    const raw = text.trim();
    if ((!raw && !files.length) || sending) return;
    setSending(true);
    const supabase = createClient();
    const body = encodeMentions(raw, picked.current);
    try {
      if (editing) {
        const { error } = await supabase.from("messages").update({ body, edited_at: new Date().toISOString() }).eq("id", editing.id);
        if (error) throw new Error("Modification impossible.");
        onCancelEdit?.();
      } else {
        const attachments: ChatAttachment[] = [];
        for (const p of files) {
          const path = `${channelId}/${crypto.randomUUID()}/${safeFileName(p.file.name)}`;
          const { error } = await supabase.storage.from("chat").upload(path, p.file, { contentType: p.file.type || "application/octet-stream" });
          if (error) throw new Error(`Envoi de « ${p.file.name} » impossible : ${error.message}`);
          attachments.push({ type: "file", path, name: p.file.name, size: p.file.size, mime: p.file.type || "application/octet-stream" });
        }
        const { data, error } = await supabase.from("messages")
          .insert({ channel_id: channelId, parent_id: parentId ?? null, body, author_id: userId, attachments })
          .select("*").single();
        if (error) throw new Error(error.message);
        onSent?.(data as Message);
      }
      setText("");
      setFiles([]);
      picked.current = new Map();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Envoi impossible.");
    } finally {
      setSending(false);
    }
  }

  return (
    <div
      className={cn("shrink-0 border-t border-border bg-surface", compact ? "px-3 py-2.5" : "px-4 py-3 sm:px-6")}
      onDragOver={(e) => { if (e.dataTransfer.types.includes("Files") && !editing) e.preventDefault(); }}
      onDrop={(e) => { if (e.dataTransfer.files?.length && !editing) { e.preventDefault(); addFiles(e.dataTransfer.files); } }}
    >
      {editing && (
        <div className="mb-2 flex items-center justify-between rounded-lg bg-amber-500/10 px-3 py-1.5 text-xs text-amber-700 dark:text-amber-300">
          Modification du message
          <button type="button" onClick={() => { setText(""); onCancelEdit?.(); }} className="font-medium hover:underline">Annuler</button>
        </div>
      )}

      <div className="relative rounded-xl border border-border bg-surface-2/50 focus-within:border-primary focus-within:ring-4 focus-within:ring-primary/10">
        {mention && suggestions.length > 0 && (
          <div className="absolute bottom-full left-2 z-30 mb-2 w-72 overflow-hidden rounded-xl border border-border bg-surface p-1 shadow-lg" role="listbox" aria-label="Mentionner">
            <p className="px-2.5 py-1.5 text-[11px] font-medium uppercase tracking-wider text-subtle">Mentionner</p>
            {suggestions.map((p, i) => (
              <button key={p.id} type="button" role="option" aria-selected={i === hi}
                onMouseDown={(e) => { e.preventDefault(); pick(p); }} onMouseEnter={() => setHi(i)}
                className={cn("flex w-full items-center gap-2.5 rounded-lg px-2.5 py-1.5 text-left", i === hi ? "bg-primary/10" : "hover:bg-surface-2")}>
                <Avatar name={p.full_name} src={p.avatar_url} size="xs" />
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-sm font-medium text-fg">{p.full_name}</span>
                  {p.job_title && <span className="block truncate text-[11px] text-subtle">{p.job_title}</span>}
                </span>
              </button>
            ))}
          </div>
        )}

        {files.length > 0 && (
          <div className="flex flex-wrap gap-2 border-b border-border/70 p-2">
            {files.map((p) => (
              <div key={p.key} className="group relative flex max-w-[220px] items-center gap-2 rounded-lg border border-border bg-surface p-1.5 pr-7">
                {p.preview ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={p.preview} alt="" className="h-10 w-10 rounded-md object-cover" />
                ) : (
                  <span className="grid h-10 w-10 place-items-center rounded-md bg-surface-2 text-subtle"><FileIcon className="h-5 w-5" /></span>
                )}
                <span className="min-w-0">
                  <span className="block truncate text-xs font-medium text-fg">{p.file.name}</span>
                  <span className="block text-[11px] text-subtle">{humanSize(p.file.size)}</span>
                </span>
                <button type="button" onClick={() => setFiles((f) => f.filter((x) => x.key !== p.key))} aria-label={`Retirer ${p.file.name}`}
                  className="absolute right-1 top-1 rounded-full p-0.5 text-subtle hover:bg-surface-2 hover:text-fg"><X className="h-3.5 w-3.5" /></button>
              </div>
            ))}
          </div>
        )}

        <div className="flex items-end gap-1 p-2">
          {!editing && (
            <>
              <button type="button" onClick={() => fileInput.current?.click()} className="grid h-9 w-9 shrink-0 place-items-center rounded-lg text-muted hover:bg-surface hover:text-fg" aria-label="Joindre des fichiers" title="Joindre des fichiers (25 Mo max.)">
                <Paperclip className="h-4 w-4" />
              </button>
              <input ref={fileInput} type="file" multiple className="hidden" onChange={(e) => { if (e.target.files) addFiles(e.target.files); e.target.value = ""; }} />
            </>
          )}
          <textarea
            ref={area}
            value={text}
            autoFocus={autoFocus}
            onChange={(e) => { setText(e.target.value); detectMention(e.target.value, e.target.selectionStart); onTyping?.(); }}
            onClick={(e) => detectMention(text, e.currentTarget.selectionStart)}
            onPaste={(e) => {
              const imgs = Array.from(e.clipboardData.files ?? []);
              if (imgs.length && !editing) { e.preventDefault(); addFiles(imgs); }
            }}
            onKeyDown={(e) => {
              if (mention && suggestions.length) {
                if (e.key === "ArrowDown") { e.preventDefault(); setHi((h) => (h + 1) % suggestions.length); return; }
                if (e.key === "ArrowUp") { e.preventDefault(); setHi((h) => (h - 1 + suggestions.length) % suggestions.length); return; }
                if (e.key === "Enter" || e.key === "Tab") { e.preventDefault(); pick(suggestions[hi]); return; }
                if (e.key === "Escape") { e.preventDefault(); setMention(null); return; }
              }
              if (e.key === "Escape" && editing) { setText(""); onCancelEdit?.(); return; }
              if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) { e.preventDefault(); send(); }
            }}
            rows={1}
            placeholder={placeholder}
            aria-label="Message"
            className="max-h-[200px] min-h-[36px] flex-1 resize-none bg-transparent px-2 py-2 text-sm text-fg outline-none placeholder:text-subtle"
          />
          <button type="button" onClick={() => {
            const el = area.current; if (!el) return;
            const pos = el.selectionStart; const pre = text.slice(0, pos); const add = pre && !/\s$/.test(pre) ? " @" : "@";
            const next = pre + add + text.slice(pos); setText(next);
            requestAnimationFrame(() => { el.focus(); el.setSelectionRange(pos + add.length, pos + add.length); detectMention(next, pos + add.length); });
          }} className="grid h-9 w-9 shrink-0 place-items-center rounded-lg text-muted hover:bg-surface hover:text-fg" aria-label="Mentionner quelqu'un" title="Mentionner quelqu'un">
            <AtSign className="h-4 w-4" />
          </button>
          <Button type="button" size="icon" onClick={send} disabled={(!text.trim() && !files.length) || sending} aria-label={editing ? "Enregistrer" : "Envoyer"}>
            {sending ? <Loader2 className="h-4 w-4 animate-spin" /> : <SendHorizontal className="h-4 w-4" />}
          </Button>
        </div>
      </div>
      {!compact && <p className="mt-1.5 px-1 text-[11px] text-subtle">Entrée pour envoyer · Maj + Entrée pour un saut de ligne · @ pour mentionner · glissez-déposez ou collez des fichiers</p>}
    </div>
  );
}
