"use client";

import { useTransition } from "react";
import { UserMinus } from "lucide-react";
import { toast } from "sonner";
import { endMembership } from "../actions";

export function EndMembershipButton({ membershipId, unitId }: { membershipId: string; unitId: string }) {
  const [pending, start] = useTransition();
  return (
    <button
      disabled={pending}
      title="Clôturer l'affectation"
      onClick={() => {
        if (!confirm("Clôturer cette affectation ? Les droits associés seront retirés ; l'historique est conservé.")) return;
        start(async () => {
          const r = await endMembership(membershipId, unitId);
          if (r.ok) toast.success(r.message); else toast.error(r.error);
        });
      }}
      className="rounded-md p-1.5 text-subtle transition hover:bg-danger/10 hover:text-danger disabled:opacity-50"
    >
      <UserMinus className="h-4 w-4" />
    </button>
  );
}
