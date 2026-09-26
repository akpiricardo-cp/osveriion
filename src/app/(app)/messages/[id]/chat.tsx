"use client";

import { Fragment, useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { ArrowLeft, Building2, FolderKanban, Hash, Loader2, Lock, LogOut, MessageSquare, Pin, Search, UserPlus, Users, Video, X } from "lucide-react";
import { toast } from "sonner";
import { createClient } from "@/lib/supabase/client";
import { Avatar } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { Checkbox, Input } from "@/components/ui/input";
import { Composer } from "@/components/chat/composer";
import { isGrouped, MessageItem } from "@/components/chat/message-item";
import { callRoomUrl, groupReactions, plainText, type ChannelPerson } from "@/lib/chat";
import type { ChannelSummary, Message, MessageReaction, ProfileLite } from "@/lib/types";
import { chatTime, cn, dateFr } from "@/lib/utils";
import { addChannelMembers, leaveChannel } from "../actions";
import { openDirectMessage } from "../../annuaire/actions";

type Panel = "thread" | "pinned" | "search" | "members" | null;
type SearchHit = { id: string; channel_id: string; author_id: string | null; body: string; created_at: string; parent_id: string | null };

export function Chat({
  channel, initial, initialReactions, hasMoreInitial, people, channelPeople, userId, userName, members, pinnedCount, initialThread, focusId,
}: {
  channel: ChannelSummary;
  initial: Message[];
  initialReactions: MessageReaction[];
  hasMoreInitial: boolean;
  people: ProfileLite[];
  channelPeople: ChannelPerson[];
  userId: string;
  userName: string;
  members: { profile_id: string; role: string }[];
  pinnedCount: number;
  initialThread: string | null;
  focusId: string | null;
}) {
  const router = useRouter();
  const [messages, setMessages] = useState<Message[]>(initial);
  const [reactions, setReactions] = useState<MessageReaction[]>(initialReactions);
  const [editing, setEditing] = useState<Message | null>(null);
  const [loadingOlder, setLoadingOlder] = useState(false);
  const [hasMore, setHasMore] = useState(hasMoreInitial);
  const [panel, setPanel] = useState<Panel>(initialThread ? "thread" : null);
  const [threadId, setThreadId] = useState<string | null>(initialThread);
  const [threadMsgs, setThreadMsgs] = useState<Message[]>([]);
  const [threadRoot, setThreadRoot] = useState<Message | null>(null);
  const [threadLoading, setThreadLoading] = useState(false);
  const [threadEditing, setThreadEditing] = useState<Message | null>(null);
  const [pinned, setPinned] = useState(pinnedCount);
  const [highlight, setHighlight] = useState<string | null>(focusId);
  const [typing, setTyping] = useState<Record<string, { name: string; at: number }>>({});
  const [calling, setCalling] = useState(false);
  const scroller = useRef<HTMLDivElement>(null);
  const threadScroller = useRef<HTMLDivElement>(null);
  const stick = useRef(!focusId);
  const rt = useRef<RealtimeChannel | null>(null);
  const lastTyping = useRef(0);
  const lastTop = useRef(0);
  const threadRef = useRef(threadId);
  threadRef.current = threadId;

  const pm = useMemo(() => new Map(people.map((p) => [p.id, p])), [people]);
  const reactionMap = useMemo(() => groupReactions(reactions, userId), [reactions, userId]);

  // ── Défilement ────────────────────────────────────────────────────────────
  useLayoutEffect(() => {
    if (stick.current && scroller.current) scroller.current.scrollTop = scroller.current.scrollHeight;
  }, [messages]);
  // Les images se chargent après le rendu : on reste collé en bas tant que l'utilisateur n'a pas remonté
  const content = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = content.current;
    if (!el || typeof ResizeObserver === "undefined") return;
    const ro = new ResizeObserver(() => { if (stick.current && scroller.current) scroller.current.scrollTop = scroller.current.scrollHeight; });
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  useLayoutEffect(() => {
    if (threadScroller.current) threadScroller.current.scrollTop = threadScroller.current.scrollHeight;
  }, [threadMsgs.length]);
  useEffect(() => {
    if (!focusId) return;
    const el = document.getElementById(`m-${focusId}`);
    el?.scrollIntoView({ block: "center" });
    const t = setTimeout(() => setHighlight(null), 4000);
    return () => clearTimeout(t);
  }, [focusId]);

  // ── Fil de discussion ─────────────────────────────────────────────────────
  const loadThread = useCallback(async (id: string) => {
    setThreadLoading(true);
    const supabase = createClient();
    const [{ data: root }, { data: replies }] = await Promise.all([
      supabase.from("messages").select("*").eq("id", id).maybeSingle(),
      supabase.from("messages").select("*").eq("parent_id", id).order("created_at").limit(500),
    ]);
    setThreadRoot((root as Message) ?? null);
    setThreadMsgs((replies as Message[]) ?? []);
    const ids = [id, ...((replies as Message[]) ?? []).map((r) => r.id)];
    const { data: rx } = await supabase.from("message_reactions").select("message_id, profile_id, emoji").in("message_id", ids);
    setReactions((prev) => [...prev.filter((r) => !ids.includes(r.message_id)), ...((rx as MessageReaction[]) ?? [])]);
    setThreadLoading(false);
  }, []);

  useEffect(() => { if (threadId) loadThread(threadId); }, [threadId, loadThread]);

  const openThread = (m: Message) => {
    setThreadId(m.id);
    setPanel("thread");
    window.history.replaceState(null, "", `/messages/${channel.id}?fil=${m.id}`);
  };
  const closePanel = () => {
    setPanel(null);
    if (threadId) { setThreadId(null); setThreadMsgs([]); setThreadRoot(null); window.history.replaceState(null, "", `/messages/${channel.id}`); }
  };

  // ── Temps réel ────────────────────────────────────────────────────────────
  useEffect(() => {
    const supabase = createClient();
    const upsert = (list: Message[], m: Message) => (list.some((x) => x.id === m.id) ? list.map((x) => (x.id === m.id ? m : x)) : [...list, m]);
    const ch = supabase
      .channel(`chat-${channel.id}`, { config: { broadcast: { self: false } } })
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "messages", filter: `channel_id=eq.${channel.id}` }, (payload) => {
        const m = payload.new as Message;
        if (!m.parent_id) setMessages((prev) => upsert(prev, m));
        else if (m.parent_id === threadRef.current) setThreadMsgs((prev) => upsert(prev, m));
        if (m.author_id) setTyping((t) => { const n = { ...t }; delete n[m.author_id!]; return n; });
        supabase.rpc("mark_channel_read", { p_channel: channel.id });
      })
      .on("postgres_changes", { event: "UPDATE", schema: "public", table: "messages", filter: `channel_id=eq.${channel.id}` }, (payload) => {
        const m = payload.new as Message;
        setMessages((prev) => prev.map((x) => (x.id === m.id ? m : x)));
        setThreadMsgs((prev) => prev.map((x) => (x.id === m.id ? m : x)));
        setThreadRoot((r) => (r?.id === m.id ? m : r));
      })
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "message_reactions", filter: `channel_id=eq.${channel.id}` }, (payload) => {
        const r = payload.new as MessageReaction;
        setReactions((prev) => (prev.some((x) => x.message_id === r.message_id && x.profile_id === r.profile_id && x.emoji === r.emoji) ? prev : [...prev, r]));
      })
      .on("postgres_changes", { event: "DELETE", schema: "public", table: "message_reactions" }, (payload) => {
        const r = payload.old as Partial<MessageReaction>;
        if (!r.message_id) return;
        setReactions((prev) => prev.filter((x) => !(x.message_id === r.message_id && x.profile_id === r.profile_id && x.emoji === r.emoji)));
      })
      .on("broadcast", { event: "typing" }, ({ payload }) => {
        const p = payload as { id: string; name: string };
        if (p.id === userId) return;
        setTyping((t) => ({ ...t, [p.id]: { name: p.name, at: Date.now() } }));
      })
      .subscribe();
    rt.current = ch;
    return () => { supabase.removeChannel(ch); rt.current = null; };
  }, [channel.id, userId]);

  // Les indicateurs « est en train d'écrire » expirent après 4 s
  useEffect(() => {
    if (!Object.keys(typing).length) return;
    const t = setInterval(() => setTyping((cur) => {
      const n = Object.fromEntries(Object.entries(cur).filter(([, v]) => Date.now() - v.at < 4000));
      return Object.keys(n).length === Object.keys(cur).length ? cur : n;
    }), 1000);
    return () => clearInterval(t);
  }, [typing]);

  const notifyTyping = () => {
    if (Date.now() - lastTyping.current < 2500) return;
    lastTyping.current = Date.now();
    rt.current?.send({ type: "broadcast", event: "typing", payload: { id: userId, name: userName } });
  };

  // ── Actions ───────────────────────────────────────────────────────────────
  const react = async (m: Message, emoji: string) => {
    const supabase = createClient();
    const mine = reactions.some((r) => r.message_id === m.id && r.profile_id === userId && r.emoji === emoji);
    if (mine) {
      setReactions((prev) => prev.filter((r) => !(r.message_id === m.id && r.profile_id === userId && r.emoji === emoji)));
      const { error } = await supabase.from("message_reactions").delete().match({ message_id: m.id, profile_id: userId, emoji });
      if (error) toast.error("Impossible de retirer la réaction.");
    } else {
      setReactions((prev) => [...prev, { message_id: m.id, profile_id: userId, emoji }]);
      const { error } = await supabase.from("message_reactions").insert({ message_id: m.id, profile_id: userId, emoji, channel_id: channel.id });
      if (error && error.code !== "23505") toast.error("Impossible d'ajouter la réaction.");
    }
  };

  const pin = async (m: Message) => {
    const { data, error } = await createClient().rpc("toggle_pin", { p_message: m.id });
    if (error) return toast.error("Action impossible.");
    const now = data ? new Date().toISOString() : null;
    const patch = (x: Message) => (x.id === m.id ? { ...x, pinned_at: now, pinned_by: now ? userId : null } : x);
    setMessages((prev) => prev.map(patch));
    setThreadRoot((r) => (r ? patch(r) : r));
    setPinned((n) => n + (data ? 1 : -1));
    toast.success(data ? "Message épinglé." : "Message désépinglé.");
  };

  const remove = async (m: Message) => {
    if (!confirm("Supprimer ce message ?")) return;
    const deleted_at = new Date().toISOString();
    const { error } = await createClient().from("messages").update({ deleted_at }).eq("id", m.id);
    if (error) return toast.error("Suppression impossible.");
    const patch = (x: Message) => (x.id === m.id ? { ...x, deleted_at } : x);
    setMessages((prev) => prev.map(patch));
    setThreadMsgs((prev) => prev.map(patch));
  };

  const startCall = async () => {
    setCalling(true);
    const url = callRoomUrl(channel.id);
    const { error } = await createClient().rpc("start_call", { p_channel: channel.id, p_url: url });
    setCalling(false);
    if (error) return toast.error("Impossible de lancer l'appel.");
    window.open(url, "_blank", "noopener,noreferrer");
  };

  async function loadOlder() {
    if (!messages.length) return;
    setLoadingOlder(true);
    stick.current = false;
    const el = scroller.current;
    const prevHeight = el?.scrollHeight ?? 0;
    const supabase = createClient();
    const { data } = await supabase.from("messages").select("*").eq("channel_id", channel.id).is("parent_id", null)
      .lt("created_at", messages[0].created_at).order("created_at", { ascending: false }).limit(60);
    const older = ((data as Message[]) ?? []).reverse();
    if (older.length) {
      const { data: rx } = await supabase.from("message_reactions").select("message_id, profile_id, emoji").in("message_id", older.map((m) => m.id));
      setReactions((prev) => [...prev, ...((rx as MessageReaction[]) ?? [])]);
    }
    setHasMore(older.length >= 60);
    setMessages((prev) => [...older, ...prev]);
    setLoadingOlder(false);
    requestAnimationFrame(() => { if (el) el.scrollTop = el.scrollHeight - prevHeight; });
  }

  const goTo = (hit: { id: string; parent_id: string | null }) => {
    if (hit.parent_id) { setThreadId(hit.parent_id); setPanel("thread"); return; }
    const el = document.getElementById(`m-${hit.id}`);
    if (el) { stick.current = false; el.scrollIntoView({ block: "center", behavior: "smooth" }); setHighlight(hit.id); setTimeout(() => setHighlight(null), 3000); }
    else router.push(`/messages/${channel.id}?m=${hit.id}`);
  };

  const Icon = channel.kind === "unit" ? Building2 : channel.kind === "project" ? FolderKanban : channel.is_private ? Lock : Hash;
  const typers = Object.values(typing).map((t) => t.name.split(" ")[0]);
  const placeholder = `Écrire à ${channel.kind === "direct" ? channel.name : "#" + channel.name}…`;

  const itemProps = { userId, people: pm, onReact: react, onPin: pin, onDelete: remove };

  return (
    <div className="flex min-h-0 flex-1">
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex h-16 shrink-0 items-center gap-3 border-b border-border px-4 sm:px-6">
          <button onClick={() => router.push("/messages")} className="rounded-md p-1 text-muted md:hidden" aria-label="Retour"><ArrowLeft className="h-5 w-5" /></button>
          {channel.kind === "direct" ? (
            <Avatar name={channel.other_name} src={channel.other_avatar} size="sm" />
          ) : (
            <span className="grid h-9 w-9 place-items-center rounded-lg bg-primary/10 text-primary"><Icon className="h-4 w-4" /></span>
          )}
          <div className="min-w-0 flex-1">
            {channel.kind === "direct" && channel.other_profile_id ? (
              <Link href={`/annuaire/${channel.other_profile_id}`} className="block truncate text-[15px] font-semibold text-fg hover:underline">{channel.name}</Link>
            ) : (
              <p className="truncate text-[15px] font-semibold text-fg">{channel.name}</p>
            )}
            <p className="truncate text-xs text-subtle">
              {channel.kind === "direct" ? channel.other_title : channel.description ?? (channel.kind === "unit" ? "Canal du département" : channel.kind === "project" ? "Canal du projet" : "Canal")}
            </p>
          </div>
          <div className="flex items-center gap-0.5">
            <HeaderButton label="Lancer un appel vidéo" onClick={startCall} disabled={calling}>{calling ? <Loader2 className="h-4 w-4 animate-spin" /> : <Video className="h-4 w-4" />}</HeaderButton>
            <HeaderButton label="Messages épinglés" active={panel === "pinned"} onClick={() => setPanel(panel === "pinned" ? null : "pinned")}>
              <Pin className="h-4 w-4" />{pinned > 0 && <span className="ml-0.5 text-[11px] font-semibold">{pinned}</span>}
            </HeaderButton>
            <HeaderButton label="Rechercher dans la conversation" active={panel === "search"} onClick={() => setPanel(panel === "search" ? null : "search")}><Search className="h-4 w-4" /></HeaderButton>
            {channel.kind !== "direct" && (
              <HeaderButton label="Membres" active={panel === "members"} onClick={() => setPanel(panel === "members" ? null : "members")}>
                <Users className="h-4 w-4" /><span className="ml-0.5 text-[11px] font-semibold">{channelPeople.length}</span>
              </HeaderButton>
            )}
            {channel.kind === "group" && (
              <>
                <InviteMembers channelId={channel.id} people={people.filter((p) => !members.some((m) => m.profile_id === p.id) && p.id !== userId)} />
                <LeaveButton channelId={channel.id} />
              </>
            )}
            {channel.kind === "project" && channel.project_id && <Link href={`/projets/${channel.project_id}`} className="ml-2 hidden text-[13px] font-medium text-primary hover:underline lg:block">Voir le projet</Link>}
            {channel.kind === "unit" && channel.unit_id && <Link href={`/organisation/${channel.unit_id}`} className="ml-2 hidden text-[13px] font-medium text-primary hover:underline lg:block">Voir l&apos;unité</Link>}
          </div>
        </header>

        <div ref={scroller} onScroll={(e) => {
            // On ne décroche du bas que si l'utilisateur remonte lui-même (pas quand une image agrandit le contenu)
            const el = e.currentTarget;
            if (el.scrollHeight - el.scrollTop - el.clientHeight < 120) stick.current = true;
            else if (el.scrollTop < lastTop.current - 2) stick.current = false;
            lastTop.current = el.scrollTop;
          }}
          className="scrollbar-thin flex-1 overflow-y-auto bg-bg/40 px-3 py-4 sm:px-5">
          <div ref={content} className="flex min-h-full flex-col">
          {hasMore && (
            <div className="mb-4 flex justify-center">
              <Button size="sm" variant="outline" onClick={loadOlder} loading={loadingOlder}>Messages précédents</Button>
            </div>
          )}
          {messages.length === 0 && (
            <div className="grid flex-1 place-items-center text-center">
              <div>
                <span className="mx-auto grid h-12 w-12 place-items-center rounded-2xl bg-primary/10 text-primary"><MessageSquare className="h-6 w-6" /></span>
                <p className="mt-3 text-sm font-medium text-fg">Début de la conversation</p>
                <p className="mt-1 text-[13px] text-muted">Envoyez le premier message, partagez un fichier ou lancez un appel.</p>
              </div>
            </div>
          )}
          {messages.map((m, i) => {
            const prev = messages[i - 1];
            const newDay = !prev || prev.created_at.slice(0, 10) !== m.created_at.slice(0, 10);
            return (
              <Fragment key={m.id}>
                {newDay && (
                  <div className="my-5 flex items-center gap-3 text-[11px] font-medium uppercase tracking-wider text-subtle">
                    <span className="h-px flex-1 bg-border" />{dateFr(m.created_at, "EEEE d MMMM")}<span className="h-px flex-1 bg-border" />
                  </div>
                )}
                <MessageItem {...itemProps} m={m} grouped={isGrouped(prev, m)} reactions={reactionMap.get(m.id)} highlight={highlight === m.id}
                  onReply={openThread} onEdit={(x) => setEditing(x)} />
              </Fragment>
            );
          })}
          </div>
        </div>

        <div className="h-5 shrink-0 bg-bg/40 px-6 text-[11px] text-subtle" aria-live="polite">
          {typers.length > 0 && <span className="inline-flex items-center gap-1.5"><TypingDots />{typers.slice(0, 3).join(", ")} {typers.length > 1 ? "écrivent" : "écrit"}…</span>}
        </div>
        <Composer
          channelId={channel.id}
          userId={userId}
          people={channelPeople}
          placeholder={placeholder}
          editing={editing}
          onCancelEdit={() => setEditing(null)}
          onTyping={notifyTyping}
          onSent={(m) => { stick.current = true; setMessages((prev) => (prev.some((x) => x.id === m.id) ? prev : [...prev, m])); }}
        />
      </div>

      {panel && (
        <aside aria-label="Panneau de la conversation" className="fixed inset-0 z-40 flex flex-col border-l border-border bg-surface md:static md:z-auto md:w-[380px] md:shrink-0 xl:w-[420px]">
          <div className="flex h-16 shrink-0 items-center justify-between border-b border-border px-4">
            <p className="text-[15px] font-semibold text-fg">
              {panel === "thread" ? "Fil de discussion" : panel === "pinned" ? "Messages épinglés" : panel === "search" ? "Rechercher" : "Membres"}
            </p>
            <button onClick={closePanel} className="rounded-md p-1.5 text-muted hover:bg-surface-2 hover:text-fg" aria-label="Fermer le panneau"><X className="h-4 w-4" /></button>
          </div>

          {panel === "thread" && (
            <>
              <div ref={threadScroller} className="scrollbar-thin flex-1 overflow-y-auto px-2 py-3">
                {threadLoading && !threadRoot ? (
                  <div className="grid h-40 place-items-center"><Loader2 className="h-5 w-5 animate-spin text-subtle" /></div>
                ) : threadRoot ? (
                  <>
                    <MessageItem {...itemProps} m={threadRoot} grouped={false} inThread reactions={reactionMap.get(threadRoot.id)} onEdit={(x) => setEditing(x)} />
                    <div className="my-3 flex items-center gap-3 px-2 text-[11px] text-subtle">
                      <span>{threadMsgs.length} réponse{threadMsgs.length > 1 ? "s" : ""}</span><span className="h-px flex-1 bg-border" />
                    </div>
                    {threadMsgs.map((m, i) => (
                      <MessageItem key={m.id} {...itemProps} m={m} grouped={isGrouped(threadMsgs[i - 1], m)} inThread reactions={reactionMap.get(m.id)}
                        onEdit={(x) => setThreadEditing(x)} highlight={highlight === m.id} />
                    ))}
                  </>
                ) : (
                  <p className="p-6 text-center text-sm text-muted">Ce message n&apos;existe plus.</p>
                )}
              </div>
              {threadRoot && (
                <Composer
                  key={threadRoot.id}
                  channelId={channel.id}
                  parentId={threadRoot.id}
                  userId={userId}
                  people={channelPeople}
                  placeholder="Répondre dans le fil…"
                  editing={threadEditing}
                  onCancelEdit={() => setThreadEditing(null)}
                  onTyping={notifyTyping}
                  onSent={(m) => {
                    setThreadMsgs((prev) => (prev.some((x) => x.id === m.id) ? prev : [...prev, m]));
                    setMessages((prev) => prev.map((x) => (x.id === threadRoot.id ? { ...x, reply_count: x.reply_count + 1, last_reply_at: m.created_at } : x)));
                  }}
                  autoFocus
                  compact
                />
              )}
            </>
          )}

          {panel === "pinned" && <PinnedPanel channelId={channel.id} people={pm} count={pinned} onOpen={goTo} />}
          {panel === "search" && <SearchPanel channelId={channel.id} people={pm} onOpen={goTo} />}
          {panel === "members" && (
            <ul className="scrollbar-thin flex-1 space-y-0.5 overflow-y-auto p-2">
              {channelPeople.map((p) => (
                <li key={p.id} className="group flex items-center gap-3 rounded-lg px-2 py-2 hover:bg-surface-2">
                  <Avatar name={p.full_name} src={p.avatar_url} size="sm" />
                  <Link href={`/annuaire/${p.id}`} className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-medium text-fg">{p.full_name}{p.id === userId && <span className="ml-1 text-xs font-normal text-subtle">(vous)</span>}</span>
                    <span className="block truncate text-xs text-subtle">{p.job_title}</span>
                  </Link>
                  {p.id !== userId && <DmButton id={p.id} />}
                </li>
              ))}
            </ul>
          )}
        </aside>
      )}
    </div>
  );
}

function HeaderButton({ label, active, onClick, disabled, children }: { label: string; active?: boolean; onClick: () => void; disabled?: boolean; children: React.ReactNode }) {
  return (
    <button onClick={onClick} disabled={disabled} aria-label={label} title={label}
      className={cn("flex h-8 min-w-8 items-center justify-center rounded-lg px-2 text-muted transition hover:bg-surface-2 hover:text-fg disabled:opacity-60",
        active && "bg-primary/10 text-primary hover:bg-primary/15 hover:text-primary")}>
      {children}
    </button>
  );
}

function TypingDots() {
  return (
    <span className="inline-flex gap-0.5">
      {[0, 1, 2].map((i) => <span key={i} className="h-1 w-1 animate-bounce rounded-full bg-subtle" style={{ animationDelay: `${i * 150}ms` }} />)}
    </span>
  );
}

function PinnedPanel({ channelId, people, count, onOpen }: { channelId: string; people: Map<string, ProfileLite>; count: number; onOpen: (m: { id: string; parent_id: string | null }) => void }) {
  const [list, setList] = useState<Message[] | null>(null);
  useEffect(() => {
    createClient().from("messages").select("*").eq("channel_id", channelId).not("pinned_at", "is", null).is("deleted_at", null)
      .order("pinned_at", { ascending: false }).limit(50).then(({ data }) => setList((data as Message[]) ?? []));
  }, [channelId, count]);
  if (!list) return <div className="grid h-40 place-items-center"><Loader2 className="h-5 w-5 animate-spin text-subtle" /></div>;
  if (!list.length) return <p className="p-6 text-center text-sm text-muted">Aucun message épinglé. Survolez un message puis « … » → Épingler pour garder les informations importantes à portée de main.</p>;
  return (
    <ul className="scrollbar-thin flex-1 space-y-2 overflow-y-auto p-3">
      {list.map((m) => <HitCard key={m.id} m={m} people={people} onClick={() => onOpen(m)} />)}
    </ul>
  );
}

function SearchPanel({ channelId, people, onOpen }: { channelId: string; people: Map<string, ProfileLite>; onOpen: (m: { id: string; parent_id: string | null }) => void }) {
  const [q, setQ] = useState("");
  const [hits, setHits] = useState<SearchHit[] | null>(null);
  const [pending, start] = useTransition();
  useEffect(() => {
    const term = q.trim();
    if (term.length < 2) { setHits(null); return; }
    const t = setTimeout(() => start(async () => {
      const { data } = await createClient().rpc("search_messages", { q: term, p_channel: channelId });
      setHits((data as SearchHit[]) ?? []);
    }), 250);
    return () => clearTimeout(t);
  }, [q, channelId]);
  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <div className="relative border-b border-border p-3">
        <Search className="pointer-events-none absolute left-6 top-1/2 h-4 w-4 -translate-y-1/2 text-subtle" />
        <Input autoFocus value={q} onChange={(e) => setQ(e.target.value)} placeholder="Mots-clés…" className="pl-9" />
      </div>
      <ul className="scrollbar-thin flex-1 space-y-2 overflow-y-auto p-3">
        {pending && <li className="flex justify-center py-4"><Loader2 className="h-4 w-4 animate-spin text-subtle" /></li>}
        {!pending && hits && hits.length === 0 && <li className="p-4 text-center text-sm text-muted">Aucun message ne correspond.</li>}
        {!pending && !hits && <li className="p-4 text-center text-sm text-muted">Tapez au moins 2 caractères.</li>}
        {hits?.map((h) => <HitCard key={h.id} m={h} people={people} query={q.trim()} onClick={() => onOpen(h)} />)}
      </ul>
    </div>
  );
}

function HitCard({ m, people, query, onClick }: { m: { author_id: string | null; body: string; created_at: string; parent_id: string | null }; people: Map<string, ProfileLite>; query?: string; onClick: () => void }) {
  const a = m.author_id ? people.get(m.author_id) : null;
  const text = plainText(m.body);
  const parts = query ? text.split(new RegExp(`(${query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")})`, "ig")) : [text];
  return (
    <li>
      <button onClick={onClick} className="w-full rounded-xl border border-border bg-surface p-3 text-left transition hover:border-primary/40 hover:shadow-sm">
        <div className="mb-1 flex items-center gap-2">
          <Avatar name={a?.full_name ?? "?"} src={a?.avatar_url} size="xs" />
          <span className="truncate text-[13px] font-medium text-fg">{a?.full_name ?? "Ancien membre"}</span>
          <span className="ml-auto shrink-0 text-[11px] text-subtle">{chatTime(m.created_at)}</span>
        </div>
        <p className="line-clamp-3 text-[13px] text-muted">
          {parts.map((p, i) => (query && p.toLowerCase() === query.toLowerCase() ? <mark key={i} className="rounded bg-amber-300/40 px-0.5 text-fg">{p}</mark> : <span key={i}>{p}</span>))}
          {!text && <span className="italic">Pièce jointe</span>}
        </p>
        {m.parent_id && <p className="mt-1 text-[11px] font-medium text-primary">Dans un fil</p>}
      </button>
    </li>
  );
}

function DmButton({ id }: { id: string }) {
  const [pending, start] = useTransition();
  return (
    <button disabled={pending} onClick={() => start(() => openDirectMessage(id))} aria-label="Message direct" title="Message direct"
      className="rounded-md p-1.5 text-subtle opacity-0 transition hover:bg-surface hover:text-fg group-hover:opacity-100 disabled:opacity-50">
      {pending ? <Loader2 className="h-4 w-4 animate-spin" /> : <MessageSquare className="h-4 w-4" />}
    </button>
  );
}

function InviteMembers({ channelId, people }: { channelId: string; people: ProfileLite[] }) {
  const [sel, setSel] = useState<string[]>([]);
  const [open, setOpen] = useState(false);
  const [pending, start] = useTransition();
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><Button size="icon-sm" variant="ghost" aria-label="Inviter"><UserPlus className="h-4 w-4" /></Button></DialogTrigger>
      <DialogContent title="Inviter dans le canal" size="sm">
        {people.length === 0 ? <p className="text-sm text-muted">Tout le monde fait déjà partie du canal.</p> : (
          <div className="scrollbar-thin max-h-72 space-y-1 overflow-y-auto">
            {people.map((p) => (
              <Checkbox key={p.id} label={p.full_name} checked={sel.includes(p.id)} className="flex w-full rounded px-2 py-1.5 hover:bg-surface-2"
                onChange={(e) => setSel((s) => (e.target.checked ? [...s, p.id] : s.filter((x) => x !== p.id)))} />
            ))}
          </div>
        )}
        <div className="mt-4 flex justify-end">
          <Button disabled={!sel.length} loading={pending} onClick={() => start(async () => {
            const r = await addChannelMembers(channelId, sel);
            if (r.ok) { toast.success(r.message); setOpen(false); setSel([]); } else toast.error(r.error);
          })}>Inviter</Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}

function LeaveButton({ channelId }: { channelId: string }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  return (
    <Button size="icon-sm" variant="ghost" aria-label="Quitter" loading={pending} onClick={() => {
      if (!confirm("Quitter ce canal ?")) return;
      start(async () => {
        const r = await leaveChannel(channelId);
        if (r.ok) router.push("/messages"); else toast.error(r.error);
      });
    }}>{!pending && <LogOut className="h-4 w-4" />}</Button>
  );
}
