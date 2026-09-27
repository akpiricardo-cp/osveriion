import { AlarmClock, FileSignature, Gavel, ShieldCheck } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { can, getContext, navAccess } from "@/lib/auth";
import { getPeople, getUnits, peopleMap, unitOptions } from "@/lib/data";
import { money } from "@/lib/utils";
import { Forbidden, PageHeader, StatCard } from "@/components/ui/misc";
import { LinkTabs } from "@/components/ui/tabs";
import { ContractList, ContractDialog } from "./legal-client";
import type { LegalContract } from "@/lib/types";

export const metadata = { title: "Juridique" };

const TABS = ["encours", "signature", "echeances", "archives"] as const;

export default async function LegalPage({ searchParams }: { searchParams: Promise<{ onglet?: string; contrat?: string }> }) {
  const { onglet = "encours" } = await searchParams;
  const ctx = await getContext();
  if (!navAccess(ctx).legal) return <Forbidden message="Le registre juridique est réservé au département juridique et à la direction." />;

  const supabase = await createClient();
  const [{ data: rows }, people, units, { data: projects }, { data: accounts }] = await Promise.all([
    supabase.from("legal_contracts").select("*").order("created_at", { ascending: false }).limit(300),
    getPeople(),
    getUnits(),
    supabase.from("projects").select("id, name").is("archived_at", null).order("name"),
    supabase.from("accounts").select("id, name").order("name").limit(200),
  ]);

  const all = (rows ?? []) as LegalContract[];
  const today = new Date().toISOString().slice(0, 10);
  const inForce = all.filter((c) => c.status === "signed" || c.status === "active");
  const awaiting = all.filter((c) => c.status === "draft" || c.status === "legal_review" || c.status === "pending_ceo");
  const expiring = inForce.filter((c) => {
    if (!c.end_date) return false;
    const notice = new Date(c.end_date);
    notice.setDate(notice.getDate() - c.renewal_notice_days);
    return notice.toISOString().slice(0, 10) <= today;
  });
  const archived = all.filter((c) => c.status === "expired" || c.status === "terminated");

  const shown =
    onglet === "signature" ? awaiting : onglet === "echeances" ? expiring : onglet === "archives" ? archived : inForce;
  const engaged = inForce.reduce((s, c) => s + Number(c.amount ?? 0), 0);
  const editable = can(ctx, "legal.admin");

  return (
    <div>
      <PageHeader
        title="Juridique"
        description="Le registre des engagements de la holding : contrats, échéances, renouvellements et niveau de risque. Toute signature passe par l'accord du CEO."
        actions={
          editable ? (
            <ContractDialog
              people={people}
              units={unitOptions(units)}
              projects={projects ?? []}
              accounts={accounts ?? []}
            />
          ) : undefined
        }
      />

      <div className="mb-6 grid grid-cols-2 gap-4 xl:grid-cols-4">
        <StatCard label="Contrats en vigueur" value={inForce.length} icon={ShieldCheck} tone="green" hint="signés et actifs" />
        <StatCard label="En cours de traitement" value={awaiting.length} icon={FileSignature} tone="amber" hint="rédaction, revue, signature" />
        <StatCard label="Échéances proches" value={expiring.length} icon={AlarmClock} tone={expiring.length ? "red" : "green"} hint="préavis de renouvellement entamé" />
        <StatCard label="Montant engagé" value={money(engaged, "XOF", true)} icon={Gavel} hint="contrats en vigueur" />
      </div>

      <LinkTabs
        basePath="/juridique"
        active={TABS.includes(onglet as (typeof TABS)[number]) ? onglet : "encours"}
        className="mb-6"
        tabs={[
          { key: "encours", label: "En vigueur", count: inForce.length },
          { key: "signature", label: "À traiter", count: awaiting.length },
          { key: "echeances", label: "Échéances", count: expiring.length },
          { key: "archives", label: "Archives", count: archived.length },
        ]}
      />

      <ContractList
        contracts={shown}
        people={Object.fromEntries(peopleMap(people))}
        projects={Object.fromEntries((projects ?? []).map((p) => [p.id, p.name]))}
        editable={editable}
        formData={{ people, units: unitOptions(units), projects: projects ?? [], accounts: accounts ?? [] }}
      />
    </div>
  );
}
