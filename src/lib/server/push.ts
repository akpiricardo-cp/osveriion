import "server-only";
import webpush from "web-push";

let ready: boolean | null = null;

export function pushConfigured() {
  if (ready === null) {
    const pub = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;
    const priv = process.env.VAPID_PRIVATE_KEY;
    ready = !!pub && !!priv;
    if (ready) webpush.setVapidDetails(process.env.VAPID_SUBJECT || `mailto:admin@${process.env.NEXT_PUBLIC_EMAIL_DOMAIN || "veriion.com"}`, pub!, priv!);
  }
  return ready;
}

export type PushPayload = { title: string; body?: string | null; url?: string | null; tag?: string };

/** Envoie une notification push. Retourne « gone » si l'abonnement n'existe plus (à supprimer). */
export async function sendPush(sub: { endpoint: string; p256dh: string; auth: string }, payload: PushPayload): Promise<"ok" | "gone" | "error"> {
  try {
    await webpush.sendNotification(
      { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
      JSON.stringify(payload),
      { TTL: 60 * 60 * 12, urgency: "normal", topic: payload.tag?.slice(0, 32).replace(/[^A-Za-z0-9_-]/g, "") || undefined },
    );
    return "ok";
  } catch (e) {
    const code = (e as { statusCode?: number }).statusCode;
    return code === 404 || code === 410 ? "gone" : "error";
  }
}
