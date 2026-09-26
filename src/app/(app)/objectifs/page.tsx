import Link from "next/link";
import { Building2, Gauge, Target, User } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { can, canAnywhere, getContext } from "@/lib/auth";
import { getPeople, getUnits, peopleMap, unitOptions } from "@/lib/data";
import { objectiveStatus } from "@/lib/labels";
import type { KeyResult, ObjectiveProgress, OrgUnit } from "@/lib/types";
import { cn } from "@/lib/utils";
import { Avatar } from "@/components/ui/avatar";
import { LabelBadge } from "@/components/ui/badge";
import { Card, CardHeader } from "@/components/ui/card";
import { EmptyState, PageHeader, Progress, Table, Td, Th, Tr } from "@/components/ui/misc";
import { KeyResultRow, KpiButton, ObjectiveButton, ObjectiveMenu, StatusSelect } from "./objectives-client";

export const metadata = { title: "Objectifs & KPI" };

function currentPeriod() {
  const d = new Date();
  return `${d.getFullYear()}-T${Math.floor(d.getMonth() / 3) + 1}`;
}

export default async function ObjectivesPage({ searchParams }: { searchParams: Promise<{ periode?: string }> }) {
  const { periode } = await searchParams;
  const period = periode ?? currentPeriod();
  const ctx = await getContext();
  const supabase = await createClient();
  const [{ data: objs }, { data: krs }, { data: periods }, { data: kpis }, units, people] = await Promise.all([
    supabase.from("objectives_progress").select("*").eq("period", period).order("created_at"),
    supabase.from("key_results").select("*").order("position"),
    supabase.from("objectives").select("period"),
    supabase.from("kpi_definitions").select("*").order("name"),
    getUnits(),
    getPeople(),
  ]);
  const objectives = (objs as ObjectiveProgress[]) ?? [];
  const keyResults = (krs as KeyResult[]) ?? [];
  const pm = peopleMap(people);
  const unitById = new Map(units.map((u) => [u.id, u]));
  const manages = (u?: OrgUnit) => ctx.isCeo || Boolean(u && ctx.grants.some((g) => g.permission === "unit.manage" && g.scope_unit_id && u.path.includes(g.scope_unit_id)));
  const editable = (o: ObjectiveProgress) =>
    o.level === "company" ? can(ctx, "objectives.admin")
      : o.level === "unit" ? can(ctx, "objectives.admin") || manages(unitById.get(o.unit_id ?? ""))
      : o.owner_id === ctx.userId || ctx.isCeo;
  const allowed: ("company" | "unit" | "individual")[] = [
    ...(can(ctx, "objectives.admin") ? ["company" as const] : []),
    ...(can(ctx, "objectives.admin") || canAnywhere(ctx, "unit.manage") ? ["unit" as const] : []),
    "individual",
  ];
  const allPeriods = [...new Set([period, currentPeriod(), ...(periods ?? []).map((p) => p.period)])].sort().reverse();
  const company = objectives.filter((o) => o.level === "company");
  const unitObjs = objectives.filter((o) => o.level === "unit");
  const mine = objectives.filter((o) => o.level === "individual");
  const avg = (list: ObjectiveProgress[]) => (list.length ? Math.round(list.reduce((s, o) => s + o.progress, 0) / list.length) : 0);

  const ObjectiveCard = ({ o }: { o: ObjectiveProgress }) => {
    const canEdit = editable(o);
    const owner = o.owner_id ? pm.get(o.owner_id) : null;
    const children = objectives.filter((c) => c.parent_id === o.id);
    return (
      <Card className="overflow-hidden">
        <div className="p-5">
          <div className="flex items-start gap-3">
            <div className="relative grid h-12 w-12 shrink-0 place-items-center">
              <svg viewBox="0 0 36 36" className="absolute inset-0 -rotate-90">
                <circle cx="18" cy="18" r="15.5" fill="none" stroke="var(--surface-3)" strokeWidth="3" />
                <circle cx="18" cy="18" r="15.5" fill="none" stroke={o.progress >= 70 ? "#10b981" : o.progress >= 40 ? "var(--primary)" : "#f59e0b"} strokeWidth="3" strokeLinecap="round" strokeDasharray={`${(o.progress / 100) * 97.4} 97.4`} />
              </svg>
              <span className="text-[11px] font-semibold tabular-nums text-fg">{o.progress}%</span>
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-[15px] font-semibold leading-snug text-fg">{o.title}</p>
              <div className="mt-1.5 flex flex-wrap items-center gap-2 text-xs text-subtle">
                {o.level === "unit" && o.unit_id && <Link href={`/organisation/${o.unit_id}`} className="flex items-center gap-1 hover:text-fg"><span className="h-2 w-2 rounded-full" style={{ background: unitById.get(o.unit_id)?.color }} />{unitById.get(o.unit_id)?.name}</Link>}
                {owner && <span className="flex items-center gap-1"><Avatar name={owner.full_name} src={owner.avatar_url} size="xs" />{owner.full_name}</span>}
              </div>
            </div>
            <div className="flex items-center gap-2">
              {canEdit ? <StatusSelect id={o.id} value={o.status} /> : <LabelBadge map={objectiveStatus} value={o.status} />}
              {canEdit && <ObjectiveMenu id={o.id} />}
            </div>
          </div>
          {o.description && <p className="mt-3 text-sm text-muted">{o.description}</p>}
          <ul className="mt-3 divide-y divide-border">
            {keyResults.filter((k) => k.objective_id === o.id).map((k) => <KeyResultRow key={k.id} kr={k} editable={canEdit} />)}
          </ul>
        </div>
        {children.length > 0 && (
          <div className="border-t border-border bg-surface-2/40 px-5 py-3">
            <p className="mb-2 text-[11px] font-medium uppercase tracking-wider text-subtle">Objectifs contributeurs</p>
            <ul className="space-y-2">
              {children.map((c) => (
                <li key={c.id} className="flex items-center gap-3 text-sm">
                  <span className="flex-1 truncate text-fg">{c.title}</span>
                  <Progress value={c.progress} className="w-24" />
                  <span className="w-10 text-right text-xs tabular-nums text-muted">{c.progress} %</span>
                </li>
              ))}
            </ul>
          </div>
        )}
      </Card>
    );
  };

  return (
    <div className="space-y-8">
      <PageHeader
        title="Objectifs & performance"
        description="Objectifs de l'entreprise, des départements et individuels — reliés entre eux et mesurés par des résultats clés."
        actions={
          <>
            <div className="flex max-w-full gap-1 overflow-x-auto rounded-lg border border-border bg-surface p-0.5 text-[13px]">
              {allPeriods.slice(0, 6).map((p) => (
                <Link key={p} href={`/objectifs?periode=${p}`} className={cn("whitespace-nowrap rounded-md px-2.5 py-1 font-medium", p === period ? "bg-surface-2 text-fg" : "text-muted hover:text-fg")}>{p.replace("-", " ")}</Link>
              ))}
            </div>
            <ObjectiveButton units={unitOptions(units)} parents={objectives.filter((o) => o.level !== "individual").map((o) => ({ id: o.id, title: o.title }))} people={people} period={period} allowed={allowed} />
          </>
        }
      />

      <div className="grid gap-4 sm:grid-cols-3">
        {[
          { label: "Entreprise", icon: Target, list: company },
          { label: "Départements", icon: Building2, list: unitObjs },
          { label: "Individuels", icon: User, list: mine },
        ].map(({ label, icon: Icon, list }) => (
          <div key={label} className="rounded-2xl border border-border bg-surface p-5 shadow-card">
            <div className="flex items-center justify-between"><p className="text-[13px] font-medium text-muted">{label}</p><Icon className="h-4 w-4 text-subtle" /></div>
            <p className="mt-2 text-2xl font-semibold tabular-nums text-fg">{avg(list)} %</p>
            <Progress value={avg(list)} className="mt-3" />
            <p className="mt-2 text-xs text-subtle">{list.length} objectif(s) · {list.filter((o) => o.status === "at_risk" || o.status === "off_track").length} à surveiller</p>
          </div>
        ))}
      </div>

      {objectives.length === 0 && <EmptyState icon={Target} title={`Aucun objectif pour ${period}`} description="Commencez par les objectifs de l'entreprise, puis déclinez-les par département." />}

      {company.length > 0 && (
        <section className="space-y-3">
          <h2 className="text-[15px] font-semibold text-fg">Objectifs de l&apos;entreprise</h2>
          <div className="grid gap-4 xl:grid-cols-2">{company.map((o) => <ObjectiveCard key={o.id} o={o} />)}</div>
        </section>
      )}
      {unitObjs.length > 0 && (
        <section className="space-y-3">
          <h2 className="text-[15px] font-semibold text-fg">Objectifs des départements</h2>
          <div className="grid gap-4 xl:grid-cols-2">{unitObjs.map((o) => <ObjectiveCard key={o.id} o={o} />)}</div>
        </section>
      )}
      {mine.length > 0 && (
        <section className="space-y-3">
          <h2 className="text-[15px] font-semibold text-fg">Objectifs individuels</h2>
          <div className="grid gap-4 xl:grid-cols-2">{mine.map((o) => <ObjectiveCard key={o.id} o={o} />)}</div>
        </section>
      )}

      <Card>
        <CardHeader title="Référentiel des indicateurs" description="Définition unique de chaque KPI : formule, source et responsable." icon={<Gauge className="h-4 w-4" />}
          action={(can(ctx, "dashboard.exec") || can(ctx, "objectives.admin")) ? <KpiButton people={people} /> : undefined} />
        <div className="mt-3">
          <Table>
            <thead><tr><Th>Indicateur</Th><Th>Définition</Th><Th>Formule</Th><Th>Source</Th><Th>Unité</Th></tr></thead>
            <tbody>
              {(kpis ?? []).map((k) => (
                <Tr key={k.id}>
                  <Td><span className="block font-medium">{k.name}</span><span className="font-mono text-[11px] text-subtle">{k.key}</span></Td>
                  <Td className="max-w-[260px] text-muted">{k.description}</Td>
                  <Td className="max-w-[260px] text-xs text-muted">{k.formula}</Td>
                  <Td className="font-mono text-xs text-muted">{k.source}</Td>
                  <Td className="text-muted">{k.unit}</Td>
                </Tr>
              ))}
            </tbody>
          </Table>
        </div>
      </Card>
    </div>
  );
}
