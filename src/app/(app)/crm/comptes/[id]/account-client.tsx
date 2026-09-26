"use client";

import { useTransition } from "react";
import { Trash2 } from "lucide-react";
import { toast } from "sonner";
import { deleteContact } from "../../actions";

export function DeleteContact({ id, accountId }: { id: string; accountId: string }) {
  const [pending, start] = useTransition();
  return (
    <button disabled={pending} aria-label="Supprimer" className="rounded p-1 text-subtle hover:text-danger disabled:opacity-50"
      onClick={() => confirm("Supprimer ce contact ?") && start(async () => { const r = await deleteContact(id, accountId); if (!r.ok) toast.error(r.error); })}>
      <Trash2 className="h-4 w-4" />
    </button>
  );
}
