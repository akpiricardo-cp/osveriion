import "server-only";
import { createAdminClient } from "@/lib/supabase/admin";
import { DEFAULT_PREFERENCES, type NotificationCategory, type NotificationPreferences } from "@/lib/notifications";
import { mailerConfigured, renderNotificationEmail, sendMail, type MailItem } from "./mailer";
import { pushConfigured, sendPush } from "./push";

type Row = { id: string; profile_id: string; kind: string; category: NotificationCategory; title: string; body: string | null; link: string | null; created_at: string };
type Sub = { id: string; profile_id: string; endpoint: string; p256dh: string; auth: string };

export type DispatchStats = { push: number; pushSkipped: number; gone: number; emails: number; emailItems: number; errors: string[] };

const TZ = process.env.NEXT_PUBLIC_TIMEZONE || "Africa/Porto-Novo";

function inQuietHours(p: NotificationPreferences) {
  if (!p.quiet_start || !p.quiet_end) return false;
  const now = new Intl.DateTimeFormat("fr-FR", { timeZone: TZ, hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(new Date());
  const [s, e, t] = [p.quiet_start.slice(0, 5), p.quiet_end.slice(0, 5), now];
  return s <= e ? t >= s && t < e : t >= s || t < e;
}

function groupBy<T, K extends string>(list: T[], key: (x: T) => K) {
  const m = new Map<K, T[]>();
  list.forEach((x) => { const k = key(x); m.set(k, [...(m.get(k) ?? []), x]); });
  return m;
}

/**
 * Envoie les notifications en attente :
 *  - push : immédiatement, sur tous les appareils enregistrés (sauf catégorie coupée ou plage « ne pas déranger ») ;
 *  - e-mail immédiat : notifications restées non lues 3 minutes, regroupées en un seul e-mail par personne ;
 *  - résumé quotidien : pour les personnes qui l'ont choisi, à l'heure qu'elles ont fixée.
 * Les files sont réservées en base (FOR UPDATE SKIP LOCKED) : plusieurs appels simultanés n'envoient rien en double.
 */
export async function dispatchNotifications(): Promise<DispatchStats> {
  const admin = createAdminClient();
  const stats: DispatchStats = { push: 0, pushSkipped: 0, gone: 0, emails: 0, emailItems: 0, errors: [] };

  const loadPrefs = async (ids: string[]) => {
    const map = new Map<string, NotificationPreferences>();
    if (!ids.length) return map;
    const { data } = await admin.from("notification_preferences").select("*").in("profile_id", ids);
    (data ?? []).forEach((p) => map.set(p.profile_id as string, { ...DEFAULT_PREFERENCES, ...(p as NotificationPreferences) }));
    return map;
  };

  // ── Push ────────────────────────────────────────────────────────────────
  if (pushConfigured()) {
    const { data, error } = await admin.rpc("claim_push_batch", { p_limit: 300 });
    if (error) stats.errors.push(`push: ${error.message}`);
    const rows = (data as Row[]) ?? [];
    if (rows.length) {
      const byUser = groupBy(rows, (r) => r.profile_id);
      const ids = [...byUser.keys()];
      const [prefs, { data: subs }] = await Promise.all([
        loadPrefs(ids),
        admin.from("push_subscriptions").select("id, profile_id, endpoint, p256dh, auth").in("profile_id", ids),
      ]);
      const subsByUser = groupBy((subs as Sub[]) ?? [], (s) => s.profile_id);
      const gone: string[] = [];
      const used: string[] = [];
      await Promise.all(ids.map(async (uid) => {
        const p = prefs.get(uid) ?? DEFAULT_PREFERENCES;
        const devices = subsByUser.get(uid) ?? [];
        const items = (byUser.get(uid) ?? []).filter((r) => !p.push_off.includes(r.category));
        if (!devices.length || !items.length || inQuietHours(p)) { stats.pushSkipped += byUser.get(uid)!.length; return; }
        // Au-delà de 3 notifications d'un coup, un seul message récapitulatif
        const payloads = items.length > 3
          ? [{ title: `${items.length} nouvelles notifications`, body: items.slice(0, 3).map((i) => i.title).join(" · "), url: "/", tag: "veriion-batch" }]
          : items.map((i) => ({ title: i.title, body: i.body, url: i.link ?? "/", tag: `n-${i.id}` }));
        for (const d of devices) {
          for (const pl of payloads) {
            const r = await sendPush(d, pl);
            if (r === "gone") { gone.push(d.id); break; }
            if (r === "ok") { stats.push++; used.push(d.id); }
          }
        }
      }));
      if (gone.length) { stats.gone = gone.length; await admin.from("push_subscriptions").delete().in("id", gone); }
      if (used.length) await admin.from("push_subscriptions").update({ last_used_at: new Date().toISOString() }).in("id", [...new Set(used)]);
    }
  }

  // ── E-mails ─────────────────────────────────────────────────────────────
  if (mailerConfigured()) {
    const [instant, digest] = await Promise.all([admin.rpc("claim_email_batch", { p_limit: 500 }), admin.rpc("claim_digest_batch")]);
    if (instant.error) stats.errors.push(`email: ${instant.error.message}`);
    if (digest.error) stats.errors.push(`résumé: ${digest.error.message}`);
    const jobs: { uid: string; rows: Row[]; digest: boolean }[] = [];
    groupBy((instant.data as Row[]) ?? [], (r) => r.profile_id).forEach((rows, uid) => jobs.push({ uid, rows, digest: false }));
    groupBy((digest.data as Row[]) ?? [], (r) => r.profile_id).forEach((rows, uid) => jobs.push({ uid, rows, digest: true }));
    if (jobs.length) {
      const ids = [...new Set(jobs.map((j) => j.uid))];
      const [prefs, { data: people }] = await Promise.all([
        loadPrefs(ids),
        admin.from("profiles").select("id, email, first_name, status").in("id", ids),
      ]);
      const pm = new Map((people ?? []).map((p) => [p.id as string, p]));
      for (const job of jobs) {
        const person = pm.get(job.uid);
        const p = prefs.get(job.uid) ?? DEFAULT_PREFERENCES;
        if (!person || person.status !== "active" || !person.email) continue;
        const items: MailItem[] = job.rows.filter((r) => !p.email_off.includes(r.category))
          .sort((a, b) => a.created_at.localeCompare(b.created_at));
        if (!items.length) continue;
        try {
          await sendMail(person.email as string, renderNotificationEmail((person.first_name as string) || "", items, job.digest));
          stats.emails++;
          stats.emailItems += items.length;
        } catch (e) {
          stats.errors.push(`email ${person.email}: ${e instanceof Error ? e.message : String(e)}`);
          // Échec d'envoi : on remet les notifications dans la file pour le prochain passage
          await admin.from("notifications").update({ emailed_at: null }).in("id", job.rows.map((r) => r.id));
        }
      }
    }
  }
  return stats;
}

/** Rappels (échéances, retards, validations, congés, réunions) quand pg_cron n'est pas disponible. */
export async function runReminders(kind: "daily" | "meetings") {
  const admin = createAdminClient();
  const { data, error } = await admin.rpc(kind === "daily" ? "generate_daily_reminders" : "remind_upcoming_meetings");
  if (error) throw new Error(error.message);
  return data as number;
}
