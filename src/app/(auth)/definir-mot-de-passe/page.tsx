"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { KeyRound } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { Field, Input } from "@/components/ui/input";

function strength(p: string) {
  let s = 0;
  if (p.length >= 12) s++;
  if (/[A-Z]/.test(p) && /[a-z]/.test(p)) s++;
  if (/\d/.test(p)) s++;
  if (/[^A-Za-z0-9]/.test(p)) s++;
  return s;
}

export default function SetPasswordPage() {
  const router = useRouter();
  const [pwd, setPwd] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const score = strength(pwd);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const confirm = String(new FormData(e.currentTarget).get("confirm"));
    if (pwd !== confirm) return setError("Les deux mots de passe ne correspondent pas.");
    if (score < 3) return setError("Choisissez un mot de passe plus robuste (12 caractères, majuscules, chiffres, symboles).");
    setLoading(true);
    const { error } = await createClient().auth.updateUser({ password: pwd });
    setLoading(false);
    if (error) return setError(error.message);
    router.replace("/");
    router.refresh();
  }

  return (
    <div>
      <div className="mb-6 grid h-12 w-12 place-items-center rounded-2xl bg-primary/10 text-primary">
        <KeyRound className="h-6 w-6" />
      </div>
      <h2 className="text-2xl font-semibold tracking-tight text-fg">Définissez votre mot de passe</h2>
      <p className="mt-1.5 text-sm text-muted">Il protège l&apos;accès à l&apos;ensemble de l&apos;écosystème interne.</p>
      <form onSubmit={onSubmit} className="mt-8 space-y-4">
        <Field label="Nouveau mot de passe" htmlFor="password">
          <Input id="password" type="password" required minLength={12} value={pwd} onChange={(e) => setPwd(e.target.value)} className="h-11" autoComplete="new-password" />
          <div className="mt-2 flex gap-1">
            {[0, 1, 2, 3].map((i) => (
              <div key={i} className={`h-1 flex-1 rounded-full ${i < score ? (score >= 3 ? "bg-emerald-500" : "bg-amber-500") : "bg-surface-3"}`} />
            ))}
          </div>
        </Field>
        <Field label="Confirmation" htmlFor="confirm">
          <Input id="confirm" name="confirm" type="password" required className="h-11" autoComplete="new-password" />
        </Field>
        {error && <p className="rounded-lg bg-danger/10 px-3 py-2 text-[13px] text-danger">{error}</p>}
        <Button type="submit" size="lg" className="w-full" loading={loading}>Enregistrer et continuer</Button>
      </form>
    </div>
  );
}
