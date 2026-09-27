"use client";

import { useCallback, useEffect, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  Ban, CalendarDays, Check, CheckCircle2, Clock, Link2, Loader2, MessageSquare, Plus, RotateCcw, Send, ShieldCheck,
  Trash2, X,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Sheet } from "@/components/ui/dialog";
import { Avatar } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input, Select, Textarea } from "@/components/ui/input";
import { priority as priorityLabels, taskStatus, TASK_COLUMNS } from "@/lib/labels";
import type { ProfileLite, Task } from "@/lib/types";
import { cn, dateTimeFr, relative } from "@/lib/utils";
import {
  addComment, addDependency, createTask, deleteTask, removeDependency, reviewTask, submitTaskForReview, updateTask,
  type TaskPatch,
} from "@/app/(app)/projets/actions";

type Comment = { id: string; body: string; created_at: string; author_id: string | null };
type Dep = { depends_on_id: string; task: { id: string; title: string; status: Task["status"] } | null };

export function TaskDrawer({
  taskId, onClose, people, siblings = [], assignableIds,
}: {
  taskId: string | null;
  onClose: () => void;
  people: ProfileLite[];
  siblings?: { id: string; title: string }[];
  /** Personnes a qui l'utilisateur peut confier une tache (lui-meme, son equipe). */
  assignableIds?: string[];
}) {
  const router = useRouter();
  const [task, setTask] = useState<Task | null>(null);
  const [comments, setComments] = useState<Comment[]>([]);
  const [deps, setDeps] = useState<Dep[]>([]);
  const [subtasks, setSubtasks] = useState<Task[]>([]);
  const [loading, setLoading] = useState(false);
  const [comment, setComment] = useState("");
  const [newSub, setNewSub] = useState("");
  const [depPick, setDepPick] = useState("");
  const [me, setMe] = useState<string | null>(null);
  const [reviewNote, setReviewNote] = useState("");
  const [pending, start] = useTransition();
  const pm = new Map(people.map((p) => [p.id, p]));
  const assignable = assignableIds ? people.filter((p) => assignableIds.includes(p.id)) : people;

  useEffect(() => {
    createClient().auth.getUser().then(({ data }) => setMe(data.user?.id ?? null));
  }, []);

  const load = useCallback(async (id: string) => {
    const supabase = createClient();
    const [t, c, d, s] = await Promise.all([
      supabase.from("tasks").select("*").eq("id", id).maybeSingle(),
      supabase.from("task_comments").select("*").eq("task_id", id).order("created_at"),
      supabase.from("task_dependencies").select("depends_on_id, task:tasks!task_dependencies_depends_on_id_fkey(id, title, status)").eq("task_id", id),
      supabase.from("tasks").select("*").eq("parent_id", id).order("position"),
    ]);
    setTask((t.data as Task) ?? null);
    setComments((c.data as Comment[]) ?? []);
    setDeps((d.data as unknown as Dep[]) ?? []);
    setSubtasks((s.data as Task[]) ?? []);
  }, []);

  useEffect(() => {
    if (!taskId) {
      setTask(null);
      return;
    }
    setLoading(true);
    load(taskId).finally(() => setLoading(false));
  }, [taskId, load]);

  function save(patch: TaskPatch) {
    if (!task) return;
    const prev = task;
    setTask({ ...task, ...patch } as Task);
    start(async () => {
      const r = await updateTask(task.id, patch, task.project_id);
      if (!r.ok) {
        setTask(prev);
        toast.error(r.error);
      } else {
        await load(task.id);
        router.refresh();
      }
    });
  }

  const blocked = deps.some((d) => d.task && d.task.status !== "done");
  const assignee = task?.assignee_id ? pm.get(task.assignee_id) : null;
  const reviewer = task ? task.reviewer_id ?? task.reporter_id : null;
  const isAssignee = Boolean(task && me && task.assignee_id === me);
  const isReviewer = Boolean(task && me && reviewer === me);
  const canSubmit = isAssignee && task?.status !== "done" && task?.status !== "review" && !blocked;
  const awaitingReview = task?.status === "review";

  function submit() {
    if (!task) return;
    start(async () => {
      const r = await submitTaskForReview(task.id, reviewNote || undefined, task.project_id);
      if (!r.ok) {
        toast.error(r.error);
        return;
      }
      toast.success(r.message);
      setReviewNote("");
      await load(task.id);
      router.refresh();
    });
  }

  function review(approve: boolean) {
    if (!task) return;
    if (!approve && reviewNote.trim().length < 3) {
      toast.error("Indiquez ce qui doit etre repris.");
      return;
    }
    start(async () => {
      const r = await reviewTask(task.id, approve, reviewNote || undefined, task.project_id);
      if (!r.ok) {
        toast.error(r.error);
        return;
      }
      toast.success(r.message);
      setReviewNote("");
      await load(task.id);
      router.refresh();
    });
  }

  return (
    <Sheet open={Boolean(taskId)} onOpenChange={(o) => !o && onClose()} title={task ? "Détail de la tâche" : "Chargement…"} width="max-w-2xl">
      {loading || !task ? (
        <div className="grid h-64 place-items-center"><Loader2 className="h-6 w-6 animate-spin text-subtle" /></div>
      ) : (
        <div className="space-y-6 p-6">
          <div>
            <input
              key={task.id + task.updated_at}
              defaultValue={task.title}
              onBlur={(e) => e.target.value.trim() && e.target.value !== task.title && save({ title: e.target.value.trim() })}
              className="w-full rounded-lg bg-transparent text-xl font-semibold tracking-tight text-fg outline-none focus:bg-surface-2 focus:px-2"
            />
            <div className="mt-2 flex flex-wrap items-center gap-2">
              {blocked && <Badge tone="red"><Ban className="h-3 w-3" /> Bloquée par une dépendance</Badge>}
              {task.requires_validation && (
                <Badge tone={task.validated_by ? "green" : "amber"}>
                  <ShieldCheck className="h-3 w-3" /> {task.validated_by ? `Validée par ${pm.get(task.validated_by)?.full_name ?? "—"}` : "Validation requise"}
                </Badge>
              )}
              {task.completed_at && <Badge tone="green"><CheckCircle2 className="h-3 w-3" /> Terminée {relative(task.completed_at)}</Badge>}
            </div>
          </div>

          {(canSubmit || awaitingReview) && (
            <div className="rounded-xl border border-border bg-surface-2/60 p-4">
              {awaitingReview ? (
                isReviewer ? (
                  <>
                    <p className="text-[13px] font-medium text-fg">
                      {assignee?.full_name ?? "La personne en charge"} a soumis cette tâche à votre vérification.
                    </p>
                    <Textarea
                      value={reviewNote}
                      onChange={(e) => setReviewNote(e.target.value)}
                      rows={2}
                      className="mt-2.5"
                      placeholder="Remarque, ou ce qui doit être repris en cas de renvoi…"
                    />
                    <div className="mt-2.5 flex flex-wrap gap-2">
                      <Button size="sm" variant="success" loading={pending} onClick={() => review(true)}>
                        <Check className="h-4 w-4" /> Valider la tâche
                      </Button>
                      <Button size="sm" variant="outline" loading={pending} onClick={() => review(false)}>
                        <RotateCcw className="h-4 w-4" /> Renvoyer pour correction
                      </Button>
                    </div>
                  </>
                ) : (
                  <p className="text-[13px] text-muted">
                    En attente de vérification par{" "}
                    <span className="font-medium text-fg">{(reviewer && pm.get(reviewer)?.full_name) ?? "le responsable"}</span>.
                  </p>
                )
              ) : (
                <>
                  <p className="text-[13px] font-medium text-fg">Travail terminé ?</p>
                  <p className="mt-0.5 text-xs text-muted">
                    {reviewer && reviewer !== me
                      ? `${pm.get(reviewer)?.full_name ?? "La personne qui vous l'a confiée"} vérifiera avant clôture.`
                      : "Cette tâche est la vôtre : la soumettre la termine directement."}
                  </p>
                  <Textarea
                    value={reviewNote}
                    onChange={(e) => setReviewNote(e.target.value)}
                    rows={2}
                    className="mt-2.5"
                    placeholder="Ce que vous avez livré, un lien, un chiffre… (facultatif)"
                  />
                  <Button size="sm" className="mt-2.5" loading={pending} onClick={submit}>
                    <Send className="h-4 w-4" /> Soumettre pour vérification
                  </Button>
                </>
              )}
            </div>
          )}

          {task.review_note && !awaitingReview && (
            <p className="rounded-xl bg-amber-500/10 px-4 py-3 text-[13px] text-fg">
              <span className="font-medium">Retour de vérification : </span>{task.review_note}
            </p>
          )}

          <div className="grid gap-x-6 gap-y-4 sm:grid-cols-2">
            <Prop label="Statut">
              <Select value={task.status} onChange={(e) => save({ status: e.target.value as Task["status"] })} disabled={pending}>
                {TASK_COLUMNS.map((s) => <option key={s} value={s}>{taskStatus[s].label}</option>)}
              </Select>
            </Prop>
            <Prop label="Priorité">
              <Select value={task.priority} onChange={(e) => save({ priority: e.target.value as Task["priority"] })}>
                {Object.entries(priorityLabels).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
              </Select>
            </Prop>
            <Prop label="Assignée à">
              <Select value={task.assignee_id ?? ""} onChange={(e) => save({ assignee_id: e.target.value || null })}>
                <option value="">— Non assignée —</option>
                {assignable.map((p) => <option key={p.id} value={p.id}>{p.full_name}</option>)}
                {task.assignee_id && !assignable.some((p) => p.id === task.assignee_id) && (
                  <option value={task.assignee_id}>{pm.get(task.assignee_id)?.full_name ?? "Personne assignée"}</option>
                )}
              </Select>
            </Prop>
            <Prop label="Échéance">
              <Input type="date" defaultValue={task.due_date ?? ""} key={"d" + task.due_date} onBlur={(e) => e.target.value !== (task.due_date ?? "") && save({ due_date: e.target.value || null })} />
            </Prop>
            <Prop label="Début">
              <Input type="date" defaultValue={task.start_date ?? ""} key={"s" + task.start_date} onBlur={(e) => e.target.value !== (task.start_date ?? "") && save({ start_date: e.target.value || null })} />
            </Prop>
            <Prop label="Estimation (heures)">
              <Input type="number" min={0} step={0.5} defaultValue={task.estimate_hours ?? ""} key={"e" + task.estimate_hours}
                onBlur={(e) => save({ estimate_hours: e.target.value === "" ? null : Number(e.target.value) })} />
            </Prop>
          </div>

          {task.project_id && (
            <label className="flex cursor-pointer items-center justify-between rounded-xl border border-border px-4 py-3">
              <span>
                <span className="block text-sm font-medium text-fg">Vérification avant clôture</span>
                <span className="block text-xs text-muted">La tâche passe « En revue » et n&apos;est close que par la personne qui l&apos;a confiée.</span>
              </span>
              <input type="checkbox" checked={task.requires_validation} onChange={(e) => save({ requires_validation: e.target.checked })} className="h-4 w-4 accent-[var(--primary)]" />
            </label>
          )}

          <div>
            <p className="mb-1.5 text-[13px] font-medium text-fg">Description</p>
            <Textarea key={"desc" + task.updated_at} defaultValue={task.description ?? ""} rows={5} placeholder="Contexte, critères d'acceptation, liens…"
              onBlur={(e) => e.target.value !== (task.description ?? "") && save({ description: e.target.value || null })} />
          </div>

          <div>
            <p className="mb-2 flex items-center gap-2 text-[13px] font-medium text-fg">
              Sous-tâches <span className="text-subtle">{subtasks.filter((s) => s.status === "done").length}/{subtasks.length}</span>
            </p>
            <ul className="space-y-1">
              {subtasks.map((s) => (
                <li key={s.id} className="flex items-center gap-2.5 rounded-lg px-2 py-1.5 hover:bg-surface-2/60">
                  <button
                    onClick={() => start(async () => {
                      const r = await updateTask(s.id, { status: s.status === "done" ? "todo" : "done" }, task.project_id);
                      if (!r.ok) toast.error(r.error);
                      await load(task.id);
                    })}
                    className={cn("grid h-[18px] w-[18px] place-items-center rounded border", s.status === "done" ? "border-emerald-500 bg-emerald-500 text-white" : "border-border")}
                  >
                    {s.status === "done" && <Check className="h-3 w-3" />}
                  </button>
                  <span className={cn("flex-1 text-sm", s.status === "done" ? "text-subtle line-through" : "text-fg")}>{s.title}</span>
                  {s.assignee_id && <Avatar name={pm.get(s.assignee_id)?.full_name} src={pm.get(s.assignee_id)?.avatar_url} size="xs" />}
                </li>
              ))}
            </ul>
            <form
              className="mt-2 flex gap-2"
              onSubmit={(e) => {
                e.preventDefault();
                if (!newSub.trim()) return;
                const fd = new FormData();
                fd.set("title", newSub);
                fd.set("parent_id", task.id);
                if (task.project_id) fd.set("project_id", task.project_id);
                if (task.assignee_id) fd.set("assignee_id", task.assignee_id);
                start(async () => {
                  const r = await createTask(null, fd);
                  if (!r.ok) toast.error(r.error);
                  setNewSub("");
                  await load(task.id);
                });
              }}
            >
              <Input value={newSub} onChange={(e) => setNewSub(e.target.value)} placeholder="Ajouter une sous-tâche…" />
              <Button type="submit" size="icon" variant="outline" aria-label="Ajouter"><Plus className="h-4 w-4" /></Button>
            </form>
          </div>

          {siblings.length > 0 && (
            <div>
              <p className="mb-2 flex items-center gap-2 text-[13px] font-medium text-fg"><Link2 className="h-4 w-4 text-subtle" /> Dépend de</p>
              <ul className="space-y-1">
                {deps.map((d) => (
                  <li key={d.depends_on_id} className="flex items-center gap-2 rounded-lg border border-border px-3 py-2 text-sm">
                    <span className={cn("h-2 w-2 rounded-full", d.task?.status === "done" ? "bg-emerald-500" : "bg-amber-500")} />
                    <span className="flex-1 truncate text-fg">{d.task?.title ?? "Tâche inaccessible"}</span>
                    <span className="text-xs text-subtle">{d.task ? taskStatus[d.task.status].label : ""}</span>
                    <button onClick={() => start(async () => { await removeDependency(task.id, d.depends_on_id, task.project_id); await load(task.id); })} className="text-subtle hover:text-danger" aria-label="Retirer"><X className="h-4 w-4" /></button>
                  </li>
                ))}
              </ul>
              <div className="mt-2 flex gap-2">
                <Select value={depPick} onChange={(e) => setDepPick(e.target.value)}>
                  <option value="">Choisir une tâche prérequise…</option>
                  {siblings.filter((s) => s.id !== task.id && !deps.some((d) => d.depends_on_id === s.id)).map((s) => <option key={s.id} value={s.id}>{s.title}</option>)}
                </Select>
                <Button variant="outline" disabled={!depPick} onClick={() => start(async () => {
                  const r = await addDependency(task.id, depPick, task.project_id);
                  if (!r.ok) toast.error(r.error);
                  setDepPick("");
                  await load(task.id);
                })}>Lier</Button>
              </div>
            </div>
          )}

          <div>
            <p className="mb-3 flex items-center gap-2 text-[13px] font-medium text-fg"><MessageSquare className="h-4 w-4 text-subtle" /> Discussion</p>
            <ul className="space-y-4">
              {comments.map((c) => {
                const a = c.author_id ? pm.get(c.author_id) : null;
                return (
                  <li key={c.id} className="flex gap-3">
                    <Avatar name={a?.full_name} src={a?.avatar_url} size="sm" />
                    <div className="min-w-0 flex-1 rounded-xl bg-surface-2/70 px-3.5 py-2.5">
                      <p className="text-xs"><span className="font-medium text-fg">{a?.full_name ?? "Ancien membre"}</span> <span className="text-subtle">· {relative(c.created_at)}</span></p>
                      <p className="mt-1 whitespace-pre-wrap text-sm text-fg">{c.body}</p>
                    </div>
                  </li>
                );
              })}
            </ul>
            <form className="mt-3 flex gap-2" onSubmit={(e) => {
              e.preventDefault();
              start(async () => {
                const r = await addComment(task.id, comment);
                if (!r.ok) { toast.error(r.error); return; }
                setComment("");
                await load(task.id);
              });
            }}>
              <Input value={comment} onChange={(e) => setComment(e.target.value)} placeholder="Écrire un commentaire…" />
              <Button type="submit" disabled={!comment.trim()} loading={pending}>Envoyer</Button>
            </form>
          </div>

          <div className="flex flex-wrap items-center justify-between gap-3 border-t border-border pt-4 text-xs text-subtle">
            <span className="flex items-center gap-3">
              <span className="flex items-center gap-1"><Clock className="h-3.5 w-3.5" /> Créée {dateTimeFr(task.created_at)}</span>
              {assignee && <span className="flex items-center gap-1"><CalendarDays className="h-3.5 w-3.5" /> MAJ {relative(task.updated_at)}</span>}
            </span>
            <Button size="sm" variant="ghost" className="text-danger hover:bg-danger/10 hover:text-danger" onClick={() => {
              if (!confirm("Supprimer définitivement cette tâche ?")) return;
              start(async () => {
                const r = await deleteTask(task.id, task.project_id);
                if (!r.ok) { toast.error(r.error); return; }
                toast.success(r.message);
                onClose();
                router.refresh();
              });
            }}>
              <Trash2 className="h-4 w-4" /> Supprimer
            </Button>
          </div>
        </div>
      )}
    </Sheet>
  );
}

function Prop({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <p className="mb-1.5 text-xs font-medium text-muted">{label}</p>
      {children}
    </div>
  );
}
