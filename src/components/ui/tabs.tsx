import Link from "next/link";
import { cn } from "@/lib/utils";

/** Onglets pilotés par l'URL (?onglet=...) — compatibles Server Components. */
export function LinkTabs({
  tabs, active, basePath, param = "onglet", className,
}: {
  tabs: { key: string; label: string; count?: number; hidden?: boolean }[];
  active: string;
  basePath: string;
  param?: string;
  className?: string;
}) {
  return (
    <div className={cn("flex gap-1 overflow-x-auto border-b border-border", className)}>
      {tabs
        .filter((t) => !t.hidden)
        .map((t) => {
          const isActive = t.key === active;
          return (
            <Link
              key={t.key}
              href={`${basePath}?${param}=${t.key}`}
              scroll={false}
              className={cn(
                "relative -mb-px inline-flex items-center gap-2 whitespace-nowrap border-b-2 px-3 pb-2.5 pt-1 text-sm font-medium transition",
                isActive ? "border-primary text-fg" : "border-transparent text-muted hover:text-fg",
              )}
            >
              {t.label}
              {t.count !== undefined && (
                <span className={cn("rounded-full px-1.5 text-[11px]", isActive ? "bg-primary/10 text-primary" : "bg-surface-3 text-muted")}>
                  {t.count}
                </span>
              )}
            </Link>
          );
        })}
    </div>
  );
}
