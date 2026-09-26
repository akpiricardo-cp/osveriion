"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { fail, numVal, ok, str } from "@/lib/actions";
import type { ActionResult } from "@/lib/types";

export async function recordMetrics(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const date = str(fd, "metric_date");
  const active = numVal(fd, "active_users");
  if (!date || active === null) return fail("Date et utilisateurs actifs requis.");
  const supabase = await createClient();
  const { error } = await supabase.from("product_metrics").upsert({
    metric_date: date, product: str(fd, "product") ?? "VERIION", country: str(fd, "country") ?? "ALL",
    active_users: Math.round(active), new_users: Math.round(numVal(fd, "new_users") ?? 0),
  }, { onConflict: "metric_date,product,country" });
  if (error) return fail(error);
  revalidatePath("/direction");
  return ok("Métriques enregistrées.");
}

export async function reportIncident(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const title = str(fd, "title");
  if (!title) return fail("Titre requis.");
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const { error } = await supabase.from("incidents").insert({
    title, description: str(fd, "description"), severity: str(fd, "severity") ?? "medium", product: str(fd, "product"), reported_by: user!.id,
  });
  if (error) return fail(error);
  revalidatePath("/direction");
  return ok("Incident signalé.");
}

export async function setIncidentStatus(id: string, status: "open" | "mitigated" | "resolved"): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("incidents").update({ status, resolved_at: status === "resolved" ? new Date().toISOString() : null }).eq("id", id);
  if (error) return fail(error);
  revalidatePath("/direction");
  return ok("Incident mis à jour.");
}
