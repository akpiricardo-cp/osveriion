"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { fail, ok, str } from "@/lib/actions";
import type { ActionResult } from "@/lib/types";

export async function publishAnnouncement(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const title = str(fd, "title");
  const body = str(fd, "body");
  if (!title || !body) return fail("Titre et contenu sont requis.");
  const { error } = await supabase.from("announcements").insert({
    title, body, pinned: fd.get("pinned") === "on", unit_id: str(fd, "unit_id"), author_id: user!.id,
  });
  if (error) return fail(error);
  revalidatePath("/");
  return ok("Annonce publiée et notifiée à l'équipe.");
}

export async function deleteAnnouncement(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("announcements").delete().eq("id", id);
  if (error) return fail(error);
  revalidatePath("/");
  return ok("Annonce supprimée.");
}

export async function toggleLifecycleItem(id: string, done: boolean): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("lifecycle_items").update({ done_at: done ? new Date().toISOString() : null }).eq("id", id);
  if (error) return fail(error);
  revalidatePath("/");
  revalidatePath("/rh");
  return ok();
}
