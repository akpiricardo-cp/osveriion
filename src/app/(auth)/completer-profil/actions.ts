"use server";

import { createClient } from "@/lib/supabase/server";
import { fail, ok, str } from "@/lib/actions";
import type { ActionResult } from "@/lib/types";

/**
 * Complète sa fiche avant d'entrer dans l'application. L'annuaire, les canaux
 * et l'organigramme s'appuient dessus : une fiche vide rend l'outil inutilisable
 * pour les autres. L'intitulé de poste, lui, ne se saisit pas — il vient de la
 * nomination.
 */
export async function completeProfile(_: ActionResult | null, fd: FormData): Promise<ActionResult> {
  const first = str(fd, "first_name");
  const last = str(fd, "last_name");
  const phone = str(fd, "phone");
  const location = str(fd, "location");

  if (!first || first.length < 2) return fail("Indiquez votre prénom.");
  if (!last || last.length < 2) return fail("Indiquez votre nom.");
  if (!phone || phone.replace(/\D/g, "").length < 8) return fail("Indiquez un numéro de téléphone joignable.");
  if (!location || location.length < 2) return fail("Indiquez votre ville et votre pays.");

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return fail("Session expirée. Reconnectez-vous.");

  const { error } = await supabase
    .from("profiles")
    .update({
      first_name: first,
      last_name: last,
      phone,
      location,
      bio: str(fd, "bio"),
      birth_date: str(fd, "birth_date"),
    })
    .eq("id", user.id);
  if (error) return fail(error);
  return ok("Profil complété. Bienvenue dans VERIION OS.");
}
