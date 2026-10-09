"use client";

import { useEffect, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { ShieldCheck, Smartphone } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Field, Input } from "@/components/ui/input";
import { createClient } from "@/lib/supabase/client";

type Enrollment = { factorId: string; qr: string; secret: string };

/**
 * Double authentification par application (Google Authenticator, Microsoft
 * Authenticator, 1Password…). Première fois : on scanne le QR code puis on saisit
 * le code à 6 chiffres. Ensuite : le code est demandé à chaque nouvelle session.
 */
export function MfaScreen({ factorId, required, email, suite }: { factorId: string | null; required: boolean; email: string; suite: string }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [enrollment, setEnrollment] = useState<Enrollment | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [code, setCode] = useState("");

  useEffect(() => {
    if (factorId) return;
    const supabase = createClient();
    (async () => {
      // Nettoie une inscription restée inachevée avant d'en commencer une nouvelle.
      const { data } = await supabase.auth.mfa.listFactors();
      for (const f of data?.all ?? []) if (f.status !== "verified") await supabase.auth.mfa.unenroll({ factorId: f.id });
      const { data: en, error: e } = await supabase.auth.mfa.enroll({ factorType: "totp", friendlyName: `VERIION OS ${new Date().toISOString().slice(0, 10)}` });
      if (e || !en) return setError(e?.message ?? "Impossible de préparer la double authentification.");
      setEnrollment({ factorId: en.id, qr: en.totp.qr_code, secret: en.totp.secret });
    })();
  }, [factorId]);

  function verify(e: React.FormEvent) {
    e.preventDefault();
    const id = factorId ?? enrollment?.factorId;
    if (!id) return;
    if (!/^\d{6}$/.test(code)) return setError("Saisissez les 6 chiffres affichés par votre application.");
    setError(null);
    start(async () => {
      const supabase = createClient();
      const { error: err } = await supabase.auth.mfa.challengeAndVerify({ factorId: id, code });
      if (err) return setError("Code incorrect ou expiré. Réessayez avec le code actuel.");
      if (!factorId) toast.success("Double authentification activée.");
      router.replace(suite);
      router.refresh();
    });
  }

  return (
    <div>
      <div className="mb-6 flex h-12 w-12 items-center justify-center rounded-2xl bg-primary/10 text-primary">
        <ShieldCheck className="h-6 w-6" />
      </div>
      <h1 className="text-2xl font-semibold tracking-tight text-fg">
        {factorId ? "Code de sécurité" : "Activer la double authentification"}
      </h1>
      <p className="mt-2 text-sm leading-relaxed text-muted">
        {factorId
          ? "Ouvrez votre application d'authentification et saisissez le code à 6 chiffres affiché pour VERIION OS."
          : required
            ? "Votre fonction vous donne accès à des opérations sensibles (finances, personnes, contrats ou droits). Elles exigent un second facteur."
            : "Protégez votre compte avec un second facteur, en plus de votre mot de passe."}
      </p>

      {!factorId && (
        <div className="mt-6 rounded-xl border border-border p-4">
          <p className="mb-3 flex items-center gap-2 text-sm font-medium text-fg">
            <Smartphone className="h-4 w-4" /> Scannez ce code avec votre application
          </p>
          {enrollment ? (
            <>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={enrollment.qr} alt="QR code de la double authentification" className="mx-auto h-44 w-44 rounded-lg bg-white p-2" />
              <p className="mt-3 text-center text-xs text-subtle">Ou saisissez la clé : <span className="select-all font-mono text-fg">{enrollment.secret}</span></p>
              <p className="mt-1 text-center text-xs text-subtle">Compte : {email}</p>
            </>
          ) : (
            <p className="py-10 text-center text-sm text-subtle">{error ?? "Préparation…"}</p>
          )}
        </div>
      )}

      <form onSubmit={verify} className="mt-6 space-y-4">
        <Field label="Code à 6 chiffres" htmlFor="code" required>
          <Input
            id="code" name="code" inputMode="numeric" autoComplete="one-time-code" autoFocus maxLength={6}
            value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
            className="h-12 text-center font-mono text-xl tracking-[0.5em]"
          />
        </Field>
        {error && (factorId || enrollment) && <p className="text-sm text-danger">{error}</p>}
        <Button type="submit" className="w-full" loading={pending} disabled={!factorId && !enrollment}>
          {factorId ? "Valider" : "Activer"}
        </Button>
      </form>
      <form action="/auth/deconnexion" method="post" className="mt-4 text-center">
        <button className="text-xs text-subtle hover:text-fg">Se déconnecter</button>
      </form>
    </div>
  );
}
