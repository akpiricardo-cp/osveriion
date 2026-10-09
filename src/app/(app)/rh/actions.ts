"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { fail, numVal, ok, str } from "@/lib/actions";
import type { ActionResult, LeaveType } from "@/lib/types";

function refresh() {
  revalidatePath("/rh");
  revalidatePath("/");
}

export async function requestLeave(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const start = str(fd, "start_date");
  const end = str(fd, "end_date");
  if (!start || !end) return fail("Dates requises.");
  if (end < start) return fail("La date de fin précède la date de début.");
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const { error } = await supabase.from("leave_requests").insert({
    profile_id: user!.id, start_date: start, end_date: end, type: (str(fd, "type") ?? "annual") as LeaveType, reason: str(fd, "reason"),
  });
  if (error) return fail(error);
  refresh();
  return ok("Demande envoyée à votre responsable.");
}

export async function decideLeave(id: string, decision: "approved" | "rejected", note?: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("leave_requests").update({ status: decision, decision_note: note || null }).eq("id", id);
  if (error) return fail(error);
  refresh();
  return ok(decision === "approved" ? "Congé approuvé." : "Demande refusée.");
}

export async function cancelLeave(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("leave_requests").update({ status: "cancelled" }).eq("id", id);
  if (error) return fail(error);
  refresh();
  return ok("Demande annulée.");
}

export async function addContract(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const profile = str(fd, "profile_id");
  const start = str(fd, "start_date");
  if (!profile || !start) return fail("Employé et date de début requis.");
  const supabase = await createClient();
  // Le contrat naît en brouillon ; le salaire convenu ne s'applique qu'à la signature.
  const { error } = await supabase.from("employment_contracts").insert({
    profile_id: profile, type: str(fd, "type") ?? "cdi", job_title: str(fd, "job_title"), start_date: start,
    end_date: str(fd, "end_date"), weekly_hours: numVal(fd, "weekly_hours") ?? 40, notes: str(fd, "notes"),
    gross_monthly: numVal(fd, "gross_monthly"),
  });
  if (error) return fail(error);
  refresh();
  revalidatePath(`/annuaire/${profile}`);
  return ok("Contrat enregistré en brouillon : soumettez-le à l'accord du CEO, puis signez-le.");
}

export async function submitEmploymentContract(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("submit_employment_contract", { p_contract: id, p_justification: null });
  if (error) return fail(error);
  refresh();
  revalidatePath("/validations");
  return ok("Contrat transmis au CEO.");
}

export async function signEmploymentContract(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("employment_contracts").update({ status: "signed" }).eq("id", id);
  if (error) return fail(error);
  refresh();
  return ok("Contrat signé : la rémunération convenue s'applique.");
}

export async function endEmploymentContract(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("employment_contracts").update({ status: "ended" }).eq("id", id);
  if (error) return fail(error);
  refresh();
  return ok("Contrat clos.");
}

export async function addSalary(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const profile = str(fd, "profile_id");
  const amount = numVal(fd, "gross_monthly");
  if (!profile || !amount) return fail("Montant requis.");
  const supabase = await createClient();
  const { error } = await supabase.from("salaries").insert({ profile_id: profile, gross_monthly: amount, effective_from: str(fd, "effective_from") ?? undefined, notes: str(fd, "notes") });
  if (error) return fail(error);
  refresh();
  return ok("Rémunération mise à jour.");
}

export async function addLifecycleItem(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const profile = str(fd, "profile_id");
  const title = str(fd, "title");
  if (!profile || !title) return fail("Titre requis.");
  const supabase = await createClient();
  const { error } = await supabase.from("lifecycle_items").insert({
    profile_id: profile, title, kind: str(fd, "kind") ?? "onboarding", due_date: str(fd, "due_date"), assignee_id: str(fd, "assignee_id"), position: 99,
  });
  if (error) return fail(error);
  refresh();
  return ok("Étape ajoutée.");
}
