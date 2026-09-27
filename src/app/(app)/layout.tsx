import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getContext, navAccess } from "@/lib/auth";
import { systemRole } from "@/lib/labels";
import { SidebarNav } from "@/components/shell/sidebar";
import { Topbar } from "@/components/shell/topbar";
import { PwaRegistrar } from "@/components/shell/pwa";
import { BottomNav } from "@/components/shell/bottom-nav";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const ctx = await getContext();
  const supabase = await createClient();

  // Le code d'accès personnel est exigé par le middleware (écran /verrou) : on
  // n'arrive ici qu'une fois l'espace déverrouillé pour la session en cours.

  // Annuaire, mentions, organigramme : tout repose sur des fiches remplies.
  // Tant que la sienne ne l'est pas, l'application reste fermée.
  if (!ctx.profile.profile_completed_at) redirect("/completer-profil");

  // Présence : met à jour la dernière activité (au plus toutes les 5 minutes)
  if (!ctx.profile.last_seen_at || Date.now() - new Date(ctx.profile.last_seen_at).getTime() > 5 * 60000) {
    await supabase.from("profiles").update({ last_seen_at: new Date().toISOString() }).eq("id", ctx.userId);
  }

  const { data: channels } = await supabase.rpc("my_channels");
  const unreadMessages = ((channels as { unread: number }[] | null) ?? []).reduce((s, c) => s + (c.unread ?? 0), 0);

  const nav = navAccess(ctx);
  const access = {
    direction: nav.direction, crm: nav.crm, finance: nav.finance, admin: nav.admin,
    operations: nav.operations, legal: nav.legal, approvals: nav.approvals,
  };

  return (
    <div className="flex min-h-screen">
      <PwaRegistrar />
      <aside className="fixed inset-y-0 left-0 z-40 hidden w-64 bg-sidebar lg:block print:hidden">
        <SidebarNav access={access} unreadMessages={unreadMessages} />
      </aside>
      <div className="flex min-w-0 flex-1 flex-col lg:pl-64 print:pl-0">
        <div className="contents print:hidden"><Topbar
          access={access}
          unreadMessages={unreadMessages}
          user={{
            id: ctx.userId,
            name: ctx.profile.full_name || ctx.email,
            email: ctx.email,
            avatar: ctx.profile.avatar_url,
            title: ctx.profile.job_title,
            role: systemRole[ctx.profile.system_role],
          }}
        /></div>
        <main className="mx-auto w-full max-w-[1400px] flex-1 px-4 pb-24 pt-5 sm:px-6 sm:pt-6 lg:px-8 lg:pb-10 lg:pt-8 print:pb-0">
          {children}
        </main>
      </div>
      <BottomNav access={access} unreadMessages={unreadMessages} />
    </div>
  );
}
