import type { MetadataRoute } from "next";

/** Application installable (écran d'accueil du téléphone, fenêtre dédiée sur ordinateur). */
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "VERIION OS",
    short_name: "VERIION",
    description: "Système de gestion et de pilotage interne de VERIION.",
    id: "/",
    start_url: "/",
    scope: "/",
    display: "standalone",
    orientation: "any",
    lang: "fr",
    background_color: "#050816",
    theme_color: "#4f46e5",
    categories: ["business", "productivity"],
    icons: [
      { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png", purpose: "any" },
      { src: "/icons/maskable-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
    shortcuts: [
      { name: "Messages", url: "/messages", icons: [{ src: "/icons/icon-192.png", sizes: "192x192" }] },
      { name: "Mes tâches", url: "/taches", icons: [{ src: "/icons/icon-192.png", sizes: "192x192" }] },
      { name: "Documents", url: "/documents", icons: [{ src: "/icons/icon-192.png", sizes: "192x192" }] },
    ],
  };
}
