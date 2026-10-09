"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { can, getContext } from "@/lib/auth";
import { fail, numVal, ok, str } from "@/lib/actions";
import type { ActionResult, MembershipRole, SystemRole } from "@/lib/types";

async function requireAdmin(perm = "users.admin") {
  const ctx = await getContext();
  if (!can(ctx, perm)) throw new Error("Action réservée aux administrateurs.");
  return ctx;
}

export async function inviteUser(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  try {
    const ctx = await requireAdmin();
    const email = str(fd, "email")?.toLowerCase();
    const domain = process.env.NEXT_PUBLIC_EMAIL_DOMAIN ?? "veriion.com";
    if (!email || !email.endsWith(`@${domain}`)) return fail(`L'adresse doit appartenir au domaine @${domain}.`);
    const systemRole = (str(fd, "system_role") ?? "employee") as SystemRole;
    if (systemRole === "ceo" && !ctx.isCeo) return fail("Seul le CEO peut désigner un CEO.");
    const unit = str(fd, "unit_id");
    const admin = createAdminClient();
    const site = process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000";
    const { data, error } = await admin.auth.admin.inviteUserByEmail(email, {
      redirectTo: `${site}/auth/callback?suite=/definir-mot-de-passe`,
      data: { first_name: str(fd, "first_name"), last_name: str(fd, "last_name"), job_title: str(fd, "job_title"), primary_unit_id: unit },
    });
    if (error) return fail(error.message.includes("already") ? "Un compte existe déjà pour cette adresse." : error.message);
    const userId = data.user.id;
    const supabase = await createClient();
    if (systemRole !== "employee") {
      const { error: e } = await supabase.from("profiles").update({ system_role: systemRole }).eq("id", userId);
      if (e) return fail(e);
    }
    const manager = str(fd, "manager_id");
    if (manager) await supabase.from("profiles").update({ manager_id: manager }).eq("id", userId);
    if (unit) {
      const { error: e } = await supabase.rpc("appoint_member", {
        p_unit: unit, p_profile: userId, p_role: (str(fd, "role") ?? "member") as MembershipRole, p_title: str(fd, "job_title"),
      });
      if (e) return fail(e);
    }
    revalidatePath("/admin");
    revalidatePath("/annuaire");
    return ok(`Invitation envoyée à ${email}.`);
  } catch (e) {
    return fail(e instanceof Error ? e.message : "Erreur");
  }
}

export async function setUserStatus(profileId: string, status: "active" | "suspended"): Promise<ActionResult> {
  try {
    const ctx = await requireAdmin();
    if (profileId === ctx.userId) return fail("Vous ne pouvez pas modifier votre propre statut.");
    const supabase = await createClient();
    const { data: target } = await supabase.from("profiles").select("system_role, status").eq("id", profileId).single();
    if (!target) return fail("Compte introuvable.");
    if (target.system_role === "ceo" && !ctx.isCeo) return fail("Seul le CEO peut agir sur le compte d'un CEO.");
    const { data: changed, error } = await supabase.from("profiles").update({ status }).eq("id", profileId).select("id");
    if (error) return fail(error);
    if (!changed?.length) return fail("Modification refusée.");
    // Bloque aussi la connexion côté Supabase Auth ; en cas d'échec, on revient en arrière.
    const admin = createAdminClient();
    const { error: banError } = await admin.auth.admin.updateUserById(profileId, { ban_duration: status === "suspended" ? "876000h" : "none" });
    if (banError) {
      await supabase.from("profiles").update({ status: target.status }).eq("id", profileId);
      return fail(`Le blocage de la connexion a échoué (${banError.message}) : rien n'a été modifié.`);
    }
    revalidatePath("/admin");
    return ok(status === "suspended" ? "Compte suspendu : la personne ne peut plus se connecter." : "Compte réactivé.");
  } catch (e) {
    return fail(e instanceof Error ? e.message : "Erreur");
  }
}

export async function offboardUser(profileId: string): Promise<ActionResult> {
  try {
    await requireAdmin();
    const supabase = await createClient();
    const { error } = await supabase.rpc("offboard_employee", { p_profile: profileId });
    if (error) return fail(error);
    const admin = createAdminClient();
    const { error: banError } = await admin.auth.admin.updateUserById(profileId, { ban_duration: "876000h" });
    revalidatePath("/admin");
    revalidatePath("/annuaire");
    if (banError) return fail(`Départ enregistré, mais le blocage de la connexion a échoué (${banError.message}). Les données restent inaccessibles (compte inactif) ; relancez le blocage depuis Supabase.`);
    return ok("Départ enregistré : accès révoqués, tâches désassignées, checklist de départ créée.");
  } catch (e) {
    return fail(e instanceof Error ? e.message : "Erreur");
  }
}

export async function sendPasswordReset(email: string): Promise<ActionResult> {
  try {
    await requireAdmin();
    const supabase = await createClient();
    const site = process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000";
    const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo: `${site}/auth/callback?suite=/definir-mot-de-passe` });
    if (error) return fail(error.message);
    return ok("Lien de réinitialisation envoyé.");
  } catch (e) {
    return fail(e instanceof Error ? e.message : "Erreur");
  }
}

/**
 * Code d'accès oublié : on l'efface. La personne reste connectée sur ses
 * appareils déjà déverrouillés et choisit un nouveau code à la prochaine session.
 */
export async function resetAccessCode(profileId: string): Promise<ActionResult> {
  try {
    await requireAdmin();
    const supabase = await createClient();
    const { error } = await supabase.rpc("clear_access_code", { p_profile: profileId });
    if (error) return fail(error);
    revalidatePath("/admin");
    return ok("Code d'accès réinitialisé : la personne en définira un nouveau à sa prochaine ouverture.");
  } catch (e) {
    return fail(e instanceof Error ? e.message : "Erreur");
  }
}

export async function grantException(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const days = numVal(fd, "days");
  if (!days || days < 1) return fail("Indiquez la durée de la dérogation.");
  const { error } = await supabase.from("role_grants").insert({
    profile_id: str(fd, "profile_id"),
    permission: str(fd, "permission"),
    scope_unit_id: str(fd, "scope_unit_id"),
    reason: str(fd, "reason"),
    expires_at: new Date(Date.now() + days * 86400000).toISOString(),
    source: "manual",
    granted_by: user!.id,
  });
  if (error) return fail(error);
  revalidatePath("/admin");
  return ok("Dérogation accordée et journalisée.");
}

export async function revokeGrant(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("role_grants").delete().eq("id", id);
  if (error) return fail(error);
  revalidatePath("/admin");
  return ok("Dérogation révoquée.");
}

export async function addTemplate(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("role_templates").insert({
    domain: str(fd, "domain"), membership_role: str(fd, "membership_role") ?? "head", permission: str(fd, "permission"), scoped: fd.get("scoped") === "on",
  });
  if (error) return fail(error);
  revalidatePath("/admin");
  return ok("Règle ajoutée : les droits de tous ont été recalculés.");
}

export async function removeTemplate(id: string): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("role_templates").delete().eq("id", id);
  if (error) return fail(error);
  revalidatePath("/admin");
  return ok("Règle supprimée : les droits de tous ont été recalculés.");
}

export async function saveSettings(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("company_settings").update({
    company_name: str(fd, "company_name") ?? "VERIION",
    email_domain: str(fd, "email_domain") ?? "veriion.com",
    currency: str(fd, "currency") ?? "XOF",
    timezone: str(fd, "timezone") ?? "Africa/Porto-Novo",
    opening_cash: numVal(fd, "opening_cash") ?? 0,
    default_tax_rate: numVal(fd, "default_tax_rate") ?? 18,
    updated_at: new Date().toISOString(),
  }).eq("id", true);
  if (error) return fail(error);
  revalidatePath("/", "layout");
  return ok("Paramètres enregistrés.");
}
