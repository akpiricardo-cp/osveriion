"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { fail, ok, str } from "@/lib/actions";
import type { ActionResult, MembershipRole, UnitDomain, UnitKind } from "@/lib/types";

const KINDS: UnitKind[] = ["company", "department", "subdepartment", "team"];
const DOMAINS: UnitDomain[] = [
  "direction", "operations", "technology", "product", "marketing", "business", "finance", "legal", "hr", "other",
];

function refresh(id?: string | null) {
  revalidatePath("/organisation");
  if (id) revalidatePath(`/organisation/${id}`);
}

export async function createUnit(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const name = str(fd, "name");
  const kind = str(fd, "kind") as UnitKind;
  if (!name || !KINDS.includes(kind)) return fail("Nom et type sont requis.");
  const domain = str(fd, "domain") as UnitDomain | null;
  const supabase = await createClient();
  const { data, error } = await supabase.from("org_units").insert({
    name, kind,
    parent_id: str(fd, "parent_id"),
    domain: domain && DOMAINS.includes(domain) ? domain : null,
    code: str(fd, "code")?.toUpperCase() ?? null,
    color: str(fd, "color") ?? "#4F46E5",
    description: str(fd, "description"),
    head_title: str(fd, "head_title"),
    deputy_title: str(fd, "deputy_title"),
    member_title: str(fd, "member_title"),
  }).select("id").single();
  if (error) return fail(error);
  refresh(str(fd, "parent_id"));
  return ok(`« ${name} » a été créé(e). Un canal interne a été ouvert.`, data);
}

export async function updateUnit(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const id = str(fd, "id");
  const name = str(fd, "name");
  if (!id || !name) return fail("Données incomplètes.");
  const supabase = await createClient();
  const patch: Record<string, unknown> = {
    name, description: str(fd, "description"), color: str(fd, "color") ?? "#4F46E5", code: str(fd, "code")?.toUpperCase() ?? null,
  };
  // Les intitulés de poste suivent l'unité : les changer renomme le poste de la
  // personne en place à sa prochaine nomination.
  for (const k of ["head_title", "deputy_title", "member_title"]) {
    if (fd.has(k)) patch[k] = str(fd, k);
  }
  const parent = fd.get("parent_id");
  if (parent !== null) patch.parent_id = str(fd, "parent_id");
  const domain = str(fd, "domain");
  if (domain && DOMAINS.includes(domain as UnitDomain)) patch.domain = domain;
  const kind = str(fd, "kind");
  if (kind && KINDS.includes(kind as UnitKind)) patch.kind = kind;
  const { error } = await supabase.from("org_units").update(patch).eq("id", id);
  if (error) return fail(error);
  refresh(id);
  return ok("Unité mise à jour.");
}

export async function archiveUnit(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { count } = await supabase.from("org_units").select("id", { count: "exact", head: true }).eq("parent_id", id).is("archived_at", null);
  if (count) return fail("Archivez ou déplacez d'abord les sous-unités.");
  const { error } = await supabase.from("org_units").update({ archived_at: new Date().toISOString() }).eq("id", id);
  if (error) return fail(error);
  refresh();
  return ok("Unité archivée. L'historique est conservé.");
}

export async function appointMember(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const unit = str(fd, "unit_id");
  const profile = str(fd, "profile_id");
  const role = (str(fd, "role") ?? "member") as MembershipRole;
  if (!unit || !profile) return fail("Choisissez une personne.");
  const supabase = await createClient();
  const { error } = await supabase.rpc("appoint_member", {
    p_unit: unit, p_profile: profile, p_role: role, p_title: str(fd, "title"), p_start: str(fd, "start_date") ?? new Date().toISOString().slice(0, 10),
  });
  if (error) return fail(error);
  refresh(unit);
  revalidatePath(`/annuaire/${profile}`);
  return ok(role === "head" ? "Responsable nommé. Ses droits ont été mis à jour automatiquement." : "Affectation enregistrée.");
}

export async function endMembership(membershipId: string, unitId: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("end_membership", { p_membership: membershipId });
  if (error) return fail(error);
  refresh(unitId);
  return ok("Affectation clôturée. Elle reste visible dans l'historique.");
}

/**
 * Fusionne deux unités : membres, sous-unités, canaux, budgets et dossiers
 * rejoignent l'unité d'accueil, la source est archivée. Réservé au CEO.
 */
export async function mergeUnits(sourceId: string, targetId: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("merge_org_units", { p_source: sourceId, p_target: targetId });
  if (error) return fail(error);
  revalidatePath("/organisation", "layout");
  revalidatePath("/annuaire");
  return ok("Unités fusionnées. L'unité absorbée est archivée, son historique reste consultable.");
}

/** Désigne le référent d'un département pour un projet (point de contact du chef de projet). */
export async function setLiaison(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const projectId = str(fd, "project_id");
  const unitId = str(fd, "unit_id");
  const profileId = str(fd, "profile_id");
  if (!projectId || !unitId) return fail("Projet ou département manquant.");
  const supabase = await createClient();
  if (!profileId) {
    const { error } = await supabase.from("project_liaisons").delete().eq("project_id", projectId).eq("unit_id", unitId);
    if (error) return fail(error);
    revalidatePath("/organisation");
    revalidatePath(`/projets/${projectId}`);
    return ok("Référent retiré.");
  }
  const { error } = await supabase
    .from("project_liaisons")
    .upsert({ project_id: projectId, unit_id: unitId, profile_id: profileId, note: str(fd, "note") }, { onConflict: "project_id,unit_id" });
  if (error) return fail(error);
  revalidatePath("/organisation");
  revalidatePath(`/projets/${projectId}`);
  return ok("Référent désigné : il rejoint le canal du projet et en est informé.");
}
