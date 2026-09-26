import { createClient } from "@/lib/supabase/server";
import { getContext } from "@/lib/auth";
import { PageHeader } from "@/components/ui/misc";
import { LinkTabs } from "@/components/ui/tabs";
import { ProfileSettings, SecuritySettings } from "./settings-client";
import { NotificationSettings } from "./notification-settings";
import { DEFAULT_PREFERENCES, type NotificationPreferences } from "@/lib/notifications";
import { mailerConfigured } from "@/lib/server/mailer";
import { pushConfigured } from "@/lib/server/push";

export const metadata = { title: "Paramètres" };

export default async function SettingsPage({ searchParams }: { searchParams: Promise<{ onglet?: string }> }) {
  const { onglet = "profil" } = await searchParams;
  const ctx = await getContext();
  const supabase = await createClient();
  const [{ data: factors }, { data: prefs }, { data: devices }] = await Promise.all([
    supabase.auth.mfa.listFactors(),
    onglet === "notifications" ? supabase.from("notification_preferences").select("*").eq("profile_id", ctx.userId).maybeSingle() : Promise.resolve({ data: null }),
    onglet === "notifications" ? supabase.from("push_subscriptions").select("id, endpoint, device, created_at, last_used_at").order("created_at", { ascending: false }) : Promise.resolve({ data: null }),
  ]);
  return (
    <div className="max-w-3xl">
      <PageHeader title="Paramètres" description="Votre profil, vos notifications, votre sécurité et vos sessions." />
      <LinkTabs basePath="/parametres" active={onglet} className="mb-6" tabs={[{ key: "profil", label: "Profil" }, { key: "notifications", label: "Notifications" }, { key: "securite", label: "Sécurité & sessions" }]} />
      {onglet === "notifications" ? (
        <NotificationSettings
          initial={{ ...DEFAULT_PREFERENCES, ...((prefs ?? {}) as Partial<NotificationPreferences>) }}
          devices={devices ?? []}
          email={ctx.email}
          pushReady={pushConfigured()}
          mailReady={mailerConfigured()}
        />
      ) : onglet === "securite" ? (
        <SecuritySettings factors={(factors?.totp ?? []).map((f) => ({ id: f.id, name: f.friendly_name ?? "Application", status: f.status, created_at: f.created_at }))} email={ctx.email} />
      ) : (
        <ProfileSettings profile={ctx.profile} />
      )}
    </div>
  );
}
