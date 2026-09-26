"use client";

import { useState, useTransition } from "react";
import { Plus, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { ActionForm } from "@/components/ui/action-form";
import { Field, Input, Select, Textarea } from "@/components/ui/input";
import { PersonSelect, UnitSelect } from "@/components/pickers";
import { objectiveStatus } from "@/lib/labels";
import type { KeyResult, ObjectiveStatus, ProfileLite } from "@/lib/types";
import { num } from "@/lib/utils";
import { addKeyResult, createObjective, deleteObjective, saveKpi, updateKeyResult, updateObjectiveStatus } from "./actions";

export function ObjectiveButton({
  units, parents, people, period, allowed,
}: { units: { id: string; label: string }[]; parents: { id: string; title: string }[]; people: ProfileLite[]; period: string; allowed: ("company" | "unit" | "individual")[] }) {
  const [open, setOpen] = useState(false);
  const [level, setLevel] = useState(allowed[0]);
  const [krs, setKrs] = useState(1);
  const labels = { company: "Entreprise", unit: "Unité / département", individual: "Individuel" };
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><Button size="sm"><Plus className="h-4 w-4" /> Nouvel objectif</Button></DialogTrigger>
      <DialogContent title="Nouvel objectif" description="Un objectif, des résultats clés mesurables." size="lg">
        <ActionForm action={createObjective} submitLabel="Créer l'objectif" onSuccess={() => { setOpen(false); setKrs(1); }}>
          <div className="grid gap-4 sm:grid-cols-3">
            <Field label="Niveau" htmlFor="level">
              <Select id="level" name="level" value={level} onChange={(e) => setLevel(e.target.value as typeof level)}>
                {allowed.map((l) => <option key={l} value={l}>{labels[l]}</option>)}
              </Select>
            </Field>
            <Field label="Période" htmlFor="period"><Input id="period" name="period" defaultValue={period} placeholder="2026-T4" /></Field>
            {level === "unit" ? (
              <Field label="Unité" htmlFor="unit_id" required><UnitSelect units={units} name="unit_id" required /></Field>
            ) : level === "individual" ? (
              <Field label="Titulaire" htmlFor="owner_id"><PersonSelect people={people} name="owner_id" placeholder="Moi" /></Field>
            ) : <div />}
          </div>
          <Field label="Objectif" htmlFor="title" required><Input id="title" name="title" required placeholder="Ex. : Devenir la plateforme éducative n°1 en Afrique de l'Ouest" /></Field>
          <Field label="Contexte" htmlFor="description"><Textarea id="description" name="description" rows={2} /></Field>
          {parents.length > 0 && level !== "company" && (
            <Field label="Contribue à" htmlFor="parent_id">
              <Select id="parent_id" name="parent_id" defaultValue=""><option value="">—</option>{parents.map((p) => <option key={p.id} value={p.id}>{p.title}</option>)}</Select>
            </Field>
          )}
          <div className="rounded-xl border border-border p-4">
            <p className="mb-3 text-[13px] font-medium text-fg">Résultats clés</p>
            <div className="space-y-2">
              {Array.from({ length: krs }).map((_, i) => (
                <div key={i} className="grid gap-2 sm:grid-cols-[1fr_130px_110px]">
                  <Input name="kr_title" placeholder="Ex. : Utilisateurs actifs mensuels" />
                  <Input name="kr_target" placeholder="Cible" inputMode="decimal" />
                  <Input name="kr_unit" placeholder="Unité" />
                </div>
              ))}
            </div>
            <button type="button" onClick={() => setKrs((n) => Math.min(n + 1, 6))} className="mt-2 text-xs font-medium text-primary hover:underline">+ Ajouter un résultat clé</button>
          </div>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function KeyResultRow({ kr, editable }: { kr: KeyResult; editable: boolean }) {
  const [value, setValue] = useState(String(Number(kr.current_value)));
  const [pending, start] = useTransition();
  const progress = Math.max(0, Math.min(100, ((Number(kr.current_value) - Number(kr.start_value)) / (Number(kr.target_value) - Number(kr.start_value))) * 100));
  return (
    <li className="grid items-center gap-3 py-2.5 sm:grid-cols-[1fr_220px_48px]">
      <span className="text-sm text-fg">{kr.title}</span>
      <span className="flex items-center gap-2">
        {editable ? (
          <Input value={value} onChange={(e) => setValue(e.target.value)} disabled={pending} inputMode="decimal" className="h-8 w-28 text-right tabular-nums"
            onBlur={() => {
              const n = Number(value.replace(",", "."));
              if (!Number.isFinite(n) || n === Number(kr.current_value)) return;
              start(async () => { const r = await updateKeyResult(kr.id, n); if (!r.ok) toast.error(r.error); });
            }} />
        ) : <span className="w-28 text-right text-sm tabular-nums text-fg">{num(kr.current_value)}</span>}
        <span className="text-xs text-subtle">/ {num(kr.target_value)} {kr.metric_unit}</span>
      </span>
      <span className="text-right text-xs font-medium tabular-nums text-muted">{Math.round(progress)} %</span>
    </li>
  );
}

export function StatusSelect({ id, value }: { id: string; value: ObjectiveStatus }) {
  const [pending, start] = useTransition();
  return (
    <select disabled={pending} defaultValue={value} onChange={(e) => start(async () => { const r = await updateObjectiveStatus(id, e.target.value as ObjectiveStatus); if (!r.ok) toast.error(r.error); })}
      className="rounded-lg border border-border bg-surface px-2 py-1 text-xs text-fg">
      {Object.entries(objectiveStatus).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
    </select>
  );
}

export function ObjectiveMenu({ id }: { id: string }) {
  const [open, setOpen] = useState(false);
  const [pending, start] = useTransition();
  return (
    <div className="flex items-center gap-1">
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogTrigger asChild><button className="rounded p-1 text-subtle hover:text-fg" aria-label="Ajouter un résultat clé"><Plus className="h-4 w-4" /></button></DialogTrigger>
        <DialogContent title="Nouveau résultat clé" size="sm">
          <ActionForm action={addKeyResult} onSuccess={() => setOpen(false)}>
            <input type="hidden" name="objective_id" value={id} />
            <Field label="Intitulé" htmlFor="title" required><Input id="title" name="title" required /></Field>
            <div className="grid grid-cols-3 gap-3">
              <Field label="Départ" htmlFor="start_value"><Input id="start_value" name="start_value" defaultValue="0" inputMode="decimal" /></Field>
              <Field label="Cible" htmlFor="target_value" required><Input id="target_value" name="target_value" required inputMode="decimal" /></Field>
              <Field label="Unité" htmlFor="metric_unit"><Input id="metric_unit" name="metric_unit" /></Field>
            </div>
          </ActionForm>
        </DialogContent>
      </Dialog>
      <button disabled={pending} className="rounded p-1 text-subtle hover:text-danger" aria-label="Supprimer"
        onClick={() => confirm("Supprimer cet objectif et ses résultats clés ?") && start(async () => { const r = await deleteObjective(id); if (!r.ok) toast.error(r.error); })}>
        <Trash2 className="h-4 w-4" />
      </button>
    </div>
  );
}

export function KpiButton({ people }: { people: ProfileLite[] }) {
  const [open, setOpen] = useState(false);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><Button size="sm" variant="outline"><Plus className="h-4 w-4" /> Indicateur</Button></DialogTrigger>
      <DialogContent title="Définir un indicateur" description="Une définition unique évite les chiffres divergents.">
        <ActionForm action={saveKpi} onSuccess={() => setOpen(false)}>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Clé" htmlFor="key" required><Input id="key" name="key" required placeholder="churn_rate" /></Field>
            <Field label="Nom" htmlFor="name" required><Input id="name" name="name" required /></Field>
          </div>
          <Field label="Définition" htmlFor="description"><Textarea id="description" name="description" rows={2} /></Field>
          <Field label="Formule" htmlFor="formula"><Input id="formula" name="formula" /></Field>
          <div className="grid grid-cols-3 gap-4">
            <Field label="Source" htmlFor="source"><Input id="source" name="source" /></Field>
            <Field label="Unité" htmlFor="unit"><Input id="unit" name="unit" /></Field>
            <Field label="Responsable" htmlFor="owner_id"><PersonSelect people={people} name="owner_id" /></Field>
          </div>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}
