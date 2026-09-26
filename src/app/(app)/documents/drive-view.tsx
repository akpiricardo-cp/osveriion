"use client";

import { useEffect, useMemo, useRef, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  ArrowDownAZ, Building2, ChevronDown, ChevronRight, Clock, Copy, Download, FileSpreadsheet, FileText, FileUp, Folder as FolderIco, FolderInput,
  FolderPlus, FolderKanban, Globe, LayoutGrid, List, Loader2, Lock, MoreVertical, Pencil, Plus, Presentation, RotateCcw, Search,
  Share2, Sheet as SheetIco, Star, Trash2, Upload, UploadCloud, Users, X,
} from "lucide-react";
import { toast } from "sonner";
import { Avatar } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Dropdown, DropdownContent, DropdownItem, DropdownLabel, DropdownSeparator, DropdownTrigger } from "@/components/ui/dropdown";
import { Input } from "@/components/ui/input";
import { EmptyState } from "@/components/ui/misc";
import { DocIcon, FolderIcon } from "@/components/drive/icons";
import { MoveDialog, NameDialog, ShareDialog, type UnitLite } from "@/components/drive/dialogs";
import { uploadToFolder } from "@/components/drive/upload";
import { ACCESS_LABEL, KIND_LABEL, humanSize, storageUrl, type DriveDoc, type Folder, type Listing, type Space } from "@/lib/drive";
import { classification as classLabels } from "@/lib/labels";
import type { ProfileLite } from "@/lib/types";
import { cn, relative } from "@/lib/utils";
import {
  createFolder, createNativeDocument, deleteForever, duplicateDocument, moveDocument, moveFolder, renameFolder, restoreItem,
  toggleFavorite, trashItem, updateDocument,
} from "./actions";

export type DriveMode = "folder" | "shared" | "recent" | "favorites" | "trash" | "search";

type Item = { type: "folder"; folder: Folder } | { type: "doc"; doc: DriveDoc };

export function DriveView({
  mode, spaces, listing, folders, documents, favorites, people, units, userId, query,
}: {
  mode: DriveMode;
  spaces: Space[];
  listing: Listing | null;
  folders: Folder[];
  documents: DriveDoc[];
  favorites: { folders: string[]; documents: string[] };
  people: ProfileLite[];
  units: UnitLite[];
  userId: string;
  query: string;
}) {
  const router = useRouter();
  const [view, setView] = useState<"grid" | "list">("grid");
  const [navOpen, setNavOpen] = useState(false);
  const [sort, setSort] = useState<"name" | "date">("date");
  const [q, setQ] = useState(query);
  const [pending, start] = useTransition();
  const [dragOver, setDragOver] = useState(false);
  const [uploads, setUploads] = useState<{ name: string; done: boolean; error?: string }[]>([]);
  const [dialog, setDialog] = useState<
    | { kind: "newFolder" }
    | { kind: "rename"; item: Item }
    | { kind: "move"; item: Item }
    | { kind: "share"; item: Item | "current" }
    | null
  >(null);
  const fileInput = useRef<HTMLInputElement>(null);
  const importInput = useRef<HTMLInputElement>(null);
  const [importKind, setImportKind] = useState<"doc" | "sheet">("doc");
  const pm = useMemo(() => new Map(people.map((p) => [p.id, p])), [people]);
  const favFolders = new Set(favorites.folders);
  const favDocs = new Set(favorites.documents);

  const current = listing?.folder ?? null;
  const access = listing?.access ?? 0;
  const canWrite = mode === "folder" && access >= 2;
  const activeSpaceId = current?.path?.[0];

  const sortedFolders = [...folders].sort((a, b) => (sort === "name" ? a.name.localeCompare(b.name) : b.updated_at.localeCompare(a.updated_at)));
  const sortedDocs = [...documents].sort((a, b) => (sort === "name" ? a.title.localeCompare(b.title) : b.updated_at.localeCompare(a.updated_at)));

  const personal = spaces.filter((s) => s.space === "personal");
  const company = spaces.filter((s) => s.space === "company");
  const unitSpaces = spaces.filter((s) => s.space === "unit");
  const projectSpaces = spaces.filter((s) => s.space === "project");

  function run(fn: () => Promise<{ ok: boolean; message?: string; error?: string; data?: unknown }>, after?: (data: unknown) => void) {
    start(async () => {
      const r = await fn();
      if (r.ok) { if (r.message) toast.success(r.message); after?.(r.data); router.refresh(); } else toast.error(r.error);
    });
  }

  async function handleFiles(files: FileList | File[]) {
    if (!current || !canWrite) return;
    const list = Array.from(files);
    setUploads(list.map((f) => ({ name: f.name, done: false })));
    let okCount = 0;
    for (let i = 0; i < list.length; i++) {
      try {
        await uploadToFolder(list[i], current.id, userId);
        okCount++;
        setUploads((u) => u.map((x, j) => (j === i ? { ...x, done: true } : x)));
      } catch (e) {
        setUploads((u) => u.map((x, j) => (j === i ? { ...x, done: true, error: e instanceof Error ? e.message : "Erreur" } : x)));
      }
    }
    if (okCount) toast.success(`${okCount} fichier(s) déposé(s).`);
    router.refresh();
    setTimeout(() => setUploads([]), 4000);
  }

  async function handleImport(file: File) {
    if (!current) return;
    const title = file.name.replace(/\.[^.]+$/, "");
    const tid = toast.loading("Conversion en cours…");
    try {
      if (importKind === "doc") {
        const [{ docxToHtml }, { generateJSON }, { editorExtensions }] = await Promise.all([
          import("@/lib/converters"), import("@tiptap/react"), import("@/components/editors/doc-extensions"),
        ]);
        const html = await docxToHtml(file);
        const json = generateJSON(html, editorExtensions());
        const text = new DOMParser().parseFromString(html, "text/html").body.textContent ?? "";
        const r = await createNativeDocument(current.id, "doc", title, json, text);
        if (!r.ok) throw new Error(r.error);
        toast.success("Document Word importé et éditable.", { id: tid });
        router.push(`/documents/d/${(r.data as { id: string }).id}`);
      } else {
        const { spreadsheetToContent } = await import("@/lib/converters");
        const content = await spreadsheetToContent(file);
        const text = content.sheets.flatMap((s) => Object.values(s.cells).map((c) => c.v)).join(" ").slice(0, 100000);
        const r = await createNativeDocument(current.id, "sheet", title, content, text);
        if (!r.ok) throw new Error(r.error);
        toast.success("Classeur importé et éditable.", { id: tid });
        router.push(`/documents/d/${(r.data as { id: string }).id}`);
      }
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Import impossible.", { id: tid });
    }
  }

  function createNative(kind: "doc" | "sheet" | "slides") {
    if (!current) return;
    run(() => createNativeDocument(current.id, kind), (d) => router.push(`/documents/d/${(d as { id: string }).id}`));
  }

  // Glisser un élément sur un dossier pour l'y déplacer
  const onItemDragStart = (e: React.DragEvent, item: Item) => {
    e.dataTransfer.setData("application/x-veriion-item", JSON.stringify(item.type === "folder" ? { t: "folder", id: item.folder.id } : { t: "doc", id: item.doc.id }));
    e.dataTransfer.effectAllowed = "move";
  };
  const dropOnFolder = (e: React.DragEvent, folderId: string) => {
    const raw = e.dataTransfer.getData("application/x-veriion-item");
    if (!raw) return;
    e.preventDefault();
    e.stopPropagation();
    const { t, id } = JSON.parse(raw) as { t: "folder" | "doc"; id: string };
    if (id === folderId) return;
    run(() => (t === "folder" ? moveFolder(id, folderId) : moveDocument(id, folderId)));
  };

  const title =
    mode === "shared" ? "Partagés avec moi" : mode === "recent" ? "Récents" : mode === "favorites" ? "Favoris" :
    mode === "trash" ? "Corbeille" : mode === "search" ? `Résultats pour « ${query} »` :
    current?.is_root && current.space === "personal" ? "Mon espace" : current?.name ?? "Documents";

  const empty = !sortedFolders.length && !sortedDocs.length;
  // Sur mobile, le menu des espaces se replie après chaque navigation
  useEffect(() => setNavOpen(false), [current?.id, mode]);

  return (
    <div className="flex flex-col gap-6 lg:flex-row">
      {/* ── Navigation des espaces ── */}
      <aside className="w-full shrink-0 lg:w-60">
        <button type="button" onClick={() => setNavOpen((v) => !v)} aria-expanded={navOpen}
          className="flex w-full items-center justify-between rounded-xl border border-border bg-surface px-4 py-2.5 text-sm font-medium text-fg lg:hidden">
          <span className="flex items-center gap-2"><FolderIco className="h-4 w-4 text-subtle" /> Espaces &amp; dossiers</span>
          <ChevronDown className={cn("h-4 w-4 text-subtle transition", navOpen && "rotate-180")} />
        </button>
        <div className={cn("space-y-5 lg:sticky lg:top-24 lg:block", navOpen ? "mt-3 block rounded-xl border border-border bg-surface p-3 lg:mt-0 lg:border-0 lg:bg-transparent lg:p-0" : "hidden")}>
          <NavGroup>
            {personal.map((s) => <NavLink key={s.id} href={`/documents?dossier=${s.id}`} icon={Lock} label="Mon espace" active={mode === "folder" && activeSpaceId === s.id} />)}
            <NavLink href="/documents?vue=partages" icon={Users} label="Partagés avec moi" active={mode === "shared"} />
            <NavLink href="/documents?vue=recents" icon={Clock} label="Récents" active={mode === "recent"} />
            <NavLink href="/documents?vue=favoris" icon={Star} label="Favoris" active={mode === "favorites"} />
          </NavGroup>
          {company.length > 0 && (
            <NavGroup title="Entreprise">
              {company.map((s) => <NavLink key={s.id} href={`/documents?dossier=${s.id}`} icon={Globe} label="Documents de l'entreprise" active={activeSpaceId === s.id} />)}
            </NavGroup>
          )}
          {unitSpaces.length > 0 && (
            <NavGroup title="Départements & équipes">
              {unitSpaces.map((s) => <NavLink key={s.id} href={`/documents?dossier=${s.id}`} icon={Building2} label={s.name} color={s.color} active={activeSpaceId === s.id} badge={s.access === 3 ? "Gestion" : undefined} />)}
            </NavGroup>
          )}
          {projectSpaces.length > 0 && (
            <NavGroup title="Projets">
              {projectSpaces.map((s) => <NavLink key={s.id} href={`/documents?dossier=${s.id}`} icon={FolderKanban} label={s.name} color={s.color} active={activeSpaceId === s.id} />)}
            </NavGroup>
          )}
          <NavGroup>
            <NavLink href="/documents?vue=corbeille" icon={Trash2} label="Corbeille" active={mode === "trash"} />
          </NavGroup>
        </div>
      </aside>

      {/* ── Contenu ── */}
      <section
        className="relative min-w-0 flex-1"
        onDragOver={(e) => { if (canWrite && e.dataTransfer.types.includes("Files")) { e.preventDefault(); setDragOver(true); } }}
        onDragLeave={(e) => { if (e.currentTarget === e.target) setDragOver(false); }}
        onDrop={(e) => { if (e.dataTransfer.files?.length) { e.preventDefault(); setDragOver(false); handleFiles(e.dataTransfer.files); } }}
      >
        <div className="mb-5 flex flex-col gap-4">
          {listing && listing.breadcrumb.length > 1 && (
            <nav className="flex flex-wrap items-center gap-1 text-[13px] text-subtle">
              {listing.breadcrumb.map((b, i) => (
                <span key={b.id} className="flex items-center gap-1">
                  {i > 0 && <ChevronRight className="h-3.5 w-3.5" />}
                  <Link href={`/documents?dossier=${b.id}`} onDragOver={(e) => e.preventDefault()} onDrop={(e) => dropOnFolder(e, b.id)}
                    className={cn("rounded px-1 py-0.5 hover:bg-surface-2 hover:text-fg", i === listing.breadcrumb.length - 1 && "text-fg")}>
                    {i === 0 && listing.folder.space === "personal" ? "Mon espace" : b.name}
                  </Link>
                </span>
              ))}
            </nav>
          )}
          <div className="flex flex-col gap-3 xl:flex-row xl:items-center xl:justify-between">
            <div className="flex min-w-0 items-center gap-3">
              {mode === "folder" && current && <FolderIcon color={spaces.find((s) => s.id === activeSpaceId)?.color} locked={current.space === "personal"} />}
              <div className="min-w-0">
                <h1 className="truncate text-2xl font-semibold tracking-tight text-fg">{title}</h1>
                {mode === "folder" && (
                  <p className="text-[13px] text-muted">
                    Votre accès : <span className="font-medium text-fg">{ACCESS_LABEL[access]}</span>
                    {listing && listing.shares.length > 0 && <> · partagé avec {listing.shares.length} personne(s) / unité(s)</>}
                  </p>
                )}
                {mode === "trash" && <p className="text-[13px] text-muted">Les éléments sont supprimés définitivement après 30 jours.</p>}
              </div>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <form onSubmit={(e) => { e.preventDefault(); router.push(q.trim() ? `/documents?q=${encodeURIComponent(q.trim())}` : "/documents"); }} className="relative">
                <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-subtle" />
                <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Rechercher dans le contenu…" className="w-60 pl-9" />
              </form>
              {mode === "folder" && access >= 2 && current && (
                <Button size="sm" variant="outline" onClick={() => setDialog({ kind: "share", item: "current" })}><Share2 className="h-4 w-4" /> Partager</Button>
              )}
              {canWrite && (
                <Dropdown>
                  <DropdownTrigger asChild><Button size="sm"><Plus className="h-4 w-4" /> Nouveau</Button></DropdownTrigger>
                  <DropdownContent className="w-64">
                    <DropdownItem onSelect={() => setDialog({ kind: "newFolder" })}><FolderPlus className="h-4 w-4 text-subtle" /> Dossier</DropdownItem>
                    <DropdownSeparator />
                    <DropdownItem onSelect={() => createNative("doc")}><FileText className="h-4 w-4 text-sky-500" /> Document texte</DropdownItem>
                    <DropdownItem onSelect={() => createNative("sheet")}><SheetIco className="h-4 w-4 text-emerald-500" /> Tableur</DropdownItem>
                    <DropdownItem onSelect={() => createNative("slides")}><Presentation className="h-4 w-4 text-orange-500" /> Présentation</DropdownItem>
                    <DropdownSeparator />
                    <DropdownItem onSelect={() => fileInput.current?.click()}><Upload className="h-4 w-4 text-subtle" /> Déposer des fichiers</DropdownItem>
                    <DropdownLabel>Importer pour modifier en ligne</DropdownLabel>
                    <DropdownItem onSelect={() => { setImportKind("doc"); setTimeout(() => importInput.current?.click(), 0); }}><FileUp className="h-4 w-4 text-subtle" /> Word (.docx) → document</DropdownItem>
                    <DropdownItem onSelect={() => { setImportKind("sheet"); setTimeout(() => importInput.current?.click(), 0); }}><FileSpreadsheet className="h-4 w-4 text-subtle" /> Excel / CSV → tableur</DropdownItem>
                  </DropdownContent>
                </Dropdown>
              )}
              <div className="flex rounded-lg border border-border bg-surface p-0.5">
                <button aria-label="Trier" onClick={() => setSort(sort === "name" ? "date" : "name")} className="flex items-center gap-1 rounded-md px-2 py-1 text-xs text-muted hover:text-fg" title="Changer le tri">
                  {sort === "name" ? <ArrowDownAZ className="h-4 w-4" /> : <Clock className="h-4 w-4" />}
                </button>
                {([["grid", LayoutGrid], ["list", List]] as const).map(([v, Icon]) => (
                  <button key={v} aria-label={v} onClick={() => setView(v)} className={cn("rounded-md px-2 py-1", view === v ? "bg-surface-2 text-fg" : "text-muted hover:text-fg")}>
                    <Icon className="h-4 w-4" />
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>

        <input ref={fileInput} type="file" multiple className="hidden" onChange={(e) => { if (e.target.files) handleFiles(e.target.files); e.target.value = ""; }} />
        <input ref={importInput} type="file" className="hidden" accept={importKind === "doc" ? ".docx" : ".xlsx,.csv"} onChange={(e) => { const f = e.target.files?.[0]; if (f) handleImport(f); e.target.value = ""; }} />

        {dragOver && (
          <div className="pointer-events-none absolute inset-0 z-20 grid place-items-center rounded-2xl border-2 border-dashed border-primary bg-primary/5 backdrop-blur-[1px]">
            <div className="text-center"><UploadCloud className="mx-auto h-10 w-10 text-primary" /><p className="mt-2 text-sm font-medium text-primary">Déposez vos fichiers dans « {title} »</p></div>
          </div>
        )}

        {uploads.length > 0 && (
          <div className="mb-4 space-y-1 rounded-xl border border-border bg-surface p-3">
            {uploads.map((u, i) => (
              <p key={i} className="flex items-center gap-2 text-sm">
                {!u.done ? <Loader2 className="h-4 w-4 animate-spin text-primary" /> : u.error ? <X className="h-4 w-4 text-danger" /> : <span className="h-2 w-2 rounded-full bg-emerald-500" />}
                <span className="truncate text-fg">{u.name}</span>
                {u.error && <span className="truncate text-xs text-danger">{u.error}</span>}
              </p>
            ))}
          </div>
        )}

        {empty ? (
          <div className="rounded-2xl border border-dashed border-border bg-surface">
            <EmptyState
              icon={mode === "trash" ? Trash2 : mode === "shared" ? Users : mode === "favorites" ? Star : FolderIco}
              title={mode === "trash" ? "La corbeille est vide" : mode === "shared" ? "Rien n'a encore été partagé avec vous" : mode === "favorites" ? "Aucun favori" : mode === "search" ? "Aucun résultat" : "Ce dossier est vide"}
              description={canWrite ? "Créez un dossier, un document, un tableur ou une présentation — ou glissez-déposez des fichiers ici." : undefined}
              action={canWrite ? (
                <div className="flex flex-wrap justify-center gap-2">
                  <Button size="sm" variant="outline" onClick={() => setDialog({ kind: "newFolder" })}><FolderPlus className="h-4 w-4" /> Dossier</Button>
                  <Button size="sm" variant="outline" onClick={() => createNative("doc")}><FileText className="h-4 w-4" /> Document</Button>
                  <Button size="sm" variant="outline" onClick={() => fileInput.current?.click()}><Upload className="h-4 w-4" /> Déposer</Button>
                </div>
              ) : undefined}
            />
          </div>
        ) : view === "grid" ? (
          <div className="space-y-6">
            {sortedFolders.length > 0 && (
              <div>
                <p className="mb-2 text-xs font-medium uppercase tracking-wider text-subtle">Dossiers</p>
                <div className="grid grid-cols-2 gap-3 md:grid-cols-3 2xl:grid-cols-4">
                  {sortedFolders.map((f) => (
                    <div key={f.id} draggable={mode === "folder" && (f.access ?? 0) >= 2} onDragStart={(e) => onItemDragStart(e, { type: "folder", folder: f })}
                      onDragOver={(e) => { if (e.dataTransfer.types.includes("application/x-veriion-item")) e.preventDefault(); }} onDrop={(e) => dropOnFolder(e, f.id)}
                      className="group relative flex items-center gap-3 rounded-xl border border-border bg-surface p-3 shadow-card transition hover:border-primary/30 hover:shadow-md">
                      <FolderIcon color={spaces.find((s) => s.id === f.path?.[0])?.color} />
                      <Link href={mode === "trash" ? "#" : `/documents?dossier=${f.id}`} className="min-w-0 flex-1 after:absolute after:inset-0">
                        <p className="truncate text-sm font-medium text-fg">{f.name}</p>
                        <p className="text-xs text-subtle">{mode === "trash" ? `Supprimé ${relative(f.deleted_at)}` : f.items !== undefined ? `${f.items} élément(s)` : relative(f.updated_at)}</p>
                      </Link>
                      {f.shared && <Users className="relative h-3.5 w-3.5 text-subtle" />}
                      <ItemMenu item={{ type: "folder", folder: f }} />
                    </div>
                  ))}
                </div>
              </div>
            )}
            {sortedDocs.length > 0 && (
              <div>
                <p className="mb-2 text-xs font-medium uppercase tracking-wider text-subtle">Fichiers</p>
                <div className="grid grid-cols-2 gap-3 md:grid-cols-3 2xl:grid-cols-4">
                  {sortedDocs.map((d) => (
                    <div key={d.id} draggable={mode === "folder" && (d.access ?? 0) >= 2} onDragStart={(e) => onItemDragStart(e, { type: "doc", doc: d })}
                      className="group relative flex flex-col overflow-hidden rounded-xl border border-border bg-surface shadow-card transition hover:border-primary/30 hover:shadow-md">
                      <Preview doc={d} />
                      <div className="flex items-start gap-2.5 p-3">
                        <DocIcon kind={d.kind} mime={d.mime_type} name={d.file_name} size="sm" />
                        <Link href={mode === "trash" ? "#" : `/documents/d/${d.id}`} className="min-w-0 flex-1 after:absolute after:inset-0">
                          <p className="truncate text-sm font-medium text-fg" title={d.title}>{d.title}</p>
                          <p className="truncate text-xs text-subtle">{mode === "trash" ? `Supprimé ${relative(d.deleted_at)}` : `${KIND_LABEL[d.kind]} · ${relative(d.updated_at)}`}</p>
                        </Link>
                        <ItemMenu item={{ type: "doc", doc: d }} />
                      </div>
                      {(d.classification !== "internal" || d.shared || favDocs.has(d.id)) && (
                        <div className="pointer-events-none absolute left-2 top-2 flex gap-1">
                          {d.classification !== "internal" && <Badge tone={classLabels[d.classification].tone}>{classLabels[d.classification].label}</Badge>}
                          {favDocs.has(d.id) && <span className="grid h-5 w-5 place-items-center rounded-full bg-surface/90"><Star className="h-3 w-3 fill-amber-400 text-amber-400" /></span>}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        ) : (
          <div className="overflow-hidden rounded-2xl border border-border bg-surface shadow-card">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-surface-2/60 text-left text-[12px] uppercase tracking-wide text-subtle">
                  <th className="px-5 py-2.5 font-medium">Nom</th><th className="hidden px-4 py-2.5 font-medium md:table-cell">Propriétaire</th>
                  <th className="hidden px-4 py-2.5 font-medium sm:table-cell">Modifié</th><th className="hidden px-4 py-2.5 font-medium lg:table-cell">Taille</th><th className="w-10" />
                </tr>
              </thead>
              <tbody>
                {sortedFolders.map((f) => (
                  <tr key={f.id} className="group border-b border-border last:border-0 hover:bg-surface-2/50" onDragOver={(e) => e.preventDefault()} onDrop={(e) => dropOnFolder(e, f.id)}
                    draggable={mode === "folder" && (f.access ?? 0) >= 2} onDragStart={(e) => onItemDragStart(e, { type: "folder", folder: f })}>
                    <td className="px-5 py-2.5"><Link href={`/documents?dossier=${f.id}`} className="flex items-center gap-3"><FolderIcon size="sm" color={spaces.find((s) => s.id === f.path?.[0])?.color} /><span className="truncate font-medium text-fg">{f.name}</span></Link></td>
                    <td className="hidden px-4 py-2.5 text-muted md:table-cell">{f.created_by ? pm.get(f.created_by)?.full_name ?? "—" : "Système"}</td>
                    <td className="hidden px-4 py-2.5 text-muted sm:table-cell">{relative(f.deleted_at ?? f.updated_at)}</td>
                    <td className="hidden px-4 py-2.5 text-muted lg:table-cell">{f.items !== undefined ? `${f.items} élément(s)` : "—"}</td>
                    <td className="px-2"><ItemMenu item={{ type: "folder", folder: f }} /></td>
                  </tr>
                ))}
                {sortedDocs.map((d) => {
                  const owner = d.owner_id ? pm.get(d.owner_id) : null;
                  return (
                    <tr key={d.id} className="group border-b border-border last:border-0 hover:bg-surface-2/50" draggable={mode === "folder" && (d.access ?? 0) >= 2} onDragStart={(e) => onItemDragStart(e, { type: "doc", doc: d })}>
                      <td className="px-5 py-2.5">
                        <Link href={mode === "trash" ? "#" : `/documents/d/${d.id}`} className="flex items-center gap-3">
                          <DocIcon kind={d.kind} mime={d.mime_type} name={d.file_name} size="sm" />
                          <span className="min-w-0"><span className="block truncate font-medium text-fg">{d.title}</span>
                            {d.classification !== "internal" && <span className="text-[11px] text-subtle">{classLabels[d.classification].label}</span>}</span>
                          {favDocs.has(d.id) && <Star className="h-3.5 w-3.5 fill-amber-400 text-amber-400" />}
                          {d.shared && <Users className="h-3.5 w-3.5 text-subtle" />}
                        </Link>
                      </td>
                      <td className="hidden px-4 py-2.5 md:table-cell">{owner ? <span className="flex items-center gap-2"><Avatar name={owner.full_name} src={owner.avatar_url} size="xs" /><span className="truncate text-muted">{owner.id === userId ? "Moi" : owner.full_name}</span></span> : "—"}</td>
                      <td className="hidden px-4 py-2.5 text-muted sm:table-cell">{relative(d.deleted_at ?? d.updated_at)}</td>
                      <td className="hidden px-4 py-2.5 text-muted lg:table-cell">{d.kind === "file" ? humanSize(d.size_bytes) : KIND_LABEL[d.kind]}</td>
                      <td className="px-2"><ItemMenu item={{ type: "doc", doc: d }} /></td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
        {pending && <Loader2 className="fixed bottom-6 right-6 h-5 w-5 animate-spin text-primary" />}
      </section>

      {/* ── Dialogues ── */}
      {current && (
        <NameDialog open={dialog?.kind === "newFolder"} onOpenChange={(o) => !o && setDialog(null)} title="Nouveau dossier" submitLabel="Créer"
          onSubmit={async (name) => { const r = await createFolder(current.id, name); if (!r.ok) { toast.error(r.error); return false; } router.refresh(); return true; }} />
      )}
      {dialog?.kind === "rename" && (
        <NameDialog open onOpenChange={(o) => !o && setDialog(null)} title="Renommer" submitLabel="Renommer"
          initial={dialog.item.type === "folder" ? dialog.item.folder.name : dialog.item.doc.title}
          onSubmit={async (name) => {
            const it = dialog.item;
            const r = it.type === "folder" ? await renameFolder(it.folder.id, name) : await updateDocument(it.doc.id, { title: name.trim() });
            if (!r.ok) { toast.error(r.error); return false; } router.refresh(); return true;
          }} />
      )}
      {dialog?.kind === "move" && (
        <MoveDialog open onOpenChange={(o) => !o && setDialog(null)} title={`Déplacer « ${dialog.item.type === "folder" ? dialog.item.folder.name : dialog.item.doc.title} »`}
          excludeId={dialog.item.type === "folder" ? dialog.item.folder.id : undefined}
          onPick={async (target) => {
            const it = dialog.item;
            const r = it.type === "folder" ? await moveFolder(it.folder.id, target) : await moveDocument(it.doc.id, target);
            if (!r.ok) { toast.error(r.error); return false; } toast.success(r.message); router.refresh(); return true;
          }} />
      )}
      {dialog?.kind === "share" && (() => {
        const it = dialog.item;
        const target = it === "current" ? { folderId: current!.id } : it.type === "folder" ? { folderId: it.folder.id } : { documentId: it.doc.id };
        const name = it === "current" ? title : it.type === "folder" ? it.folder.name : it.doc.title;
        const acc = it === "current" ? access : it.type === "folder" ? it.folder.access ?? access : it.doc.access ?? access;
        const space = it === "current" ? current?.space : it.type === "folder" ? it.folder.space : current?.space;
        return <ShareDialog open onOpenChange={(o) => !o && setDialog(null)} target={target} name={name} space={space} people={people.filter((p) => p.id !== userId)} units={units} access={acc} />;
      })()}
    </div>
  );

  function ItemMenu({ item }: { item: Item }) {
    const acc = item.type === "folder" ? item.folder.access ?? (mode === "folder" ? access : 1) : item.doc.access ?? (mode === "folder" ? access : 1);
    const isFav = item.type === "folder" ? favFolders.has(item.folder.id) : favDocs.has(item.doc.id);
    const id = item.type === "folder" ? item.folder.id : item.doc.id;
    const t = item.type === "folder" ? "folder" : "document";
    return (
      <Dropdown>
        <DropdownTrigger className="relative z-10 rounded-md p-1 text-subtle opacity-70 transition hover:bg-surface-2 hover:text-fg group-hover:opacity-100" aria-label="Actions">
          <MoreVertical className="h-4 w-4" />
        </DropdownTrigger>
        <DropdownContent className="w-56">
          {mode === "trash" ? (
            <>
              <DropdownItem onSelect={() => run(() => restoreItem(t, id))}><RotateCcw className="h-4 w-4 text-subtle" /> Restaurer</DropdownItem>
              {acc >= 3 && (
                <DropdownItem danger onSelect={() => confirm("Supprimer définitivement ? Cette action est irréversible.") && run(() => deleteForever(t, id))}>
                  <Trash2 className="h-4 w-4" /> Supprimer définitivement
                </DropdownItem>
              )}
            </>
          ) : (
            <>
              {item.type === "doc" && item.doc.kind === "file" && item.doc.storage_path && (
                <DropdownItem asChild><a href={storageUrl("documents", item.doc.storage_path, { download: true, name: item.doc.file_name ?? item.doc.title })}><Download className="h-4 w-4 text-subtle" /> Télécharger</a></DropdownItem>
              )}
              <DropdownItem onSelect={() => run(() => toggleFavorite(item.type === "folder" ? { folderId: id } : { documentId: id }, !isFav))}>
                <Star className={cn("h-4 w-4", isFav ? "fill-amber-400 text-amber-400" : "text-subtle")} /> {isFav ? "Retirer des favoris" : "Ajouter aux favoris"}
              </DropdownItem>
              {acc >= 2 && <DropdownItem onSelect={() => setDialog({ kind: "share", item })}><Share2 className="h-4 w-4 text-subtle" /> Partager</DropdownItem>}
              {acc >= 2 && <DropdownItem onSelect={() => setDialog({ kind: "rename", item })}><Pencil className="h-4 w-4 text-subtle" /> Renommer</DropdownItem>}
              {acc >= 2 && <DropdownItem onSelect={() => setDialog({ kind: "move", item })}><FolderInput className="h-4 w-4 text-subtle" /> Déplacer</DropdownItem>}
              {item.type === "doc" && <DropdownItem onSelect={() => run(() => duplicateDocument(id), (d) => router.push(`/documents/d/${(d as { id: string }).id}`))}><Copy className="h-4 w-4 text-subtle" /> Dupliquer</DropdownItem>}
              {acc >= 2 && (
                <>
                  <DropdownSeparator />
                  <DropdownItem danger onSelect={() => run(() => trashItem(t, id))}><Trash2 className="h-4 w-4" /> Mettre à la corbeille</DropdownItem>
                </>
              )}
            </>
          )}
        </DropdownContent>
      </Dropdown>
    );
  }
}

function Preview({ doc }: { doc: DriveDoc }) {
  const isImage = doc.kind === "file" && doc.mime_type?.startsWith("image/") && doc.storage_path;
  const tint = { doc: "from-sky-500/10", sheet: "from-emerald-500/10", slides: "from-orange-500/10", file: "from-slate-500/5" }[doc.kind];
  return (
    <div className={cn("relative h-28 overflow-hidden border-b border-border bg-gradient-to-br to-transparent", tint)}>
      {isImage ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={storageUrl("documents", doc.storage_path!)} alt="" loading="lazy" className="h-full w-full object-cover" />
      ) : (
        <div className="grid h-full place-items-center"><DocIcon kind={doc.kind} mime={doc.mime_type} name={doc.file_name} size="lg" /></div>
      )}
    </div>
  );
}

function NavGroup({ title, children }: { title?: string; children: React.ReactNode }) {
  return (
    <div>
      {title && <p className="mb-1 px-3 text-[11px] font-semibold uppercase tracking-wider text-subtle">{title}</p>}
      <ul className="space-y-0.5">{children}</ul>
    </div>
  );
}

function NavLink({ href, icon: Icon, label, active, color, badge }: { href: string; icon: React.ComponentType<{ className?: string }>; label: string; active?: boolean; color?: string | null; badge?: string }) {
  return (
    <li>
      <Link href={href} className={cn("flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm transition", active ? "bg-primary/10 font-medium text-primary" : "text-muted hover:bg-surface-2 hover:text-fg")}>
        {color ? <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ background: color }} /> : <Icon className="h-4 w-4 shrink-0" />}
        <span className="truncate">{label}</span>
        {badge && <span className="ml-auto text-[10px] text-subtle">{badge}</span>}
      </Link>
    </li>
  );
}
