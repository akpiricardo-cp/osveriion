import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getContext, navAccess } from "@/lib/auth";
import { systemRole } from "@/lib/labels";
import { SidebarNav } from "@/components/shell/sidebar";
import { Topbar } from "@/components/shell/topbar";
import { PwaRegistrar } from "@/components/shell/pwa";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const ctx = await getContext();
  const supabase = await createClient();

  // Double authentification : vérification obligatoire si un facteur existe, activation si imposée.
  const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  if (aal?.nextLevel === "aal2" && aal.currentLevel !== "aal2") redirect("/mfa");
  if (process.env.REQUIRE_MFA === "true" && aal?.nextLevel !== "aal2") redirect("/mfa/activation");

  // Présence : met à jour la dernière activité (au plus toutes les 5 minutes)
  if (!ctx.profile.last_seen_at || Date.now() - new Date(ctx.profile.last_seen_at).getTime() > 5 * 60000) {
    await supabase.from("profiles").update({ last_seen_at: new Date().toISOString() }).eq("id", ctx.userId);
  }

  const { data: channels } = await supabase.rpc("my_channels");
  const unreadMessages = ((channels as { unread: number }[] | null) ?? []).reduce((s, c) => s + (c.unread ?? 0), 0);

  const nav = navAccess(ctx);
  const access = { direction: nav.direction, crm: nav.crm, finance: nav.finance, admin: nav.admin };

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
        <main className="mx-auto w-full max-w-[1400px] flex-1 px-4 py-6 sm:px-6 lg:px-8 lg:py-8">{children}</main>
      </div>
    </div>
  );
}
