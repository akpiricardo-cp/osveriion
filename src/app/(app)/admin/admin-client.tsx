"use client";

import { useState, useTransition } from "react";
import { KeyRound, MoreHorizontal, Plus, ShieldOff, UserCheck, UserMinus, UserPlus, X } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { Dropdown, DropdownContent, DropdownItem, DropdownSeparator, DropdownTrigger } from "@/components/ui/dropdown";
import { ActionForm } from "@/components/ui/action-form";
import { Checkbox, Field, Input, Select, Textarea } from "@/components/ui/input";
import { PersonSelect, UnitSelect } from "@/components/pickers";
import { membershipRole, systemRole, unitDomain } from "@/lib/labels";
import type { ProfileLite } from "@/lib/types";
import { addTemplate, grantException, inviteUser, offboardUser, removeTemplate, revokeGrant, sendPasswordReset, setUserStatus } from "./actions";

export function InviteButton({ units, people, isCeo }: { units: { id: string; label: string }[]; people: ProfileLite[]; isCeo: boolean }) {
  const [open, setOpen] = useState(false);
  const domain = process.env.NEXT_PUBLIC_EMAIL_DOMAIN ?? "veriion.com";
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><Button size="sm"><UserPlus className="h-4 w-4" /> Inviter un collaborateur</Button></DialogTrigger>
      <DialogContent title="Inviter un collaborateur" description="Un e-mail d'invitation lui permettra de définir son mot de passe. Ses droits découlent de son affectation." size="lg">
        <ActionForm action={inviteUser} submitLabel="Envoyer l'invitation" onSuccess={() => setOpen(false)}>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Prénom" htmlFor="first_name" required><Input id="first_name" name="first_name" required /></Field>
            <Field label="Nom" htmlFor="last_name" required><Input id="last_name" name="last_name" required /></Field>
          </div>
          <Field label="Adresse e-mail professionnelle" htmlFor="email" required hint={`Format recommandé : prenom.nom@${domain}`}>
            <Input id="email" name="email" type="email" required placeholder={`prenom.nom@${domain}`} />
          </Field>
          <Field label="Intitulé du poste" htmlFor="job_title"><Input id="job_title" name="job_title" /></Field>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Affectation" htmlFor="unit_id"><UnitSelect units={units} name="unit_id" /></Field>
            <Field label="Rôle dans l'unité" htmlFor="role"><Select id="role" name="role" defaultValue="member">{Object.entries(membershipRole).map(([k, l]) => <option key={k} value={k}>{l}</option>)}</Select></Field>
            <Field label="Manager" htmlFor="manager_id"><PersonSelect people={people} name="manager_id" placeholder="— Aucun —" /></Field>
            <Field label="Rôle système" htmlFor="system_role">
              <Select id="system_role" name="system_role" defaultValue="employee">
                {Object.entries(systemRole).filter(([k]) => isCeo || k !== "ceo").map(([k, l]) => <option key={k} value={k}>{l}</option>)}
              </Select>
            </Field>
          </div>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function UserMenu({ id, email, status, self }: { id: string; email: string; status: string; self: boolean }) {
  const [pending, start] = useTransition();
  const run = (fn: () => Promise<{ ok: boolean; message?: string; error?: string }>, msg?: string) => {
    if (msg && !confirm(msg)) return;
    start(async () => { const r = await fn(); if (r.ok) toast.success(r.message); else toast.error(r.error); });
  };
  if (self) return null;
  return (
    <Dropdown>
      <DropdownTrigger disabled={pending} className="rounded-md p-1.5 text-subtle hover:bg-surface-2 hover:text-fg" aria-label="Actions"><MoreHorizontal className="h-4 w-4" /></DropdownTrigger>
      <DropdownContent>
        <DropdownItem onSelect={() => run(() => sendPasswordReset(email))}><KeyRound className="h-4 w-4 text-subtle" /> Réinitialiser le mot de passe</DropdownItem>
        {status === "active" && <DropdownItem onSelect={() => run(() => setUserStatus(id, "suspended"), "Suspendre ce compte ? La personne ne pourra plus se connecter.")}><ShieldOff className="h-4 w-4 text-subtle" /> Suspendre</DropdownItem>}
        {status === "suspended" && <DropdownItem onSelect={() => run(() => setUserStatus(id, "active"))}><UserCheck className="h-4 w-4 text-subtle" /> Réactiver</DropdownItem>}
        {status !== "offboarded" && (
          <>
            <DropdownSeparator />
            <DropdownItem danger onSelect={() => run(() => offboardUser(id), "Enregistrer le départ ? Tous les accès seront révoqués, les affectations clôturées et les tâches désassignées.")}>
              <UserMinus className="h-4 w-4" /> Enregistrer le départ
            </DropdownItem>
          </>
        )}
      </DropdownContent>
    </Dropdown>
  );
}

export function GrantButton({ people, units, permissions }: { people: ProfileLite[]; units: { id: string; label: string }[]; permissions: { key: string; label: string; scopable: boolean }[] }) {
  const [open, setOpen] = useState(false);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><Button size="sm" variant="outline"><Plus className="h-4 w-4" /> Dérogation</Button></DialogTrigger>
      <DialogContent title="Accorder une dérogation" description="Droit manuel, temporaire et motivé. Il est journalisé et visible par l'audit.">
        <ActionForm action={grantException} onSuccess={() => setOpen(false)}>
          <Field label="Bénéficiaire" htmlFor="profile_id" required><PersonSelect people={people} name="profile_id" required placeholder="Choisir…" /></Field>
          <Field label="Permission" htmlFor="permission" required>
            <Select id="permission" name="permission" required>{permissions.map((p) => <option key={p.key} value={p.key}>{p.label} ({p.key})</option>)}</Select>
          </Field>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Limitée à l'unité" htmlFor="scope_unit_id" hint="Pour les permissions d'unité"><UnitSelect units={units} name="scope_unit_id" placeholder="— Globale —" /></Field>
            <Field label="Durée" htmlFor="days"><Select id="days" name="days" defaultValue="30"><option value="7">7 jours</option><option value="30">30 jours</option><option value="90">90 jours</option><option value="">Sans expiration</option></Select></Field>
          </div>
          <Field label="Motif" htmlFor="reason" required><Textarea id="reason" name="reason" required rows={2} placeholder="Ex. : intérim du CFO pendant ses congés" /></Field>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function RevokeButton({ id }: { id: string }) {
  const [pending, start] = useTransition();
  return (
    <button disabled={pending} aria-label="Révoquer" className="rounded p-1 text-subtle hover:text-danger disabled:opacity-40"
      onClick={() => confirm("Révoquer cette dérogation ?") && start(async () => { const r = await revokeGrant(id); if (r.ok) toast.success(r.message); else toast.error(r.error); })}>
      <X className="h-4 w-4" />
    </button>
  );
}

export function TemplateButton({ permissions }: { permissions: { key: string; label: string; scopable: boolean }[] }) {
  const [open, setOpen] = useState(false);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><Button size="sm" variant="outline"><Plus className="h-4 w-4" /> Règle</Button></DialogTrigger>
      <DialogContent title="Nouvelle règle d'attribution automatique" description="Toute personne ayant ce rôle dans une unité de ce domaine recevra la permission.">
        <ActionForm action={addTemplate} onSuccess={() => setOpen(false)}>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Domaine" htmlFor="domain"><Select id="domain" name="domain" defaultValue=""><option value="">Toutes les unités</option>{Object.entries(unitDomain).map(([k, l]) => <option key={k} value={k}>{l}</option>)}</Select></Field>
            <Field label="Rôle minimum" htmlFor="membership_role"><Select id="membership_role" name="membership_role">{Object.entries(membershipRole).map(([k, l]) => <option key={k} value={k}>{l}</option>)}</Select></Field>
          </div>
          <Field label="Permission" htmlFor="permission" required><Select id="permission" name="permission">{permissions.map((p) => <option key={p.key} value={p.key}>{p.label}</option>)}</Select></Field>
          <Checkbox name="scoped" label="Limiter la permission à l'unité (et ses sous-unités)" />
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function RemoveTemplateButton({ id }: { id: string }) {
  const [pending, start] = useTransition();
  return (
    <button disabled={pending} aria-label="Supprimer" className="rounded p-1 text-subtle hover:text-danger disabled:opacity-40"
      onClick={() => confirm("Supprimer cette règle ? Les droits de tous les collaborateurs seront recalculés.") && start(async () => { const r = await removeTemplate(id); if (r.ok) toast.success(r.message); else toast.error(r.error); })}>
      <X className="h-4 w-4" />
    </button>
  );
}
