import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { ProfileForm } from "./profile-form";

export const metadata: Metadata = { title: "Compléter mon profil" };

export default async function CompleteProfilePage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/connexion");

  const { data: profile } = await supabase
    .from("profiles")
    .select("first_name, last_name, phone, location, bio, birth_date, job_title, profile_completed_at")
    .eq("id", user.id)
    .maybeSingle();

  if (profile?.profile_completed_at) redirect("/");

  return (
    <ProfileForm
      email={user.email ?? ""}
      jobTitle={profile?.job_title ?? null}
      initial={{
        first_name: profile?.first_name ?? "",
        last_name: profile?.last_name ?? "",
        phone: profile?.phone ?? "",
        location: profile?.location ?? "",
        bio: profile?.bio ?? "",
        birth_date: profile?.birth_date ?? "",
      }}
    />
  );
}
