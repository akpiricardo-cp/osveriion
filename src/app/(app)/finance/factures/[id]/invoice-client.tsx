"use client";

import { useState, useTransition } from "react";
import { Ban, CheckCircle2, Plus, Printer, Send, Trash2, Undo2 } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import type { InvoiceStatus } from "@/lib/types";
import { money } from "@/lib/utils";
import { addInvoiceLine, deleteInvoiceLine, setInvoiceStatus } from "../../actions";

export function InvoiceActions({ id, status, admin }: { id: string; status: InvoiceStatus; admin: boolean }) {
  const [pending, start] = useTransition();
  const go = (s: InvoiceStatus, confirmMsg?: string) => {
    if (confirmMsg && !confirm(confirmMsg)) return;
    start(async () => { const r = await setInvoiceStatus(id, s); if (r.ok) toast.success(r.message); else toast.error(r.error); });
  };
  return (
    <>
      <Button size="sm" variant="outline" onClick={() => window.print()}><Printer className="h-4 w-4" /> Imprimer / PDF</Button>
      {admin && status === "draft" && <Button size="sm" loading={pending} onClick={() => go("sent")}><Send className="h-4 w-4" /> Marquer envoyée</Button>}
      {admin && (status === "sent" || status === "overdue") && <Button size="sm" variant="success" loading={pending} onClick={() => go("paid", "Confirmer l'encaissement ? Le revenu sera comptabilisé automatiquement.")}><CheckCircle2 className="h-4 w-4" /> Encaissée</Button>}
      {admin && status === "paid" && <Button size="sm" variant="outline" loading={pending} onClick={() => go("sent", "Annuler l'encaissement ? Le revenu associé sera retiré.")}><Undo2 className="h-4 w-4" /> Annuler l&apos;encaissement</Button>}
      {admin && status !== "cancelled" && status !== "paid" && <Button size="sm" variant="ghost" loading={pending} onClick={() => go("cancelled", "Annuler cette facture ?")}><Ban className="h-4 w-4" /></Button>}
      {admin && status === "cancelled" && <Button size="sm" variant="outline" loading={pending} onClick={() => go("draft")}>Rouvrir</Button>}
    </>
  );
}

type Line = { id: string; description: string; quantity: number; unit_price: number; amount: number };

export function InvoiceLines({ invoiceId, lines, editable, currency }: { invoiceId: string; lines: Line[]; editable: boolean; currency: string }) {
  const [desc, setDesc] = useState("");
  const [qty, setQty] = useState("1");
  const [price, setPrice] = useState("");
  const [pending, start] = useTransition();
  return (
    <div className="mt-8">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b-2 border-fg/80 text-left text-xs uppercase tracking-wider text-subtle">
            <th className="pb-2 font-medium">Désignation</th><th className="pb-2 text-right font-medium">Qté</th><th className="pb-2 text-right font-medium">Prix unitaire</th><th className="pb-2 text-right font-medium">Montant HT</th>{editable && <th className="w-8" />}
          </tr>
        </thead>
        <tbody>
          {lines.length === 0 && <tr><td colSpan={5} className="py-6 text-center text-muted">Aucune ligne.</td></tr>}
          {lines.map((l) => (
            <tr key={l.id} className="border-b border-border">
              <td className="py-3 text-fg">{l.description}</td>
              <td className="py-3 text-right tabular-nums text-muted">{Number(l.quantity)}</td>
              <td className="py-3 text-right tabular-nums text-muted">{money(l.unit_price, currency)}</td>
              <td className="py-3 text-right font-medium tabular-nums text-fg">{money(l.amount, currency)}</td>
              {editable && (
                <td className="py-3 text-right">
                  <button aria-label="Supprimer" className="text-subtle hover:text-danger" onClick={() => start(async () => { const r = await deleteInvoiceLine(l.id, invoiceId); if (!r.ok) toast.error(r.error); })}><Trash2 className="h-4 w-4" /></button>
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
      {editable && (
        <form
          className="mt-3 grid gap-2 print:hidden sm:grid-cols-[1fr_80px_160px_auto]"
          onSubmit={(e) => {
            e.preventDefault();
            start(async () => {
              const r = await addInvoiceLine(invoiceId, desc, Number(qty), Number(price.replace(/\s/g, "").replace(",", ".")));
              if (!r.ok) { toast.error(r.error); return; }
              setDesc(""); setQty("1"); setPrice("");
            });
          }}
        >
          <Input value={desc} onChange={(e) => setDesc(e.target.value)} placeholder="Désignation" required />
          <Input value={qty} onChange={(e) => setQty(e.target.value)} type="number" min="0.01" step="0.01" />
          <Input value={price} onChange={(e) => setPrice(e.target.value)} placeholder="Prix unitaire HT" inputMode="decimal" required />
          <Button type="submit" variant="outline" loading={pending}><Plus className="h-4 w-4" /> Ligne</Button>
        </form>
      )}
    </div>
  );
}
