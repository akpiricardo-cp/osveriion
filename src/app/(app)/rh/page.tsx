import Link from "next/link";
import { CalendarCheck, CalendarClock, ClipboardCheck, Palmtree, UserCheck, Users } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { can, canAnywhere, getContext } from "@/lib/auth";
import { getPeople, peopleMap } from "@/lib/data";
import { contractType, leaveType, requestStatus } from "@/lib/labels";
import type { LeaveRequest } from "@/lib/types";
import { dateFr, money } from "@/lib/utils";
import { Avatar } from "@/components/ui/avatar";
import { Badge, LabelBadge } from "@/components/ui/badge";
import { Card, CardHeader } from "@/components/ui/card";
import { EmptyState, PageHeader, Progress, StatCard, Table, Td, Th, Tr } from "@/components/ui/misc";
import { LinkTabs } from "@/components/ui/tabs";
import { LifecycleChecklist } from "./lifecycle-checklist";
import { CancelLeaveButton, ContractButton, ContractStepButtons, DecideButtons, LeaveRequestButton, LifecycleItemButton } from "./rh-client";

export const metadata = { title: "Ressources humaines" };
const ANNUAL_ALLOWANCE = 30; // 2,5 jours ouvrables par mois (Code du travail béninois)

export default async function HrPage({ searchParams }: { searchParams: Promise<{ onglet?: string }> }) {
  const { onglet = "conges" } = await searchParams;
  const ctx = await getContext();
  const supabase = await createClient();
  const hrView = can(ctx, "hr.view") || can(ctx, "hr.admin");
  const hrAdmin = can(ctx, "hr.admin");
  const isManager = canAnywhere(ctx, "unit.manage") || hrAdmin;
  const people = await getPeople();
  const pm = peopleMap(people);
  const year = new Date().getFullYear();

  const [{ data: mine }, { data: pending }, { data: upcoming }] = await Promise.all([
    supabase.from("leave_requests").select("*").eq("profile_id", ctx.userId).order("start_date", { ascending: false }),
    supabase.from("leave_requests").select("*").eq("status", "pending").neq("profile_id", ctx.userId).order("start_date"),
    supabase.from("leave_requests").select("*").eq("status", "approved").gte("end_date", new Date().toISOString().slice(0, 10)).order("start_date").limit(30),
  ]);
  const myLeaves = (mine as LeaveRequest[]) ?? [];
  const usedDays = myLeaves.filter((l) => l.status === "approved" && l.type === "annual" && l.start_date.startsWith(String(year))).reduce((s, l) => s + Number(l.days), 0);
  const pendingList = (pending as LeaveRequest[]) ?? [];

  return (
    <div>
      <PageHeader title="Ressources humaines" description="Congés, contrats, intégration et départs." actions={<LeaveRequestButton />} />
      <LinkTabs basePath="/rh" active={onglet} className="mb-6" tabs={[
        { key: "conges", label: "Mes congés" },
        { key: "validation", label: "À valider", count: pendingList.length, hidden: !isManager && !pendingList.length },
        { key: "effectif", label: "Effectif & contrats", hidden: !hrView },
        { key: "parcours", label: "Intégrations & départs", hidden: !hrView && !isManager },
      ]} />

      {onglet === "conges" && (
        <div className="space-y-6">
          <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
            <StatCard label={`Congés payés ${year}`} value={`${Math.max(0, ANNUAL_ALLOWANCE - usedDays)} j`} icon={Palmtree} tone="green" hint={`restants sur ${ANNUAL_ALLOWANCE}`} />
            <StatCard label="Jours pris" value={`${usedDays} j`} icon={CalendarCheck} hint="congés payés approuvés" />
            <StatCard label="En attente" value={myLeaves.filter((l) => l.status === "pending").length} icon={CalendarClock} tone="amber" />
            <StatCard label="Demandes" value={myLeaves.length} icon={ClipboardCheck} tone="cyan" hint="depuis votre arrivée" />
          </div>
          <Card>
            <CardHeader title="Mes demandes" />
            <div className="mt-3">
              {myLeaves.length === 0 ? <EmptyState icon={Palmtree} title="Aucune demande" description="Vos demandes d'absence apparaîtront ici." /> : (
                <Table>
                  <thead><tr><Th>Type</Th><Th>Période</Th><Th>Jours</Th><Th>Statut</Th><Th>Décision</Th><Th /></tr></thead>
                  <tbody>
                    {myLeaves.map((l) => (
                      <Tr key={l.id}>
                        <Td className="font-medium">{leaveType[l.type]}</Td>
                        <Td className="text-muted">{dateFr(l.start_date)} → {dateFr(l.end_date)}</Td>
                        <Td className="tabular-nums">{Number(l.days)}</Td>
                        <Td><LabelBadge map={requestStatus} value={l.status} /></Td>
                        <Td className="text-xs text-muted">{l.approver_id ? `${pm.get(l.approver_id)?.full_name ?? "—"}${l.decision_note ? ` — ${l.decision_note}` : ""}` : "—"}</Td>
                        <Td className="text-right">{l.status === "pending" && <CancelLeaveButton id={l.id} />}</Td>
                      </Tr>
                    ))}
                  </tbody>
                </Table>
              )}
            </div>
          </Card>
        </div>
      )}

      {onglet === "validation" && (
        <div className="grid gap-6 xl:grid-cols-[1.5fr_1fr]">
          <Card>
            <CardHeader title="Demandes en attente" description="Vous voyez les demandes des personnes que vous encadrez." icon={<UserCheck className="h-4 w-4" />} />
            <ul className="divide-y divide-border pt-3">
              {pendingList.length === 0 && <EmptyState icon={UserCheck} title="Tout est traité" description="Aucune demande en attente." />}
              {pendingList.map((l) => {
                const p = pm.get(l.profile_id);
                return (
                  <li key={l.id} className="flex flex-col gap-3 px-5 py-4 sm:flex-row sm:items-center">
                    <Avatar name={p?.full_name} src={p?.avatar_url} size="md" />
                    <div className="min-w-0 flex-1">
                      <p className="text-sm font-semibold text-fg">{p?.full_name}</p>
                      <p className="text-[13px] text-muted">{leaveType[l.type]} · {dateFr(l.start_date, "d MMM")} → {dateFr(l.end_date, "d MMM yyyy")} · <span className="font-medium text-fg">{Number(l.days)} j</span></p>
                      {l.reason && <p className="mt-1 text-xs text-subtle">« {l.reason} »</p>}
                    </div>
                    <DecideButtons id={l.id} />
                  </li>
                );
              })}
            </ul>
          </Card>
          <Card>
            <CardHeader title="Absences à venir" icon={<Palmtree className="h-4 w-4" />} />
            <ul className="space-y-1 p-3">
              {(upcoming ?? []).length === 0 && <li className="px-2 py-3 text-sm text-muted">Aucune absence prévue.</li>}
              {(upcoming as LeaveRequest[] ?? []).map((l) => {
                const p = pm.get(l.profile_id);
                return (
                  <li key={l.id} className="flex items-center gap-3 rounded-lg px-2 py-2">
                    <Avatar name={p?.full_name} src={p?.avatar_url} size="xs" />
                    <span className="flex-1 truncate text-sm text-fg">{p?.full_name}</span>
                    <span className="text-xs text-subtle">{dateFr(l.start_date, "d MMM")} → {dateFr(l.end_date, "d MMM")}</span>
                  </li>
                );
              })}
            </ul>
          </Card>
        </div>
      )}

      {onglet === "effectif" && hrView && <Staff hrAdmin={hrAdmin} />}
      {onglet === "parcours" && (hrView || isManager) && <Journeys />}
    </div>
  );

  async function Staff({ hrAdmin }: { hrAdmin: boolean }) {
    const [{ data: profiles }, { data: contracts }, { data: salaries }] = await Promise.all([
      supabase.from("profiles").select("id, full_name, avatar_url, job_title, hire_date, status, email").order("first_name"),
      supabase.from("employment_contracts").select("*").order("start_date", { ascending: false }),
      hrAdmin ? supabase.from("salaries").select("profile_id, gross_monthly, effective_from").order("effective_from", { ascending: false }) : Promise.resolve({ data: [] as { profile_id: string; gross_monthly: number }[] }),
    ]);
    const all = profiles ?? [];
    const active = all.filter((p) => p.status === "active");
    const payroll = active.reduce((s, p) => s + Number((salaries ?? []).find((x) => x.profile_id === p.id)?.gross_monthly ?? 0), 0);
    const signed = (contracts ?? []).filter((c) => c.status === "signed");
    const ending = signed.filter((c) => c.end_date && c.end_date >= new Date().toISOString().slice(0, 10) && c.end_date <= new Date(Date.now() + 60 * 86400000).toISOString().slice(0, 10));
    const inProgress = (contracts ?? []).filter((c) => c.status === "draft" || c.status === "pending_ceo");
    const { data: decisions } = inProgress.length
      ? await supabase.from("approval_requests_status").select("subject_id, status, stale").eq("kind", "employment_contract").in("subject_id", inProgress.map((c) => c.id))
      : { data: [] as { subject_id: string; status: string; stale: boolean }[] };
    const approvedIds = new Set((decisions ?? []).filter((d) => d.status === "approved" && !d.stale).map((d) => d.subject_id));
    const statusLabel: Record<string, string> = { draft: "Brouillon", pending_ceo: "Chez le CEO", signed: "Signé", ended: "Clos" };
    return (
      <div className="space-y-6">
        <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
          <StatCard label="Effectif actif" value={active.length} icon={Users} />
          <StatCard label="Arrivées cette année" value={active.filter((p) => p.hire_date?.startsWith(String(year))).length} icon={UserCheck} tone="green" />
          <StatCard label="Fins de contrat (60 j)" value={ending.length} icon={CalendarClock} tone={ending.length ? "amber" : "green"} />
          {hrAdmin ? <StatCard label="Masse salariale mensuelle" value={money(payroll, "XOF", true)} icon={ClipboardCheck} tone="cyan" hint="brut, effectif actif" /> : <StatCard label="Départs" value={all.filter((p) => p.status === "offboarded").length} icon={Users} tone="red" />}
        </div>
        {hrAdmin && inProgress.length > 0 && (
          <Card>
            <CardHeader title="Contrats en préparation" description="Brouillon → accord du CEO → signature. Le salaire convenu s'applique à la signature." icon={<ClipboardCheck className="h-4 w-4" />} />
            <div className="mt-3">
              <Table>
                <thead><tr><Th>Collaborateur</Th><Th>Contrat</Th><Th>Début</Th><Th className="text-right">Brut mensuel</Th><Th>Étape</Th><Th /></tr></thead>
                <tbody>
                  {inProgress.map((c) => (
                    <Tr key={c.id}>
                      <Td className="font-medium">{pm.get(c.profile_id)?.full_name ?? "—"}<span className="block text-xs text-subtle">{c.job_title ?? ""}</span></Td>
                      <Td><Badge tone="blue">{contractType[c.type as keyof typeof contractType]}</Badge></Td>
                      <Td className="text-muted">{dateFr(c.start_date)}</Td>
                      <Td className="text-right tabular-nums">{c.gross_monthly != null ? money(c.gross_monthly) : "—"}</Td>
                      <Td><Badge tone={approvedIds.has(c.id) ? "green" : c.status === "pending_ceo" ? "amber" : "neutral"} dot>{approvedIds.has(c.id) ? "Accord obtenu" : statusLabel[c.status]}</Badge></Td>
                      <Td className="text-right"><ContractStepButtons id={c.id} status={c.status} approved={approvedIds.has(c.id)} /></Td>
                    </Tr>
                  ))}
                </tbody>
              </Table>
            </div>
          </Card>
        )}
        <Card>
          <CardHeader title="Collaborateurs" action={hrAdmin ? <ContractButton people={people} /> : undefined} />
          <div className="mt-3">
            <Table>
              <thead><tr><Th>Collaborateur</Th><Th>Contrat</Th><Th>Arrivée</Th><Th>Fin</Th>{hrAdmin && <Th className="text-right">Brut mensuel</Th>}<Th>Statut</Th>{hrAdmin && <Th />}</tr></thead>
              <tbody>
                {all.map((p) => {
                  const c = signed.find((x) => x.profile_id === p.id);
                  const s = (salaries ?? []).find((x) => x.profile_id === p.id);
                  return (
                    <Tr key={p.id}>
                      <Td><Link href={`/annuaire/${p.id}`} className="flex items-center gap-3"><Avatar name={p.full_name} src={p.avatar_url} size="sm" /><span><span className="block font-medium hover:underline">{p.full_name}</span><span className="text-xs text-subtle">{p.job_title ?? p.email}</span></span></Link></Td>
                      <Td>{c ? <Badge tone="blue">{contractType[c.type]}</Badge> : <span className="text-xs text-subtle">Aucun</span>}</Td>
                      <Td className="text-muted">{p.hire_date ? dateFr(p.hire_date) : "—"}</Td>
                      <Td className="text-muted">{c?.end_date ? dateFr(c.end_date) : "—"}</Td>
                      {hrAdmin && <Td className="text-right tabular-nums">{s ? money(s.gross_monthly) : "—"}</Td>}
                      <Td><Badge tone={p.status === "active" ? "green" : p.status === "suspended" ? "amber" : "neutral"} dot>{p.status === "active" ? "Actif" : p.status === "suspended" ? "Suspendu" : "Parti"}</Badge></Td>
                      {hrAdmin && <Td className="text-right"><ContractButton people={people} profileId={p.id} /></Td>}
                    </Tr>
                  );
                })}
              </tbody>
            </Table>
          </div>
        </Card>
      </div>
    );
  }

  async function Journeys() {
    const { data } = await supabase.from("lifecycle_items").select("*").order("position");
    const items = data ?? [];
    const byPerson = new Map<string, typeof items>();
    items.filter((i) => i.profile_id !== ctx.userId || hrView).forEach((i) => {
      const k = `${i.profile_id}|${i.kind}`;
      if (!byPerson.has(k)) byPerson.set(k, []);
      byPerson.get(k)!.push(i);
    });
    const groups = [...byPerson.entries()].filter(([, list]) => list.some((i) => !i.done_at));
    if (!groups.length) return <EmptyState icon={ClipboardCheck} title="Aucun parcours en cours" description="Les intégrations et départs en cours s'afficheront ici." />;
    return (
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {groups.map(([key, list]) => {
          const [pid, kind] = key.split("|");
          const p = pm.get(pid);
          const done = list.filter((i) => i.done_at).length;
          return (
            <Card key={key}>
              <div className="flex items-center gap-3 px-5 pt-5">
                <Avatar name={p?.full_name ?? "Ancien collaborateur"} src={p?.avatar_url} size="md" />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold text-fg">{p?.full_name ?? "Ancien collaborateur"}</p>
                  <Badge tone={kind === "onboarding" ? "green" : "amber"}>{kind === "onboarding" ? "Intégration" : "Départ"}</Badge>
                </div>
                <LifecycleItemButton profileId={pid} kind={kind as "onboarding" | "offboarding"} people={people} />
              </div>
              <div className="px-5 pt-3"><Progress value={(done / list.length) * 100} /></div>
              <LifecycleChecklist items={list} />
            </Card>
          );
        })}
      </div>
    );
  }
}
