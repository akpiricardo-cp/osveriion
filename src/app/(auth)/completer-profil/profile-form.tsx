"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { ArrowRight, UserRoundPen } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Field, Input, Textarea } from "@/components/ui/input";
import { completeProfile } from "./actions";

type Initial = {
  first_name: string;
  last_name: string;
  phone: string;
  location: string;
  bio: string;
  birth_date: string;
};

export function ProfileForm({ email, jobTitle, initial }: { email: string; jobTitle: string | null; initial: Initial }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);

  function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    setError(null);
    start(async () => {
      const res = await completeProfile(null, fd);
      if (!res.ok) return setError(res.error);
      toast.success(res.message);
      router.replace("/");
      router.refresh();
    });
  }

  return (
    <div>
      <div className="mb-6 grid h-12 w-12 place-items-center rounded-2xl bg-primary/10 text-primary">
        <UserRoundPen className="h-6 w-6" />
      </div>
      <h2 className="text-2xl font-semibold tracking-tight text-fg">Complétez votre profil</h2>
      <p className="mt-1.5 text-sm text-muted">
        Vos collègues vous trouvent dans l&apos;annuaire, vous mentionnent et vous joignent grâce à ces informations.
        Elles sont demandées une seule fois.
      </p>

      <form onSubmit={submit} className="mt-8 space-y-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Prénom" htmlFor="first_name" required>
            <Input id="first_name" name="first_name" required autoFocus defaultValue={initial.first_name} className="h-11" autoComplete="given-name" />
          </Field>
          <Field label="Nom" htmlFor="last_name" required>
            <Input id="last_name" name="last_name" required defaultValue={initial.last_name} className="h-11" autoComplete="family-name" />
          </Field>
        </div>
        <Field label="Téléphone" htmlFor="phone" required hint="Joignable pendant les heures de travail.">
          <Input id="phone" name="phone" type="tel" required defaultValue={initial.phone} placeholder="+229 01 00 00 00 00" className="h-11" autoComplete="tel" />
        </Field>
        <Field label="Localisation" htmlFor="location" required>
          <Input id="location" name="location" required defaultValue={initial.location} placeholder="Cotonou, Bénin" className="h-11" />
        </Field>
        <Field label="Date de naissance" htmlFor="birth_date" hint="Facultatif — sert aux anniversaires de l'équipe.">
          <Input id="birth_date" name="birth_date" type="date" defaultValue={initial.birth_date} className="h-11" />
        </Field>
        <Field label="Présentation" htmlFor="bio" hint="Facultatif — une ou deux phrases sur ce que vous faites.">
          <Textarea id="bio" name="bio" rows={3} defaultValue={initial.bio} />
        </Field>

        <div className="rounded-xl border border-border bg-surface-2/60 p-3 text-[13px] text-muted">
          <p><span className="font-medium text-fg">{email}</span> — géré par l&apos;administration.</p>
          <p className="mt-1">
            Poste : <span className="font-medium text-fg">{jobTitle ?? "attribué lors de votre nomination"}</span>. Il
            suit automatiquement votre place dans l&apos;organigramme.
          </p>
        </div>

        {error && <p className="rounded-lg bg-danger/10 px-3 py-2 text-[13px] text-danger">{error}</p>}
        <Button type="submit" size="lg" className="w-full" loading={pending}>
          Entrer dans mon espace <ArrowRight className="h-4 w-4" />
        </Button>
      </form>
    </div>
  );
}
