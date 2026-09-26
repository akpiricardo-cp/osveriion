import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { UNLOCK_COOKIE, unlockTokenValid } from "@/lib/access-code";

const PUBLIC_PATHS = ["/connexion", "/mot-de-passe-oublie", "/auth"];
// Accessibles alors que l'espace est encore verrouillé : la saisie du code
// elle-même, et la définition du mot de passe après une invitation.
const UNLOCKED_PATHS = ["/verrou", "/definir-mot-de-passe"];

const matches = (path: string, paths: string[]) => paths.some((p) => path === p || path.startsWith(p + "/"));

export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
        },
      },
    },
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const path = request.nextUrl.pathname;
  const isPublic = matches(path, PUBLIC_PATHS);

  if (!user && !isPublic) {
    const url = request.nextUrl.clone();
    url.pathname = "/connexion";
    url.search = path !== "/" ? `?suite=${encodeURIComponent(path + request.nextUrl.search)}` : "";
    return NextResponse.redirect(url);
  }

  if (user && path === "/connexion") {
    const url = request.nextUrl.clone();
    url.pathname = "/";
    url.search = "";
    return NextResponse.redirect(url);
  }

  // Code d'accès : la session reste ouverte, mais l'espace est verrouillé
  // jusqu'à la saisie du code personnel (une fois par session du navigateur).
  if (user && !isPublic) {
    const unlocked = await unlockTokenValid(request.cookies.get(UNLOCK_COOKIE)?.value, user.id);
    const onLockScreen = matches(path, UNLOCKED_PATHS);
    if (!unlocked && !onLockScreen) {
      const url = request.nextUrl.clone();
      url.pathname = "/verrou";
      url.search = path !== "/" ? `?suite=${encodeURIComponent(path + request.nextUrl.search)}` : "";
      return NextResponse.redirect(url);
    }
    if (unlocked && path === "/verrou") {
      const suite = request.nextUrl.searchParams.get("suite");
      const next = suite?.startsWith("/") && !suite.startsWith("//") ? suite : "/";
      return NextResponse.redirect(new URL(next, request.url));
    }
  }

  return response;
}
