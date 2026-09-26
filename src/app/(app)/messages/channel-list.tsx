"use client";

import { useEffect, useMemo, useState, useTransition } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { Building2, FolderKanban, Hash, Lock, Plus, Search, UserPlus } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Avatar } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { ActionForm } from "@/components/ui/action-form";
import { Checkbox, Field, Input } from "@/components/ui/input";
import type { ChannelSummary, ProfileLite } from "@/lib/types";
import { cn, relative } from "@/lib/utils";
import { openDirectMessage } from "../annuaire/actions";
import { createGroup } from "./actions";

const SECTIONS: { key: ChannelSummary["kind"]; label: string }[] = [
  { key: "direct", label: "Conversations directes" },
  { key: "group", label: "Canaux" },
  { key: "unit", label: "Départements & équipes" },
  { key: "project", label: "Projets" },
];

export function ChannelList({ channels, people, userId }: { channels: ChannelSummary[]; people: ProfileLite[]; userId: string }) {
  const pathname = usePathname();
  const router = useRouter();
  const [q, setQ] = useState("");
  const activeId = pathname.split("/")[2];

  useEffect(() => {
    const supabase = createClient();
    const ch = supabase
      .channel(`inbox-${userId}`)
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "messages" }, () => router.refresh())
      .subscribe();
    return () => { supabase.removeChannel(ch); };
  }, [router, userId]);

  const filtered = useMemo(() => channels.filter((c) => !q || c.name.toLowerCase().includes(q.toLowerCase())), [channels, q]);

  return (
    <aside className={cn("flex w-full shrink-0 flex-col border-r border-border md:w-80", activeId && "hidden md:flex")}>
      <div className="flex items-center justify-between gap-2 px-4 pb-3 pt-5">
        <h1 className="text-lg font-semibold tracking-tight text-fg">Messages</h1>
        <div className="flex gap-1">
          <NewDirect people={people} />
          <NewGroup people={people} />
        </div>
      </div>
      <div className="px-4 pb-3">
        <div className="relative">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-subtle" />
          <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Rechercher" className="pl-9" />
        </div>
      </div>
      <nav className="scrollbar-thin flex-1 space-y-5 overflow-y-auto px-2 pb-6">
        {SECTIONS.map((s) => {
          const items = filtered.filter((c) => c.kind === s.key);
          if (!items.length) return null;
          return (
            <div key={s.key}>
              <p className="mb-1 px-3 text-[11px] font-semibold uppercase tracking-wider text-subtle">{s.label}</p>
              <ul>
                {items.map((c) => {
                  const active = c.id === activeId;
                  const Icon = c.kind === "unit" ? Building2 : c.kind === "project" ? FolderKanban : c.is_private ? Lock : Hash;
                  return (
                    <li key={c.id}>
                      <Link href={`/messages/${c.id}`} className={cn("flex items-center gap-3 rounded-lg px-3 py-2 transition", active ? "bg-primary/10" : "hover:bg-surface-2")}>
                        {c.kind === "direct" ? (
                          <Avatar name={c.other_name} src={c.other_avatar} size="sm" />
                        ) : (
                          <span className={cn("grid h-8 w-8 place-items-center rounded-lg", active ? "bg-primary/15 text-primary" : "bg-surface-2 text-muted")}><Icon className="h-4 w-4" /></span>
                        )}
                        <span className="min-w-0 flex-1">
                          <span className={cn("block truncate text-sm", c.unread ? "font-semibold text-fg" : "text-fg")}>{c.name}</span>
                          <span className="block truncate text-[11px] text-subtle">
                            {c.kind === "direct" ? c.other_title ?? "" : c.last_message_at ? relative(c.last_message_at) : "Aucun message"}
                          </span>
                        </span>
                        {c.unread > 0 && <span className="rounded-full bg-primary px-1.5 py-px text-[10.5px] font-semibold text-white">{c.unread}</span>}
                      </Link>
                    </li>
                  );
                })}
              </ul>
            </div>
          );
        })}
      </nav>
    </aside>
  );
}

function NewDirect({ people }: { people: ProfileLite[] }) {
  const [q, setQ] = useState("");
  const [pending, start] = useTransition();
  return (
    <Dialog>
      <DialogTrigger asChild><Button size="icon-sm" variant="ghost" aria-label="Nouvelle conversation"><UserPlus className="h-4 w-4" /></Button></DialogTrigger>
      <DialogContent title="Nouvelle conversation" size="sm">
        <Input autoFocus value={q} onChange={(e) => setQ(e.target.value)} placeholder="Rechercher un collègue…" />
        <ul className="scrollbar-thin mt-3 max-h-80 overflow-y-auto">
          {people.filter((p) => p.full_name.toLowerCase().includes(q.toLowerCase())).map((p) => (
            <li key={p.id}>
              <button disabled={pending} onClick={() => start(() => openDirectMessage(p.id))} className="flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left hover:bg-surface-2 disabled:opacity-50">
                <Avatar name={p.full_name} src={p.avatar_url} size="sm" />
                <span className="min-w-0"><span className="block truncate text-sm text-fg">{p.full_name}</span><span className="block truncate text-xs text-subtle">{p.job_title}</span></span>
              </button>
            </li>
          ))}
        </ul>
      </DialogContent>
    </Dialog>
  );
}

function NewGroup({ people }: { people: ProfileLite[] }) {
  const [open, setOpen] = useState(false);
  const router = useRouter();
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><Button size="icon-sm" variant="ghost" aria-label="Nouveau canal"><Plus className="h-4 w-4" /></Button></DialogTrigger>
      <DialogContent title="Nouveau canal" description="Un espace de discussion thématique ou de groupe.">
        <ActionForm action={createGroup} submitLabel="Créer le canal" onSuccess={(r) => { setOpen(false); const id = r.ok && (r.data as { id: string })?.id; if (id) router.push(`/messages/${id}`); }}>
          <Field label="Nom" htmlFor="name" required hint="Ex. : lancement-oniix, veille-concurrentielle"><Input id="name" name="name" required /></Field>
          <Field label="Sujet" htmlFor="description"><Input id="description" name="description" /></Field>
          <Checkbox name="is_private" label="Canal privé (sur invitation uniquement)" />
          <Field label="Membres">
            <div className="scrollbar-thin max-h-48 space-y-1 overflow-y-auto rounded-lg border border-border p-2">
              {people.map((p) => <Checkbox key={p.id} name="members" value={p.id} label={p.full_name} className="flex w-full rounded px-1 py-1 hover:bg-surface-2" />)}
            </div>
          </Field>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}
