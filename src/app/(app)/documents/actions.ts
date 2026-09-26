"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { explain, fail, ok } from "@/lib/actions";
import { defaultContent, type DocKind, type ShareRole } from "@/lib/drive";
import type { ActionResult, DocCategory, DocClassification } from "@/lib/types";

function refresh(docId?: string) {
  revalidatePath("/documents", "layout");
  if (docId) revalidatePath(`/documents/d/${docId}`);
}

async function me() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Session expirée");
  return { supabase, userId: user.id };
}

// ─── Dossiers ───────────────────────────────────────────────────────────────
export async function createFolder(parentId: string, name: string): Promise<ActionResult> {
  const clean = name.trim();
  if (!clean) return fail("Nom requis.");
  const { supabase, userId } = await me();
  const { data: parent } = await supabase.from("folders").select("space").eq("id", parentId).single();
  const { data, error } = await supabase.from("folders")
    .insert({ parent_id: parentId, name: clean, space: parent?.space ?? "personal", created_by: userId })
    .select("id").single();
  if (error) return fail(error.code === "23505" ? "Un dossier porte déjà ce nom ici." : error);
  refresh();
  return ok("Dossier créé.", data);
}

export async function renameFolder(id: string, name: string): Promise<ActionResult> {
  const clean = name.trim();
  if (!clean) return fail("Nom requis.");
  const { supabase } = await me();
  const { error } = await supabase.from("folders").update({ name: clean }).eq("id", id);
  if (error) return fail(error.code === "23505" ? "Un dossier porte déjà ce nom ici." : error);
  refresh();
  return ok("Dossier renommé.");
}

export async function moveFolder(id: string, parentId: string): Promise<ActionResult> {
  if (id === parentId) return fail("Destination invalide.");
  const { supabase } = await me();
  const { error } = await supabase.from("folders").update({ parent_id: parentId }).eq("id", id);
  if (error) return fail(error.code === "23505" ? "Un dossier porte déjà ce nom à destination." : error);
  refresh();
  return ok("Dossier déplacé.");
}

// ─── Documents ──────────────────────────────────────────────────────────────
export async function createNativeDocument(folderId: string, kind: Exclude<DocKind, "file">, title?: string, content?: unknown, text?: string): Promise<ActionResult> {
  const { supabase, userId } = await me();
  const defaultTitles = { doc: "Document sans titre", sheet: "Tableur sans titre", slides: "Présentation sans titre" };
  const t = title?.trim() || defaultTitles[kind];
  const category: DocCategory = kind === "slides" ? "presentation" : "other";
  const { data, error } = await supabase.from("documents").insert({
    title: t, kind, folder_id: folderId, owner_id: userId, updated_by: userId, category,
    content: content ?? defaultContent(kind, t), content_text: text ?? null,
  }).select("id").single();
  if (error) return fail(error);
  refresh();
  return ok("Document créé.", data);
}

export async function registerFile(input: {
  folderId: string; title: string; storagePath: string; fileName: string; mime: string; size: number;
}): Promise<ActionResult> {
  const { supabase, userId } = await me();
  const { data, error } = await supabase.from("documents").insert({
    title: input.title, kind: "file", folder_id: input.folderId, owner_id: userId, updated_by: userId,
    storage_path: input.storagePath, file_name: input.fileName, mime_type: input.mime || null, size_bytes: input.size,
  }).select("id").single();
  if (error) {
    await supabase.storage.from("documents").remove([input.storagePath]);
    return fail(error);
  }
  refresh();
  return ok(undefined, data);
}

export async function replaceFile(docId: string, input: { storagePath: string; fileName: string; mime: string; size: number; note?: string }): Promise<ActionResult> {
  const { supabase } = await me();
  const { error } = await supabase.rpc("replace_document_file", {
    p_doc: docId, p_storage_path: input.storagePath, p_file_name: input.fileName, p_mime: input.mime || null, p_size: input.size, p_note: input.note ?? null,
  });
  if (error) return fail(error);
  refresh(docId);
  return ok("Nouvelle version publiée. L'ancienne reste disponible dans l'historique.");
}

export async function updateDocument(docId: string, patch: {
  title?: string; description?: string | null; classification?: DocClassification; category?: DocCategory; tags?: string[];
}): Promise<ActionResult> {
  const { supabase } = await me();
  if (patch.title !== undefined && !patch.title.trim()) return fail("Titre requis.");
  const { error } = await supabase.from("documents").update(patch).eq("id", docId);
  if (error) return fail(error);
  refresh(docId);
  return ok();
}

export async function moveDocument(docId: string, folderId: string): Promise<ActionResult> {
  const { supabase } = await me();
  const { error } = await supabase.from("documents").update({ folder_id: folderId }).eq("id", docId);
  if (error) return fail(error);
  refresh(docId);
  return ok("Document déplacé.");
}

export async function duplicateDocument(docId: string): Promise<ActionResult> {
  const { supabase } = await me();
  const { data, error } = await supabase.rpc("duplicate_document", { p_doc: docId, p_folder: null });
  if (error) return fail(error);
  // Un fichier dupliqué partage le même contenu stocké : on copie le fichier.
  const { data: src } = await supabase.from("documents").select("storage_path, file_name").eq("id", docId).single();
  if (src?.storage_path) {
    const { data: { user } } = await supabase.auth.getUser();
    const dest = `${user!.id}/${crypto.randomUUID()}-${src.file_name ?? "copie"}`;
    const { error: e2 } = await supabase.storage.from("documents").copy(src.storage_path, dest);
    if (!e2) await supabase.from("documents").update({ storage_path: dest }).eq("id", data);
  }
  refresh();
  return ok("Copie créée.", { id: data });
}

export async function saveContent(docId: string, content: unknown, text: string, baseRevision: number | null, snapshot = false, note?: string): Promise<ActionResult<{ revision: number }>> {
  const { supabase } = await me();
  const { data, error } = await supabase.rpc("save_document_content", {
    p_doc: docId, p_content: content, p_text: text, p_base_revision: baseRevision, p_snapshot: snapshot, p_note: note ?? null,
  });
  if (error) {
    if (error.code === "40001") return { ok: false, error: "conflict" };
    return { ok: false, error: explain(error) };
  }
  if (snapshot) revalidatePath(`/documents/d/${docId}`);
  return { ok: true, data: { revision: data as number } };
}

export async function restoreVersion(versionId: string, docId: string): Promise<ActionResult> {
  const { supabase } = await me();
  const { error } = await supabase.rpc("restore_document_version", { p_version: versionId });
  if (error) return fail(error);
  refresh(docId);
  return ok("Version restaurée. L'état précédent a été conservé dans l'historique.");
}

export async function touchRecent(docId: string) {
  const { supabase, userId } = await me();
  await supabase.from("document_recents").upsert({ profile_id: userId, document_id: docId, opened_at: new Date().toISOString() });
}

// ─── Corbeille ──────────────────────────────────────────────────────────────
export async function trashItem(kind: "folder" | "document", id: string): Promise<ActionResult> {
  const { supabase } = await me();
  const { error } = await supabase.rpc("trash_item", kind === "folder" ? { p_folder: id, p_doc: null } : { p_folder: null, p_doc: id });
  if (error) return fail(error);
  refresh();
  return ok("Placé dans la corbeille (30 jours).");
}

export async function restoreItem(kind: "folder" | "document", id: string): Promise<ActionResult> {
  const { supabase } = await me();
  const { error } = await supabase.rpc("restore_item", kind === "folder" ? { p_folder: id, p_doc: null } : { p_folder: null, p_doc: id });
  if (error) return fail(error);
  refresh();
  return ok("Élément restauré.");
}

export async function deleteForever(kind: "folder" | "document", id: string): Promise<ActionResult> {
  const { supabase } = await me();
  if (kind === "document") {
    const { data: doc } = await supabase.from("documents").select("storage_path").eq("id", id).single();
    const { data: versions } = await supabase.from("document_versions").select("storage_path").eq("document_id", id).not("storage_path", "is", null);
    const { error } = await supabase.from("documents").delete().eq("id", id);
    if (error) return fail(error);
    const paths = [doc?.storage_path, ...(versions ?? []).map((v) => v.storage_path)].filter(Boolean) as string[];
    if (paths.length) await supabase.storage.from("documents").remove(paths);
  } else {
    const { error } = await supabase.from("folders").delete().eq("id", id);
    if (error) return fail(error);
  }
  refresh();
  return ok("Supprimé définitivement.");
}

// ─── Partages & favoris ─────────────────────────────────────────────────────
export async function addShare(target: { folderId?: string; documentId?: string }, who: { profileId?: string; unitId?: string }, role: ShareRole, expiresInDays?: number): Promise<ActionResult> {
  const { supabase, userId } = await me();
  const { error } = await supabase.from("shares").upsert({
    folder_id: target.folderId ?? null, document_id: target.documentId ?? null,
    profile_id: who.profileId ?? null, unit_id: who.unitId ?? null, role, created_by: userId,
    expires_at: expiresInDays ? new Date(Date.now() + expiresInDays * 86400000).toISOString() : null,
  });
  if (error) return fail(error.code === "23505" ? "Déjà partagé avec cette personne ou cette unité." : error);
  refresh(target.documentId);
  return ok("Partage enregistré.");
}

export async function updateShareRole(id: string, role: ShareRole): Promise<ActionResult> {
  const { supabase } = await me();
  const { error } = await supabase.from("shares").update({ role }).eq("id", id);
  if (error) return fail(error);
  refresh();
  return ok("Droit modifié.");
}

export async function removeShare(id: string): Promise<ActionResult> {
  const { supabase } = await me();
  const { error } = await supabase.from("shares").delete().eq("id", id);
  if (error) return fail(error);
  refresh();
  return ok("Accès retiré.");
}

export async function toggleFavorite(target: { folderId?: string; documentId?: string }, on: boolean): Promise<ActionResult> {
  const { supabase, userId } = await me();
  const q = supabase.from("drive_favorites");
  const { error } = on
    ? await q.insert({ profile_id: userId, folder_id: target.folderId ?? null, document_id: target.documentId ?? null })
    : target.folderId
      ? await q.delete().eq("profile_id", userId).eq("folder_id", target.folderId)
      : await q.delete().eq("profile_id", userId).eq("document_id", target.documentId!);
  if (error && error.code !== "23505") return fail(error);
  refresh(target.documentId);
  return ok(on ? "Ajouté aux favoris." : "Retiré des favoris.");
}
