import Link from "next/link";
import { CalendarRange, ClipboardCheck, FolderKanban, Send } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { can, getContext, navAccess } from "@/lib/auth";
import { getPeople, peopleMap } from "@/lib/data";
import { dateFr } from "@/lib/utils";
import { Card, CardHeader } from "@/components/ui/card";
import { Badge, LabelBadge } from "@/components/ui/badge";
import { EmptyState, Forbidden, PageHeader, StatCard } from "@/components/ui/misc";
import { LinkTabs } from "@/components/ui/tabs";
import { cycleKind, cycleStatus } from "@/lib/labels";
import { CycleDialog, CycleCard, ReportList } from "./operations-client";
import type { OperationCycle, OperationItem, OperationReport } from "@/lib/types";

export const metadata = { title: "Opérations" };

export default async function OperationsPage({
  searchParams,
}: {
  searchParams: Promise<{ onglet?: string; projet?: string }>;
}) {
  const { onglet = "calendriers", projet } = await searchParams;
  const ctx = await getContext();
  if (!navAccess(ctx).operations) {
    return <Forbidden message="L'espace Opérations est réservé au département des Opérations et à la direction." />;
  }

  const supabase = await createClient();
  const planner = can(ctx, "ops.plan") || can(ctx, "projects.admin") || ctx.isCeo;

  const [{ data: projectRows }, { data: cycleRows }, { data: reportRows }, people] = await Promise.all([
    supabase.from("projects").select("id, name, code, color, status, lead_id").is("archived_at", null).order("name"),
    supabase
      .from("operation_cycles")
      .select("*, operation_items(*)")
      .order("period_start", { ascending: false })
      .limit(120),
    supabase.from("operation_reports").select("*").order("created_at", { ascending: false }).limit(60),
    getPeople(),
  ]);

  type Project = { id: string; name: string; code: string; color: string; status: string; lead_id: string | null };
  type CycleWithItems = OperationCycle & { operation_items: OperationItem[] };

  const projects = (projectRows ?? []) as Project[];
  const cycles = (cycleRows ?? []) as CycleWithItems[];
  const reports = (reportRows ?? []) as OperationReport[];
  const pm = peopleMap(people);

  const selected = projet ? projects.find((p) => p.id === projet) ?? null : null;
  const visible = selected ? cycles.filter((c) => c.project_id === selected.id) : cycles;
  const month = new Date().toISOString().slice(0, 7);
  const published = cycles.filter((c) => c.status === "published");
  const awaitingReport = published.filter(
    (c) => c.period_end < new Date().toISOString().slice(0, 10) && !reports.some((r) => r.cycle_id === c.id),
  );
  const toAcknowledge = reports.filter((r) => r.status === "submitted");

  return (
    <div>
      <PageHeader
        title="Opérations"
        description="Le calendrier de chaque projet s'écrit ici : les grandes lignes du mois, de la semaine et du jour. Les chefs de projet les traduisent en tâches et rendent compte à la fin de chaque cycle."
        crumbs={selected ? [{ label: "Opérations", href: "/operations" }, { label: selected.name }] : undefined}
        actions={planner ? <CycleDialog projects={projects} defaultProject={selected?.id} /> : undefined}
      />

      <div className="mb-6 grid grid-cols-2 gap-4 xl:grid-cols-4">
        <StatCard label="Projets pilotés" value={projects.filter((p) => p.status === "active").length} icon={FolderKanban} hint="en cours" href="/projets" />
        <StatCard label="Calendriers publiés" value={published.length} icon={CalendarRange} tone="green" hint="toutes périodes" />
        <StatCard label="Rapports à traiter" value={toAcknowledge.length} icon={ClipboardCheck} tone={toAcknowledge.length ? "amber" : "green"} hint="en attente d'accusé" />
        <StatCard label="Rapports manquants" value={awaitingReport.length} icon={Send} tone={awaitingReport.length ? "red" : "green"} hint="cycles clos sans compte rendu" />
      </div>

      <LinkTabs
        basePath="/operations"
        active={onglet}
        className="mb-6"
        tabs={[
          { key: "calendriers", label: "Calendriers", count: visible.length },
          { key: "rapports", label: "Rapports", count: reports.length },
        ]}
      />

      {onglet === "rapports" ? (
        <ReportList
          reports={reports}
          projects={Object.fromEntries(projects.map((p) => [p.id, p.name]))}
          cycles={Object.fromEntries(cycles.map((c) => [c.id, c.title]))}
          people={Object.fromEntries(pm)}
          canAcknowledge={can(ctx, "ops.review") || can(ctx, "ops.plan") || ctx.isCeo}
        />
      ) : (
        <div className="space-y-6">
          {!selected && (
            <Card>
              <CardHeader title="Par projet" description="Où en est le calendrier de chaque produit de la holding ce mois-ci." />
              <ul className="mt-3 divide-y divide-border">
                {projects.length === 0 && (
                  <li><EmptyState icon={FolderKanban} title="Aucun projet" description="Créez un projet pour commencer à planifier ses opérations." /></li>
                )}
                {projects.map((p) => {
                  const current = cycles.find((c) => c.project_id === p.id && c.kind === "monthly" && c.period_start.startsWith(month));
                  const lead = p.lead_id ? pm.get(p.lead_id) : null;
                  return (
                    <li key={p.id}>
                      <Link href={`/operations?projet=${p.id}`} className="flex items-center gap-3 px-5 py-3 transition hover:bg-surface-2/60">
                        <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ background: p.color }} />
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-sm font-medium text-fg">{p.name}</p>
                          <p className="truncate text-xs text-subtle">
                            {lead ? `Chief Product : ${lead.full_name}` : "Chief Product à nommer"}
                          </p>
                        </div>
                        {current ? <LabelBadge map={cycleStatus} value={current.status} /> : <Badge tone="red" dot>Calendrier du mois absent</Badge>}
                      </Link>
                    </li>
                  );
                })}
              </ul>
            </Card>
          )}

          {visible.length === 0 ? (
            <Card>
              <EmptyState
                icon={CalendarRange}
                title="Aucun calendrier"
                description="Créez un cycle mensuel, hebdomadaire ou journalier, puis listez-y les grandes lignes attendues du projet."
              />
            </Card>
          ) : (
            <div className="space-y-4">
              {visible.map((c) => (
                <CycleCard
                  key={c.id}
                  cycle={c}
                  items={c.operation_items ?? []}
                  projectName={projects.find((p) => p.id === c.project_id)?.name ?? "Projet"}
                  people={people}
                  canPlan={planner}
                  subtitle={`${cycleKind[c.kind]} · ${dateFr(c.period_start)} → ${dateFr(c.period_end)}`}
                />
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
