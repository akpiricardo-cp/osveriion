"use client";

import { useState, useTransition } from "react";
import { MessageSquare, Pencil } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { ActionForm } from "@/components/ui/action-form";
import { Field, Input, Select, Textarea } from "@/components/ui/input";
import { PersonSelect, UnitSelect } from "@/components/pickers";
import { systemRole } from "@/lib/labels";
import type { Profile, ProfileLite } from "@/lib/types";
import { openDirectMessage, updateProfile } from "../actions";

export function MessageButton({ id }: { id: string }) {
  const [pending, start] = useTransition();
  return (
    <Button size="sm" variant="outline" loading={pending} onClick={() => start(() => openDirectMessage(id))}>
      <MessageSquare className="h-4 w-4" /> Message
    </Button>
  );
}

export function EditProfileButton({
  profile: p, people, units, admin, manager, ceo,
}: { profile: Profile; people: ProfileLite[]; units: { id: string; label: string }[]; admin: boolean; manager: boolean; ceo: boolean }) {
  const [open, setOpen] = useState(false);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><Button size="sm"><Pencil className="h-4 w-4" /> Modifier</Button></DialogTrigger>
      <DialogContent title="Modifier le profil" size="lg">
        <ActionForm action={updateProfile} onSuccess={() => setOpen(false)} resetOnSuccess={false}>
          <input type="hidden" name="id" value={p.id} />
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Prénom" htmlFor="first_name"><Input id="first_name" name="first_name" defaultValue={p.first_name} required /></Field>
            <Field label="Nom" htmlFor="last_name"><Input id="last_name" name="last_name" defaultValue={p.last_name} /></Field>
            <Field label="Intitulé de poste" htmlFor="job_title"><Input id="job_title" name="job_title" defaultValue={p.job_title ?? ""} /></Field>
            <Field label="Téléphone" htmlFor="phone"><Input id="phone" name="phone" defaultValue={p.phone ?? ""} placeholder="+229 …" /></Field>
            <Field label="Localisation" htmlFor="location"><Input id="location" name="location" defaultValue={p.location ?? ""} placeholder="Cotonou" /></Field>
            <Field label="Date de naissance" htmlFor="birth_date"><Input id="birth_date" name="birth_date" type="date" defaultValue={p.birth_date ?? ""} /></Field>
          </div>
          <Field label="Présentation" htmlFor="bio"><Textarea id="bio" name="bio" rows={3} defaultValue={p.bio ?? ""} /></Field>
          {manager && (
            <div className="grid gap-4 rounded-xl border border-border bg-surface-2/50 p-4 sm:grid-cols-2">
              <Field label="Manager" htmlFor="manager_id"><PersonSelect people={people.filter((x) => x.id !== p.id)} name="manager_id" defaultValue={p.manager_id} placeholder="— Aucun —" /></Field>
              <Field label="Unité principale" htmlFor="primary_unit_id"><UnitSelect units={units} name="primary_unit_id" defaultValue={p.primary_unit_id} /></Field>
            </div>
          )}
          {admin && (
            <div className="grid gap-4 rounded-xl border border-amber-500/30 bg-amber-500/[0.05] p-4 sm:grid-cols-3">
              <Field label="Rôle système" htmlFor="system_role">
                <Select id="system_role" name="system_role" defaultValue={p.system_role}>
                  {Object.entries(systemRole).filter(([k]) => ceo || k !== "ceo" || p.system_role === "ceo").map(([k, l]) => <option key={k} value={k}>{l}</option>)}
                </Select>
              </Field>
              <Field label="Statut" htmlFor="status">
                <Select id="status" name="status" defaultValue={p.status}>
                  <option value="active">Actif</option>
                  <option value="suspended">Suspendu</option>
                  <option value="offboarded">Parti</option>
                </Select>
              </Field>
              <Field label="Date d'arrivée" htmlFor="hire_date"><Input id="hire_date" name="hire_date" type="date" defaultValue={p.hire_date ?? ""} /></Field>
            </div>
          )}
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}
