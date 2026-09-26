import { Suspense } from "react";
import { createClient } from "@/lib/supabase/server";
import { getContext } from "@/lib/auth";
import { getPeople } from "@/lib/data";
import { PageHeader } from "@/components/ui/misc";
import { LinkTabs } from "@/components/ui/tabs";
import type { Task } from "@/lib/types";
import { MyTasks } from "./my-tasks";

export const metadata = { title: "Mes tâches" };

export default async function TasksPage({ searchParams }: { searchParams: Promise<{ onglet?: string }> }) {
  const { onglet = "assignees" } = await searchParams;
  const ctx = await getContext();
  const supabase = await createClient();
  let query = supabase.from("tasks").select("*, projects(name, color)").is("parent_id", null);
  if (onglet === "creees") query = query.eq("reporter_id", ctx.userId).neq("assignee_id", ctx.userId).neq("status", "done");
  else if (onglet === "terminees") query = query.eq("assignee_id", ctx.userId).eq("status", "done").order("completed_at", { ascending: false }).limit(50);
  else query = query.eq("assignee_id", ctx.userId).neq("status", "done");
  const [{ data }, people] = await Promise.all([query.order("due_date", { ascending: true, nullsFirst: false }), getPeople()]);

  return (
    <div>
      <PageHeader title="Mes tâches" description="Toutes vos tâches, tous projets confondus, classées par échéance." />
      <LinkTabs basePath="/taches" active={onglet} className="mb-6" tabs={[
        { key: "assignees", label: "Assignées à moi" },
        { key: "creees", label: "Déléguées" },
        { key: "terminees", label: "Terminées" },
      ]} />
      <Suspense>
        <MyTasks tasks={(data as (Task & { projects: { name: string; color: string } | null })[]) ?? []} people={people} mode={onglet} />
      </Suspense>
    </div>
  );
}
