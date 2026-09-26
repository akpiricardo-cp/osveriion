import type { ChatAttachment, Message, MessageReaction } from "@/lib/types";

export const QUICK_EMOJIS = ["👍", "❤️", "😂", "🎉", "✅", "👀", "🙏", "🔥"] as const;
export const MAX_CHAT_FILE = 25 * 1024 * 1024;

export type ChannelPerson = { id: string; full_name: string; avatar_url: string | null; job_title: string | null };

/** Jeton de rendu d'un message : texte brut, mention ou lien. */
export type Token = { t: "text"; v: string } | { t: "mention"; name: string; id: string } | { t: "link"; href: string };

const MENTION = /@\[([^\]]{1,80})\]\(([0-9a-fA-F-]{36})\)/g;
const URL_RE = /\bhttps?:\/\/[^\s<>()]+[^\s<>().,;:!?'"]/g;

export function tokenize(body: string): Token[] {
  const out: Token[] = [];
  let last = 0;
  for (const m of body.matchAll(MENTION)) {
    if (m.index! > last) pushText(out, body.slice(last, m.index));
    out.push({ t: "mention", name: m[1], id: m[2] });
    last = m.index! + m[0].length;
  }
  if (last < body.length) pushText(out, body.slice(last));
  return out;
}

function pushText(out: Token[], s: string) {
  let last = 0;
  for (const m of s.matchAll(URL_RE)) {
    if (m.index! > last) out.push({ t: "text", v: s.slice(last, m.index) });
    out.push({ t: "link", href: m[0] });
    last = m.index! + m[0].length;
  }
  if (last < s.length) out.push({ t: "text", v: s.slice(last) });
}

/** Texte lisible (aperçus, notifications, recherche) : @[Nom](id) → @Nom */
export function plainText(body: string) {
  return body.replace(MENTION, "@$1");
}

/**
 * Le champ de saisie affiche « @Prénom Nom » ; à l'envoi on encode les mentions
 * choisies dans l'autocomplétion au format stocké @[Nom](uuid).
 */
export function encodeMentions(text: string, picked: Map<string, string>) {
  let out = text;
  // les noms les plus longs d'abord pour éviter les recouvrements (« Awa » / « Awa Houngbo »)
  [...picked.entries()].sort((a, b) => b[0].length - a[0].length).forEach(([name, id]) => {
    const esc = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    out = out.replace(new RegExp(`(^|[^\\[\\w])@${esc}(?![\\w\\]])`, "g"), `$1@[${name}](${id})`);
  });
  return out;
}

/** Inverse de encodeMentions, pour modifier un message existant. */
export function decodeMentions(body: string) {
  const picked = new Map<string, string>();
  const text = body.replace(MENTION, (_, name: string, id: string) => { picked.set(name, id); return `@${name}`; });
  return { text, picked };
}

export function groupReactions(list: MessageReaction[], userId: string) {
  const by = new Map<string, Map<string, { count: number; mine: boolean; who: string[] }>>();
  for (const r of list) {
    let m = by.get(r.message_id);
    if (!m) by.set(r.message_id, (m = new Map()));
    const e = m.get(r.emoji) ?? { count: 0, mine: false, who: [] };
    e.count++;
    e.who.push(r.profile_id);
    if (r.profile_id === userId) e.mine = true;
    m.set(r.emoji, e);
  }
  return by;
}

export function fileAttachments(m: Pick<Message, "attachments">) {
  return (m.attachments ?? []).filter((a): a is Extract<ChatAttachment, { type: "file" }> => a.type === "file");
}

export function callAttachment(m: Pick<Message, "attachments">) {
  return (m.attachments ?? []).find((a): a is Extract<ChatAttachment, { type: "call" }> => a.type === "call") ?? null;
}

export function chatFileUrl(path: string, opts?: { download?: boolean; name?: string }) {
  const q = new URLSearchParams();
  if (opts?.download) q.set("telecharger", "1");
  if (opts?.name) q.set("nom", opts.name);
  const qs = q.toString();
  return `/api/storage/chat/${path.split("/").map(encodeURIComponent).join("/")}${qs ? `?${qs}` : ""}`;
}

/** Adresse d'une salle de visioconférence propre à la conversation. */
export function callRoomUrl(channelId: string) {
  const base = (process.env.NEXT_PUBLIC_MEET_BASE_URL || "https://meet.jit.si/veriion").replace(/\/+$/, "");
  const suffix = `${channelId.slice(0, 8)}-${Math.random().toString(36).slice(2, 8)}`;
  // meet.jit.si/veriion → meet.jit.si/veriion-xxxx ; https://visio.exemple.com → https://visio.exemple.com/xxxx
  return /\/[^/]+$/.test(base.replace(/^https:\/\/[^/]+/, "")) ? `${base}-${suffix}` : `${base}/veriion-${suffix}`;
}
