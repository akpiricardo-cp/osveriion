"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { bool, fail, numVal, ok, str } from "@/lib/actions";
import type { ActionResult, Priority, ProjectStatus, TaskStatus } from "@/lib/types";

const TASK_STATUSES: TaskStatus[] = ["backlog", "todo", "in_progress", "review", "done"];
const PRIORITIES: Priority[] = ["low", "medium", "high", "urgent"];
const PROJECT_STATUSES: ProjectStatus[] = ["planned", "active", "on_hold", "completed", "cancelled"];

function refresh(projectId?: string | null) {
  revalidatePath("/projets");
  revalidatePath("/taches");
  revalidatePath("/");
  if (projectId) revalidatePath(`/projets/${projectId}`);
}

// ───────────────────────────── Projets ─────────────────────────────
export async function createProject(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const name = str(fd, "name");
  if (!name) return fail("Le nom du projet est requis.");
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const status = str(fd, "status") as ProjectStatus;
  const { data, error } = await supabase.from("projects").insert({
    name,
    description: str(fd, "description"),
    unit_id: str(fd, "unit_id"),
    status: PROJECT_STATUSES.includes(status) ? status : "planned",
    priority: (str(fd, "priority") as Priority) ?? "medium",
    start_date: str(fd, "start_date"),
    due_date: str(fd, "due_date"),
    budget: numVal(fd, "budget"),
    color: str(fd, "color") ?? "#4F46E5",
    owner_id: user!.id,
  }).select("id").single();
  if (error) return fail(error);
  refresh();
  return ok("Projet créé. Un canal de discussion dédié est disponible.", data);
}

export async function updateProject(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const id = str(fd, "id");
  if (!id) return fail("Projet manquant.");
  const supabase = await createClient();
  const status = str(fd, "status") as ProjectStatus;
  const { error } = await supabase.from("projects").update({
    name: str(fd, "name"),
    description: str(fd, "description"),
    unit_id: str(fd, "unit_id"),
    status: PROJECT_STATUSES.includes(status) ? status : undefined,
    priority: str(fd, "priority") ?? undefined,
    start_date: str(fd, "start_date"),
    due_date: str(fd, "due_date"),
    budget: numVal(fd, "budget"),
    color: str(fd, "color") ?? undefined,
    owner_id: str(fd, "owner_id") ?? undefined,
  }).eq("id", id);
  if (error) return fail(error);
  refresh(id);
  return ok("Projet mis à jour.");
}

export async function archiveProject(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("projects").update({ archived_at: new Date().toISOString() }).eq("id", id);
  if (error) return fail(error);
  refresh(id);
  return ok("Projet archivé.");
}

export async function setProjectMember(projectId: string, profileId: string, role: "lead" | "member" | "viewer" | null): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = role
    ? await supabase.from("project_members").upsert({ project_id: projectId, profile_id: profileId, role })
    : await supabase.from("project_members").delete().eq("project_id", projectId).eq("profile_id", profileId);
  if (error) return fail(error);
  refresh(projectId);
  return ok(role ? "Membre mis à jour." : "Membre retiré.");
}

// ───────────────────────────── Tâches ─────────────────────────────
export async function createTask(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const title = str(fd, "title");
  if (!title) return fail("Le titre est requis.");
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const status = (str(fd, "status") ?? "todo") as TaskStatus;
  const prio = (str(fd, "priority") ?? "medium") as Priority;
  const projectId = str(fd, "project_id");
  const { data, error } = await supabase.from("tasks").insert({
    title,
    project_id: projectId,
    parent_id: str(fd, "parent_id"),
    description: str(fd, "description"),
    status: TASK_STATUSES.includes(status) ? status : "todo",
    priority: PRIORITIES.includes(prio) ? prio : "medium",
    assignee_id: str(fd, "assignee_id") ?? (projectId ? null : user!.id),
    due_date: str(fd, "due_date"),
    start_date: str(fd, "start_date"),
    estimate_hours: numVal(fd, "estimate_hours"),
    requires_validation: bool(fd, "requires_validation"),
    objective_id: str(fd, "objective_id"),
    reporter_id: user!.id,
    position: Date.now() / 1000,
  }).select("id").single();
  if (error) return fail(error);
  refresh(projectId);
  return ok("Tâche créée.", data);
}

export type TaskPatch = Partial<{
  title: string; description: string | null; status: TaskStatus; priority: Priority; assignee_id: string | null;
  due_date: string | null; start_date: string | null; estimate_hours: number | null; requires_validation: boolean;
  position: number; objective_id: string | null;
}>;

export async function updateTask(id: string, patch: TaskPatch, projectId?: string | null): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("tasks").update(patch).eq("id", id);
  if (error) return fail(error);
  refresh(projectId);
  return ok();
}

export async function deleteTask(id: string, projectId?: string | null): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("tasks").delete().eq("id", id);
  if (error) return fail(error);
  refresh(projectId);
  return ok("Tâche supprimée.");
}

export async function addDependency(taskId: string, dependsOn: string, projectId?: string | null): Promise<ActionResult> {
  if (taskId === dependsOn) return fail("Une tâche ne peut pas dépendre d'elle-même.");
  const supabase = await createClient();
  // Empêche les cycles simples (A dépend de B et B dépend de A)
  const { data: reverse } = await supabase.from("task_dependencies").select("task_id").eq("task_id", dependsOn).eq("depends_on_id", taskId);
  if (reverse?.length) return fail("Dépendance circulaire détectée.");
  const { error } = await supabase.from("task_dependencies").insert({ task_id: taskId, depends_on_id: dependsOn });
  if (error) return fail(error);
  refresh(projectId);
  return ok("Dépendance ajoutée.");
}

export async function removeDependency(taskId: string, dependsOn: string, projectId?: string | null): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("task_dependencies").delete().eq("task_id", taskId).eq("depends_on_id", dependsOn);
  if (error) return fail(error);
  refresh(projectId);
  return ok();
}

export async function addComment(taskId: string, body: string): Promise<ActionResult> {
  const text = body.trim();
  if (!text) return fail("Commentaire vide.");
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const { error } = await supabase.from("task_comments").insert({ task_id: taskId, body: text, author_id: user!.id });
  if (error) return fail(error);
  return ok();
}
