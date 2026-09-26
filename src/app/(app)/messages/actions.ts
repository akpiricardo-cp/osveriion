"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { fail, ok, str } from "@/lib/actions";
import type { ActionResult } from "@/lib/types";

export async function createGroup(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const name = str(fd, "name")?.toLowerCase().replace(/\s+/g, "-");
  if (!name) return fail("Nom requis.");
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const { data, error } = await supabase.from("channels").insert({
    kind: "group", name, description: str(fd, "description"), is_private: fd.get("is_private") === "on", created_by: user!.id,
  }).select("id").single();
  if (error) return fail(error);
  const members = fd.getAll("members").map(String).filter((m) => m && m !== user!.id);
  if (members.length) {
    const { error: e2 } = await supabase.from("channel_members").insert(members.map((m) => ({ channel_id: data.id, profile_id: m })));
    if (e2) return fail(e2);
  }
  revalidatePath("/messages", "layout");
  return ok("Canal créé.", data);
}

export async function addChannelMembers(channelId: string, ids: string[]): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("channel_members").upsert(ids.map((id) => ({ channel_id: channelId, profile_id: id })), { ignoreDuplicates: true });
  if (error) return fail(error);
  revalidatePath(`/messages/${channelId}`);
  return ok("Membres ajoutés.");
}

export async function leaveChannel(channelId: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const { error } = await supabase.from("channel_members").delete().eq("channel_id", channelId).eq("profile_id", user!.id);
  if (error) return fail(error);
  revalidatePath("/messages", "layout");
  return ok("Vous avez quitté le canal.");
}
