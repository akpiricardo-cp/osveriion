"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Archive, Rocket, UserPlus, Users, X } from "lucide-react";
import { toast } from "sonner";
import { Avatar } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import { Select } from "@/components/ui/input";
import type { ProfileLite } from "@/lib/types";
import { activateProject, archiveProject, requestProjectLaunch, setProjectMember } from "../actions";

const ROLES = { lead: "Responsable", member: "Contributeur", viewer: "Lecteur" } as const;

export function MembersButton({ projectId, people, members }: { projectId: string; people: ProfileLite[]; members: { profile_id: string; role: string }[] }) {
  const [pick, setPick] = useState("");
  const [pending, start] = useTransition();
  const pm = new Map(people.map((p) => [p.id, p]));
  const run = (profile: string, role: keyof typeof ROLES | null) =>
    start(async () => {
      const r = await setProjectMember(projectId, profile, role);
      if (r.ok) toast.success(r.message); else toast.error(r.error);
    });
  return (
    <Dialog>
      <DialogTrigger asChild><Button size="sm" variant="outline"><Users className="h-4 w-4" /> Équipe</Button></DialogTrigger>
      <DialogContent title="Équipe du projet" description="Les contributeurs peuvent créer et déplacer les tâches ; les lecteurs consultent seulement.">
        <div className="mb-4 flex gap-2">
          <Select value={pick} onChange={(e) => setPick(e.target.value)}>
            <option value="">Ajouter une personne…</option>
            {people.filter((p) => !members.some((m) => m.profile_id === p.id)).map((p) => <option key={p.id} value={p.id}>{p.full_name}</option>)}
          </Select>
          <Button disabled={!pick} loading={pending} onClick={() => { run(pick, "member"); setPick(""); }}><UserPlus className="h-4 w-4" /></Button>
        </div>
        <ul className="divide-y divide-border rounded-xl border border-border">
          {members.map((m) => {
            const p = pm.get(m.profile_id);
            return (
              <li key={m.profile_id} className="flex items-center gap-3 px-3 py-2.5">
                <Avatar name={p?.full_name} src={p?.avatar_url} size="sm" />
                <span className="flex-1 truncate text-sm text-fg">{p?.full_name ?? "Ancien membre"}</span>
                <div className="w-36">
                  <Select value={m.role} onChange={(e) => run(m.profile_id, e.target.value as keyof typeof ROLES)} disabled={pending}>
                    {Object.entries(ROLES).map(([k, l]) => <option key={k} value={k}>{l}</option>)}
                  </Select>
                </div>
                <button onClick={() => run(m.profile_id, null)} className="rounded p-1 text-subtle hover:text-danger" aria-label="Retirer"><X className="h-4 w-4" /></button>
              </li>
            );
          })}
        </ul>
      </DialogContent>
    </Dialog>
  );
}

export function ArchiveProjectButton({ id }: { id: string }) {
  const [pending, start] = useTransition();
  const router = useRouter();
  return (
    <Button size="sm" variant="ghost" loading={pending} onClick={() => {
      if (!confirm("Archiver ce projet ? Il n'apparaîtra plus dans les listes, l'historique est conservé.")) return;
      start(async () => {
        const r = await archiveProject(id);
        if (r.ok) { toast.success(r.message); router.push("/projets"); } else toast.error(r.error);
      });
    }}>
      <Archive className="h-4 w-4" />
    </Button>
  );
}

/**
 * Lancement d'un projet : il faut l'accord du CEO. Une fois l'accord obtenu, le
 * chef de projet acte le démarrage.
 */
export function LaunchProjectButton({ id, approved, pending: waiting }: { id: string; approved: boolean; pending: boolean }) {
  const [busy, start] = useTransition();
  const router = useRouter();
  const run = (fn: () => Promise<{ ok: boolean; message?: string; error?: string }>) =>
    start(async () => {
      const r = await fn();
      if (r.ok) { toast.success(r.message); router.refresh(); } else toast.error(r.error);
    });

  if (approved) {
    return (
      <Button size="sm" loading={busy} onClick={() => run(() => activateProject(id))}>
        <Rocket className="h-4 w-4" /> Lancer le projet
      </Button>
    );
  }
  return (
    <Button size="sm" variant="outline" loading={busy} disabled={waiting} onClick={() => run(() => requestProjectLaunch(id))}>
      <Rocket className="h-4 w-4" /> {waiting ? "En attente du CEO" : "Demander le lancement"}
    </Button>
  );
}
