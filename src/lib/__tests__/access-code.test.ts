import { beforeAll, describe, expect, it } from "vitest";
import { ACCESS_CODE_RULE, UNLOCK_MAX_AGE_MS, issueUnlockToken, unlockTokenValid } from "@/lib/access-code";

beforeAll(() => {
  process.env.ACCESS_CODE_SECRET = "secret-de-test-0123456789abcdef";
});

describe("jeton de déverrouillage", () => {
  const user = "00000000-0000-0000-0000-00000000000a";

  it("est valide pour la personne qui l'a obtenu", async () => {
    expect(await unlockTokenValid(await issueUnlockToken(user), user)).toBe(true);
  });

  it("ne déverrouille pas l'espace d'une autre personne", async () => {
    const token = await issueUnlockToken(user);
    expect(await unlockTokenValid(token, "00000000-0000-0000-0000-00000000000b")).toBe(false);
  });

  it("refuse une signature falsifiée ou un jeton malformé", async () => {
    const token = await issueUnlockToken(user);
    const [issued] = token.split(".");
    expect(await unlockTokenValid(`${issued}.AAAA`, user)).toBe(false);
    expect(await unlockTokenValid("pas-un-jeton", user)).toBe(false);
    expect(await unlockTokenValid(undefined, user)).toBe(false);
  });

  it("expire après la durée maximale", async () => {
    const token = await issueUnlockToken(user);
    const sig = token.split(".")[1];
    const old = Date.now() - UNLOCK_MAX_AGE_MS - 1000;
    // Même signature, date antidatée : la signature ne correspond plus et la date est hors délai.
    expect(await unlockTokenValid(`${old}.${sig}`, user)).toBe(false);
  });

  it("dépend du secret : changer le secret invalide les jetons", async () => {
    const token = await issueUnlockToken(user);
    process.env.ACCESS_CODE_SECRET = "un-autre-secret-0123456789abcdef";
    expect(await unlockTokenValid(token, user)).toBe(false);
    process.env.ACCESS_CODE_SECRET = "secret-de-test-0123456789abcdef";
  });
});

describe("forme du code", () => {
  it("accepte 6 à 32 caractères sans espace", () => {
    expect(ACCESS_CODE_RULE.test("Koffi-2026")).toBe(true);
    expect(ACCESS_CODE_RULE.test("12345")).toBe(false);
    expect(ACCESS_CODE_RULE.test("avec espace")).toBe(false);
    expect(ACCESS_CODE_RULE.test("x".repeat(33))).toBe(false);
  });
});
