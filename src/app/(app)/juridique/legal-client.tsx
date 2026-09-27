"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { FileSignature, Gavel, MoreHorizontal, PenLine, Plus, Send, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { Badge, LabelBadge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { Dropdown, DropdownContent, DropdownItem, DropdownSeparator, DropdownTrigger } from "@/components/ui/dropdown";
import { ActionForm } from "@/components/ui/action-form";
import { Checkbox, Field, Input, Select, Textarea } from "@/components/ui/input";
import { EmptyState } from "@/components/ui/misc";
import { contractRisk, legalContractStatus, legalContractType } from "@/lib/labels";
import { dateFr, money } from "@/lib/utils";
import type { LegalContract, ProfileLite } from "@/lib/types";
import { deleteContract, saveContract, setContractStatus, signContract, submitContract } from "./actions";

export interface FormData {
  people: ProfileLite[];
  units: { id: string; label: string }[];
  projects: { id: string; name: string }[];
  accounts: { id: string; name: string }[];
}

export function ContractDialog({
  people, units, projects, accounts, contract, trigger,
}: FormData & { contract?: LegalContract; trigger?: React.ReactNode }) {
  const [open, setOpen] = useState(false);
  const router = useRouter();
  const c = contract;
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        {trigger ?? <Button size="sm"><Plus className="h-4 w-4" /> Nouveau contrat</Button>}
      </DialogTrigger>
      <DialogContent
        title={c ? `Contrat ${c.reference}` : "Enregistrer un contrat"}
        description="Le contrat entre au registre en brouillon. Il passe ensuite en revue juridique, puis à la signature du CEO."
        size="lg"
      >
        <ActionForm action={saveContract} submitLabel={c ? "Enregistrer" : "Créer le contrat"} onSuccess={() => { setOpen(false); router.refresh(); }}>
          {c && <input type="hidden" name="id" value={c.id} />}
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Titre" htmlFor="title" required className="sm:col-span-2">
              <Input id="title" name="title" required defaultValue={c?.title} placeholder="Accord de partenariat technique" />
            </Field>
            <Field label="Partie signataire" htmlFor="counterparty" required hint="L'entreprise ou la personne en face.">
              <Input id="counterparty" name="counterparty" required defaultValue={c?.counterparty} />
            </Field>
            <Field label="Nature" htmlFor="type" required>
              <Select id="type" name="type" defaultValue={c?.type ?? "other"}>
                {Object.entries(legalContractType).map(([k, label]) => <option key={k} value={k}>{label}</option>)}
              </Select>
            </Field>
            <Field label="Juriste en charge" htmlFor="owner_id">
              <Select id="owner_id" name="owner_id" defaultValue={c?.owner_id ?? ""}>
                <option value="">— À attribuer</option>
                {people.map((p) => <option key={p.id} value={p.id}>{p.full_name}</option>)}
              </Select>
            </Field>
            <Field label="Niveau de risque" htmlFor="risk">
              <Select id="risk" name="risk" defaultValue={c?.risk ?? "low"}>
                <option value="low">Faible</option>
                <option value="medium">Moyen</option>
                <option value="high">Élevé</option>
              </Select>
            </Field>
            <Field label="Projet concerné" htmlFor="project_id">
              <Select id="project_id" name="project_id" defaultValue={c?.project_id ?? ""}>
                <option value="">— Aucun</option>
                {projects.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
              </Select>
            </Field>
            <Field label="Département porteur" htmlFor="unit_id">
              <Select id="unit_id" name="unit_id" defaultValue={c?.unit_id ?? ""}>
                <option value="">— Aucun</option>
                {units.map((u) => <option key={u.id} value={u.id}>{u.label}</option>)}
              </Select>
            </Field>
            <Field label="Compte CRM lié" htmlFor="account_id">
              <Select id="account_id" name="account_id" defaultValue={c?.account_id ?? ""}>
                <option value="">— Aucun</option>
                {accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
              </Select>
            </Field>
            <Field label="Montant engagé" htmlFor="amount" hint="En XOF, si le contrat porte une somme.">
              <Input id="amount" name="amount" inputMode="decimal" defaultValue={c?.amount ?? ""} />
            </Field>
            <Field label="Prise d'effet" htmlFor="effective_date">
              <Input id="effective_date" name="effective_date" type="date" defaultValue={c?.effective_date ?? ""} />
            </Field>
            <Field label="Échéance" htmlFor="end_date">
              <Input id="end_date" name="end_date" type="date" defaultValue={c?.end_date ?? ""} />
            </Field>
            <Field label="Préavis (jours)" htmlFor="renewal_notice_days" hint="Alerte avant l'échéance.">
              <Input id="renewal_notice_days" name="renewal_notice_days" inputMode="numeric" defaultValue={c?.renewal_notice_days ?? 30} />
            </Field>
            <div className="flex items-end pb-1">
              <Checkbox name="auto_renew" label="Reconduction tacite" defaultChecked={c?.auto_renew} />
            </div>
          </div>
          <Field label="Engagements à tenir" htmlFor="obligations" hint="Ce que VERIION doit livrer, payer ou respecter.">
            <Textarea id="obligations" name="obligations" rows={3} defaultValue={c?.obligations ?? ""} />
          </Field>
          <Field label="Notes internes" htmlFor="notes">
            <Textarea id="notes" name="notes" rows={2} defaultValue={c?.notes ?? ""} />
          </Field>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

function ContractMenu({ contract, formData }: { contract: LegalContract; formData: FormData }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const run = (fn: () => Promise<{ ok: boolean; message?: string; error?: string }>, confirmMsg?: string) => {
    if (confirmMsg && !confirm(confirmMsg)) return;
    start(async () => {
      const r = await fn();
      if (r.ok) { toast.success(r.message); router.refresh(); } else toast.error(r.error);
    });
  };
  const c = contract;

  return (
    <Dropdown>
      <DropdownTrigger disabled={pending} className="rounded-md p-1.5 text-subtle hover:bg-surface-2 hover:text-fg" aria-label="Actions">
        <MoreHorizontal className="h-4 w-4" />
      </DropdownTrigger>
      <DropdownContent>
        <ContractDialog
          {...formData}
          contract={c}
          trigger={
            <DropdownItem onSelect={(e) => e.preventDefault()}>
              <PenLine className="h-4 w-4 text-subtle" /> Modifier
            </DropdownItem>
          }
        />
        {c.status === "draft" && (
          <DropdownItem onSelect={() => run(() => setContractStatus(c.id, "legal_review"))}>
            <Gavel className="h-4 w-4 text-subtle" /> Passer en revue juridique
          </DropdownItem>
        )}
        {(c.status === "draft" || c.status === "legal_review") && (
          <DropdownItem onSelect={() => run(() => submitContract(c.id))}>
            <Send className="h-4 w-4 text-subtle" /> Envoyer à la signature du CEO
          </DropdownItem>
        )}
        {c.status === "pending_ceo" && (
          <DropdownItem onSelect={() => run(() => signContract(c.id), "L'accord du CEO est-il donné ? Le contrat passera en vigueur.")}>
            <FileSignature className="h-4 w-4 text-subtle" /> Acter la signature
          </DropdownItem>
        )}
        {(c.status === "signed" || c.status === "active") && (
          <>
            <DropdownSeparator />
            <DropdownItem onSelect={() => run(() => setContractStatus(c.id, "terminated"), "Résilier ce contrat ?")}>
              <Trash2 className="h-4 w-4 text-subtle" /> Enregistrer la résiliation
            </DropdownItem>
          </>
        )}
        {c.status === "draft" && (
          <>
            <DropdownSeparator />
            <DropdownItem danger onSelect={() => run(() => deleteContract(c.id), "Supprimer définitivement ce brouillon ?")}>
              <Trash2 className="h-4 w-4" /> Supprimer
            </DropdownItem>
          </>
        )}
      </DropdownContent>
    </Dropdown>
  );
}

export function ContractList({
  contracts, people, projects, editable, formData,
}: {
  contracts: LegalContract[];
  people: Record<string, ProfileLite>;
  projects: Record<string, string>;
  editable: boolean;
  formData: FormData;
}) {
  if (contracts.length === 0) {
    return (
      <Card>
        <EmptyState icon={Gavel} title="Aucun contrat ici" description="Les contrats de la holding, leurs échéances et leur niveau de risque se suivent depuis ce registre." />
      </Card>
    );
  }

  const today = new Date().toISOString().slice(0, 10);

  return (
    <ul className="space-y-3">
      {contracts.map((c) => {
        const owner = c.owner_id ? people[c.owner_id] : null;
        const late = c.end_date && c.end_date < today;
        return (
          <li key={c.id}>
            <Card className="p-4 sm:p-5">
              <div className="flex items-start gap-3">
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-mono text-[11px] text-subtle">{c.reference}</span>
                    <LabelBadge map={legalContractStatus} value={c.status} />
                    <Badge tone="neutral">{legalContractType[c.type]}</Badge>
                    {c.risk !== "low" && <LabelBadge map={contractRisk} value={c.risk} />}
                    {c.auto_renew && <Badge tone="cyan">Tacite reconduction</Badge>}
                  </div>
                  <p className="mt-2 text-[15px] font-semibold leading-snug text-fg">{c.title}</p>
                  <p className="mt-0.5 text-sm text-muted">avec {c.counterparty}</p>

                  <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-subtle">
                    {c.project_id && projects[c.project_id] && <span>Projet : {projects[c.project_id]}</span>}
                    {owner && <span>Juriste : {owner.full_name}</span>}
                    {c.effective_date && <span>Effet : {dateFr(c.effective_date)}</span>}
                    {c.end_date && (
                      <span className={late ? "font-medium text-danger" : undefined}>
                        Échéance : {dateFr(c.end_date)}
                      </span>
                    )}
                  </div>
                  {c.obligations && (
                    <p className="mt-3 line-clamp-2 rounded-lg bg-surface-2 px-3 py-2 text-[13px] text-muted">{c.obligations}</p>
                  )}
                </div>

                <div className="flex shrink-0 flex-col items-end gap-2">
                  {c.amount != null && <p className="text-right font-semibold tabular-nums text-fg">{money(c.amount, c.currency)}</p>}
                  {editable && <ContractMenu contract={c} formData={formData} />}
                </div>
              </div>
            </Card>
          </li>
        );
      })}
    </ul>
  );
}
