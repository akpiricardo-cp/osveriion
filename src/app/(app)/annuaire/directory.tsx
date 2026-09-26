"use client";

import { useMemo, useState, useTransition } from "react";
import Link from "next/link";
import { Mail, MapPin, MessageSquare, Phone, Search } from "lucide-react";
import { Avatar } from "@/components/ui/avatar";
import { Input, Select } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { EmptyState } from "@/components/ui/misc";
import { openDirectMessage } from "./actions";

type Person = { id: string; full_name: string; email: string; job_title: string | null; avatar_url: string | null; phone: string | null; location: string | null; primary_unit_id: string | null; last_seen_at: string | null };

export function Directory({
  people, units, departments, memberships, me,
}: {
  me: string;
  people: Person[];
  units: Record<string, { name: string; color: string; path: string[] }>;
  departments: { id: string; name: string }[];
  memberships: { profile_id: string; unit_id: string; role: string }[];
}) {
  const [q, setQ] = useState("");
  const [dept, setDept] = useState("");
  const [pending, start] = useTransition();

  const filtered = useMemo(() => {
    const s = q.trim().toLowerCase();
    return people.filter((p) => {
      if (s && !`${p.full_name} ${p.email} ${p.job_title ?? ""}`.toLowerCase().includes(s)) return false;
      if (dept) {
        const inDept = memberships.some((m) => m.profile_id === p.id && units[m.unit_id]?.path.includes(dept));
        if (!inDept) return false;
      }
      return true;
    });
  }, [people, q, dept, memberships, units]);

  const online = (d: string | null) => d && Date.now() - new Date(d).getTime() < 5 * 60000;

  return (
    <div>
      <div className="mb-5 flex flex-col gap-3 sm:flex-row">
        <div className="relative flex-1">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-subtle" />
          <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Nom, poste, e-mail…" className="pl-9" />
        </div>
        <div className="sm:w-64">
          <Select value={dept} onChange={(e) => setDept(e.target.value)}>
            <option value="">Tous les départements</option>
            {departments.map((d) => <option key={d.id} value={d.id}>{d.name}</option>)}
          </Select>
        </div>
      </div>
      {filtered.length === 0 ? (
        <EmptyState icon={Search} title="Aucun résultat" description="Modifiez votre recherche." />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
          {filtered.map((p) => {
            const roles = memberships.filter((m) => m.profile_id === p.id);
            const main = roles.find((r) => r.unit_id === p.primary_unit_id) ?? roles[0];
            const u = main ? units[main.unit_id] : null;
            return (
              <div key={p.id} className="group relative flex flex-col rounded-2xl border border-border bg-surface p-5 shadow-card transition hover:border-primary/30 hover:shadow-md">
                <div className="flex items-start gap-3.5">
                  <div className="relative">
                    <Avatar name={p.full_name} src={p.avatar_url} size="lg" />
                    {online(p.last_seen_at) && <span className="absolute bottom-0.5 right-0.5 h-3 w-3 rounded-full bg-emerald-500 ring-2 ring-surface" />}
                  </div>
                  <div className="min-w-0 flex-1">
                    <Link href={`/annuaire/${p.id}`} className="block truncate text-[15px] font-semibold text-fg after:absolute after:inset-0">{p.full_name}</Link>
                    <p className="truncate text-[13px] text-muted">{p.job_title ?? "—"}</p>
                    {u && (
                      <p className="mt-1.5 flex items-center gap-1.5 truncate text-xs text-subtle">
                        <span className="h-2 w-2 rounded-full" style={{ background: u.color }} /> {u.name}
                        {main?.role === "head" && <Badge tone="violet" className="ml-1">Responsable</Badge>}
                      </p>
                    )}
                  </div>
                </div>
                <div className="mt-4 space-y-1.5 text-[13px] text-muted">
                  <p className="flex items-center gap-2 truncate"><Mail className="h-3.5 w-3.5 shrink-0 text-subtle" />{p.email}</p>
                  {p.phone && <p className="flex items-center gap-2"><Phone className="h-3.5 w-3.5 text-subtle" />{p.phone}</p>}
                  {p.location && <p className="flex items-center gap-2"><MapPin className="h-3.5 w-3.5 text-subtle" />{p.location}</p>}
                </div>
                {p.id !== me && <button
                  disabled={pending}
                  onClick={() => start(() => openDirectMessage(p.id))}
                  className="relative z-10 mt-4 inline-flex items-center justify-center gap-2 rounded-lg border border-border py-1.5 text-[13px] font-medium text-fg transition hover:bg-surface-2 disabled:opacity-50"
                >
                  <MessageSquare className="h-4 w-4" /> Message
                </button>}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
