/**
 * Déconnexion complète : la route serveur ferme la session Supabase **et**
 * efface le verrou du code d'accès (cookie httpOnly, hors de portée du
 * navigateur). D'où ce passage par le serveur plutôt qu'un signOut() local.
 */
export async function logout() {
  await fetch("/auth/deconnexion", { method: "POST", redirect: "manual" });
  window.location.href = "/connexion";
}
