import "server-only";
import { createClient } from "@supabase/supabase-js";

/**
 * Client « service role » : contourne RLS. À n'utiliser que dans des actions
 * serveur qui ont déjà vérifié les permissions de l'appelant.
 */
export function createAdminClient() {
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!key) throw new Error("SUPABASE_SERVICE_ROLE_KEY manquante : impossible d'administrer les comptes.");
  return createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
