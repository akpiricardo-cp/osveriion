"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { fail, numVal, ok, str } from "@/lib/actions";
import type { ActionResult, InvoiceStatus } from "@/lib/types";

function refresh(invoiceId?: string) {
  revalidatePath("/finance");
  revalidatePath("/direction");
  if (invoiceId) revalidatePath(`/finance/factures/${invoiceId}`);
}

export async function addTransaction(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const type = str(fd, "type");
  const amount = numVal(fd, "amount");
  if ((type !== "revenue" && type !== "expense") || !amount || amount <= 0) return fail("Type et montant positif requis.");
  const supabase = await createClient();
  const { error } = await supabase.from("transactions").insert({
    type, amount,
    occurred_on: str(fd, "occurred_on") ?? new Date().toISOString().slice(0, 10),
    category: str(fd, "category") ?? "Autre",
    description: str(fd, "description"),
    unit_id: str(fd, "unit_id"), project_id: str(fd, "project_id"), account_id: str(fd, "account_id"),
    product: str(fd, "product"), country: str(fd, "country"), reference: str(fd, "reference"),
  });
  if (error) return fail(error);
  refresh();
  return ok(type === "revenue" ? "Revenu enregistré." : "Dépense enregistrée.");
}

export async function deleteTransaction(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("transactions").delete().eq("id", id);
  if (error) return fail(error);
  refresh();
  return ok("Opération supprimée.");
}

export async function setBudget(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const unit = str(fd, "unit_id");
  const year = numVal(fd, "fiscal_year");
  const amount = numVal(fd, "amount");
  if (!unit || !year || amount === null) return fail("Unité, exercice et montant requis.");
  const supabase = await createClient();
  const { error } = await supabase.from("budgets").upsert({ unit_id: unit, fiscal_year: year, amount, notes: str(fd, "notes") }, { onConflict: "unit_id,fiscal_year" });
  if (error) return fail(error);
  refresh();
  return ok("Budget enregistré.");
}

export async function createInvoice(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const supabase = await createClient();
  const { data: settings } = await supabase.from("company_settings").select("default_tax_rate").single();
  const { data, error } = await supabase.from("invoices").insert({
    account_id: str(fd, "account_id"),
    unit_id: str(fd, "unit_id"),
    issue_date: str(fd, "issue_date") ?? undefined,
    due_date: str(fd, "due_date") ?? undefined,
    product: str(fd, "product"),
    country: str(fd, "country"),
    tax_rate: numVal(fd, "tax_rate") ?? settings?.default_tax_rate ?? 18,
    notes: str(fd, "notes"),
  }).select("id").single();
  if (error) return fail(error);
  const desc = str(fd, "line_description");
  const price = numVal(fd, "line_amount");
  if (desc && price) await supabase.from("invoice_lines").insert({ invoice_id: data.id, description: desc, quantity: 1, unit_price: price });
  refresh();
  return ok("Facture créée.", data);
}

export async function updateInvoice(id: string, patch: Record<string, unknown>): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("invoices").update(patch).eq("id", id);
  if (error) return fail(error);
  refresh(id);
  return ok();
}

export async function setInvoiceStatus(id: string, status: InvoiceStatus): Promise<ActionResult> {
  const r = await updateInvoice(id, { status });
  if (!r.ok) return r;
  const msg: Record<InvoiceStatus, string> = {
    draft: "Facture repassée en brouillon.", sent: "Facture marquée comme envoyée.",
    paid: "Paiement enregistré : le revenu a été comptabilisé.", overdue: "Facture marquée en retard.", cancelled: "Facture annulée.",
  };
  return ok(msg[status]);
}

export async function addInvoiceLine(invoiceId: string, description: string, quantity: number, unitPrice: number): Promise<ActionResult> {
  if (!description.trim() || quantity <= 0 || unitPrice < 0) return fail("Ligne invalide.");
  const supabase = await createClient();
  const { error } = await supabase.from("invoice_lines").insert({ invoice_id: invoiceId, description: description.trim(), quantity, unit_price: unitPrice });
  if (error) return fail(error);
  refresh(invoiceId);
  return ok();
}

export async function deleteInvoiceLine(lineId: string, invoiceId: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("invoice_lines").delete().eq("id", lineId);
  if (error) return fail(error);
  refresh(invoiceId);
  return ok();
}
