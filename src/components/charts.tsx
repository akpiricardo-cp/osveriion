"use client";

import {
  Area, AreaChart, Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis, type TooltipContentProps,
} from "recharts";
import { money, num } from "@/lib/utils";

const MONTHS = ["Janv.", "Févr.", "Mars", "Avr.", "Mai", "Juin", "Juil.", "Août", "Sept.", "Oct.", "Nov.", "Déc."];
const axis = { stroke: "var(--subtle)", fontSize: 11, tickLine: false, axisLine: false } as const;

function Tip({ active, payload, label, currency = true, labels }: Partial<TooltipContentProps<number, string>> & { currency?: boolean; labels?: Record<string, string> }) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-xl border border-border bg-surface px-3 py-2 shadow-xl">
      <p className="mb-1 text-xs font-medium text-muted">{label}</p>
      {payload.map((p) => (
        <p key={String(p.dataKey)} className="flex items-center gap-2 text-[13px] text-fg">
          <span className="h-2 w-2 rounded-sm" style={{ background: p.color }} />
          <span className="text-muted">{labels?.[String(p.dataKey)] ?? p.name}</span>
          <span className="ml-auto pl-4 font-semibold tabular-nums">{currency ? money(Number(p.value)) : num(Number(p.value))}</span>
        </p>
      ))}
    </div>
  );
}

function Legend({ items }: { items: { color: string; label: string }[] }) {
  return (
    <div className="mb-3 flex flex-wrap gap-4 text-xs text-muted">
      {items.map((i) => (
        <span key={i.label} className="flex items-center gap-1.5"><span className="h-2.5 w-2.5 rounded-sm" style={{ background: i.color }} />{i.label}</span>
      ))}
    </div>
  );
}

/** Revenus vs dépenses par mois (barres groupées, un seul axe). */
export function RevenueExpenseChart({ data }: { data: { month: number; revenue: number; expense: number }[] }) {
  const rows = data.map((d) => ({ ...d, label: MONTHS[d.month - 1] }));
  return (
    <div>
      <Legend items={[{ color: "var(--series-1)", label: "Revenus" }, { color: "var(--series-2)", label: "Dépenses" }]} />
      <div className="h-72">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={rows} barGap={2} barCategoryGap="28%" margin={{ left: 4, right: 4, top: 8 }}>
            <CartesianGrid vertical={false} stroke="var(--chart-grid)" />
            <XAxis dataKey="label" {...axis} />
            <YAxis {...axis} width={52} tickFormatter={(v) => num(v, true)} />
            <Tooltip cursor={{ fill: "var(--surface-2)" }} content={<Tip labels={{ revenue: "Revenus", expense: "Dépenses" }} />} />
            <Bar dataKey="revenue" name="Revenus" fill="var(--series-1)" radius={[4, 4, 0, 0]} maxBarSize={22} />
            <Bar dataKey="expense" name="Dépenses" fill="var(--series-2)" radius={[4, 4, 0, 0]} maxBarSize={22} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}

/** Série temporelle simple (utilisateurs actifs). */
export function TrendChart({ data, label }: { data: { date: string; value: number }[]; label: string }) {
  const rows = data.map((d) => ({ ...d, label: new Date(d.date).toLocaleDateString("fr-FR", { day: "numeric", month: "short" }) }));
  return (
    <div className="h-56">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={rows} margin={{ left: 4, right: 8, top: 8 }}>
          <defs>
            <linearGradient id="trend-fill" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="var(--series-1)" stopOpacity={0.25} />
              <stop offset="100%" stopColor="var(--series-1)" stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid vertical={false} stroke="var(--chart-grid)" />
          <XAxis dataKey="label" {...axis} minTickGap={36} />
          <YAxis {...axis} width={48} tickFormatter={(v) => num(v, true)} domain={["auto", "auto"]} />
          <Tooltip cursor={{ stroke: "var(--subtle)", strokeDasharray: "3 3" }} content={<Tip currency={false} labels={{ value: label }} />} />
          <Area type="monotone" dataKey="value" name={label} stroke="var(--series-1)" strokeWidth={2} fill="url(#trend-fill)" activeDot={{ r: 4, strokeWidth: 2, stroke: "var(--surface)" }} />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}

/** Barres horizontales à une seule série (répartition par produit, pays, étape…). */
export function HBarChart({ data, currency = true }: { data: { label: string; value: number }[]; currency?: boolean }) {
  const height = Math.max(120, data.length * 38);
  return (
    <div style={{ height }}>
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data} layout="vertical" margin={{ left: 0, right: 16 }} barCategoryGap="30%">
          <CartesianGrid horizontal={false} stroke="var(--chart-grid)" />
          <XAxis type="number" {...axis} tickFormatter={(v) => num(v, true)} />
          <YAxis type="category" dataKey="label" {...axis} width={96} tick={{ fill: "var(--muted)", fontSize: 12 }} />
          <Tooltip cursor={{ fill: "var(--surface-2)" }} content={<Tip currency={currency} labels={{ value: currency ? "Montant" : "Valeur" }} />} />
          <Bar dataKey="value" fill="var(--series-1)" radius={[0, 4, 4, 0]} maxBarSize={18} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
