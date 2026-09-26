import * as Y from "yjs";
import * as awarenessProtocol from "y-protocols/awareness";
import { fromBase64, toBase64 } from "lib0/buffer";
import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

/**
 * Fournisseur Yjs sur Supabase Realtime (canal « broadcast ») :
 * - diffuse chaque modification locale aux autres personnes ouvertes sur le document ;
 * - à l'arrivée, échange les vecteurs d'état pour récupérer ce qui manque (dans les deux sens) ;
 * - partage la « conscience » (curseur, sélection, nom, couleur) pour afficher les curseurs.
 * La persistance reste assurée par l'application (colonne documents.ydoc).
 */
export class SupabaseYjsProvider {
  readonly doc: Y.Doc;
  readonly awareness: awarenessProtocol.Awareness;
  readonly channel: RealtimeChannel;
  connected = false;
  private pending: Uint8Array[] = [];
  private flushTimer: ReturnType<typeof setTimeout> | null = null;
  private readonly peer = Math.random().toString(36).slice(2, 10);
  private listeners = new Set<(connected: boolean) => void>();

  constructor(private supabase: SupabaseClient, docId: string, doc: Y.Doc, readonly readOnly = false) {
    this.doc = doc;
    this.awareness = new awarenessProtocol.Awareness(doc);
    this.channel = supabase.channel(`ydoc-${docId}`, { config: { broadcast: { self: false }, presence: { key: `${doc.clientID}` } } });

    this.channel
      .on("broadcast", { event: "y-update" }, ({ payload }) => {
        Y.applyUpdate(this.doc, fromBase64(payload.u), this);
      })
      .on("broadcast", { event: "y-sync1" }, ({ payload }) => {
        // Un pair arrive : on lui envoie ce qui lui manque, avec notre vecteur d'état pour qu'il fasse de même
        const diff = Y.encodeStateAsUpdate(this.doc, fromBase64(payload.sv));
        this.send("y-sync2", { to: payload.from, u: toBase64(diff), sv: toBase64(Y.encodeStateVector(this.doc)), from: this.peer });
        this.broadcastAwareness([this.doc.clientID]);
      })
      .on("broadcast", { event: "y-sync2" }, ({ payload }) => {
        if (payload.to !== this.peer) return;
        Y.applyUpdate(this.doc, fromBase64(payload.u), this);
        if (payload.sv && !this.readOnly) {
          const back = Y.encodeStateAsUpdate(this.doc, fromBase64(payload.sv));
          if (back.length > 2) this.send("y-update", { u: toBase64(back) });
        }
      })
      .on("broadcast", { event: "y-aw" }, ({ payload }) => {
        awarenessProtocol.applyAwarenessUpdate(this.awareness, fromBase64(payload.u), this);
      })
      .on("presence", { event: "leave" }, ({ key }) => {
        const id = Number(key);
        if (Number.isFinite(id) && id !== this.doc.clientID) awarenessProtocol.removeAwarenessStates(this.awareness, [id], this);
      })
      .subscribe((status) => {
        if (status === "SUBSCRIBED") {
          this.connected = true;
          this.channel.track({ at: Date.now() });
          this.send("y-sync1", { sv: toBase64(Y.encodeStateVector(this.doc)), from: this.peer });
          this.broadcastAwareness([this.doc.clientID]);
          this.flush();
        } else if (status === "CLOSED" || status === "CHANNEL_ERROR" || status === "TIMED_OUT") {
          this.connected = false;
        }
        this.listeners.forEach((l) => l(this.connected));
      });

    doc.on("update", this.onDocUpdate);
    this.awareness.on("update", this.onAwarenessUpdate);
    if (typeof window !== "undefined") window.addEventListener("beforeunload", this.onUnload);
  }

  onStatus(cb: (connected: boolean) => void) {
    this.listeners.add(cb);
    return () => this.listeners.delete(cb);
  }

  private send(event: string, payload: Record<string, unknown>) {
    if (!this.connected) return;
    this.channel.send({ type: "broadcast", event, payload });
  }

  // Les frappes rapprochées sont regroupées (≈ 40 ms) pour limiter le nombre de messages.
  private onDocUpdate = (update: Uint8Array, origin: unknown) => {
    if (origin === this || this.readOnly) return;
    this.pending.push(update);
    if (!this.flushTimer) this.flushTimer = setTimeout(() => this.flush(), 40);
  };

  private flush() {
    if (this.flushTimer) { clearTimeout(this.flushTimer); this.flushTimer = null; }
    if (!this.pending.length || !this.connected) return;
    const merged = this.pending.length === 1 ? this.pending[0] : Y.mergeUpdates(this.pending);
    this.pending = [];
    this.send("y-update", { u: toBase64(merged) });
  }

  private onAwarenessUpdate = ({ added, updated, removed }: { added: number[]; updated: number[]; removed: number[] }, origin: unknown) => {
    if (origin === this) return;
    this.broadcastAwareness([...added, ...updated, ...removed]);
  };

  private broadcastAwareness(clients: number[]) {
    if (!clients.length) return;
    this.send("y-aw", { u: toBase64(awarenessProtocol.encodeAwarenessUpdate(this.awareness, clients)) });
  }

  private onUnload = () => {
    awarenessProtocol.removeAwarenessStates(this.awareness, [this.doc.clientID], "unload");
  };

  destroy() {
    this.flush();
    awarenessProtocol.removeAwarenessStates(this.awareness, [this.doc.clientID], "destroy");
    this.doc.off("update", this.onDocUpdate);
    this.awareness.off("update", this.onAwarenessUpdate);
    this.awareness.destroy();
    if (typeof window !== "undefined") window.removeEventListener("beforeunload", this.onUnload);
    this.supabase.removeChannel(this.channel);
    this.listeners.clear();
  }
}

export const encodeDoc = (doc: Y.Doc) => toBase64(Y.encodeStateAsUpdate(doc));
export const applyEncoded = (doc: Y.Doc, b64: string, origin?: unknown) => Y.applyUpdate(doc, fromBase64(b64), origin);
