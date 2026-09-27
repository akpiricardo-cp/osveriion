import { Stamp } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { canDecideApprovals, getContext, navAccess } from "@/lib/auth";
import { getPeople, getUnits, peopleMap, unitOptions } from "@/lib/data";
import { money } from "@/lib/utils";
import { Forbidden, PageHeader, StatCard } from "@/components/ui/misc";
import { LinkTabs } from "@/components/ui/tabs";
import { ApprovalList, RequestApprovalButton } from "./approvals-client";
import type { ApprovalRequest } from "@/lib/types";

export const metadata = { title: "Validations" };

export default async function ApprovalsPage({ searchParams }: { searchParams: Promise<{ onglet?: string }> }) {
  const { onglet = "attente" } = await searchParams;
  const ctx = await getContext();
  if (!navAccess(ctx).approvals) return <Forbidden message="Le guichet des validations est réservé aux responsables qui soumettent ou tranchent les décisions." />;

  const decider = canDecideApprovals(ctx);
  const supabase = await createClient();

  const [{ data: rows }, { data: settings }, people, units, { data: projects }] = await Promise.all([
    supabase.from("approval_requests").select("*").order("created_at", { ascending: false }).limit(200),
    supabase.from("company_settings").select("ceo_approval_threshold, currency").maybeSingle(),
    getPeople(),
    getUnits(),
    supabase.from("projects").select("id, name").is("archived_at", null).order("name"),
  ]);

  const all = (rows ?? []) as ApprovalRequest[];
  const pending = all.filter((a) => a.status === "pending");
  const mine = all.filter((a) => a.requested_by === ctx.userId);
  const decided = all.filter((a) => a.status !== "pending");
  const shown = onglet === "mes-demandes" ? mine : onglet === "historique" ? decided : pending;
  const threshold = Number(settings?.ceo_approval_threshold ?? 500000);
  const engaged = pending.reduce((s, a) => s + Number(a.amount ?? 0), 0);

  return (
    <div>
      <PageHeader
        title="Validations"
        description={
          decider
            ? "Les décisions qui engagent la holding passent ici : budgets et dépenses au-delà du seuil, contrats, calendriers mensuels, lancements de projet et embauches."
            : "Vos demandes de décision et leur suivi. Le CEO tranche depuis ce même guichet."
        }
        actions={<RequestApprovalButton units={unitOptions(units)} projects={projects ?? []} threshold={threshold} />}
      />

      <div className="mb-6 grid grid-cols-2 gap-4 xl:grid-cols-4">
        <StatCard label="En attente" value={pending.length} icon={Stamp} tone={pending.length ? "amber" : "green"} hint={decider ? "à trancher" : "chez le CEO"} />
        <StatCard label="Montants engagés" value={money(engaged, settings?.currency ?? "XOF", true)} hint="sur les demandes en attente" />
        <StatCard label="Seuil d'accord CEO" value={money(threshold, settings?.currency ?? "XOF", true)} hint="au-delà, la dépense remonte" tone="cyan" />
        <StatCard label="Mes demandes" value={mine.length} hint={`${mine.filter((a) => a.status === "approved").length} approuvées`} tone="green" />
      </div>

      <LinkTabs
        basePath="/validations"
        active={onglet}
        className="mb-6"
        tabs={[
          { key: "attente", label: decider ? "À trancher" : "En attente", count: pending.length },
          { key: "mes-demandes", label: "Mes demandes", count: mine.length },
          { key: "historique", label: "Historique", count: decided.length },
        ]}
      />

      <ApprovalList
        requests={shown}
        people={Object.fromEntries(peopleMap(people))}
        units={Object.fromEntries(units.map((u) => [u.id, u.name]))}
        projects={Object.fromEntries((projects ?? []).map((p) => [p.id, p.name]))}
        canDecide={decider}
        userId={ctx.userId}
      />
    </div>
  );
}
