"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { ShieldCheck } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

function MfaVerify() {
  const router = useRouter();
  const params = useSearchParams();
  const [factorId, setFactorId] = useState<string | null>(null);
  const [code, setCode] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    createClient().auth.mfa.listFactors().then(({ data }) => {
      const f = data?.totp?.find((x) => x.status === "verified");
      if (f) setFactorId(f.id);
      else router.replace("/mfa/activation");
    });
  }, [router]);

  async function verify(e: React.FormEvent) {
    e.preventDefault();
    if (!factorId) return;
    setLoading(true);
    setError(null);
    const { error } = await createClient().auth.mfa.challengeAndVerify({ factorId, code: code.replace(/\s/g, "") });
    setLoading(false);
    if (error) return setError("Code invalide. Vérifiez l'heure de votre téléphone et réessayez.");
    router.replace(params.get("suite") || "/");
    router.refresh();
  }

  async function signOut() {
    await createClient().auth.signOut();
    router.replace("/connexion");
  }

  return (
    <div>
      <div className="mb-6 grid h-12 w-12 place-items-center rounded-2xl bg-primary/10 text-primary">
        <ShieldCheck className="h-6 w-6" />
      </div>
      <h2 className="text-2xl font-semibold tracking-tight text-fg">Double authentification</h2>
      <p className="mt-1.5 text-sm text-muted">Saisissez le code à 6 chiffres de votre application d&apos;authentification.</p>
      <form onSubmit={verify} className="mt-8 space-y-4">
        <Input
          autoFocus inputMode="numeric" autoComplete="one-time-code" maxLength={7} value={code}
          onChange={(e) => setCode(e.target.value)} placeholder="000 000"
          className="h-14 text-center font-mono text-2xl tracking-[0.5em]"
        />
        {error && <p className="rounded-lg bg-danger/10 px-3 py-2 text-[13px] text-danger">{error}</p>}
        <Button type="submit" size="lg" className="w-full" loading={loading} disabled={code.replace(/\s/g, "").length !== 6}>
          Vérifier
        </Button>
      </form>
      <button onClick={signOut} className="mt-6 w-full text-center text-[13px] text-muted hover:text-fg">
        Utiliser un autre compte
      </button>
    </div>
  );
}

export default function MfaPage() {
  return (
    <Suspense>
      <MfaVerify />
    </Suspense>
  );
}
