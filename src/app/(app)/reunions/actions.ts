"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { fail, ok, str } from "@/lib/actions";
import { randomRoom } from "@/lib/utils";
import type { ActionResult } from "@/lib/types";

function refresh() {
  revalidatePath("/reunions");
  revalidatePath("/");
}

export async function createMeeting(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const title = str(fd, "title");
  const date = str(fd, "date");
  const time = str(fd, "time");
  const duration = Number(str(fd, "duration") ?? 60);
  const tz = str(fd, "tz_offset") ?? "+01:00";
  if (!title || !date || !time) return fail("Titre, date et heure requis.");
  const starts = new Date(`${date}T${time}:00${tz}`);
  if (Number.isNaN(starts.getTime())) return fail("Date invalide.");
  const ends = new Date(starts.getTime() + Math.max(15, duration) * 60000);
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const base = process.env.NEXT_PUBLIC_MEET_BASE_URL ?? "https://meet.jit.si/veriion";
  const { data, error } = await supabase.from("meetings").insert({
    title,
    description: str(fd, "description"),
    starts_at: starts.toISOString(),
    ends_at: ends.toISOString(),
    location: str(fd, "location"),
    video_url: fd.get("video") === "on" ? `${base}-${randomRoom()}` : null,
    unit_id: str(fd, "unit_id"),
    project_id: str(fd, "project_id"),
    organizer_id: user!.id,
  }).select("id").single();
  if (error) return fail(error);
  const attendees = [...new Set(fd.getAll("attendees").map(String))].filter((a) => a && a !== user!.id);
  if (attendees.length) {
    const { error: e2 } = await supabase.from("meeting_attendees").insert(attendees.map((a) => ({ meeting_id: data.id, profile_id: a })));
    if (e2) return fail(e2);
  }
  refresh();
  return ok(`Réunion planifiée${attendees.length ? ` — ${attendees.length} invitation(s) envoyée(s)` : ""}.`);
}

export async function respondMeeting(meetingId: string, response: "accepted" | "declined"): Promise<ActionResult> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const { error } = await supabase.from("meeting_attendees").update({ response }).eq("meeting_id", meetingId).eq("profile_id", user!.id);
  if (error) return fail(error);
  refresh();
  return ok(response === "accepted" ? "Présence confirmée." : "Absence signalée.");
}

export async function saveMinutes(meetingId: string, minutes: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("meetings").update({ minutes }).eq("id", meetingId);
  if (error) return fail(error);
  refresh();
  return ok("Compte rendu enregistré.");
}

export async function deleteMeeting(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("meetings").delete().eq("id", id);
  if (error) return fail(error);
  refresh();
  return ok("Réunion supprimée.");
}
