import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { MfaScreen } from "./mfa-screen";

export const metadata: Metadata = { title: "Double authentification" };

export default async function MfaPage({ searchParams }: { searchParams: Promise<{ suite?: string; inscription?: string }> }) {
  const { suite, inscription } = await searchParams;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/connexion");

  const { data: factors } = await supabase.auth.mfa.listFactors();
  const verified = (factors?.totp ?? []).filter((f) => f.status === "verified");

  return (
    <MfaScreen
      factorId={verified[0]?.id ?? null}
      required={Boolean(inscription)}
      email={user.email ?? ""}
      suite={suite?.startsWith("/") && !suite.startsWith("//") ? suite : "/"}
    />
  );
}
