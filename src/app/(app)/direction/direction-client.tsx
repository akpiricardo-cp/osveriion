"use client";

import { useState, useTransition } from "react";
import { Activity, AlertTriangle } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { ActionForm } from "@/components/ui/action-form";
import { Field, Input, Select, Textarea } from "@/components/ui/input";
import { PRODUCTS, severity } from "@/lib/labels";
import { todayISO } from "@/lib/utils";
import { recordMetrics, reportIncident, setIncidentStatus } from "./actions";

export function MetricsButton() {
  const [open, setOpen] = useState(false);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><Button size="sm" variant="outline"><Activity className="h-4 w-4" /> Métriques produit</Button></DialogTrigger>
      <DialogContent title="Saisir les métriques du jour" description="Peut aussi être alimenté automatiquement par API (table product_metrics).">
        <ActionForm action={recordMetrics} onSuccess={() => setOpen(false)}>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Date" htmlFor="metric_date"><Input id="metric_date" name="metric_date" type="date" defaultValue={todayISO()} /></Field>
            <Field label="Produit" htmlFor="product"><Select id="product" name="product" defaultValue="VERIION"><option value="VERIION">Tous produits</option>{PRODUCTS.map((p) => <option key={p}>{p}</option>)}</Select></Field>
            <Field label="Utilisateurs actifs" htmlFor="active_users" required><Input id="active_users" name="active_users" inputMode="numeric" required /></Field>
            <Field label="Nouveaux utilisateurs" htmlFor="new_users"><Input id="new_users" name="new_users" inputMode="numeric" /></Field>
          </div>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function IncidentButton() {
  const [open, setOpen] = useState(false);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><Button size="sm" variant="outline"><AlertTriangle className="h-4 w-4" /> Signaler un incident</Button></DialogTrigger>
      <DialogContent title="Signaler un incident">
        <ActionForm action={reportIncident} onSuccess={() => setOpen(false)}>
          <Field label="Titre" htmlFor="title" required><Input id="title" name="title" required /></Field>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Gravité" htmlFor="severity"><Select id="severity" name="severity" defaultValue="medium">{Object.entries(severity).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}</Select></Field>
            <Field label="Produit" htmlFor="product"><Select id="product" name="product" defaultValue=""><option value="">—</option>{PRODUCTS.map((p) => <option key={p}>{p}</option>)}</Select></Field>
          </div>
          <Field label="Description" htmlFor="description"><Textarea id="description" name="description" rows={3} /></Field>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function IncidentStatus({ id, status }: { id: string; status: "open" | "mitigated" | "resolved" }) {
  const [pending, start] = useTransition();
  return (
    <select disabled={pending} defaultValue={status} className="rounded-lg border border-border bg-surface px-2 py-1 text-xs text-fg"
      onChange={(e) => start(async () => { const r = await setIncidentStatus(id, e.target.value as typeof status); if (r.ok) toast.success(r.message); else toast.error(r.error); })}>
      <option value="open">Ouvert</option>
      <option value="mitigated">Atténué</option>
      <option value="resolved">Résolu</option>
    </select>
  );
}
