import Link from "next/link";
import { ArrowDownRight, ArrowUpRight, Landmark, Receipt, Wallet } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { can, canAnywhere, getContext } from "@/lib/auth";
import { getUnits, unitOptions } from "@/lib/data";
import { COUNTRIES, invoiceStatus } from "@/lib/labels";
import type { Invoice, Transaction } from "@/lib/types";
import { cn, dateFr, money } from "@/lib/utils";
import { Card, CardHeader } from "@/components/ui/card";
import { Badge, LabelBadge } from "@/components/ui/badge";
import { EmptyState, Forbidden, PageHeader, Progress, StatCard, Table, Td, Th, Tr } from "@/components/ui/misc";
import { LinkTabs } from "@/components/ui/tabs";
import { HBarChart, RevenueExpenseChart } from "@/components/charts";
import { ActivateBudget, BudgetButton, InvoiceButton, ReverseTransaction, TransactionButton, type ExpenseApproval } from "./finance-forms";

export const metadata = { title: "Finance" };

export default async function FinancePage({ searchParams }: { searchParams: Promise<{ onglet?: string; annee?: string; type?: string }> }) {
  const sp = await searchParams;
  const ctx = await getContext();
  const fullRead = can(ctx, "finance.view") || can(ctx, "finance.admin") || can(ctx, "dashboard.exec");
  const managerOnly = !fullRead && canAnywhere(ctx, "unit.manage");
  if (!fullRead && !managerOnly) return <Forbidden message="La finance est réservée au département Finance et à la direction." />;
  const admin = can(ctx, "finance.admin");
  const onglet = sp.onglet ?? (managerOnly ? "budgets" : "apercu");
  const year = Number(sp.annee ?? new Date().getFullYear());
  const supabase = await createClient();
  const units = await getUnits();
  const opts = unitOptions(units);
  const { data: accounts } = fullRead ? await supabase.from("accounts").select("id, name").order("name") : { data: [] };
  const [{ data: approvals }, { data: gov }] = await Promise.all([
    admin ? supabase.rpc("available_expense_approvals") : Promise.resolve({ data: [] }),
    supabase.from("governance_settings").select("ceo_approval_threshold").maybeSingle(),
  ]);
  const threshold = Number(gov?.ceo_approval_threshold ?? 500000);
  const from = `${year}-01-01`, to = `${year}-12-31`;

  const { data: txData } = await supabase.from("transactions").select("*").gte("occurred_on", from).lte("occurred_on", to).order("occurred_on", { ascending: false });
  const tx = (txData as Transaction[]) ?? [];
  const revenue = tx.filter((t) => t.type === "revenue").reduce((s, t) => s + Number(t.amount), 0);
  const expense = tx.filter((t) => t.type === "expense").reduce((s, t) => s + Number(t.amount), 0);
  const unitName = (id: string | null) => units.find((u) => u.id === id)?.name ?? "—";

  return (
    <div>
      <PageHeader
        title="Finance"
        description={managerOnly ? "Budget et dépenses de vos unités." : "Revenus, dépenses, trésorerie, factures et budgets de VERIION."}
        actions={
          <>
            <div className="flex rounded-lg border border-border bg-surface p-0.5 text-[13px]">
              {[year - 1, year, year + 1].map((y) => (
                <Link key={y} href={`/finance?onglet=${onglet}&annee=${y}`} className={cn("rounded-md px-2.5 py-1 font-medium", y === year ? "bg-surface-2 text-fg" : "text-muted hover:text-fg")}>{y}</Link>
              ))}
            </div>
            {admin && <InvoiceButton units={opts} accounts={accounts ?? []} />}
            {admin && <TransactionButton units={opts} accounts={accounts ?? []} approvals={(approvals ?? []) as ExpenseApproval[]} threshold={threshold} />}
          </>
        }
      />
      <LinkTabs basePath={`/finance`} active={onglet} className="mb-6" tabs={[
        { key: "apercu", label: "Vue d'ensemble", hidden: managerOnly },
        { key: "operations", label: "Opérations", count: tx.length },
        { key: "factures", label: "Factures", hidden: managerOnly },
        { key: "budgets", label: "Budgets" },
      ]} />

      {onglet === "apercu" && fullRead && <Overview year={year} tx={tx} revenue={revenue} expense={expense} />}
      {onglet === "operations" && (
        tx.length === 0 ? <EmptyState icon={Wallet} title="Aucune opération" description={`Aucune opération enregistrée pour ${year}.`} /> : (
          <div className="overflow-hidden rounded-2xl border border-border bg-surface shadow-card">
            <Table>
              <thead><tr><Th>Date</Th><Th>Libellé</Th><Th>Catégorie</Th><Th>Unité</Th><Th>Produit / pays</Th><Th className="text-right">Montant</Th>{admin && <Th />}</tr></thead>
              <tbody>
                {tx.slice(0, 300).map((t) => (
                  <Tr key={t.id}>
                    <Td className="whitespace-nowrap text-muted">{dateFr(t.occurred_on, "d MMM yyyy")}</Td>
                    <Td className="max-w-[280px]">
                      <span className={cn("block truncate font-medium", t.reversed_by && "text-muted line-through")}>{t.description ?? t.category}</span>
                      {t.reference && <span className="block truncate font-mono text-[11px] text-subtle">{t.reference}</span>}
                      {t.reverses_id && <span className="block truncate text-[11px] text-subtle">Contre-passation{t.reversal_reason ? ` — ${t.reversal_reason}` : ""}</span>}
                    </Td>
                    <Td className="text-muted">{t.category}</Td>
                    <Td className="text-muted">{unitName(t.unit_id)}</Td>
                    <Td className="text-muted">{[t.product, t.country ? COUNTRIES[t.country] ?? t.country : null].filter(Boolean).join(" · ") || "—"}</Td>
                    <Td className={cn("whitespace-nowrap text-right font-semibold tabular-nums", t.type === "revenue" ? "text-emerald-600 dark:text-emerald-400" : "text-fg")}>
                      {(t.type === "revenue") === (Number(t.amount) >= 0) ? "+" : "−"} {money(Math.abs(Number(t.amount)), t.currency)}
                    </Td>
                    {admin && <Td>{!t.invoice_id && !t.reverses_id && !t.reversed_by && <ReverseTransaction id={t.id} />}</Td>}
                  </Tr>
                ))}
              </tbody>
            </Table>
          </div>
        )
      )}
      {onglet === "factures" && fullRead && <Invoices />}
      {onglet === "budgets" && <Budgets year={year} tx={tx} admin={admin} opts={opts} units={units} />}
    </div>
  );

  async function Invoices() {
    const { data } = await supabase.from("invoices").select("*, accounts(name)").order("issue_date", { ascending: false }).limit(200);
    const list = (data as (Invoice & { accounts: { name: string } | null })[]) ?? [];
    if (!list.length) return <EmptyState icon={Receipt} title="Aucune facture" description="Les factures créées ou générées par les opportunités gagnées apparaîtront ici." />;
    return (
      <div className="overflow-hidden rounded-2xl border border-border bg-surface shadow-card">
        <Table>
          <thead><tr><Th>Numéro</Th><Th>Client</Th><Th>Émise le</Th><Th>Échéance</Th><Th>Statut</Th><Th className="text-right">Total TTC</Th></tr></thead>
          <tbody>
            {list.map((i) => (
              <Tr key={i.id}>
                <Td><Link href={`/finance/factures/${i.id}`} className="font-mono text-[13px] font-medium text-primary hover:underline">{i.number}</Link></Td>
                <Td className="font-medium">{i.accounts?.name ?? "—"}</Td>
                <Td className="text-muted">{dateFr(i.issue_date)}</Td>
                <Td className={cn("text-muted", i.status === "overdue" && "font-medium text-danger")}>{dateFr(i.due_date)}</Td>
                <Td><LabelBadge map={invoiceStatus} value={i.status} /></Td>
                <Td className="text-right font-semibold tabular-nums">{money(i.total, i.currency)}</Td>
              </Tr>
            ))}
          </tbody>
        </Table>
      </div>
    );
  }
}

async function Overview({ year, tx, revenue, expense }: { year: number; tx: Transaction[]; revenue: number; expense: number }) {
  const supabase = await createClient();
  const [{ data: settings }, { data: allTx }, { data: receivables }] = await Promise.all([
    supabase.from("company_settings").select("opening_cash").single(),
    supabase.from("transactions").select("type, amount"),
    supabase.from("invoices").select("total, status").in("status", ["sent", "overdue"]),
  ]);
  const cash = Number(settings?.opening_cash ?? 0) + (allTx ?? []).reduce((s, t) => s + (t.type === "revenue" ? 1 : -1) * Number(t.amount), 0);
  const monthly = Array.from({ length: 12 }, (_, i) => ({
    month: i + 1,
    revenue: tx.filter((t) => t.type === "revenue" && Number(t.occurred_on.slice(5, 7)) === i + 1).reduce((s, t) => s + Number(t.amount), 0),
    expense: tx.filter((t) => t.type === "expense" && Number(t.occurred_on.slice(5, 7)) === i + 1).reduce((s, t) => s + Number(t.amount), 0),
  }));
  const group = (key: "product" | "country" | "category", type: "revenue" | "expense") => {
    const m = new Map<string, number>();
    tx.filter((t) => t.type === type).forEach((t) => {
      const k = (key === "country" ? (t.country ? COUNTRIES[t.country] ?? t.country : null) : t[key]) ?? "Non affecté";
      m.set(k, (m.get(k) ?? 0) + Number(t.amount));
    });
    return [...m.entries()].map(([label, value]) => ({ label, value })).sort((a, b) => b.value - a.value).slice(0, 8);
  };
  const recv = (receivables ?? []).reduce((s, i) => s + Number(i.total), 0);
  const overdue = (receivables ?? []).filter((i) => i.status === "overdue").reduce((s, i) => s + Number(i.total), 0);
  const margin = revenue ? ((revenue - expense) / revenue) * 100 : 0;

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        <StatCard label={`Revenus ${year}`} value={money(revenue, "XOF", true)} icon={ArrowUpRight} tone="green" />
        <StatCard label={`Dépenses ${year}`} value={money(expense, "XOF", true)} icon={ArrowDownRight} tone="amber" hint={`Marge ${margin.toFixed(0)} %`} />
        <StatCard label="Trésorerie estimée" value={money(cash, "XOF", true)} icon={Landmark} tone={cash >= 0 ? "primary" : "red"} hint="toutes périodes" />
        <StatCard label="À encaisser" value={money(recv, "XOF", true)} icon={Receipt} tone={overdue ? "red" : "cyan"} hint={overdue ? `dont ${money(overdue, "XOF", true)} en retard` : "factures envoyées"} />
      </div>
      <Card>
        <CardHeader title="Revenus et dépenses par mois" description={`Exercice ${year}`} />
        <div className="p-5 pt-3"><RevenueExpenseChart data={monthly} /></div>
      </Card>
      <div className="grid gap-6 lg:grid-cols-3">
        <Card><CardHeader title="Revenus par produit" /><div className="p-5">{group("product", "revenue").length ? <HBarChart data={group("product", "revenue")} /> : <p className="text-sm text-muted">Aucune donnée.</p>}</div></Card>
        <Card><CardHeader title="Revenus par pays" /><div className="p-5">{group("country", "revenue").length ? <HBarChart data={group("country", "revenue")} /> : <p className="text-sm text-muted">Aucune donnée.</p>}</div></Card>
        <Card><CardHeader title="Dépenses par catégorie" /><div className="p-5">{group("category", "expense").length ? <HBarChart data={group("category", "expense")} /> : <p className="text-sm text-muted">Aucune donnée.</p>}</div></Card>
      </div>
    </div>
  );
}

async function Budgets({ year, tx, admin, opts, units }: { year: number; tx: Transaction[]; admin: boolean; opts: { id: string; label: string }[]; units: { id: string; name: string; color: string; path: string[]; depth: number }[] }) {
  const supabase = await createClient();
  const [{ data }, { data: projects }] = await Promise.all([
    supabase.from("budgets").select("*").eq("fiscal_year", year),
    supabase.from("projects").select("id, name, color").is("archived_at", null).order("name"),
  ]);
  const budgets = (data ?? []) as { id: string; unit_id: string | null; project_id: string | null; amount: number; status: "draft" | "active"; notes: string | null }[];
  const projectOpts = (projects ?? []).map((p) => ({ id: p.id, label: p.name }));
  const actions = admin ? <BudgetButton units={opts} projects={projectOpts} year={year} /> : undefined;
  if (!budgets.length) return <EmptyState icon={Wallet} title="Aucun budget défini" description={`Définissez les budgets ${year} des unités et des projets. Un budget reste en brouillon jusqu'à son activation ; au-delà du seuil, l'activation demande l'accord du CEO.`} action={actions} />;
  const spentFor = (b: (typeof budgets)[number]) => tx.filter((t) => t.type === "expense" && (
    b.project_id ? t.project_id === b.project_id : t.unit_id && units.find((u) => u.id === t.unit_id)?.path.includes(b.unit_id!)
  )).reduce((s, t) => s + Number(t.amount), 0);
  const active = budgets.filter((b) => b.status === "active");
  const totalBudget = active.reduce((s, b) => s + Number(b.amount), 0);
  const elapsed = year === new Date().getFullYear() ? (new Date().getMonth() + 1) / 12 : year < new Date().getFullYear() ? 1 : 0;
  const { data: pendingApprovals } = await supabase.from("approval_requests").select("subject_id").eq("kind", "budget").eq("status", "pending");
  const pendingIds = new Set((pendingApprovals ?? []).map((a) => a.subject_id));
  return (
    <Card>
      <CardHeader title={`Budgets ${year}`} description={`${money(totalBudget)} actifs · ${budgets.length - active.length} en brouillon · ${Math.round(elapsed * 100)} % de l'exercice écoulé`} action={actions} />
      <ul className="divide-y divide-border pt-3">
        {budgets.map((b) => {
          const u = units.find((x) => x.id === b.unit_id);
          const p = (projects ?? []).find((x) => x.id === b.project_id);
          const spent = spentFor(b);
          const ratio = Number(b.amount) ? spent / Number(b.amount) : 0;
          const tone = ratio > 1 ? "bg-rose-500" : ratio > elapsed + 0.1 ? "bg-amber-500" : "bg-emerald-500";
          return (
            <li key={b.id} className="grid items-center gap-3 px-5 py-4 sm:grid-cols-[240px_1fr_400px]">
              <span className="flex min-w-0 items-center gap-2.5 font-medium text-fg">
                <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ background: u?.color ?? p?.color }} />
                <span className="truncate">{u?.name ?? (p ? `Projet — ${p.name}` : "Budget")}</span>
                {b.status === "draft" && <Badge tone={pendingIds.has(b.id) ? "amber" : "neutral"}>{pendingIds.has(b.id) ? "Chez le CEO" : "Brouillon"}</Badge>}
              </span>
              <div className="relative">
                <Progress value={ratio * 100} tone={tone} className="h-2" />
                {elapsed > 0 && elapsed < 1 && <span className="absolute -top-1 h-4 w-0.5 rounded bg-fg/40" style={{ left: `${elapsed * 100}%` }} title="Temps écoulé" />}
              </div>
              <span className="flex items-center justify-end gap-3 text-sm tabular-nums">
                <span className="whitespace-nowrap text-fg">{money(spent, "XOF", true)} <span className="text-subtle">/ {money(b.amount, "XOF", true)}</span></span>
                <span className={cn("w-12 text-right font-medium", ratio > 1 ? "text-danger" : "text-muted")}>{Math.round(ratio * 100)} %</span>
                {admin && b.status === "draft" && !pendingIds.has(b.id) && <ActivateBudget id={b.id} />}
                {admin && !pendingIds.has(b.id) && <BudgetButton units={opts} projects={projectOpts} year={year} unitId={b.unit_id ?? undefined} projectId={b.project_id ?? undefined} amount={Number(b.amount)} />}
              </span>
            </li>
          );
        })}
      </ul>
    </Card>
  );
}
