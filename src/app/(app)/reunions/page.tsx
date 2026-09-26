import { CalendarDays, Clock, MapPin, Video } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { getContext } from "@/lib/auth";
import { getPeople, getUnits, peopleMap, unitOptions } from "@/lib/data";
import type { Meeting } from "@/lib/types";
import { cn, dateFr } from "@/lib/utils";
import { AvatarStack } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { EmptyState, PageHeader } from "@/components/ui/misc";
import { LinkTabs } from "@/components/ui/tabs";
import { MeetingButton, MeetingControls } from "./meetings-client";

export const metadata = { title: "Réunions" };

export default async function MeetingsPage({ searchParams }: { searchParams: Promise<{ onglet?: string }> }) {
  const { onglet = "a-venir" } = await searchParams;
  const ctx = await getContext();
  const supabase = await createClient();
  const now = new Date().toISOString();
  const q = supabase.from("meetings").select("*");
  const [{ data }, { data: attendees }, people, units, { data: projects }] = await Promise.all([
    onglet === "passees" ? q.lt("ends_at", now).order("starts_at", { ascending: false }).limit(40) : q.gte("ends_at", now).order("starts_at").limit(80),
    supabase.from("meeting_attendees").select("*"),
    getPeople(),
    getUnits(),
    supabase.from("projects").select("id, name").is("archived_at", null).order("name"),
  ]);
  const meetings = (data as Meeting[]) ?? [];
  const pm = peopleMap(people);
  const groups = new Map<string, Meeting[]>();
  meetings.forEach((m) => {
    const k = new Date(m.starts_at).toLocaleDateString("fr-CA", { timeZone: "Africa/Porto-Novo" });
    if (!groups.has(k)) groups.set(k, []);
    groups.get(k)!.push(m);
  });

  return (
    <div>
      <PageHeader title="Réunions" description="Planifiez, invitez, rejoignez en visio et consignez les comptes rendus."
        actions={<MeetingButton people={people.filter((p) => p.id !== ctx.userId)} units={unitOptions(units)} projects={projects ?? []} />} />
      <LinkTabs basePath="/reunions" active={onglet} className="mb-6" tabs={[{ key: "a-venir", label: "À venir" }, { key: "passees", label: "Passées" }]} />
      {meetings.length === 0 ? (
        <EmptyState icon={CalendarDays} title="Aucune réunion" description={onglet === "passees" ? "Aucune réunion passée." : "Planifiez votre prochaine réunion d'équipe."} />
      ) : (
        <div className="space-y-8">
          {[...groups.entries()].map(([day, list]) => (
            <section key={day}>
              <h2 className="mb-3 text-sm font-semibold capitalize text-fg">{dateFr(day, "EEEE d MMMM yyyy")}</h2>
              <div className="space-y-3">
                {list.map((m) => {
                  const att = (attendees ?? []).filter((a) => a.meeting_id === m.id);
                  const me = att.find((a) => a.profile_id === ctx.userId);
                  const live = new Date(m.starts_at) <= new Date() && new Date(m.ends_at) >= new Date();
                  const organizer = m.organizer_id ? pm.get(m.organizer_id) : null;
                  const unit = units.find((u) => u.id === m.unit_id);
                  return (
                    <div key={m.id} className={cn("flex flex-col gap-4 rounded-2xl border bg-surface p-5 shadow-card sm:flex-row", live ? "border-emerald-500/40" : "border-border")}>
                      <div className="grid w-20 shrink-0 place-items-center self-start rounded-xl bg-surface-2 py-2 text-center">
                        <span className="text-lg font-semibold tabular-nums text-fg">{dateFr(m.starts_at, "HH:mm")}</span>
                        <span className="text-[11px] text-subtle">{Math.round((new Date(m.ends_at).getTime() - new Date(m.starts_at).getTime()) / 60000)} min</span>
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="flex flex-wrap items-center gap-2">
                          <p className="text-[15px] font-semibold text-fg">{m.title}</p>
                          {live && <Badge tone="green" dot>En cours</Badge>}
                          {unit && <Badge>{unit.name}</Badge>}
                          {me && <Badge tone={me.response === "accepted" ? "green" : me.response === "declined" ? "red" : "amber"}>{me.response === "accepted" ? "Présent(e)" : me.response === "declined" ? "Absent(e)" : "Réponse attendue"}</Badge>}
                        </div>
                        {m.description && <p className="mt-1 text-sm text-muted">{m.description}</p>}
                        <div className="mt-2 flex flex-wrap items-center gap-4 text-xs text-subtle">
                          <span className="flex items-center gap-1"><Clock className="h-3.5 w-3.5" />{dateFr(m.starts_at, "HH:mm")} – {dateFr(m.ends_at, "HH:mm")}</span>
                          {m.location && <span className="flex items-center gap-1"><MapPin className="h-3.5 w-3.5" />{m.location}</span>}
                          {m.video_url && <span className="flex items-center gap-1"><Video className="h-3.5 w-3.5" />Visioconférence</span>}
                          <span>Organisé par {organizer?.full_name ?? "—"}</span>
                          {att.length > 0 && <AvatarStack people={att.map((a) => pm.get(a.profile_id)).filter(Boolean) as { full_name: string; avatar_url: string | null }[]} />}
                        </div>
                        {m.minutes && <p className="mt-3 whitespace-pre-line rounded-xl bg-surface-2/60 p-3 text-sm text-muted">{m.minutes}</p>}
                      </div>
                      <MeetingControls meeting={m} isOrganizer={m.organizer_id === ctx.userId} myResponse={me?.response} past={onglet === "passees"} live={live} />
                    </div>
                  );
                })}
              </div>
            </section>
          ))}
        </div>
      )}
    </div>
  );
}
