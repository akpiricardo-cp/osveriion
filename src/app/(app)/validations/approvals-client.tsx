"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Check, Plus, Stamp, X } from "lucide-react";
import { toast } from "sonner";
import { Avatar } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { ActionForm } from "@/components/ui/action-form";
import { Field, Input, Select, Textarea } from "@/components/ui/input";
import { EmptyState } from "@/components/ui/misc";
import { approvalKind, approvalStatus } from "@/lib/labels";
import { dateTimeFr, money, relative } from "@/lib/utils";
import type { ApprovalRequest, ProfileLite } from "@/lib/types";
import { cancelApproval, decideApproval, submitApproval } from "./actions";

/** Soumettre une décision au CEO sans passer par une fiche (dépense, budget, arbitrage). */
export function RequestApprovalButton({
  units, projects, threshold,
}: { units: { id: string; label: string }[]; projects: { id: string; name: string }[]; threshold: number }) {
  const [open, setOpen] = useState(false);
  const router = useRouter();
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm"><Plus className="h-4 w-4" /> Soumettre une décision</Button>
      </DialogTrigger>
      <DialogContent
        title="Soumettre une décision au CEO"
        description={`Au-delà de ${money(threshold)}, une dépense ou un budget exige son accord. Les contrats et calendriers mensuels se soumettent depuis leur fiche.`}
      >
        <ActionForm action={submitApproval} submitLabel="Transmettre" onSuccess={() => { setOpen(false); router.refresh(); }}>
          <Field label="Nature de la décision" htmlFor="kind" required>
            <Select id="kind" name="kind" defaultValue="expense">
              <option value="expense">Dépense</option>
              <option value="budget">Budget</option>
              <option value="project">Lancement de projet</option>
              <option value="employment_contract">Contrat de travail</option>
              <option value="other">Autre arbitrage</option>
            </Select>
          </Field>
          <Field label="Objet" htmlFor="subject_label" required hint="Ce que le CEO lira en premier.">
            <Input id="subject_label" name="subject_label" required placeholder="Renouvellement des serveurs de production" />
          </Field>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Montant" htmlFor="amount" hint="En XOF, si la décision engage une somme.">
              <Input id="amount" name="amount" inputMode="decimal" placeholder="750000" />
            </Field>
            <Field label="Projet concerné" htmlFor="project_id">
              <Select id="project_id" name="project_id" defaultValue="">
                <option value="">— Aucun</option>
                {projects.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
              </Select>
            </Field>
          </div>
          <Field label="Unité concernée" htmlFor="unit_id">
            <Select id="unit_id" name="unit_id" defaultValue="">
              <option value="">— Aucune</option>
              {units.map((u) => <option key={u.id} value={u.id}>{u.label}</option>)}
            </Select>
          </Field>
          <Field label="Justification" htmlFor="justification" hint="Pourquoi maintenant, et ce qui se passe sans accord.">
            <Textarea id="justification" name="justification" rows={3} />
          </Field>
        </ActionForm>
      </DialogContent>
    </Dialog>
  );
}

function DecisionDialog({
  request, approve, onDone,
}: { request: ApprovalRequest; approve: boolean; onDone: () => void }) {
  const [open, setOpen] = useState(false);
  const [note, setNote] = useState("");
  const [pending, start] = useTransition();

  function confirm() {
    start(async () => {
      const res = await decideApproval(request.id, approve, note);
      if (!res.ok) {
        toast.error(res.error);
        return;
      }
      toast.success(res.message);
      setOpen(false);
      setNote("");
      onDone();
    });
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm" variant={approve ? "success" : "outline"}>
          {approve ? <><Check className="h-4 w-4" /> Approuver</> : <><X className="h-4 w-4" /> Refuser</>}
        </Button>
      </DialogTrigger>
      <DialogContent
        title={approve ? "Approuver cette décision" : "Refuser cette décision"}
        description={request.subject_label}
        size="sm"
      >
        <Field
          label={approve ? "Mot au demandeur" : "Motif du refus"}
          htmlFor="note"
          required={!approve}
          hint={approve ? "Facultatif — une consigne, une réserve, une échéance." : "Obligatoire : la personne doit savoir quoi corriger."}
        >
          <Textarea id="note" rows={3} value={note} onChange={(e) => setNote(e.target.value)} autoFocus />
        </Field>
        <div className="mt-5 flex justify-end gap-2">
          <Button variant="ghost" onClick={() => setOpen(false)}>Annuler</Button>
          <Button variant={approve ? "success" : "danger"} loading={pending} onClick={confirm}>
            {approve ? "Donner mon accord" : "Refuser"}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}

export function ApprovalList({
  requests, people, units, projects, canDecide, userId,
}: {
  requests: ApprovalRequest[];
  people: Record<string, ProfileLite>;
  units: Record<string, string>;
  projects: Record<string, string>;
  canDecide: boolean;
  userId: string;
}) {
  const router = useRouter();
  const [pending, start] = useTransition();

  if (requests.length === 0) {
    return (
      <Card>
        <EmptyState
          icon={Stamp}
          title="Rien à trancher"
          description="Les décisions soumises au CEO apparaîtront ici, avec leur montant et leur justification."
        />
      </Card>
    );
  }

  return (
    <ul className="space-y-3">
      {requests.map((a) => {
        const author = a.requested_by ? people[a.requested_by] : null;
        const decider = a.decided_by ? people[a.decided_by] : null;
        const context = [a.project_id ? projects[a.project_id] : null, a.unit_id ? units[a.unit_id] : null].filter(Boolean).join(" · ");
        return (
          <li key={a.id}>
            <Card className="p-4 sm:p-5">
              <div className="flex flex-col gap-4 sm:flex-row sm:items-start">
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <Badge tone="violet">{approvalKind[a.kind]}</Badge>
                    <Badge tone={approvalStatus[a.status].tone} dot>{approvalStatus[a.status].label}</Badge>
                    {context && <span className="truncate text-xs text-subtle">{context}</span>}
                  </div>
                  <p className="mt-2 text-[15px] font-semibold leading-snug text-fg">{a.subject_label}</p>
                  {a.justification && <p className="mt-1 whitespace-pre-line text-sm leading-relaxed text-muted">{a.justification}</p>}
                  <div className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-subtle">
                    <span className="inline-flex items-center gap-1.5">
                      <Avatar name={author?.full_name ?? "—"} src={author?.avatar_url} size="xs" />
                      {author?.full_name ?? "Demandeur inconnu"}
                    </span>
                    <span>·</span>
                    <span>{relative(a.created_at)}</span>
                    {a.decided_at && (
                      <>
                        <span>·</span>
                        <span>{a.status === "approved" ? "Approuvée" : "Refusée"} par {decider?.full_name ?? "le CEO"} le {dateTimeFr(a.decided_at)}</span>
                      </>
                    )}
                  </div>
                  {a.decision_note && (
                    <p className="mt-3 rounded-lg bg-surface-2 px-3 py-2 text-[13px] text-fg">
                      <span className="font-medium">Réponse : </span>{a.decision_note}
                    </p>
                  )}
                </div>

                <div className="flex shrink-0 flex-col items-stretch gap-2 sm:items-end">
                  {a.amount != null && (
                    <p className="text-right text-lg font-semibold tabular-nums text-fg">{money(a.amount, a.currency)}</p>
                  )}
                  {a.status === "pending" && (
                    <div className="flex flex-wrap gap-2">
                      {canDecide && <DecisionDialog request={a} approve onDone={() => router.refresh()} />}
                      {canDecide && <DecisionDialog request={a} approve={false} onDone={() => router.refresh()} />}
                      {!canDecide && a.requested_by === userId && (
                        <Button
                          size="sm"
                          variant="ghost"
                          loading={pending}
                          onClick={() => start(async () => {
                            const res = await cancelApproval(a.id);
                            if (res.ok) { toast.success(res.message); router.refresh(); } else toast.error(res.error);
                          })}
                        >
                          Retirer
                        </Button>
                      )}
                    </div>
                  )}
                </div>
              </div>
            </Card>
          </li>
        );
      })}
    </ul>
  );
}
