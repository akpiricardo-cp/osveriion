"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { FolderKanban, UserPlus2 } from "lucide-react";
import { Avatar } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Card, CardHeader } from "@/components/ui/card";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { ActionForm } from "@/components/ui/action-form";
import { Field, Input, Select } from "@/components/ui/input";
import { EmptyState } from "@/components/ui/misc";
import { cn } from "@/lib/utils";
import type { ProfileLite } from "@/lib/types";
import { setLiaison } from "./actions";

export interface CoordProject {
  id: string;
  name: string;
  code: string;
  color: string;
  status: string;
  lead_id: string | null;
}
export interface CoordUnit {
  id: string;
  name: string;
  code: string | null;
  color: string;
  head_title: string | null;
}
export interface Liaison {
  project_id: string;
  unit_id: string;
  profile_id: string;
  note: string | null;
}

/**
 * Qui parle à qui. Chaque projet a son Chief Product ; chaque département lui
 * désigne un référent. C'est ce tableau qui rend la coordination lisible :
 * une case vide est une fonction qui ne suit pas le projet.
 */
export function Coordination({
  projects, departments, liaisons, people, manageableUnits,
}: {
  projects: CoordProject[];
  departments: CoordUnit[];
  liaisons: Liaison[];
  people: ProfileLite[];
  manageableUnits: string[];
}) {
  const router = useRouter();
  const [target, setTarget] = useState<{ project: CoordProject; unit: CoordUnit; current?: Liaison } | null>(null);
  const pm = new Map(people.map((p) => [p.id, p]));
  const canManage = new Set(manageableUnits);

  if (projects.length === 0) {
    return (
      <Card>
        <EmptyState
          icon={FolderKanban}
          title="Aucun projet"
          description="La holding pilote ses produits sous forme de projets. Créez-en un pour lui nommer un Chief Product et lui affecter des référents."
          action={<Link href="/projets" className="text-sm font-medium text-primary hover:underline">Ouvrir les projets</Link>}
        />
      </Card>
    );
  }

  return (
    <>
      <div className="space-y-4">
        {projects.map((project) => {
          const lead = project.lead_id ? pm.get(project.lead_id) : null;
          const covered = departments.filter((d) => liaisons.some((l) => l.project_id === project.id && l.unit_id === d.id)).length;
          return (
            <Card key={project.id}>
              <CardHeader
                title={
                  <Link href={`/projets/${project.id}`} className="hover:underline">
                    <span className="inline-flex items-center gap-2">
                      <span className="h-2.5 w-2.5 rounded-full" style={{ background: project.color }} />
                      {project.name}
                    </span>
                  </Link>
                }
                description={lead ? `Chief Product : ${lead.full_name}` : "Chief Product à nommer"}
                action={
                  <Badge tone={covered === departments.length ? "green" : covered ? "amber" : "red"} dot>
                    {covered} / {departments.length} départements
                  </Badge>
                }
              />
              <div className="grid gap-2 p-5 pt-4 sm:grid-cols-2 xl:grid-cols-4">
                {departments.map((unit) => {
                  const liaison = liaisons.find((l) => l.project_id === project.id && l.unit_id === unit.id);
                  const person = liaison ? pm.get(liaison.profile_id) : null;
                  const editable = canManage.has(unit.id);
                  return (
                    <button
                      key={unit.id}
                      type="button"
                      disabled={!editable}
                      onClick={() => setTarget({ project, unit, current: liaison })}
                      className={cn(
                        "flex items-center gap-2.5 rounded-xl border p-2.5 text-left transition",
                        person ? "border-border bg-surface-2/50" : "border-dashed border-border",
                        editable ? "hover:border-primary/40 hover:bg-surface-2" : "cursor-default opacity-90",
                      )}
                    >
                      <span className="h-8 w-1 shrink-0 rounded-full" style={{ background: unit.color }} />
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-[11px] font-medium uppercase tracking-wide text-subtle">{unit.code ?? unit.name}</p>
                        {person ? (
                          <span className="mt-0.5 flex min-w-0 items-center gap-1.5">
                            <Avatar name={person.full_name} src={person.avatar_url} size="xs" />
                            <span className="truncate text-[13px] font-medium text-fg">{person.full_name}</span>
                          </span>
                        ) : (
                          <span className="mt-0.5 flex items-center gap-1 text-[13px] italic text-subtle">
                            <UserPlus2 className="h-3.5 w-3.5" /> À désigner
                          </span>
                        )}
                      </div>
                    </button>
                  );
                })}
              </div>
            </Card>
          );
        })}
      </div>

      <Dialog open={!!target} onOpenChange={(o) => !o && setTarget(null)}>
        {target && (
          <DialogContent
            title={`Référent ${target.unit.name}`}
            description={`Point de contact direct du chef de projet « ${target.project.name} » pour cette fonction. Il rejoint le canal du projet.`}
          >
            <ActionForm
              action={setLiaison}
              submitLabel="Désigner"
              onSuccess={() => { setTarget(null); router.refresh(); }}
            >
              <input type="hidden" name="project_id" value={target.project.id} />
              <input type="hidden" name="unit_id" value={target.unit.id} />
              <Field label="Personne" htmlFor="profile_id" hint="Laissez vide pour retirer le référent actuel.">
                <Select id="profile_id" name="profile_id" defaultValue={target.current?.profile_id ?? ""}>
                  <option value="">— Aucun référent</option>
                  {people.map((p) => (
                    <option key={p.id} value={p.id}>{p.full_name}{p.job_title ? ` — ${p.job_title}` : ""}</option>
                  ))}
                </Select>
              </Field>
              <Field label="Périmètre confié" htmlFor="note" hint="Facultatif : ce que ce département suit sur ce projet.">
                <Input id="note" name="note" defaultValue={target.current?.note ?? ""} placeholder="Suivi budgétaire mensuel et validation des dépenses" />
              </Field>
            </ActionForm>
          </DialogContent>
        )}
      </Dialog>
    </>
  );
}
