"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { canDecideApprovals, getContext } from "@/lib/auth";
import { fail, numVal, ok, str } from "@/lib/actions";
import type { ActionResult, ApprovalKind } from "@/lib/types";

const KINDS: ApprovalKind[] = ["budget", "expense", "legal_contract", "operation_cycle", "project", "employment_contract", "other"];

/** Décision du CEO : accord ou refus motivé. */
export async function decideApproval(id: string, approve: boolean, note?: string): Promise<ActionResult> {
  const ctx = await getContext();
  if (!canDecideApprovals(ctx)) return fail("Cette décision revient au CEO.");
  const supabase = await createClient();
  const { error } = await supabase.rpc("decide_approval", { p_id: id, p_approve: approve, p_note: note ?? null });
  if (error) return fail(error);
  revalidatePath("/validations");
  revalidatePath("/", "layout");
  return ok(approve ? "Accord enregistré." : "Refus enregistré : le demandeur est prévenu.");
}

export async function cancelApproval(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("cancel_approval", { p_id: id });
  if (error) return fail(error);
  revalidatePath("/validations");
  return ok("Demande retirée.");
}

/** Soumet une décision au CEO depuis le guichet (dépense, budget, autre). */
export async function submitApproval(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const kind = (str(fd, "kind") ?? "other") as ApprovalKind;
  if (!KINDS.includes(kind)) return fail("Type de décision inconnu.");
  const label = str(fd, "subject_label");
  if (!label || label.length < 3) return fail("Décrivez l'objet de la demande.");
  const supabase = await createClient();
  const { error } = await supabase.rpc("request_approval", {
    p_kind: kind,
    p_subject: str(fd, "subject_id"),
    p_label: label,
    p_amount: numVal(fd, "amount"),
    p_justification: str(fd, "justification"),
    p_unit: str(fd, "unit_id"),
    p_project: str(fd, "project_id"),
  });
  if (error) return fail(error);
  revalidatePath("/validations");
  return ok("Demande transmise au CEO.");
}
