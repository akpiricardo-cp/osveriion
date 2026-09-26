"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { toast } from "sonner";
import * as P from "@radix-ui/react-popover";
import { Bell, CheckCheck, Settings2 } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { cn, relative } from "@/lib/utils";
import type { Notification } from "@/lib/types";

export function NotificationsBell({ userId }: { userId: string }) {
  const router = useRouter();
  const [items, setItems] = useState<Notification[]>([]);
  const unread = items.filter((n) => !n.read_at).length;
  const pathname = usePathname();
  const pathRef = useRef(pathname);
  pathRef.current = pathname;
  const openRef = useRef<(n: Notification) => void>(() => {});

  const load = useCallback(async () => {
    const { data } = await createClient()
      .from("notifications").select("*").order("created_at", { ascending: false }).limit(30);
    setItems((data as Notification[]) ?? []);
  }, []);

  useEffect(() => {
    load();
    const supabase = createClient();
    const channel = supabase
      .channel(`notif-${userId}`)
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "notifications", filter: `profile_id=eq.${userId}` },
        (payload) => {
          const n = payload.new as Notification;
          setItems((prev) => [n, ...prev].slice(0, 30));
          // Alerte discrète dans l'application, sauf si l'on est déjà sur la page concernée
          if (!n.link || !pathRef.current || !n.link.startsWith(pathRef.current) || pathRef.current === "/") {
            toast(n.title, { description: n.body ?? undefined, action: n.link ? { label: "Voir", onClick: () => openRef.current(n) } : undefined, duration: 6000 });
          }
        })
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [userId, load]);

  async function markAll() {
    const now = new Date().toISOString();
    setItems((prev) => prev.map((n) => ({ ...n, read_at: n.read_at ?? now })));
    await createClient().from("notifications").update({ read_at: now }).is("read_at", null);
  }

  async function open(n: Notification) {
    if (!n.read_at) {
      setItems((prev) => prev.map((x) => (x.id === n.id ? { ...x, read_at: new Date().toISOString() } : x)));
      await createClient().from("notifications").update({ read_at: new Date().toISOString() }).eq("id", n.id);
    }
    if (n.link) { if (/^https?:\/\//.test(n.link)) window.open(n.link, "_blank", "noopener,noreferrer"); else router.push(n.link); }
  }
  openRef.current = open;

  return (
    <P.Root>
      <P.Trigger className="relative grid h-9 w-9 place-items-center rounded-lg text-muted transition hover:bg-surface-2 hover:text-fg" aria-label="Notifications">
        <Bell className="h-[18px] w-[18px]" />
        {unread > 0 && (
          <span className="absolute right-1.5 top-1.5 grid h-4 min-w-4 place-items-center rounded-full bg-danger px-1 text-[10px] font-semibold text-white ring-2 ring-surface">
            {unread > 9 ? "9+" : unread}
          </span>
        )}
      </P.Trigger>
      <P.Portal>
        <P.Content align="end" sideOffset={8} className="z-50 w-[380px] max-w-[calc(100vw-1rem)] overflow-hidden rounded-2xl border border-border bg-surface shadow-2xl data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95">
          <div className="flex items-center justify-between border-b border-border px-4 py-3">
            <p className="text-sm font-semibold text-fg">Notifications</p>
            {unread > 0 && (
              <button onClick={markAll} className="flex items-center gap-1 text-xs font-medium text-primary hover:underline">
                <CheckCheck className="h-3.5 w-3.5" /> Tout marquer comme lu
              </button>
            )}
          </div>
          <div className="scrollbar-thin max-h-[420px] overflow-y-auto">
            {items.length === 0 ? (
              <p className="px-4 py-12 text-center text-sm text-muted">Vous êtes à jour.</p>
            ) : (
              items.map((n) => (
                <P.Close asChild key={n.id}>
                  <button
                    onClick={() => open(n)}
                    className={cn("flex w-full gap-3 border-b border-border px-4 py-3 text-left transition last:border-0 hover:bg-surface-2", !n.read_at && "bg-primary/[0.04]")}
                  >
                    <span className={cn("mt-1.5 h-2 w-2 shrink-0 rounded-full", n.read_at ? "bg-transparent" : "bg-primary")} />
                    <span className="min-w-0 flex-1">
                      <span className="block text-[13px] font-medium text-fg">{n.title}</span>
                      {n.body && <span className="mt-0.5 block truncate text-xs text-muted">{n.body}</span>}
                      <span className="mt-1 block text-[11px] text-subtle">{relative(n.created_at)}</span>
                    </span>
                  </button>
                </P.Close>
              ))
            )}
          </div>
          <P.Close asChild>
            <Link href="/parametres?onglet=notifications" className="flex items-center justify-center gap-1.5 border-t border-border px-4 py-2.5 text-xs font-medium text-muted hover:bg-surface-2 hover:text-fg">
              <Settings2 className="h-3.5 w-3.5" /> Préférences de notification
            </Link>
          </P.Close>
        </P.Content>
      </P.Portal>
    </P.Root>
  );
}
