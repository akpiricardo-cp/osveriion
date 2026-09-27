"use client";

import { useMemo, useState, useTransition } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Check, CheckCircle2, Plus } from "lucide-react";
import { toast } from "sonner";
import { Avatar } from "@/components/ui/avatar";
import { LabelBadge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input, Select } from "@/components/ui/input";
import { EmptyState } from "@/components/ui/misc";
import { TaskDrawer } from "@/components/tasks/task-drawer";
import { priority, taskStatus } from "@/lib/labels";
import type { ProfileLite, Task } from "@/lib/types";
import { cn, dateFr, todayISO } from "@/lib/utils";
import { createTask, submitTaskForReview, updateTask } from "../projets/actions";

type Row = Task & { projects: { name: string; color: string } | null };

function bucket(t: Row) {
  if (t.status === "done") return "Terminées";
  if (!t.due_date) return "Sans échéance";
  const today = todayISO();
  if (t.due_date < today) return "En retard";
  if (t.due_date === today) return "Aujourd'hui";
  const week = new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 10);
  return t.due_date <= week ? "Cette semaine" : "Plus tard";
}
const ORDER = ["En retard", "Aujourd'hui", "Cette semaine", "Plus tard", "Sans échéance", "Terminées"];

export function MyTasks({ tasks, people, mode }: { tasks: Row[]; people: ProfileLite[]; mode: string }) {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const [title, setTitle] = useState("");
  const [due, setDue] = useState("");
  const [prio, setPrio] = useState("medium");
  const [pending, start] = useTransition();
  const [done, setDone] = useState<Set<string>>(new Set());
  const pm = new Map(people.map((p) => [p.id, p]));
  const openId = params.get("tache");

  const groups = useMemo(() => {
    const g = new Map<string, Row[]>();
    tasks.forEach((t) => {
      const b = bucket(t);
      if (!g.has(b)) g.set(b, []);
      g.get(b)!.push(t);
    });
    return ORDER.filter((k) => g.has(k)).map((k) => [k, g.get(k)!] as const);
  }, [tasks]);

  const open = (id: string | null) => {
    const sp = new URLSearchParams(params.toString());
    if (id) sp.set("tache", id); else sp.delete("tache");
    router.replace(`${pathname}?${sp}`, { scroll: false });
  };

  return (
    <div className="space-y-6">
      {mode === "assignees" && (
        <form
          className="flex flex-col gap-2 rounded-2xl border border-border bg-surface p-3 shadow-card sm:flex-row"
          onSubmit={(e) => {
            e.preventDefault();
            if (!title.trim()) return;
            const fd = new FormData();
            fd.set("title", title);
            fd.set("priority", prio);
            if (due) fd.set("due_date", due);
            start(async () => {
              const r = await createTask(null, fd);
              if (!r.ok) { toast.error(r.error); return; }
              setTitle(""); setDue("");
              router.refresh();
            });
          }}
        >
          <Input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Nouvelle tâche personnelle…" className="flex-1" />
          <Input type="date" value={due} onChange={(e) => setDue(e.target.value)} className="sm:w-40" />
          <div className="sm:w-36">
            <Select value={prio} onChange={(e) => setPrio(e.target.value)}>
              {Object.entries(priority).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
            </Select>
          </div>
          <Button type="submit" loading={pending}><Plus className="h-4 w-4" /> Ajouter</Button>
        </form>
      )}

      {tasks.length === 0 && <EmptyState icon={CheckCircle2} title="Aucune tâche" description="Rien à afficher dans cette vue." />}

      {groups.map(([label, rows]) => (
        <section key={label}>
          <h2 className={cn("mb-2 flex items-center gap-2 text-sm font-semibold", label === "En retard" ? "text-danger" : "text-fg")}>
            {label} <span className="rounded-full bg-surface-3 px-2 text-xs font-medium text-muted">{rows.length}</span>
          </h2>
          <ul className="divide-y divide-border overflow-hidden rounded-2xl border border-border bg-surface shadow-card">
            {rows.map((t) => {
              const isDone = t.status === "done" || done.has(t.id);
              const a = pm.get(t.assignee_id ?? "");
              return (
                <li key={t.id} className="flex items-center gap-3 px-4 py-3 transition hover:bg-surface-2/50">
                  <button
                    aria-label={t.requires_validation && t.status !== "done" ? "Soumettre à vérification" : "Terminer"}
                    title={t.requires_validation && t.status !== "done" ? "Soumettre à vérification" : "Terminer"}
                    onClick={() => start(async () => {
                      setDone((s) => new Set(s).add(t.id));
                      // Une tâche confiée par quelqu'un d'autre ne se clot pas seule : elle se soumet.
                      const r = t.requires_validation && t.status !== "done"
                        ? await submitTaskForReview(t.id, undefined, t.project_id)
                        : await updateTask(t.id, { status: t.status === "done" ? "todo" : "done" }, t.project_id);
                      if (!r.ok) {
                        setDone((s) => { const n = new Set(s); n.delete(t.id); return n; });
                        toast.error(r.error);
                      } else {
                        if (r.message) toast.success(r.message);
                        router.refresh();
                      }
                    })}
                    className={cn("grid h-5 w-5 shrink-0 place-items-center rounded-full border-2 transition", isDone ? "border-emerald-500 bg-emerald-500 text-white" : "border-border hover:border-emerald-500")}
                  >
                    {isDone && <Check className="h-3 w-3" />}
                  </button>
                  <button onClick={() => open(t.id)} className="min-w-0 flex-1 text-left">
                    <p className={cn("truncate text-sm font-medium", isDone ? "text-subtle line-through" : "text-fg")}>{t.title}</p>
                    <p className="flex items-center gap-1.5 truncate text-xs text-subtle">
                      <span className="h-1.5 w-1.5 rounded-full" style={{ background: t.projects?.color ?? "var(--subtle)" }} />
                      {t.projects?.name ?? "Tâche personnelle"}
                    </p>
                  </button>
                  <LabelBadge map={taskStatus} value={t.status} />
                  {(t.priority === "high" || t.priority === "urgent") && <LabelBadge map={priority} value={t.priority} />}
                  {mode === "creees" && a && <Avatar name={a.full_name} src={a.avatar_url} size="xs" />}
                  <span className="hidden w-20 text-right text-xs text-muted sm:block">{t.due_date ? dateFr(t.due_date, "d MMM") : ""}</span>
                </li>
              );
            })}
          </ul>
        </section>
      ))}

      <TaskDrawer taskId={openId} onClose={() => open(null)} people={people} />
    </div>
  );
}
