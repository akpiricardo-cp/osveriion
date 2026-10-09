import Link from "next/link";
import {
  AlarmClock, AlertOctagon, Banknote, Briefcase, FolderKanban, Handshake, Landmark, Receipt, TrendingDown, TrendingUp, Users, UsersRound,
} from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { can, getContext } from "@/lib/auth";
import { objectiveStatus, priority, severity, stage as stageLabels } from "@/lib/labels";
import type { ObjectiveStatus, OpportunityStage, Priority } from "@/lib/types";
import { cn, dateFr, money, num } from "@/lib/utils";
import { Card, CardHeader } from "@/components/ui/card";
import { LabelBadge } from "@/components/ui/badge";
import { EmptyState, Forbidden, PageHeader, Progress, StatCard, Table, Td, Th, Tr } from "@/components/ui/misc";
import { HBarChart, RevenueExpenseChart, TrendChart } from "@/components/charts";
import { IncidentButton, IncidentStatus, MetricsButton } from "./direction-client";

export const metadata = { title: "Dashboard de direction" };

type Dash = {
  year: number;
  kpis: Record<string, number>;
  monthly: { month: number; revenue: number; expense: number }[];
  active_users_series: { date: string; value: number }[];
  revenue_by_product: { label: string; value: number }[];
  revenue_by_country: { label: string; value: number }[];
  pipeline: { stage: OpportunityStage; count: number; amount: number }[];
  departments: { id: string; name: string; color: string; head: string | null; headcount: number; tasks_open: number; tasks_overdue: number; budget: number; spent: number; objectives_progress: number }[];
  late_tasks: { id: string; title: string; due_date: string; priority: Priority; project_id: string | null; project: string | null; assignee: string | null }[];
  incidents: { id: string; title: string; severity: "low" | "medium" | "high" | "critical"; status: "open" | "mitigated" | "resolved"; occurred_at: string; product: string | null }[];
  company_objectives: { id: string; title: string; progress: number; status: ObjectiveStatus; period: string }[];
};

const trend = (a: number, b: number) => (b ? ((a - b) / b) * 100 : 0);

export default async function DirectionPage({ searchParams }: { searchParams: Promise<{ annee?: string }> }) {
  const ctx = await getContext();
  if (!can(ctx, "dashboard.exec")) return <Forbidden message="Le dashboard de direction est réservé au CEO et aux membres de la direction." />;
  const { annee } = await searchParams;
  const year = Number(annee ?? new Date().getFullYear());
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("exec_dashboard", { p_year: year });
  if (error || !data) return <EmptyState title="Données indisponibles" description={error?.message} />;
  const d = data as Dash;
  const k = d.kpis;
  const countries: Record<string, string> = { BJ: "Bénin", CI: "Côte d'Ivoire", SN: "Sénégal", TG: "Togo", NG: "Nigeria" };

  return (
    <div className="space-y-6">
      <PageHeader
        title="Dashboard de direction"
        description={`Vue consolidée de VERIION — exercice ${d.year}. Chaque indicateur renvoie vers sa donnée source.`}
        actions={
          <>
            <div className="flex rounded-lg border border-border bg-surface p-0.5 text-[13px]">
              {[year - 1, year].map((y) => (
                <Link key={y} href={`/direction?annee=${y}`} className={cn("rounded-md px-2.5 py-1 font-medium", y === year ? "bg-surface-2 text-fg" : "text-muted hover:text-fg")}>{y}</Link>
              ))}
            </div>
            {can(ctx, "metrics.manage") && <MetricsButton />}
            <IncidentButton />
          </>
        }
      />

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard label="Utilisateurs des plateformes" value={num(k.active_users, true)} icon={Users} trend={{ value: trend(k.active_users, k.active_users_prev), label: "vs il y a 30 j" }} />
        <StatCard label="Revenus cumulés" value={money(k.revenue_ytd, "XOF", true)} icon={TrendingUp} tone="green" href="/finance" trend={k.revenue_prev ? { value: trend(k.revenue_ytd, k.revenue_prev), label: "vs N-1 même date" } : undefined} hint={k.revenue_prev ? undefined : "depuis le 1er janvier"} />
        <StatCard label="Dépenses cumulées" value={money(k.expense_ytd, "XOF", true)} icon={TrendingDown} tone="amber" href="/finance?onglet=operations" hint={k.revenue_ytd ? `marge ${Math.round(((k.revenue_ytd - k.expense_ytd) / k.revenue_ytd) * 100)} %` : undefined} />
        <StatCard label="Trésorerie" value={money(k.cash, "XOF", true)} icon={Landmark} tone={k.cash >= 0 ? "cyan" : "red"} hint={`${money(k.receivables, "XOF", true)} à encaisser`} />
        <StatCard label="Pipeline pondéré" value={money(k.pipeline_weighted, "XOF", true)} icon={Handshake} tone="pink" href="/crm" hint={`sur ${money(k.pipeline_total, "XOF", true)} ouvert`} />
        <StatCard label="Projets en cours" value={k.projects_active} icon={FolderKanban} href="/projets" hint={`${k.tasks_open} tâches ouvertes`} />
        <StatCard label="Tâches en retard" value={k.tasks_overdue} icon={AlarmClock} tone={k.tasks_overdue ? "red" : "green"} hint="toutes équipes" />
        <StatCard label="Effectif" value={k.headcount} icon={UsersRound} tone="green" href="/annuaire" hint={`${k.clients} clients · ${k.partners} partenaires`} />
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.6fr_1fr]">
        <Card>
          <CardHeader title="Revenus et dépenses" description={`Par mois, ${d.year}`} icon={<Banknote className="h-4 w-4" />} />
          <div className="p-5 pt-3"><RevenueExpenseChart data={d.monthly} /></div>
        </Card>
        <Card>
          <CardHeader title="Utilisateurs des plateformes" description="90 derniers jours, tous produits — saisie manuelle des métriques produit" icon={<Users className="h-4 w-4" />} />
          <div className="p-5 pt-3">
            {d.active_users_series.length ? <TrendChart data={d.active_users_series} label="Utilisateurs actifs" /> : <p className="py-16 text-center text-sm text-muted">Aucune métrique produit enregistrée.</p>}
            <p className="mt-2 text-xs text-subtle">{num(k.new_users_30d)} nouveaux utilisateurs sur 30 jours.</p>
          </div>
        </Card>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <Card><CardHeader title="Revenus par produit" /><div className="p-5">{d.revenue_by_product.length ? <HBarChart data={d.revenue_by_product} /> : <p className="text-sm text-muted">Aucun revenu.</p>}</div></Card>
        <Card><CardHeader title="Revenus par pays" /><div className="p-5">{d.revenue_by_country.length ? <HBarChart data={d.revenue_by_country.map((r) => ({ ...r, label: countries[r.label] ?? r.label }))} /> : <p className="text-sm text-muted">Aucun revenu.</p>}</div></Card>
        <Card>
          <CardHeader title="Pipeline commercial" description="Montant par étape" />
          <div className="p-5"><HBarChart data={d.pipeline.filter((p) => p.stage !== "lost").map((p) => ({ label: stageLabels[p.stage].label, value: Number(p.amount) }))} /></div>
        </Card>
      </div>

      <Card>
        <CardHeader title="Performance des départements" description="Effectif, exécution, budget et objectifs" icon={<Briefcase className="h-4 w-4" />} />
        <div className="mt-3">
          <Table>
            <thead><tr><Th>Département</Th><Th>Responsable</Th><Th className="text-right">Effectif</Th><Th className="text-right">Tâches ouvertes</Th><Th className="text-right">En retard</Th><Th className="w-[260px]">Budget consommé</Th><Th className="w-[160px]">Objectifs</Th></tr></thead>
            <tbody>
              {d.departments.map((u) => {
                const ratio = u.budget ? (u.spent / u.budget) * 100 : 0;
                return (
                  <Tr key={u.id}>
                    <Td><Link href={`/organisation/${u.id}`} className="flex items-center gap-2.5 font-medium hover:underline"><span className="h-2.5 w-2.5 rounded-full" style={{ background: u.color }} />{u.name}</Link></Td>
                    <Td className="text-muted">{u.head ?? <span className="italic text-subtle">Vacant</span>}</Td>
                    <Td className="text-right tabular-nums">{u.headcount}</Td>
                    <Td className="text-right tabular-nums">{u.tasks_open}</Td>
                    <Td className={cn("text-right tabular-nums", u.tasks_overdue && "font-semibold text-danger")}>{u.tasks_overdue}</Td>
                    <Td>
                      {u.budget ? (
                        <div className="flex items-center gap-2"><Progress value={ratio} tone={ratio > 100 ? "bg-rose-500" : ratio > 85 ? "bg-amber-500" : "bg-emerald-500"} /><span className="w-36 whitespace-nowrap text-right text-xs tabular-nums text-muted">{Math.round(ratio)} % · {money(u.budget, "XOF", true)}</span></div>
                      ) : <span className="text-xs text-subtle">Non défini</span>}
                    </Td>
                    <Td><div className="flex items-center gap-2"><Progress value={u.objectives_progress} /><span className="w-10 text-right text-xs tabular-nums text-muted">{u.objectives_progress} %</span></div></Td>
                  </Tr>
                );
              })}
            </tbody>
          </Table>
        </div>
      </Card>

      <div className="grid gap-6 xl:grid-cols-3">
        <Card>
          <CardHeader title="Objectifs de l'entreprise" action={<Link href="/objectifs" className="text-[13px] font-medium text-primary hover:underline">Détail</Link>} />
          <div className="space-y-4 p-5">
            {d.company_objectives.length === 0 && <p className="text-sm text-muted">Aucun objectif défini.</p>}
            {d.company_objectives.map((o) => (
              <div key={o.id}>
                <div className="mb-1.5 flex items-center justify-between gap-2"><p className="truncate text-sm font-medium text-fg">{o.title}</p><LabelBadge map={objectiveStatus} value={o.status} /></div>
                <div className="flex items-center gap-3"><Progress value={o.progress} /><span className="w-10 text-right text-xs tabular-nums text-muted">{o.progress} %</span></div>
              </div>
            ))}
          </div>
        </Card>
        <Card>
          <CardHeader title="Tâches en retard" description="Les plus anciennes échéances" icon={<AlarmClock className="h-4 w-4" />} />
          <ul className="divide-y divide-border pt-3">
            {d.late_tasks.length === 0 && <li className="px-5 py-6 text-center text-sm text-muted">Aucune tâche en retard.</li>}
            {d.late_tasks.map((t) => (
              <li key={t.id}>
                <Link href={t.project_id ? `/projets/${t.project_id}?tache=${t.id}` : "/taches"} className="flex items-center gap-3 px-5 py-2.5 hover:bg-surface-2/60">
                  <div className="min-w-0 flex-1"><p className="truncate text-sm font-medium text-fg">{t.title}</p><p className="truncate text-xs text-subtle">{t.project ?? "Personnelle"} · {t.assignee ?? "Non assignée"}</p></div>
                  <LabelBadge map={priority} value={t.priority} />
                  <span className="text-xs font-medium text-danger">{dateFr(t.due_date, "d MMM")}</span>
                </Link>
              </li>
            ))}
          </ul>
        </Card>
        <Card>
          <CardHeader title="Incidents importants" description={`${k.open_incidents} non résolu(s)`} icon={<AlertOctagon className="h-4 w-4" />} />
          <ul className="divide-y divide-border pt-3">
            {d.incidents.length === 0 && <li className="px-5 py-6 text-center text-sm text-muted">Aucun incident ouvert.</li>}
            {d.incidents.map((i) => (
              <li key={i.id} className="flex items-center gap-3 px-5 py-3">
                <span className={cn("h-2.5 w-2.5 shrink-0 rounded-full", i.severity === "critical" ? "bg-rose-600 ring-4 ring-rose-500/20" : i.severity === "high" ? "bg-rose-500" : i.severity === "medium" ? "bg-amber-500" : "bg-slate-400")} />
                <div className="min-w-0 flex-1"><p className="truncate text-sm font-medium text-fg">{i.title}</p><p className="text-xs text-subtle">{severity[i.severity].label}{i.product && ` · ${i.product}`} · {dateFr(i.occurred_at, "d MMM HH:mm")}</p></div>
                <IncidentStatus id={i.id} status={i.status} />
              </li>
            ))}
          </ul>
          {(k.pending_leaves > 0 || k.overdue_invoices > 0) && (
            <div className="space-y-1 border-t border-border px-5 py-3 text-xs text-muted">
              {k.overdue_invoices > 0 && <p className="flex items-center gap-2"><Receipt className="h-3.5 w-3.5 text-danger" />{money(k.overdue_invoices, "XOF", true)} de factures en retard de paiement</p>}
              {k.pending_leaves > 0 && <p className="flex items-center gap-2"><UsersRound className="h-3.5 w-3.5 text-amber-500" />{k.pending_leaves} demande(s) de congé en attente</p>}
            </div>
          )}
        </Card>
      </div>
    </div>
  );
}
