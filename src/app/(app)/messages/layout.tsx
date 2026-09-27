import { createClient } from "@/lib/supabase/server";
import { getContext } from "@/lib/auth";
import { getPeople } from "@/lib/data";
import type { ChannelSummary } from "@/lib/types";
import { ChannelList } from "./channel-list";

export const metadata = { title: "Messages" };

export default async function MessagesLayout({ children }: { children: React.ReactNode }) {
  const ctx = await getContext();
  const supabase = await createClient();
  const [{ data }, people] = await Promise.all([supabase.rpc("my_channels"), getPeople()]);
  return (
    <div className="-mx-4 -mb-24 -mt-5 flex h-[calc(100dvh-7rem)] overflow-hidden border-border bg-surface sm:-mx-6 sm:-mt-6 lg:-mx-8 lg:-mb-10 lg:-mt-8 lg:h-[calc(100dvh-4rem)]">
      <ChannelList channels={(data as ChannelSummary[]) ?? []} people={people.filter((p) => p.id !== ctx.userId)} userId={ctx.userId} />
      <section className="flex min-w-0 flex-1 flex-col">{children}</section>
    </div>
  );
}
