"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Pencil, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { ActionForm } from "@/components/ui/action-form";
import { Field, Input, Select, Textarea } from "@/components/ui/input";
import { PersonSelect, UnitSelect } from "@/components/pickers";
import { priority, projectStatus } from "@/lib/labels";
import type { Project, ProfileLite } from "@/lib/types";
import { cn } from "@/lib/utils";
import { createProject, updateProject } from "./actions";

const COLORS = ["#4F46E5", "#7C3AED", "#DB2777", "#EA580C", "#D97706", "#059669", "#0E7490", "#0284C7", "#0B1F3A"];

export function ProjectFormButton({ units, project, people }: { units: { id: string; label: string }[]; project?: Project; people?: ProfileLite[] }) {
  const [open, setOpen] = useState(false);
  const [color, setColor] = useState(project?.color ?? COLORS[0]);
  const router = useRouter();
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        {project ? <Button size="sm" variant="outline"><Pencil className="h-4 w-4" /> Modifier</Button> : <Button size="sm"><Plus className="h-4 w-4" /> Nouveau projet</Button>}
      </DialogTrigger>
      <DialogContent title={project ? "Modifier le projet" : "Nouveau projet"} size="lg">
        <ActionForm
          action={project ? updateProject : createProject}
          submitLabel={project ? "Enregistrer" : "Créer le projet"}
          resetOnSuccess={!project}
          onSuccess={(r) => {
            setOpen(false);
            const id = r.ok && (r.data as { id?: string } | undefined)?.id;
            if (id) router.push(`/projets/${id}`);
          }}
        >
          {project && <input type="hidden" name="id" value={project.id} />}
          <input type="hidden" name="color" value={color} />
          <Field label="Nom du projet" htmlFor="name" required><Input id="name" name="name" required defaultValue={project?.name} /></Field>
          <Field label="Description" htmlFor="description"><Textarea id="description" name="description" rows={3} defaultValue={project?.description ?? ""} /></Field>
          <div className="grid gap-4 sm:grid-cols-3">
            <Field label="Statut" htmlFor="status">
              <Select id="status" name="status" defaultValue={project?.status ?? "planned"}>
                {Object.entries(projectStatus).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
              </Select>
            </Field>
            <Field label="Priorité" htmlFor="priority">
              <Select id="priority" name="priority" defaultValue={project?.priority ?? "medium"}>
                {Object.entries(priority).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
              </Select>
            </Field>
            <Field label="Budget (FCFA)" htmlFor="budget"><Input id="budget" name="budget" inputMode="numeric" defaultValue={project?.budget ?? ""} /></Field>
            <Field label="Début" htmlFor="start_date"><Input id="start_date" name="start_date" type="date" defaultValue={project?.start_date ?? ""} /></Field>
            <Field label="Échéance" htmlFor="due_date"><Input id="due_date" name="due_date" type="date" defaultValue={project?.due_date ?? ""} /></Field>
            <Field label="Unité" htmlFor="unit_id"><UnitSelect units={units} name="unit_id" defaultValue={project?.unit_id} placeholder="— Transverse —" /></Field>
          </div>
          {project && people && (
            <Field label="Responsable du projet" htmlFor="owner_id"><PersonSelect people={people} name="owner_id" defaultValue={project.owner_id} required /></Field>
          )}
          <Field label="Couleur">
            <div className="flex flex-wrap gap-2">
              {COLORS.map((c) => (
                <button key={c} type="button" onClick={() => setColor(c)} className={cn("h-7 w-7 rounded-full ring-offset-2 ring-offset-surface", color === c && "ring-2 ring-fg/60")} style={{ background: c }} aria-label={c} />
              ))}
            </div>
          </Field>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}
