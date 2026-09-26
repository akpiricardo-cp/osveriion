import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getContext } from "@/lib/auth";
import { getPeople } from "@/lib/data";
import type { ChannelPerson } from "@/lib/chat";
import type { ChannelSummary, Message, MessageReaction } from "@/lib/types";
import { Chat } from "./chat";

const PAGE = 60;

export default async function ChannelPage({
  params, searchParams,
}: { params: Promise<{ id: string }>; searchParams: Promise<{ fil?: string; m?: string }> }) {
  const { id } = await params;
  const sp = await searchParams;
  const ctx = await getContext();
  const supabase = await createClient();

  const [{ data: channels }, { data: latest }, { data: members }, { data: channelPeople }, { count: pinnedCount }, people] = await Promise.all([
    supabase.rpc("my_channels"),
    supabase.from("messages").select("*").eq("channel_id", id).is("parent_id", null).order("created_at", { ascending: false }).limit(PAGE),
    supabase.from("channel_members").select("profile_id, role").eq("channel_id", id),
    supabase.rpc("channel_people", { p_channel: id }),
    supabase.from("messages").select("id", { count: "exact", head: true }).eq("channel_id", id).not("pinned_at", "is", null).is("deleted_at", null),
    getPeople(),
  ]);
  const channel = ((channels as ChannelSummary[]) ?? []).find((c) => c.id === id);
  if (!channel) notFound();

  let messages = ((latest as Message[]) ?? []).reverse();
  let hasMore = (latest?.length ?? 0) >= PAGE;
  let thread = sp.fil ?? null;
  let focus: string | null = sp.m ?? null;

  // Lien direct vers un message : on charge l'historique jusqu'à lui si nécessaire
  if (focus) {
    const { data: target } = await supabase.from("messages").select("id, parent_id, created_at").eq("id", focus).eq("channel_id", id).maybeSingle();
    if (!target) focus = null;
    else if (target.parent_id) thread = target.parent_id;
    else if (!messages.some((m) => m.id === target.id)) {
      const [{ data: after }, { data: before }] = await Promise.all([
        supabase.from("messages").select("*").eq("channel_id", id).is("parent_id", null).gte("created_at", target.created_at).order("created_at").limit(300),
        supabase.from("messages").select("*").eq("channel_id", id).is("parent_id", null).lt("created_at", target.created_at).order("created_at", { ascending: false }).limit(20),
      ]);
      messages = [...((before as Message[]) ?? []).reverse(), ...((after as Message[]) ?? [])];
      hasMore = (before?.length ?? 0) >= 20;
    }
  }

  const ids = messages.map((m) => m.id);
  const { data: reactions } = ids.length
    ? await supabase.from("message_reactions").select("message_id, profile_id, emoji").in("message_id", ids)
    : { data: [] };

  await supabase.rpc("mark_channel_read", { p_channel: id });

  return (
    <Chat
      key={id}
      channel={channel}
      initial={messages}
      initialReactions={(reactions as MessageReaction[]) ?? []}
      hasMoreInitial={hasMore}
      people={people}
      channelPeople={(channelPeople as ChannelPerson[]) ?? []}
      userId={ctx.userId}
      userName={ctx.profile.full_name}
      members={members ?? []}
      pinnedCount={pinnedCount ?? 0}
      initialThread={thread}
      focusId={focus}
    />
  );
}
