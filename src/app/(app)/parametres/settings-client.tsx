"use client";

import { useEffect, useRef, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Camera, Crown, KeyRound, Laptop, Lock, LogOut, Scale, ShieldCheck, Smartphone } from "lucide-react";
import { toast } from "sonner";
import { createClient } from "@/lib/supabase/client";
import { Avatar } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardHeader } from "@/components/ui/card";
import { ActionForm } from "@/components/ui/action-form";
import { Field, Input, Select, Textarea } from "@/components/ui/input";
import type { GovernanceSettings as Governance, Profile, ProfileLite } from "@/lib/types";
import { money } from "@/lib/utils";
import { logout } from "@/lib/logout";
import { updateProfile } from "../annuaire/actions";
import { changeAccessCode, lockSpaceNow, saveGovernance, transferCeo } from "./actions";

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
      <MfaCard />
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

/** Second facteur : état, activation, retrait. */
function MfaCard() {
  const router = useRouter();
  const [factor, setFactor] = useState<{ id: string; created_at: string } | null | undefined>(undefined);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    void createClient().auth.mfa.listFactors().then(({ data }) => {
      const f = (data?.totp ?? []).find((x) => x.status === "verified");
      setFactor(f ? { id: f.id, created_at: f.created_at } : null);
    });
  }, []);

  async function remove() {
    if (!factor || !confirm("Retirer la double authentification ? Si votre fonction l'exige, elle vous sera redemandée.")) return;
    setBusy(true);
    const { error } = await createClient().auth.mfa.unenroll({ factorId: factor.id });
    setBusy(false);
    if (error) return toast.error("Validez d'abord votre code de sécurité (reconnectez-vous) pour retirer ce facteur.");
    toast.success("Double authentification retirée.");
    setFactor(null);
    router.refresh();
  }

  return (
    <Card>
      <CardHeader
        title="Double authentification"
        description="Un code à 6 chiffres, généré par une application sur votre téléphone, est demandé à chaque nouvelle session. Il est exigé pour les finances, les personnes, les contrats et les droits."
        icon={<Smartphone className="h-4 w-4" />}
        action={factor === undefined ? null : factor ? <Badge tone="green" dot>Activée</Badge> : <Badge tone="amber" dot>Inactive</Badge>}
      />
      <div className="flex flex-wrap gap-3 p-5">
        {factor === null && (
          <Link href="/double-authentification?suite=/parametres?onglet=securite" className="inline-flex h-9 items-center rounded-lg bg-primary px-4 text-sm font-medium text-primary-fg hover:bg-primary-hover">Activer</Link>
        )}
        {factor && <Button variant="outline" loading={busy} onClick={remove}>Retirer ce facteur</Button>}
      </div>
    </Card>
  );
}

/** Paramètres de gouvernance : réservés au CEO, journalisés. */
export function GovernanceSettings({ settings, people, currentUserId }: { settings: Governance; people: ProfileLite[]; currentUserId: string }) {
  const router = useRouter();
  const [successor, setSuccessor] = useState("");
  const [pending, start] = useTransition();

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader
          title="Règles de décision"
          description={`Seuil actuel : ${money(settings.ceo_approval_threshold)}. Au-delà, dépenses et budgets exigent votre accord. Chaque modification est inscrite au journal.`}
          icon={<Scale className="h-4 w-4" />}
        />
        <div className="p-5">
          <ActionForm action={saveGovernance} submitLabel="Enregistrer" onSuccess={() => router.refresh()}>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Seuil d'accord du CEO (XOF)" htmlFor="ceo_approval_threshold" required>
                <Input id="ceo_approval_threshold" name="ceo_approval_threshold" inputMode="decimal" defaultValue={String(settings.ceo_approval_threshold)} required />
              </Field>
              <Field label="Relance des décisions en attente (jours)" htmlFor="approval_reminder_days" required>
                <Input id="approval_reminder_days" name="approval_reminder_days" type="number" min={1} max={30} defaultValue={settings.approval_reminder_days} required />
              </Field>
              <Field label="Durée maximale d'une dérogation (jours)" htmlFor="max_grant_days" required>
                <Input id="max_grant_days" name="max_grant_days" type="number" min={1} max={366} defaultValue={settings.max_grant_days} required />
              </Field>
              <Field label="Double authentification des rôles sensibles" htmlFor="mfa_enforced">
                <Select id="mfa_enforced" name="mfa_enforced" defaultValue={settings.mfa_enforced ? "on" : "off"}>
                  <option value="on">Obligatoire (recommandé)</option>
                  <option value="off">Facultative</option>
                </Select>
              </Field>
            </div>
          </ActionForm>
        </div>
      </Card>

      <Card>
        <CardHeader
          title="Transmettre la fonction de CEO"
          description="Votre successeur devient CEO ; vous devenez administrateur. L'opération est définitive et journalisée."
          icon={<Crown className="h-4 w-4" />}
        />
        <div className="flex flex-col gap-3 p-5 sm:flex-row">
          <Select value={successor} onChange={(e) => setSuccessor(e.target.value)} aria-label="Successeur">
            <option value="">— Choisir le successeur</option>
            {people.filter((p) => p.id !== currentUserId).map((p) => <option key={p.id} value={p.id}>{p.full_name}</option>)}
          </Select>
          <Button
            variant="danger"
            disabled={!successor}
            loading={pending}
            onClick={() => {
              const name = people.find((p) => p.id === successor)?.full_name;
              if (!confirm(`Transmettre la fonction de CEO à ${name} ? Vous perdrez vos droits de CEO.`)) return;
              start(async () => {
                const r = await transferCeo(successor);
                if (!r.ok) return void toast.error(r.error);
                toast.success(r.message);
                router.push("/");
                router.refresh();
              });
            }}
          >
            Transmettre
          </Button>
        </div>
      </Card>
    </div>
  );
}
