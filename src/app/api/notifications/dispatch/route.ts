import { NextResponse, type NextRequest } from "next/server";
import { dispatchNotifications } from "@/lib/server/dispatch";
import { authorized } from "../auth";

export const dynamic = "force-dynamic";
export const maxDuration = 60;

/** Envoi des notifications en attente (push immédiat, e-mails regroupés, résumés quotidiens). */
async function handle(request: NextRequest) {
  if (!authorized(request)) return NextResponse.json({ error: "Non autorisé" }, { status: 401 });
  const stats = await dispatchNotifications();
  return NextResponse.json(stats, { status: stats.errors.length ? 207 : 200 });
}

export const GET = handle;
export const POST = handle;
