"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { ArrowRight, Lock, Mail } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { Field, Input } from "@/components/ui/input";
import { LogoMark } from "@/components/logo";

const ERRORS: Record<string, string> = {
  inactif: "Votre compte est suspendu ou désactivé. Contactez l'administration.",
  profil: "Profil introuvable. Contactez l'administration.",
  lien: "Ce lien est invalide ou a expiré. Demandez-en un nouveau.",
};

export function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(ERRORS[params.get("erreur") ?? ""] ?? null);
  const domain = process.env.NEXT_PUBLIC_EMAIL_DOMAIN ?? "veriion.com";

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const fd = new FormData(e.currentTarget);
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithPassword({
      email: String(fd.get("email")).trim().toLowerCase(),
      password: String(fd.get("password")),
    });
    if (error) {
      setLoading(false);
      setError(error.message === "Invalid login credentials" ? "Identifiants incorrects." : error.message);
      return;
    }
    // L'espace s'ouvre après la saisie du code d'accès personnel (écran /verrou,
    // imposé par le middleware tant que la session n'est pas déverrouillée).
    router.replace(params.get("suite") || "/");
    router.refresh();
  }

  return (
    <div>
      <LogoMark className="mb-8 h-10 w-10 lg:hidden" />
      <h2 className="text-2xl font-semibold tracking-tight text-fg">Bon retour</h2>
      <p className="mt-1.5 text-sm text-muted">Connectez-vous avec votre identité VERIION.</p>

      <form onSubmit={onSubmit} className="mt-8 space-y-4">
        <Field label="Adresse e-mail professionnelle" htmlFor="email">
          <div className="relative">
            <Mail className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-subtle" />
            <Input id="email" name="email" type="email" required autoComplete="email" placeholder={`prenom.nom@${domain}`} className="h-11 pl-9" />
          </div>
        </Field>
        <Field label="Mot de passe" htmlFor="password">
          <div className="relative">
            <Lock className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-subtle" />
            <Input id="password" name="password" type="password" required autoComplete="current-password" className="h-11 pl-9" />
          </div>
        </Field>
        <div className="flex justify-end">
          <Link href="/mot-de-passe-oublie" className="text-[13px] font-medium text-primary hover:underline">
            Mot de passe oublié ?
          </Link>
        </div>
        {error && <p className="rounded-lg bg-danger/10 px-3 py-2 text-[13px] text-danger">{error}</p>}
        <Button type="submit" size="lg" className="w-full" loading={loading}>
          Se connecter <ArrowRight className="h-4 w-4" />
        </Button>
      </form>
      <p className="mt-8 text-center text-xs text-subtle">
        Accès réservé aux collaborateurs VERIION. Toute connexion est journalisée.
      </p>
    </div>
  );
}
