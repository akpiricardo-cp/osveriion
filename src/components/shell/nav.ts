import {
  BarChart3, Briefcase, Building2, CalendarDays, CheckSquare, FileText, FolderKanban, Gavel, Handshake, Home,
  MessagesSquare, Settings, Shield, Stamp, Target, Users, Wallet, CalendarRange, type LucideIcon,
} from "lucide-react";

export type NavKey = "direction" | "crm" | "finance" | "admin" | "operations" | "legal" | "approvals";
export interface NavItem { href: string; label: string; icon: LucideIcon; requires?: NavKey; badge?: "messages" }

export const NAV: { title: string; items: NavItem[] }[] = [
  {
    title: "Général",
    items: [
      { href: "/", label: "Accueil", icon: Home },
      { href: "/direction", label: "Direction", icon: BarChart3, requires: "direction" },
      { href: "/messages", label: "Messages", icon: MessagesSquare, badge: "messages" },
      { href: "/reunions", label: "Réunions", icon: CalendarDays },
    ],
  },
  {
    title: "Produits",
    items: [
      { href: "/projets", label: "Projets", icon: FolderKanban },
      { href: "/operations", label: "Opérations", icon: CalendarRange, requires: "operations" },
      { href: "/taches", label: "Mes tâches", icon: CheckSquare },
      { href: "/objectifs", label: "Objectifs & KPI", icon: Target },
      { href: "/documents", label: "Documents", icon: FileText },
    ],
  },
  {
    title: "Holding",
    items: [
      { href: "/organisation", label: "Organisation", icon: Building2 },
      { href: "/annuaire", label: "Annuaire", icon: Users },
      { href: "/validations", label: "Validations", icon: Stamp, requires: "approvals" },
      { href: "/juridique", label: "Juridique", icon: Gavel, requires: "legal" },
      { href: "/crm", label: "CRM & partenariats", icon: Handshake, requires: "crm" },
      { href: "/finance", label: "Finance", icon: Wallet, requires: "finance" },
      { href: "/rh", label: "Ressources humaines", icon: Briefcase },
    ],
  },
  {
    title: "Système",
    items: [
      { href: "/admin", label: "Administration", icon: Shield, requires: "admin" },
      { href: "/parametres", label: "Paramètres", icon: Settings },
    ],
  },
];
