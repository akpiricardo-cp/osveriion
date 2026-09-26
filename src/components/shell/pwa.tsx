"use client";

import { useEffect } from "react";
import { refreshPushRegistration, registerServiceWorker } from "@/lib/push-client";

/** Enregistre le service worker (application installable, notifications push). */
export function PwaRegistrar() {
  useEffect(() => {
    if (process.env.NODE_ENV !== "production") return;
    registerServiceWorker()?.then(() => refreshPushRegistration()).catch(() => {});
  }, []);
  return null;
}
