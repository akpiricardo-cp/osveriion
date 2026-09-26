"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { createClient } from "@/lib/supabase/client";

export type SyncStatus = "saved" | "dirty" | "saving" | "live" | "error" | "conflict" | "readonly";
export type Viewer = { id: string; name: string; avatar: string | null; color: string; session: string; editor: boolean; since: number; focus?: string | null };

export const COLLAB_COLORS = ["#6366f1", "#ec4899", "#10b981", "#f59e0b", "#0ea5e9", "#8b5cf6", "#ef4444", "#14b8a6"];
export const colorFor = (id: string) => COLLAB_COLORS[Math.abs([...id].reduce((a, c) => (a * 31 + c.charCodeAt(0)) | 0, 7)) % COLLAB_COLORS.length];

/**
 * Enregistrement automatique, présence et coordination de la co-édition.
 *
 * Mode classique : verrou optimiste (révision de départ) ; si quelqu'un d'autre enregistre,
 * le document est rechargé, ou un conflit est signalé s'il y a des modifications locales.
 *
 * Mode co-édition (collab) : les modifications sont fusionnées en direct (Yjs pour le texte,
 * cellule par cellule pour le tableur, diapositive par diapositive pour les présentations).
 * Un seul poste — le « meneur », le plus ancien éditeur connecté — enregistre en base ;
 * s'il ferme le document, le suivant prend le relais automatiquement.
 */
export function useDocSync({
  docId, initialRevision, canEdit, me, getContent, onRemote, collab = false, onOp, onSnapshot,
}: {
  docId: string;
  initialRevision: number;
  canEdit: boolean;
  me: { id: string; name: string; avatar: string | null };
  getContent: () => { content: unknown; text: string; ydoc?: string | null };
  onRemote: (content: unknown, revision: number) => void;
  collab?: boolean;
  /** Opération reçue d'un collaborateur (tableur, présentation). */
  onOp?: (op: unknown) => void;
  /** État complet envoyé par le meneur à l'arrivée (rattrape les opérations pas encore enregistrées). */
  onSnapshot?: (content: unknown) => void;
}) {
  const [status, setStatus] = useState<SyncStatus>(canEdit ? "saved" : "readonly");
  const [presence, setPresence] = useState<Viewer[]>([]);
  const [lastSaved, setLastSaved] = useState<Date | null>(null);
  const [remoteEditor, setRemoteEditor] = useState<string | null>(null);
  const [connected, setConnected] = useState(false);
  const session = useMemo(() => Math.random().toString(36).slice(2, 10), []);
  const since = useMemo(() => Date.now(), []);
  const color = useMemo(() => colorFor(me.id), [me.id]);
  const revision = useRef(initialRevision);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const saving = useRef(false);
  const dirty = useRef(false);
  const channelRef = useRef<ReturnType<ReturnType<typeof createClient>["channel"]> | null>(null);
  const getRef = useRef(getContent);
  getRef.current = getContent;
  const remoteRef = useRef(onRemote);
  remoteRef.current = onRemote;
  const focusRef = useRef<string | null>(null);
  const opRef = useRef(onOp);
  opRef.current = onOp;
  const snapRef = useRef(onSnapshot);
  snapRef.current = onSnapshot;

  // Meneur = éditeur connecté le plus ancien (départage par session). Hors ligne : on enregistre soi-même.
  const leaderSession = useMemo(() => {
    const editors = presence.filter((p) => p.editor).concat(canEdit ? [{ session, since } as Viewer] : []);
    editors.sort((a, b) => a.since - b.since || a.session.localeCompare(b.session));
    return editors[0]?.session ?? session;
  }, [presence, canEdit, session, since]);
  const isLeader = !collab || !connected || leaderSession === session;
  const leaderRef = useRef(isLeader);
  leaderRef.current = isLeader;

  const save = useCallback(async (opts?: { snapshot?: boolean; note?: string; force?: boolean }) => {
    if (!canEdit || saving.current) return false;
    if (collab && !leaderRef.current && !opts?.snapshot && !opts?.force) return false;
    if (timer.current) clearTimeout(timer.current);
    saving.current = true;
    setStatus("saving");
    const { content, text, ydoc } = getRef.current();
    const { data, error } = await createClient().rpc("save_document_content", {
      p_doc: docId, p_content: content, p_text: text,
      p_base_revision: opts?.force ? null : revision.current,
      p_snapshot: !!opts?.snapshot, p_note: opts?.note ?? null, p_ydoc: ydoc ?? null,
    });
    saving.current = false;
    if (!error) {
      revision.current = data as number;
      dirty.current = false;
      setStatus("saved");
      setLastSaved(new Date());
      setRemoteEditor(null);
      channelRef.current?.send({ type: "broadcast", event: "saved", payload: { revision: revision.current, by: me.name, id: me.id, session, at: Date.now() } });
      return true;
    }
    setStatus(error.code === "40001" ? "conflict" : "error");
    return false;
  }, [canEdit, collab, docId, me.id, me.name, session]);

  const schedule = useCallback(() => {
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => { if (dirty.current) save(); }, 1400);
  }, [save]);

  const markDirty = useCallback(() => {
    if (!canEdit) return;
    dirty.current = true;
    if (collab && !leaderRef.current) { setStatus((s) => (s === "conflict" ? s : "live")); return; }
    setStatus((s) => (s === "conflict" ? s : "dirty"));
    schedule();
  }, [canEdit, collab, schedule]);

  // Devenu meneur avec des modifications non enregistrées : on enregistre
  useEffect(() => {
    if (collab && isLeader && dirty.current && canEdit) { setStatus("dirty"); schedule(); }
  }, [collab, isLeader, canEdit, schedule]);

  const reload = useCallback(async () => {
    if (collab) { window.location.reload(); return; }
    const { data } = await createClient().from("documents").select("content, revision").eq("id", docId).single();
    if (data) {
      revision.current = data.revision;
      dirty.current = false;
      remoteRef.current(data.content, data.revision);
      setStatus(canEdit ? "saved" : "readonly");
      setRemoteEditor(null);
    }
  }, [docId, canEdit, collab]);

  /** Après une restauration de version : tout le monde recharge le document. */
  const announceReset = useCallback(() => {
    channelRef.current?.send({ type: "broadcast", event: "reset", payload: { by: me.name } });
  }, [me.name]);

  /** Diffuse une opération locale aux collaborateurs. */
  const sendOp = useCallback((op: unknown) => {
    channelRef.current?.send({ type: "broadcast", event: "op", payload: { session, op } });
  }, [session]);

  /** Partage la position (cellule, diapositive) affichée chez les autres. */
  const setFocus = useCallback((focus: string | null) => {
    if (focusRef.current === focus) return;
    focusRef.current = focus;
    channelRef.current?.track({ id: me.id, name: me.name, avatar: me.avatar, color, session, editor: canEdit, since, focus });
  }, [me.id, me.name, me.avatar, color, session, canEdit, since]);

  useEffect(() => {
    const supabase = createClient();
    const ch = supabase.channel(`doc-${docId}`, { config: { presence: { key: `${me.id}:${session}` } } });
    channelRef.current = ch;
    ch.on("presence", { event: "sync" }, () => {
      const state = ch.presenceState<Viewer>();
      setPresence(Object.values(state).map((v) => v[0]).filter((v) => v && v.session !== session));
    })
      .on("broadcast", { event: "saved" }, ({ payload }) => {
        if (payload.session === session || payload.revision <= revision.current) return;
        if (collab) {
          // Le meneur a enregistré l'état fusionné, qui contient nos modifications déjà diffusées
          revision.current = payload.revision;
          dirty.current = false;
          setLastSaved(new Date());
          setStatus(canEdit ? "saved" : "readonly");
          return;
        }
        if (dirty.current) {
          setRemoteEditor(payload.by);
          setStatus("conflict");
        } else {
          reload();
        }
      })
      .on("broadcast", { event: "reset" }, () => window.location.reload())
      .on("broadcast", { event: "op" }, ({ payload }) => {
        if (payload.session === session) return;
        opRef.current?.(payload.op);
        if (canEdit) {
          dirty.current = true;
          if (leaderRef.current) { setStatus((st) => (st === "conflict" ? st : "dirty")); schedule(); }
          else setStatus((st) => (st === "conflict" ? st : "live"));
        }
      })
      .on("broadcast", { event: "state-req" }, ({ payload }) => {
        if (!collab || !snapRef.current || payload.session === session || !leaderRef.current) return;
        ch.send({ type: "broadcast", event: "state", payload: { to: payload.session, content: getRef.current().content, revision: revision.current } });
      })
      .on("broadcast", { event: "state" }, ({ payload }) => {
        if (payload.to !== session || dirty.current) return;
        snapRef.current?.(payload.content);
      })
      .subscribe((s) => {
        if (s === "SUBSCRIBED") {
          setConnected(true);
          ch.track({ id: me.id, name: me.name, avatar: me.avatar, color, session, editor: canEdit, since, focus: focusRef.current });
          if (collab && snapRef.current) ch.send({ type: "broadcast", event: "state-req", payload: { session } });
        } else if (s === "CLOSED" || s === "CHANNEL_ERROR" || s === "TIMED_OUT") setConnected(false);
      });
    return () => { supabase.removeChannel(ch); channelRef.current = null; };
  }, [docId, me.id, me.name, me.avatar, reload, session, color, canEdit, since, collab, schedule]);

  useEffect(() => {
    const onUnload = (e: BeforeUnloadEvent) => { if (dirty.current && leaderRef.current) { e.preventDefault(); e.returnValue = ""; } };
    const onHide = () => { if (document.visibilityState === "hidden" && dirty.current && leaderRef.current) save(); };
    window.addEventListener("beforeunload", onUnload);
    document.addEventListener("visibilitychange", onHide);
    return () => { window.removeEventListener("beforeunload", onUnload); document.removeEventListener("visibilitychange", onHide); };
  }, [save]);

  useEffect(() => () => { if (timer.current) clearTimeout(timer.current); }, []);

  // Une personne ouverte dans plusieurs onglets n'apparaît qu'une fois
  const viewers = useMemo(() => {
    const seen = new Set<string>();
    return presence.filter((p) => p.id !== me.id && !seen.has(p.id) && seen.add(p.id));
  }, [presence, me.id]);

  return { status, viewers, presence, lastSaved, remoteEditor, markDirty, save, reload, revision, announceReset, setFocus, sendOp, isLeader, connected, color, session };
}
