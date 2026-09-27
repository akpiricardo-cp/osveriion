"use client";

import { useState } from "react";
import Link from "next/link";
import * as D from "@radix-ui/react-dialog";
import { useTheme } from "next-themes";
import { LogOut, Menu, Monitor, Moon, Settings, ShieldCheck, Sun, User } from "lucide-react";
import { Avatar } from "@/components/ui/avatar";
import { logout } from "@/lib/logout";
import { Dropdown, DropdownContent, DropdownItem, DropdownLabel, DropdownSeparator, DropdownTrigger } from "@/components/ui/dropdown";
import { CommandSearch } from "./command-search";
import { NotificationsBell } from "./notifications";
import { SidebarNav } from "./sidebar";
import type { NavKey } from "./nav";

export function Topbar({
  user, access, unreadMessages,
}: {
  user: { id: string; name: string; email: string; avatar: string | null; title: string | null; role: string };
  access: Record<NavKey, boolean>;
  unreadMessages: number;
}) {
  const [mobileOpen, setMobileOpen] = useState(false);
  const { setTheme } = useTheme();

  return (
    <header className="sticky top-0 z-30 flex h-14 items-center gap-2 border-b border-border bg-surface/85 px-3 pt-safe backdrop-blur-xl sm:h-16 sm:gap-3 sm:px-6">
      <D.Root open={mobileOpen} onOpenChange={setMobileOpen}>
        <D.Trigger className="grid h-9 w-9 place-items-center rounded-lg text-muted hover:bg-surface-2 lg:hidden" aria-label="Menu">
          <Menu className="h-5 w-5" />
        </D.Trigger>
        <D.Portal>
          <D.Overlay className="fixed inset-0 z-50 bg-black/40 lg:hidden" />
          <D.Content className="fixed inset-y-0 left-0 z-50 w-72 bg-sidebar data-[state=open]:animate-in data-[state=open]:slide-in-from-left lg:hidden">
            <D.Title className="sr-only">Navigation</D.Title>
            <D.Description className="sr-only">Menu principal</D.Description>
            <SidebarNav access={access} unreadMessages={unreadMessages} onNavigate={() => setMobileOpen(false)} />
          </D.Content>
        </D.Portal>
      </D.Root>

      <div className="flex-1"><CommandSearch /></div>

      <div className="flex items-center gap-1">
        <NotificationsBell userId={user.id} />
        <Dropdown>
          <DropdownTrigger className="ml-1 flex items-center gap-2.5 rounded-lg p-1 pr-2 transition hover:bg-surface-2" aria-label="Menu utilisateur">
            <Avatar name={user.name} src={user.avatar} size="sm" />
            <span className="hidden text-left leading-tight md:block">
              <span className="block max-w-[160px] truncate text-[13px] font-medium text-fg">{user.name}</span>
              <span className="block max-w-[160px] truncate text-[11px] text-subtle">{user.title ?? user.role}</span>
            </span>
          </DropdownTrigger>
          <DropdownContent className="w-64">
            <DropdownLabel>
              <span className="block text-[13px] font-medium text-fg">{user.name}</span>
              <span className="block truncate text-xs font-normal">{user.email}</span>
            </DropdownLabel>
            <DropdownSeparator />
            <DropdownItem asChild><Link href={`/annuaire/${user.id}`}><User className="h-4 w-4 text-subtle" /> Mon profil</Link></DropdownItem>
            <DropdownItem asChild><Link href="/parametres"><Settings className="h-4 w-4 text-subtle" /> Paramètres</Link></DropdownItem>
            <DropdownItem asChild><Link href="/parametres?onglet=securite"><ShieldCheck className="h-4 w-4 text-subtle" /> Sécurité & sessions</Link></DropdownItem>
            <DropdownSeparator />
            <DropdownLabel>Thème</DropdownLabel>
            <div className="grid grid-cols-3 gap-1 px-1 pb-1">
              {([["light", Sun, "Clair"], ["dark", Moon, "Sombre"], ["system", Monitor, "Auto"]] as const).map(([t, Icon, l]) => (
                <button key={t} onClick={() => setTheme(t)} className="flex flex-col items-center gap-1 rounded-lg py-2 text-[11px] text-muted transition hover:bg-surface-2 hover:text-fg">
                  <Icon className="h-4 w-4" /> {l}
                </button>
              ))}
            </div>
            <DropdownSeparator />
            <DropdownItem
              danger
              onSelect={() => { void logout(); }}
            >
              <LogOut className="h-4 w-4" /> Se déconnecter
            </DropdownItem>
          </DropdownContent>
        </Dropdown>
      </div>
    </header>
  );
}
