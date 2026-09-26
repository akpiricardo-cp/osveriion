import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { can, getContext } from "@/lib/auth";
import { COUNTRIES, invoiceStatus } from "@/lib/labels";
import type { Invoice } from "@/lib/types";
import { dateFr, money } from "@/lib/utils";
import { LabelBadge } from "@/components/ui/badge";
import { Forbidden, PageHeader } from "@/components/ui/misc";
import { LogoMark } from "@/components/logo";
import { InvoiceActions, InvoiceLines } from "./invoice-client";

export default async function InvoicePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const ctx = await getContext();
  if (!(can(ctx, "finance.view") || can(ctx, "finance.admin") || can(ctx, "dashboard.exec"))) return <Forbidden />;
  const supabase = await createClient();
  const { data } = await supabase.from("invoices").select("*, accounts(*)").eq("id", id).maybeSingle();
  if (!data) notFound();
  const inv = data as Invoice & { accounts: { name: string; city: string | null; country: string | null; email: string | null; phone: string | null } | null };
  const [{ data: lines }, { data: settings }] = await Promise.all([
    supabase.from("invoice_lines").select("*").eq("invoice_id", id).order("position").order("id"),
    supabase.from("company_settings").select("*").single(),
  ]);
  const admin = can(ctx, "finance.admin");
  const editable = admin && inv.status === "draft";

  return (
    <div>
      <div className="print:hidden">
        <PageHeader
          crumbs={[{ label: "Finance", href: "/finance?onglet=factures" }, { label: inv.number }]}
          title={<span className="flex items-center gap-3">Facture {inv.number} <LabelBadge map={invoiceStatus} value={inv.status} /></span>}
          actions={<InvoiceActions id={inv.id} status={inv.status} admin={admin} />}
        />
      </div>
      <div className="mx-auto max-w-4xl rounded-2xl border border-border bg-surface p-8 shadow-card print:max-w-none print:border-0 print:p-0 print:shadow-none sm:p-12">
        <div className="flex flex-col justify-between gap-8 sm:flex-row">
          <div>
            <div className="flex items-center gap-3"><LogoMark className="h-10 w-10" /><span className="text-xl font-semibold tracking-[0.14em] text-fg">{settings?.company_name ?? "VERIION"}</span></div>
            <p className="mt-3 text-sm text-muted">L&apos;écosystème numérique de l&apos;Afrique<br />Cotonou, Bénin · finance@{settings?.email_domain ?? "veriion.com"}</p>
          </div>
          <div className="text-left sm:text-right">
            <p className="text-3xl font-semibold tracking-tight text-fg">FACTURE</p>
            <p className="mt-1 font-mono text-sm text-muted">{inv.number}</p>
            <div className="mt-4 space-y-1 text-sm">
              <p><span className="text-subtle">Émise le </span><span className="font-medium text-fg">{dateFr(inv.issue_date, "d MMMM yyyy")}</span></p>
              <p><span className="text-subtle">Échéance </span><span className="font-medium text-fg">{dateFr(inv.due_date, "d MMMM yyyy")}</span></p>
            </div>
          </div>
        </div>
        <div className="mt-10 rounded-xl bg-surface-2/60 p-5">
          <p className="text-xs font-medium uppercase tracking-wider text-subtle">Facturé à</p>
          <p className="mt-1 text-base font-semibold text-fg">{inv.accounts?.name ?? "—"}</p>
          <p className="text-sm text-muted">{[inv.accounts?.city, inv.accounts?.country ? COUNTRIES[inv.accounts.country] : null].filter(Boolean).join(", ")}</p>
          {inv.accounts?.email && <p className="text-sm text-muted">{inv.accounts.email}</p>}
        </div>

        <InvoiceLines invoiceId={inv.id} lines={lines ?? []} editable={editable} currency={inv.currency} />

        <div className="mt-6 flex justify-end">
          <dl className="w-full max-w-xs space-y-2 text-sm">
            <div className="flex justify-between"><dt className="text-muted">Sous-total HT</dt><dd className="tabular-nums text-fg">{money(inv.subtotal, inv.currency)}</dd></div>
            <div className="flex justify-between"><dt className="text-muted">TVA ({Number(inv.tax_rate)} %)</dt><dd className="tabular-nums text-fg">{money(inv.tax_amount, inv.currency)}</dd></div>
            <div className="flex justify-between border-t border-border pt-3 text-base font-semibold"><dt className="text-fg">Total TTC</dt><dd className="tabular-nums text-fg">{money(inv.total, inv.currency)}</dd></div>
            {inv.paid_at && <p className="pt-2 text-right text-xs font-medium text-emerald-600">Payée le {dateFr(inv.paid_at)}</p>}
          </dl>
        </div>
        {inv.notes && <p className="mt-10 whitespace-pre-line border-t border-border pt-6 text-sm text-muted">{inv.notes}</p>}
      </div>
    </div>
  );
}
