"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { fail, ok } from "@/lib/actions";
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
  const stats = await dispatchNotifications();
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
