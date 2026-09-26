/**
 * Code d'accès personnel — jeton de déverrouillage.
 *
 * Le code lui-même n'est jamais manipulé ici : il est vérifié par la base
 * (`verify_access_code`). Une fois le code accepté, l'espace est déverrouillé
 * pour la session du navigateur au moyen d'un cookie signé (HMAC-SHA256), lu
 * par le middleware à chaque requête. Fermer le navigateur efface le cookie :
 * la session Supabase reste ouverte, mais le code est redemandé.
 *
 * Volontairement sans dépendance Node : ce module tourne aussi dans le
 * middleware (runtime Edge), d'où l'usage exclusif de Web Crypto.
 */

export const UNLOCK_COOKIE = "veriion-acces";

/** Forme d'un code : 6 à 32 caractères, sans espace (même règle que `public.access_code_valid`). */
export const ACCESS_CODE_RULE = /^\S{6,32}$/;

/** Durée de vie maximale d'un déverrouillage, même si le navigateur reste ouvert. */
export const UNLOCK_MAX_AGE_MS = 12 * 60 * 60 * 1000;

/** Cookie de session : aucun `maxAge` — il disparaît à la fermeture du navigateur. */
export const unlockCookieOptions = {
  httpOnly: true,
  sameSite: "lax",
  secure: process.env.NODE_ENV === "production",
  path: "/",
} as const;

function secret() {
  const value = process.env.ACCESS_CODE_SECRET || process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!value) throw new Error("ACCESS_CODE_SECRET (ou SUPABASE_SERVICE_ROLE_KEY) est manquant.");
  return value;
}

let cached: { secret: string; key: Promise<CryptoKey> } | null = null;

function hmacKey() {
  const value = secret();
  if (!cached || cached.secret !== value) {
    cached = {
      secret: value,
      key: crypto.subtle.importKey("raw", new TextEncoder().encode(value), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]),
    };
  }
  return cached.key;
}

function base64url(bytes: ArrayBuffer) {
  let binary = "";
  for (const byte of new Uint8Array(bytes)) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function signature(userId: string, issuedAt: number) {
  const data = new TextEncoder().encode(`${userId}.${issuedAt}`);
  return base64url(await crypto.subtle.sign("HMAC", await hmacKey(), data));
}

/** Comparaison à durée constante, pour ne rien révéler de la signature attendue. */
function sameString(a: string, b: string) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** Jeton à déposer dans le cookie après vérification du code. */
export async function issueUnlockToken(userId: string) {
  const issuedAt = Date.now();
  return `${issuedAt}.${await signature(userId, issuedAt)}`;
}

/** Vrai si le jeton du cookie déverrouille bien l'espace de cet utilisateur. */
export async function unlockTokenValid(token: string | undefined, userId: string) {
  if (!token) return false;
  const separator = token.indexOf(".");
  if (separator < 1) return false;
  const issuedAt = Number(token.slice(0, separator));
  if (!Number.isFinite(issuedAt)) return false;
  const age = Date.now() - issuedAt;
  if (age < -60_000 || age > UNLOCK_MAX_AGE_MS) return false;
  try {
    return sameString(token.slice(separator + 1), await signature(userId, issuedAt));
  } catch {
    return false;
  }
}
