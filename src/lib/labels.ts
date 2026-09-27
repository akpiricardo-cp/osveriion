import type {
  AccountType, ApprovalKind, ApprovalStatus, CycleKind, CycleStatus, DocCategory, DocClassification, InvoiceStatus,
  LeaveType, LegalContractStatus, LegalContractType, MembershipRole, ObjectiveStatus, OpportunityStage, OpsItemStatus,
  Priority, ProjectStatus, RequestStatus, SystemRole, TaskStatus, UnitDomain, UnitKind,
} from "./types";

export type Tone = "neutral" | "blue" | "green" | "amber" | "red" | "violet" | "cyan" | "pink";
type Labeled<K extends string> = Record<K, { label: string; tone: Tone }>;

export const taskStatus: Labeled<TaskStatus> = {
  backlog: { label: "Backlog", tone: "neutral" },
  todo: { label: "À faire", tone: "blue" },
  in_progress: { label: "En cours", tone: "violet" },
  review: { label: "En revue", tone: "amber" },
  done: { label: "Terminé", tone: "green" },
};
export const TASK_COLUMNS: TaskStatus[] = ["backlog", "todo", "in_progress", "review", "done"];

export const priority: Labeled<Priority> = {
  low: { label: "Basse", tone: "neutral" },
  medium: { label: "Moyenne", tone: "blue" },
  high: { label: "Haute", tone: "amber" },
  urgent: { label: "Urgente", tone: "red" },
};

export const projectStatus: Labeled<ProjectStatus> = {
  planned: { label: "Planifié", tone: "neutral" },
  active: { label: "Actif", tone: "green" },
  on_hold: { label: "En pause", tone: "amber" },
  completed: { label: "Terminé", tone: "blue" },
  cancelled: { label: "Annulé", tone: "red" },
};

export const accountType: Labeled<AccountType> = {
  prospect: { label: "Prospect", tone: "amber" },
  client: { label: "Client", tone: "green" },
  partner: { label: "Partenaire", tone: "violet" },
};

export const stage: Labeled<OpportunityStage> = {
  lead: { label: "Piste", tone: "neutral" },
  qualified: { label: "Qualifiée", tone: "blue" },
  proposal: { label: "Proposition", tone: "violet" },
  negotiation: { label: "Négociation", tone: "amber" },
  won: { label: "Gagnée", tone: "green" },
  lost: { label: "Perdue", tone: "red" },
};
export const STAGES: OpportunityStage[] = ["lead", "qualified", "proposal", "negotiation", "won", "lost"];

export const invoiceStatus: Labeled<InvoiceStatus> = {
  draft: { label: "Brouillon", tone: "neutral" },
  sent: { label: "Envoyée", tone: "blue" },
  paid: { label: "Payée", tone: "green" },
  overdue: { label: "En retard", tone: "red" },
  cancelled: { label: "Annulée", tone: "neutral" },
};

export const leaveType: Record<LeaveType, string> = {
  annual: "Congés payés",
  sick: "Maladie",
  maternity: "Maternité",
  paternity: "Paternité",
  unpaid: "Sans solde",
  other: "Autre",
};

export const requestStatus: Labeled<RequestStatus> = {
  pending: { label: "En attente", tone: "amber" },
  approved: { label: "Approuvé", tone: "green" },
  rejected: { label: "Refusé", tone: "red" },
  cancelled: { label: "Annulé", tone: "neutral" },
};

export const classification: Labeled<DocClassification> = {
  internal: { label: "Interne", tone: "green" },
  restricted: { label: "Restreint", tone: "amber" },
  confidential: { label: "Confidentiel", tone: "red" },
};

export const docCategory: Record<DocCategory, string> = {
  contract: "Contrat",
  procedure: "Procédure",
  presentation: "Présentation",
  policy: "Politique interne",
  technical: "Documentation technique",
  minutes: "Compte rendu",
  project: "Fichier de projet",
  other: "Autre",
};

export const objectiveStatus: Labeled<ObjectiveStatus> = {
  on_track: { label: "En bonne voie", tone: "green" },
  at_risk: { label: "À risque", tone: "amber" },
  off_track: { label: "En retard", tone: "red" },
  done: { label: "Atteint", tone: "blue" },
};

export const unitKind: Record<UnitKind, string> = {
  company: "Entreprise",
  department: "Département",
  subdepartment: "Sous-département",
  team: "Équipe",
};

export const unitDomain: Record<UnitDomain, string> = {
  direction: "Direction",
  operations: "Opérations",
  technology: "Technologie",
  product: "Produit",
  marketing: "Marketing",
  business: "Business",
  finance: "Finance",
  legal: "Juridique",
  hr: "Ressources humaines",
  other: "Autre",
};

export const membershipRole: Record<MembershipRole, string> = {
  head: "Responsable",
  deputy: "Adjoint(e)",
  member: "Membre",
};

export const systemRole: Record<SystemRole, string> = {
  ceo: "CEO",
  admin: "Administrateur",
  employee: "Employé",
};

export const contractType: Record<string, string> = {
  cdi: "CDI",
  cdd: "CDD",
  internship: "Stage",
  freelance: "Freelance",
  consultant: "Consultant",
};

export const severity: Labeled<"low" | "medium" | "high" | "critical"> = {
  low: { label: "Faible", tone: "neutral" },
  medium: { label: "Moyenne", tone: "amber" },
  high: { label: "Élevée", tone: "red" },
  critical: { label: "Critique", tone: "red" },
};

export const COUNTRIES: Record<string, string> = {
  BJ: "Bénin", CI: "Côte d'Ivoire", SN: "Sénégal", TG: "Togo", NG: "Nigeria", GH: "Ghana", BF: "Burkina Faso",
  ML: "Mali", NE: "Niger", CM: "Cameroun", GA: "Gabon", CD: "RD Congo", CG: "Congo", KE: "Kenya", RW: "Rwanda",
  MA: "Maroc", TN: "Tunisie", ZA: "Afrique du Sud", FR: "France", US: "États-Unis",
};

export const PRODUCTS = ["Oniix", "iSkul", "Wiix", "Eduoo"];

export const EXPENSE_CATEGORIES = [
  "Salaires", "Infrastructure cloud", "Logiciels", "Marketing digital", "Locaux", "Déplacements",
  "Matériel", "Prestataires", "Formation", "Frais bancaires", "Taxes", "Autre",
];
export const REVENUE_CATEGORIES = ["Ventes", "Abonnements", "Services", "Subventions", "Partenariats", "Autre"];

// ── Holding : validations, calendrier opérationnel, juridique ──────────────

export const approvalKind: Record<ApprovalKind, string> = {
  budget: "Budget",
  expense: "Dépense",
  legal_contract: "Contrat",
  operation_cycle: "Calendrier opérationnel",
  project: "Lancement de projet",
  employment_contract: "Contrat de travail",
  other: "Autre décision",
};

export const approvalStatus: Labeled<ApprovalStatus> = {
  pending: { label: "En attente du CEO", tone: "amber" },
  approved: { label: "Approuvée", tone: "green" },
  rejected: { label: "Refusée", tone: "red" },
  cancelled: { label: "Annulée", tone: "neutral" },
};

export const cycleKind: Record<CycleKind, string> = {
  monthly: "Mensuel",
  weekly: "Hebdomadaire",
  daily: "Journalier",
};

export const cycleStatus: Labeled<CycleStatus> = {
  draft: { label: "Brouillon", tone: "neutral" },
  pending_ceo: { label: "Chez le CEO", tone: "amber" },
  published: { label: "Publié", tone: "green" },
  closed: { label: "Clôturé", tone: "blue" },
};

export const opsItemStatus: Labeled<OpsItemStatus> = {
  planned: { label: "Prévu", tone: "neutral" },
  in_progress: { label: "En cours", tone: "violet" },
  done: { label: "Atteint", tone: "green" },
  dropped: { label: "Abandonné", tone: "red" },
};

export const legalContractType: Record<LegalContractType, string> = {
  nda: "Accord de confidentialité",
  partnership: "Partenariat",
  client: "Client",
  supplier: "Fournisseur",
  licence: "Licence",
  employment: "Contrat de travail",
  statutory: "Acte statutaire",
  other: "Autre",
};

export const legalContractStatus: Labeled<LegalContractStatus> = {
  draft: { label: "Brouillon", tone: "neutral" },
  legal_review: { label: "Revue juridique", tone: "blue" },
  pending_ceo: { label: "Chez le CEO", tone: "amber" },
  signed: { label: "Signé", tone: "green" },
  active: { label: "En vigueur", tone: "green" },
  expired: { label: "Échu", tone: "red" },
  terminated: { label: "Résilié", tone: "neutral" },
};

export const contractRisk: Labeled<"low" | "medium" | "high"> = {
  low: { label: "Risque faible", tone: "green" },
  medium: { label: "Risque moyen", tone: "amber" },
  high: { label: "Risque élevé", tone: "red" },
};
