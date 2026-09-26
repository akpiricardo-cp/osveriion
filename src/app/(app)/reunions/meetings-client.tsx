"use client";

import { useState, useTransition } from "react";
import { Check, FileText, Plus, Trash2, Video, X } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { ActionForm } from "@/components/ui/action-form";
import { Checkbox, Field, Input, Select, Textarea } from "@/components/ui/input";
import { UnitSelect } from "@/components/pickers";
import type { Meeting, ProfileLite } from "@/lib/types";
import { todayISO } from "@/lib/utils";
import { createMeeting, deleteMeeting, respondMeeting, saveMinutes } from "./actions";

function tzOffset() {
  const m = -new Date().getTimezoneOffset();
  const s = m >= 0 ? "+" : "-";
  const a = Math.abs(m);
  return `${s}${String(Math.floor(a / 60)).padStart(2, "0")}:${String(a % 60).padStart(2, "0")}`;
}

export function MeetingButton({ people, units, projects }: { people: ProfileLite[]; units: { id: string; label: string }[]; projects: { id: string; name: string }[] }) {
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><Button size="sm"><Plus className="h-4 w-4" /> Planifier</Button></DialogTrigger>
      <DialogContent title="Planifier une réunion" size="lg">
        <ActionForm action={createMeeting} submitLabel="Planifier et inviter" onSuccess={() => setOpen(false)}>
          <input type="hidden" name="tz_offset" value={tzOffset()} />
          <Field label="Titre" htmlFor="title" required><Input id="title" name="title" required placeholder="Comité de direction hebdomadaire" /></Field>
          <div className="grid gap-4 sm:grid-cols-3">
            <Field label="Date" htmlFor="date" required><Input id="date" name="date" type="date" required defaultValue={todayISO()} /></Field>
            <Field label="Heure" htmlFor="time" required><Input id="time" name="time" type="time" required defaultValue="10:00" /></Field>
            <Field label="Durée" htmlFor="duration">
              <Select id="duration" name="duration" defaultValue="60">
                {[15, 30, 45, 60, 90, 120, 180].map((d) => <option key={d} value={d}>{d < 60 ? `${d} min` : `${d / 60} h${d % 60 ? " 30" : ""}`}</option>)}
              </Select>
            </Field>
            <Field label="Lieu" htmlFor="location"><Input id="location" name="location" placeholder="Salle Cotonou" /></Field>
            <Field label="Unité" htmlFor="unit_id"><UnitSelect units={units} name="unit_id" /></Field>
            <Field label="Projet" htmlFor="project_id"><Select id="project_id" name="project_id" defaultValue=""><option value="">—</option>{projects.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</Select></Field>
          </div>
          <Checkbox name="video" defaultChecked label="Créer une salle de visioconférence" />
          <Field label="Ordre du jour" htmlFor="description"><Textarea id="description" name="description" rows={3} /></Field>
          <Field label="Participants">
            <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Filtrer…" className="mb-2" />
            <div className="scrollbar-thin max-h-44 space-y-0.5 overflow-y-auto rounded-lg border border-border p-2">
              {people.map((p) => (
                <div key={p.id} className={p.full_name.toLowerCase().includes(q.toLowerCase()) ? "" : "hidden"}>
                  <Checkbox name="attendees" value={p.id} label={p.full_name} className="flex w-full rounded px-1 py-1 hover:bg-surface-2" />
                </div>
              ))}
            </div>
          </Field>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function MeetingControls({ meeting, isOrganizer, myResponse, past, live }: { meeting: Meeting; isOrganizer: boolean; myResponse?: string; past: boolean; live: boolean }) {
  const [pending, start] = useTransition();
  const [minutes, setMinutes] = useState(meeting.minutes ?? "");
  const [open, setOpen] = useState(false);
  const run = (fn: () => Promise<{ ok: boolean; message?: string; error?: string }>) =>
    start(async () => { const r = await fn(); if (r.ok) { if (r.message) toast.success(r.message); } else toast.error(r.error ?? "Erreur"); });
  return (
    <div className="flex shrink-0 flex-wrap items-start gap-2 sm:flex-col sm:items-end">
      {meeting.video_url && !past && (
        <a href={meeting.video_url} target="_blank" rel="noreferrer"><Button size="sm" variant={live ? "success" : "outline"}><Video className="h-4 w-4" /> Rejoindre</Button></a>
      )}
      {myResponse && !past && (
        <div className="flex gap-1">
          <Button size="icon-sm" variant={myResponse === "accepted" ? "success" : "outline"} disabled={pending} onClick={() => run(() => respondMeeting(meeting.id, "accepted"))} aria-label="Accepter"><Check className="h-4 w-4" /></Button>
          <Button size="icon-sm" variant={myResponse === "declined" ? "danger" : "outline"} disabled={pending} onClick={() => run(() => respondMeeting(meeting.id, "declined"))} aria-label="Décliner"><X className="h-4 w-4" /></Button>
        </div>
      )}
      {isOrganizer && (
        <div className="flex gap-1">
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild><Button size="sm" variant="ghost"><FileText className="h-4 w-4" /> Compte rendu</Button></DialogTrigger>
            <DialogContent title="Compte rendu" description={meeting.title}>
              <Textarea value={minutes} onChange={(e) => setMinutes(e.target.value)} rows={10} placeholder="Décisions, actions, responsables, échéances…" />
              <div className="mt-4 flex justify-end"><Button loading={pending} onClick={() => run(async () => { const r = await saveMinutes(meeting.id, minutes); if (r.ok) setOpen(false); return r; })}>Enregistrer</Button></div>
            </DialogContent>
          </Dialog>
          <Button size="icon-sm" variant="ghost" disabled={pending} aria-label="Supprimer" onClick={() => confirm("Supprimer cette réunion ?") && run(() => deleteMeeting(meeting.id))}><Trash2 className="h-4 w-4" /></Button>
        </div>
      )}
    </div>
  );
}
