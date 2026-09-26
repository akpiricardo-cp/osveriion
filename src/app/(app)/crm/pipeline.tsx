"use client";

import { useEffect, useState, useTransition } from "react";
import Link from "next/link";
import { DndContext, DragOverlay, PointerSensor, TouchSensor, useDraggable, useDroppable, useSensor, useSensors, type DragEndEvent } from "@dnd-kit/core";
import { toast } from "sonner";
import { CalendarDays } from "lucide-react";
import { Avatar } from "@/components/ui/avatar";
import { STAGES, stage as stageLabels } from "@/lib/labels";
import type { Opportunity, OpportunityStage, ProfileLite } from "@/lib/types";
import { cn, dateFr, money } from "@/lib/utils";
import { moveOpportunity } from "./actions";

type Opp = Opportunity & { accounts: { name: string } | null };
const ACCENT: Record<OpportunityStage, string> = {
  lead: "bg-slate-400", qualified: "bg-sky-500", proposal: "bg-violet-500", negotiation: "bg-amber-500", won: "bg-emerald-500", lost: "bg-rose-500",
};

export function Pipeline({ initial, people, canEdit }: { initial: Opp[]; people: ProfileLite[]; canEdit: boolean }) {
  const [opps, setOpps] = useState(initial);
  const [active, setActive] = useState<Opp | null>(null);
  const [, start] = useTransition();
  const pm = new Map(people.map((p) => [p.id, p]));
  useEffect(() => setOpps(initial), [initial]);
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 6 } }), useSensor(TouchSensor, { activationConstraint: { delay: 180, tolerance: 6 } }));

  function onDragEnd(e: DragEndEvent) {
    setActive(null);
    const o = opps.find((x) => x.id === e.active.id);
    const target = e.over?.id as OpportunityStage | undefined;
    if (!o || !target || o.stage === target) return;
    let reason: string | undefined;
    if (target === "lost") {
      reason = prompt("Motif de la perte (facultatif) :") ?? undefined;
    }
    if (target === "won" && !confirm(`Marquer « ${o.name} » comme gagnée ? Un projet de livraison et une facture brouillon seront créés.`)) return;
    const prev = opps;
    setOpps(opps.map((x) => (x.id === o.id ? { ...x, stage: target } : x)));
    start(async () => {
      const r = await moveOpportunity(o.id, target, reason);
      if (!r.ok) { setOpps(prev); toast.error(r.error); } else if (r.message) toast.success(r.message);
    });
  }

  return (
    <DndContext sensors={sensors} onDragStart={(e) => setActive(opps.find((o) => o.id === e.active.id) ?? null)} onDragEnd={onDragEnd}>
      <div className="scrollbar-thin -mx-4 flex gap-4 overflow-x-auto px-4 pb-4 sm:mx-0 sm:px-0">
        {STAGES.map((s) => {
          const items = opps.filter((o) => o.stage === s).sort((a, b) => b.amount - a.amount);
          const total = items.reduce((t, o) => t + Number(o.amount), 0);
          return (
            <StageColumn key={s} stage={s} count={items.length} total={total}>
              {items.map((o) => (
                <Draggable key={o.id} id={o.id} disabled={!canEdit}>
                  <OppCard o={o} owner={pm.get(o.owner_id ?? "")} />
                </Draggable>
              ))}
            </StageColumn>
          );
        })}
      </div>
      <DragOverlay>{active && <div className="rotate-2"><OppCard o={active} owner={pm.get(active.owner_id ?? "")} /></div>}</DragOverlay>
    </DndContext>
  );
}

function StageColumn({ stage, count, total, children }: { stage: OpportunityStage; count: number; total: number; children: React.ReactNode }) {
  const { setNodeRef, isOver } = useDroppable({ id: stage });
  return (
    <div ref={setNodeRef} className={cn("flex w-[270px] shrink-0 flex-col rounded-2xl border border-transparent bg-surface-2/60 p-2 transition", isOver && "border-primary/40 bg-primary/[0.06]")}>
      <div className="mb-2 px-2 py-1.5">
        <div className="flex items-center gap-2">
          <span className={cn("h-2 w-2 rounded-full", ACCENT[stage])} />
          <span className="text-[13px] font-semibold text-fg">{stageLabels[stage].label}</span>
          <span className="rounded-full bg-surface px-1.5 text-[11px] font-medium text-muted">{count}</span>
        </div>
        <p className="mt-1 text-xs tabular-nums text-subtle">{money(total, "XOF", true)}</p>
      </div>
      <div className="flex min-h-[80px] flex-col gap-2">{children}</div>
    </div>
  );
}

function Draggable({ id, children, disabled }: { id: string; children: React.ReactNode; disabled?: boolean }) {
  const { attributes, listeners, setNodeRef, isDragging } = useDraggable({ id, disabled });
  return <div ref={setNodeRef} {...listeners} {...attributes} className={cn(isDragging && "opacity-30")}>{children}</div>;
}

function OppCard({ o, owner }: { o: Opp; owner?: ProfileLite }) {
  return (
    <div className="rounded-xl border border-border bg-surface p-3 shadow-card transition hover:border-primary/30 hover:shadow-md">
      <Link href={`/crm/comptes/${o.account_id}`} onPointerDown={(e) => e.stopPropagation()} className="block truncate text-[11.5px] font-medium text-primary hover:underline">
        {o.accounts?.name}
      </Link>
      <p className="mt-0.5 text-[13.5px] font-medium leading-snug text-fg">{o.name}</p>
      <div className="mt-2 flex items-baseline justify-between">
        <p className="text-sm font-semibold tabular-nums text-fg">{money(o.amount, o.currency, true)}</p>
        <span className="text-[11px] text-subtle">{o.probability} %</span>
      </div>
      <div className="mt-2 flex items-center gap-2 text-[11px] text-subtle">
        {o.product && <span className="rounded bg-surface-2 px-1.5 py-0.5">{o.product}</span>}
        {o.expected_close && <span className="flex items-center gap-1"><CalendarDays className="h-3 w-3" />{dateFr(o.expected_close, "d MMM")}</span>}
        {owner && <span className="ml-auto"><Avatar name={owner.full_name} src={owner.avatar_url} size="xs" /></span>}
      </div>
    </div>
  );
}
