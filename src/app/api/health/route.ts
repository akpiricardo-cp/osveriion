import { NextResponse, type NextRequest } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { authorized } from "../notifications/auth";

export const dynamic = "force-dynamic";

/**
 * Supervision : GET /api/health
 *  - sans jeton : 200 si l'application répond (sonde de disponibilité) ;
 *  - avec « Authorization: Bearer <CRON_SECRET> » : état détaillé (base, files
 *    de notifications, échecs des tâches planifiées). 503 si quelque chose cloche.
 */
export async function GET(request: NextRequest) {
  if (!authorized(request)) return NextResponse.json({ status: "ok" });
  try {
    const { data, error } = await createAdminClient().rpc("ops_health");
    if (error) return NextResponse.json({ status: "error", database: error.message }, { status: 503 });
    const h = data as { push_backlog: number; email_backlog: number; cron_failures_24h: unknown[] };
    const degraded = h.push_backlog > 50 || h.email_backlog > 200 || h.cron_failures_24h.length > 0;
    return NextResponse.json({ status: degraded ? "degraded" : "ok", ...h, checked_at: new Date().toISOString() }, { status: degraded ? 503 : 200 });
  } catch (e) {
    return NextResponse.json({ status: "error", message: e instanceof Error ? e.message : "Erreur" }, { status: 503 });
  }
}
