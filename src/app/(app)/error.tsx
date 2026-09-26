"use client";

import { AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";

export default function AppError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div className="mx-auto mt-16 max-w-md rounded-2xl border border-border bg-surface p-8 text-center shadow-card">
      <div className="mx-auto mb-4 grid h-12 w-12 place-items-center rounded-2xl bg-amber-500/10 text-amber-600"><AlertTriangle className="h-6 w-6" /></div>
      <h2 className="text-lg font-semibold text-fg">Une erreur est survenue</h2>
      <p className="mt-2 text-sm text-muted">L&apos;incident a été enregistré. Réessayez ; si le problème persiste, contactez l&apos;équipe Technologie.</p>
      {error.digest && <p className="mt-3 font-mono text-xs text-subtle">Réf. {error.digest}</p>}
      <Button className="mt-6" onClick={reset}>Réessayer</Button>
    </div>
  );
}
