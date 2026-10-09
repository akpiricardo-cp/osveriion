"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { fail, numVal, ok, str } from "@/lib/actions";
import { ACCESS_CODE_RULE } from "@/lib/access-code";
import { lockSession, unlockSession } from "@/lib/server/unlock";
import { NOTIFICATION_CATEGORIES, type NotificationPreferences } from "@/lib/notifications";
import { dispatchNotifications } from "@/lib/server/dispatch";
import { mailerConfigured, renderNotificationEmail, sendMail } from "@/lib/server/mailer";
import { pushConfigured } from "@/lib/server/push";
import type { ActionResult } from "@/lib/types";

const KEYS = new Set<string>(NOTIFICATION_CATEGORIES.map((c) => c.key));
const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;

export async function savePreferences(p: NotificationPreferences): Promise<ActionResult> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return fail("Session expirée.");
  if (!["instant", "digest", "off"].includes(p.email_mode)) return fail("Mode d'e-mail invalide.");
  p = { ...p, quiet_start: p.quiet_start?.slice(0, 5) || null, quiet_end: p.quiet_end?.slice(0, 5) || null };
  const quietOk = (!p.quiet_start && !p.quiet_end) || (TIME.test(p.quiet_start ?? "") && TIME.test(p.quiet_end ?? ""));
  if (!quietOk) return fail("Plage « ne pas déranger » invalide (format HH:MM).");
  const { error } = await supabase.from("notification_preferences").upsert({
    profile_id: user.id,
    email_mode: p.email_mode,
    email_off: p.email_off.filter((k) => KEYS.has(k)),
    push_off: p.push_off.filter((k) => KEYS.has(k)),
    quiet_start: p.quiet_start || null,
    quiet_end: p.quiet_end || null,
    digest_hour: Math.min(23, Math.max(0, Math.round(p.digest_hour))),
    updated_at: new Date().toISOString(),
  });
  if (error) return fail(error);
  revalidatePath("/parametres");
  return ok("Préférences enregistrées.");
}

/** Notification de test sur tous vos appareils (vérifie la configuration push de bout en bout). */
export async function sendTestPush(): Promise<ActionResult> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return fail("Session expirée.");
  if (!pushConfigured()) return fail("Push non configuré sur le serveur : ajoutez NEXT_PUBLIC_VAPID_PUBLIC_KEY et VAPID_PRIVATE_KEY (voir README).");
  const admin = createAdminClient();
  const { count } = await admin.from("push_subscriptions").select("id", { count: "exact", head: true }).eq("profile_id", user.id);
  if (!count) return fail("Aucun appareil enregistré : activez d'abord les notifications sur cet appareil.");
  const { error } = await admin.from("notifications").insert({
    profile_id: user.id, kind: "test", title: "Notification de test", body: "Les notifications VERIION OS fonctionnent sur cet appareil.", link: "/parametres?onglet=notifications",
  });
  if (error) return fail(error);
  const stats = await dispatchNotifications({ onlyProfile: user.id, pushOnly: true });
  if (!stats.push) return fail(stats.errors[0] ?? "Aucune notification n'a pu être envoyée (plage « ne pas déranger » ou catégorie désactivée ?).");
  return ok(`Notification envoyée sur ${stats.push} appareil${stats.push > 1 ? "s" : ""}.`);
}

/** E-mail de test à votre adresse (vérifie le SMTP). */
export async function sendTestEmail(): Promise<ActionResult> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user?.email) return fail("Session expirée.");
  if (!mailerConfigured()) return fail("E-mail non configuré sur le serveur : ajoutez SMTP_HOST, SMTP_USER, SMTP_PASSWORD et SMTP_FROM (voir README).");
  const { data: me } = await supabase.from("profiles").select("first_name").eq("id", user.id).single();
  try {
    await sendMail(user.email, renderNotificationEmail(me?.first_name ?? "", [
      { title: "E-mail de test", body: "Si vous lisez ceci, les e-mails de notification VERIION OS fonctionnent.", link: "/parametres?onglet=notifications", category: "other", created_at: new Date().toISOString() },
    ], false));
    return ok(`E-mail envoyé à ${user.email}.`);
  } catch (e) {
    return fail(`Envoi impossible : ${e instanceof Error ? e.message : String(e)}`);
  }
}

/**
 * Change (ou définit) le code d'accès personnel. La session reste ouverte et le
 * nouveau code déverrouille immédiatement l'espace sur cet appareil.
 */
export async function changeAccessCode(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const code = str(fd, "code") ?? "";
  if (!ACCESS_CODE_RULE.test(code)) return fail("Le code doit contenir de 6 à 32 caractères, sans espace.");
  if (code !== (str(fd, "confirm") ?? "")) return fail("Les deux codes ne correspondent pas.");
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return fail("Session expirée.");
  const { data: hasCode } = await supabase.rpc("has_access_code");
  const current = str(fd, "current");
  if (hasCode && !current) return fail("Saisissez votre code actuel.");
  const { error } = await supabase.rpc("set_access_code", { p_code: code, p_current: current });
  if (error) return fail(error);
  await unlockSession(user.id);
  revalidatePath("/parametres");
  return ok("Code d'accès mis à jour.");
}

/** Verrouille l'espace sur cet appareil sans fermer la session : le code sera redemandé. */
export async function lockSpaceNow(): Promise<never> {
  await lockSession();
  redirect("/verrou");
}

/** Paramètres de gouvernance (CEO, double authentification exigée par la base). */
export async function saveGovernance(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const threshold = numVal(fd, "ceo_approval_threshold");
  const reminder = numVal(fd, "approval_reminder_days");
  const maxGrant = numVal(fd, "max_grant_days");
  if (threshold === null || threshold < 0) return fail("Seuil invalide.");
  if (!reminder || reminder < 1 || reminder > 30) return fail("Relance : entre 1 et 30 jours.");
  if (!maxGrant || maxGrant < 1 || maxGrant > 366) return fail("Dérogation : entre 1 et 366 jours.");
  const supabase = await createClient();
  const { data, error } = await supabase.from("governance_settings").update({
    ceo_approval_threshold: threshold,
    approval_reminder_days: Math.round(reminder),
    max_grant_days: Math.round(maxGrant),
    mfa_enforced: str(fd, "mfa_enforced") !== "off",
  }).eq("id", true).select("id");
  if (error) return fail(error);
  if (!data?.length) return fail("Réservé au CEO, après validation de la double authentification.");
  revalidatePath("/", "layout");
  return ok("Règles de gouvernance enregistrées.");
}

export async function transferCeo(successorId: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("transfer_ceo", { p_to: successorId });
  if (error) return fail(error);
  revalidatePath("/", "layout");
  return ok("Fonction transmise : votre successeur est désormais CEO.");
}
