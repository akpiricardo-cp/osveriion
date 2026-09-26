"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Command } from "cmdk";
import * as D from "@radix-ui/react-dialog";
import {
  Building2, CheckSquare, FileText, FolderKanban, Handshake, Loader2, Search, User,
  type LucideIcon,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { NAV } from "./nav";

type Hit = { kind: string; id: string; title: string; subtitle: string | null; link: string };
const KIND: Record<string, { label: string; icon: LucideIcon }> = {
  person: { label: "Personnes", icon: User },
  unit: { label: "Organisation", icon: Building2 },
  project: { label: "Projets", icon: FolderKanban },
  task: { label: "Tâches", icon: CheckSquare },
  account: { label: "CRM", icon: Handshake },
  document: { label: "Documents", icon: FileText },
};

export function CommandSearch() {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  const [hits, setHits] = useState<Hit[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setOpen((o) => !o);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  useEffect(() => {
    if (q.trim().length < 2) {
      setHits([]);
      return;
    }
    setLoading(true);
    const t = setTimeout(async () => {
      const { data } = await createClient().rpc("global_search", { q });
      setHits((data as Hit[]) ?? []);
      setLoading(false);
    }, 220);
    return () => clearTimeout(t);
  }, [q]);

  const go = (href: string) => {
    setOpen(false);
    setQ("");
    router.push(href);
  };

  const groups = Object.keys(KIND).map((k) => ({ k, items: hits.filter((h) => h.kind === k) })).filter((g) => g.items.length);

  return (
    <>
      <button
        onClick={() => setOpen(true)}
        className="flex h-9 w-full max-w-md items-center gap-2.5 rounded-lg border border-border bg-surface-2/70 px-3 text-sm text-subtle transition hover:border-primary/30 hover:text-muted"
      >
        <Search className="h-4 w-4" />
        <span className="flex-1 truncate text-left"><span className="sm:hidden">Rechercher…</span><span className="hidden sm:inline">Rechercher personnes, projets, clients, documents…</span></span>
        <kbd className="hidden rounded border border-border bg-surface px-1.5 py-0.5 font-mono text-[10px] text-subtle sm:inline">⌘K</kbd>
      </button>
      <D.Root open={open} onOpenChange={setOpen}>
        <D.Portal>
          <D.Overlay className="fixed inset-0 z-50 bg-black/40 backdrop-blur-[2px]" />
          <D.Content className="fixed left-1/2 top-[12vh] z-50 w-[calc(100vw-2rem)] max-w-2xl -translate-x-1/2 overflow-hidden rounded-2xl border border-border bg-surface shadow-2xl">
            <D.Title className="sr-only">Recherche globale</D.Title>
            <D.Description className="sr-only">Rechercher dans VERIION OS</D.Description>
            <Command shouldFilter={false} loop>
              <div className="flex items-center gap-3 border-b border-border px-4">
                {loading ? <Loader2 className="h-4 w-4 animate-spin text-subtle" /> : <Search className="h-4 w-4 text-subtle" />}
                <Command.Input
                  value={q}
                  onValueChange={setQ}
                  placeholder="Tapez pour rechercher…"
                  className="h-14 flex-1 bg-transparent text-[15px] text-fg outline-none placeholder:text-subtle"
                />
              </div>
              <Command.List className="scrollbar-thin max-h-[60vh] overflow-y-auto p-2">
                {q.trim().length < 2 ? (
                  <Command.Group heading="Aller à" className="[&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:py-1.5 [&_[cmdk-group-heading]]:text-xs [&_[cmdk-group-heading]]:text-subtle">
                    {NAV.flatMap((g) => g.items).map((i) => (
                      <Command.Item key={i.href} value={i.href} onSelect={() => go(i.href)} className="flex cursor-pointer items-center gap-3 rounded-lg px-3 py-2 text-sm text-fg data-[selected=true]:bg-surface-2">
                        <i.icon className="h-4 w-4 text-subtle" /> {i.label}
                      </Command.Item>
                    ))}
                  </Command.Group>
                ) : (
                  <>
                    {!loading && hits.length === 0 && (
                      <p className="px-3 py-10 text-center text-sm text-muted">Aucun résultat pour « {q} »</p>
                    )}
                    {groups.map(({ k, items }) => {
                      const Icon = KIND[k].icon;
                      return (
                        <Command.Group key={k} heading={KIND[k].label} className="[&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:py-1.5 [&_[cmdk-group-heading]]:text-xs [&_[cmdk-group-heading]]:text-subtle">
                          {items.map((h) => (
                            <Command.Item key={h.kind + h.id} value={h.kind + h.id} onSelect={() => go(h.link)} className="flex cursor-pointer items-center gap-3 rounded-lg px-3 py-2 data-[selected=true]:bg-surface-2">
                              <div className="grid h-8 w-8 place-items-center rounded-lg bg-surface-2 text-muted"><Icon className="h-4 w-4" /></div>
                              <div className="min-w-0">
                                <p className="truncate text-sm font-medium text-fg">{h.title}</p>
                                {h.subtitle && <p className="truncate text-xs text-subtle">{h.subtitle}</p>}
                              </div>
                            </Command.Item>
                          ))}
                        </Command.Group>
                      );
                    })}
                  </>
                )}
              </Command.List>
            </Command>
          </D.Content>
        </D.Portal>
      </D.Root>
    </>
  );
}
