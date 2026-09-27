import Link from "next/link";
import {
  AlarmClock, ArrowRight, CalendarDays, CheckCircle2, CheckSquare, Megaphone, Pin, ShieldCheck, Sparkles, Stamp,
  Video,
} from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { can, canDecideApprovals, getContext } from "@/lib/auth";
import { getPeople, getUnits, peopleMap, unitOptions } from "@/lib/data";
import { priority, taskStatus } from "@/lib/labels";
import { cn, dateFr, isOverdue, relative } from "@/lib/utils";
import { Card, CardHeader } from "@/components/ui/card";
import { Avatar } from "@/components/ui/avatar";
import { Badge, LabelBadge } from "@/components/ui/badge";
import { ButtonLink } from "@/components/ui/button";
import { EmptyState, Progress, StatCard } from "@/components/ui/misc";
import { AnnouncementComposer, AnnouncementActions } from "./home-client";
import { LifecycleChecklist } from "./rh/lifecycle-checklist";

export const metadata = { title: "Accueil" };

function greeting() {
  const h = Number(new Intl.DateTimeFormat("fr-FR", { hour: "numeric", hour12: false, timeZone: "Africa/Porto-Novo" }).format(new Date()));
  return h < 12 ? "Bonjour" : h < 18 ? "Bon après-midi" : "Bonsoir";
}

export default async function HomePage() {
  const ctx = await getContext();
  const supabase = await createClient();
  const now = new Date();
  const in7 = new Date(now.getTime() + 7 * 86400000).toISOString();
  const today = now.toISOString().slice(0, 10);

  const [tasksRes, meetingsRes, annRes, onboardingRes, leavesRes, reviewRes, approvalRes, cycleRes, people, units] = await Promise.all([
    supabase.from("tasks").select("id, title, status, priority, due_date, project_id, projects(name, color)")
      .eq("assignee_id", ctx.userId).neq("status", "done").order("due_date", { ascending: true, nullsFirst: false }).limit(8),
    supabase.from("meetings").select("id, title, starts_at, ends_at, video_url, location")
      .gte("ends_at", now.toISOString()).lte("starts_at", in7).order("starts_at").limit(5),
    supabase.from("announcements").select("*").order("pinned", { ascending: false }).order("published_at", { ascending: false }).limit(5),
    supabase.from("lifecycle_items").select("*").eq("profile_id", ctx.userId).eq("kind", "onboarding").order("position"),
    supabase.from("leave_requests").select("id", { count: "exact", head: true }).eq("status", "pending").neq("profile_id", ctx.userId),
    supabase.from("tasks").select("id", { count: "exact", head: true })
      .eq("status", "review").or(`reviewer_id.eq.${ctx.userId},reporter_id.eq.${ctx.userId}`),
    supabase.from("approval_requests").select("id", { count: "exact", head: true }).eq("status", "pending"),
    supabase.from("operation_cycles")
      .select("id, title, focus, project_id, period_end, projects(name)")
      .eq("status", "published").gte("period_end", today).order("period_start", { ascending: false }).limit(1),
    getPeople(),
    getUnits(),
  ]);

  type TaskRow = { id: string; title: string; status: keyof typeof taskStatus; priority: keyof typeof priority; due_date: string | null; project_id: string | null; projects: { name: string; color: string } | null };
  const tasks = (tasksRes.data as unknown as TaskRow[]) ?? [];
  const meetings = meetingsRes.data ?? [];
  const announcements = annRes.data ?? [];
  const onboarding = onboardingRes.data ?? [];
  const pendingLeaves = leavesRes.count ?? 0;
  const toReview = reviewRes.count ?? 0;
  const toDecide = canDecideApprovals(ctx) ? approvalRes.count ?? 0 : 0;
  const cycle = (cycleRes.data as unknown as
    { id: string; title: string; focus: string | null; project_id: string; projects: { name: string } | null }[] | null)?.[0] ?? null;
  const pm = peopleMap(people);
  const overdue = tasks.filter((t) => isOverdue(t.due_date)).length;
  const dueToday = tasks.filter((t) => t.due_date === today).length;
  const onboardingDone = onboarding.filter((i) => i.done_at).length;
  const canPublish = can(ctx, "announcements.publish") || ctx.grants.some((g) => g.permission === "announcements.publish");

  return (
    <div className="space-y-8">
      <div className="relative overflow-hidden rounded-3xl bg-brand px-6 py-7 text-white sm:px-8">
        <div className="bg-grid absolute inset-0 opacity-60 [mask-image:linear-gradient(to_left,black,transparent)]" />
        <div className="absolute -right-24 -top-24 h-72 w-72 rounded-full bg-indigo-600/30 blur-3xl" />
        <div className="relative flex flex-col gap-6 md:flex-row md:items-center md:justify-between">
          <div>
            <p className="text-sm text-indigo-200/80">{dateFr(now, "EEEE d MMMM yyyy")}</p>
            <h1 className="mt-1 text-2xl font-semibold tracking-tight sm:text-3xl">
              {greeting()}, {ctx.profile.first_name || ctx.profile.full_name}
            </h1>
            <p className="mt-2 max-w-xl text-sm text-slate-300">
              {tasks.length === 0
                ? "Aucune tâche ouverte ne vous est assignée. Belle journée !"
                : `Vous avez ${tasks.length} tâche${tasks.length > 1 ? "s" : ""} ouverte${tasks.length > 1 ? "s" : ""}${overdue ? `, dont ${overdue} en retard` : ""}.`}
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <ButtonLink href="/taches" variant="secondary" className="border-white/10 bg-white/10 text-white hover:bg-white/15">
              <CheckSquare className="h-4 w-4" /> Mes tâches
            </ButtonLink>
            <ButtonLink href="/messages" className="bg-indigo-500 hover:bg-indigo-400">
              Messages <ArrowRight className="h-4 w-4" />
            </ButtonLink>
          </div>
        </div>
      </div>

      {(toReview > 0 || toDecide > 0 || cycle) && (
        <div className="flex flex-col gap-2 rounded-2xl border border-border bg-surface p-4 shadow-card sm:flex-row sm:items-center sm:gap-5">
          {toReview > 0 && (
            <Link href="/taches?onglet=verifier" className="group flex items-center gap-2.5 text-sm">
              <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-amber-500/10 text-amber-600">
                <ShieldCheck className="h-4 w-4" />
              </span>
              <span>
                <span className="block font-medium text-fg group-hover:underline">
                  {toReview} tâche{toReview > 1 ? "s" : ""} à vérifier
                </span>
                <span className="block text-xs text-subtle">soumises par votre équipe</span>
              </span>
            </Link>
          )}
          {toDecide > 0 && (
            <Link href="/validations" className="group flex items-center gap-2.5 text-sm">
              <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-violet-500/10 text-violet-600">
                <Stamp className="h-4 w-4" />
              </span>
              <span>
                <span className="block font-medium text-fg group-hover:underline">
                  {toDecide} décision{toDecide > 1 ? "s" : ""} à trancher
                </span>
                <span className="block text-xs text-subtle">budgets, contrats, calendriers, projets</span>
              </span>
            </Link>
          )}
          {cycle && (
            <Link href={`/projets/${cycle.project_id}?onglet=operations`} className="group flex min-w-0 items-center gap-2.5 text-sm sm:ml-auto">
              <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-cyan-500/10 text-cyan-600">
                <CalendarDays className="h-4 w-4" />
              </span>
              <span className="min-w-0">
                <span className="block truncate font-medium text-fg group-hover:underline">
                  Cap en cours : {cycle.title}
                </span>
                <span className="block truncate text-xs text-subtle">{cycle.projects?.name ?? "Projet"}{cycle.focus ? ` — ${cycle.focus}` : ""}</span>
              </span>
            </Link>
          )}
        </div>
      )}

      <div className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        <StatCard label="Tâches ouvertes" value={tasks.length} icon={CheckSquare} href="/taches" hint="qui vous sont assignées" />
        <StatCard label="En retard" value={overdue} icon={AlarmClock} tone={overdue ? "red" : "green"} hint={dueToday ? `${dueToday} à rendre aujourd'hui` : "échéance dépassée"} />
        <StatCard label="Réunions (7 jours)" value={meetings.length} icon={CalendarDays} tone="cyan" href="/reunions" hint="à venir" />
        <StatCard label="Congés à valider" value={pendingLeaves} icon={CheckCircle2} tone="amber" href="/rh?onglet=validation" hint="demandes en attente" />
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.4fr_1fr]">
        <div className="space-y-6">
          <Card>
            <CardHeader title="Mes priorités" description="Tâches ouvertes triées par échéance" icon={<Sparkles className="h-4 w-4" />}
              action={<Link href="/taches" className="text-[13px] font-medium text-primary hover:underline">Tout voir</Link>} />
            <div className="mt-3">
              {tasks.length === 0 ? (
                <EmptyState icon={CheckCircle2} title="Rien d'urgent" description="Les tâches qui vous sont assignées apparaîtront ici." />
              ) : (
                <ul className="divide-y divide-border">
                  {tasks.map((t) => (
                    <li key={t.id}>
                      <Link href={t.project_id ? `/projets/${t.project_id}?tache=${t.id}` : "/taches"} className="flex items-center gap-3 px-5 py-3 transition hover:bg-surface-2/60">
                        <span className="h-2 w-2 shrink-0 rounded-full" style={{ background: t.projects?.color ?? "var(--subtle)" }} />
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-sm font-medium text-fg">{t.title}</p>
                          <p className="truncate text-xs text-subtle">{t.projects?.name ?? "Tâche personnelle"}</p>
                        </div>
                        <LabelBadge map={taskStatus} value={t.status} />
                        <span className={cn("hidden w-24 text-right text-xs sm:block", isOverdue(t.due_date) ? "font-medium text-danger" : "text-muted")}>
                          {t.due_date ? dateFr(t.due_date, "d MMM") : "—"}
                        </span>
                      </Link>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </Card>

          <Card>
            <CardHeader title="Annonces de la direction" description="Informations officielles de l'entreprise" icon={<Megaphone className="h-4 w-4" />}
              action={canPublish ? <AnnouncementComposer units={unitOptions(units)} /> : undefined} />
            <div className="mt-3">
              {announcements.length === 0 ? (
                <EmptyState icon={Megaphone} title="Aucune annonce" description="Les annonces publiées par la direction s'afficheront ici." />
              ) : (
                <ul className="divide-y divide-border">
                  {announcements.map((a) => {
                    const author = a.author_id ? pm.get(a.author_id) : null;
                    return (
                      <li key={a.id} className="px-5 py-4">
                        <div className="flex items-start gap-3">
                          <Avatar name={author?.full_name ?? "VERIION"} src={author?.avatar_url} size="sm" />
                          <div className="min-w-0 flex-1">
                            <div className="flex flex-wrap items-center gap-2">
                              <p className="text-sm font-semibold text-fg">{a.title}</p>
                              {a.pinned && <Badge tone="violet"><Pin className="h-3 w-3" /> Épinglée</Badge>}
                            </div>
                            <p className="mt-1 whitespace-pre-line text-sm leading-relaxed text-muted">{a.body}</p>
                            <p className="mt-2 text-xs text-subtle">{author?.full_name ?? "Direction"} · {relative(a.published_at)}</p>
                          </div>
                          {(a.author_id === ctx.userId || ctx.isAdmin) && <AnnouncementActions id={a.id} />}
                        </div>
                      </li>
                    );
                  })}
                </ul>
              )}
            </div>
          </Card>
        </div>

        <div className="space-y-6">
          {onboarding.length > 0 && onboardingDone < onboarding.length && (
            <Card>
              <CardHeader title="Votre intégration" description={`${onboardingDone} / ${onboarding.length} étapes terminées`} />
              <div className="px-5 pt-3"><Progress value={(onboardingDone / onboarding.length) * 100} /></div>
              <LifecycleChecklist items={onboarding} />
            </Card>
          )}

          <Card>
            <CardHeader title="Agenda" description="Vos 7 prochains jours" icon={<CalendarDays className="h-4 w-4" />}
              action={<Link href="/reunions" className="text-[13px] font-medium text-primary hover:underline">Planifier</Link>} />
            <div className="mt-3 pb-2">
              {meetings.length === 0 ? (
                <EmptyState icon={CalendarDays} title="Agenda libre" description="Aucune réunion prévue cette semaine." />
              ) : (
                <ul className="space-y-1 px-3">
                  {meetings.map((m) => {
                    const live = new Date(m.starts_at) <= now && new Date(m.ends_at) >= now;
                    return (
                      <li key={m.id} className="flex items-center gap-3 rounded-xl px-2 py-2.5 hover:bg-surface-2/60">
                        <div className="grid w-12 shrink-0 place-items-center rounded-lg bg-surface-2 py-1.5 text-center">
                          <span className="text-[10px] font-medium uppercase text-subtle">{dateFr(m.starts_at, "EEE")}</span>
                          <span className="text-sm font-semibold text-fg">{dateFr(m.starts_at, "HH:mm")}</span>
                        </div>
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-sm font-medium text-fg">{m.title}</p>
                          <p className="truncate text-xs text-subtle">{m.location ?? "En ligne"} · {dateFr(m.starts_at, "d MMM")}</p>
                        </div>
                        {m.video_url && (
                          <a href={m.video_url} target="_blank" rel="noreferrer" className={cn("grid h-8 w-8 place-items-center rounded-lg transition", live ? "bg-emerald-500 text-white" : "bg-surface-2 text-muted hover:text-fg")} aria-label="Rejoindre">
                            <Video className="h-4 w-4" />
                          </a>
                        )}
                      </li>
                    );
                  })}
                </ul>
              )}
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
}
