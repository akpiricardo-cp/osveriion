import Link from "next/link";
import { notFound } from "next/navigation";
import {
  AlarmClock, Building2, CalendarDays, FileText, FolderKanban, History, MessagesSquare, Target, Users, Wallet,
} from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { can, canOnUnit, getContext } from "@/lib/auth";
import { getPeople, getUnits, peopleMap, unitOptions } from "@/lib/data";
import { membershipRole, objectiveStatus, projectStatus, unitDomain, unitKind } from "@/lib/labels";
import type { Membership, ObjectiveProgress, Project } from "@/lib/types";
import { dateFr, money } from "@/lib/utils";
import { Card, CardHeader } from "@/components/ui/card";
import { Avatar } from "@/components/ui/avatar";
import { Badge, LabelBadge } from "@/components/ui/badge";
import { ButtonLink } from "@/components/ui/button";
import { EmptyState, PageHeader, Progress, StatCard } from "@/components/ui/misc";
import { AppointButton, ArchiveUnitButton, CreateUnitButton, EditUnitButton } from "../unit-forms";
import { EndMembershipButton } from "./member-actions";

export default async function UnitPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const ctx = await getContext();
  const supabase = await createClient();
  const [units, people] = await Promise.all([getUnits(), getPeople()]);
  const unit = units.find((u) => u.id === id);
  if (!unit) notFound();
  const pm = peopleMap(people);
  const subtree = units.filter((u) => u.path.includes(id));
  const subtreeIds = subtree.map((u) => u.id);

  const [overviewRes, membersRes, historyRes, objectivesRes, projectsRes, channelRes, meetingsRes, canManage, canManageParent, spaceRes] = await Promise.all([
    supabase.rpc("unit_overview", { p_unit: id }),
    supabase.from("unit_memberships").select("*").in("unit_id", subtreeIds).is("end_date", null).order("start_date"),
    supabase.from("unit_memberships").select("*").eq("unit_id", id).not("end_date", "is", null).order("end_date", { ascending: false }).limit(12),
    supabase.from("objectives_progress").select("*").eq("level", "unit").eq("unit_id", id).order("created_at"),
    supabase.from("projects").select("*").in("unit_id", subtreeIds).is("archived_at", null).order("created_at", { ascending: false }).limit(8),
    supabase.from("channels").select("id").eq("kind", "unit").eq("unit_id", id).maybeSingle(),
    supabase.from("meetings").select("id, title, starts_at").in("unit_id", subtreeIds).gte("starts_at", new Date().toISOString()).order("starts_at").limit(4),
    canOnUnit("unit.manage", id),
    canOnUnit("unit.manage", unit.parent_id),
    supabase.from("folders").select("id").eq("space", "unit").eq("unit_id", id).eq("is_root", true).maybeSingle(),
  ]);

  const ov = (overviewRes.data ?? {}) as Record<string, number | null>;
  const members = (membersRes.data as Membership[]) ?? [];
  const history = (historyRes.data as Membership[]) ?? [];
  const objectives = (objectivesRes.data as ObjectiveProgress[]) ?? [];
  const projects = (projectsRes.data as Project[]) ?? [];
  const orgManage = can(ctx, "org.manage");
  const manage = canManage || orgManage;
  const canAppointHead = orgManage || canManageParent;
  const head = members.find((m) => m.unit_id === id && m.role === "head");
  const deputy = members.find((m) => m.unit_id === id && m.role === "deputy");
  const children = units.filter((u) => u.parent_id === id);
  const ancestors = unit.path.slice(0, -1).map((a) => units.find((u) => u.id === a)).filter(Boolean);
  const unitName = (uid: string) => units.find((u) => u.id === uid)?.name ?? "";
  const budget = ov.budget != null ? Number(ov.budget) : null;
  const spent = Number(ov.spent ?? 0);

  return (
    <div className="space-y-6">
      <PageHeader
        crumbs={[{ label: "Organisation", href: "/organisation" }, ...ancestors.map((a) => ({ label: a!.name, href: `/organisation/${a!.id}` })), { label: unit.name }]}
        title={
          <span className="flex items-center gap-3">
            <span className="h-7 w-2 rounded-full" style={{ background: unit.color }} />
            {unit.name}
          </span>
        }
        description={unit.description ?? `${unitKind[unit.kind]} · domaine ${unitDomain[unit.domain].toLowerCase()}`}
        actions={
          <>
            {channelRes.data && <ButtonLink href={`/messages/${channelRes.data.id}`} size="sm" variant="outline"><MessagesSquare className="h-4 w-4" /> Canal</ButtonLink>}
            {manage && <EditUnitButton unit={unit} units={unitOptions(units)} canRestructure={orgManage || canManageParent} />}
            {manage && <CreateUnitButton units={unitOptions(units)} parentId={unit.id} label="Sous-unité" />}
            {orgManage && unit.kind !== "company" && <ArchiveUnitButton id={unit.id} />}
          </>
        }
      />

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard label="Effectif" value={ov.headcount ?? 0} icon={Users} hint={`${children.length} sous-unité(s)`} />
        <StatCard label="Tâches ouvertes" value={ov.tasks_open ?? 0} icon={FolderKanban} tone="cyan" hint={`${ov.projects_active ?? 0} projet(s) actif(s)`} />
        <StatCard label="En retard" value={ov.tasks_overdue ?? 0} icon={AlarmClock} tone={ov.tasks_overdue ? "red" : "green"} hint={`${ov.tasks_done_30d ?? 0} terminées sur 30 j`} />
        {budget !== null ? (
          <StatCard label={`Budget ${new Date().getFullYear()}`} value={money(budget, "XOF", true)} icon={Wallet} tone="amber"
            hint={budget > 0 ? `${Math.round((spent / budget) * 100)} % consommé` : "non défini"} />
        ) : (
          <StatCard label="Objectifs" value={`${ov.objectives_progress ?? 0} %`} icon={Target} tone="green" hint={`${ov.objectives ?? 0} objectif(s)`} />
        )}
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.5fr_1fr]">
        <div className="space-y-6">
          <Card>
            <CardHeader title="Équipe" description={`${members.length} affectation(s) active(s), sous-unités comprises`} icon={<Users className="h-4 w-4" />}
              action={
                <div className="flex gap-2">
                  {canAppointHead && <AppointButton unitId={id} people={people} defaultRole="head" label={head ? "Changer de responsable" : "Nommer le responsable"} variant="outline" />}
                  {manage && <AppointButton unitId={id} people={people} />}
                </div>
              } />
            <div className="mt-4 grid gap-3 px-5 sm:grid-cols-2">
              {[{ m: head, label: "Responsable" }, { m: deputy, label: "Adjoint(e)" }].map(({ m, label }) => {
                const p = m ? pm.get(m.profile_id) : null;
                return (
                  <div key={label} className="flex items-center gap-3 rounded-xl border border-dashed border-border p-3">
                    <Avatar name={p?.full_name ?? "?"} src={p?.avatar_url} size="md" />
                    <div className="min-w-0">
                      <p className="text-[11px] font-medium uppercase tracking-wider text-subtle">{label}</p>
                      {p ? (
                        <Link href={`/annuaire/${p.id}`} className="block truncate text-sm font-semibold text-fg hover:underline">{p.full_name}</Link>
                      ) : (
                        <p className="text-sm italic text-subtle">Poste vacant</p>
                      )}
                      {m?.title && <p className="truncate text-xs text-muted">{m.title}</p>}
                    </div>
                  </div>
                );
              })}
            </div>
            <ul className="mt-4 divide-y divide-border border-t border-border">
              {members.length === 0 && <EmptyState icon={Users} title="Aucun membre" description="Affectez des collaborateurs à cette unité." />}
              {members.map((m) => {
                const p = pm.get(m.profile_id);
                if (!p) return null;
                return (
                  <li key={m.id} className="flex items-center gap-3 px-5 py-3">
                    <Avatar name={p.full_name} src={p.avatar_url} size="sm" />
                    <div className="min-w-0 flex-1">
                      <Link href={`/annuaire/${p.id}`} className="block truncate text-sm font-medium text-fg hover:underline">{p.full_name}</Link>
                      <p className="truncate text-xs text-subtle">{m.title ?? p.job_title ?? p.email}{m.unit_id !== id && ` · ${unitName(m.unit_id)}`}</p>
                    </div>
                    <Badge tone={m.role === "head" ? "violet" : m.role === "deputy" ? "blue" : "neutral"}>{membershipRole[m.role]}</Badge>
                    <span className="hidden w-28 text-right text-xs text-subtle sm:block">depuis {dateFr(m.start_date, "MMM yyyy")}</span>
                    {manage && m.unit_id === id && <EndMembershipButton membershipId={m.id} unitId={id} />}
                  </li>
                );
              })}
            </ul>
          </Card>

          <Card>
            <CardHeader title="Projets" icon={<FolderKanban className="h-4 w-4" />} action={<Link href="/projets" className="text-[13px] font-medium text-primary hover:underline">Tous les projets</Link>} />
            <div className="mt-3">
              {projects.length === 0 ? (
                <EmptyState icon={FolderKanban} title="Aucun projet" description="Les projets rattachés à cette unité apparaîtront ici." />
              ) : (
                <ul className="divide-y divide-border">
                  {projects.map((p) => (
                    <li key={p.id}>
                      <Link href={`/projets/${p.id}`} className="flex items-center gap-3 px-5 py-3 hover:bg-surface-2/60">
                        <span className="h-8 w-1.5 rounded-full" style={{ background: p.color }} />
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-sm font-medium text-fg">{p.name}</p>
                          <p className="text-xs text-subtle">{p.code}{p.due_date && ` · échéance ${dateFr(p.due_date)}`}</p>
                        </div>
                        <LabelBadge map={projectStatus} value={p.status} />
                      </Link>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </Card>
        </div>

        <div className="space-y-6">
          <Card>
            <CardHeader title="Objectifs de l'unité" icon={<Target className="h-4 w-4" />} action={<Link href="/objectifs" className="text-[13px] font-medium text-primary hover:underline">Gérer</Link>} />
            <div className="space-y-4 p-5">
              {objectives.length === 0 && <p className="text-sm text-muted">Aucun objectif défini pour cette unité.</p>}
              {objectives.map((o) => (
                <div key={o.id}>
                  <div className="mb-1.5 flex items-center justify-between gap-2">
                    <p className="truncate text-sm font-medium text-fg">{o.title}</p>
                    <LabelBadge map={objectiveStatus} value={o.status} />
                  </div>
                  <div className="flex items-center gap-3"><Progress value={o.progress} /><span className="w-10 text-right text-xs tabular-nums text-muted">{o.progress} %</span></div>
                </div>
              ))}
            </div>
          </Card>

          {budget !== null && (
            <Card>
              <CardHeader title="Budget" description={`Exercice ${new Date().getFullYear()}`} icon={<Wallet className="h-4 w-4" />} />
              <div className="p-5">
                <div className="flex items-end justify-between">
                  <p className="text-2xl font-semibold tabular-nums text-fg">{money(spent)}</p>
                  <p className="text-sm text-muted">sur {money(budget)}</p>
                </div>
                <Progress className="mt-3 h-2" value={budget ? (spent / budget) * 100 : 0} tone={budget && spent > budget ? "bg-rose-500" : "bg-primary"} />
                <p className="mt-2 text-xs text-subtle">Dépenses imputées à l&apos;unité et à ses sous-unités.</p>
              </div>
            </Card>
          )}

          {children.length > 0 && (
            <Card>
              <CardHeader title="Sous-unités" icon={<Building2 className="h-4 w-4" />} />
              <ul className="space-y-1 p-3">
                {children.map((c) => (
                  <li key={c.id}>
                    <Link href={`/organisation/${c.id}`} className="flex items-center gap-3 rounded-lg px-2 py-2 hover:bg-surface-2/60">
                      <span className="h-2.5 w-2.5 rounded-full" style={{ background: c.color }} />
                      <span className="flex-1 truncate text-sm text-fg">{c.name}</span>
                      <span className="text-xs text-subtle">{unitKind[c.kind]}</span>
                    </Link>
                  </li>
                ))}
              </ul>
            </Card>
          )}

          <Card>
            <CardHeader title="À venir" icon={<CalendarDays className="h-4 w-4" />} />
            <ul className="space-y-1 p-3">
              {(meetingsRes.data ?? []).length === 0 && <li className="px-2 py-2 text-sm text-muted">Aucune réunion planifiée.</li>}
              {(meetingsRes.data ?? []).map((m) => (
                <li key={m.id} className="flex items-center justify-between rounded-lg px-2 py-2 text-sm">
                  <span className="truncate text-fg">{m.title}</span>
                  <span className="text-xs text-subtle">{dateFr(m.starts_at, "d MMM HH:mm")}</span>
                </li>
              ))}
              <li className="flex items-center justify-between rounded-lg px-2 py-2 text-sm">
                <Link href={spaceRes.data ? `/documents?dossier=${spaceRes.data.id}` : "/documents"} className="flex items-center gap-2 text-muted hover:text-fg"><FileText className="h-4 w-4" /> Documents de l&apos;unité</Link>
                <span className="text-xs text-subtle">{ov.documents ?? 0}</span>
              </li>
            </ul>
          </Card>

          {history.length > 0 && (
            <Card>
              <CardHeader title="Historique des affectations" icon={<History className="h-4 w-4" />} />
              <ul className="space-y-2 p-5">
                {history.map((h) => (
                  <li key={h.id} className="flex items-center gap-3 text-sm">
                    <Avatar name={pm.get(h.profile_id)?.full_name ?? "Ancien membre"} size="xs" />
                    <span className="flex-1 truncate text-muted">
                      <span className="font-medium text-fg">{pm.get(h.profile_id)?.full_name ?? "Ancien membre"}</span> · {membershipRole[h.role]}
                    </span>
                    <span className="text-xs text-subtle">{dateFr(h.start_date, "MM/yy")} → {dateFr(h.end_date, "MM/yy")}</span>
                  </li>
                ))}
              </ul>
            </Card>
          )}
        </div>
      </div>
    </div>
  );
}
