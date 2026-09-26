import Link from "next/link";
import { notFound } from "next/navigation";
import { Briefcase, Building2, CalendarDays, Mail, MapPin, Phone, ShieldCheck, Users } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { can, getContext } from "@/lib/auth";
import { getPeople, getUnits, peopleMap, unitOptions } from "@/lib/data";
import { contractType, membershipRole, systemRole } from "@/lib/labels";
import type { Membership, Profile } from "@/lib/types";
import { dateFr, money } from "@/lib/utils";
import { Avatar } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Card, CardHeader } from "@/components/ui/card";
import { KeyValue } from "@/components/ui/misc";
import { EditProfileButton, MessageButton } from "./profile-client";

export default async function ProfilePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const ctx = await getContext();
  const supabase = await createClient();
  const { data: profile } = await supabase.from("profiles").select("*").eq("id", id).maybeSingle();
  if (!profile) notFound();
  const p = profile as Profile;

  const [people, units, membershipsRes, reportsRes, contractsRes, salaryRes, managesRes] = await Promise.all([
    getPeople(),
    getUnits(),
    supabase.from("unit_memberships").select("*").eq("profile_id", id).order("start_date", { ascending: false }),
    supabase.from("profiles").select("id, full_name, avatar_url, job_title").eq("manager_id", id).eq("status", "active"),
    supabase.from("employment_contracts").select("*").eq("profile_id", id).order("start_date", { ascending: false }),
    supabase.from("salaries").select("*").eq("profile_id", id).order("effective_from", { ascending: false }).limit(1),
    supabase.rpc("manages_profile", { p_profile: id }),
  ]);
  const pm = peopleMap(people);
  const memberships = (membershipsRes.data as Membership[]) ?? [];
  const active = memberships.filter((m) => !m.end_date);
  const past = memberships.filter((m) => m.end_date);
  const unit = (uid: string) => units.find((u) => u.id === uid);
  const manager = p.manager_id ? pm.get(p.manager_id) : null;
  const isMe = id === ctx.userId;
  const isAdmin = can(ctx, "users.admin");
  const canEdit = isMe || isAdmin || Boolean(managesRes.data);
  const contract = contractsRes.data?.[0];
  const salary = salaryRes.data?.[0];

  return (
    <div className="space-y-6">
      <Card className="overflow-hidden">
        <div className="relative h-28 bg-brand">
          <div className="bg-grid absolute inset-0 opacity-70" />
          <div className="absolute -right-10 -top-16 h-56 w-56 rounded-full bg-indigo-600/30 blur-3xl" />
        </div>
        <div className="flex flex-col gap-4 px-6 pb-6 sm:flex-row sm:items-end">
          <Avatar name={p.full_name} src={p.avatar_url} size="xl" className="-mt-10 ring-4 ring-surface" />
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <h1 className="text-2xl font-semibold tracking-tight text-fg">{p.full_name}</h1>
              {p.system_role !== "employee" && <Badge tone="violet"><ShieldCheck className="h-3 w-3" />{systemRole[p.system_role]}</Badge>}
              {p.status !== "active" && <Badge tone="red">{p.status === "suspended" ? "Suspendu" : "Parti"}</Badge>}
            </div>
            <p className="text-sm text-muted">{p.job_title ?? "Poste non renseigné"}</p>
          </div>
          <div className="flex gap-2">
            {!isMe && p.status === "active" && <MessageButton id={p.id} />}
            {canEdit && (
              <EditProfileButton
                profile={p}
                people={people}
                units={unitOptions(units)}
                admin={isAdmin}
                manager={isAdmin || Boolean(managesRes.data)}
                ceo={ctx.isCeo}
              />
            )}
          </div>
        </div>
      </Card>

      <div className="grid gap-6 lg:grid-cols-[1fr_1.3fr]">
        <div className="space-y-6">
          <Card>
            <CardHeader title="Coordonnées" />
            <div className="space-y-3 p-5 text-sm">
              <p className="flex items-center gap-3 text-fg"><Mail className="h-4 w-4 text-subtle" /><a href={`mailto:${p.email}`} className="hover:underline">{p.email}</a></p>
              {p.phone && <p className="flex items-center gap-3 text-fg"><Phone className="h-4 w-4 text-subtle" />{p.phone}</p>}
              {p.location && <p className="flex items-center gap-3 text-fg"><MapPin className="h-4 w-4 text-subtle" />{p.location}</p>}
              {p.hire_date && <p className="flex items-center gap-3 text-fg"><CalendarDays className="h-4 w-4 text-subtle" />Arrivé(e) le {dateFr(p.hire_date)}</p>}
            </div>
            {p.bio && <p className="border-t border-border px-5 py-4 text-sm leading-relaxed text-muted">{p.bio}</p>}
          </Card>

          <Card>
            <CardHeader title="Rattachement" icon={<Users className="h-4 w-4" />} />
            <div className="p-5">
              <p className="mb-2 text-xs font-medium uppercase tracking-wider text-subtle">Manager</p>
              {manager ? (
                <Link href={`/annuaire/${manager.id}`} className="flex items-center gap-3 rounded-lg p-2 hover:bg-surface-2/60">
                  <Avatar name={manager.full_name} src={manager.avatar_url} size="sm" />
                  <div><p className="text-sm font-medium text-fg">{manager.full_name}</p><p className="text-xs text-subtle">{manager.job_title}</p></div>
                </Link>
              ) : <p className="text-sm text-muted">Non défini</p>}
              {(reportsRes.data?.length ?? 0) > 0 && (
                <>
                  <p className="mb-2 mt-5 text-xs font-medium uppercase tracking-wider text-subtle">Équipe directe ({reportsRes.data!.length})</p>
                  <ul className="space-y-1">
                    {reportsRes.data!.map((r) => (
                      <li key={r.id}>
                        <Link href={`/annuaire/${r.id}`} className="flex items-center gap-3 rounded-lg p-2 hover:bg-surface-2/60">
                          <Avatar name={r.full_name} src={r.avatar_url} size="xs" />
                          <span className="text-sm text-fg">{r.full_name}</span>
                          <span className="truncate text-xs text-subtle">{r.job_title}</span>
                        </Link>
                      </li>
                    ))}
                  </ul>
                </>
              )}
            </div>
          </Card>

          {(contract || salary) && (
            <Card>
              <CardHeader title="Dossier RH" description="Visible par la personne et les RH" icon={<Briefcase className="h-4 w-4" />} />
              <div className="divide-y divide-border px-5 pb-3">
                {contract && <KeyValue label="Contrat">{contractType[contract.type]} depuis le {dateFr(contract.start_date)}</KeyValue>}
                {contract?.end_date && <KeyValue label="Fin de contrat">{dateFr(contract.end_date)}</KeyValue>}
                {salary && <KeyValue label="Salaire brut mensuel">{money(salary.gross_monthly, salary.currency)}</KeyValue>}
              </div>
            </Card>
          )}
        </div>

        <Card>
          <CardHeader title="Affectations" description="Postes actuels et historique complet" icon={<Building2 className="h-4 w-4" />} />
          <div className="p-5">
            {active.length === 0 && <p className="text-sm text-muted">Aucune affectation active.</p>}
            <ul className="space-y-2">
              {active.map((m) => {
                const u = unit(m.unit_id);
                return (
                  <li key={m.id}>
                    <Link href={`/organisation/${m.unit_id}`} className="flex items-center gap-3 rounded-xl border border-border p-3 transition hover:border-primary/30">
                      <span className="h-9 w-1.5 rounded-full" style={{ background: u?.color }} />
                      <div className="min-w-0 flex-1">
                        <p className="text-sm font-medium text-fg">{u?.name ?? "Unité archivée"}</p>
                        <p className="text-xs text-subtle">{m.title ?? membershipRole[m.role]} · depuis le {dateFr(m.start_date)}</p>
                      </div>
                      <Badge tone={m.role === "head" ? "violet" : m.role === "deputy" ? "blue" : "neutral"}>{membershipRole[m.role]}</Badge>
                    </Link>
                  </li>
                );
              })}
            </ul>
            {past.length > 0 && (
              <>
                <p className="mb-3 mt-6 text-xs font-medium uppercase tracking-wider text-subtle">Historique</p>
                <ol className="relative ml-2 space-y-4 border-l border-border pl-5">
                  {past.map((m) => (
                    <li key={m.id} className="relative">
                      <span className="absolute -left-[26px] top-1.5 h-2.5 w-2.5 rounded-full border-2 border-surface bg-subtle" />
                      <p className="text-sm text-fg">{membershipRole[m.role]} — {unit(m.unit_id)?.name ?? "Unité archivée"}</p>
                      <p className="text-xs text-subtle">{dateFr(m.start_date)} → {dateFr(m.end_date)}{m.title && ` · ${m.title}`}</p>
                    </li>
                  ))}
                </ol>
              </>
            )}
          </div>
        </Card>
      </div>
    </div>
  );
}
