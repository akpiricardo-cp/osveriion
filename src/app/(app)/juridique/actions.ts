"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { can, getContext } from "@/lib/auth";
import { bool, fail, numVal, ok, str } from "@/lib/actions";
import type { ActionResult, LegalContractStatus } from "@/lib/types";

async function requireLegal() {
  const ctx = await getContext();
  if (!can(ctx, "legal.admin")) throw new Error("Action réservée au département juridique.");
  return ctx;
}

function contractPatch(fd: FormData) {
  return {
    title: str(fd, "title"),
    type: str(fd, "type") ?? "other",
    counterparty: str(fd, "counterparty"),
    account_id: str(fd, "account_id"),
    project_id: str(fd, "project_id"),
    unit_id: str(fd, "unit_id"),
    owner_id: str(fd, "owner_id"),
    amount: numVal(fd, "amount"),
    risk: str(fd, "risk") ?? "low",
    effective_date: str(fd, "effective_date"),
    end_date: str(fd, "end_date"),
    renewal_notice_days: numVal(fd, "renewal_notice_days") ?? 30,
    auto_renew: bool(fd, "auto_renew"),
    obligations: str(fd, "obligations"),
    notes: str(fd, "notes"),
  };
}

export async function saveContract(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  try {
    await requireLegal();
    const patch = contractPatch(fd);
    if (!patch.title || patch.title.length < 3) return fail("Donnez un titre au contrat.");
    if (!patch.counterparty) return fail("Indiquez la partie signataire en face.");
    const supabase = await createClient();
    const id = str(fd, "id");
    const { error } = id
      ? await supabase.from("legal_contracts").update(patch).eq("id", id)
      : await supabase.from("legal_contracts").insert(patch);
    if (error) return fail(error);
    revalidatePath("/juridique");
    return ok(id ? "Contrat mis à jour." : "Contrat enregistré au registre.");
  } catch (e) {
    return fail(e instanceof Error ? e.message : "Erreur");
  }
}

/** Fait passer un contrat d'une étape à l'autre (hors signature, qui exige l'accord du CEO). */
export async function setContractStatus(id: string, status: LegalContractStatus): Promise<ActionResult> {
  try {
    await requireLegal();
    const supabase = await createClient();
    const { error } = await supabase.from("legal_contracts").update({ status }).eq("id", id);
    if (error) return fail(error);
    revalidatePath("/juridique");
    return ok("Statut mis à jour.");
  } catch (e) {
    return fail(e instanceof Error ? e.message : "Erreur");
  }
}

/** Revue juridique terminée : le contrat part à la signature du CEO. */
export async function submitContract(id: string, justification?: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("submit_contract_for_signature", { p_contract: id, p_justification: justification ?? null });
  if (error) return fail(error);
  revalidatePath("/juridique");
  revalidatePath("/validations");
  return ok("Contrat transmis au CEO pour signature.");
}

/** Une fois l'accord donné, le juriste acte la signature. */
export async function signContract(id: string): Promise<ActionResult> {
  try {
    await requireLegal();
    const supabase = await createClient();
    const { error } = await supabase.from("legal_contracts").update({ status: "active" }).eq("id", id);
    if (error) return fail(error);
    revalidatePath("/juridique");
    return ok("Contrat signé et en vigueur.");
  } catch (e) {
    return fail(e instanceof Error ? e.message : "Erreur");
  }
}

export async function deleteContract(id: string): Promise<ActionResult> {
  try {
    await requireLegal();
    const supabase = await createClient();
    const { error } = await supabase.from("legal_contracts").delete().eq("id", id);
    if (error) return fail(error);
    revalidatePath("/juridique");
    return ok("Brouillon supprimé.");
  } catch (e) {
    return fail(e instanceof Error ? e.message : "Erreur");
  }
}
