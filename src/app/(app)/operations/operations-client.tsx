"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { CalendarRange, Check, ClipboardCheck, ListPlus, MoreHorizontal, Plus, Send, Target, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { Avatar } from "@/components/ui/avatar";
import { Badge, LabelBadge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardHeader } from "@/components/ui/card";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { Dropdown, DropdownContent, DropdownItem, DropdownSeparator, DropdownTrigger } from "@/components/ui/dropdown";
import { ActionForm } from "@/components/ui/action-form";
import { Field, Input, Select, Textarea } from "@/components/ui/input";
import { EmptyState, Progress } from "@/components/ui/misc";
import { cycleStatus, opsItemStatus } from "@/lib/labels";
import { dateFr, dateTimeFr, relative } from "@/lib/utils";
import type { OperationCycle, OperationItem, OperationReport, ProfileLite } from "@/lib/types";
import {
  acknowledgeReport, deleteCycle, deleteItem, publishCycle, saveCycle, saveItem, setItemStatus, submitReport,
} from "./actions";

type ActionRun = () => Promise<{ ok: boolean; message?: string; error?: string }>;

function useRun() {
  const router = useRouter();
  const [pending, start] = useTransition();
  const run = (fn: ActionRun, confirmMsg?: string) => {
    if (confirmMsg && !confirm(confirmMsg)) return;
    start(async () => {
      const r = await fn();
      if (r.ok) { toast.success(r.message); router.refresh(); } else toast.error(r.error);
    });
  };
  return { pending, run, router };
}

/** Création d'un cycle : mensuel, hebdomadaire ou journalier. */
export function CycleDialog({
  projects, defaultProject, cycle, trigger,
}: {
  projects: { id: string; name: string }[];
  defaultProject?: string;
  cycle?: OperationCycle;
  trigger?: React.ReactNode;
}) {
  const [open, setOpen] = useState(false);
  const router = useRouter();
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        {trigger ?? <Button size="sm"><Plus className="h-4 w-4" /> Nouveau cycle</Button>}
      </DialogTrigger>
      <DialogContent
        title={cycle ? "Modifier le cycle" : "Écrire un calendrier"}
        description="Le cycle mensuel donne le cap et passe par l'accord du CEO. L'hebdomadaire et le journalier se publient directement."
      >
        <ActionForm action={saveCycle} submitLabel={cycle ? "Enregistrer" : "Créer le cycle"} onSuccess={() => { setOpen(false); router.refresh(); }}>
          {cycle && <input type="hidden" name="id" value={cycle.id} />}
          <Field label="Projet" htmlFor="project_id" required>
            <Select id="project_id" name="project_id" required defaultValue={cycle?.project_id ?? defaultProject ?? ""}>
              <option value="" disabled>Choisir un projet</option>
              {projects.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
            </Select>
          </Field>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Rythme" htmlFor="kind" required>
              <Select id="kind" name="kind" defaultValue={cycle?.kind ?? "monthly"}>
                <option value="monthly">Mensuel — le cap du mois</option>
                <option value="weekly">Hebdomadaire — la semaine</option>
                <option value="daily">Journalier — la journée</option>
              </Select>
            </Field>
            <Field label="Début de la période" htmlFor="period_start" required>
              <Input id="period_start" name="period_start" type="date" required defaultValue={cycle?.period_start ?? new Date().toISOString().slice(0, 10)} />
            </Field>
          </div>
          <Field label="Intitulé" htmlFor="title" required hint="Ce que l'équipe verra en tête du calendrier.">
            <Input id="title" name="title" required defaultValue={cycle?.title} placeholder="Octobre — ouverture de la bêta publique" />
          </Field>
          <Field label="Cap du cycle" htmlFor="focus" hint="En une phrase : ce qui compte vraiment sur la période.">
            <Textarea id="focus" name="focus" rows={2} defaultValue={cycle?.focus ?? ""} />
          </Field>
          <Field label="Fin de période" htmlFor="period_end" hint="Laissez vide : déduite du rythme choisi.">
            <Input id="period_end" name="period_end" type="date" defaultValue={cycle?.period_end ?? ""} />
          </Field>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

/** Ajout ou modification d'une grande ligne du cycle. */
function ItemDialog({
  cycleId, item, people, trigger,
}: { cycleId: string; item?: OperationItem; people: ProfileLite[]; trigger: React.ReactNode }) {
  const [open, setOpen] = useState(false);
  const router = useRouter();
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>{trigger}</DialogTrigger>
      <DialogContent
        title={item ? "Modifier la grande ligne" : "Ajouter une grande ligne"}
        description="Ce que les Opérations attendent du projet. Le chef de projet la découpera en tâches pour son équipe."
      >
        <ActionForm action={saveItem} submitLabel={item ? "Enregistrer" : "Ajouter"} onSuccess={() => { setOpen(false); router.refresh(); }}>
          <input type="hidden" name="cycle_id" value={cycleId} />
          {item && <input type="hidden" name="id" value={item.id} />}
          <Field label="Intitulé" htmlFor="title" required>
            <Input id="title" name="title" required defaultValue={item?.title} placeholder="Ouvrir l'inscription aux 500 premiers utilisateurs" />
          </Field>
          <Field label="Précisions" htmlFor="detail">
            <Textarea id="detail" name="detail" rows={3} defaultValue={item?.detail ?? ""} />
          </Field>
          <Field label="Résultat attendu" htmlFor="expected_outcome" hint="Vérifiable : un chiffre, un livrable, un état.">
            <Input id="expected_outcome" name="expected_outcome" defaultValue={item?.expected_outcome ?? ""} placeholder="500 comptes créés, 0 incident bloquant" />
          </Field>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Responsable pressenti" htmlFor="owner_id">
              <Select id="owner_id" name="owner_id" defaultValue={item?.owner_id ?? ""}>
                <option value="">— Le chef de projet décide</option>
                {people.map((p) => <option key={p.id} value={p.id}>{p.full_name}</option>)}
              </Select>
            </Field>
            <Field label="Échéance" htmlFor="due_date">
              <Input id="due_date" name="due_date" type="date" defaultValue={item?.due_date ?? ""} />
            </Field>
          </div>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function CycleCard({
  cycle, items, projectName, people, canPlan, subtitle, footer,
}: {
  cycle: OperationCycle;
  items: OperationItem[];
  projectName: string;
  people: ProfileLite[];
  canPlan: boolean;
  subtitle: string;
  footer?: React.ReactNode;
}) {
  const { pending, run } = useRun();
  const pm = new Map(people.map((p) => [p.id, p]));
  const done = items.filter((i) => i.status === "done").length;
  const sorted = [...items].sort((a, b) => a.position - b.position);

  return (
    <Card>
      <CardHeader
        title={cycle.title}
        description={`${projectName} · ${subtitle}`}
        icon={<CalendarRange className="h-4 w-4" />}
        action={
          <div className="flex items-center gap-2">
            <LabelBadge map={cycleStatus} value={cycle.status} />
            {canPlan && (
              <Dropdown>
                <DropdownTrigger disabled={pending} className="rounded-md p-1.5 text-subtle hover:bg-surface-2 hover:text-fg" aria-label="Actions du cycle">
                  <MoreHorizontal className="h-4 w-4" />
                </DropdownTrigger>
                <DropdownContent>
                  <ItemDialog
                    cycleId={cycle.id}
                    people={people}
                    trigger={<DropdownItem onSelect={(e) => e.preventDefault()}><ListPlus className="h-4 w-4 text-subtle" /> Ajouter une grande ligne</DropdownItem>}
                  />
                  {cycle.status !== "published" && (
                    <DropdownItem onSelect={() => run(() => publishCycle(cycle.id))}>
                      <Send className="h-4 w-4 text-subtle" /> Publier le calendrier
                    </DropdownItem>
                  )}
                  {cycle.status !== "published" && (
                    <>
                      <DropdownSeparator />
                      <DropdownItem danger onSelect={() => run(() => deleteCycle(cycle.id), "Supprimer ce cycle et ses grandes lignes ?")}>
                        <Trash2 className="h-4 w-4" /> Supprimer
                      </DropdownItem>
                    </>
                  )}
                </DropdownContent>
              </Dropdown>
            )}
          </div>
        }
      />

      {cycle.focus && <p className="px-5 pt-3 text-sm leading-relaxed text-muted">{cycle.focus}</p>}

      {items.length > 0 && (
        <div className="px-5 pt-4">
          <div className="mb-1.5 flex items-center justify-between text-xs text-subtle">
            <span>{done} / {items.length} grandes lignes atteintes</span>
            <span>{items.length ? Math.round((done / items.length) * 100) : 0} %</span>
          </div>
          <Progress value={items.length ? (done / items.length) * 100 : 0} />
        </div>
      )}

      <div className="mt-3">
        {sorted.length === 0 ? (
          <EmptyState
            icon={Target}
            title="Aucune grande ligne"
            description="Un calendrier vide ne se publie pas : listez ce qui est attendu du projet sur la période."
            action={canPlan ? (
              <ItemDialog cycleId={cycle.id} people={people} trigger={<Button size="sm" variant="outline"><Plus className="h-4 w-4" /> Ajouter</Button>} />
            ) : undefined}
          />
        ) : (
          <ul className="divide-y divide-border">
            {sorted.map((item) => {
              const owner = item.owner_id ? pm.get(item.owner_id) : null;
              return (
                <li key={item.id} className="flex items-start gap-3 px-5 py-3">
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <p className="text-sm font-medium text-fg">{item.title}</p>
                      <LabelBadge map={opsItemStatus} value={item.status} />
                    </div>
                    {item.detail && <p className="mt-1 text-[13px] leading-relaxed text-muted">{item.detail}</p>}
                    <div className="mt-1.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-subtle">
                      {item.expected_outcome && <span className="inline-flex items-center gap-1"><Target className="h-3 w-3" /> {item.expected_outcome}</span>}
                      {owner && (
                        <span className="inline-flex items-center gap-1.5">
                          <Avatar name={owner.full_name} src={owner.avatar_url} size="xs" /> {owner.full_name}
                        </span>
                      )}
                      {item.due_date && <span>Pour le {dateFr(item.due_date)}</span>}
                    </div>
                  </div>
                  {canPlan && (
                    <Dropdown>
                      <DropdownTrigger disabled={pending} className="rounded-md p-1.5 text-subtle hover:bg-surface-2 hover:text-fg" aria-label="Actions">
                        <MoreHorizontal className="h-4 w-4" />
                      </DropdownTrigger>
                      <DropdownContent>
                        <ItemDialog
                          cycleId={cycle.id}
                          item={item}
                          people={people}
                          trigger={<DropdownItem onSelect={(e) => e.preventDefault()}>Modifier</DropdownItem>}
                        />
                        <DropdownItem onSelect={() => run(() => setItemStatus(item.id, "in_progress"))}>Marquer en cours</DropdownItem>
                        <DropdownItem onSelect={() => run(() => setItemStatus(item.id, "done"))}>Marquer atteinte</DropdownItem>
                        <DropdownItem onSelect={() => run(() => setItemStatus(item.id, "dropped"))}>Abandonner</DropdownItem>
                        <DropdownSeparator />
                        <DropdownItem danger onSelect={() => run(() => deleteItem(item.id), "Retirer cette grande ligne ?")}>
                          <Trash2 className="h-4 w-4" /> Retirer
                        </DropdownItem>
                      </DropdownContent>
                    </Dropdown>
                  )}
                </li>
              );
            })}
          </ul>
        )}
      </div>
      {footer && <div className="border-t border-border px-5 py-3">{footer}</div>}
    </Card>
  );
}

/** Rapport de fin de cycle, rédigé par le chef de projet. */
export function ReportDialog({
  cycleId, projectId, cycleTitle, trigger,
}: { cycleId: string; projectId: string; cycleTitle: string; trigger?: React.ReactNode }) {
  const [open, setOpen] = useState(false);
  const router = useRouter();
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        {trigger ?? <Button size="sm" variant="outline"><Send className="h-4 w-4" /> Rendre compte</Button>}
      </DialogTrigger>
      <DialogContent title="Rapport de cycle" description={`${cycleTitle} — transmis au département des Opérations.`}>
        <ActionForm action={submitReport} submitLabel="Transmettre le rapport" onSuccess={() => { setOpen(false); router.refresh(); }}>
          <input type="hidden" name="cycle_id" value={cycleId} />
          <input type="hidden" name="project_id" value={projectId} />
          <Field label="Avancement" htmlFor="progress" required hint="Part du cap atteinte, en pourcentage.">
            <Input id="progress" name="progress" type="number" min={0} max={100} defaultValue={0} required />
          </Field>
          <Field label="Ce qui a été fait" htmlFor="summary" required>
            <Textarea id="summary" name="summary" rows={4} required placeholder="Les livrables sortis, les décisions prises, les chiffres du cycle." />
          </Field>
          <Field label="Points de blocage" htmlFor="blockers" hint="Ce qui ralentit et demande un arbitrage.">
            <Textarea id="blockers" name="blockers" rows={2} />
          </Field>
          <Field label="Prochaines étapes" htmlFor="next_steps">
            <Textarea id="next_steps" name="next_steps" rows={2} />
          </Field>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function ReportList({
  reports, projects, cycles, people, canAcknowledge,
}: {
  reports: OperationReport[];
  projects: Record<string, string>;
  cycles: Record<string, string>;
  people: Record<string, ProfileLite>;
  canAcknowledge: boolean;
}) {
  const { pending, run } = useRun();

  if (reports.length === 0) {
    return (
      <Card>
        <EmptyState icon={ClipboardCheck} title="Aucun rapport" description="Les comptes rendus des chefs de projet arriveront ici à la clôture de chaque cycle." />
      </Card>
    );
  }

  return (
    <ul className="space-y-3">
      {reports.map((r) => {
        const author = r.author_id ? people[r.author_id] : null;
        return (
          <li key={r.id}>
            <Card className="p-4 sm:p-5">
              <div className="flex flex-wrap items-center gap-2">
                <Badge tone="violet">{projects[r.project_id] ?? "Projet"}</Badge>
                <span className="text-sm font-medium text-fg">{cycles[r.cycle_id] ?? "Cycle"}</span>
                {r.status === "acknowledged"
                  ? <Badge tone="green" dot>Pris en compte</Badge>
                  : <Badge tone="amber" dot>À traiter</Badge>}
                <span className="text-xs text-subtle">{relative(r.submitted_at ?? r.created_at)}</span>
              </div>

              <div className="mt-3 max-w-xs">
                <div className="mb-1 flex items-center justify-between text-xs text-subtle">
                  <span>Avancement</span><span>{r.progress} %</span>
                </div>
                <Progress value={r.progress} />
              </div>

              <p className="mt-3 whitespace-pre-line text-sm leading-relaxed text-fg">{r.summary}</p>
              {r.blockers && (
                <p className="mt-2 rounded-lg bg-amber-500/10 px-3 py-2 text-[13px] text-fg">
                  <span className="font-medium">Blocages : </span>{r.blockers}
                </p>
              )}
              {r.next_steps && (
                <p className="mt-2 text-[13px] text-muted"><span className="font-medium text-fg">Suite : </span>{r.next_steps}</p>
              )}

              <div className="mt-3 flex flex-wrap items-center justify-between gap-3 text-xs text-subtle">
                <span className="inline-flex items-center gap-1.5">
                  <Avatar name={author?.full_name ?? "—"} src={author?.avatar_url} size="xs" />
                  {author?.full_name ?? "Chef de projet"}
                </span>
                {r.status === "submitted" && canAcknowledge ? (
                  <Button size="sm" variant="outline" loading={pending} onClick={() => run(() => acknowledgeReport(r.id))}>
                    <Check className="h-4 w-4" /> Accuser réception
                  </Button>
                ) : r.reviewed_at ? (
                  <span>Traité le {dateTimeFr(r.reviewed_at)}</span>
                ) : null}
              </div>
              {r.review_note && <p className="mt-2 rounded-lg bg-surface-2 px-3 py-2 text-[13px] text-fg">{r.review_note}</p>}
            </Card>
          </li>
        );
      })}
    </ul>
  );
}
