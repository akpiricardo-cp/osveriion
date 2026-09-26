import Link from "next/link";
import { Building } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { can, getContext } from "@/lib/auth";
import { getPeople, peopleMap } from "@/lib/data";
import { accountType, COUNTRIES } from "@/lib/labels";
import type { Account } from "@/lib/types";
import { relative } from "@/lib/utils";
import { Avatar } from "@/components/ui/avatar";
import { LabelBadge } from "@/components/ui/badge";
import { EmptyState, Forbidden, PageHeader, Table, Td, Th, Tr } from "@/components/ui/misc";
import { LinkTabs } from "@/components/ui/tabs";
import { AccountFormButton } from "../crm-forms";

export const metadata = { title: "Comptes" };

export default async function AccountsPage({ searchParams }: { searchParams: Promise<{ onglet?: string }> }) {
  const { onglet = "tous" } = await searchParams;
  const ctx = await getContext();
  if (!(can(ctx, "crm.view") || can(ctx, "crm.edit") || can(ctx, "dashboard.exec"))) return <Forbidden />;
  const supabase = await createClient();
  const [{ data }, { data: opps }, people] = await Promise.all([
    supabase.from("accounts").select("*").order("name"),
    supabase.from("opportunities").select("account_id, amount, stage"),
    getPeople(),
  ]);
  const accounts = (data as Account[]) ?? [];
  const list = onglet === "tous" ? accounts : accounts.filter((a) => a.type === onglet);
  const pm = peopleMap(people);
  const count = (t: string) => accounts.filter((a) => a.type === t).length;

  return (
    <div>
      <PageHeader crumbs={[{ label: "CRM", href: "/crm" }, { label: "Comptes" }]} title="Comptes & partenaires" description="Prospects, clients et partenaires de VERIION."
        actions={can(ctx, "crm.edit") ? <AccountFormButton people={people} /> : undefined} />
      <LinkTabs basePath="/crm/comptes" active={onglet} className="mb-6" tabs={[
        { key: "tous", label: "Tous", count: accounts.length },
        { key: "prospect", label: "Prospects", count: count("prospect") },
        { key: "client", label: "Clients", count: count("client") },
        { key: "partner", label: "Partenaires", count: count("partner") },
      ]} />
      {list.length === 0 ? (
        <EmptyState icon={Building} title="Aucun compte" description="Ajoutez vos prospects, clients et partenaires." />
      ) : (
        <div className="overflow-hidden rounded-2xl border border-border bg-surface shadow-card">
          <Table>
            <thead><tr><Th>Compte</Th><Th>Type</Th><Th>Pays</Th><Th>Opportunités ouvertes</Th><Th>Responsable</Th><Th>Créé</Th></tr></thead>
            <tbody>
              {list.map((a) => {
                const ao = (opps ?? []).filter((o) => o.account_id === a.id && !["won", "lost"].includes(o.stage));
                const owner = a.owner_id ? pm.get(a.owner_id) : null;
                return (
                  <Tr key={a.id}>
                    <Td>
                      <Link href={`/crm/comptes/${a.id}`} className="flex items-center gap-3">
                        <span className="grid h-9 w-9 place-items-center rounded-lg bg-surface-2 text-sm font-semibold text-muted">{a.name[0]}</span>
                        <span><span className="block font-medium text-fg hover:underline">{a.name}</span><span className="text-xs text-subtle">{a.industry ?? "—"}</span></span>
                      </Link>
                    </Td>
                    <Td><LabelBadge map={accountType} value={a.type} /></Td>
                    <Td className="text-muted">{a.country ? COUNTRIES[a.country] ?? a.country : "—"}{a.city && `, ${a.city}`}</Td>
                    <Td className="tabular-nums">{ao.length ? `${ao.length} · ${new Intl.NumberFormat("fr-FR", { notation: "compact" }).format(ao.reduce((s, o) => s + Number(o.amount), 0))} FCFA` : "—"}</Td>
                    <Td>{owner ? <span className="flex items-center gap-2"><Avatar name={owner.full_name} src={owner.avatar_url} size="xs" /><span className="text-sm">{owner.full_name}</span></span> : "—"}</Td>
                    <Td className="text-xs text-subtle">{relative(a.created_at)}</Td>
                  </Tr>
                );
              })}
            </tbody>
          </Table>
        </div>
      )}
    </div>
  );
}
