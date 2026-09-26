import { Handshake, Percent, Target, Trophy } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { can, getContext } from "@/lib/auth";
import { getPeople } from "@/lib/data";
import { money, pct } from "@/lib/utils";
import { ButtonLink } from "@/components/ui/button";
import { Forbidden, PageHeader, StatCard } from "@/components/ui/misc";
import type { Opportunity } from "@/lib/types";
import { OpportunityFormButton } from "./crm-forms";
import { Pipeline } from "./pipeline";

export const metadata = { title: "CRM" };

export default async function CrmPage() {
  const ctx = await getContext();
  const canRead = can(ctx, "crm.view") || can(ctx, "crm.edit") || can(ctx, "dashboard.exec");
  if (!canRead) return <Forbidden message="Le CRM est réservé aux équipes Business, Marketing (lecture) et à la direction." />;
  const canEdit = can(ctx, "crm.edit");
  const supabase = await createClient();
  const year = new Date().getFullYear();
  const [{ data: opps }, { data: accounts }, people] = await Promise.all([
    supabase.from("opportunities").select("*, accounts(name)").order("amount", { ascending: false }),
    supabase.from("accounts").select("id, name").order("name"),
    getPeople(),
  ]);
  const all = (opps as (Opportunity & { accounts: { name: string } | null })[]) ?? [];
  const open = all.filter((o) => !["won", "lost"].includes(o.stage));
  const closedThisYear = all.filter((o) => o.closed_at && new Date(o.closed_at).getFullYear() === year);
  const won = closedThisYear.filter((o) => o.stage === "won");
  const winRate = closedThisYear.length ? (won.length / closedThisYear.length) * 100 : 0;

  return (
    <div>
      <PageHeader
        title="Pipeline commercial"
        description="Glissez les opportunités d'une étape à l'autre. Une opportunité gagnée crée automatiquement le projet de livraison et la facture."
        actions={
          <>
            <ButtonLink href="/crm/comptes" size="sm" variant="outline"><Handshake className="h-4 w-4" /> Comptes & contacts</ButtonLink>
            {canEdit && <OpportunityFormButton accounts={accounts ?? []} people={people} />}
          </>
        }
      />
      <div className="mb-6 grid grid-cols-2 gap-4 xl:grid-cols-4">
        <StatCard label="Pipeline ouvert" value={money(open.reduce((s, o) => s + Number(o.amount), 0), "XOF", true)} icon={Target} hint={`${open.length} opportunités`} />
        <StatCard label="Pipeline pondéré" value={money(open.reduce((s, o) => s + Number(o.amount) * o.probability / 100, 0), "XOF", true)} icon={Percent} tone="cyan" hint="montant × probabilité" />
        <StatCard label={`Gagné en ${year}`} value={money(won.reduce((s, o) => s + Number(o.amount), 0), "XOF", true)} icon={Trophy} tone="green" hint={`${won.length} signature(s)`} />
        <StatCard label="Taux de transformation" value={pct(winRate)} icon={Handshake} tone="amber" hint={`sur ${closedThisYear.length} affaire(s) clôturée(s)`} />
      </div>
      <Pipeline initial={all} people={people} canEdit={canEdit} />
    </div>
  );
}
