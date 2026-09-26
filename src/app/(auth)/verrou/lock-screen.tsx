"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { ArrowRight, Eye, EyeOff, KeyRound, Lock } from "lucide-react";
import { toast } from "sonner";
import { Avatar } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Field, Input } from "@/components/ui/input";
import { ACCESS_CODE_RULE } from "@/lib/access-code";
import type { ActionResult } from "@/lib/types";
import { createAccessCode, unlockSpace } from "./actions";

function CodeInput({
  id, name, autoFocus, placeholder = "Votre code",
}: { id: string; name: string; autoFocus?: boolean; placeholder?: string }) {
  const [shown, setShown] = useState(false);
  return (
    <div className="relative">
      <Input
        id={id} name={name} type={shown ? "text" : "password"} required autoFocus={autoFocus}
        autoComplete="off" minLength={6} maxLength={32} placeholder={placeholder}
        className="h-12 pr-11 text-center font-mono text-lg tracking-[0.35em] placeholder:tracking-normal placeholder:font-sans placeholder:text-base"
      />
      <button
        type="button" onClick={() => setShown((s) => !s)}
        className="absolute right-3 top-1/2 -translate-y-1/2 text-subtle transition hover:text-fg"
        aria-label={shown ? "Masquer le code" : "Afficher le code"}
      >
        {shown ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
      </button>
    </div>
  );
}

export function LockScreen({
  hasCode, suite, name, email, avatar,
}: { hasCode: boolean; suite: string; name: string | null; email: string; avatar: string | null }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);

  function submit(action: (prev: ActionResult | null, fd: FormData) => Promise<ActionResult>) {
    return (e: React.FormEvent<HTMLFormElement>) => {
      e.preventDefault();
      const fd = new FormData(e.currentTarget);
      const code = String(fd.get("code") ?? "");
      if (!hasCode && !ACCESS_CODE_RULE.test(code)) return setError("Le code doit contenir de 6 à 32 caractères, sans espace.");
      setError(null);
      start(async () => {
        const res = await action(null, fd);
        if (!res.ok) return setError(res.error);
        if (res.message) toast.success(res.message);
        router.replace(suite);
        router.refresh();
      });
    };
  }

  return (
    <div>
      <div className="mb-6 grid h-12 w-12 place-items-center rounded-2xl bg-primary/10 text-primary">
        {hasCode ? <Lock className="h-6 w-6" /> : <KeyRound className="h-6 w-6" />}
      </div>

      {hasCode ? (
        <>
          <h2 className="text-2xl font-semibold tracking-tight text-fg">Votre espace est verrouillé</h2>
          <p className="mt-1.5 text-sm text-muted">
            Vous restez connecté{name ? `, ${name}` : ""} : saisissez simplement votre code d&apos;accès pour reprendre là où vous en étiez.
          </p>
          <div className="mt-6 flex items-center gap-3 rounded-xl border border-border bg-surface p-3">
            <Avatar name={name ?? email} src={avatar} size="md" />
            <div className="min-w-0">
              <p className="truncate text-sm font-medium text-fg">{name ?? email}</p>
              <p className="truncate text-xs text-subtle">{email}</p>
            </div>
          </div>
          <form onSubmit={submit(unlockSpace)} className="mt-6 space-y-4">
            <CodeInput id="code" name="code" autoFocus />
            {error && <p className="rounded-lg bg-danger/10 px-3 py-2 text-[13px] text-danger">{error}</p>}
            <Button type="submit" size="lg" className="w-full" loading={pending}>
              Accéder à mon espace <ArrowRight className="h-4 w-4" />
            </Button>
          </form>
          <p className="mt-6 text-center text-xs text-subtle">
            Code oublié ? Demandez sa réinitialisation à l&apos;administration : votre travail reste intact.
          </p>
        </>
      ) : (
        <>
          <h2 className="text-2xl font-semibold tracking-tight text-fg">Créez votre code d&apos;accès</h2>
          <p className="mt-1.5 text-sm text-muted">
            Un code connu de vous seul, demandé à chaque nouvelle session pour rouvrir votre espace. Il ne remplace pas
            votre mot de passe et ne vous déconnecte jamais.
          </p>
          <form onSubmit={submit(createAccessCode)} className="mt-8 space-y-4">
            <Field label="Nouveau code" htmlFor="code" hint="6 à 32 caractères, chiffres ou lettres. Évitez 123456 ou une date connue.">
              <CodeInput id="code" name="code" autoFocus placeholder="Choisissez un code" />
            </Field>
            <Field label="Confirmation" htmlFor="confirm">
              <CodeInput id="confirm" name="confirm" placeholder="Répétez le code" />
            </Field>
            {error && <p className="rounded-lg bg-danger/10 px-3 py-2 text-[13px] text-danger">{error}</p>}
            <Button type="submit" size="lg" className="w-full" loading={pending}>
              Enregistrer et continuer <ArrowRight className="h-4 w-4" />
            </Button>
          </form>
        </>
      )}

      <form action="/auth/deconnexion" method="post" className="mt-4">
        <button type="submit" className="w-full text-center text-[13px] text-muted transition hover:text-fg">
          Utiliser un autre compte
        </button>
      </form>
    </div>
  );
}
