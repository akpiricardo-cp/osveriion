"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Archive, Pencil, Plus, UserPlus } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { ActionForm } from "@/components/ui/action-form";
import { Field, Input, Select, Textarea } from "@/components/ui/input";
import { PersonSelect, UnitSelect } from "@/components/pickers";
import { membershipRole, unitDomain, unitKind } from "@/lib/labels";
import type { OrgUnit, ProfileLite } from "@/lib/types";
import { cn, todayISO } from "@/lib/utils";
import { appointMember, archiveUnit, createUnit, updateUnit } from "./actions";

const COLORS = ["#0B1F3A", "#0E7490", "#4F46E5", "#7C3AED", "#DB2777", "#EA580C", "#D97706", "#059669", "#0284C7", "#475569"];

function ColorPicker({ defaultValue }: { defaultValue?: string }) {
  const [color, setColor] = useState(defaultValue ?? COLORS[2]);
  return (
    <div className="flex flex-wrap gap-2">
      <input type="hidden" name="color" value={color} />
      {COLORS.map((c) => (
        <button key={c} type="button" onClick={() => setColor(c)} aria-label={c}
          className={cn("h-7 w-7 rounded-full ring-offset-2 ring-offset-surface transition", color === c && "ring-2 ring-fg/60")} style={{ background: c }} />
      ))}
    </div>
  );
}

function UnitFields({ unit, units, parentId }: { unit?: OrgUnit; units: { id: string; label: string }[]; parentId?: string }) {
  return (
    <>
      {unit && <input type="hidden" name="id" value={unit.id} />}
      <div className="grid gap-4 sm:grid-cols-[1fr_120px]">
        <Field label="Nom" htmlFor="name" required><Input id="name" name="name" required defaultValue={unit?.name} /></Field>
        <Field label="Code" htmlFor="code"><Input id="code" name="code" defaultValue={unit?.code ?? ""} placeholder="MKT" /></Field>
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Type" htmlFor="kind" required>
          <Select id="kind" name="kind" defaultValue={unit?.kind ?? (parentId ? "subdepartment" : "department")}>
            {Object.entries(unitKind).map(([k, l]) => <option key={k} value={k}>{l}</option>)}
          </Select>
        </Field>
        <Field label="Domaine" htmlFor="domain" hint="Détermine les droits automatiques.">
          <Select id="domain" name="domain" defaultValue={unit?.domain ?? ""}>
            <option value="">Hérité de l&apos;unité parente</option>
            {Object.entries(unitDomain).map(([k, l]) => <option key={k} value={k}>{l}</option>)}
          </Select>
        </Field>
      </div>
      <Field label="Rattachée à" htmlFor="parent_id">
        <UnitSelect units={units.filter((u) => u.id !== unit?.id)} name="parent_id" defaultValue={unit?.parent_id ?? parentId} placeholder="— Racine —" />
      </Field>
      <Field label="Couleur"><ColorPicker defaultValue={unit?.color} /></Field>
      <Field label="Mission" htmlFor="description"><Textarea id="description" name="description" rows={3} defaultValue={unit?.description ?? ""} /></Field>
    </>
  );
}

export function CreateUnitButton({ units, parentId, label = "Nouvelle unité" }: { units: { id: string; label: string }[]; parentId?: string; label?: string }) {
  const [open, setOpen] = useState(false);
  const router = useRouter();
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><Button size="sm"><Plus className="h-4 w-4" /> {label}</Button></DialogTrigger>
      <DialogContent title="Créer une unité" description="Département, sous-département ou équipe.">
        <ActionForm action={createUnit} submitLabel="Créer" onSuccess={(r) => { setOpen(false); const id = (r.ok && (r.data as { id: string })?.id); if (id) router.push(`/organisation/${id}`); }}>
          <UnitFields units={units} parentId={parentId} />
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function EditUnitButton({ unit, units, canRestructure }: { unit: OrgUnit; units: { id: string; label: string }[]; canRestructure: boolean }) {
  const [open, setOpen] = useState(false);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><Button size="sm" variant="outline"><Pencil className="h-4 w-4" /> Modifier</Button></DialogTrigger>
      <DialogContent title={`Modifier « ${unit.name} »`}>
        <ActionForm action={updateUnit} onSuccess={() => setOpen(false)} resetOnSuccess={false}>
          {canRestructure ? (
            <UnitFields unit={unit} units={units} />
          ) : (
            <>
              <input type="hidden" name="id" value={unit.id} />
              <Field label="Nom" htmlFor="name" required><Input id="name" name="name" required defaultValue={unit.name} /></Field>
              <Field label="Code" htmlFor="code"><Input id="code" name="code" defaultValue={unit.code ?? ""} /></Field>
              <Field label="Couleur"><ColorPicker defaultValue={unit.color} /></Field>
              <Field label="Mission" htmlFor="description"><Textarea id="description" name="description" rows={3} defaultValue={unit.description ?? ""} /></Field>
            </>
          )}
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function ArchiveUnitButton({ id }: { id: string }) {
  const [pending, start] = useTransition();
  const router = useRouter();
  return (
    <Button size="sm" variant="ghost" loading={pending} onClick={() => {
      if (!confirm("Archiver cette unité ? Ses membres perdront les droits associés. L'historique est conservé.")) return;
      start(async () => {
        const r = await archiveUnit(id);
        if (r.ok) { toast.success(r.message); router.push("/organisation"); } else toast.error(r.error);
      });
    }}>
      <Archive className="h-4 w-4" /> Archiver
    </Button>
  );
}

export function AppointButton({
  unitId, people, defaultRole = "member", label, variant = "primary",
}: { unitId: string; people: ProfileLite[]; defaultRole?: "head" | "deputy" | "member"; label?: string; variant?: "primary" | "outline" }) {
  const [open, setOpen] = useState(false);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm" variant={variant}><UserPlus className="h-4 w-4" /> {label ?? "Ajouter un membre"}</Button>
      </DialogTrigger>
      <DialogContent title="Affecter une personne" description="La nomination met à jour ses droits automatiquement. L'affectation précédente est clôturée et historisée.">
        <ActionForm action={appointMember} submitLabel="Confirmer" onSuccess={() => setOpen(false)}>
          <input type="hidden" name="unit_id" value={unitId} />
          <Field label="Personne" htmlFor="profile_id" required><PersonSelect people={people} name="profile_id" required placeholder="Choisir…" /></Field>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Rôle" htmlFor="role">
              <Select id="role" name="role" defaultValue={defaultRole}>
                {Object.entries(membershipRole).map(([k, l]) => <option key={k} value={k}>{l}</option>)}
              </Select>
            </Field>
            <Field label="À partir du" htmlFor="start_date"><Input id="start_date" name="start_date" type="date" defaultValue={todayISO()} /></Field>
          </div>
          <Field label="Intitulé du poste" htmlFor="title" hint="Ex. : CMO, Lead Backend, Chargé d'acquisition"><Input id="title" name="title" /></Field>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}
