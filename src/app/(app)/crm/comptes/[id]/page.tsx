import Link from "next/link";
import { notFound } from "next/navigation";
import { Calendar, FileText, Globe, Mail, MapPin, MessageSquareText, Phone, PhoneCall, Receipt, Star, StickyNote, Target, Users } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { can, getContext } from "@/lib/auth";
import { getPeople, peopleMap } from "@/lib/data";
import { accountType, COUNTRIES, invoiceStatus, stage as stageLabels } from "@/lib/labels";
import type { Account, Invoice, Opportunity } from "@/lib/types";
import { dateFr, dateTimeFr, money } from "@/lib/utils";
import { Avatar } from "@/components/ui/avatar";
import { Badge, LabelBadge } from "@/components/ui/badge";
import { Card, CardHeader } from "@/components/ui/card";
import { Forbidden, PageHeader } from "@/components/ui/misc";
import { AccountFormButton, ContactFormButton, InteractionForm, OpportunityFormButton } from "../../crm-forms";
import { DeleteContact } from "./account-client";

const KIND_ICON = { call: PhoneCall, email: Mail, meeting: Calendar, note: StickyNote } as const;
const KIND_LABEL = { call: "Appel", email: "E-mail", meeting: "Rendez-vous", note: "Note" } as const;

export default async function AccountPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const ctx = await getContext();
  if (!(can(ctx, "crm.view") || can(ctx, "crm.edit") || can(ctx, "dashboard.exec"))) return <Forbidden />;
  const supabase = await createClient();
  const { data: acc } = await supabase.from("accounts").select("*").eq("id", id).maybeSingle();
  if (!acc) notFound();
  const a = acc as Account;
  const [{ data: contacts }, { data: opps }, { data: interactions }, { data: invoices }, { data: docs }, people] = await Promise.all([
    supabase.from("contacts").select("*").eq("account_id", id).order("is_primary", { ascending: false }),
    supabase.from("opportunities").select("*").eq("account_id", id).order("created_at", { ascending: false }),
    supabase.from("interactions").select("*").eq("account_id", id).order("occurred_at", { ascending: false }).limit(30),
    supabase.from("invoices").select("*").eq("account_id", id).order("issue_date", { ascending: false }),
    supabase.from("documents").select("id, title, category, created_at").eq("account_id", id),
    getPeople(),
  ]);
  const pm = peopleMap(people);
  const canEdit = can(ctx, "crm.edit") || a.owner_id === ctx.userId;
  const owner = a.owner_id ? pm.get(a.owner_id) : null;
  const opportunities = (opps as Opportunity[]) ?? [];
  const contactsList = contacts ?? [];

  return (
    <div className="space-y-6">
      <PageHeader
        crumbs={[{ label: "CRM", href: "/crm" }, { label: "Comptes", href: "/crm/comptes" }, { label: a.name }]}
        title={<span className="flex items-center gap-3">{a.name} <LabelBadge map={accountType} value={a.type} /></span>}
        description={[a.industry, a.country ? COUNTRIES[a.country] ?? a.country : null].filter(Boolean).join(" · ")}
        actions={canEdit ? (
          <>
            <OpportunityFormButton accounts={[{ id: a.id, name: a.name }]} people={people} accountId={a.id} />
            <AccountFormButton account={a} people={people} />
          </>
        ) : undefined}
      />

      <div className="grid gap-6 xl:grid-cols-[1fr_1.6fr]">
        <div className="space-y-6">
          <Card>
            <CardHeader title="Informations" />
            <div className="space-y-3 p-5 text-sm">
              {a.website && <p className="flex items-center gap-3"><Globe className="h-4 w-4 text-subtle" /><a href={a.website} target="_blank" rel="noreferrer" className="truncate text-primary hover:underline">{a.website.replace(/^https?:\/\//, "")}</a></p>}
              {a.email && <p className="flex items-center gap-3"><Mail className="h-4 w-4 text-subtle" /><a href={`mailto:${a.email}`} className="hover:underline">{a.email}</a></p>}
              {a.phone && <p className="flex items-center gap-3"><Phone className="h-4 w-4 text-subtle" />{a.phone}</p>}
              {(a.city || a.country) && <p className="flex items-center gap-3"><MapPin className="h-4 w-4 text-subtle" />{[a.city, a.country ? COUNTRIES[a.country] : null].filter(Boolean).join(", ")}</p>}
              {owner && <p className="flex items-center gap-3"><Avatar name={owner.full_name} src={owner.avatar_url} size="xs" /><span className="text-muted">Responsable : <span className="font-medium text-fg">{owner.full_name}</span></span></p>}
              {a.tags.length > 0 && <div className="flex flex-wrap gap-1.5 pt-1">{a.tags.map((t) => <Badge key={t}>{t}</Badge>)}</div>}
            </div>
            {a.notes && <p className="whitespace-pre-line border-t border-border px-5 py-4 text-sm text-muted">{a.notes}</p>}
          </Card>

          <Card>
            <CardHeader title="Contacts" icon={<Users className="h-4 w-4" />} action={canEdit ? <ContactFormButton accountId={a.id} /> : undefined} />
            <ul className="divide-y divide-border pt-3">
              {contactsList.length === 0 && <li className="px-5 py-4 text-sm text-muted">Aucun contact.</li>}
              {contactsList.map((c) => (
                <li key={c.id} className="flex items-center gap-3 px-5 py-3">
                  <Avatar name={`${c.first_name} ${c.last_name ?? ""}`} size="sm" />
                  <div className="min-w-0 flex-1">
                    <p className="flex items-center gap-1.5 text-sm font-medium text-fg">{c.first_name} {c.last_name}{c.is_primary && <Star className="h-3.5 w-3.5 fill-amber-400 text-amber-400" />}</p>
                    <p className="truncate text-xs text-subtle">{[c.job_title, c.email, c.phone].filter(Boolean).join(" · ")}</p>
                  </div>
                  {canEdit && <DeleteContact id={c.id} accountId={a.id} />}
                </li>
              ))}
            </ul>
          </Card>

          {(invoices?.length ?? 0) > 0 && (
            <Card>
              <CardHeader title="Factures" icon={<Receipt className="h-4 w-4" />} />
              <ul className="divide-y divide-border pt-3">
                {(invoices as Invoice[]).map((i) => (
                  <li key={i.id}>
                    <Link href={`/finance/factures/${i.id}`} className="flex items-center gap-3 px-5 py-3 hover:bg-surface-2/60">
                      <span className="font-mono text-xs text-muted">{i.number}</span>
                      <span className="flex-1 text-right text-sm font-medium tabular-nums text-fg">{money(i.total, i.currency)}</span>
                      <LabelBadge map={invoiceStatus} value={i.status} />
                    </Link>
                  </li>
                ))}
              </ul>
            </Card>
          )}

          {(docs?.length ?? 0) > 0 && (
            <Card>
              <CardHeader title="Documents & contrats" icon={<FileText className="h-4 w-4" />} />
              <ul className="space-y-1 p-3">
                {docs!.map((d) => (
                  <li key={d.id}><Link href={`/documents?doc=${d.id}`} className="flex items-center gap-2 rounded-lg px-2 py-2 text-sm text-fg hover:bg-surface-2/60"><FileText className="h-4 w-4 text-subtle" />{d.title}</Link></li>
                ))}
              </ul>
            </Card>
          )}
        </div>

        <div className="space-y-6">
          <Card>
            <CardHeader title="Opportunités" icon={<Target className="h-4 w-4" />} description={`${opportunities.length} au total`} />
            <ul className="divide-y divide-border pt-3">
              {opportunities.length === 0 && <li className="px-5 py-4 text-sm text-muted">Aucune opportunité.</li>}
              {opportunities.map((o) => (
                <li key={o.id} className="flex items-center gap-3 px-5 py-3">
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium text-fg">{o.name}</p>
                    <p className="text-xs text-subtle">{o.product ?? "—"} · {o.probability} %{o.expected_close && ` · ${dateFr(o.expected_close)}`}</p>
                  </div>
                  <span className="text-sm font-semibold tabular-nums text-fg">{money(o.amount, o.currency, true)}</span>
                  <LabelBadge map={stageLabels} value={o.stage} />
                  {o.project_id && <Link href={`/projets/${o.project_id}`} className="text-xs font-medium text-primary hover:underline">Projet</Link>}
                  {canEdit && <OpportunityFormButton accounts={[{ id: a.id, name: a.name }]} people={people} opportunity={o} />}
                </li>
              ))}
            </ul>
          </Card>

          <Card>
            <CardHeader title="Historique des interactions" icon={<MessageSquareText className="h-4 w-4" />} />
            <div className="border-b border-border p-5">
              <InteractionForm accountId={a.id} contacts={contactsList.map((c) => ({ id: c.id, name: `${c.first_name} ${c.last_name ?? ""}` }))} opportunities={opportunities.map((o) => ({ id: o.id, name: o.name }))} />
            </div>
            <ol className="relative space-y-5 p-5 pl-10">
              <span className="absolute bottom-6 left-[27px] top-6 w-px bg-border" />
              {(interactions ?? []).length === 0 && <li className="text-sm text-muted">Aucune interaction enregistrée.</li>}
              {(interactions ?? []).map((i) => {
                const Icon = KIND_ICON[i.kind as keyof typeof KIND_ICON] ?? StickyNote;
                const author = i.author_id ? pm.get(i.author_id) : null;
                return (
                  <li key={i.id} className="relative">
                    <span className="absolute -left-[26px] grid h-6 w-6 place-items-center rounded-full bg-surface ring-1 ring-border"><Icon className="h-3.5 w-3.5 text-primary" /></span>
                    <p className="text-sm font-medium text-fg">{i.subject}</p>
                    <p className="text-xs text-subtle">{KIND_LABEL[i.kind as keyof typeof KIND_LABEL]} · {dateTimeFr(i.occurred_at)} · {author?.full_name ?? "—"}</p>
                    {i.body && <p className="mt-1.5 whitespace-pre-line text-sm text-muted">{i.body}</p>}
                  </li>
                );
              })}
            </ol>
          </Card>
        </div>
      </div>
    </div>
  );
}
