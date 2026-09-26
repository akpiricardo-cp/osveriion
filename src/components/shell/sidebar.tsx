"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { Logo } from "@/components/logo";
import { NAV, type NavKey } from "./nav";

export function SidebarNav({
  access, unreadMessages, onNavigate,
}: { access: Record<NavKey, boolean>; unreadMessages: number; onNavigate?: () => void }) {
  const pathname = usePathname();
  const isActive = (href: string) => (href === "/" ? pathname === "/" : pathname === href || pathname.startsWith(href + "/"));

  return (
    <div className="flex h-full flex-col">
      <div className="px-5 pb-6 pt-5">
        <Link href="/" onClick={onNavigate}><Logo /></Link>
      </div>
      <nav className="scrollbar-thin flex-1 space-y-6 overflow-y-auto px-3 pb-6">
        {NAV.map((group) => {
          const items = group.items.filter((i) => !i.requires || access[i.requires]);
          if (!items.length) return null;
          return (
            <div key={group.title}>
              <p className="mb-1.5 px-3 text-[10.5px] font-semibold uppercase tracking-[0.16em] text-sidebar-muted">{group.title}</p>
              <ul className="space-y-0.5">
                {items.map((item) => {
                  const active = isActive(item.href);
                  const Icon = item.icon;
                  return (
                    <li key={item.href}>
                      <Link
                        href={item.href}
                        onClick={onNavigate}
                        className={cn(
                          "group relative flex items-center gap-3 rounded-lg px-3 py-2 text-[13.5px] font-medium transition",
                          active ? "bg-sidebar-active text-white" : "text-sidebar-fg/80 hover:bg-white/[0.04] hover:text-white",
                        )}
                      >
                        {active && <span className="absolute left-0 top-1/2 h-5 w-[3px] -translate-y-1/2 rounded-r-full bg-indigo-400" />}
                        <Icon className={cn("h-[18px] w-[18px] shrink-0", active ? "text-indigo-300" : "text-sidebar-muted group-hover:text-sidebar-fg")} />
                        <span className="truncate">{item.label}</span>
                        {item.badge === "messages" && unreadMessages > 0 && (
                          <span className="ml-auto rounded-full bg-indigo-500 px-1.5 py-px text-[10.5px] font-semibold text-white">
                            {unreadMessages > 99 ? "99+" : unreadMessages}
                          </span>
                        )}
                      </Link>
                    </li>
                  );
                })}
              </ul>
            </div>
          );
        })}
      </nav>
      <div className="m-3 rounded-xl border border-white/[0.06] bg-white/[0.03] p-3.5">
        <p className="text-[12px] font-medium text-white">VERIION OS</p>
        <p className="mt-0.5 text-[11px] leading-relaxed text-sidebar-muted">L&apos;écosystème numérique de l&apos;Afrique — usage interne.</p>
      </div>
    </div>
  );
}
