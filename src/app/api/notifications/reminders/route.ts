import { NextResponse, type NextRequest } from "next/server";
import { runReminders } from "@/lib/server/dispatch";
import { authorized } from "../auth";

export const dynamic = "force-dynamic";

/**
 * Rappels automatiques, à utiliser seulement si pg_cron n'est pas activé dans Supabase :
 *   /api/notifications/reminders?type=daily     → chaque matin (échéances, retards, validations, congés)
 *   /api/notifications/reminders?type=meetings  → toutes les 5 minutes (réunions imminentes)
 */
async function handle(request: NextRequest) {
  if (!authorized(request)) return NextResponse.json({ error: "Non autorisé" }, { status: 401 });
  const type = request.nextUrl.searchParams.get("type") === "meetings" ? "meetings" : "daily";
  try {
    return NextResponse.json({ type, created: await runReminders(type) });
  } catch (e) {
    return NextResponse.json({ error: e instanceof Error ? e.message : "Erreur" }, { status: 500 });
  }
}

export const GET = handle;
export const POST = handle;
