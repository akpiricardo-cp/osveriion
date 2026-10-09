import { notFound } from "next/navigation";
import { Suspense } from "react";
import Link from "next/link";
import { CalendarDays, FolderOpen, MessagesSquare, Rocket, Users, Wallet } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { getContext } from "@/lib/auth";
import { getPeople, getUnits, peopleMap, unitOptions } from "@/lib/data";
import { cycleKind, priority, projectStatus } from "@/lib/labels";
import type { ApprovalRequest, OperationCycle, OperationItem, OperationReport, Project, Task } from "@/lib/types";
import { dateFr, money } from "@/lib/utils";
import { Avatar } from "@/components/ui/avatar";
import { Badge, LabelBadge } from "@/components/ui/badge";
import { ButtonLink } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState, PageHeader, Progress } from "@/components/ui/misc";
import { LinkTabs } from "@/components/ui/tabs";
import { ProjectBoard } from "@/components/tasks/kanban";
import { CycleCard, ReportDialog, ReportList } from "../../operations/operations-client";
import { ProjectFormButton } from "../project-form";
import { ArchiveProjectButton, LaunchProjectButton, MembersButton } from "./project-client";

export default async function ProjectPage({
  params, searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ onglet?: string }>;
}) {
  const { id } = await params;
  const { onglet = "taches" } = await searchParams;
  const ctx = await getContext();
  const supabase = await createClient();
  const { data: project } = await supabase.from("projects").select("*").eq("id", id).maybeSingle();
  if (!project) notFound();
  const p = project as Project;

  const [
    { data: tasks }, { data: members }, { data: deps }, { data: channel },
    canManage, canContribute, people, units, { data: space },
    { data: liaisonRows }, { data: cycleRows }, { data: reportRows }, { data: approvals },
  ] = await Promise.all([
    supabase.from("tasks").select("*").eq("project_id", id).order("position"),
    supabase.from("project_members").select("profile_id, role").eq("project_id", id),
    supabase.from("task_dependencies").select("task_id, depends_on_id, tasks!task_dependencies_task_id_fkey!inner(project_id)").eq("tasks.project_id", id),
    supabase.from("channels").select("id").eq("project_id", id).maybeSingle(),
    supabase.rpc("can_manage_project", { p_project: id }),
    supabase.rpc("can_contribute_project", { p_project: id }),
    getPeople(),
    getUnits(),
    supabase.from("folders").select("id").eq("space", "project").eq("project_id", id).eq("is_root", true).maybeSingle(),
    supabase.from("project_liaisons").select("unit_id, profile_id, note").eq("project_id", id),
    supabase.from("operation_cycles").select("*, operation_items(*)").eq("project_id", id).order("period_start", { ascending: false }).limit(24),
    supabase.from("operation_reports").select("*").eq("project_id", id).order("created_at", { ascending: false }).limit(24),
    supabase.from("approval_requests").select("*").eq("project_id", id).eq("kind", "project").order("created_at", { ascending: false }).limit(1),
  ]);

  type CycleWithItems = OperationCycle & { operation_items: OperationItem[] };
  const pm = peopleMap(people);
  const all = (tasks as Task[]) ?? [];
  const status = new Map(all.map((t) => [t.id, t.status]));
  const blockedIds = (deps ?? [])
    .filter((d) => status.has(d.task_id) && status.get(d.depends_on_id) !== undefined && status.get(d.depends_on_id) !== "done")
    .map((d) => d.task_id);
  const top = all.filter((t) => !t.parent_id);
  const done = top.filter((t) => t.status === "done").length;
  const lead = p.lead_id ? pm.get(p.lead_id) : p.owner_id ? pm.get(p.owner_id) : null;
  const unit = units.find((u) => u.id === p.unit_id);
  const team = (members ?? []).map((m) => ({ ...m, person: pm.get(m.profile_id) })).filter((m) => m.person);
  const liaisons = (liaisonRows ?? []).map((l) => ({ ...l, unit: units.find((u) => u.id === l.unit_id), person: pm.get(l.profile_id) }));
  const cycles = (cycleRows ?? []) as CycleWithItems[];
  const reports = (reportRows ?? []) as OperationReport[];
  const launch = ((approvals ?? []) as ApprovalRequest[])[0];
  const manage = Boolean(canManage.data);
  const isLead = p.lead_id === ctx.userId || p.owner_id === ctx.userId || manage;
  const openCycles = cycles.filter((c) => c.status === "published");
  // Le chef de projet repartit dans son equipe ; un membre ne se confie que ses propres taches.
  const assignableIds = manage ? team.map((m) => m.profile_id) : [ctx.userId];

  return (
    <div>
      <PageHeader
        crumbs={[{ label: "Projets", href: "/projets" }, { label: p.code }]}
        title={<span className="flex items-center gap-3"><span className="h-6 w-2 rounded-full" style={{ background: p.color }} />{p.name}</span>}
        description={p.mission ?? p.description ?? undefined}
        actions={
          <>
            {space && <ButtonLink href={`/documents?dossier=${space.id}`} size="sm" variant="outline"><FolderOpen className="h-4 w-4" /> Documents</ButtonLink>}
            {channel && <ButtonLink href={`/messages/${channel.id}`} size="sm" variant="outline"><MessagesSquare className="h-4 w-4" /> Discussion</ButtonLink>}
            {manage && <MembersButton projectId={p.id} people={people} members={members ?? []} />}
            {manage && <ProjectFormButton units={unitOptions(units)} project={p} people={people} />}
            {manage && <ArchiveProjectButton id={p.id} />}
          </>
        }
      />

      {p.status === "planned" && manage && (
        <div className="mb-6 flex flex-col gap-3 rounded-2xl border border-amber-500/30 bg-amber-500/[0.07] p-4 sm:flex-row sm:items-center">
          <Rocket className="h-5 w-5 shrink-0 text-amber-600" />
          <p className="flex-1 text-sm text-fg">
            <span className="font-medium">Projet non lancé.</span>{" "}
            {launch?.status === "pending"
              ? "Le CEO a été saisi : le projet passera actif dès son accord."
              : launch?.status === "rejected"
                ? `Lancement refusé : ${launch.decision_note ?? "sans motif enregistré"}.`
                : "Le lancement d'un projet demande l'accord du CEO."}
          </p>
          <LaunchProjectButton id={p.id} approved={launch?.status === "approved"} pending={launch?.status === "pending"} />
        </div>
      )}

      <div className="mb-6 grid gap-5 rounded-2xl border border-border bg-surface p-5 shadow-card sm:grid-cols-2 xl:grid-cols-[auto_auto_auto_auto_minmax(180px,1fr)]">
        <Meta label="Statut"><div className="flex gap-2"><LabelBadge map={projectStatus} value={p.status} /><LabelBadge map={priority} value={p.priority} /></div></Meta>
        <Meta label="Chief Product">
          {lead ? (
            <Link href={`/annuaire/${lead.id}`} className="flex items-center gap-2 hover:underline">
              <Avatar name={lead.full_name} src={lead.avatar_url} size="xs" />
              <span className="truncate text-sm font-medium text-fg">{lead.full_name}</span>
            </Link>
          ) : "À nommer"}
        </Meta>
        <Meta label="Calendrier">
          <span className="flex items-center gap-1.5 text-sm text-fg">
            <CalendarDays className="h-4 w-4 text-subtle" />
            {p.start_date ? dateFr(p.start_date, "d MMM") : "?"} → {p.due_date ? dateFr(p.due_date, "d MMM yyyy") : "?"}
          </span>
        </Meta>
        <Meta label={`Équipe · ${unit?.name ?? "Holding"}`}>
          <span className="flex flex-wrap items-center gap-2 whitespace-nowrap text-sm text-fg">
            <Users className="h-4 w-4 text-subtle" />{team.length} membre(s)
            {p.budget ? <><Wallet className="ml-2 h-4 w-4 text-subtle" />{money(p.budget, "XOF", true)}</> : null}
          </span>
        </Meta>
        <Meta label={`Avancement · ${done}/${top.length}`}>
          <div className="flex items-center gap-3">
            <Progress value={top.length ? (done / top.length) * 100 : 0} />
            <span className="whitespace-nowrap text-sm font-medium tabular-nums text-fg">{top.length ? Math.round((done / top.length) * 100) : 0} %</span>
          </div>
        </Meta>
      </div>

      {liaisons.length > 0 && (
        <div className="mb-6 flex flex-wrap items-center gap-2 rounded-2xl border border-border bg-surface p-4 shadow-card">
          <span className="mr-1 text-[13px] font-medium text-muted">Référents départements :</span>
          {liaisons.map((l) => (
            <span key={l.unit_id} className="inline-flex items-center gap-1.5 rounded-full border border-border bg-surface-2 py-1 pl-1 pr-3" title={l.note ?? undefined}>
              <Avatar name={l.person?.full_name} src={l.person?.avatar_url} size="xs" />
              <span className="text-[12.5px] text-fg">{l.person?.full_name ?? "—"}</span>
              <span className="text-[11px] text-subtle">· {l.unit?.code ?? l.unit?.name}</span>
            </span>
          ))}
          <Link href="/organisation?onglet=coordination" className="ml-auto text-[13px] font-medium text-primary hover:underline">Gérer</Link>
        </div>
      )}

      <LinkTabs
        basePath={`/projets/${p.id}`}
        active={onglet}
        className="mb-6"
        tabs={[
          { key: "taches", label: "Tâches", count: top.length },
          { key: "operations", label: "Calendrier & rapports", count: openCycles.length },
        ]}
      />

      {onglet === "operations" ? (
        <div className="space-y-6">
          {cycles.length === 0 ? (
            <Card>
              <EmptyState
                icon={CalendarDays}
                title="Aucun calendrier reçu"
                description="Le département des Opérations écrit les grandes lignes du mois, de la semaine et du jour. Elles apparaîtront ici dès publication."
              />
            </Card>
          ) : (
            cycles.map((c) => (
              <CycleCard
                key={c.id}
                cycle={c}
                items={c.operation_items ?? []}
                projectName={p.name}
                people={people}
                canPlan={false}
                subtitle={`${cycleKind[c.kind]} · ${dateFr(c.period_start)} → ${dateFr(c.period_end)}`}
                footer={
                  isLead && c.status === "published" ? (
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <span className="text-[13px] text-muted">
                        {reports.some((r) => r.cycle_id === c.id) ? "Rapport déjà transmis pour ce cycle." : "Rendez compte aux Opérations à la clôture du cycle."}
                      </span>
                      <ReportDialog cycleId={c.id} projectId={p.id} cycleTitle={c.title} />
                    </div>
                  ) : undefined
                }
              />
            ))
          )}

          {reports.length > 0 && (
            <section className="space-y-3">
              <h2 className="text-[15px] font-semibold tracking-tight text-fg">Rapports transmis</h2>
              <ReportList
                reports={reports}
                projects={{ [p.id]: p.name }}
                cycles={Object.fromEntries(cycles.map((c) => [c.id, c.title]))}
                people={Object.fromEntries(pm)}
                canAcknowledge={false}
              />
            </section>
          )}
        </div>
      ) : (
        <>
          {openCycles.length > 0 && (
            <div className="mb-4 flex flex-wrap items-center gap-2 text-[13px] text-muted">
              <Badge tone="cyan">Cap en cours</Badge>
              <span className="font-medium text-fg">{openCycles[0].title}</span>
              {openCycles[0].focus && <span className="truncate">— {openCycles[0].focus}</span>}
              <Link href={`/projets/${p.id}?onglet=operations`} className="font-medium text-primary hover:underline">Voir les grandes lignes</Link>
            </div>
          )}
          <Suspense>
            <ProjectBoard
              projectId={p.id}
              initialTasks={all}
              people={people}
              blockedIds={blockedIds}
              canContribute={Boolean(canContribute.data)}
              assignableIds={assignableIds}
            />
          </Suspense>
        </>
      )}

      <p className="mt-6 text-xs text-subtle">
        Connecté(e) en tant que {ctx.profile.full_name}. Les tâches se répartissent au sein de l&apos;équipe du projet ; chaque tâche terminée passe par une vérification.
      </p>
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
