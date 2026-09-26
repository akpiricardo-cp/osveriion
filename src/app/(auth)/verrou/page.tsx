import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { LockScreen } from "./lock-screen";

export const metadata: Metadata = { title: "Code d'accès" };

export default async function VerrouPage({ searchParams }: { searchParams: Promise<{ suite?: string }> }) {
  const { suite } = await searchParams;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/connexion");

  const [{ data: hasCode }, { data: profile }] = await Promise.all([
    supabase.rpc("has_access_code"),
    supabase.from("profiles").select("first_name, full_name, avatar_url").eq("id", user.id).maybeSingle(),
  ]);

  return (
    <LockScreen
      hasCode={Boolean(hasCode)}
      suite={suite?.startsWith("/") && !suite.startsWith("//") ? suite : "/"}
      name={profile?.first_name || profile?.full_name || null}
      email={user.email ?? ""}
      avatar={profile?.avatar_url ?? null}
    />
  );
}
