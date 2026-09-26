import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getContext } from "@/lib/auth";
import { getPeople, getUnits } from "@/lib/data";
import type { DriveDoc, FolderSpace } from "@/lib/drive";
import { Forbidden } from "@/components/ui/misc";
import { EditorLoader } from "@/components/editors/editor-loader";
import type { EditorMeta } from "@/components/editors/editor-shell";
import { touchRecent } from "../../actions";

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const { data } = await supabase.from("documents").select("title").eq("id", id).maybeSingle();
  return { title: data?.title ?? "Document" };
}

export default async function DocumentPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const ctx = await getContext();
  const supabase = await createClient();
  const { data } = await supabase.from("documents").select("*").eq("id", id).maybeSingle();
  if (!data) notFound();
  const { content, ...rest } = data as DriveDoc & { content: unknown };
  const doc = rest as DriveDoc;
  if (doc.deleted_at) return <Forbidden message="Ce document est dans la corbeille. Restaurez-le depuis Documents › Corbeille." />;

  const [{ data: access }, { data: folder }, people, units, , { data: ystate }] = await Promise.all([
    supabase.rpc("document_access", { p_doc: id }),
    doc.folder_id ? supabase.from("folders").select("id, name, space, is_root").eq("id", doc.folder_id).maybeSingle() : Promise.resolve({ data: null }),
    getPeople(),
    getUnits(),
    touchRecent(id),
    doc.kind === "doc" ? supabase.from("document_ydocs").select("state, revision").eq("document_id", id).maybeSingle() : Promise.resolve({ data: null }),
  ]);
  // L'état Yjs n'est utilisé que s'il correspond à la dernière révision enregistrée
  const ydoc = ystate && ystate.revision === doc.revision ? (ystate.state as string) : null;

  const meta: EditorMeta = {
    doc,
    access: (access as number) ?? 1,
    folder: folder ? { id: folder.id, name: folder.is_root && folder.space === "personal" ? "Mon espace" : folder.name, space: folder.space as FolderSpace } : null,
    people,
    units: units.map((u) => ({ id: u.id, name: u.name, color: u.color, depth: u.depth })),
    userId: ctx.userId,
  };
  const me = { id: ctx.userId, name: ctx.profile.full_name, avatar: ctx.profile.avatar_url };

  return <EditorLoader key={doc.id + doc.version} kind={doc.kind} meta={meta} initial={content} ydoc={ydoc} me={me} />;
}
