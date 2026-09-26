"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Plus, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { ActionForm } from "@/components/ui/action-form";
import { Field, Input, Select, Textarea } from "@/components/ui/input";
import { UnitSelect } from "@/components/pickers";
import { COUNTRIES, EXPENSE_CATEGORIES, PRODUCTS, REVENUE_CATEGORIES } from "@/lib/labels";
import { todayISO } from "@/lib/utils";
import { addTransaction, createInvoice, deleteTransaction, setBudget } from "./actions";

export function TransactionButton({ units, accounts }: { units: { id: string; label: string }[]; accounts: { id: string; name: string }[] }) {
  const [open, setOpen] = useState(false);
  const [type, setType] = useState<"expense" | "revenue">("expense");
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><Button size="sm"><Plus className="h-4 w-4" /> Nouvelle opération</Button></DialogTrigger>
      <DialogContent title="Enregistrer une opération" size="lg">
        <ActionForm action={addTransaction} onSuccess={() => setOpen(false)}>
          <input type="hidden" name="type" value={type} />
          <div className="grid grid-cols-2 gap-2 rounded-xl bg-surface-2 p-1">
            {([["expense", "Dépense"], ["revenue", "Revenu"]] as const).map(([k, l]) => (
              <button key={k} type="button" onClick={() => setType(k)} className={`rounded-lg py-2 text-sm font-medium transition ${type === k ? "bg-surface text-fg shadow-sm" : "text-muted"}`}>{l}</button>
            ))}
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <Field label="Montant (FCFA)" htmlFor="amount" required><Input id="amount" name="amount" inputMode="decimal" required /></Field>
            <Field label="Date" htmlFor="occurred_on"><Input id="occurred_on" name="occurred_on" type="date" defaultValue={todayISO()} /></Field>
            <Field label="Catégorie" htmlFor="category">
              <Select id="category" name="category" key={type}>
                {(type === "expense" ? EXPENSE_CATEGORIES : REVENUE_CATEGORIES).map((c) => <option key={c}>{c}</option>)}
              </Select>
            </Field>
          </div>
          <Field label="Libellé" htmlFor="description"><Input id="description" name="description" /></Field>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Unité imputée" htmlFor="unit_id"><UnitSelect units={units} name="unit_id" /></Field>
            <Field label="Compte (client / fournisseur)" htmlFor="account_id">
              <Select id="account_id" name="account_id" defaultValue=""><option value="">—</option>{accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</Select>
            </Field>
            <Field label="Produit" htmlFor="product">
              <Select id="product" name="product" defaultValue=""><option value="">—</option>{PRODUCTS.map((p) => <option key={p}>{p}</option>)}</Select>
            </Field>
            <Field label="Pays" htmlFor="country">
              <Select id="country" name="country" defaultValue="BJ">{Object.entries(COUNTRIES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</Select>
            </Field>
          </div>
          <Field label="Référence / pièce" htmlFor="reference"><Input id="reference" name="reference" placeholder="N° de reçu, virement…" /></Field>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function DeleteTransaction({ id }: { id: string }) {
  const [pending, start] = useTransition();
  return (
    <button disabled={pending} aria-label="Supprimer" className="rounded p-1 text-subtle hover:text-danger disabled:opacity-40"
      onClick={() => confirm("Supprimer cette opération ?") && start(async () => { const r = await deleteTransaction(id); if (r.ok) toast.success(r.message); else toast.error(r.error); })}>
      <Trash2 className="h-4 w-4" />
    </button>
  );
}

export function BudgetButton({ units, year, unitId, amount }: { units: { id: string; label: string }[]; year: number; unitId?: string; amount?: number }) {
  const [open, setOpen] = useState(false);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        {unitId ? <button className="text-xs font-medium text-primary hover:underline">Modifier</button> : <Button size="sm"><Plus className="h-4 w-4" /> Définir un budget</Button>}
      </DialogTrigger>
      <DialogContent title="Budget annuel" size="sm">
        <ActionForm action={setBudget} onSuccess={() => setOpen(false)}>
          <Field label="Unité" htmlFor="unit_id" required><UnitSelect units={units} name="unit_id" defaultValue={unitId} required /></Field>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Exercice" htmlFor="fiscal_year"><Input id="fiscal_year" name="fiscal_year" type="number" defaultValue={year} /></Field>
            <Field label="Montant (FCFA)" htmlFor="amount" required><Input id="amount" name="amount" inputMode="numeric" defaultValue={amount} required /></Field>
          </div>
          <Field label="Notes" htmlFor="notes"><Textarea id="notes" name="notes" rows={2} /></Field>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function InvoiceButton({ units, accounts }: { units: { id: string; label: string }[]; accounts: { id: string; name: string }[] }) {
  const [open, setOpen] = useState(false);
  const router = useRouter();
  const due = new Date(Date.now() + 30 * 86400000).toISOString().slice(0, 10);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><Button size="sm" variant="outline"><Plus className="h-4 w-4" /> Nouvelle facture</Button></DialogTrigger>
      <DialogContent title="Nouvelle facture" size="lg">
        <ActionForm action={createInvoice} submitLabel="Créer la facture" onSuccess={(r) => { setOpen(false); const id = r.ok && (r.data as { id: string })?.id; if (id) router.push(`/finance/factures/${id}`); }}>
          <Field label="Client" htmlFor="account_id" required>
            <Select id="account_id" name="account_id" required defaultValue=""><option value="" disabled>Choisir…</option>{accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</Select>
          </Field>
          <div className="grid gap-4 sm:grid-cols-3">
            <Field label="Date d'émission" htmlFor="issue_date"><Input id="issue_date" name="issue_date" type="date" defaultValue={todayISO()} /></Field>
            <Field label="Échéance" htmlFor="due_date"><Input id="due_date" name="due_date" type="date" defaultValue={due} /></Field>
            <Field label="TVA %" htmlFor="tax_rate"><Input id="tax_rate" name="tax_rate" type="number" step="0.01" defaultValue={18} /></Field>
            <Field label="Produit" htmlFor="product"><Select id="product" name="product" defaultValue=""><option value="">—</option>{PRODUCTS.map((p) => <option key={p}>{p}</option>)}</Select></Field>
            <Field label="Pays" htmlFor="country"><Select id="country" name="country" defaultValue="BJ">{Object.entries(COUNTRIES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</Select></Field>
            <Field label="Unité" htmlFor="unit_id"><UnitSelect units={units} name="unit_id" /></Field>
          </div>
          <div className="grid gap-4 rounded-xl border border-border p-4 sm:grid-cols-[1fr_180px]">
            <Field label="Première ligne" htmlFor="line_description"><Input id="line_description" name="line_description" placeholder="Désignation" /></Field>
            <Field label="Montant HT" htmlFor="line_amount"><Input id="line_amount" name="line_amount" inputMode="numeric" /></Field>
          </div>
          <Field label="Notes" htmlFor="notes"><Textarea id="notes" name="notes" rows={2} placeholder="Conditions de paiement, coordonnées bancaires…" /></Field>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}
