"use client";

import { useState } from "react";
import Link from "next/link";
import { Copy, Download, FileText, MessageSquareReply, MoreHorizontal, Pencil, Pin, PinOff, SmilePlus, Trash2, Video } from "lucide-react";
import { toast } from "sonner";
import { Avatar } from "@/components/ui/avatar";
import { Dropdown, DropdownContent, DropdownItem, DropdownSeparator, DropdownTrigger } from "@/components/ui/dropdown";
import { humanSize } from "@/lib/drive";
import { callAttachment, chatFileUrl, fileAttachments, QUICK_EMOJIS, tokenize } from "@/lib/chat";
import type { Message, ProfileLite } from "@/lib/types";
import { chatTime, cn, dateTimeFr, relative } from "@/lib/utils";

export type ReactionSummary = Map<string, { count: number; mine: boolean; who: string[] }>;

export function MessageItem({
  m, grouped, userId, people, reactions, highlight, inThread,
  onReact, onReply, onPin, onEdit, onDelete,
}: {
  m: Message;
  grouped: boolean;
  userId: string;
  people: Map<string, ProfileLite>;
  reactions?: ReactionSummary;
  highlight?: boolean;
  inThread?: boolean;
  onReact: (m: Message, emoji: string) => void;
  onReply?: (m: Message) => void;
  onPin: (m: Message) => void;
  onEdit: (m: Message) => void;
  onDelete: (m: Message) => void;
}) {
  const [picker, setPicker] = useState(false);
  const author = m.author_id ? people.get(m.author_id) : null;
  const mine = m.author_id === userId;
  const files = fileAttachments(m);
  const call = callAttachment(m);
  const images = files.filter((f) => f.mime.startsWith("image/"));
  const others = files.filter((f) => !f.mime.startsWith("image/"));
  const deleted = !!m.deleted_at;

  const copyLink = () => {
    const url = `${window.location.origin}/messages/${m.channel_id}?${m.parent_id ? `fil=${m.parent_id}&` : ""}m=${m.id}`;
    navigator.clipboard.writeText(url).then(() => toast.success("Lien copié."), () => toast.error("Copie impossible."));
  };

  return (
    <div id={`m-${m.id}`} className={cn(
      "group relative flex gap-3 rounded-lg px-2 py-0.5 transition-colors hover:bg-surface-2/60",
      !grouped && "mt-3",
      m.pinned_at && !deleted && "bg-amber-500/[0.06]",
      highlight && "bg-primary/10 ring-1 ring-primary/30",
    )}>
      <div className="w-9 shrink-0 pt-0.5">
        {!grouped ? (
          author ? <Link href={`/annuaire/${author.id}`}><Avatar name={author.full_name} src={author.avatar_url} size="sm" /></Link> : <Avatar name="?" size="sm" />
        ) : (
          <span className="invisible block pt-1 text-right text-[10px] text-subtle group-hover:visible" title={dateTimeFr(m.created_at)}>{chatTime(m.created_at).replace(/^.* /, "")}</span>
        )}
      </div>
      <div className="min-w-0 flex-1 pb-0.5">
        {!grouped && (
          <p className="flex flex-wrap items-baseline gap-x-2 text-[13px]">
            {author ? <Link href={`/annuaire/${author.id}`} className="font-semibold text-fg hover:underline">{author.full_name}</Link> : <span className="font-semibold text-fg">Ancien membre</span>}
            <span className="text-[11px] text-subtle" title={dateTimeFr(m.created_at)}>{chatTime(m.created_at)}</span>
            {m.pinned_at && !deleted && <span className="inline-flex items-center gap-0.5 text-[11px] font-medium text-amber-600 dark:text-amber-400"><Pin className="h-3 w-3" /> Épinglé</span>}
          </p>
        )}

        {deleted ? (
          <p className="text-sm italic text-subtle">Message supprimé</p>
        ) : m.kind === "call" && call ? (
          <div className="mt-1 flex max-w-md items-center gap-3 rounded-xl border border-border bg-surface p-3 shadow-xs">
            <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-emerald-500/15 text-emerald-600"><Video className="h-5 w-5" /></span>
            <div className="min-w-0 flex-1">
              <p className="text-sm font-medium text-fg">Appel vidéo</p>
              <p className="truncate text-xs text-subtle">{author?.full_name ?? "Quelqu'un"} a lancé un appel · {relative(m.created_at)}</p>
            </div>
            <a href={call.url} target="_blank" rel="noopener noreferrer" className="rounded-lg bg-emerald-600 px-3 py-1.5 text-[13px] font-medium text-white hover:bg-emerald-700">Rejoindre</a>
          </div>
        ) : (
          <>
            {m.body && (
              <p className="whitespace-pre-wrap break-words text-[14px] leading-relaxed text-fg">
                {tokenize(m.body).map((t, i) =>
                  t.t === "text" ? <span key={i}>{t.v}</span>
                  : t.t === "link" ? <a key={i} href={t.href} target="_blank" rel="noopener noreferrer" className="text-primary underline-offset-2 hover:underline">{t.href}</a>
                  : <Link key={i} href={`/annuaire/${t.id}`} className={cn("rounded px-1 font-medium", t.id === userId ? "bg-amber-400/25 text-amber-800 dark:text-amber-200" : "bg-primary/10 text-primary")}>@{t.name}</Link>,
                )}
                {m.edited_at && <span className="ml-1 text-[11px] text-subtle">(modifié)</span>}
              </p>
            )}
            {images.length === 1 && (
              <a href={chatFileUrl(images[0].path)} target="_blank" rel="noopener noreferrer" className="mt-1.5 inline-block max-w-full overflow-hidden rounded-lg border border-border bg-surface-2">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={chatFileUrl(images[0].path)} alt={images[0].name} loading="lazy" className="block max-h-80 w-auto max-w-full sm:max-w-md" />
              </a>
            )}
            {images.length > 1 && (
              <div className="mt-1.5 grid max-w-md grid-cols-2 gap-1.5">
                {images.map((f) => (
                  <a key={f.path} href={chatFileUrl(f.path)} target="_blank" rel="noopener noreferrer" className="block aspect-square overflow-hidden rounded-lg border border-border bg-surface-2">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={chatFileUrl(f.path)} alt={f.name} loading="lazy" className="h-full w-full object-cover" />
                  </a>
                ))}
              </div>
            )}
            {others.length > 0 && (
              <div className="mt-1.5 flex flex-wrap gap-2">
                {others.map((f) => (
                  <div key={f.path} className="flex w-72 max-w-full items-center gap-3 rounded-xl border border-border bg-surface p-2.5">
                    <span className="grid h-10 w-10 shrink-0 place-items-center rounded-lg bg-primary/10 text-primary"><FileText className="h-5 w-5" /></span>
                    <a href={chatFileUrl(f.path)} target="_blank" rel="noopener noreferrer" className="min-w-0 flex-1">
                      <span className="block truncate text-sm font-medium text-fg hover:underline">{f.name}</span>
                      <span className="block text-[11px] text-subtle">{humanSize(f.size)}</span>
                    </a>
                    <a href={chatFileUrl(f.path, { download: true, name: f.name })} className="rounded-md p-1.5 text-subtle hover:bg-surface-2 hover:text-fg" aria-label={`Télécharger ${f.name}`}><Download className="h-4 w-4" /></a>
                  </div>
                ))}
              </div>
            )}
          </>
        )}

        {reactions && reactions.size > 0 && !deleted && (
          <div className="mt-1.5 flex flex-wrap gap-1">
            {[...reactions.entries()].map(([emoji, r]) => (
              <button key={emoji} onClick={() => onReact(m, emoji)}
                title={r.who.map((id) => people.get(id)?.full_name ?? "?").join(", ")}
                className={cn("flex h-6 items-center gap-1 rounded-full border px-2 text-xs transition",
                  r.mine ? "border-primary/40 bg-primary/10 text-primary" : "border-border bg-surface text-muted hover:border-primary/30")}>
                <span className="text-[13px] leading-none">{emoji}</span><span className="font-medium">{r.count}</span>
              </button>
            ))}
          </div>
        )}

        {!inThread && m.reply_count > 0 && onReply && !deleted && (
          <button onClick={() => onReply(m)} className="mt-1.5 flex items-center gap-2 rounded-md px-1 py-0.5 text-xs hover:bg-surface">
            <span className="font-semibold text-primary">{m.reply_count} réponse{m.reply_count > 1 ? "s" : ""}</span>
            {m.last_reply_at && <span className="text-subtle">Dernière {relative(m.last_reply_at)}</span>}
          </button>
        )}
      </div>

      {!deleted && m.kind !== "system" && (
        <div className={cn("absolute -top-3 right-2 z-10 flex items-center gap-0.5 rounded-lg border border-border bg-surface p-0.5 shadow-sm",
          picker ? "opacity-100" : "opacity-0 group-hover:opacity-100 focus-within:opacity-100")}>
          {QUICK_EMOJIS.slice(0, 3).map((e) => (
            <button key={e} onClick={() => onReact(m, e)} className="grid h-7 w-7 place-items-center rounded-md text-[15px] hover:bg-surface-2" aria-label={`Réagir ${e}`}>{e}</button>
          ))}
          <div className="relative">
            <button onClick={() => setPicker((v) => !v)} className="grid h-7 w-7 place-items-center rounded-md text-muted hover:bg-surface-2 hover:text-fg" aria-label="Ajouter une réaction"><SmilePlus className="h-4 w-4" /></button>
            {picker && (
              <div className="absolute right-0 top-8 z-20 grid grid-cols-4 gap-0.5 rounded-xl border border-border bg-surface p-1.5 shadow-lg" onMouseLeave={() => setPicker(false)}>
                {QUICK_EMOJIS.map((e) => (
                  <button key={e} onClick={() => { onReact(m, e); setPicker(false); }} className="grid h-8 w-8 place-items-center rounded-md text-lg hover:bg-surface-2">{e}</button>
                ))}
              </div>
            )}
          </div>
          {!inThread && onReply && (
            <button onClick={() => onReply(m)} className="grid h-7 w-7 place-items-center rounded-md text-muted hover:bg-surface-2 hover:text-fg" aria-label="Répondre dans un fil" title="Répondre dans un fil"><MessageSquareReply className="h-4 w-4" /></button>
          )}
          <Dropdown>
            <DropdownTrigger className="grid h-7 w-7 place-items-center rounded-md text-muted hover:bg-surface-2 hover:text-fg" aria-label="Plus d'actions"><MoreHorizontal className="h-4 w-4" /></DropdownTrigger>
            <DropdownContent align="end" className="w-52">
              {!m.parent_id && (
                <DropdownItem onSelect={() => onPin(m)}>{m.pinned_at ? <><PinOff className="h-4 w-4 text-subtle" /> Désépingler</> : <><Pin className="h-4 w-4 text-subtle" /> Épingler</>}</DropdownItem>
              )}
              <DropdownItem onSelect={copyLink}><Copy className="h-4 w-4 text-subtle" /> Copier le lien</DropdownItem>
              {mine && m.kind === "text" && (
                <>
                  <DropdownSeparator />
                  <DropdownItem onSelect={() => onEdit(m)}><Pencil className="h-4 w-4 text-subtle" /> Modifier</DropdownItem>
                  <DropdownItem danger onSelect={() => onDelete(m)}><Trash2 className="h-4 w-4" /> Supprimer</DropdownItem>
                </>
              )}
            </DropdownContent>
          </Dropdown>
        </div>
      )}
    </div>
  );
}

/** Séparateur de jour + regroupement des messages consécutifs d'un même auteur. */
export function isGrouped(prev: Message | undefined, m: Message) {
  if (!prev) return false;
  if (prev.created_at.slice(0, 10) !== m.created_at.slice(0, 10)) return false;
  if (prev.kind !== "text" || m.kind !== "text") return false;
  return prev.author_id === m.author_id && new Date(m.created_at).getTime() - new Date(prev.created_at).getTime() < 5 * 60000;
}
