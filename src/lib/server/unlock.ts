import "server-only";
import { cookies } from "next/headers";
import { UNLOCK_COOKIE, issueUnlockToken, unlockCookieOptions } from "@/lib/access-code";

/** Déverrouille l'espace pour la session du navigateur (après un code accepté). */
export async function unlockSession(userId: string) {
  (await cookies()).set(UNLOCK_COOKIE, await issueUnlockToken(userId), unlockCookieOptions);
}

/** Reverrouille l'espace sans fermer la session : le code sera redemandé. */
export async function lockSession() {
  (await cookies()).delete(UNLOCK_COOKIE);
}
