"use client";

import { useState } from "react";
import Link from "next/link";
import { ArrowLeft, MailCheck } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { Field, Input } from "@/components/ui/input";

export default function ForgotPasswordPage() {
  const [sent, setSent] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    const email = String(new FormData(e.currentTarget).get("email")).trim().toLowerCase();
    const site = process.env.NEXT_PUBLIC_SITE_URL ?? window.location.origin;
    const { error } = await createClient().auth.resetPasswordForEmail(email, {
      redirectTo: `${site}/auth/callback?suite=/definir-mot-de-passe`,
    });
    setLoading(false);
    if (error) setError(error.message);
    else setSent(true);
  }

  if (sent) {
    return (
      <div className="text-center">
        <div className="mx-auto mb-5 grid h-12 w-12 place-items-center rounded-2xl bg-emerald-500/10 text-emerald-600">
          <MailCheck className="h-6 w-6" />
        </div>
        <h2 className="text-xl font-semibold text-fg">Vérifiez votre boîte e-mail</h2>
        <p className="mt-2 text-sm text-muted">Si un compte existe pour cette adresse, un lien de réinitialisation vient d&apos;être envoyé.</p>
        <Link href="/connexion" className="mt-6 inline-block text-sm font-medium text-primary hover:underline">Retour à la connexion</Link>
      </div>
    );
  }

  return (
    <div>
      <Link href="/connexion" className="mb-8 inline-flex items-center gap-1.5 text-[13px] text-muted hover:text-fg">
        <ArrowLeft className="h-4 w-4" /> Retour
      </Link>
      <h2 className="text-2xl font-semibold tracking-tight text-fg">Mot de passe oublié</h2>
      <p className="mt-1.5 text-sm text-muted">Recevez un lien sécurisé pour choisir un nouveau mot de passe.</p>
      <form onSubmit={onSubmit} className="mt-8 space-y-4">
        <Field label="Adresse e-mail professionnelle" htmlFor="email">
          <Input id="email" name="email" type="email" required className="h-11" />
        </Field>
        {error && <p className="rounded-lg bg-danger/10 px-3 py-2 text-[13px] text-danger">{error}</p>}
        <Button type="submit" size="lg" className="w-full" loading={loading}>Envoyer le lien</Button>
      </form>
    </div>
  );
}
