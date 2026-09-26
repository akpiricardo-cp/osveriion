"use client";

import { useState, useTransition } from "react";
import { MoreHorizontal, Plus, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { ActionForm } from "@/components/ui/action-form";
import { Checkbox, Field, Input, Textarea } from "@/components/ui/input";
import { UnitSelect } from "@/components/pickers";
import { Dropdown, DropdownContent, DropdownItem, DropdownTrigger } from "@/components/ui/dropdown";
import { deleteAnnouncement, publishAnnouncement } from "./home-actions";

export function AnnouncementComposer({ units }: { units: { id: string; label: string }[] }) {
  const [open, setOpen] = useState(false);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm" variant="outline"><Plus className="h-4 w-4" /> Publier</Button>
      </DialogTrigger>
      <DialogContent title="Nouvelle annonce" description="Tous les destinataires recevront une notification.">
        <ActionForm action={publishAnnouncement} submitLabel="Publier l'annonce" onSuccess={() => setOpen(false)}>
          <Field label="Titre" htmlFor="title" required><Input id="title" name="title" required maxLength={140} /></Field>
          <Field label="Message" htmlFor="body" required><Textarea id="body" name="body" required rows={6} /></Field>
          <Field label="Destinataires" htmlFor="unit_id" hint="Laissez vide pour toute l'entreprise.">
            <UnitSelect units={units} name="unit_id" placeholder="Toute l'entreprise" />
          </Field>
          <Checkbox name="pinned" label="Épingler en haut du fil" />
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function AnnouncementActions({ id }: { id: string }) {
  const [pending, start] = useTransition();
  return (
    <Dropdown>
      <DropdownTrigger className="rounded-md p-1 text-subtle hover:bg-surface-2 hover:text-fg" disabled={pending} aria-label="Actions">
        <MoreHorizontal className="h-4 w-4" />
      </DropdownTrigger>
      <DropdownContent>
        <DropdownItem danger onSelect={() => start(async () => {
          const r = await deleteAnnouncement(id);
          if (r.ok) toast.success(r.message); else toast.error(r.error);
        })}>
          <Trash2 className="h-4 w-4" /> Supprimer
        </DropdownItem>
      </DropdownContent>
    </Dropdown>
  );
}
