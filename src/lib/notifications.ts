/**
 * Catégories de notifications, partagées entre l'interface (préférences) et l'envoi.
 * Doit rester alignée sur la fonction SQL public.notification_category().
 */
export const NOTIFICATION_CATEGORIES = [
  { key: "messages", label: "Messages", description: "Messages directs, mentions @ et réponses dans vos fils" },
  { key: "tasks", label: "Tâches", description: "Tâches attribuées, commentaires, échéances et retards" },
  { key: "approvals", label: "Validations", description: "Tâches à vérifier, décisions du CEO et congés à traiter" },
  { key: "projects", label: "Projets & opérations", description: "Calendriers publiés, rapports de cycle et référents" },
  { key: "legal", label: "Juridique", description: "Contrats à signer et échéances de renouvellement" },
  { key: "meetings", label: "Réunions", description: "Invitations et rappel 15 minutes avant le début" },
  { key: "documents", label: "Documents", description: "Dossiers et documents partagés avec vous" },
  { key: "hr", label: "Ressources humaines", description: "Décisions sur vos congés, départs et arrivées" },
  { key: "announcements", label: "Annonces", description: "Annonces de la direction" },
  { key: "other", label: "Organisation", description: "Nominations et autres informations" },
] as const;

export type NotificationCategory = (typeof NOTIFICATION_CATEGORIES)[number]["key"];

export function categoryOf(kind: string): NotificationCategory {
  if (kind.startsWith("approval.")) return "approvals";
  if (["task.review", "task.submitted", "leave.requested", "reminder.reviews", "reminder.leaves", "reminder.approvals"].includes(kind)) return "approvals";
  if (kind.startsWith("message.")) return "messages";
  if (kind.startsWith("ops.") || kind.startsWith("project.") || kind === "reminder.report") return "projects";
  if (kind.startsWith("legal.") || kind === "reminder.contract") return "legal";
  if (kind.startsWith("task.") || kind === "reminder.due" || kind === "reminder.overdue") return "tasks";
  if (kind.startsWith("drive.")) return "documents";
  if (kind.startsWith("meeting.") || kind === "reminder.meeting") return "meetings";
  if (kind.startsWith("leave.") || kind.startsWith("hr.")) return "hr";
  if (kind === "announcement") return "announcements";
  return "other";
}

export type EmailMode = "instant" | "digest" | "off";

export interface NotificationPreferences {
  email_mode: EmailMode;
  email_off: string[];
  push_off: string[];
  quiet_start: string | null;
  quiet_end: string | null;
  digest_hour: number;
}

export const DEFAULT_PREFERENCES: NotificationPreferences = {
  email_mode: "instant",
  email_off: [],
  push_off: [],
  quiet_start: null,
  quiet_end: null,
  digest_hour: 7,
};
