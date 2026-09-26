"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { fail, numVal, ok, str } from "@/lib/actions";
import type { ActionResult, ObjectiveLevel, ObjectiveStatus } from "@/lib/types";

function refresh() {
  revalidatePath("/objectifs");
  revalidatePath("/direction");
  revalidatePath("/organisation", "layout");
}

export async function createObjective(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const title = str(fd, "title");
  const level = str(fd, "level") as ObjectiveLevel;
  if (!title || !["company", "unit", "individual"].includes(level)) return fail("Titre et niveau requis.");
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const { data, error } = await supabase.from("objectives").insert({
    title, level,
    description: str(fd, "description"),
    unit_id: level === "unit" ? str(fd, "unit_id") : null,
    parent_id: str(fd, "parent_id"),
    owner_id: str(fd, "owner_id") ?? user!.id,
    period: str(fd, "period") ?? undefined,
  }).select("id").single();
  if (error) return fail(error);
  // Résultats clés saisis dans le formulaire
  const krs = fd.getAll("kr_title").map(String).map((t, i) => ({
    title: t.trim(),
    target: Number(String(fd.getAll("kr_target")[i] ?? "").replace(",", ".")),
    unit: String(fd.getAll("kr_unit")[i] ?? "").trim() || null,
  })).filter((k) => k.title && Number.isFinite(k.target) && k.target !== 0);
  if (krs.length) {
    const { error: e2 } = await supabase.from("key_results").insert(krs.map((k, i) => ({
      objective_id: data.id, title: k.title, target_value: k.target, metric_unit: k.unit, position: i,
    })));
    if (e2) return fail(e2);
  }
  refresh();
  return ok("Objectif créé.");
}

export async function updateObjectiveStatus(id: string, status: ObjectiveStatus): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("objectives").update({ status }).eq("id", id);
  if (error) return fail(error);
  refresh();
  return ok();
}

export async function deleteObjective(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("objectives").delete().eq("id", id);
  if (error) return fail(error);
  refresh();
  return ok("Objectif supprimé.");
}

export async function updateKeyResult(id: string, current: number): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("key_results").update({ current_value: current }).eq("id", id);
  if (error) return fail(error);
  refresh();
  return ok("Progression mise à jour.");
}

export async function addKeyResult(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const obj = str(fd, "objective_id");
  const title = str(fd, "title");
  const target = numVal(fd, "target_value");
  if (!obj || !title || target === null) return fail("Intitulé et cible requis.");
  const supabase = await createClient();
  const { error } = await supabase.from("key_results").insert({
    objective_id: obj, title, target_value: target, start_value: numVal(fd, "start_value") ?? 0,
    current_value: numVal(fd, "start_value") ?? 0, metric_unit: str(fd, "metric_unit"),
  });
  if (error) return fail(error);
  refresh();
  return ok("Résultat clé ajouté.");
}

export async function saveKpi(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const key = str(fd, "key");
  const name = str(fd, "name");
  if (!key || !name) return fail("Clé et nom requis.");
  const supabase = await createClient();
  const { error } = await supabase.from("kpi_definitions").upsert({
    key, name, description: str(fd, "description"), formula: str(fd, "formula"), source: str(fd, "source"), unit: str(fd, "unit"), owner_id: str(fd, "owner_id"),
  }, { onConflict: "key" });
  if (error) return fail(error);
  refresh();
  return ok("Indicateur enregistré.");
}
