"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { CheckCircle2, Plus, Undo2 } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { ActionForm } from "@/components/ui/action-form";
import { Field, Input, Select, Textarea } from "@/components/ui/input";
import { UnitSelect } from "@/components/pickers";
import { COUNTRIES, EXPENSE_CATEGORIES, PRODUCTS, REVENUE_CATEGORIES } from "@/lib/labels";
import { money, todayISO } from "@/lib/utils";
import { activateBudget, addTransaction, createInvoice, reverseTransaction, setBudget } from "./actions";

export type ExpenseApproval = { id: string; subject_label: string; amount: number; consumed_amount: number; remaining: number; currency: string };

export function TransactionButton({ units, accounts, approvals, threshold }: { units: { id: string; label: string }[]; accounts: { id: string; name: string }[]; approvals: ExpenseApproval[]; threshold: number }) {
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
          {type === "expense" && (
            <Field label="Accord du CEO" htmlFor="approval_id" hint={`Obligatoire au-delà de ${money(threshold)}. Le montant est déduit du reste disponible de l'accord.`}>
              <Select id="approval_id" name="approval_id" defaultValue="">
                <option value="">— Aucun (dépense sous le seuil)</option>
                {approvals.map((a) => <option key={a.id} value={a.id}>{a.subject_label} — reste {money(a.remaining, a.currency)}</option>)}
              </Select>
            </Field>
          )}
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function ReverseTransaction({ id }: { id: string }) {
  const [pending, start] = useTransition();
  return (
    <button disabled={pending} aria-label="Contre-passer" title="Annuler par contre-passation" className="rounded p-1 text-subtle hover:text-danger disabled:opacity-40"
      onClick={() => {
        const reason = prompt("Motif de l'annulation (une écriture inverse sera passée, l'opération reste tracée) :");
        if (!reason || reason.trim().length < 3) return;
        start(async () => { const r = await reverseTransaction(id, reason); if (r.ok) toast.success(r.message); else toast.error(r.error); });
      }}>
      <Undo2 className="h-4 w-4" />
    </button>
  );
}

export function ActivateBudget({ id }: { id: string }) {
  const [pending, start] = useTransition();
  return (
    <Button size="sm" variant="outline" loading={pending}
      onClick={() => start(async () => { const r = await activateBudget(id); if (r.ok) toast.success(r.message); else toast.error(r.error); })}>
      <CheckCircle2 className="h-4 w-4" /> Activer
    </Button>
  );
}

export function BudgetButton({ units, projects, year, unitId, projectId, amount }: { units: { id: string; label: string }[]; projects: { id: string; label: string }[]; year: number; unitId?: string; projectId?: string; amount?: number }) {
  const [open, setOpen] = useState(false);
  const [scope, setScope] = useState<"unit" | "project">(projectId ? "project" : "unit");
  const editing = Boolean(unitId || projectId);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        {editing ? <button className="text-xs font-medium text-primary hover:underline">Modifier</button> : <Button size="sm"><Plus className="h-4 w-4" /> Définir un budget</Button>}
      </DialogTrigger>
      <DialogContent title="Budget annuel" description="Enregistré en brouillon : activez-le ensuite. Modifier un budget actif le repasse en brouillon." size="sm">
        <ActionForm action={setBudget} onSuccess={() => setOpen(false)}>
          {!editing && (
            <div className="grid grid-cols-2 gap-2 rounded-xl bg-surface-2 p-1">
              {([["unit", "Unité"], ["project", "Projet"]] as const).map(([k, l]) => (
                <button key={k} type="button" onClick={() => setScope(k)} className={`rounded-lg py-2 text-sm font-medium transition ${scope === k ? "bg-surface text-fg shadow-sm" : "text-muted"}`}>{l}</button>
              ))}
            </div>
          )}
          {scope === "unit" ? (
            <Field label="Unité" htmlFor="unit_id" required><UnitSelect units={units} name="unit_id" defaultValue={unitId} required /></Field>
          ) : (
            <Field label="Projet" htmlFor="project_id" required>
              <Select id="project_id" name="project_id" defaultValue={projectId ?? ""} required>
                <option value="" disabled>Choisir…</option>
                {projects.map((p) => <option key={p.id} value={p.id}>{p.label}</option>)}
              </Select>
            </Field>
          )}
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
