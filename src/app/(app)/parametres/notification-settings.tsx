"use client";

import { useEffect, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { BellRing, Mail, Moon, MonitorSmartphone, Send, Smartphone, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { createClient } from "@/lib/supabase/client";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardHeader } from "@/components/ui/card";
import { Input, Select, Switch } from "@/components/ui/input";
import { NOTIFICATION_CATEGORIES, type EmailMode, type NotificationPreferences } from "@/lib/notifications";
import { currentSubscription, disablePush, enablePush, pushSupported } from "@/lib/push-client";
import { cn, relative } from "@/lib/utils";
import { savePreferences, sendTestEmail, sendTestPush } from "./actions";

type Device = { id: string; endpoint: string; device: string | null; created_at: string; last_used_at: string | null };

export function NotificationSettings({ initial, devices, email, pushReady, mailReady }: {
  initial: NotificationPreferences; devices: Device[]; email: string; pushReady: boolean; mailReady: boolean;
}) {
  const router = useRouter();
  const [p, setP] = useState<NotificationPreferences>(initial);
  const [dirty, setDirty] = useState(false);
  const [pending, start] = useTransition();
  const [busy, setBusy] = useState<string | null>(null);
  const [here, setHere] = useState<string | null>(null);
  const [support, setSupport] = useState<"yes" | "no" | "denied" | null>(null);

  useEffect(() => {
    if (!pushSupported()) { setSupport("no"); return; }
    setSupport(Notification.permission === "denied" ? "denied" : "yes");
    currentSubscription().then((s) => setHere(s?.endpoint ?? null)).catch(() => {});
  }, []);

  const set = (patch: Partial<NotificationPreferences>) => { setP((x) => ({ ...x, ...patch })); setDirty(true); };
  const toggle = (list: "email_off" | "push_off", key: string, on: boolean) =>
    set({ [list]: on ? p[list].filter((k) => k !== key) : [...p[list], key] } as Partial<NotificationPreferences>);

  const save = () => start(async () => {
    const r = await savePreferences(p);
    if (r.ok) { toast.success(r.message); setDirty(false); } else toast.error(r.error);
  });

  const hereRegistered = !!here && devices.some((d) => d.endpoint === here);

  return (
    <div className="space-y-6">
      {/* Appareils */}
      <Card>
        <CardHeader title="Notifications sur vos appareils" icon={<BellRing className="h-4 w-4" />}
          description="Recevez une alerte sur votre téléphone ou votre ordinateur, même lorsque VERIION OS est fermé."
          action={hereRegistered ? <Badge tone="green" dot>Activées ici</Badge> : undefined} />
        <div className="space-y-4 p-5">
          {!pushReady && (
            <p className="rounded-lg bg-amber-500/10 px-3 py-2 text-[13px] text-amber-700 dark:text-amber-300">
              Les notifications push ne sont pas encore configurées sur le serveur (clés VAPID). Les notifications dans l&apos;application et par e-mail fonctionnent.
            </p>
          )}
          {support === "no" && (
            <p className="text-[13px] text-muted">Ce navigateur ne prend pas en charge les notifications push. <strong>Sur iPhone :</strong> ouvrez VERIION OS dans Safari, touchez Partager → « Sur l&apos;écran d&apos;accueil », puis activez les notifications depuis l&apos;application installée.</p>
          )}
          {support === "denied" && (
            <p className="text-[13px] text-muted">Vous avez bloqué les notifications pour ce site. Autorisez-les dans les réglages du navigateur (icône à gauche de l&apos;adresse), puis revenez ici.</p>
          )}
          {support === "yes" && pushReady && (
            <div className="flex flex-wrap gap-2">
              {hereRegistered ? (
                <>
                  <Button size="sm" variant="outline" loading={busy === "test"} onClick={async () => {
                    setBusy("test"); const r = await sendTestPush(); setBusy(null);
                    if (r.ok) toast.success(r.message); else toast.error(r.error);
                  }}><Send className="h-4 w-4" /> Envoyer une notification de test</Button>
                  <Button size="sm" variant="ghost" loading={busy === "off"} onClick={async () => {
                    setBusy("off");
                    try { await disablePush(); setHere(null); toast.success("Notifications désactivées sur cet appareil."); router.refresh(); }
                    catch (e) { toast.error(e instanceof Error ? e.message : "Échec"); }
                    setBusy(null);
                  }}>Désactiver sur cet appareil</Button>
                </>
              ) : (
                <Button size="sm" loading={busy === "on"} onClick={async () => {
                  setBusy("on");
                  try { const s = await enablePush(); setHere(s.endpoint); toast.success("Notifications activées sur cet appareil."); router.refresh(); }
                  catch (e) { toast.error(e instanceof Error ? e.message : "Échec"); }
                  setBusy(null);
                }}><BellRing className="h-4 w-4" /> Activer sur cet appareil</Button>
              )}
            </div>
          )}

          {devices.length > 0 && (
            <ul className="divide-y divide-border rounded-xl border border-border">
              {devices.map((d) => (
                <li key={d.id} className="flex items-center gap-3 px-3 py-2.5">
                  {/iPhone|Android/.test(d.device ?? "") ? <Smartphone className="h-4 w-4 text-subtle" /> : <MonitorSmartphone className="h-4 w-4 text-subtle" />}
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm text-fg">{d.device ?? "Appareil"}{d.endpoint === here && <span className="ml-2 text-xs font-medium text-primary">cet appareil</span>}</p>
                    <p className="text-xs text-subtle">Ajouté {relative(d.created_at)}{d.last_used_at ? ` · dernière notification ${relative(d.last_used_at)}` : ""}</p>
                  </div>
                  <button aria-label="Retirer cet appareil" className="rounded-md p-1.5 text-subtle hover:bg-surface-2 hover:text-danger" onClick={async () => {
                    const { error } = await createClient().from("push_subscriptions").delete().eq("id", d.id);
                    if (error) toast.error(error.message); else { if (d.endpoint === here) setHere(null); router.refresh(); }
                  }}><Trash2 className="h-4 w-4" /></button>
                </li>
              ))}
            </ul>
          )}

          <div className="flex flex-wrap items-center gap-3 border-t border-border pt-4">
            <Moon className="h-4 w-4 text-subtle" />
            <span className="text-sm text-fg">Ne pas déranger</span>
            <Switch label="Plage « ne pas déranger »" checked={!!p.quiet_start} onChange={(v) => set(v ? { quiet_start: "21:00", quiet_end: "07:00" } : { quiet_start: null, quiet_end: null })} />
            {p.quiet_start && (
              <span className="flex items-center gap-2 text-sm text-muted">
                de <Input type="time" value={p.quiet_start.slice(0, 5)} onChange={(e) => set({ quiet_start: e.target.value })} className="h-8 w-28" aria-label="Début" />
                à <Input type="time" value={(p.quiet_end ?? "07:00").slice(0, 5)} onChange={(e) => set({ quiet_end: e.target.value })} className="h-8 w-28" aria-label="Fin" />
              </span>
            )}
            <span className="w-full text-xs text-subtle">Aucune notification push pendant cette plage (heure de Porto-Novo). Elles restent visibles dans l&apos;application.</span>
          </div>
        </div>
      </Card>

      {/* E-mails */}
      <Card>
        <CardHeader title="E-mails" icon={<Mail className="h-4 w-4" />} description={`Envoyés à ${email} — seulement pour ce que vous n'avez pas déjà vu dans l'application.`} />
        <div className="space-y-3 p-5">
          {!mailReady && (
            <p className="rounded-lg bg-amber-500/10 px-3 py-2 text-[13px] text-amber-700 dark:text-amber-300">L&apos;envoi d&apos;e-mails n&apos;est pas encore configuré sur le serveur (SMTP). Vos préférences seront appliquées dès sa mise en place.</p>
          )}
          {([
            ["instant", "Au fil de l'eau", "Un e-mail regroupé quelques minutes après une notification restée non lue."],
            ["digest", "Résumé quotidien", "Un seul e-mail par jour avec tout ce que vous n'avez pas lu."],
            ["off", "Jamais", "Uniquement dans l'application et sur vos appareils."],
          ] as [EmailMode, string, string][]).map(([k, label, desc]) => (
            <label key={k} className={cn("flex cursor-pointer items-start gap-3 rounded-xl border p-3 transition", p.email_mode === k ? "border-primary bg-primary/[0.04]" : "border-border hover:bg-surface-2/60")}>
              <input type="radio" name="email_mode" checked={p.email_mode === k} onChange={() => set({ email_mode: k })} className="mt-1 accent-[var(--primary)]" />
              <span className="min-w-0 flex-1">
                <span className="block text-sm font-medium text-fg">{label}</span>
                <span className="block text-xs text-muted">{desc}</span>
                {k === "digest" && p.email_mode === "digest" && (
                  <span className="mt-2 flex items-center gap-2 text-xs text-muted">
                    Envoyé chaque jour à
                    <Select value={String(p.digest_hour)} onChange={(e) => set({ digest_hour: Number(e.target.value) })} className="h-8 w-24" aria-label="Heure du résumé">
                      {Array.from({ length: 24 }, (_, h) => <option key={h} value={h}>{String(h).padStart(2, "0")} h 00</option>)}
                    </Select>
                  </span>
                )}
              </span>
            </label>
          ))}
          {mailReady && (
            <Button size="sm" variant="ghost" loading={busy === "mail"} onClick={async () => {
              setBusy("mail"); const r = await sendTestEmail(); setBusy(null);
              if (r.ok) toast.success(r.message); else toast.error(r.error);
            }}><Send className="h-4 w-4" /> Recevoir un e-mail de test</Button>
          )}
        </div>
      </Card>

      {/* Par catégorie */}
      <Card>
        <CardHeader title="Par type de notification" description="Les notifications restent toujours visibles dans l'application (cloche en haut à droite)." />
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-xs text-subtle">
                <th className="px-5 py-2.5 font-medium">Type</th>
                <th className="w-24 px-3 py-2.5 text-center font-medium">Appareils</th>
                <th className="w-24 px-3 py-2.5 text-center font-medium">E-mail</th>
              </tr>
            </thead>
            <tbody>
              {NOTIFICATION_CATEGORIES.map((c) => (
                <tr key={c.key} className="border-b border-border last:border-0">
                  <td className="px-5 py-3"><p className="font-medium text-fg">{c.label}</p><p className="text-xs text-muted">{c.description}</p></td>
                  <td className="px-3 py-3 text-center"><Switch label={`${c.label} : appareils`} checked={!p.push_off.includes(c.key)} onChange={(v) => toggle("push_off", c.key, v)} /></td>
                  <td className="px-3 py-3 text-center"><Switch label={`${c.label} : e-mail`} checked={!p.email_off.includes(c.key)} disabled={p.email_mode === "off"} onChange={(v) => toggle("email_off", c.key, v)} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <div className={cn("sticky bottom-4 z-10 flex justify-end transition", dirty ? "opacity-100" : "pointer-events-none opacity-0")}>
        <div className="flex items-center gap-3 rounded-xl border border-border bg-surface px-4 py-2.5 shadow-lg">
          <span className="text-sm text-muted">Modifications non enregistrées</span>
          <Button size="sm" variant="ghost" onClick={() => { setP(initial); setDirty(false); }}>Annuler</Button>
          <Button size="sm" loading={pending} onClick={save}>Enregistrer</Button>
        </div>
      </div>
    </div>
  );
}
