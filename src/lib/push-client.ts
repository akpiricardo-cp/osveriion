"use client";

import { createClient } from "@/lib/supabase/client";

/** Notifications push côté navigateur : abonnement de l'appareil et enregistrement auprès de VERIION OS. */

export const pushSupported = () =>
  typeof window !== "undefined" && "serviceWorker" in navigator && "PushManager" in window && "Notification" in window;

export const vapidKey = () => process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY ?? "";

function toUint8(base64: string) {
  const pad = "=".repeat((4 - (base64.length % 4)) % 4);
  const raw = atob((base64 + pad).replace(/-/g, "+").replace(/_/g, "/"));
  return Uint8Array.from(raw, (c) => c.charCodeAt(0));
}

export function deviceName() {
  const ua = navigator.userAgent;
  const os = /iPhone|iPad/.test(ua) ? "iPhone/iPad" : /Android/.test(ua) ? "Android" : /Mac/.test(ua) ? "Mac" : /Windows/.test(ua) ? "Windows" : /Linux/.test(ua) ? "Linux" : "Appareil";
  const browser = /Edg\//.test(ua) ? "Edge" : /Chrome\//.test(ua) ? "Chrome" : /Firefox\//.test(ua) ? "Firefox" : /Safari\//.test(ua) ? "Safari" : "Navigateur";
  return `${browser} · ${os}`;
}

export async function registerServiceWorker() {
  if (!pushSupported()) return null;
  return navigator.serviceWorker.register("/sw.js", { scope: "/" });
}

async function save(sub: PushSubscription) {
  const json = sub.toJSON() as { endpoint: string; keys: { p256dh: string; auth: string } };
  const { error } = await createClient().rpc("register_push_subscription", {
    p_endpoint: json.endpoint, p_p256dh: json.keys.p256dh, p_auth: json.keys.auth, p_device: deviceName(),
  });
  if (error) throw new Error(error.message);
}

export async function currentSubscription() {
  if (!pushSupported()) return null;
  const reg = await navigator.serviceWorker.getRegistration("/");
  return (await reg?.pushManager.getSubscription()) ?? null;
}

/** Demande l'autorisation, abonne l'appareil et l'enregistre. */
export async function enablePush() {
  if (!pushSupported()) throw new Error("Ce navigateur ne prend pas en charge les notifications push. Sur iPhone, ajoutez d'abord VERIION OS à l'écran d'accueil.");
  if (!vapidKey()) throw new Error("Les notifications push ne sont pas encore configurées sur le serveur (clé VAPID manquante).");
  const permission = await Notification.requestPermission();
  if (permission !== "granted") throw new Error("Autorisation refusée. Vous pouvez la réactiver dans les réglages du navigateur pour ce site.");
  const reg = (await registerServiceWorker())!;
  await navigator.serviceWorker.ready;
  const existing = await reg.pushManager.getSubscription();
  // Le navigateur contacte son service push (Google, Apple, Mozilla) : on n'attend pas indéfiniment
  const sub = existing ?? (await Promise.race([
    reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: toUint8(vapidKey()) }),
    new Promise<never>((_, reject) => setTimeout(() => reject(new Error("Le service de notifications du navigateur ne répond pas. Vérifiez votre connexion puis réessayez.")), 20000)),
  ]));
  await save(sub);
  return sub;
}

export async function disablePush() {
  const sub = await currentSubscription();
  if (!sub) return;
  await createClient().from("push_subscriptions").delete().eq("endpoint", sub.endpoint);
  await sub.unsubscribe();
}

/** Au chargement : l'abonnement existant est ré-associé à la personne connectée (changement de compte, renouvellement). */
export async function refreshPushRegistration() {
  if (!pushSupported() || Notification.permission !== "granted" || !vapidKey()) return;
  await registerServiceWorker();
  const sub = await currentSubscription();
  if (sub) await save(sub).catch(() => {});
}
