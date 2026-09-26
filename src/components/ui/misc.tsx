import * as React from "react";
import Link from "next/link";
import { ChevronRight, ShieldAlert, type LucideIcon } from "lucide-react";
import { cn } from "@/lib/utils";

export function PageHeader({
  title, description, actions, crumbs, className,
}: {
  title: React.ReactNode;
  description?: React.ReactNode;
  actions?: React.ReactNode;
  crumbs?: { label: string; href?: string }[];
  className?: string;
}) {
  return (
    <div className={cn("mb-6 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between", className)}>
      <div className="min-w-0">
        {crumbs && crumbs.length > 0 && (
          <nav className="mb-2 flex flex-wrap items-center gap-1 text-[13px] text-subtle">
            {crumbs.map((c, i) => (
              <React.Fragment key={i}>
                {i > 0 && <ChevronRight className="h-3.5 w-3.5" />}
                {c.href ? (
                  <Link href={c.href} className="transition hover:text-fg">{c.label}</Link>
                ) : (
                  <span>{c.label}</span>
                )}
              </React.Fragment>
            ))}
          </nav>
        )}
        <h1 className="text-2xl font-semibold tracking-tight text-fg">{title}</h1>
        {description && <p className="mt-1 max-w-2xl text-sm text-muted">{description}</p>}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </div>
  );
}

export function StatCard({
  label, value, icon: Icon, hint, trend, tone = "primary", href,
}: {
  label: string;
  value: React.ReactNode;
  icon?: LucideIcon;
  hint?: React.ReactNode;
  trend?: { value: number; label?: string; positiveIsGood?: boolean };
  tone?: "primary" | "green" | "amber" | "red" | "cyan" | "pink";
  href?: string;
}) {
  const toneCls = {
    primary: "bg-primary/10 text-primary",
    green: "bg-emerald-500/10 text-emerald-600 dark:text-emerald-400",
    amber: "bg-amber-500/10 text-amber-600 dark:text-amber-400",
    red: "bg-rose-500/10 text-rose-600 dark:text-rose-400",
    cyan: "bg-cyan-500/10 text-cyan-600 dark:text-cyan-400",
    pink: "bg-pink-500/10 text-pink-600 dark:text-pink-400",
  }[tone];
  const good = trend ? (trend.positiveIsGood === false ? trend.value <= 0 : trend.value >= 0) : true;
  const inner = (
    <div className="group relative h-full overflow-hidden rounded-2xl border border-border bg-surface p-4 shadow-card sm:p-5 transition hover:border-primary/30">
      <div className="flex items-start justify-between gap-3">
        <p className="text-[13px] font-medium text-muted">{label}</p>
        {Icon && (
          <div className={cn("grid h-8 w-8 place-items-center rounded-lg", toneCls)}>
            <Icon className="h-4 w-4" />
          </div>
        )}
      </div>
      <p className="mt-3 break-words text-xl font-semibold leading-tight tracking-tight text-fg tabular-nums sm:text-[26px] sm:leading-none">{value}</p>
      <div className="mt-2.5 flex items-center gap-2 text-xs">
        {trend && (
          <span className={cn("rounded-md px-1.5 py-0.5 font-medium", good ? "bg-emerald-500/10 text-emerald-600 dark:text-emerald-400" : "bg-rose-500/10 text-rose-600 dark:text-rose-400")}>
            {trend.value >= 0 ? "▲" : "▼"} {Math.abs(trend.value).toFixed(1).replace(".", ",")} %
          </span>
        )}
        {(hint || trend?.label) && <span className="truncate text-subtle">{hint ?? trend?.label}</span>}
      </div>
    </div>
  );
  return href ? <Link href={href} className="block">{inner}</Link> : inner;
}

export function Progress({ value, className, tone }: { value: number; className?: string; tone?: string }) {
  const v = Math.max(0, Math.min(100, value));
  const auto = v >= 70 ? "bg-emerald-500" : v >= 40 ? "bg-primary" : "bg-amber-500";
  return (
    <div className={cn("h-1.5 w-full overflow-hidden rounded-full bg-surface-3", className)}>
      <div className={cn("h-full rounded-full transition-all", tone ?? auto)} style={{ width: `${v}%` }} />
    </div>
  );
}

export function EmptyState({
  icon: Icon, title, description, action, className,
}: { icon?: LucideIcon; title: string; description?: string; action?: React.ReactNode; className?: string }) {
  return (
    <div className={cn("flex flex-col items-center justify-center px-6 py-14 text-center", className)}>
      {Icon && (
        <div className="mb-4 grid h-12 w-12 place-items-center rounded-2xl bg-surface-2 text-subtle ring-1 ring-border">
          <Icon className="h-5 w-5" />
        </div>
      )}
      <p className="text-sm font-semibold text-fg">{title}</p>
      {description && <p className="mt-1 max-w-sm text-[13px] text-muted">{description}</p>}
      {action && <div className="mt-5">{action}</div>}
    </div>
  );
}

export function Forbidden({ message }: { message?: string }) {
  return (
    <div className="mx-auto mt-16 max-w-md rounded-2xl border border-border bg-surface p-8 text-center shadow-card">
      <div className="mx-auto mb-4 grid h-12 w-12 place-items-center rounded-2xl bg-rose-500/10 text-rose-600">
        <ShieldAlert className="h-6 w-6" />
      </div>
      <h2 className="text-lg font-semibold text-fg">Accès restreint</h2>
      <p className="mt-2 text-sm text-muted">
        {message ?? "Votre rôle actuel ne donne pas accès à cet espace. Contactez votre responsable si vous pensez que c'est une erreur."}
      </p>
      <Link href="/" className="mt-6 inline-block text-sm font-medium text-primary hover:underline">Retour à l&apos;accueil</Link>
    </div>
  );
}

export function Table({ className, ...props }: React.TableHTMLAttributes<HTMLTableElement>) {
  return (
    <div className="overflow-x-auto">
      <table className={cn("w-full text-sm", className)} {...props} />
    </div>
  );
}
export function Th({ className, ...props }: React.ThHTMLAttributes<HTMLTableCellElement>) {
  return (
    <th
      className={cn("border-b border-border bg-surface-2/60 px-4 py-2.5 text-left text-[12px] font-medium uppercase tracking-wide text-subtle first:pl-5 last:pr-5", className)}
      {...props}
    />
  );
}
export function Td({ className, ...props }: React.TdHTMLAttributes<HTMLTableCellElement>) {
  return <td className={cn("border-b border-border px-4 py-3 align-middle text-fg first:pl-5 last:pr-5", className)} {...props} />;
}
export function Tr({ className, ...props }: React.HTMLAttributes<HTMLTableRowElement>) {
  return <tr className={cn("transition hover:bg-surface-2/50 [&:last-child>td]:border-b-0", className)} {...props} />;
}

export function Section({ title, description, children, action }: { title: string; description?: string; children: React.ReactNode; action?: React.ReactNode }) {
  return (
    <section className="space-y-3">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h2 className="text-[15px] font-semibold tracking-tight text-fg">{title}</h2>
          {description && <p className="text-[13px] text-muted">{description}</p>}
        </div>
        {action}
      </div>
      {children}
    </section>
  );
}

export function KeyValue({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-4 py-2.5 text-sm">
      <span className="text-muted">{label}</span>
      <span className="text-right font-medium text-fg">{children}</span>
    </div>
  );
}
