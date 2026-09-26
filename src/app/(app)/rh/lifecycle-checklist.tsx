"use client";

import { useOptimistic, useTransition } from "react";
import { Check } from "lucide-react";
import { toast } from "sonner";
import { cn, dateFr } from "@/lib/utils";
import { toggleLifecycleItem } from "../home-actions";

type Item = { id: string; title: string; done_at: string | null; due_date: string | null };

export function LifecycleChecklist({ items, readOnly }: { items: Item[]; readOnly?: boolean }) {
  const [, start] = useTransition();
  const [optimistic, setOptimistic] = useOptimistic(items, (state, id: string) =>
    state.map((i) => (i.id === id ? { ...i, done_at: i.done_at ? null : new Date().toISOString() } : i)),
  );
  return (
    <ul className="space-y-0.5 p-3">
      {optimistic.map((i) => (
        <li key={i.id}>
          <button
            disabled={readOnly}
            onClick={() => start(async () => {
              setOptimistic(i.id);
              const r = await toggleLifecycleItem(i.id, !i.done_at);
              if (!r.ok) toast.error(r.error);
            })}
            className="flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left transition hover:bg-surface-2/60 disabled:cursor-default"
          >
            <span className={cn("grid h-5 w-5 shrink-0 place-items-center rounded-md border transition", i.done_at ? "border-emerald-500 bg-emerald-500 text-white" : "border-border bg-surface")}>
              {i.done_at && <Check className="h-3.5 w-3.5" />}
            </span>
            <span className={cn("flex-1 text-sm", i.done_at ? "text-subtle line-through" : "text-fg")}>{i.title}</span>
            {i.due_date && !i.done_at && <span className="text-xs text-subtle">{dateFr(i.due_date, "d MMM")}</span>}
          </button>
        </li>
      ))}
    </ul>
  );
}
