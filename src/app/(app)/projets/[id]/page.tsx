import { notFound } from "next/navigation";
import { Suspense } from "react";
import { CalendarDays, FolderOpen, MessagesSquare, Users, Wallet } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { getContext } from "@/lib/auth";
import { getPeople, getUnits, peopleMap, unitOptions } from "@/lib/data";
import { priority, projectStatus } from "@/lib/labels";
import type { Project, Task } from "@/lib/types";
import { dateFr, money } from "@/lib/utils";
import { Avatar } from "@/components/ui/avatar";
import { LabelBadge } from "@/components/ui/badge";
import { ButtonLink } from "@/components/ui/button";
import { PageHeader, Progress } from "@/components/ui/misc";
import { ProjectBoard } from "@/components/tasks/kanban";
import { ProjectFormButton } from "../project-form";
import { ArchiveProjectButton, MembersButton } from "./project-client";

export default async function ProjectPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const ctx = await getContext();
  const supabase = await createClient();
  const { data: project } = await supabase.from("projects").select("*").eq("id", id).maybeSingle();
  if (!project) notFound();
  const p = project as Project;

  const [{ data: tasks }, { data: members }, { data: deps }, { data: channel }, canManage, canContribute, people, units, { data: space }] = await Promise.all([
    supabase.from("tasks").select("*").eq("project_id", id).order("position"),
    supabase.from("project_members").select("profile_id, role").eq("project_id", id),
    supabase.from("task_dependencies").select("task_id, depends_on_id"),
    supabase.from("channels").select("id").eq("project_id", id).maybeSingle(),
    supabase.rpc("can_manage_project", { p_project: id }),
    supabase.rpc("can_contribute_project", { p_project: id }),
    getPeople(),
    getUnits(),
    supabase.from("folders").select("id").eq("space", "project").eq("project_id", id).eq("is_root", true).maybeSingle(),
  ]);
  const pm = peopleMap(people);
  const all = (tasks as Task[]) ?? [];
  const status = new Map(all.map((t) => [t.id, t.status]));
  const blockedIds = (deps ?? []).filter((d) => status.has(d.task_id) && status.get(d.depends_on_id) !== undefined && status.get(d.depends_on_id) !== "done").map((d) => d.task_id);
  const top = all.filter((t) => !t.parent_id);
  const done = top.filter((t) => t.status === "done").length;
  const owner = p.owner_id ? pm.get(p.owner_id) : null;
  const unit = units.find((u) => u.id === p.unit_id);
  const team = (members ?? []).map((m) => ({ ...m, person: pm.get(m.profile_id) })).filter((m) => m.person);

  return (
    <div>
      <PageHeader
        crumbs={[{ label: "Projets", href: "/projets" }, { label: p.code }]}
        title={<span className="flex items-center gap-3"><span className="h-6 w-2 rounded-full" style={{ background: p.color }} />{p.name}</span>}
        description={p.description ?? undefined}
        actions={
          <>
            {space && <ButtonLink href={`/documents?dossier=${space.id}`} size="sm" variant="outline"><FolderOpen className="h-4 w-4" /> Documents</ButtonLink>}
            {channel && <ButtonLink href={`/messages/${channel.id}`} size="sm" variant="outline"><MessagesSquare className="h-4 w-4" /> Discussion</ButtonLink>}
            {canManage.data && <MembersButton projectId={p.id} people={people} members={members ?? []} />}
            {canManage.data && <ProjectFormButton units={unitOptions(units)} project={p} people={people} />}
            {canManage.data && <ArchiveProjectButton id={p.id} />}
          </>
        }
      />
      <div className="mb-6 grid gap-5 rounded-2xl border border-border bg-surface p-5 shadow-card sm:grid-cols-2 xl:grid-cols-[auto_auto_auto_auto_minmax(180px,1fr)]">
        <Meta label="Statut"><div className="flex gap-2"><LabelBadge map={projectStatus} value={p.status} /><LabelBadge map={priority} value={p.priority} /></div></Meta>
        <Meta label="Responsable">
          {owner ? <span className="flex items-center gap-2"><Avatar name={owner.full_name} src={owner.avatar_url} size="xs" /><span className="truncate text-sm font-medium text-fg">{owner.full_name}</span></span> : "—"}
        </Meta>
        <Meta label="Calendrier"><span className="flex items-center gap-1.5 text-sm text-fg"><CalendarDays className="h-4 w-4 text-subtle" />{p.start_date ? dateFr(p.start_date, "d MMM") : "?"} → {p.due_date ? dateFr(p.due_date, "d MMM yyyy") : "?"}</span></Meta>
        <Meta label={`Équipe · ${unit?.name ?? "Transverse"}`}>
          <span className="flex flex-wrap items-center gap-2 whitespace-nowrap text-sm text-fg"><Users className="h-4 w-4 text-subtle" />{team.length} membre(s){p.budget ? <><Wallet className="ml-2 h-4 w-4 text-subtle" />{money(p.budget, "XOF", true)}</> : null}</span>
        </Meta>
        <Meta label={`Avancement · ${done}/${top.length}`}>
          <div className="flex items-center gap-3"><Progress value={top.length ? (done / top.length) * 100 : 0} /><span className="whitespace-nowrap text-sm font-medium tabular-nums text-fg">{top.length ? Math.round((done / top.length) * 100) : 0} %</span></div>
        </Meta>
      </div>
      <Suspense>
        <ProjectBoard projectId={p.id} initialTasks={all} people={people} blockedIds={blockedIds} canContribute={Boolean(canContribute.data)} />
      </Suspense>
      <p className="mt-6 text-xs text-subtle">Vous êtes connecté(e) en tant que {ctx.profile.full_name}. Les modifications sont synchronisées en temps réel et journalisées.</p>
    </div>
  );
}

function Meta({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="min-w-0">
      <p className="mb-1.5 text-xs font-medium text-subtle">{label}</p>
      {children}
    </div>
  );
}
