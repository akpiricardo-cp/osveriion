"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { fail, ok, str } from "@/lib/actions";
import type { ActionResult } from "@/lib/types";

export async function openDirectMessage(profileId: string) {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("open_direct_channel", { p_other: profileId });
  if (error) throw new Error(error.message);
  redirect(`/messages/${data}`);
}

export async function updateProfile(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const id = str(fd, "id");
  if (!id) return fail("Profil manquant.");
  const supabase = await createClient();
  const patch: Record<string, unknown> = {};
  for (const k of ["first_name", "last_name", "job_title", "phone", "location", "bio", "birth_date"]) {
    if (fd.has(k)) patch[k] = str(fd, k) ?? (k === "first_name" || k === "last_name" ? "" : null);
  }
  for (const k of ["manager_id", "primary_unit_id", "hire_date", "system_role", "status"]) {
    if (fd.has(k)) patch[k] = str(fd, k);
  }
  if (patch.manager_id === id) return fail("Une personne ne peut pas être son propre manager.");
  const { error } = await supabase.from("profiles").update(patch).eq("id", id);
  if (error) return fail(error);
  revalidatePath(`/annuaire/${id}`);
  revalidatePath("/annuaire");
  return ok("Profil mis à jour.");
}
