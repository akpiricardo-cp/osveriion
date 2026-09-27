"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { fail, numVal, ok, str } from "@/lib/actions";
import type { ActionResult, CycleKind, OpsItemStatus } from "@/lib/types";

const KINDS: CycleKind[] = ["monthly", "weekly", "daily"];

/** Fin de période déduite du type de cycle : un mois, une semaine, un jour. */
function periodEnd(kind: CycleKind, start: string) {
  const d = new Date(start + "T00:00:00Z");
  if (kind === "monthly") {
    const end = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0));
    return end.toISOString().slice(0, 10);
  }
  if (kind === "weekly") {
    d.setUTCDate(d.getUTCDate() + 6);
    return d.toISOString().slice(0, 10);
  }
  return start;
}

export async function saveCycle(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const projectId = str(fd, "project_id");
  const kind = (str(fd, "kind") ?? "monthly") as CycleKind;
  const start = str(fd, "period_start");
  const title = str(fd, "title");
  if (!projectId) return fail("Choisissez le projet concerné.");
  if (!KINDS.includes(kind)) return fail("Type de cycle inconnu.");
  if (!start) return fail("Indiquez le début de la période.");
  if (!title || title.length < 3) return fail("Donnez un intitulé au cycle.");

  const supabase = await createClient();
  const id = str(fd, "id");
  const patch = {
    project_id: projectId,
    kind,
    title,
    focus: str(fd, "focus"),
    period_start: start,
    period_end: str(fd, "period_end") ?? periodEnd(kind, start),
  };
  const { error } = id
    ? await supabase.from("operation_cycles").update(patch).eq("id", id)
    : await supabase.from("operation_cycles").insert(patch);
  if (error) return fail(error);
  revalidatePath("/operations");
  revalidatePath(`/projets/${projectId}`);
  return ok(id ? "Cycle mis à jour." : "Cycle créé : ajoutez-y les grandes lignes.");
}

export async function deleteCycle(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("operation_cycles").delete().eq("id", id);
  if (error) return fail(error);
  revalidatePath("/operations");
  return ok("Cycle supprimé.");
}

/** Publication : le mensuel part chez le CEO, l'hebdomadaire et le journalier vont droit à l'équipe. */
export async function publishCycle(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("publish_operation_cycle", { p_cycle: id });
  if (error) return fail(error);
  const { data: cycle } = await supabase.from("operation_cycles").select("status, project_id").eq("id", id).maybeSingle();
  revalidatePath("/operations");
  revalidatePath("/validations");
  if (cycle?.project_id) revalidatePath(`/projets/${cycle.project_id}`);
  return ok(cycle?.status === "pending_ceo" ? "Calendrier transmis au CEO pour accord." : "Calendrier publié : l'équipe est prévenue.");
}

export async function saveItem(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const cycleId = str(fd, "cycle_id");
  const title = str(fd, "title");
  if (!cycleId) return fail("Cycle manquant.");
  if (!title || title.length < 3) return fail("Décrivez la grande ligne en une phrase.");
  const supabase = await createClient();
  const id = str(fd, "id");
  const patch = {
    cycle_id: cycleId,
    title,
    detail: str(fd, "detail"),
    expected_outcome: str(fd, "expected_outcome"),
    owner_id: str(fd, "owner_id"),
    due_date: str(fd, "due_date"),
    position: numVal(fd, "position") ?? Date.now() / 1000,
  };
  const { error } = id
    ? await supabase.from("operation_items").update(patch).eq("id", id)
    : await supabase.from("operation_items").insert(patch);
  if (error) return fail(error);
  revalidatePath("/operations");
  return ok(id ? "Grande ligne mise à jour." : "Grande ligne ajoutée.");
}

export async function setItemStatus(id: string, status: OpsItemStatus): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("operation_items").update({ status }).eq("id", id);
  if (error) return fail(error);
  revalidatePath("/operations");
  return ok("Avancement enregistré.");
}

export async function deleteItem(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("operation_items").delete().eq("id", id);
  if (error) return fail(error);
  revalidatePath("/operations");
  return ok("Grande ligne retirée.");
}

/** Le chef de projet rend compte du cycle aux Opérations. */
export async function submitReport(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const cycleId = str(fd, "cycle_id");
  const summary = str(fd, "summary");
  if (!cycleId) return fail("Cycle manquant.");
  if (!summary || summary.length < 10) return fail("Résumez ce qui a été fait, en quelques phrases.");
  const supabase = await createClient();
  const { error } = await supabase.rpc("submit_operation_report", {
    p_cycle: cycleId,
    p_progress: numVal(fd, "progress") ?? 0,
    p_summary: summary,
    p_blockers: str(fd, "blockers"),
    p_next: str(fd, "next_steps"),
  });
  if (error) return fail(error);
  revalidatePath("/operations");
  const projectId = str(fd, "project_id");
  if (projectId) revalidatePath(`/projets/${projectId}`);
  return ok("Rapport transmis aux Opérations.");
}

export async function acknowledgeReport(id: string, note?: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("acknowledge_operation_report", { p_report: id, p_note: note ?? null });
  if (error) return fail(error);
  revalidatePath("/operations");
  return ok("Rapport pris en compte.");
}

/** Le chef de projet transforme une grande ligne en tâches pour son équipe. */
export async function createTaskFromItem(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const itemId = str(fd, "operation_item_id");
  const projectId = str(fd, "project_id");
  const title = str(fd, "title");
  if (!title || title.length < 3) return fail("Donnez un intitulé à la tâche.");
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return fail("Session expirée.");
  const { error } = await supabase.from("tasks").insert({
    title,
    description: str(fd, "description"),
    project_id: projectId,
    operation_item_id: itemId,
    assignee_id: str(fd, "assignee_id"),
    reporter_id: user.id,
    due_date: str(fd, "due_date"),
    priority: str(fd, "priority") ?? "medium",
    status: "todo",
  });
  if (error) return fail(error);
  if (itemId) await supabase.from("operation_items").update({ status: "in_progress" }).eq("id", itemId);
  if (projectId) revalidatePath(`/projets/${projectId}`);
  revalidatePath("/taches");
  return ok("Tâche créée et assignée.");
}
