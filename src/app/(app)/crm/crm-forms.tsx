"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Pencil, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { ActionForm } from "@/components/ui/action-form";
import { Checkbox, Field, Input, Select, Textarea } from "@/components/ui/input";
import { PersonSelect } from "@/components/pickers";
import { accountType, COUNTRIES, PRODUCTS, stage as stageLabels } from "@/lib/labels";
import type { Account, Opportunity, ProfileLite } from "@/lib/types";
import { logInteraction, saveAccount, saveContact, saveOpportunity } from "./actions";

export function AccountFormButton({ account, people, variant }: { account?: Account; people: ProfileLite[]; variant?: "outline" }) {
  const [open, setOpen] = useState(false);
  const router = useRouter();
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        {account ? <Button size="sm" variant="outline"><Pencil className="h-4 w-4" /> Modifier</Button> : <Button size="sm" variant={variant}><Plus className="h-4 w-4" /> Nouveau compte</Button>}
      </DialogTrigger>
      <DialogContent title={account ? "Modifier le compte" : "Nouveau compte"} description="Prospect, client ou partenaire." size="lg">
        <ActionForm action={saveAccount} resetOnSuccess={!account} onSuccess={(r) => { setOpen(false); const id = r.ok && (r.data as { id: string })?.id; if (id && !account) router.push(`/crm/comptes/${id}`); }}>
          {account && <input type="hidden" name="id" value={account.id} />}
          <div className="grid gap-4 sm:grid-cols-[1fr_180px]">
            <Field label="Raison sociale" htmlFor="name" required><Input id="name" name="name" required defaultValue={account?.name} /></Field>
            <Field label="Type" htmlFor="type">
              <Select id="type" name="type" defaultValue={account?.type ?? "prospect"}>
                {Object.entries(accountType).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
              </Select>
            </Field>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <Field label="Secteur" htmlFor="industry"><Input id="industry" name="industry" defaultValue={account?.industry ?? ""} placeholder="Télécoms, Éducation…" /></Field>
            <Field label="Pays" htmlFor="country">
              <Select id="country" name="country" defaultValue={account?.country ?? "BJ"}>
                {Object.entries(COUNTRIES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
              </Select>
            </Field>
            <Field label="Ville" htmlFor="city"><Input id="city" name="city" defaultValue={account?.city ?? ""} /></Field>
            <Field label="Site web" htmlFor="website"><Input id="website" name="website" type="url" defaultValue={account?.website ?? ""} placeholder="https://" /></Field>
            <Field label="E-mail" htmlFor="email"><Input id="email" name="email" type="email" defaultValue={account?.email ?? ""} /></Field>
            <Field label="Téléphone" htmlFor="phone"><Input id="phone" name="phone" defaultValue={account?.phone ?? ""} /></Field>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Responsable du compte" htmlFor="owner_id"><PersonSelect people={people} name="owner_id" defaultValue={account?.owner_id} placeholder="Moi" /></Field>
            <Field label="Étiquettes" htmlFor="tags" hint="Séparées par des virgules"><Input id="tags" name="tags" defaultValue={account?.tags.join(", ")} /></Field>
          </div>
          <Field label="Notes" htmlFor="notes"><Textarea id="notes" name="notes" rows={3} defaultValue={account?.notes ?? ""} /></Field>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function OpportunityFormButton({
  accounts, people, accountId, opportunity, label = "Nouvelle opportunité", size = "sm",
}: { accounts: { id: string; name: string }[]; people: ProfileLite[]; accountId?: string; opportunity?: Opportunity; label?: string; size?: "sm" | "icon-sm" }) {
  const [open, setOpen] = useState(false);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        {opportunity ? <button className="rounded p-1 text-subtle hover:text-fg" aria-label="Modifier"><Pencil className="h-3.5 w-3.5" /></button>
          : <Button size={size}><Plus className="h-4 w-4" />{size === "sm" && ` ${label}`}</Button>}
      </DialogTrigger>
      <DialogContent title={opportunity ? "Modifier l'opportunité" : "Nouvelle opportunité"} size="lg">
        <ActionForm action={saveOpportunity} resetOnSuccess={!opportunity} onSuccess={() => setOpen(false)}>
          {opportunity && <input type="hidden" name="id" value={opportunity.id} />}
          <Field label="Intitulé" htmlFor="name" required><Input id="name" name="name" required defaultValue={opportunity?.name} placeholder="Ex. : Déploiement iSkul — 40 établissements" /></Field>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Compte" htmlFor="account_id" required>
              <Select id="account_id" name="account_id" required defaultValue={opportunity?.account_id ?? accountId ?? ""}>
                <option value="" disabled>Choisir…</option>
                {accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
              </Select>
            </Field>
            <Field label="Produit" htmlFor="product">
              <Select id="product" name="product" defaultValue={opportunity?.product ?? ""}>
                <option value="">—</option>
                {PRODUCTS.map((p) => <option key={p} value={p}>{p}</option>)}
              </Select>
            </Field>
          </div>
          <div className="grid gap-4 sm:grid-cols-4">
            <Field label="Montant (FCFA)" htmlFor="amount" className="sm:col-span-2"><Input id="amount" name="amount" inputMode="numeric" defaultValue={opportunity?.amount ?? ""} /></Field>
            <Field label="Probabilité %" htmlFor="probability"><Input id="probability" name="probability" type="number" min={0} max={100} defaultValue={opportunity?.probability ?? 20} /></Field>
            <Field label="Étape" htmlFor="stage">
              <Select id="stage" name="stage" defaultValue={opportunity?.stage ?? "lead"}>
                {Object.entries(stageLabels).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
              </Select>
            </Field>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Signature prévue" htmlFor="expected_close"><Input id="expected_close" name="expected_close" type="date" defaultValue={opportunity?.expected_close ?? ""} /></Field>
            <Field label="Responsable" htmlFor="owner_id"><PersonSelect people={people} name="owner_id" defaultValue={opportunity?.owner_id} placeholder="Moi" /></Field>
          </div>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function ContactFormButton({ accountId }: { accountId: string }) {
  const [open, setOpen] = useState(false);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><Button size="sm" variant="outline"><Plus className="h-4 w-4" /> Contact</Button></DialogTrigger>
      <DialogContent title="Nouveau contact">
        <ActionForm action={saveContact} onSuccess={() => setOpen(false)}>
          <input type="hidden" name="account_id" value={accountId} />
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Prénom" htmlFor="first_name" required><Input id="first_name" name="first_name" required /></Field>
            <Field label="Nom" htmlFor="last_name"><Input id="last_name" name="last_name" /></Field>
            <Field label="Fonction" htmlFor="job_title"><Input id="job_title" name="job_title" /></Field>
            <Field label="Téléphone" htmlFor="phone"><Input id="phone" name="phone" /></Field>
          </div>
          <Field label="E-mail" htmlFor="email"><Input id="email" name="email" type="email" /></Field>
          <Checkbox name="is_primary" label="Interlocuteur principal" />
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

export function InteractionForm({ accountId, contacts, opportunities }: { accountId: string; contacts: { id: string; name: string }[]; opportunities: { id: string; name: string }[] }) {
  return (
    <ActionForm action={logInteraction} submitLabel="Enregistrer" className="space-y-3">
      <input type="hidden" name="account_id" value={accountId} />
      <div className="grid gap-3 sm:grid-cols-[140px_1fr]">
        <Select name="kind" defaultValue="call">
          <option value="call">Appel</option>
          <option value="email">E-mail</option>
          <option value="meeting">Rendez-vous</option>
          <option value="note">Note</option>
        </Select>
        <Input name="subject" required placeholder="Objet de l'échange" />
      </div>
      <Textarea name="body" rows={3} placeholder="Compte rendu, prochaines étapes…" />
      <div className="grid gap-3 sm:grid-cols-3">
        <Select name="contact_id" defaultValue=""><option value="">Contact —</option>{contacts.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</Select>
        <Select name="opportunity_id" defaultValue=""><option value="">Opportunité —</option>{opportunities.map((o) => <option key={o.id} value={o.id}>{o.name}</option>)}</Select>
        <Input name="occurred_at" type="datetime-local" />
      </div>
    </ActionForm>
  );
}
