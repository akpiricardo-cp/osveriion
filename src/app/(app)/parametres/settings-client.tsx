"use client";

import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Camera, KeyRound, Laptop, Lock, LogOut, ShieldCheck } from "lucide-react";
import { toast } from "sonner";
import { createClient } from "@/lib/supabase/client";
import { Avatar } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardHeader } from "@/components/ui/card";
import { ActionForm } from "@/components/ui/action-form";
import { Field, Input, Textarea } from "@/components/ui/input";
import type { Profile } from "@/lib/types";
import { logout } from "@/lib/logout";
import { updateProfile } from "../annuaire/actions";
import { changeAccessCode, lockSpaceNow } from "./actions";

export function ProfileSettings({ profile: p }: { profile: Profile }) {
  const router = useRouter();
  const input = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);

  async function onAvatar(file: File) {
    if (!file.type.startsWith("image/")) return toast.error("Choisissez une image.");
    if (file.size > 5 * 1024 * 1024) return toast.error("Image trop lourde (5 Mo max).");
    setUploading(true);
    const supabase = createClient();
    const path = `${p.id}/avatar-${Date.now()}.${file.name.split(".").pop() ?? "jpg"}`;
    const { error } = await supabase.storage.from("avatars").upload(path, file, { upsert: true, contentType: file.type });
    if (error) { setUploading(false); return toast.error(error.message); }
    const { data } = supabase.storage.from("avatars").getPublicUrl(path);
    const { error: e2 } = await supabase.from("profiles").update({ avatar_url: data.publicUrl }).eq("id", p.id);
    setUploading(false);
    if (e2) return toast.error(e2.message);
    toast.success("Photo mise à jour.");
    router.refresh();
  }

  return (
    <Card>
      <CardHeader title="Profil public" description="Visible par tous les collaborateurs dans l'annuaire." />
      <div className="p-5">
        <div className="mb-6 flex items-center gap-4">
          <Avatar name={p.full_name} src={p.avatar_url} size="xl" />
          <div>
            <input ref={input} type="file" accept="image/*" className="hidden" onChange={(e) => e.target.files?.[0] && onAvatar(e.target.files[0])} />
            <Button size="sm" variant="outline" loading={uploading} onClick={() => input.current?.click()}><Camera className="h-4 w-4" /> Changer la photo</Button>
            <p className="mt-1.5 text-xs text-subtle">JPG ou PNG, carré de préférence, 5 Mo max.</p>
          </div>
        </div>
        <ActionForm action={updateProfile} resetOnSuccess={false} onSuccess={() => router.refresh()}>
          <input type="hidden" name="id" value={p.id} />
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Prénom" htmlFor="first_name"><Input id="first_name" name="first_name" defaultValue={p.first_name} required /></Field>
            <Field label="Nom" htmlFor="last_name"><Input id="last_name" name="last_name" defaultValue={p.last_name} /></Field>
            <Field label="Intitulé de poste" htmlFor="job_title" hint="Attribué automatiquement à votre nomination."><Input id="job_title" value={p.job_title ?? "—"} disabled /></Field>
            <Field label="Téléphone" htmlFor="phone" required><Input id="phone" name="phone" type="tel" required defaultValue={p.phone ?? ""} /></Field>
            <Field label="Localisation" htmlFor="location" required><Input id="location" name="location" required defaultValue={p.location ?? ""} placeholder="Cotonou, Bénin" /></Field>
            <Field label="E-mail" htmlFor="email" hint="Géré par l'administration."><Input id="email" value={p.email} disabled /></Field>
          </div>
          <Field label="Présentation" htmlFor="bio"><Textarea id="bio" name="bio" rows={3} defaultValue={p.bio ?? ""} /></Field>
        </ActionForm>
      </div>
    </Card>
  );
}

export function SecuritySettings({ hasCode, email }: { hasCode: boolean; email: string }) {
  const router = useRouter();
  const [pwd, setPwd] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const [locking, startLocking] = useTransition();

  async function changePassword(e: React.FormEvent) {
    e.preventDefault();
    if (pwd.length < 12) return toast.error("12 caractères minimum.");
    setBusy("pwd");
    const { error } = await createClient().auth.updateUser({ password: pwd });
    setBusy(null);
    if (error) return toast.error(error.message);
    setPwd("");
    toast.success("Mot de passe modifié.");
  }

  async function signOutOthers() {
    setBusy("others");
    const { error } = await createClient().auth.signOut({ scope: "others" });
    setBusy(null);
    if (error) return toast.error(error.message);
    toast.success("Toutes vos autres sessions ont été fermées.");
  }

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader
          title="Code d'accès"
          description="Connu de vous seul, il est demandé à chaque nouvelle session pour rouvrir votre espace — sans jamais vous déconnecter."
          icon={<ShieldCheck className="h-4 w-4" />}
          action={hasCode ? <Badge tone="green" dot>Défini</Badge> : <Badge tone="red" dot>À définir</Badge>}
        />
        <div className="p-5">
          <ActionForm
            action={changeAccessCode}
            submitLabel={hasCode ? "Changer le code" : "Définir le code"}
            onSuccess={() => router.refresh()}
          >
            <div className="grid gap-4 sm:grid-cols-2">
              {hasCode && (
                <Field label="Code actuel" htmlFor="current" className="sm:col-span-2">
                  <Input id="current" name="current" type="password" required autoComplete="off" maxLength={32} />
                </Field>
              )}
              <Field label="Nouveau code" htmlFor="code" hint="6 à 32 caractères, sans espace.">
                <Input id="code" name="code" type="password" required autoComplete="new-password" minLength={6} maxLength={32} />
              </Field>
              <Field label="Confirmation" htmlFor="confirm">
                <Input id="confirm" name="confirm" type="password" required autoComplete="new-password" minLength={6} maxLength={32} />
              </Field>
            </div>
          </ActionForm>
          <p className="mt-4 text-xs text-subtle">
            Code oublié ? Un administrateur peut le réinitialiser : vous en choisirez un nouveau à votre prochaine ouverture.
          </p>
        </div>
      </Card>

      <Card>
        <CardHeader title="Mot de passe" icon={<KeyRound className="h-4 w-4" />} description={email} />
        <form onSubmit={changePassword} className="flex flex-col gap-3 p-5 sm:flex-row">
          <Input type="password" value={pwd} onChange={(e) => setPwd(e.target.value)} placeholder="Nouveau mot de passe (12 caractères min.)" autoComplete="new-password" />
          <Button type="submit" loading={busy === "pwd"}>Modifier</Button>
        </form>
      </Card>

      <Card>
        <CardHeader title="Sessions" description="Verrouillez cet appareil ou déconnectez ceux que vous n'utilisez plus." icon={<Laptop className="h-4 w-4" />} />
        <div className="flex flex-col gap-3 p-5 sm:flex-row">
          <Button variant="outline" loading={locking} onClick={() => startLocking(() => { void lockSpaceNow(); })}>
            <Lock className="h-4 w-4" /> Verrouiller maintenant
          </Button>
          <Button variant="outline" loading={busy === "others"} onClick={signOutOthers}><LogOut className="h-4 w-4" /> Déconnecter les autres appareils</Button>
          <Button variant="ghost" onClick={() => { void logout(); }}>Me déconnecter ici</Button>
        </div>
        <p className="px-5 pb-5 text-xs text-subtle">
          Verrouiller ne ferme pas la session : votre code suffit pour revenir dans votre espace.
        </p>
      </Card>
    </div>
  );
}
