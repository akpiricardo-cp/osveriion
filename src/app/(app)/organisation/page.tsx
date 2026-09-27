import { Building2, FolderKanban, Network, UserX, Users } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { can, getContext } from "@/lib/auth";
import { getPeople, getUnits, peopleMap, unitOptions } from "@/lib/data";
import { PageHeader, StatCard, EmptyState } from "@/components/ui/misc";
import { Card } from "@/components/ui/card";
import { LinkTabs } from "@/components/ui/tabs";
import { OrgChart, buildTree } from "./org-chart";
import { CreateUnitButton } from "./unit-forms";
import { Coordination, type CoordProject, type Liaison } from "./coordination";

export const metadata = { title: "Organisation" };

export default async function OrganisationPage({ searchParams }: { searchParams: Promise<{ onglet?: string }> }) {
  const { onglet = "organigramme" } = await searchParams;
  const ctx = await getContext();
  const supabase = await createClient();

  const [units, people, { data: memberships }, { data: projectRows }, { data: liaisonRows }] = await Promise.all([
    getUnits(),
    getPeople(),
    supabase.from("unit_memberships").select("unit_id, profile_id, role, title").is("end_date", null),
    supabase.from("projects").select("id, name, code, color, status, lead_id").is("archived_at", null).order("name"),
    supabase.from("project_liaisons").select("project_id, unit_id, profile_id, note"),
  ]);

  const ms = memberships ?? [];
  const pm = peopleMap(people);
  const roots = buildTree(units, ms, pm);
  const root = roots.find((r) => r.unit.kind === "company") ?? roots[0];
  const ceo = people.find((p) => p.id === ctx.userId && ctx.isCeo) ?? null;
  const canManage = can(ctx, "org.manage");
  const projects = (projectRows ?? []) as CoordProject[];
  const liaisons = (liaisonRows ?? []) as Liaison[];

  const departments = units
    .filter((u) => u.kind === "department" && u.parent_id === root?.unit.id)
    .map((u) => ({ id: u.id, name: u.name, code: u.code, color: u.color, head_title: u.head_title }));

  const vacant = units.filter((u) => u.kind !== "company" && !ms.some((m) => m.unit_id === u.id && m.role === "head")).length;
  const unassigned = people.filter((p) => !ms.some((m) => m.profile_id === p.id)).length;
  const missingLiaisons = projects.length * departments.length - liaisons.length;

  // Un responsable ne désigne un référent que pour son propre département.
  const manageableUnits = canManage
    ? departments.map((d) => d.id)
    : departments.filter((d) => ctx.grants.some((g) => g.permission === "unit.manage" && (g.scope_unit_id === null || g.scope_unit_id === d.id))).map((d) => d.id);

  return (
    <div>
      <PageHeader
        title="Organisation"
        description="VERIION est une holding : une équipe administrative transverse d'un côté, des projets dirigés par leur Chief Product de l'autre. Chaque département désigne un référent par projet — c'est lui que le chef de projet appelle."
        actions={canManage ? <CreateUnitButton units={unitOptions(units)} parentId={root?.unit.id} /> : undefined}
      />

      <div className="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard label="Départements" value={departments.length} icon={Building2} hint="fonctions transverses" />
        <StatCard label="Projets pilotés" value={projects.length} icon={FolderKanban} tone="cyan" href="/projets" hint={`${projects.filter((p) => p.status === "active").length} actifs`} />
        <StatCard label="Collaborateurs actifs" value={people.length} icon={Users} tone="green" href="/annuaire" hint={unassigned ? `${unassigned} sans affectation` : "tous affectés"} />
        <StatCard
          label="Postes à pourvoir"
          value={vacant}
          icon={UserX}
          tone={vacant ? "amber" : "green"}
          hint={missingLiaisons > 0 ? `${missingLiaisons} référent(s) à désigner` : "coordination complète"}
        />
      </div>

      <LinkTabs
        basePath="/organisation"
        active={onglet}
        className="mb-6"
        tabs={[
          { key: "organigramme", label: "Organigramme" },
          { key: "coordination", label: "Projets & référents", count: projects.length },
        ]}
      />

      {onglet === "coordination" ? (
        <Coordination
          projects={projects}
          departments={departments}
          liaisons={liaisons}
          people={people}
          manageableUnits={manageableUnits}
        />
      ) : (
        <Card className="p-4 sm:p-6">
          {root ? (
            <OrgChart root={root} ceo={ceo} />
          ) : (
            <EmptyState
              icon={Network}
              title="Organisation vide"
              description="Exécutez le fichier supabase/seed.sql ou créez votre première unité."
              action={canManage ? <CreateUnitButton units={[]} label="Créer l'entreprise" /> : undefined}
            />
          )}
        </Card>
      )}
    </div>
  );
}
