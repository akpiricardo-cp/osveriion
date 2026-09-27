"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import * as D from "@radix-ui/react-dialog";
import { CheckSquare, FolderKanban, Home, Menu, MessagesSquare, type LucideIcon } from "lucide-react";
import { cn } from "@/lib/utils";
import { SidebarNav } from "./sidebar";
import type { NavKey } from "./nav";

const ITEMS: { href: string; label: string; icon: LucideIcon; badge?: boolean }[] = [
  { href: "/", label: "Accueil", icon: Home },
  { href: "/taches", label: "Tâches", icon: CheckSquare },
  { href: "/messages", label: "Messages", icon: MessagesSquare, badge: true },
  { href: "/projets", label: "Projets", icon: FolderKanban },
];

/**
 * Navigation du pouce : sur téléphone, les quatre écrans quotidiens restent à
 * portée, le reste de l'organisation s'ouvre en tiroir. Masquée dès l'écran
 * large, où la barre latérale reprend la main.
 */
export function BottomNav({ access, unreadMessages }: { access: Record<NavKey, boolean>; unreadMessages: number }) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const isActive = (href: string) => (href === "/" ? pathname === "/" : pathname === href || pathname.startsWith(href + "/"));

  return (
    <nav className="fixed inset-x-0 bottom-0 z-40 border-t border-border bg-surface/95 pb-safe backdrop-blur-xl lg:hidden print:hidden">
      <ul className="flex items-stretch">
        {ITEMS.map((item) => {
          const active = isActive(item.href);
          const Icon = item.icon;
          return (
            <li key={item.href} className="flex-1">
              <Link
                href={item.href}
                className={cn(
                  "relative flex h-14 flex-col items-center justify-center gap-0.5 text-[10.5px] font-medium transition",
                  active ? "text-primary" : "text-subtle",
                )}
              >
                <span className="relative">
                  <Icon className="h-[21px] w-[21px]" />
                  {item.badge && unreadMessages > 0 && (
                    <span className="absolute -right-2 -top-1 min-w-[16px] rounded-full bg-indigo-500 px-1 text-center text-[9.5px] font-semibold leading-4 text-white">
                      {unreadMessages > 9 ? "9+" : unreadMessages}
                    </span>
                  )}
                </span>
                {item.label}
                {active && <span className="absolute inset-x-5 top-0 h-0.5 rounded-b-full bg-primary" />}
              </Link>
            </li>
          );
        })}

        <li className="flex-1">
          <D.Root open={open} onOpenChange={setOpen}>
            <D.Trigger className="flex h-14 w-full flex-col items-center justify-center gap-0.5 text-[10.5px] font-medium text-subtle transition">
              <Menu className="h-[21px] w-[21px]" />
              Plus
            </D.Trigger>
            <D.Portal>
              <D.Overlay className="fixed inset-0 z-50 bg-black/40 data-[state=open]:animate-in data-[state=open]:fade-in-0" />
              <D.Content className="fixed inset-y-0 right-0 z-50 w-72 bg-sidebar data-[state=open]:animate-in data-[state=open]:slide-in-from-right">
                <D.Title className="sr-only">Navigation</D.Title>
                <D.Description className="sr-only">Tous les espaces de VERIION OS</D.Description>
                <SidebarNav access={access} unreadMessages={unreadMessages} onNavigate={() => setOpen(false)} />
              </D.Content>
            </D.Portal>
          </D.Root>
        </li>
      </ul>
    </nav>
  );
}
