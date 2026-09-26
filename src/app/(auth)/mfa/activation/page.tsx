"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Copy, Smartphone } from "lucide-react";
import { toast } from "sonner";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

export default function MfaEnrollPage() {
  const router = useRouter();
  const [factor, setFactor] = useState<{ id: string; qr: string; secret: string } | null>(null);
  const [code, setCode] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const started = useRef(false);

  useEffect(() => {
    if (started.current) return;
    started.current = true;
    (async () => {
      const supabase = createClient();
      const { data: list } = await supabase.auth.mfa.listFactors();
      if (list?.totp?.some((f) => f.status === "verified")) {
        router.replace("/");
        return;
      }
      // Nettoie les facteurs non vérifiés d'une tentative précédente
      for (const f of list?.all ?? []) {
        if (f.status === "unverified") await supabase.auth.mfa.unenroll({ factorId: f.id });
      }
      const { data, error } = await supabase.auth.mfa.enroll({ factorType: "totp", friendlyName: `VERIION ${Date.now()}` });
      if (error || !data) return setError(error?.message ?? "Impossible de démarrer l'activation.");
      setFactor({ id: data.id, qr: data.totp.qr_code, secret: data.totp.secret });
    })();
  }, [router]);

  async function verify(e: React.FormEvent) {
    e.preventDefault();
    if (!factor) return;
    setLoading(true);
    setError(null);
    const { error } = await createClient().auth.mfa.challengeAndVerify({ factorId: factor.id, code: code.replace(/\s/g, "") });
    setLoading(false);
    if (error) return setError("Code invalide, réessayez.");
    toast.success("Double authentification activée");
    router.replace("/");
    router.refresh();
  }

  return (
    <div>
      <div className="mb-6 grid h-12 w-12 place-items-center rounded-2xl bg-primary/10 text-primary">
        <Smartphone className="h-6 w-6" />
      </div>
      <h2 className="text-2xl font-semibold tracking-tight text-fg">Activez la double authentification</h2>
      <p className="mt-1.5 text-sm text-muted">
        Obligatoire chez VERIION. Scannez ce QR code avec Google Authenticator, Microsoft Authenticator, 1Password ou Authy.
      </p>
      <div className="mt-6 rounded-2xl border border-border bg-surface p-5">
        {factor ? (
          <>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={factor.qr} alt="QR code 2FA" className="mx-auto h-44 w-44 rounded-lg bg-white p-2" />
            <button
              type="button"
              onClick={() => { navigator.clipboard.writeText(factor.secret); toast.success("Clé copiée"); }}
              className="mx-auto mt-4 flex items-center gap-2 rounded-lg bg-surface-2 px-3 py-1.5 font-mono text-xs text-muted hover:text-fg"
            >
              {factor.secret.match(/.{1,4}/g)?.join(" ")} <Copy className="h-3.5 w-3.5" />
            </button>
          </>
        ) : (
          <div className="mx-auto h-44 w-44 animate-pulse rounded-lg bg-surface-3" />
        )}
      </div>
      <form onSubmit={verify} className="mt-5 space-y-4">
        <Input
          inputMode="numeric" autoComplete="one-time-code" maxLength={7} value={code} onChange={(e) => setCode(e.target.value)}
          placeholder="Code à 6 chiffres" className="h-12 text-center font-mono text-xl tracking-[0.4em]"
        />
        {error && <p className="rounded-lg bg-danger/10 px-3 py-2 text-[13px] text-danger">{error}</p>}
        <Button type="submit" size="lg" className="w-full" loading={loading} disabled={!factor || code.replace(/\s/g, "").length !== 6}>
          Activer
        </Button>
      </form>
    </div>
  );
}
