import Link from "next/link";
import { ScrollText, Settings2, ShieldCheck, Users, Workflow } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { can, getContext } from "@/lib/auth";
import { getPeople, getUnits, peopleMap, unitOptions } from "@/lib/data";
import { membershipRole, systemRole, unitDomain } from "@/lib/labels";
import type { MembershipRole, Profile, UnitDomain } from "@/lib/types";
import { cn, dateFr, dateTimeFr, relative } from "@/lib/utils";
import { Avatar } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Card, CardHeader } from "@/components/ui/card";
import { ActionForm } from "@/components/ui/action-form";
import { Field, Input } from "@/components/ui/input";
import { Forbidden, PageHeader, Table, Td, Th, Tr } from "@/components/ui/misc";
import { LinkTabs } from "@/components/ui/tabs";
import { saveSettings } from "./actions";
import { GrantButton, InviteButton, RemoveTemplateButton, RevokeButton, TemplateButton, UserMenu } from "./admin-client";

export const metadata = { title: "Administration" };

const ACTIONS: Record<string, string> = { insert: "Création", update: "Modification", delete: "Suppression" };
const TABLES: Record<string, string> = {
  profiles: "Profil", org_units: "Unité", unit_memberships: "Affectation", role_grants: "Droit", role_templates: "Règle de droits",
  projects: "Projet", tasks: "Tâche", accounts: "Compte CRM", opportunities: "Opportunité", budgets: "Budget", invoices: "Facture",
  transactions: "Opération financière", employment_contracts: "Contrat", salaries: "Salaire", leave_requests: "Congé",
  documents: "Document", objectives: "Objectif", announcements: "Annonce", incidents: "Incident", company_settings: "Paramètres",
};

export default async function AdminPage({ searchParams }: { searchParams: Promise<{ onglet?: string; table?: string; page?: string }> }) {
  const sp = await searchParams;
  const ctx = await getContext();
  const canUsers = can(ctx, "users.admin");
  const canAudit = can(ctx, "audit.view");
  const canGrants = can(ctx, "grants.manage");
  if (!canUsers && !canAudit && !canGrants) return <Forbidden />;
  const onglet = sp.onglet ?? (canUsers ? "utilisateurs" : canGrants ? "droits" : "journal");
  const supabase = await createClient();
  const [people, units] = await Promise.all([getPeople(), getUnits()]);
  const pm = peopleMap(people);
  const opts = unitOptions(units);
  const unitName = (id: string | null) => (id ? units.find((u) => u.id === id)?.name ?? "—" : "Globale");

  return (
    <div>
      <PageHeader title="Administration" description="Comptes, droits, règles d'attribution automatique, journal d'activité et paramètres de l'entreprise." />
      <LinkTabs basePath="/admin" active={onglet} className="mb-6" tabs={[
        { key: "utilisateurs", label: "Comptes", hidden: !canUsers },
        { key: "droits", label: "Droits & dérogations", hidden: !canGrants && !canAudit },
        { key: "regles", label: "Règles automatiques", hidden: !canGrants },
        { key: "journal", label: "Journal d'activité", hidden: !canAudit },
        { key: "parametres", label: "Paramètres", hidden: !ctx.isAdmin },
      ]} />
      {onglet === "utilisateurs" && canUsers && <UsersTab />}
      {onglet === "droits" && (canGrants || canAudit) && <GrantsTab />}
      {onglet === "regles" && canGrants && <RulesTab />}
      {onglet === "journal" && canAudit && <AuditTab />}
      {onglet === "parametres" && ctx.isAdmin && <SettingsTab />}
    </div>
  );

  async function UsersTab() {
    const [{ data }, { data: ms }] = await Promise.all([
      supabase.from("profiles").select("*").order("status").order("first_name"),
      supabase.from("unit_memberships").select("profile_id, unit_id, role").is("end_date", null),
    ]);
    const all = (data as Profile[]) ?? [];
    return (
      <Card>
        <CardHeader title={`${all.filter((p) => p.status === "active").length} comptes actifs`} description={`${all.length} au total`} icon={<Users className="h-4 w-4" />}
          action={<InviteButton units={opts} people={people} isCeo={ctx.isCeo} />} />
        <div className="mt-3">
          <Table>
            <thead><tr><Th>Collaborateur</Th><Th>Rôle système</Th><Th>Affectations</Th><Th>Statut</Th><Th>Dernière activité</Th><Th /></tr></thead>
            <tbody>
              {all.map((p) => (
                <Tr key={p.id}>
                  <Td><Link href={`/annuaire/${p.id}`} className="flex items-center gap-3"><Avatar name={p.full_name} src={p.avatar_url} size="sm" /><span><span className="block font-medium hover:underline">{p.full_name || p.email}</span><span className="text-xs text-subtle">{p.email}</span></span></Link></Td>
                  <Td>{p.system_role === "employee" ? <span className="text-muted">Employé</span> : <Badge tone="violet"><ShieldCheck className="h-3 w-3" />{systemRole[p.system_role]}</Badge>}</Td>
                  <Td className="max-w-[260px]">
                    <div className="flex flex-wrap gap-1">
                      {(ms ?? []).filter((m) => m.profile_id === p.id).map((m, i) => (
                        <Badge key={i} tone={m.role === "head" ? "violet" : "neutral"}>{unitName(m.unit_id)}{m.role !== "member" && ` · ${membershipRole[m.role as MembershipRole]}`}</Badge>
                      ))}
                    </div>
                  </Td>
                  <Td><Badge tone={p.status === "active" ? "green" : p.status === "suspended" ? "amber" : "neutral"} dot>{p.status === "active" ? "Actif" : p.status === "suspended" ? "Suspendu" : "Parti"}</Badge></Td>
                  <Td className="text-xs text-subtle">{p.last_seen_at ? relative(p.last_seen_at) : "—"}</Td>
                  <Td className="text-right"><UserMenu id={p.id} email={p.email} status={p.status} self={p.id === ctx.userId} /></Td>
                </Tr>
              ))}
            </tbody>
          </Table>
        </div>
      </Card>
    );
  }

  async function GrantsTab() {
    const [{ data: grants }, { data: perms }] = await Promise.all([
      supabase.from("role_grants").select("*").order("created_at", { ascending: false }),
      supabase.from("permissions").select("*").order("category"),
    ]);
    const permLabel = new Map((perms ?? []).map((p) => [p.key, p.label]));
    const manual = (grants ?? []).filter((g) => g.source === "manual");
    const auto = (grants ?? []).filter((g) => g.source === "auto");
    const byPerson = new Map<string, typeof auto>();
    auto.forEach((g) => { if (!byPerson.has(g.profile_id)) byPerson.set(g.profile_id, []); byPerson.get(g.profile_id)!.push(g); });
    return (
      <div className="space-y-6">
        <Card>
          <CardHeader title="Dérogations manuelles" description="Droits accordés hors organigramme — temporaires et motivés." icon={<ShieldCheck className="h-4 w-4" />}
            action={canGrants ? <GrantButton people={people} units={opts} permissions={(perms ?? []).map((p) => ({ key: p.key, label: p.label, scopable: p.scopable }))} /> : undefined} />
          <div className="mt-3">
            {manual.length === 0 ? <p className="px-5 pb-5 text-sm text-muted">Aucune dérogation active.</p> : (
              <Table>
                <thead><tr><Th>Bénéficiaire</Th><Th>Permission</Th><Th>Périmètre</Th><Th>Motif</Th><Th>Expire</Th><Th>Accordée par</Th><Th /></tr></thead>
                <tbody>
                  {manual.map((g) => {
                    const expired = g.expires_at && new Date(g.expires_at) < new Date();
                    return (
                      <Tr key={g.id} className={cn(expired && "opacity-50")}>
                        <Td className="font-medium">{pm.get(g.profile_id)?.full_name ?? "—"}</Td>
                        <Td><Badge tone="amber">{permLabel.get(g.permission) ?? g.permission}</Badge></Td>
                        <Td className="text-muted">{unitName(g.scope_unit_id)}</Td>
                        <Td className="max-w-[240px] text-xs text-muted">{g.reason}</Td>
                        <Td className="text-xs text-muted">{g.expires_at ? (expired ? "Expirée" : dateFr(g.expires_at)) : "Jamais"}</Td>
                        <Td className="text-xs text-muted">{g.granted_by ? pm.get(g.granted_by)?.full_name : "—"}</Td>
                        <Td>{canGrants && <RevokeButton id={g.id} />}</Td>
                      </Tr>
                    );
                  })}
                </tbody>
              </Table>
            )}
          </div>
        </Card>
        <Card>
          <CardHeader title="Droits issus de l'organigramme" description="Calculés automatiquement à chaque nomination. Aucun réglage manuel." icon={<Workflow className="h-4 w-4" />} />
          <ul className="divide-y divide-border pt-3">
            {[...byPerson.entries()].map(([pid, list]) => (
              <li key={pid} className="flex flex-col gap-2 px-5 py-3 sm:flex-row sm:items-center">
                <span className="flex w-56 shrink-0 items-center gap-2 text-sm font-medium text-fg"><Avatar name={pm.get(pid)?.full_name} src={pm.get(pid)?.avatar_url} size="xs" />{pm.get(pid)?.full_name ?? "—"}</span>
                <div className="flex flex-wrap gap-1.5">
                  {list.map((g) => <Badge key={g.id} tone={g.scope_unit_id ? "blue" : "violet"}>{permLabel.get(g.permission) ?? g.permission}{g.scope_unit_id && ` · ${unitName(g.scope_unit_id)}`}</Badge>)}
                </div>
              </li>
            ))}
          </ul>
        </Card>
      </div>
    );
  }

  async function RulesTab() {
    const [{ data: rules }, { data: perms }] = await Promise.all([
      supabase.from("role_templates").select("*").order("domain", { nullsFirst: true }),
      supabase.from("permissions").select("*").order("category"),
    ]);
    const permLabel = new Map((perms ?? []).map((p) => [p.key, p.label]));
    return (
      <Card>
        <CardHeader title="Règles d'attribution automatique" description="« Le rôle dans l'organigramme donne les droits. » Modifier une règle recalcule immédiatement les droits de tous." icon={<Workflow className="h-4 w-4" />}
          action={ctx.isCeo ? <TemplateButton permissions={(perms ?? []).map((p) => ({ key: p.key, label: p.label, scopable: p.scopable }))} /> : undefined} />
        <div className="mt-3">
          <Table>
            <thead><tr><Th>Domaine de l&apos;unité</Th><Th>Rôle minimum</Th><Th>Permission accordée</Th><Th>Portée</Th>{ctx.isCeo && <Th />}</tr></thead>
            <tbody>
              {(rules ?? []).map((r) => (
                <Tr key={r.id}>
                  <Td className="font-medium">{r.domain ? unitDomain[r.domain as UnitDomain] : "Toutes les unités"}</Td>
                  <Td>{membershipRole[r.membership_role as MembershipRole]}</Td>
                  <Td><Badge tone="violet">{permLabel.get(r.permission) ?? r.permission}</Badge></Td>
                  <Td className="text-muted">{r.scoped ? "Unité et sous-unités" : "Globale"}</Td>
                  {ctx.isCeo && <Td className="text-right"><RemoveTemplateButton id={r.id} /></Td>}
                </Tr>
              ))}
            </tbody>
          </Table>
        </div>
      </Card>
    );
  }

  async function AuditTab() {
    const page = Math.max(1, Number(sp.page ?? 1));
    const size = 50;
    let q = supabase.from("audit_log").select("*", { count: "exact" }).order("occurred_at", { ascending: false }).range((page - 1) * size, page * size - 1);
    if (sp.table) q = q.eq("table_name", sp.table);
    const { data, count } = await q;
    const pages = Math.max(1, Math.ceil((count ?? 0) / size));
    return (
      <Card>
        <CardHeader title="Journal d'activité" description={`${count ?? 0} événement(s) — immuable`} icon={<ScrollText className="h-4 w-4" />} />
        <div className="flex flex-wrap gap-1.5 px-5 pt-4">
          <Link href="/admin?onglet=journal" className={cn("rounded-full px-2.5 py-1 text-xs", !sp.table ? "bg-primary text-white" : "bg-surface-2 text-muted hover:text-fg")}>Tout</Link>
          {Object.entries(TABLES).map(([k, l]) => (
            <Link key={k} href={`/admin?onglet=journal&table=${k}`} className={cn("rounded-full px-2.5 py-1 text-xs", sp.table === k ? "bg-primary text-white" : "bg-surface-2 text-muted hover:text-fg")}>{l}</Link>
          ))}
        </div>
        <ul className="mt-4 divide-y divide-border">
          {(data ?? []).map((e) => {
            const actor = e.actor_id ? pm.get(e.actor_id) : null;
            const label = (e.new_data?.name ?? e.new_data?.title ?? e.old_data?.name ?? e.old_data?.title ?? e.new_data?.full_name ?? e.new_data?.number ?? "") as string;
            return (
              <li key={e.id} className="px-5 py-3">
                <details>
                  <summary className="flex cursor-pointer list-none flex-wrap items-center gap-x-3 gap-y-1 text-sm">
                    <Avatar name={actor?.full_name ?? "Système"} src={actor?.avatar_url} size="xs" />
                    <span className="font-medium text-fg">{actor?.full_name ?? "Système"}</span>
                    <Badge tone={e.action === "delete" ? "red" : e.action === "insert" ? "green" : "blue"}>{ACTIONS[e.action] ?? e.action}</Badge>
                    <span className="text-muted">{TABLES[e.table_name] ?? e.table_name}</span>
                    {label && <span className="max-w-[260px] truncate text-fg">« {label} »</span>}
                    {e.changed_fields && <span className="font-mono text-[11px] text-subtle">{e.changed_fields.join(", ")}</span>}
                    <span className="ml-auto text-xs text-subtle">{dateTimeFr(e.occurred_at)}</span>
                  </summary>
                  <div className="mt-3 grid gap-3 md:grid-cols-2">
                    {e.old_data && <pre className="scrollbar-thin max-h-64 overflow-auto rounded-lg bg-surface-2 p-3 font-mono text-[11px] text-muted">{JSON.stringify(e.old_data, null, 2)}</pre>}
                    {e.new_data && <pre className="scrollbar-thin max-h-64 overflow-auto rounded-lg bg-surface-2 p-3 font-mono text-[11px] text-muted">{JSON.stringify(e.new_data, null, 2)}</pre>}
                    {!e.old_data && !e.new_data && <p className="text-xs text-subtle">Contenu masqué (donnée sensible).</p>}
                  </div>
                </details>
              </li>
            );
          })}
        </ul>
        <div className="flex items-center justify-between border-t border-border px-5 py-3 text-sm">
          <span className="text-muted">Page {page} / {pages}</span>
          <div className="flex gap-2">
            {page > 1 && <Link className="text-primary hover:underline" href={`/admin?onglet=journal${sp.table ? `&table=${sp.table}` : ""}&page=${page - 1}`}>Précédent</Link>}
            {page < pages && <Link className="text-primary hover:underline" href={`/admin?onglet=journal${sp.table ? `&table=${sp.table}` : ""}&page=${page + 1}`}>Suivant</Link>}
          </div>
        </div>
      </Card>
    );
  }

  async function SettingsTab() {
    const { data: s } = await supabase.from("company_settings").select("*").single();
    return (
      <Card className="max-w-2xl">
        <CardHeader title="Paramètres de l'entreprise" icon={<Settings2 className="h-4 w-4" />} />
        <div className="p-5">
          <ActionForm action={saveSettings} resetOnSuccess={false}>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Raison sociale" htmlFor="company_name"><Input id="company_name" name="company_name" defaultValue={s?.company_name} /></Field>
              <Field label="Domaine e-mail" htmlFor="email_domain"><Input id="email_domain" name="email_domain" defaultValue={s?.email_domain} /></Field>
              <Field label="Devise" htmlFor="currency"><Input id="currency" name="currency" defaultValue={s?.currency} /></Field>
              <Field label="Fuseau horaire" htmlFor="timezone"><Input id="timezone" name="timezone" defaultValue={s?.timezone} /></Field>
              <Field label="Trésorerie d'ouverture (FCFA)" htmlFor="opening_cash" hint="Point de départ du calcul de trésorerie."><Input id="opening_cash" name="opening_cash" defaultValue={s?.opening_cash} inputMode="numeric" /></Field>
              <Field label="TVA par défaut (%)" htmlFor="default_tax_rate"><Input id="default_tax_rate" name="default_tax_rate" defaultValue={s?.default_tax_rate} /></Field>
            </div>
          </ActionForm>
        </div>
      </Card>
    );
  }
}
