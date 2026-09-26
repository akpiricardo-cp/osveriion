"use client";

import { useState, useTransition } from "react";
import { Check, Plus, X } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { ActionForm } from "@/components/ui/action-form";
import { Field, Input, Select, Textarea } from "@/components/ui/input";
import { PersonSelect } from "@/components/pickers";
import { contractType, leaveType } from "@/lib/labels";
import type { ProfileLite } from "@/lib/types";
import { todayISO } from "@/lib/utils";
import { addContract, addLifecycleItem, cancelLeave, decideLeave, requestLeave } from "./actions";

export function LeaveRequestButton() {
  const [open, setOpen] = useState(false);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><Button size="sm"><Plus className="h-4 w-4" /> Demander un congé</Button></DialogTrigger>
      <DialogContent title="Demande d'absence" description="Votre responsable sera notifié immédiatement.">
        <ActionForm action={requestLeave} submitLabel="Envoyer la demande" onSuccess={() => setOpen(false)}>
          <Field label="Type" htmlFor="type"><Select id="type" name="type">{Object.entries(leaveType).map(([k, l]) => <option key={k} value={k}>{l}</option>)}</Select></Field>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Du" htmlFor="start_date" required><Input id="start_date" name="start_date" type="date" required min={todayISO()} /></Field>
            <Field label="Au (inclus)" htmlFor="end_date" required><Input id="end_date" name="end_date" type="date" required min={todayISO()} /></Field>
          </div>
          <Field label="Motif / commentaire" htmlFor="reason"><Textarea id="reason" name="reason" rows={3} /></Field>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function DecideButtons({ id }: { id: string }) {
  const [pending, start] = useTransition();
  const go = (d: "approved" | "rejected") => {
    const note = d === "rejected" ? prompt("Motif du refus (communiqué au demandeur) :") ?? undefined : undefined;
    if (d === "rejected" && note === undefined) return;
    start(async () => { const r = await decideLeave(id, d, note); if (r.ok) toast.success(r.message); else toast.error(r.error); });
  };
  return (
    <div className="flex gap-1.5">
      <Button size="sm" variant="success" loading={pending} onClick={() => go("approved")}><Check className="h-4 w-4" /> Approuver</Button>
      <Button size="sm" variant="outline" disabled={pending} onClick={() => go("rejected")}><X className="h-4 w-4" /> Refuser</Button>
    </div>
  );
}

export function CancelLeaveButton({ id }: { id: string }) {
  const [pending, start] = useTransition();
  return (
    <button disabled={pending} className="text-xs font-medium text-muted hover:text-danger disabled:opacity-50"
      onClick={() => confirm("Annuler cette demande ?") && start(async () => { const r = await cancelLeave(id); if (!r.ok) toast.error(r.error); })}>
      Annuler
    </button>
  );
}

export function ContractButton({ people, profileId }: { people: ProfileLite[]; profileId?: string }) {
  const [open, setOpen] = useState(false);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        {profileId ? <button className="text-xs font-medium text-primary hover:underline">+ Contrat</button> : <Button size="sm" variant="outline"><Plus className="h-4 w-4" /> Contrat</Button>}
      </DialogTrigger>
      <DialogContent title="Nouveau contrat" size="lg">
        <ActionForm action={addContract} onSuccess={() => setOpen(false)}>
          <Field label="Employé" htmlFor="profile_id" required><PersonSelect people={people} name="profile_id" defaultValue={profileId} required placeholder="Choisir…" /></Field>
          <div className="grid gap-4 sm:grid-cols-3">
            <Field label="Type" htmlFor="type"><Select id="type" name="type">{Object.entries(contractType).map(([k, l]) => <option key={k} value={k}>{l}</option>)}</Select></Field>
            <Field label="Début" htmlFor="start_date" required><Input id="start_date" name="start_date" type="date" required defaultValue={todayISO()} /></Field>
            <Field label="Fin (CDD, stage)" htmlFor="end_date"><Input id="end_date" name="end_date" type="date" /></Field>
            <Field label="Poste" htmlFor="job_title" className="sm:col-span-2"><Input id="job_title" name="job_title" /></Field>
            <Field label="Heures / semaine" htmlFor="weekly_hours"><Input id="weekly_hours" name="weekly_hours" type="number" defaultValue={40} /></Field>
          </div>
          <Field label="Salaire brut mensuel (FCFA)" htmlFor="gross_monthly" hint="Visible uniquement par l'employé, les RH et la Finance."><Input id="gross_monthly" name="gross_monthly" inputMode="numeric" /></Field>
          <Field label="Notes" htmlFor="notes"><Textarea id="notes" name="notes" rows={2} /></Field>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function LifecycleItemButton({ profileId, kind, people }: { profileId: string; kind: "onboarding" | "offboarding"; people: ProfileLite[] }) {
  const [open, setOpen] = useState(false);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><button className="text-xs font-medium text-primary hover:underline">+ Étape</button></DialogTrigger>
      <DialogContent title="Ajouter une étape" size="sm">
        <ActionForm action={addLifecycleItem} onSuccess={() => setOpen(false)}>
          <input type="hidden" name="profile_id" value={profileId} />
          <input type="hidden" name="kind" value={kind} />
          <Field label="Étape" htmlFor="title" required><Input id="title" name="title" required /></Field>
          <Field label="Échéance" htmlFor="due_date"><Input id="due_date" name="due_date" type="date" /></Field>
          <Field label="Responsable de l'étape" htmlFor="assignee_id"><PersonSelect people={people} name="assignee_id" /></Field>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}
