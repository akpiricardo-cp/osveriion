"use client";

import { useEffect, useMemo, useState, useTransition } from "react";
import { Building2, ChevronRight, Folder, Globe, Loader2, Lock, Trash2, UserPlus, Users } from "lucide-react";
import { toast } from "sonner";
import { createClient } from "@/lib/supabase/client";
import { Avatar } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { Input, Select } from "@/components/ui/input";
import { ROLE_LABEL, type FolderSpace, type Share, type ShareRole } from "@/lib/drive";
import type { ProfileLite } from "@/lib/types";
import { cn } from "@/lib/utils";
import { addShare, removeShare, updateShareRole } from "@/app/(app)/documents/actions";

export type UnitLite = { id: string; name: string; color: string; depth: number };

// ─── Saisie d'un nom (création / renommage) ─────────────────────────────────
export function NameDialog({
  open, onOpenChange, title, label = "Nom", initial = "", submitLabel = "Valider", onSubmit,
}: {
  open: boolean; onOpenChange: (o: boolean) => void; title: string; label?: string; initial?: string; submitLabel?: string;
  onSubmit: (value: string) => Promise<boolean>;
}) {
  const [value, setValue] = useState(initial);
  const [pending, start] = useTransition();
  useEffect(() => { if (open) setValue(initial); }, [open, initial]);
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent title={title} size="sm">
        <form onSubmit={(e) => { e.preventDefault(); start(async () => { if (await onSubmit(value)) onOpenChange(false); }); }} className="space-y-4">
          <div>
            <label className="mb-1.5 block text-[13px] font-medium text-fg">{label}</label>
            <Input autoFocus value={value} onChange={(e) => setValue(e.target.value)} onFocus={(e) => e.currentTarget.select()} maxLength={120} />
          </div>
          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={() => onOpenChange(false)}>Annuler</Button>
            <Button type="submit" loading={pending} disabled={!value.trim()}>{submitLabel}</Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}

// ─── Choix d'un dossier de destination ──────────────────────────────────────
type TreeNode = { id: string; parent_id: string | null; name: string; space: FolderSpace; depth: number; is_root: boolean };
const SPACE_ICON = { personal: Lock, company: Globe, unit: Building2, project: Folder };

export function MoveDialog({
  open, onOpenChange, title, excludeId, onPick,
}: { open: boolean; onOpenChange: (o: boolean) => void; title: string; excludeId?: string; onPick: (folderId: string) => Promise<boolean> }) {
  const [nodes, setNodes] = useState<TreeNode[] | null>(null);
  const [expanded, setExpanded] = useState<Set<string>>(new Set());
  const [selected, setSelected] = useState<string | null>(null);
  const [q, setQ] = useState("");
  const [pending, start] = useTransition();

  useEffect(() => {
    if (!open) return;
    setSelected(null);
    createClient().rpc("drive_tree").then(({ data }) => setNodes((data as TreeNode[]) ?? []));
  }, [open]);

  const visible = useMemo(() => {
    if (!nodes) return [];
    const excluded = new Set<string>();
    if (excludeId) {
      // exclut le dossier déplacé et ses descendants
      const walk = (id: string) => { excluded.add(id); nodes.filter((n) => n.parent_id === id).forEach((n) => walk(n.id)); };
      walk(excludeId);
    }
    return nodes.filter((n) => !excluded.has(n.id));
  }, [nodes, excludeId]);

  const children = (pid: string | null) => visible.filter((n) => (pid === null ? !visible.some((p) => p.id === n.parent_id) : n.parent_id === pid));
  const matches = q.trim() ? visible.filter((n) => n.name.toLowerCase().includes(q.toLowerCase())) : null;

  const Row = ({ n, depth }: { n: TreeNode; depth: number }) => {
    const kids = children(n.id);
    const isOpen = expanded.has(n.id);
    const Icon = n.is_root ? SPACE_ICON[n.space] : Folder;
    return (
      <li>
        <div className={cn("flex items-center gap-1 rounded-lg pr-2 transition", selected === n.id ? "bg-primary/10 text-primary" : "hover:bg-surface-2")} style={{ paddingLeft: depth * 16 + 4 }}>
          <button type="button" onClick={() => setExpanded((s) => { const x = new Set(s); if (x.has(n.id)) x.delete(n.id); else x.add(n.id); return x; })}
            className={cn("grid h-6 w-6 place-items-center rounded text-subtle", !kids.length && "invisible")} aria-label="Déplier">
            <ChevronRight className={cn("h-4 w-4 transition", isOpen && "rotate-90")} />
          </button>
          <button type="button" onClick={() => setSelected(n.id)} onDoubleClick={() => start(async () => { if (await onPick(n.id)) onOpenChange(false); })}
            className="flex min-w-0 flex-1 items-center gap-2 py-1.5 text-left text-sm">
            <Icon className="h-4 w-4 shrink-0 opacity-70" /><span className="truncate">{n.name}</span>
          </button>
        </div>
        {isOpen && kids.length > 0 && <ul>{kids.map((k) => <Row key={k.id} n={k} depth={depth + 1} />)}</ul>}
      </li>
    );
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent title={title} description="Seuls les dossiers dans lesquels vous pouvez écrire sont proposés.">
        <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Rechercher un dossier…" className="mb-3" />
        <div className="scrollbar-thin h-80 overflow-y-auto rounded-xl border border-border p-2">
          {!nodes ? (
            <div className="grid h-full place-items-center"><Loader2 className="h-5 w-5 animate-spin text-subtle" /></div>
          ) : matches ? (
            <ul>{matches.map((n) => <Row key={n.id} n={n} depth={0} />)}</ul>
          ) : (
            <ul>{children(null).map((n) => <Row key={n.id} n={n} depth={0} />)}</ul>
          )}
        </div>
        <div className="mt-4 flex justify-end gap-2">
          <Button variant="ghost" onClick={() => onOpenChange(false)}>Annuler</Button>
          <Button disabled={!selected} loading={pending} onClick={() => selected && start(async () => { if (await onPick(selected)) onOpenChange(false); })}>Déplacer ici</Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}

// ─── Partage ────────────────────────────────────────────────────────────────
const INHERITED: Record<FolderSpace, string> = {
  personal: "Espace personnel : privé. Seules les personnes et unités ajoutées ci-dessous y ont accès — la direction comprise.",
  unit: "Espace de département : tous ses membres peuvent consulter et modifier ; les responsables gèrent. Les accès ci-dessous s'ajoutent.",
  project: "Espace de projet : l'équipe du projet contribue, les responsables gèrent. Les accès ci-dessous s'ajoutent.",
  company: "Espace entreprise : tous les collaborateurs peuvent consulter ; la direction gère. Les accès ci-dessous s'ajoutent.",
};

export function ShareDialog({
  open, onOpenChange, target, name, space, people, units, access,
}: {
  open: boolean; onOpenChange: (o: boolean) => void; target: { folderId?: string; documentId?: string };
  name: string; space?: FolderSpace; people: ProfileLite[]; units: UnitLite[]; access: number;
}) {
  const [shares, setShares] = useState<Share[] | null>(null);
  const [kind, setKind] = useState<"person" | "unit">("person");
  const [who, setWho] = useState("");
  const [role, setRole] = useState<ShareRole>("viewer");
  const [days, setDays] = useState("");
  const [pending, start] = useTransition();
  const pm = useMemo(() => new Map(people.map((p) => [p.id, p])), [people]);
  const um = useMemo(() => new Map(units.map((u) => [u.id, u])), [units]);

  const load = () => {
    const q = createClient().from("shares").select("*").order("created_at");
    (target.folderId ? q.eq("folder_id", target.folderId) : q.eq("document_id", target.documentId!)).then(({ data }) => setShares((data as Share[]) ?? []));
  };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { if (open) load(); }, [open, target.folderId, target.documentId]);

  const roles = (Object.keys(ROLE_LABEL) as ShareRole[]).filter((r) => ({ viewer: 1, editor: 2, manager: 3 })[r] <= access);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent title={`Partager « ${name} »`} size="lg">
        {space && <p className="mb-4 rounded-xl bg-surface-2/70 px-4 py-3 text-[13px] text-muted">{INHERITED[space]}</p>}
        <form
          className="grid gap-2 sm:grid-cols-[120px_1fr_140px_120px_auto]"
          onSubmit={(e) => {
            e.preventDefault();
            if (!who) return;
            start(async () => {
              const r = await addShare(target, kind === "person" ? { profileId: who } : { unitId: who }, role, days ? Number(days) : undefined);
              if (r.ok) { toast.success(r.message); setWho(""); load(); } else toast.error(r.error);
            });
          }}
        >
          <Select value={kind} onChange={(e) => { setKind(e.target.value as "person" | "unit"); setWho(""); }}>
            <option value="person">Personne</option>
            <option value="unit">Unité</option>
          </Select>
          <Select value={who} onChange={(e) => setWho(e.target.value)}>
            <option value="">{kind === "person" ? "Choisir un collègue…" : "Choisir une unité…"}</option>
            {kind === "person"
              ? people.map((p) => <option key={p.id} value={p.id}>{p.full_name}</option>)
              : units.map((u) => <option key={u.id} value={u.id}>{"  ".repeat(u.depth)}{u.name}</option>)}
          </Select>
          <Select value={role} onChange={(e) => setRole(e.target.value as ShareRole)}>
            {roles.map((r) => <option key={r} value={r}>{ROLE_LABEL[r]}</option>)}
          </Select>
          <Select value={days} onChange={(e) => setDays(e.target.value)}>
            <option value="">Permanent</option>
            <option value="7">7 jours</option>
            <option value="30">30 jours</option>
            <option value="90">90 jours</option>
          </Select>
          <Button type="submit" loading={pending} disabled={!who}><UserPlus className="h-4 w-4" /> Ajouter</Button>
        </form>

        <div className="mt-5">
          <p className="mb-2 text-xs font-medium uppercase tracking-wider text-subtle">Accès accordés</p>
          {!shares ? (
            <Loader2 className="h-5 w-5 animate-spin text-subtle" />
          ) : shares.length === 0 ? (
            <p className="rounded-xl border border-dashed border-border px-4 py-6 text-center text-sm text-muted">Aucun partage particulier.</p>
          ) : (
            <ul className="divide-y divide-border rounded-xl border border-border">
              {shares.map((s) => {
                const p = s.profile_id ? pm.get(s.profile_id) : null;
                const u = s.unit_id ? um.get(s.unit_id) : null;
                return (
                  <li key={s.id} className="flex items-center gap-3 px-3 py-2.5">
                    {p ? <Avatar name={p.full_name} src={p.avatar_url} size="sm" /> : <span className="grid h-8 w-8 place-items-center rounded-full bg-surface-2 text-muted"><Users className="h-4 w-4" /></span>}
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium text-fg">{p?.full_name ?? (u ? `Unité · ${u.name}` : "—")}</p>
                      {s.expires_at && <p className="text-xs text-subtle">Expire le {new Date(s.expires_at).toLocaleDateString("fr-FR")}</p>}
                    </div>
                    <div className="w-40">
                      <Select value={s.role} disabled={access < 3} onChange={(e) => start(async () => {
                        const r = await updateShareRole(s.id, e.target.value as ShareRole);
                        if (!r.ok) toast.error(r.error); load();
                      })}>
                        {(Object.keys(ROLE_LABEL) as ShareRole[]).map((r) => <option key={r} value={r}>{ROLE_LABEL[r]}</option>)}
                      </Select>
                    </div>
                    <button aria-label="Retirer" className="rounded p-1.5 text-subtle hover:bg-danger/10 hover:text-danger"
                      onClick={() => start(async () => { const r = await removeShare(s.id); if (r.ok) load(); else toast.error(r.error); })}>
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
        <p className="mt-4 text-xs text-subtle">
          Lecteur : consulte et télécharge · Éditeur : modifie, ajoute, organise · Gestionnaire : partage, supprime définitivement.
        </p>
      </DialogContent>
    </Dialog>
  );
}
