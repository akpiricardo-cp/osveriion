// Types des principales entités (miroir du schéma SQL).

export type SystemRole = "ceo" | "admin" | "employee";
export type EmployeeStatus = "active" | "suspended" | "offboarded";
export type UnitKind = "company" | "department" | "subdepartment" | "team";
export type UnitDomain = "direction" | "operations" | "technology" | "marketing" | "business" | "finance" | "hr" | "other";
export type MembershipRole = "head" | "deputy" | "member";
export type ProjectStatus = "planned" | "active" | "on_hold" | "completed" | "cancelled";
export type TaskStatus = "backlog" | "todo" | "in_progress" | "review" | "done";
export type Priority = "low" | "medium" | "high" | "urgent";
export type AccountType = "prospect" | "client" | "partner";
export type OpportunityStage = "lead" | "qualified" | "proposal" | "negotiation" | "won" | "lost";
export type InvoiceStatus = "draft" | "sent" | "paid" | "overdue" | "cancelled";
export type LeaveType = "annual" | "sick" | "maternity" | "paternity" | "unpaid" | "other";
export type RequestStatus = "pending" | "approved" | "rejected" | "cancelled";
export type DocClassification = "internal" | "restricted" | "confidential";
export type DocCategory = "contract" | "procedure" | "presentation" | "policy" | "technical" | "minutes" | "project" | "other";
export type ObjectiveLevel = "company" | "unit" | "individual";
export type ObjectiveStatus = "on_track" | "at_risk" | "off_track" | "done";

export interface Profile {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  full_name: string;
  job_title: string | null;
  phone: string | null;
  avatar_url: string | null;
  bio: string | null;
  location: string | null;
  system_role: SystemRole;
  status: EmployeeStatus;
  primary_unit_id: string | null;
  manager_id: string | null;
  hire_date: string | null;
  birth_date: string | null;
  last_seen_at: string | null;
  created_at: string;
}

export type ProfileLite = Pick<Profile, "id" | "full_name" | "avatar_url" | "job_title" | "email">;

export interface OrgUnit {
  id: string;
  parent_id: string | null;
  name: string;
  code: string | null;
  kind: UnitKind;
  domain: UnitDomain;
  description: string | null;
  color: string;
  sort_order: number;
  path: string[];
  depth: number;
  archived_at: string | null;
}

export interface Membership {
  id: string;
  unit_id: string;
  profile_id: string;
  role: MembershipRole;
  title: string | null;
  start_date: string;
  end_date: string | null;
  profile?: ProfileLite;
}

export interface Project {
  id: string;
  code: string;
  name: string;
  description: string | null;
  unit_id: string | null;
  owner_id: string | null;
  status: ProjectStatus;
  priority: Priority;
  start_date: string | null;
  due_date: string | null;
  budget: number | null;
  color: string;
  created_at: string;
}

export interface Task {
  id: string;
  project_id: string | null;
  parent_id: string | null;
  title: string;
  description: string | null;
  status: TaskStatus;
  priority: Priority;
  assignee_id: string | null;
  reporter_id: string | null;
  start_date: string | null;
  due_date: string | null;
  estimate_hours: number | null;
  position: number;
  requires_validation: boolean;
  validated_by: string | null;
  validated_at: string | null;
  completed_at: string | null;
  objective_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface Account {
  id: string;
  name: string;
  type: AccountType;
  industry: string | null;
  country: string | null;
  city: string | null;
  website: string | null;
  email: string | null;
  phone: string | null;
  owner_id: string | null;
  notes: string | null;
  tags: string[];
  created_at: string;
}

export interface Opportunity {
  id: string;
  account_id: string;
  name: string;
  stage: OpportunityStage;
  amount: number;
  currency: string;
  probability: number;
  expected_close: string | null;
  product: string | null;
  owner_id: string | null;
  project_id: string | null;
  closed_at: string | null;
  position: number;
  created_at: string;
}

export interface Invoice {
  id: string;
  number: string;
  account_id: string | null;
  opportunity_id: string | null;
  unit_id: string | null;
  status: InvoiceStatus;
  issue_date: string;
  due_date: string;
  currency: string;
  subtotal: number;
  tax_rate: number;
  tax_amount: number;
  total: number;
  product: string | null;
  country: string | null;
  notes: string | null;
  paid_at: string | null;
}

export interface Transaction {
  id: string;
  type: "revenue" | "expense";
  amount: number;
  currency: string;
  occurred_on: string;
  category: string;
  description: string | null;
  unit_id: string | null;
  project_id: string | null;
  account_id: string | null;
  invoice_id: string | null;
  product: string | null;
  country: string | null;
  reference: string | null;
}

export interface DocumentRow {
  id: string;
  title: string;
  description: string | null;
  category: DocCategory;
  classification: DocClassification;
  unit_id: string | null;
  project_id: string | null;
  account_id: string | null;
  owner_id: string | null;
  storage_path: string | null;
  file_name: string | null;
  mime_type: string | null;
  size_bytes: number | null;
  version: number;
  tags: string[];
  created_at: string;
  updated_at: string;
}

export interface Notification {
  id: string;
  kind: string;
  title: string;
  body: string | null;
  link: string | null;
  read_at: string | null;
  created_at: string;
}

export interface ChannelSummary {
  id: string;
  kind: "unit" | "project" | "group" | "direct";
  name: string;
  description: string | null;
  unit_id: string | null;
  project_id: string | null;
  is_private: boolean;
  last_message_at: string | null;
  unread: number;
  is_member: boolean;
  other_profile_id: string | null;
  other_name: string | null;
  other_avatar: string | null;
  other_title: string | null;
}

export interface Message {
  id: string;
  channel_id: string;
  author_id: string | null;
  parent_id: string | null;
  body: string;
  kind: "text" | "call" | "system";
  attachments: ChatAttachment[];
  mentions: string[];
  reply_count: number;
  last_reply_at: string | null;
  pinned_at: string | null;
  pinned_by: string | null;
  edited_at: string | null;
  deleted_at: string | null;
  created_at: string;
}

export type ChatAttachment =
  | { type: "file"; path: string; name: string; size: number; mime: string; width?: number; height?: number }
  | { type: "call"; url: string };

export interface MessageReaction {
  message_id: string;
  profile_id: string;
  emoji: string;
}

export interface ObjectiveProgress {
  id: string;
  parent_id: string | null;
  level: ObjectiveLevel;
  unit_id: string | null;
  owner_id: string | null;
  title: string;
  description: string | null;
  period: string;
  status: ObjectiveStatus;
  progress: number;
  key_result_count: number;
}

export interface KeyResult {
  id: string;
  objective_id: string;
  title: string;
  metric_unit: string | null;
  start_value: number;
  target_value: number;
  current_value: number;
  position: number;
}

export interface Meeting {
  id: string;
  title: string;
  description: string | null;
  starts_at: string;
  ends_at: string;
  location: string | null;
  video_url: string | null;
  unit_id: string | null;
  project_id: string | null;
  organizer_id: string | null;
  minutes: string | null;
}

export interface LeaveRequest {
  id: string;
  profile_id: string;
  type: LeaveType;
  start_date: string;
  end_date: string;
  days: number;
  reason: string | null;
  status: RequestStatus;
  approver_id: string | null;
  decided_at: string | null;
  decision_note: string | null;
  created_at: string;
}

export type ActionResult<T = unknown> = { ok: true; data?: T; message?: string } | { ok: false; error: string };
