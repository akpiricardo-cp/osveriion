import Link from "next/link";
import { CalendarDays, FolderKanban } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { getContext } from "@/lib/auth";
import { getPeople, getUnits, peopleMap, unitOptions } from "@/lib/data";
import { projectStatus } from "@/lib/labels";
import type { Project, ProjectStatus } from "@/lib/types";
import { cn, dateFr, isOverdue } from "@/lib/utils";
import { LabelBadge } from "@/components/ui/badge";
import { AvatarStack } from "@/components/ui/avatar";
import { EmptyState, PageHeader, Progress } from "@/components/ui/misc";
import { LinkTabs } from "@/components/ui/tabs";
import { ProjectFormButton } from "./project-form";

export const metadata = { title: "Projets" };

export default async function ProjectsPage({ searchParams }: { searchParams: Promise<{ onglet?: string }> }) {
  const { onglet = "actifs" } = await searchParams;
  const ctx = await getContext();
  const supabase = await createClient();
  const [{ data: projects }, { data: tasks }, { data: members }, people, units] = await Promise.all([
    supabase.from("projects").select("*").is("archived_at", null).order("created_at", { ascending: false }),
    supabase.from("tasks").select("project_id, status, due_date").not("project_id", "is", null).is("parent_id", null),
    supabase.from("project_members").select("project_id, profile_id"),
    getPeople(),
    getUnits(),
  ]);
  const pm = peopleMap(people);
  const all = (projects as Project[]) ?? [];
  const filters: Record<string, (p: Project) => boolean> = {
    actifs: (p) => (["planned", "active", "on_hold"] as ProjectStatus[]).includes(p.status),
    miens: (p) => p.owner_id === ctx.userId || (members ?? []).some((m) => m.project_id === p.id && m.profile_id === ctx.userId),
    termines: (p) => p.status === "completed" || p.status === "cancelled",
    tous: () => true,
  };
  const list = all.filter(filters[onglet] ?? filters.actifs);
  const unitName = (id: string | null) => units.find((u) => u.id === id)?.name;

  return (
    <div>
      <PageHeader
        title="Projets"
        description="Les produits de la holding. Chacun a son Chief Product, son équipe et ses référents dans les départements."
        actions={<ProjectFormButton units={unitOptions(units)} people={people} />}
      />
      <LinkTabs
        basePath="/projets"
        active={onglet}
        className="mb-6"
        tabs={[
          { key: "actifs", label: "En cours", count: all.filter(filters.actifs).length },
          { key: "miens", label: "Mes projets", count: all.filter(filters.miens).length },
          { key: "termines", label: "Terminés", count: all.filter(filters.termines).length },
          { key: "tous", label: "Tous", count: all.length },
        ]}
      />
      {list.length === 0 ? (
        <EmptyState icon={FolderKanban} title="Aucun projet ici" description="Créez un projet pour organiser les tâches, les échéances et la discussion de l'équipe." />
      ) : (
        <div className="grid gap-4 md:grid-cols-2 2xl:grid-cols-3">
          {list.map((p) => {
            const pt = (tasks ?? []).filter((t) => t.project_id === p.id);
            const done = pt.filter((t) => t.status === "done").length;
            const late = pt.filter((t) => t.status !== "done" && isOverdue(t.due_date)).length;
            const team = (members ?? []).filter((m) => m.project_id === p.id).map((m) => pm.get(m.profile_id)).filter(Boolean) as { full_name: string; avatar_url: string | null }[];
            return (
              <Link key={p.id} href={`/projets/${p.id}`} className="group relative overflow-hidden rounded-2xl border border-border bg-surface p-5 shadow-card transition hover:-translate-y-0.5 hover:border-primary/30 hover:shadow-lg">
                <span className="absolute inset-x-0 top-0 h-1" style={{ background: p.color }} />
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="font-mono text-[11px] text-subtle">{p.code}{unitName(p.unit_id) && ` · ${unitName(p.unit_id)}`}</p>
                    <h3 className="mt-1 truncate text-[15px] font-semibold text-fg group-hover:text-primary">{p.name}</h3>
                  </div>
                  <LabelBadge map={projectStatus} value={p.status} />
                </div>
                {p.description && <p className="mt-2 line-clamp-2 text-[13px] text-muted">{p.description}</p>}
                <div className="mt-4">
                  <div className="mb-1.5 flex justify-between text-xs text-muted">
                    <span>{done}/{pt.length} tâches</span>
                    <span className="tabular-nums">{pt.length ? Math.round((done / pt.length) * 100) : 0} %</span>
                  </div>
                  <Progress value={pt.length ? (done / pt.length) * 100 : 0} />
                </div>
                <div className="mt-4 flex items-center justify-between">
                  <AvatarStack people={team} />
                  <div className="flex items-center gap-3 text-xs">
                    {late > 0 && <span className="font-medium text-danger">{late} en retard</span>}
                    {p.due_date && <span className={cn("flex items-center gap-1 text-subtle", isOverdue(p.due_date, p.status === "completed") && "text-danger")}><CalendarDays className="h-3.5 w-3.5" />{dateFr(p.due_date, "d MMM yyyy")}</span>}
                  </div>
                </div>
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
