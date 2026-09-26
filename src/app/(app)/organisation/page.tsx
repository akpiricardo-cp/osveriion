import { Building2, Network, UserX, Users } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { can, getContext } from "@/lib/auth";
import { getPeople, getUnits, peopleMap, unitOptions } from "@/lib/data";
import { PageHeader, StatCard, EmptyState } from "@/components/ui/misc";
import { Card } from "@/components/ui/card";
import { OrgChart, buildTree } from "./org-chart";
import { CreateUnitButton } from "./unit-forms";

export const metadata = { title: "Organisation" };

export default async function OrganisationPage() {
  const ctx = await getContext();
  const supabase = await createClient();
  const [units, people, { data: memberships }] = await Promise.all([
    getUnits(),
    getPeople(),
    supabase.from("unit_memberships").select("unit_id, profile_id, role, title").is("end_date", null),
  ]);
  const ms = memberships ?? [];
  const pm = peopleMap(people);
  const roots = buildTree(units, ms, pm);
  const root = roots.find((r) => r.unit.kind === "company") ?? roots[0];
  const ceo = people.find((p) => p.id === ctx.userId && ctx.isCeo) ?? null;
  const canManage = can(ctx, "org.manage");
  const vacant = units.filter((u) => u.kind !== "company" && !ms.some((m) => m.unit_id === u.id && m.role === "head")).length;
  const unassigned = people.filter((p) => !ms.some((m) => m.profile_id === p.id)).length;

  return (
    <div>
      <PageHeader
        title="Organisation"
        description="Structure de VERIION : départements, sous-départements, équipes et responsables. Chaque nomination met à jour les droits d'accès."
        actions={canManage ? <CreateUnitButton units={unitOptions(units)} parentId={root?.unit.id} /> : undefined}
      />
      <div className="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard label="Départements" value={units.filter((u) => u.kind === "department").length} icon={Building2} />
        <StatCard label="Unités au total" value={units.length} icon={Network} tone="cyan" />
        <StatCard label="Collaborateurs actifs" value={people.length} icon={Users} tone="green" href="/annuaire" />
        <StatCard label="Postes de responsable vacants" value={vacant} icon={UserX} tone={vacant ? "amber" : "green"} hint={unassigned ? `${unassigned} personne(s) sans affectation` : undefined} />
      </div>
      <Card className="p-4 sm:p-6">
        {root ? (
          <OrgChart root={root} ceo={ceo} />
        ) : (
          <EmptyState icon={Building2} title="Organisation vide" description="Exécutez le fichier supabase/seed.sql ou créez votre première unité." action={canManage ? <CreateUnitButton units={[]} label="Créer l'entreprise" /> : undefined} />
        )}
      </Card>
    </div>
  );
}
