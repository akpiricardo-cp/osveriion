"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Camera, KeyRound, Laptop, LogOut, ShieldCheck, ShieldX, Smartphone } from "lucide-react";
import { toast } from "sonner";
import { createClient } from "@/lib/supabase/client";
import { Avatar } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button, ButtonLink } from "@/components/ui/button";
import { Card, CardHeader } from "@/components/ui/card";
import { ActionForm } from "@/components/ui/action-form";
import { Field, Input, Textarea } from "@/components/ui/input";
import type { Profile } from "@/lib/types";
import { dateFr } from "@/lib/utils";
import { updateProfile } from "../annuaire/actions";

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
            <Field label="Intitulé de poste" htmlFor="job_title"><Input id="job_title" name="job_title" defaultValue={p.job_title ?? ""} /></Field>
            <Field label="Téléphone" htmlFor="phone"><Input id="phone" name="phone" defaultValue={p.phone ?? ""} /></Field>
            <Field label="Localisation" htmlFor="location"><Input id="location" name="location" defaultValue={p.location ?? ""} /></Field>
            <Field label="E-mail" htmlFor="email" hint="Géré par l'administration."><Input id="email" value={p.email} disabled /></Field>
          </div>
          <Field label="Présentation" htmlFor="bio"><Textarea id="bio" name="bio" rows={3} defaultValue={p.bio ?? ""} /></Field>
        </ActionForm>
      </div>
    </Card>
  );
}

export function SecuritySettings({ factors, email }: { factors: { id: string; name: string; status: string; created_at: string }[]; email: string }) {
  const router = useRouter();
  const [pwd, setPwd] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const verified = factors.filter((f) => f.status === "verified");

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

  async function removeFactor(id: string) {
    if (process.env.NEXT_PUBLIC_REQUIRE_MFA !== "false" && verified.length <= 1 && !confirm("La double authentification est obligatoire : vous devrez en configurer une nouvelle immédiatement. Continuer ?")) return;
    setBusy(id);
    const { error } = await createClient().auth.mfa.unenroll({ factorId: id });
    setBusy(null);
    if (error) return toast.error(error.message);
    toast.success("Facteur supprimé.");
    router.refresh();
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
        <CardHeader title="Double authentification" description="Protège votre compte même si votre mot de passe est compromis." icon={<ShieldCheck className="h-4 w-4" />}
          action={verified.length ? <Badge tone="green" dot>Activée</Badge> : <Badge tone="red" dot>Désactivée</Badge>} />
        <div className="space-y-3 p-5">
          {verified.map((f) => (
            <div key={f.id} className="flex items-center gap-3 rounded-xl border border-border p-3">
              <Smartphone className="h-5 w-5 text-primary" />
              <div className="flex-1"><p className="text-sm font-medium text-fg">Application d&apos;authentification</p><p className="text-xs text-subtle">Ajoutée le {dateFr(f.created_at)}</p></div>
              <Button size="sm" variant="ghost" loading={busy === f.id} onClick={() => removeFactor(f.id)}><ShieldX className="h-4 w-4" /> Retirer</Button>
            </div>
          ))}
          {verified.length === 0 && <ButtonLink href="/mfa/activation" size="sm">Activer la double authentification</ButtonLink>}
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
        <CardHeader title="Sessions" description="Déconnectez les appareils que vous n'utilisez plus." icon={<Laptop className="h-4 w-4" />} />
        <div className="flex flex-col gap-3 p-5 sm:flex-row">
          <Button variant="outline" loading={busy === "others"} onClick={signOutOthers}><LogOut className="h-4 w-4" /> Déconnecter les autres appareils</Button>
          <Button variant="ghost" onClick={async () => { await createClient().auth.signOut(); window.location.href = "/connexion"; }}>Me déconnecter ici</Button>
        </div>
      </Card>
    </div>
  );
}
