"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { fail, numVal, ok, str } from "@/lib/actions";
import type { AccountType, ActionResult, OpportunityStage } from "@/lib/types";

const TYPES: AccountType[] = ["prospect", "client", "partner"];
const STAGES: OpportunityStage[] = ["lead", "qualified", "proposal", "negotiation", "won", "lost"];

function refresh(accountId?: string | null) {
  revalidatePath("/crm");
  revalidatePath("/crm/comptes");
  if (accountId) revalidatePath(`/crm/comptes/${accountId}`);
}

export async function saveAccount(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const name = str(fd, "name");
  if (!name) return fail("Le nom est requis.");
  const id = str(fd, "id");
  const type = str(fd, "type") as AccountType;
  const supabase = await createClient();
  const row = {
    name,
    type: TYPES.includes(type) ? type : "prospect",
    industry: str(fd, "industry"), country: str(fd, "country"), city: str(fd, "city"),
    website: str(fd, "website"), email: str(fd, "email"), phone: str(fd, "phone"), notes: str(fd, "notes"),
    owner_id: str(fd, "owner_id") ?? undefined,
    tags: (str(fd, "tags") ?? "").split(",").map((t) => t.trim()).filter(Boolean),
  };
  const res = id
    ? await supabase.from("accounts").update(row).eq("id", id).select("id").single()
    : await supabase.from("accounts").insert(row).select("id").single();
  if (res.error) return fail(res.error);
  refresh(res.data.id);
  return ok(id ? "Compte mis à jour." : "Compte créé.", res.data);
}

export async function deleteAccount(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("accounts").delete().eq("id", id);
  if (error) return fail(error);
  refresh();
  return ok("Compte supprimé.");
}

export async function saveContact(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const first = str(fd, "first_name");
  const account = str(fd, "account_id");
  if (!first || !account) return fail("Prénom requis.");
  const supabase = await createClient();
  const { error } = await supabase.from("contacts").insert({
    account_id: account, first_name: first, last_name: str(fd, "last_name"), job_title: str(fd, "job_title"),
    email: str(fd, "email"), phone: str(fd, "phone"), is_primary: fd.get("is_primary") === "on",
  });
  if (error) return fail(error);
  refresh(account);
  return ok("Contact ajouté.");
}

export async function deleteContact(id: string, accountId: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("contacts").delete().eq("id", id);
  if (error) return fail(error);
  refresh(accountId);
  return ok("Contact supprimé.");
}

export async function saveOpportunity(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const name = str(fd, "name");
  const account = str(fd, "account_id");
  if (!name || !account) return fail("Nom et compte sont requis.");
  const id = str(fd, "id");
  const stage = (str(fd, "stage") ?? "lead") as OpportunityStage;
  const supabase = await createClient();
  const row = {
    name, account_id: account,
    stage: STAGES.includes(stage) ? stage : "lead",
    amount: numVal(fd, "amount") ?? 0,
    probability: Math.max(0, Math.min(100, numVal(fd, "probability") ?? 10)),
    expected_close: str(fd, "expected_close"),
    product: str(fd, "product"),
    owner_id: str(fd, "owner_id") ?? undefined,
  };
  const { error } = id
    ? await supabase.from("opportunities").update(row).eq("id", id)
    : await supabase.from("opportunities").insert(row);
  if (error) return fail(error);
  refresh(account);
  return ok(stage === "won" ? "Opportunité gagnée : projet de livraison et facture brouillon créés." : "Opportunité enregistrée.");
}

export async function moveOpportunity(id: string, stage: OpportunityStage, lostReason?: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("opportunities").update({ stage, lost_reason: lostReason ?? null, position: Date.now() / 1000 }).eq("id", id);
  if (error) return fail(error);
  refresh();
  revalidatePath("/projets");
  revalidatePath("/finance");
  return ok(stage === "won" ? "Bravo ! Le compte devient client ; un projet et une facture brouillon ont été créés." : undefined);
}

export async function logInteraction(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const account = str(fd, "account_id");
  const subject = str(fd, "subject");
  if (!account || !subject) return fail("Sujet requis.");
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const { error } = await supabase.from("interactions").insert({
    account_id: account, subject, body: str(fd, "body"), kind: str(fd, "kind") ?? "note",
    contact_id: str(fd, "contact_id"), opportunity_id: str(fd, "opportunity_id"),
    occurred_at: str(fd, "occurred_at") ? new Date(str(fd, "occurred_at")!).toISOString() : new Date().toISOString(),
    author_id: user!.id,
  });
  if (error) return fail(error);
  refresh(account);
  return ok("Interaction enregistrée.");
}
