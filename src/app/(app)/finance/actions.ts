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
    approval_id: type === "expense" ? str(fd, "approval_id") : null,
  });
  if (error) return fail(error);
  refresh();
  revalidatePath("/validations");
  return ok(type === "revenue" ? "Revenu enregistré." : "Dépense enregistrée.");
}

/** Annule une opération par une écriture inverse : rien ne s'efface. */
export async function reverseTransaction(id: string, reason: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("reverse_transaction", { p_id: id, p_reason: reason });
  if (error) return fail(error);
  refresh();
  return ok("Opération contre-passée : l'écriture inverse est enregistrée.");
}

/** Enregistre (ou modifie) un budget : toujours en brouillon, l'activation est un acte distinct. */
export async function setBudget(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const unit = str(fd, "unit_id");
  const project = str(fd, "project_id");
  const year = numVal(fd, "fiscal_year");
  const amount = numVal(fd, "amount");
  if ((!unit && !project) || !year || amount === null) return fail("Unité ou projet, exercice et montant requis.");
  const supabase = await createClient();
  let query = supabase.from("budgets").select("id").eq("fiscal_year", year);
  query = project ? query.eq("project_id", project) : query.eq("unit_id", unit!);
  const { data: existing } = await query.maybeSingle();
  const row = { amount, notes: str(fd, "notes"), status: "draft" as const };
  const { error } = existing
    ? await supabase.from("budgets").update(row).eq("id", existing.id)
    : await supabase.from("budgets").insert({ ...row, fiscal_year: year, unit_id: project ? null : unit, project_id: project });
  if (error) return fail(error);
  refresh();
  return ok("Budget enregistré en brouillon : activez-le pour qu'il s'applique.");
}

export async function activateBudget(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("activate_budget", { p_budget: id, p_justification: null });
  if (error) return fail(error);
  refresh();
  revalidatePath("/validations");
  return ok(data === "active" ? "Budget activé." : "Budget au-delà du seuil : demande d'accord transmise au CEO.");
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
  if (desc && price) {
    const { error: lineError } = await supabase.from("invoice_lines").insert({ invoice_id: data.id, description: desc, quantity: 1, unit_price: price });
    if (lineError) return fail(`Facture créée, mais la première ligne n'a pas pu être ajoutée : ${lineError.message}`);
  }
  refresh();
  return ok("Facture créée.", data);
}

type InvoicePatch = Partial<{ status: InvoiceStatus; due_date: string; notes: string | null; account_id: string; tax_rate: number }>;
const INVOICE_PATCH_KEYS = new Set(["status", "due_date", "notes", "account_id", "tax_rate"]);

export async function updateInvoice(id: string, patch: InvoicePatch): Promise<ActionResult> {
  const clean = Object.fromEntries(Object.entries(patch).filter(([k]) => INVOICE_PATCH_KEYS.has(k)));
  const supabase = await createClient();
  const { error } = await supabase.from("invoices").update(clean).eq("id", id);
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
