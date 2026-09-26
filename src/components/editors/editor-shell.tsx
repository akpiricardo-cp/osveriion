"use client";

import { useEffect, useRef, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  AlertTriangle, ArrowLeft, Check, CloudOff, Copy, Download, History, Info, Loader2, MoreHorizontal, RotateCcw, Share2, Trash2,
} from "lucide-react";
import { toast } from "sonner";
import { createClient } from "@/lib/supabase/client";
import { Avatar } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Sheet } from "@/components/ui/dialog";
import { Dropdown, DropdownContent, DropdownItem, DropdownLabel, DropdownSeparator, DropdownTrigger } from "@/components/ui/dropdown";
import { Input, Select, Textarea } from "@/components/ui/input";
import { DocIcon } from "@/components/drive/icons";
import { ShareDialog, type UnitLite } from "@/components/drive/dialogs";
import { humanSize, storageUrl, type DriveDoc, type FolderSpace } from "@/lib/drive";
import { classification as classLabels, docCategory } from "@/lib/labels";
import type { DocCategory, DocClassification, ProfileLite } from "@/lib/types";
import { cn, dateTimeFr, relative } from "@/lib/utils";
import { duplicateDocument, restoreVersion, trashItem, updateDocument } from "@/app/(app)/documents/actions";
import type { SyncStatus, Viewer } from "./use-doc-sync";

export interface EditorMeta {
  doc: DriveDoc;
  access: number;
  folder: { id: string; name: string; space: FolderSpace } | null;
  people: ProfileLite[];
  units: UnitLite[];
  userId: string;
}

type Version = { id: string; revision: number; title: string; note: string | null; created_by: string | null; created_at: string; storage_path: string | null; file_name: string | null; size_bytes: number | null };

export function EditorShell({
  meta, status, viewers, lastSaved, remoteEditor, onReload, onForceSave, onSnapshot, onRestored, live, exportItems, toolbar, children, wide,
}: {
  meta: EditorMeta;
  status?: SyncStatus;
  viewers?: Viewer[];
  lastSaved?: Date | null;
  remoteEditor?: string | null;
  onReload?: () => void;
  onForceSave?: () => void;
  onSnapshot?: (note: string) => Promise<boolean>;
  /** Après restauration d'une version (co-édition : tout le monde recharge). */
  onRestored?: () => void;
  /** Co-édition active (connexion temps réel établie). */
  live?: boolean;
  exportItems?: React.ReactNode;
  toolbar?: React.ReactNode;
  children: React.ReactNode;
  wide?: boolean;
}) {
  const { doc, access, folder } = meta;
  const router = useRouter();
  const [title, setTitle] = useState(doc.title);
  const [share, setShare] = useState(false);
  const [history, setHistory] = useState(false);
  const [pending, start] = useTransition();
  const canEdit = access >= 2;
  const back = folder ? `/documents?dossier=${folder.id}` : "/documents";

  useEffect(() => setTitle(doc.title), [doc.title]);

  // Document tout juste créé : on propose de le nommer immédiatement
  const titleRef = useRef<HTMLInputElement>(null);
  useEffect(() => {
    if (canEdit && doc.revision <= 1 && / sans titre$/.test(doc.title)) { titleRef.current?.focus(); titleRef.current?.select(); }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [doc.id]);

  return (
    <div className={cn("-mx-4 -mt-6 sm:-mx-6 lg:-mx-8 lg:-mt-8", "print:m-0")}>
      <div className="sticky top-16 z-20 border-b border-border bg-surface/95 backdrop-blur print:hidden">
        <div className="flex flex-wrap items-center gap-3 px-4 py-2.5 sm:px-6">
          <Link href={back} className="grid h-8 w-8 place-items-center rounded-lg text-muted hover:bg-surface-2 hover:text-fg" aria-label="Retour au dossier"><ArrowLeft className="h-4 w-4" /></Link>
          <DocIcon kind={doc.kind} mime={doc.mime_type} name={doc.file_name} size="sm" />
          <div className="min-w-0 flex-1">
            <input
              ref={titleRef}
              aria-label="Titre du document"
              value={title}
              readOnly={!canEdit}
              onChange={(e) => setTitle(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter") (e.target as HTMLInputElement).blur(); }}
              onBlur={() => {
                const t = title.trim();
                if (!t) return setTitle(doc.title);
                if (t !== doc.title) start(async () => { const r = await updateDocument(doc.id, { title: t }); if (!r.ok) toast.error(r.error); else router.refresh(); });
              }}
              className="w-full max-w-xl truncate rounded-md bg-transparent px-1 text-[15px] font-semibold text-fg outline-none hover:bg-surface-2 focus:bg-surface-2"
            />
            <div className="flex min-w-0 items-center gap-2 whitespace-nowrap px-1 text-xs text-subtle">
              {folder && <Link href={back} className="truncate hover:text-fg">{folder.space === "personal" && folder.name === "Mon espace" ? "Mon espace" : folder.name}</Link>}
              <span>·</span>
              <StatusLabel status={status} lastSaved={lastSaved} access={access} />
              {doc.classification !== "internal" && <Badge tone={classLabels[doc.classification].tone}>{classLabels[doc.classification].label}</Badge>}
            </div>
          </div>
          {viewers && viewers.length > 0 && (
            <div className="flex items-center gap-2">
            {live && <span className="hidden items-center gap-1.5 rounded-full bg-emerald-500/10 px-2 py-0.5 text-[11px] font-medium text-emerald-700 sm:flex dark:text-emerald-300"><span className="h-1.5 w-1.5 animate-pulse rounded-full bg-emerald-500" /> En direct</span>}
            <div className="flex -space-x-2" title={viewers.map((v) => `${v.name} ${v.editor ? "modifie" : "consulte"}`).join(" · ")}>
              {viewers.slice(0, 4).map((v) => (
                <span key={v.id} className="rounded-full ring-2" style={{ ["--tw-ring-color" as string]: v.color }}>
                  <Avatar name={v.name} src={v.avatar} size="xs" />
                </span>
              ))}
              {viewers.length > 4 && <span className="grid h-6 w-6 place-items-center rounded-full bg-surface-2 text-[10px] font-semibold text-muted ring-2 ring-surface">+{viewers.length - 4}</span>}
            </div>
            </div>
          )}
          <div className="flex items-center gap-1.5">
            <Button size="sm" variant="ghost" onClick={() => setHistory(true)}><History className="h-4 w-4" /><span className="hidden md:inline">Historique</span></Button>
            {exportItems && (
              <Dropdown>
                <DropdownTrigger asChild><Button size="sm" variant="outline"><Download className="h-4 w-4" /><span className="hidden md:inline">Exporter</span></Button></DropdownTrigger>
                <DropdownContent className="w-56"><DropdownLabel>Télécharger au format</DropdownLabel>{exportItems}</DropdownContent>
              </Dropdown>
            )}
            {access >= 2 && <Button size="sm" onClick={() => setShare(true)}><Share2 className="h-4 w-4" /> Partager</Button>}
            <Dropdown>
              <DropdownTrigger className="grid h-8 w-8 place-items-center rounded-lg text-muted hover:bg-surface-2" aria-label="Plus"><MoreHorizontal className="h-4 w-4" /></DropdownTrigger>
              <DropdownContent>
                <DropdownItem onSelect={() => start(async () => { const r = await duplicateDocument(doc.id); if (r.ok) router.push(`/documents/d/${(r.data as { id: string }).id}`); else toast.error(r.error); })}><Copy className="h-4 w-4 text-subtle" /> Dupliquer</DropdownItem>
                <DropdownItem onSelect={() => setHistory(true)}><Info className="h-4 w-4 text-subtle" /> Informations</DropdownItem>
                {canEdit && (
                  <>
                    <DropdownSeparator />
                    <DropdownItem danger onSelect={() => start(async () => { const r = await trashItem("document", doc.id); if (r.ok) { toast.success(r.message); router.push(back); } else toast.error(r.error); })}>
                      <Trash2 className="h-4 w-4" /> Mettre à la corbeille
                    </DropdownItem>
                  </>
                )}
              </DropdownContent>
            </Dropdown>
          </div>
        </div>
        {toolbar && <div className="border-t border-border px-2 sm:px-4">{toolbar}</div>}
        {status === "conflict" && (
          <div className="flex flex-wrap items-center gap-3 border-t border-amber-500/30 bg-amber-500/10 px-6 py-2 text-sm text-fg">
            <AlertTriangle className="h-4 w-4 text-amber-600" />
            <span className="flex-1">{remoteEditor ? `${remoteEditor} vient d'enregistrer une version plus récente.` : "Ce document a été modifié ailleurs pendant que vous écriviez."}</span>
            <Button size="sm" variant="outline" onClick={onReload}><RotateCcw className="h-4 w-4" /> Charger leur version</Button>
            <Button size="sm" onClick={onForceSave}>Garder la mienne</Button>
          </div>
        )}
      </div>

      <div className={cn("px-4 py-6 sm:px-6", wide ? "" : "mx-auto max-w-[1100px]")}>{children}</div>

      <ShareDialog open={share} onOpenChange={setShare} target={{ documentId: doc.id }} name={doc.title} space={folder?.space}
        people={meta.people.filter((p) => p.id !== meta.userId)} units={meta.units} access={access} />
      <HistorySheet open={history} onOpenChange={setHistory} meta={meta} onRestored={() => { if (onRestored) onRestored(); else { onReload?.(); router.refresh(); } }} onSnapshot={onSnapshot} />
      {pending && <Loader2 className="fixed bottom-6 right-6 h-5 w-5 animate-spin text-primary" />}
    </div>
  );
}

function StatusLabel({ status, lastSaved, access }: { status?: SyncStatus; lastSaved?: Date | null; access: number }) {
  if (access < 2 || status === "readonly") return <span className="truncate">Lecture seule<span className="hidden sm:inline"> · vous pouvez consulter et exporter</span></span>;
  switch (status) {
    case "saving": return <span className="flex items-center gap-1"><Loader2 className="h-3 w-3 animate-spin" /> Enregistrement…</span>;
    case "dirty": return <span>Modifications non enregistrées</span>;
    case "live": return <span className="flex items-center gap-1"><span className="h-1.5 w-1.5 rounded-full bg-emerald-500" /> Synchronisé en direct</span>;
    case "error": return <span className="flex items-center gap-1 text-danger"><CloudOff className="h-3 w-3" /> Échec de l&apos;enregistrement — nouvel essai à la prochaine modification</span>;
    case "conflict": return <span className="text-amber-600">Conflit de version</span>;
    case "saved": return <span className="flex items-center gap-1"><Check className="h-3 w-3 text-emerald-500" /> {lastSaved ? `Enregistré ${relative(lastSaved)}` : "Tout est enregistré"}</span>;
    default: return null;
  }
}

function HistorySheet({ open, onOpenChange, meta, onRestored, onSnapshot }: { open: boolean; onOpenChange: (o: boolean) => void; meta: EditorMeta; onRestored: () => void; onSnapshot?: (note: string) => Promise<boolean> }) {
  const { doc, access } = meta;
  const [versions, setVersions] = useState<Version[] | null>(null);
  const [note, setNote] = useState("");
  const [desc, setDesc] = useState(doc.description ?? "");
  const [pending, start] = useTransition();
  const router = useRouter();
  const pm = new Map(meta.people.map((p) => [p.id, p]));
  const load = () => createClient().from("document_versions").select("*").eq("document_id", doc.id).order("created_at", { ascending: false }).limit(50)
    .then(({ data }) => setVersions((data as Version[]) ?? []));
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { if (open) load(); }, [open]);
  const canEdit = access >= 2;
  const save = (patch: Parameters<typeof updateDocument>[1]) => start(async () => { const r = await updateDocument(doc.id, patch); if (r.ok) { toast.success("Informations mises à jour."); router.refresh(); } else toast.error(r.error); });

  return (
    <Sheet open={open} onOpenChange={onOpenChange} title="Informations & historique" description={doc.title}>
      <div className="space-y-6 p-6">
        <section className="space-y-3">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <p className="mb-1 text-xs font-medium text-muted">Confidentialité</p>
              <Select value={doc.classification} disabled={access < 3} onChange={(e) => save({ classification: e.target.value as DocClassification })}>
                {Object.entries(classLabels).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
              </Select>
            </div>
            <div>
              <p className="mb-1 text-xs font-medium text-muted">Catégorie</p>
              <Select value={doc.category} disabled={!canEdit} onChange={(e) => save({ category: e.target.value as DocCategory })}>
                {Object.entries(docCategory).map(([k, l]) => <option key={k} value={k}>{l}</option>)}
              </Select>
            </div>
          </div>
          <p className="text-xs text-subtle">
            Interne : accès du dossier · Restreint : éditeurs et gestionnaires du dossier uniquement · Confidentiel : gestionnaires, auteur et personnes invitées.
          </p>
          <div>
            <p className="mb-1 text-xs font-medium text-muted">Description</p>
            <Textarea rows={2} value={desc} disabled={!canEdit} onChange={(e) => setDesc(e.target.value)} onBlur={() => desc !== (doc.description ?? "") && save({ description: desc || null })} />
          </div>
          <dl className="grid grid-cols-2 gap-y-1.5 text-sm">
            <dt className="text-muted">Créé par</dt><dd className="text-right text-fg">{pm.get(doc.owner_id ?? "")?.full_name ?? "—"}</dd>
            <dt className="text-muted">Créé le</dt><dd className="text-right text-fg">{dateTimeFr(doc.created_at)}</dd>
            <dt className="text-muted">Dernière modification</dt><dd className="text-right text-fg">{relative(doc.updated_at)}{doc.updated_by && ` · ${pm.get(doc.updated_by)?.full_name ?? ""}`}</dd>
            {doc.kind === "file" && <><dt className="text-muted">Taille</dt><dd className="text-right text-fg">{humanSize(doc.size_bytes)} · v{doc.version}</dd></>}
          </dl>
        </section>

        <section>
          <div className="mb-3 flex items-center justify-between">
            <h3 className="text-sm font-semibold text-fg">Versions</h3>
          </div>
          {onSnapshot && canEdit && (
            <form className="mb-4 flex gap-2" onSubmit={(e) => { e.preventDefault(); start(async () => { if (await onSnapshot(note || "Version enregistrée manuellement")) { setNote(""); toast.success("Version enregistrée."); load(); } }); }}>
              <Input value={note} onChange={(e) => setNote(e.target.value)} placeholder="Nommer cette version (ex. « Validée par le CODIR »)" />
              <Button type="submit" variant="outline" loading={pending}>Enregistrer</Button>
            </form>
          )}
          {!versions ? <Loader2 className="h-5 w-5 animate-spin text-subtle" /> : versions.length === 0 ? (
            <p className="rounded-xl border border-dashed border-border px-4 py-6 text-center text-sm text-muted">Aucune version antérieure. Les versions sont conservées automatiquement au fil des modifications.</p>
          ) : (
            <ol className="relative space-y-4 border-l border-border pl-5">
              {versions.map((v) => {
                const who = v.created_by ? pm.get(v.created_by) : null;
                return (
                  <li key={v.id} className="relative">
                    <span className="absolute -left-[26px] top-1 h-2.5 w-2.5 rounded-full border-2 border-surface bg-primary" />
                    <p className="text-sm font-medium text-fg">{v.note ?? `Révision ${v.revision}`}</p>
                    <p className="text-xs text-subtle">{dateTimeFr(v.created_at)} · {who?.full_name ?? "—"}{v.file_name && ` · ${v.file_name} (${humanSize(v.size_bytes)})`}</p>
                    <div className="mt-1.5 flex gap-3">
                      {v.storage_path && <a className="text-xs font-medium text-primary hover:underline" href={storageUrl("documents", v.storage_path, { download: true, name: v.file_name ?? "version" })}>Télécharger</a>}
                      {canEdit && (
                        <button className="text-xs font-medium text-primary hover:underline" disabled={pending}
                          onClick={() => confirm("Restaurer cette version ? L'état actuel sera conservé dans l'historique.") && start(async () => {
                            const r = await restoreVersion(v.id, doc.id);
                            if (r.ok) { toast.success(r.message); load(); onRestored(); } else toast.error(r.error);
                          })}>
                          Restaurer
                        </button>
                      )}
                    </div>
                  </li>
                );
              })}
            </ol>
          )}
        </section>
      </div>
    </Sheet>
  );
}

export function ExportItem({ onSelect, icon, label }: { onSelect: () => void; icon: React.ReactNode; label: string }) {
  return <DropdownItem onSelect={onSelect}>{icon} {label}</DropdownItem>;
}
