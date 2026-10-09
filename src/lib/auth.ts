import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { Profile } from "@/lib/types";

export type Grant = { permission: string; scope_unit_id: string | null };

export interface AppContext {
  userId: string;
  email: string;
  profile: Profile;
  grants: Grant[];
  isCeo: boolean;
  isAdmin: boolean;
}

const ADMIN_PERMS = new Set(["org.manage", "users.admin", "grants.manage", "audit.view"]);

/** Contexte de l'utilisateur connecté, mis en cache pour la durée de la requête. */
export const getContext = cache(async (): Promise<AppContext> => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/connexion");

  const [{ data: profile }, { data: grants }] = await Promise.all([
    supabase.from("profiles").select("*").eq("id", user.id).single(),
    supabase.rpc("my_permissions"),
  ]);

  if (!profile) redirect("/connexion?erreur=profil");
  if (profile.status !== "active") {
    await supabase.auth.signOut();
    redirect("/connexion?erreur=inactif");
  }

  return {
    userId: user.id,
    email: user.email ?? profile.email,
    profile: profile as Profile,
    grants: (grants ?? []) as Grant[],
    isCeo: profile.system_role === "ceo",
    isAdmin: profile.system_role === "ceo" || profile.system_role === "admin",
  };
});

/** Permission détenue globalement (sans périmètre). */
export function can(ctx: AppContext, perm: string) {
  if (ctx.isCeo) return true;
  if (ADMIN_PERMS.has(perm) && ctx.isAdmin) return true;
  return ctx.grants.some((g) => g.permission === perm && g.scope_unit_id === null);
}

/** Permission détenue globalement ou sur au moins une unité. */
export function canAnywhere(ctx: AppContext, perm: string) {
  return can(ctx, perm) || ctx.grants.some((g) => g.permission === perm);
}

/** Permission sur une unité donnée (vérifiée par la base, qui connaît la hiérarchie). */
export async function canOnUnit(perm: string, unitId: string | null | undefined) {
  if (!unitId) return false;
  const supabase = await createClient();
  const { data } = await supabase.rpc("has_perm", { p_perm: perm, p_unit: unitId });
  return Boolean(data);
}

export function navAccess(ctx: AppContext) {
  const operations = can(ctx, "ops.plan") || can(ctx, "ops.review") || can(ctx, "projects.admin") || can(ctx, "dashboard.exec");
  const legal = can(ctx, "legal.view") || can(ctx, "legal.admin") || can(ctx, "dashboard.exec");
  return {
    direction: can(ctx, "dashboard.exec"),
    crm: canAnywhere(ctx, "crm.view") || canAnywhere(ctx, "crm.edit") || can(ctx, "dashboard.exec"),
    finance: can(ctx, "finance.view") || can(ctx, "finance.admin") || can(ctx, "dashboard.exec") || canAnywhere(ctx, "unit.manage"),
    hrAdmin: can(ctx, "hr.view") || can(ctx, "hr.admin"),
    admin: can(ctx, "users.admin") || can(ctx, "audit.view") || can(ctx, "grants.manage"),
    operations,
    legal,
    // Le guichet des validations s'adresse à ceux qui décident et à ceux qui soumettent.
    approvals: ctx.isCeo || can(ctx, "approvals.decide") || can(ctx, "finance.admin") || can(ctx, "legal.admin")
      || can(ctx, "ops.plan") || canAnywhere(ctx, "unit.manage") || can(ctx, "hr.admin"),
  };
}

/**
 * Rôles qui manipulent l'argent, les personnes, les contrats ou les droits :
 * la double authentification leur est imposée (la base exige le niveau aal2
 * pour ces opérations, l'interface les fait enrôler dès l'entrée).
 */
const STRONG_AUTH_PERMS = [
  "finance.admin", "finance.view", "hr.admin", "legal.admin", "approvals.decide",
  "grants.manage", "users.admin", "docs.confidential", "dashboard.exec",
];

export function needsStrongAuth(ctx: AppContext) {
  return ctx.isAdmin || STRONG_AUTH_PERMS.some((p) => ctx.grants.some((g) => g.permission === p));
}

/** Peut décider des validations de la holding (le CEO, ou une délégation explicite). */
export function canDecideApprovals(ctx: AppContext) {
  return ctx.isCeo || can(ctx, "approvals.decide");
}
