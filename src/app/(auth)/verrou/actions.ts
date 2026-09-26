"use server";

import { createClient } from "@/lib/supabase/server";
import { fail, ok, str } from "@/lib/actions";
import { ACCESS_CODE_RULE } from "@/lib/access-code";
import { unlockSession } from "@/lib/server/unlock";
import type { ActionResult } from "@/lib/types";

const tries = (n: number) => `${n} tentative${n > 1 ? "s" : ""}`;

type Verdict = { ok?: boolean; missing?: boolean; remaining?: number; locked_until?: string };

async function me() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  return { supabase, user };
}

/** Première ouverture : la personne choisit son code, puis entre directement. */
export async function createAccessCode(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const code = str(fd, "code") ?? "";
  if (!ACCESS_CODE_RULE.test(code)) return fail("Le code doit contenir de 6 à 32 caractères, sans espace.");
  if (code !== (str(fd, "confirm") ?? "")) return fail("Les deux codes ne correspondent pas.");
  const { supabase, user } = await me();
  if (!user) return fail("Session expirée. Reconnectez-vous.");
  const { error } = await supabase.rpc("set_access_code", { p_code: code });
  if (error) return fail(error);
  await unlockSession(user.id);
  return ok("Code d'accès enregistré. Il vous sera demandé à chaque nouvelle session.");
}

/** Retour dans son espace : le code rouvre l'accès, la session n'a jamais été fermée. */
export async function unlockSpace(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const code = str(fd, "code");
  if (!code) return fail("Saisissez votre code d'accès.");
  const { supabase, user } = await me();
  if (!user) return fail("Session expirée. Reconnectez-vous.");
  const { data, error } = await supabase.rpc("verify_access_code", { p_code: code });
  if (error) return fail(error);
  const verdict = (data ?? {}) as Verdict;
  if (verdict.ok) {
    await unlockSession(user.id);
    return ok();
  }
  if (verdict.missing) return fail("Aucun code n'est défini pour votre compte : rechargez la page pour en créer un.");
  if (verdict.locked_until) {
    const minutes = Math.max(1, Math.ceil((new Date(verdict.locked_until).getTime() - Date.now()) / 60000));
    return fail(`Trop de tentatives. Réessayez dans ${minutes} minute${minutes > 1 ? "s" : ""} ou demandez une réinitialisation à l'administration.`);
  }
  return fail(`Code incorrect. Il reste ${tries(verdict.remaining ?? 0)} avant un blocage de 15 minutes.`);
}
