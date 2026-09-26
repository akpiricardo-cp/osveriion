import "server-only";
import { cache } from "react";
import { createClient } from "@/lib/supabase/server";
import type { OrgUnit, ProfileLite } from "@/lib/types";

export const getPeople = cache(async (): Promise<ProfileLite[]> => {
  const supabase = await createClient();
  const { data } = await supabase
    .from("profiles")
    .select("id, full_name, avatar_url, job_title, email")
    .eq("status", "active")
    .order("first_name");
  return (data as ProfileLite[]) ?? [];
});

export const getUnits = cache(async (): Promise<OrgUnit[]> => {
  const supabase = await createClient();
  const { data } = await supabase.from("org_units").select("*").is("archived_at", null).order("depth").order("sort_order").order("name");
  return (data as OrgUnit[]) ?? [];
});

export function peopleMap(people: ProfileLite[]) {
  return new Map(people.map((p) => [p.id, p]));
}

/** Liste des unités indentée selon la hiérarchie (pour les listes déroulantes). */
export function unitOptions(units: OrgUnit[]) {
  const children = new Map<string | null, OrgUnit[]>();
  units.forEach((u) => {
    const k = u.parent_id;
    if (!children.has(k)) children.set(k, []);
    children.get(k)!.push(u);
  });
  const out: { id: string; label: string; depth: number }[] = [];
  const walk = (parent: string | null, depth: number) => {
    (children.get(parent) ?? []).forEach((u) => {
      out.push({ id: u.id, label: `${"   ".repeat(depth)}${depth ? "└ " : ""}${u.name}`, depth });
      walk(u.id, depth + 1);
    });
  };
  walk(null, 0);
  return out;
}
