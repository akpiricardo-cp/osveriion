"use client";

import { createClient } from "@/lib/supabase/client";
import { safeFileName } from "@/lib/drive";
import { registerFile, replaceFile } from "@/app/(app)/documents/actions";

export const MAX_UPLOAD = 50 * 1024 * 1024;

async function put(file: File, userId: string) {
  if (file.size > MAX_UPLOAD) throw new Error(`« ${file.name} » dépasse 50 Mo.`);
  const path = `${userId}/${crypto.randomUUID()}-${safeFileName(file.name)}`;
  const { error } = await createClient().storage.from("documents").upload(path, file, { contentType: file.type || undefined, upsert: false });
  if (error) throw new Error(`Échec du dépôt de « ${file.name} » : ${error.message}`);
  return path;
}

export async function uploadToFolder(file: File, folderId: string, userId: string) {
  const path = await put(file, userId);
  const title = file.name.replace(/\.[^.]+$/, "") || file.name;
  const r = await registerFile({ folderId, title, storagePath: path, fileName: file.name, mime: file.type, size: file.size });
  if (!r.ok) throw new Error(r.error);
  return (r.data as { id: string }).id;
}

export async function uploadNewVersion(file: File, docId: string, userId: string, note?: string) {
  const path = await put(file, userId);
  const r = await replaceFile(docId, { storagePath: path, fileName: file.name, mime: file.type, size: file.size, note });
  if (!r.ok) throw new Error(r.error);
}

/** Dépose une image insérée dans un document natif (compartiment doc-assets). */
export async function uploadDocAsset(file: File, docId: string) {
  if (!file.type.startsWith("image/")) throw new Error("Seules les images peuvent être insérées.");
  if (file.size > 10 * 1024 * 1024) throw new Error("Image trop lourde (10 Mo max).");
  const path = `${docId}/${crypto.randomUUID()}-${safeFileName(file.name)}`;
  const { error } = await createClient().storage.from("doc-assets").upload(path, file, { contentType: file.type });
  if (error) throw new Error(error.message);
  return `/api/storage/doc-assets/${path.split("/").map(encodeURIComponent).join("/")}`;
}
