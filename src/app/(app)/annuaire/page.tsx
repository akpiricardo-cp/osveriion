import { createClient } from "@/lib/supabase/server";
import { getUnits } from "@/lib/data";
import { getContext } from "@/lib/auth";
import { PageHeader } from "@/components/ui/misc";
import { Directory } from "./directory";

export const metadata = { title: "Annuaire" };

export default async function DirectoryPage() {
  const ctx = await getContext();
  const supabase = await createClient();
  const [{ data: people }, units, { data: memberships }] = await Promise.all([
    supabase.from("profiles").select("id, full_name, email, job_title, avatar_url, phone, location, primary_unit_id, last_seen_at").eq("status", "active").order("first_name"),
    getUnits(),
    supabase.from("unit_memberships").select("profile_id, unit_id, role").is("end_date", null),
  ]);
  const unitName = Object.fromEntries(units.map((u) => [u.id, { name: u.name, color: u.color, path: u.path }]));
  return (
    <div>
      <PageHeader title="Annuaire" description={`${people?.length ?? 0} collaborateurs actifs chez VERIION.`} />
      <Directory
        people={people ?? []}
        units={unitName}
        departments={units.filter((u) => u.depth === 1).map((u) => ({ id: u.id, name: u.name }))}
        memberships={memberships ?? []}
        me={ctx.userId}
      />
    </div>
  );
}
