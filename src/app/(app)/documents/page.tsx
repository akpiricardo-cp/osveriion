import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getContext } from "@/lib/auth";
import { getPeople, getUnits } from "@/lib/data";
import type { DriveDoc, Folder, Listing, Space } from "@/lib/drive";
import { Forbidden } from "@/components/ui/misc";
import { DriveView, type DriveMode } from "./drive-view";

export const metadata = { title: "Documents" };

export default async function DrivePage({ searchParams }: { searchParams: Promise<{ dossier?: string; vue?: string; q?: string; doc?: string }> }) {
  const sp = await searchParams;
  if (sp.doc) redirect(`/documents/d/${sp.doc}`);
  const ctx = await getContext();
  const supabase = await createClient();
  const [{ data: spacesData }, { data: favs }, people, units] = await Promise.all([
    supabase.rpc("my_drive_spaces"),
    supabase.from("drive_favorites").select("folder_id, document_id").eq("profile_id", ctx.userId),
    getPeople(),
    getUnits(),
  ]);
  const spaces = (spacesData as Space[]) ?? [];
  const personal = spaces.find((s) => s.space === "personal");
  const favorites = { folders: (favs ?? []).map((f) => f.folder_id).filter(Boolean) as string[], documents: (favs ?? []).map((f) => f.document_id).filter(Boolean) as string[] };

  let mode: DriveMode = "folder";
  let listing: Listing | null = null;
  let folders: Folder[] = [];
  let documents: DriveDoc[] = [];
  const docCols = "id, title, description, category, classification, folder_id, kind, owner_id, updated_by, storage_path, file_name, mime_type, size_bytes, version, revision, tags, created_at, updated_at, deleted_at";

  if (sp.vue === "partages") {
    mode = "shared";
    const { data } = await supabase.rpc("shared_with_me");
    const rows = (data ?? []) as { kind: string; id: string }[];
    const fIds = rows.filter((r) => r.kind === "folder").map((r) => r.id);
    const dIds = rows.filter((r) => r.kind === "document").map((r) => r.id);
    const [f, d] = await Promise.all([
      fIds.length ? supabase.from("folders").select("*").in("id", fIds) : Promise.resolve({ data: [] }),
      dIds.length ? supabase.from("documents").select(docCols).in("id", dIds) : Promise.resolve({ data: [] }),
    ]);
    folders = (f.data as Folder[]) ?? [];
    documents = (d.data as DriveDoc[]) ?? [];
  } else if (sp.vue === "recents") {
    mode = "recent";
    const { data } = await supabase.from("document_recents").select(`opened_at, documents(${docCols})`).eq("profile_id", ctx.userId).order("opened_at", { ascending: false }).limit(60);
    documents = ((data ?? []) as unknown as { documents: DriveDoc | null }[]).map((r) => r.documents).filter((d): d is DriveDoc => Boolean(d && !d.deleted_at));
  } else if (sp.vue === "favoris") {
    mode = "favorites";
    const [f, d] = await Promise.all([
      favorites.folders.length ? supabase.from("folders").select("*").in("id", favorites.folders).is("deleted_at", null) : Promise.resolve({ data: [] }),
      favorites.documents.length ? supabase.from("documents").select(docCols).in("id", favorites.documents).is("deleted_at", null) : Promise.resolve({ data: [] }),
    ]);
    folders = (f.data as Folder[]) ?? [];
    documents = (d.data as DriveDoc[]) ?? [];
  } else if (sp.vue === "corbeille") {
    mode = "trash";
    const [f, d] = await Promise.all([
      supabase.from("folders").select("*").not("deleted_at", "is", null).order("deleted_at", { ascending: false }).limit(200),
      supabase.from("documents").select(docCols).not("deleted_at", "is", null).order("deleted_at", { ascending: false }).limit(200),
    ]);
    const trashedFolders = (f.data as Folder[]) ?? [];
    const ids = new Set(trashedFolders.map((x) => x.id));
    folders = trashedFolders.filter((x) => !x.parent_id || !ids.has(x.parent_id));
    documents = ((d.data as DriveDoc[]) ?? []).filter((x) => !x.folder_id || !ids.has(x.folder_id));
  } else if (sp.q && sp.q.trim().length > 1) {
    mode = "search";
    const q = sp.q.trim();
    const [f, d] = await Promise.all([
      supabase.from("folders").select("*").is("deleted_at", null).ilike("name", `%${q.replace(/[%_]/g, "")}%`).limit(40),
      supabase.from("documents").select(docCols).is("deleted_at", null).textSearch("search", q, { type: "websearch", config: "french" }).limit(80),
    ]);
    folders = (f.data as Folder[]) ?? [];
    documents = (d.data as DriveDoc[]) ?? [];
    if (!documents.length) {
      const { data: byTitle } = await supabase.from("documents").select(docCols).is("deleted_at", null).ilike("title", `%${q.replace(/[%_]/g, "")}%`).limit(80);
      documents = (byTitle as DriveDoc[]) ?? [];
    }
  } else {
    const folderId = sp.dossier ?? personal?.id;
    if (!folderId) return <Forbidden message="Aucun espace documentaire disponible pour votre compte." />;
    const { data, error } = await supabase.rpc("drive_listing", { p_folder: folderId });
    if (error || !data) return <Forbidden message="Ce dossier n'existe pas ou ne vous est pas accessible." />;
    listing = data as Listing;
    folders = listing.folders;
    documents = listing.documents;
  }

  return (
    <DriveView
      mode={mode}
      spaces={spaces}
      listing={listing}
      folders={folders}
      documents={documents}
      favorites={favorites}
      people={people}
      units={units.map((u) => ({ id: u.id, name: u.name, color: u.color, depth: u.depth }))}
      userId={ctx.userId}
      query={sp.q ?? ""}
    />
  );
}
