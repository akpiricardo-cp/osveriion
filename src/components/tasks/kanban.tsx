"use client";

import { useEffect, useMemo, useState, useTransition } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import {
  DndContext, DragOverlay, PointerSensor, TouchSensor, useDraggable, useDroppable, useSensor, useSensors,
  type DragEndEvent, type DragStartEvent,
} from "@dnd-kit/core";
import { toast } from "sonner";
import { AlarmClock, Ban, CheckSquare, LayoutGrid, List, Plus, ShieldCheck } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Avatar } from "@/components/ui/avatar";
import { Badge, LabelBadge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Table, Td, Th, Tr } from "@/components/ui/misc";
import { priority, taskStatus, TASK_COLUMNS } from "@/lib/labels";
import type { ProfileLite, Task, TaskStatus } from "@/lib/types";
import { cn, dateFr, isOverdue } from "@/lib/utils";
import { createTask, updateTask } from "@/app/(app)/projets/actions";
import { TaskDrawer } from "./task-drawer";

const COLUMN_ACCENT: Record<TaskStatus, string> = {
  backlog: "bg-slate-400", todo: "bg-sky-500", in_progress: "bg-violet-500", review: "bg-amber-500", done: "bg-emerald-500",
};

export function ProjectBoard({
  projectId, initialTasks, people, blockedIds, canContribute, assignableIds,
}: {
  projectId: string;
  initialTasks: Task[];
  people: ProfileLite[];
  blockedIds: string[];
  canContribute: boolean;
  /** Personnes a qui l'utilisateur peut confier une tache : son equipe, ou lui seul. */
  assignableIds?: string[];
}) {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const [tasks, setTasks] = useState(initialTasks);
  const [view, setView] = useState<"board" | "list">("board");
  const [dragging, setDragging] = useState<Task | null>(null);
  const [filter, setFilter] = useState("");
  const [, start] = useTransition();
  const openId = params.get("tache");
  const pm = useMemo(() => new Map(people.map((p) => [p.id, p])), [people]);
  const blocked = useMemo(() => new Set(blockedIds), [blockedIds]);

  useEffect(() => setTasks(initialTasks), [initialTasks]);

  // Collaboration en temps réel : toute modification d'une tâche du projet rafraîchit le tableau.
  useEffect(() => {
    const supabase = createClient();
    const ch = supabase
      .channel(`project-${projectId}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "tasks", filter: `project_id=eq.${projectId}` }, () => router.refresh())
      .subscribe();
    return () => { supabase.removeChannel(ch); };
  }, [projectId, router]);

  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 6 } }), useSensor(TouchSensor, { activationConstraint: { delay: 180, tolerance: 6 } }));
  const top = tasks.filter((t) => !t.parent_id).filter((t) => !filter || t.title.toLowerCase().includes(filter.toLowerCase()) || pm.get(t.assignee_id ?? "")?.full_name.toLowerCase().includes(filter.toLowerCase()));
  const subCount = (id: string) => {
    const subs = tasks.filter((t) => t.parent_id === id);
    return subs.length ? `${subs.filter((s) => s.status === "done").length}/${subs.length}` : null;
  };

  function open(id: string | null) {
    const sp = new URLSearchParams(params.toString());
    if (id) sp.set("tache", id); else sp.delete("tache");
    router.replace(`${pathname}${sp.toString() ? `?${sp}` : ""}`, { scroll: false });
  }

  function onDragStart(e: DragStartEvent) {
    setDragging(tasks.find((t) => t.id === e.active.id) ?? null);
  }

  function onDragEnd(e: DragEndEvent) {
    setDragging(null);
    const task = tasks.find((t) => t.id === e.active.id);
    const status = e.over?.id as TaskStatus | undefined;
    if (!task || !status || task.status === status) return;
    const maxPos = Math.max(0, ...tasks.filter((t) => t.status === status).map((t) => t.position));
    const prev = tasks;
    setTasks(tasks.map((t) => (t.id === task.id ? { ...t, status, position: maxPos + 1 } : t)));
    start(async () => {
      const r = await updateTask(task.id, { status, position: maxPos + 1 }, projectId);
      if (!r.ok) {
        setTasks(prev);
        toast.error(r.error);
      }
    });
  }

  return (
    <div>
      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <Input value={filter} onChange={(e) => setFilter(e.target.value)} placeholder="Filtrer par titre ou personne…" className="sm:max-w-xs" />
        <div className="inline-flex rounded-lg border border-border bg-surface p-0.5">
          {([["board", LayoutGrid, "Tableau"], ["list", List, "Liste"]] as const).map(([v, Icon, l]) => (
            <button key={v} onClick={() => setView(v)} className={cn("flex items-center gap-1.5 rounded-md px-3 py-1.5 text-[13px] font-medium transition", view === v ? "bg-surface-2 text-fg shadow-sm" : "text-muted hover:text-fg")}>
              <Icon className="h-4 w-4" /> {l}
            </button>
          ))}
        </div>
      </div>

      {view === "board" ? (
        <DndContext sensors={sensors} onDragStart={onDragStart} onDragEnd={onDragEnd}>
          <div className="scrollbar-thin -mx-4 flex gap-4 overflow-x-auto px-4 pb-4 sm:mx-0 sm:px-0">
            {TASK_COLUMNS.map((col) => {
              const items = top.filter((t) => t.status === col).sort((a, b) => a.position - b.position);
              return (
                <Column key={col} status={col} count={items.length}>
                  {items.map((t) => (
                    <DraggableCard key={t.id} task={t} disabled={!canContribute}>
                      <CardBody task={t} assignee={pm.get(t.assignee_id ?? "")} blocked={blocked.has(t.id)} sub={subCount(t.id)} onOpen={() => open(t.id)} />
                    </DraggableCard>
                  ))}
                  {canContribute && <QuickAdd projectId={projectId} status={col} onCreated={() => router.refresh()} />}
                </Column>
              );
            })}
          </div>
          <DragOverlay>
            {dragging && (
              <div className="rotate-2 cursor-grabbing">
                <CardBody task={dragging} assignee={pm.get(dragging.assignee_id ?? "")} blocked={blocked.has(dragging.id)} sub={subCount(dragging.id)} />
              </div>
            )}
          </DragOverlay>
        </DndContext>
      ) : (
        <div className="overflow-hidden rounded-2xl border border-border bg-surface">
          <Table>
            <thead><tr><Th>Tâche</Th><Th>Statut</Th><Th>Priorité</Th><Th>Assignée</Th><Th>Échéance</Th></tr></thead>
            <tbody>
              {top.sort((a, b) => TASK_COLUMNS.indexOf(a.status) - TASK_COLUMNS.indexOf(b.status)).map((t) => {
                const a = pm.get(t.assignee_id ?? "");
                return (
                  <Tr key={t.id} className="cursor-pointer" onClick={() => open(t.id)}>
                    <Td className="max-w-[360px]"><span className="flex items-center gap-2">{blocked.has(t.id) && <Ban className="h-3.5 w-3.5 text-danger" />}<span className="truncate font-medium">{t.title}</span></span></Td>
                    <Td><LabelBadge map={taskStatus} value={t.status} /></Td>
                    <Td><LabelBadge map={priority} value={t.priority} /></Td>
                    <Td>{a ? <span className="flex items-center gap-2"><Avatar name={a.full_name} src={a.avatar_url} size="xs" /><span className="truncate text-sm">{a.full_name}</span></span> : <span className="text-subtle">—</span>}</Td>
                    <Td className={cn(isOverdue(t.due_date, t.status === "done") && "font-medium text-danger")}>{t.due_date ? dateFr(t.due_date) : "—"}</Td>
                  </Tr>
                );
              })}
            </tbody>
          </Table>
        </div>
      )}

      <TaskDrawer
        taskId={openId}
        onClose={() => open(null)}
        people={people}
        assignableIds={assignableIds}
        siblings={tasks.filter((t) => !t.parent_id).map((t) => ({ id: t.id, title: t.title }))}
      />
    </div>
  );
}

function Column({ status, count, children }: { status: TaskStatus; count: number; children: React.ReactNode }) {
  const { setNodeRef, isOver } = useDroppable({ id: status });
  return (
    <div ref={setNodeRef} className={cn("flex w-[272px] shrink-0 flex-col rounded-2xl border border-transparent bg-surface-2/60 p-2 transition", isOver && "border-primary/40 bg-primary/[0.06]")}>
      <div className="mb-2 flex items-center gap-2 px-2 py-1.5">
        <span className={cn("h-2 w-2 rounded-full", COLUMN_ACCENT[status])} />
        <span className="text-[13px] font-semibold text-fg">{taskStatus[status].label}</span>
        <span className="rounded-full bg-surface px-1.5 text-[11px] font-medium text-muted">{count}</span>
      </div>
      <div className="flex min-h-[80px] flex-col gap-2">{children}</div>
    </div>
  );
}

function DraggableCard({ task, children, disabled }: { task: Task; children: React.ReactNode; disabled?: boolean }) {
  const { attributes, listeners, setNodeRef, isDragging } = useDraggable({ id: task.id, disabled });
  return (
    <div ref={setNodeRef} {...listeners} {...attributes} className={cn("touch-manipulation", isDragging && "opacity-30")}>
      {children}
    </div>
  );
}

function CardBody({ task: t, assignee, blocked, sub, onOpen }: { task: Task; assignee?: ProfileLite; blocked: boolean; sub: string | null; onOpen?: () => void }) {
  const overdue = isOverdue(t.due_date, t.status === "done");
  return (
    <button onClick={onOpen} className="group w-full rounded-xl border border-border bg-surface p-3 text-left shadow-card transition hover:border-primary/30 hover:shadow-md">
      <div className="flex items-start gap-2">
        <p className={cn("flex-1 text-[13.5px] font-medium leading-snug text-fg", t.status === "done" && "text-muted line-through")}>{t.title}</p>
        {(t.priority === "high" || t.priority === "urgent") && <LabelBadge map={priority} value={t.priority} />}
      </div>
      <div className="mt-3 flex items-center gap-2 text-[11.5px] text-subtle">
        {blocked && <span title="Bloquée par une dépendance" className="text-danger"><Ban className="h-3.5 w-3.5" /></span>}
        {t.requires_validation && <span title="Validation requise" className={t.validated_by ? "text-emerald-500" : "text-amber-500"}><ShieldCheck className="h-3.5 w-3.5" /></span>}
        {sub && <span className="flex items-center gap-1"><CheckSquare className="h-3.5 w-3.5" />{sub}</span>}
        {t.due_date && (
          <span className={cn("flex items-center gap-1", overdue && "font-medium text-danger")}>
            <AlarmClock className="h-3.5 w-3.5" />{dateFr(t.due_date, "d MMM")}
          </span>
        )}
        <span className="ml-auto">{assignee ? <Avatar name={assignee.full_name} src={assignee.avatar_url} size="xs" /> : <Badge>Libre</Badge>}</span>
      </div>
    </button>
  );
}

function QuickAdd({ projectId, status, onCreated }: { projectId: string; status: TaskStatus; onCreated: () => void }) {
  const [open, setOpen] = useState(false);
  const [title, setTitle] = useState("");
  const [pending, start] = useTransition();
  if (!open) {
    return (
      <button onClick={() => setOpen(true)} className="flex items-center gap-1.5 rounded-lg px-2 py-1.5 text-[13px] text-subtle transition hover:bg-surface hover:text-fg">
        <Plus className="h-4 w-4" /> Ajouter
      </button>
    );
  }
  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        if (!title.trim()) return setOpen(false);
        const fd = new FormData();
        fd.set("title", title);
        fd.set("status", status);
        fd.set("project_id", projectId);
        start(async () => {
          const r = await createTask(null, fd);
          if (!r.ok) toast.error(r.error);
          setTitle("");
          onCreated();
        });
      }}
    >
      <Input autoFocus value={title} onChange={(e) => setTitle(e.target.value)} onBlur={() => !title && setOpen(false)} placeholder="Titre de la tâche, puis Entrée" disabled={pending} />
    </form>
  );
}
