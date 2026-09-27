import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { lockSession } from "@/lib/server/unlock";

export async function POST(request: NextRequest) {
  const supabase = await createClient();
  await supabase.auth.signOut();
  // Le verrou du code d'accès disparaît avec la session : le code sera redemandé.
  await lockSession();
  return NextResponse.redirect(new URL("/connexion", request.url), { status: 303 });
}
