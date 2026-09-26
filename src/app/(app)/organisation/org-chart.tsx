import Link from "next/link";
import { Users } from "lucide-react";
import { Avatar } from "@/components/ui/avatar";
import type { OrgUnit, ProfileLite } from "@/lib/types";
import { cn } from "@/lib/utils";

export interface UnitNode {
  unit: OrgUnit;
  head?: ProfileLite & { title?: string | null };
  deputy?: ProfileLite;
  headcount: number;
  children: UnitNode[];
}

function HeadLine({ node }: { node: UnitNode }) {
  if (!node.head) return <span className="truncate text-[11px] italic text-subtle">À nommer</span>;
  return (
    <span className="flex min-w-0 items-center gap-1.5">
      <Avatar name={node.head.full_name} src={node.head.avatar_url} size="xs" />
      <span className="truncate text-[11.5px] text-muted">{node.head.full_name}</span>
    </span>
  );
}

function SubTree({ nodes, color, depth }: { nodes: UnitNode[]; color: string; depth: number }) {
  if (!nodes.length) return null;
  return (
    <ul className={cn("relative space-y-2", depth === 0 ? "ml-3 mt-3 border-l-2 pl-4" : "ml-3 mt-2 border-l pl-3")} style={{ borderColor: `${color}55` }}>
      {nodes.map((n) => (
        <li key={n.unit.id} className="relative">
          <span className="absolute -left-4 top-5 h-px w-4" style={{ background: `${color}55`, left: depth === 0 ? "-1rem" : "-0.75rem", width: depth === 0 ? "1rem" : "0.75rem" }} />
          <Link
            href={`/organisation/${n.unit.id}`}
            className={cn(
              "group block overflow-hidden rounded-xl border bg-surface transition hover:-translate-y-0.5 hover:shadow-md",
              depth === 0 ? "px-3 py-2.5" : "rounded-full px-3 py-1.5 text-center",
            )}
            style={{ borderColor: `${color}40`, background: depth === 0 ? `color-mix(in srgb, ${color} 6%, var(--surface))` : undefined }}
          >
            {depth === 0 ? (
              <div className="flex items-start gap-2.5">
                <span className="mt-0.5 h-8 w-1 shrink-0 rounded-full" style={{ background: color }} />
                <div className="min-w-0 flex-1">
                  <p className="line-clamp-2 break-words text-[12.5px] font-medium leading-snug text-fg" title={n.unit.name}>{n.unit.name}</p>
                  <div className="mt-1 flex min-w-0 items-center justify-between gap-2">
                    <HeadLine node={n} />
                    <span className="flex shrink-0 items-center gap-1 text-[11px] text-subtle"><Users className="h-3 w-3" />{n.headcount}</span>
                  </div>
                </div>
              </div>
            ) : (
              <span className="text-[12px] font-medium" style={{ color }}>{n.unit.name}</span>
            )}
          </Link>
          <SubTree nodes={n.children} color={color} depth={depth + 1} />
        </li>
      ))}
    </ul>
  );
}

export function OrgChart({ root, ceo }: { root: UnitNode; ceo?: ProfileLite | null }) {
  const departments = root.children;
  const leader = root.head ?? ceo ?? undefined;
  return (
    <div className="scrollbar-thin overflow-x-auto pb-4">
      <div className="mx-auto px-2 pt-2" style={{ minWidth: Math.max(640, departments.length * 168) }}>
        <div className="flex justify-center">
          <Link href={`/organisation/${root.unit.id}`} className="relative w-[320px] overflow-hidden rounded-2xl bg-brand p-4 text-white shadow-xl ring-1 ring-white/10 transition hover:-translate-y-0.5">
            <div className="absolute -right-10 -top-10 h-32 w-32 rounded-full bg-indigo-500/30 blur-2xl" />
            <p className="relative text-[10px] font-medium uppercase tracking-[0.2em] text-indigo-200/80">Direction générale</p>
            <p className="relative mt-1 text-lg font-semibold tracking-tight">{root.unit.name}</p>
            <div className="relative mt-3 flex items-center gap-2.5">
              <Avatar name={leader?.full_name ?? "CEO"} src={leader?.avatar_url} size="sm" />
              <div className="min-w-0 leading-tight">
                <p className="truncate text-[13px] font-medium">{leader?.full_name ?? "À nommer"}</p>
                <p className="text-[11px] text-slate-400">Directeur Général (CEO)</p>
              </div>
              <span className="ml-auto flex items-center gap-1 text-xs text-slate-300"><Users className="h-3.5 w-3.5" />{root.headcount}</span>
            </div>
          </Link>
        </div>

        {departments.length > 0 && (
          <>
            <div className="mx-auto h-6 w-px bg-fg/25" />
            <div className="relative grid gap-3" style={{ gridTemplateColumns: `repeat(${departments.length}, minmax(152px, 1fr))` }}>
              {departments.length > 1 && (
                <div
                  className="absolute top-0 h-px bg-fg/25"
                  style={{ left: `calc(100% / ${departments.length} / 2)`, right: `calc(100% / ${departments.length} / 2)` }}
                />
              )}
              {departments.map((d) => (
                <div key={d.unit.id} className="relative pt-6">
                  <div className="absolute left-1/2 top-0 h-6 w-px bg-fg/25" />
                  <Link href={`/organisation/${d.unit.id}`} className="block overflow-hidden rounded-2xl border border-border bg-surface shadow-card transition hover:-translate-y-0.5 hover:shadow-lg">
                    <div className="flex items-center justify-between px-3 py-1.5 text-white" style={{ background: d.unit.color }}>
                      <span className="text-[11px] font-semibold uppercase tracking-wider">{d.head?.title ?? d.unit.code ?? "Département"}</span>
                      <span className="flex items-center gap-1 text-[11px] opacity-90"><Users className="h-3 w-3" />{d.headcount}</span>
                    </div>
                    <div className="px-3 py-3">
                      <p className="truncate text-[14px] font-semibold text-fg">{d.unit.name}</p>
                      <div className="mt-2"><HeadLine node={d} /></div>
                    </div>
                  </Link>
                  <SubTree nodes={d.children} color={d.unit.color} depth={0} />
                </div>
              ))}
            </div>
          </>
        )}
      </div>
    </div>
  );
}

/** Construit l'arbre à partir des unités et des affectations actives. */
export function buildTree(
  units: OrgUnit[],
  memberships: { unit_id: string; profile_id: string; role: string; title: string | null }[],
  people: Map<string, ProfileLite>,
): UnitNode[] {
  const nodes = new Map<string, UnitNode>();
  units.forEach((u) => nodes.set(u.id, { unit: u, headcount: 0, children: [] }));
  memberships.forEach((m) => {
    const n = nodes.get(m.unit_id);
    const p = people.get(m.profile_id);
    if (!n || !p) return;
    if (m.role === "head") n.head = { ...p, title: m.title };
    if (m.role === "deputy") n.deputy = p;
  });
  // effectif = personnes distinctes dans le sous-arbre
  units.forEach((u) => {
    const set = new Set<string>();
    memberships.forEach((m) => {
      const mu = units.find((x) => x.id === m.unit_id);
      if (mu && mu.path.includes(u.id)) set.add(m.profile_id);
    });
    nodes.get(u.id)!.headcount = set.size;
  });
  const roots: UnitNode[] = [];
  units.forEach((u) => {
    const n = nodes.get(u.id)!;
    if (u.parent_id && nodes.has(u.parent_id)) nodes.get(u.parent_id)!.children.push(n);
    else roots.push(n);
  });
  const sort = (list: UnitNode[]) => {
    list.sort((a, b) => a.unit.sort_order - b.unit.sort_order || a.unit.name.localeCompare(b.unit.name));
    list.forEach((n) => sort(n.children));
  };
  sort(roots);
  return roots;
}
