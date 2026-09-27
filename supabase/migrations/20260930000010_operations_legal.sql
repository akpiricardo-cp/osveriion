-- =============================================================================
-- VERIION OS — Migration 10 : opérations, juridique, validations et tâches
-- =============================================================================
-- Comment le travail descend et remonte dans la holding :
--
--   1. Les Opérations écrivent le calendrier d'un projet (mensuel, hebdomadaire,
--      journalier) sous forme de grandes lignes.
--   2. Le calendrier mensuel est soumis au CEO, puis publié au chef de projet.
--   3. Le chef de projet découpe chaque grande ligne en tâches et les répartit
--      dans son équipe — lui compris. Personne n'assigne vers le haut ni en
--      dehors de son périmètre.
--   4. Chaque membre soumet sa tâche terminée à vérification ; celui qui l'a
--      assignée valide ou renvoie avec un motif.
--   5. Le chef de projet rend compte aux Opérations pour chaque cycle.
--
-- En parallèle : le registre juridique (contrats, échéances, renouvellements) et
-- le guichet unique des validations du CEO (budgets et dépenses au-delà d'un
-- seuil, contrats, calendriers mensuels, lancement de projet et embauches).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Validations : le guichet unique des décisions du CEO
-- -----------------------------------------------------------------------------
do $enum$ begin
  create type public.approval_kind as enum ('budget', 'expense', 'legal_contract', 'operation_cycle', 'project', 'employment_contract', 'other');
exception when duplicate_object then null;
end $enum$;
do $enum$ begin
  create type public.approval_status as enum ('pending', 'approved', 'rejected', 'cancelled');
exception when duplicate_object then null;
end $enum$;

-- Seuil au-delà duquel une dépense ou un budget remonte au CEO.
alter table public.company_settings
  add column if not exists ceo_approval_threshold numeric(16,2) not null default 500000;

create table if not exists public.approval_requests (
  id             uuid primary key default gen_random_uuid(),
  kind           public.approval_kind not null,
  subject_id     uuid,                       -- la ligne concernée (budget, contrat, cycle…)
  subject_label  text not null,
  amount         numeric(16,2),
  currency       text not null default 'XOF',
  justification  text,
  unit_id        uuid references public.org_units(id) on delete set null,
  project_id     uuid references public.projects(id)  on delete set null,
  status         public.approval_status not null default 'pending',
  requested_by   uuid references public.profiles(id) on delete set null default auth.uid(),
  decided_by     uuid references public.profiles(id) on delete set null,
  decided_at     timestamptz,
  decision_note  text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
-- Une seule demande en attente par sujet : pas de double file.
create unique index if not exists approval_requests_pending_subject on public.approval_requests(kind, subject_id)
  where status = 'pending' and subject_id is not null;
create index if not exists approval_requests_queue_idx on public.approval_requests(status, created_at desc);
create index if not exists approval_requests_author_idx on public.approval_requests(requested_by, created_at desc);
drop trigger if exists approval_requests_updated_at on public.approval_requests;
create trigger approval_requests_updated_at before update on public.approval_requests
  for each row execute function public.set_updated_at();
drop trigger if exists audit_approval_requests on public.approval_requests;
create trigger audit_approval_requests after insert or update or delete on public.approval_requests
  for each row execute function public.audit_trigger();

insert into public.permissions (key, label, description, category, scopable) values
  ('approvals.decide', 'Valider les décisions', 'Approuver budgets, dépenses, contrats, calendriers et lancements de projet', 'Direction', false),
  ('ops.plan',         'Planifier les opérations', 'Écrire et publier le calendrier opérationnel des projets',                 'Opérations', false),
  ('ops.review',       'Suivre les rapports',      'Lire les rapports des chefs de projet et en accuser réception',           'Opérations', false),
  ('legal.view',       'Consulter le juridique',   'Lecture du registre des contrats et de leurs échéances',                  'Juridique',  false),
  ('legal.admin',      'Administrer le juridique', 'Rédiger, réviser, signer et clôturer les contrats',                       'Juridique',  false)
on conflict (key) do nothing;

insert into public.role_templates (domain, membership_role, permission, scoped) values
  ('operations', 'head',   'ops.plan',   false),
  ('operations', 'deputy', 'ops.plan',   false),
  ('operations', 'member', 'ops.review', false),
  ('operations', 'head',   'ops.review', false),
  ('legal',      'head',   'legal.admin', false),
  ('legal',      'deputy', 'legal.admin', false),
  ('legal',      'member', 'legal.view',  false),
  ('finance',    'head',   'legal.view',  false)
on conflict do nothing;

-- Le CEO décide ; il peut déléguer par une dérogation « approvals.decide ».
create or replace function public.can_decide_approvals()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_ceo() or public.has_perm('approvals.decide')
$$;
grant execute on function public.can_decide_approvals() to authenticated;

create or replace function public.ceo_approval_threshold()
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce((select ceo_approval_threshold from public.company_settings where id), 500000)
$$;
grant execute on function public.ceo_approval_threshold() to authenticated;

/** Une décision approuvée existe-t-elle pour ce sujet ? */
create or replace function public.approval_granted(p_kind public.approval_kind, p_subject uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.approval_requests
    where kind = p_kind and subject_id = p_subject and status = 'approved'
  )
$$;
grant execute on function public.approval_granted(public.approval_kind, uuid) to authenticated;

/** Soumet une décision au CEO. Renvoie la demande déjà en attente s'il y en a une. */
create or replace function public.request_approval(
  p_kind public.approval_kind, p_subject uuid, p_label text,
  p_amount numeric default null, p_justification text default null,
  p_unit uuid default null, p_project uuid default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; r record;
begin
  if not public.is_active_user() then raise exception 'Compte inactif' using errcode = '42501'; end if;
  if length(trim(coalesce(p_label, ''))) < 3 then raise exception 'Précisez l''objet de la demande'; end if;

  select id into v_id from public.approval_requests
   where kind = p_kind and subject_id = p_subject and status = 'pending' and p_subject is not null;
  if v_id is not null then return v_id; end if;

  insert into public.approval_requests (kind, subject_id, subject_label, amount, justification, unit_id, project_id)
  values (p_kind, p_subject, trim(p_label), p_amount, nullif(trim(coalesce(p_justification, '')), ''), p_unit, p_project)
  returning id into v_id;

  for r in
    select p.id from public.profiles p where p.status = 'active' and p.system_role = 'ceo'
    union
    select g.profile_id from public.role_grants g
     where g.permission = 'approvals.decide' and (g.expires_at is null or g.expires_at > now())
  loop
    perform public.notify(r.id, 'approval.requested', 'Décision attendue : ' || trim(p_label),
      case when p_amount is not null then to_char(p_amount, 'FM999G999G999D00') || ' XOF' else null end,
      '/validations?demande=' || v_id);
  end loop;
  return v_id;
end $$;
grant execute on function public.request_approval(public.approval_kind, uuid, text, numeric, text, uuid, uuid) to authenticated;

/** Accord ou refus du CEO, toujours motivé côté refus. */
create or replace function public.decide_approval(p_id uuid, p_approve boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare a public.approval_requests;
begin
  if not public.can_decide_approvals() then
    raise exception 'Cette décision revient au CEO' using errcode = '42501';
  end if;
  select * into a from public.approval_requests where id = p_id for update;
  if a.id is null then raise exception 'Demande introuvable'; end if;
  if a.status <> 'pending' then raise exception 'Cette demande a déjà été traitée'; end if;
  if not p_approve and length(trim(coalesce(p_note, ''))) < 3 then
    raise exception 'Motivez le refus : la personne doit savoir quoi corriger';
  end if;

  update public.approval_requests
     set status = case when p_approve then 'approved' else 'rejected' end::public.approval_status,
         decided_by = auth.uid(), decided_at = now(), decision_note = nullif(trim(coalesce(p_note, '')), '')
   where id = p_id;

  perform public.notify(a.requested_by,
    case when p_approve then 'approval.approved' else 'approval.rejected' end,
    case when p_approve then 'Accord du CEO : ' else 'Refus : ' end || a.subject_label,
    nullif(trim(coalesce(p_note, '')), ''), '/validations?demande=' || a.id);
end $$;
grant execute on function public.decide_approval(uuid, boolean, text) to authenticated;

/** Annule sa propre demande tant qu'elle n'est pas tranchée. */
create or replace function public.cancel_approval(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.approval_requests set status = 'cancelled'
   where id = p_id and status = 'pending' and (requested_by = auth.uid() or public.can_decide_approvals());
  if not found then raise exception 'Demande introuvable ou déjà tranchée'; end if;
end $$;
grant execute on function public.cancel_approval(uuid) to authenticated;

alter table public.approval_requests enable row level security;
grant select, insert, update on public.approval_requests to authenticated;
drop policy if exists "validations: lecture" on public.approval_requests;
create policy "validations: lecture" on public.approval_requests for select to authenticated
  using (public.is_active_user() and (
    requested_by = auth.uid() or public.can_decide_approvals()
    or public.has_perm('dashboard.exec')
    or (unit_id is not null and public.has_perm('unit.manage', unit_id))
    or (project_id is not null and public.can_view_project(project_id))));
-- Écriture par les fonctions ci-dessus uniquement.

-- -----------------------------------------------------------------------------
-- 2. Budgets et dépenses : le seuil déclenche l'accord du CEO
-- -----------------------------------------------------------------------------
do $budgets$
declare v_first_run boolean := not exists (
  select 1 from information_schema.columns
   where table_schema = 'public' and table_name = 'budgets' and column_name = 'status');
begin
  alter table public.budgets
    add column if not exists status text not null default 'draft' check (status in ('draft', 'active')),
    add column if not exists project_id uuid references public.projects(id) on delete cascade;
  alter table public.budgets alter column unit_id drop not null;
  alter table public.budgets drop constraint if exists budgets_scope_chk;
  alter table public.budgets add constraint budgets_scope_chk check (unit_id is not null or project_id is not null);
  -- Les budgets déjà en place existaient avant le circuit de validation : ils restent actifs.
  if v_first_run then update public.budgets set status = 'active'; end if;
end $budgets$;
comment on column public.budgets.project_id is 'Budget d''un projet de la holding (sinon budget d''unité).';
-- Un seul budget par projet et par exercice, comme pour les unités.
create unique index if not exists budgets_project_year on public.budgets(project_id, fiscal_year) where project_id is not null;

-- Le chef de projet voit le budget de son projet ; sa gestion reste à la finance.
drop policy if exists "budgets: lecture" on public.budgets;
drop policy if exists "budgets: lecture" on public.budgets;
create policy "budgets: lecture" on public.budgets for select to authenticated
  using (public.can_read_finance() or public.has_perm('unit.manage', unit_id)
         or (project_id is not null and public.can_view_project(project_id)));

create or replace function public.budgets_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null
     and new.status = 'active'
     and new.amount > public.ceo_approval_threshold()
     and not public.approval_granted('budget', new.id)
     and not public.is_ceo() then
    raise exception 'Ce budget dépasse le seuil : l''accord du CEO est requis avant activation.' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists budgets_guard_biu on public.budgets;
create trigger budgets_guard_biu before insert or update on public.budgets
  for each row execute function public.budgets_guard();

alter table public.transactions
  add column if not exists approval_id uuid references public.approval_requests(id) on delete set null;

create or replace function public.transactions_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and new.type = 'expense'
     and new.amount > public.ceo_approval_threshold() and not public.is_ceo() then
    if not exists (
      select 1 from public.approval_requests a
      where a.id = new.approval_id and a.kind = 'expense' and a.status = 'approved'
        and coalesce(a.amount, 0) >= new.amount
    ) then
      raise exception 'Dépense au-dessus du seuil : rattachez-la à un accord du CEO portant au moins ce montant.' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists transactions_guard_biu on public.transactions;
create trigger transactions_guard_biu before insert or update on public.transactions
  for each row execute function public.transactions_guard();

-- -----------------------------------------------------------------------------
-- 3. Lancement d'un projet et embauches : accord du CEO
-- -----------------------------------------------------------------------------
alter table public.projects
  add column if not exists approved_by uuid references public.profiles(id) on delete set null,
  add column if not exists approved_at timestamptz;
update public.projects set approved_at = created_at where status <> 'planned' and approved_at is null;

create or replace function public.projects_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'active' and (tg_op = 'INSERT' or old.status <> 'active') then
    if auth.uid() is not null and not public.is_ceo() and not public.approval_granted('project', new.id) then
      raise exception 'Le lancement d''un projet demande l''accord du CEO. Soumettez-le depuis la fiche du projet.' using errcode = '42501';
    end if;
    new.approved_at := coalesce(new.approved_at, now());
    new.approved_by := coalesce(new.approved_by, auth.uid());
  end if;
  return new;
end $$;
drop trigger if exists projects_guard_biu on public.projects;
create trigger projects_guard_biu before insert or update on public.projects
  for each row execute function public.projects_guard();

alter table public.employment_contracts
  add column if not exists status text not null default 'draft' check (status in ('draft', 'pending_ceo', 'signed', 'ended')),
  add column if not exists approved_by uuid references public.profiles(id) on delete set null,
  add column if not exists approved_at timestamptz;
update public.employment_contracts set status = 'signed', approved_at = created_at where approved_at is null;

create or replace function public.employment_contracts_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'signed' and (tg_op = 'INSERT' or old.status <> 'signed') then
    if auth.uid() is not null and not public.is_ceo() and not public.approval_granted('employment_contract', new.id) then
      raise exception 'La signature d''un contrat de travail demande l''accord du CEO.' using errcode = '42501';
    end if;
    new.approved_at := coalesce(new.approved_at, now());
    new.approved_by := coalesce(new.approved_by, auth.uid());
  end if;
  return new;
end $$;
drop trigger if exists employment_contracts_guard_biu on public.employment_contracts;
create trigger employment_contracts_guard_biu before insert or update on public.employment_contracts
  for each row execute function public.employment_contracts_guard();

-- -----------------------------------------------------------------------------
-- 4. Calendrier opérationnel des projets
-- -----------------------------------------------------------------------------
do $enum$ begin
  create type public.cycle_kind as enum ('monthly', 'weekly', 'daily');
exception when duplicate_object then null;
end $enum$;
do $enum$ begin
  create type public.cycle_status as enum ('draft', 'pending_ceo', 'published', 'closed');
exception when duplicate_object then null;
end $enum$;
do $enum$ begin
  create type public.ops_item_status as enum ('planned', 'in_progress', 'done', 'dropped');
exception when duplicate_object then null;
end $enum$;

create table if not exists public.operation_cycles (
  id              uuid primary key default gen_random_uuid(),
  project_id      uuid not null references public.projects(id) on delete cascade,
  parent_cycle_id uuid references public.operation_cycles(id) on delete set null,  -- hebdo/journalier rattaché au mensuel
  kind            public.cycle_kind   not null,
  status          public.cycle_status not null default 'draft',
  period_start    date not null,
  period_end      date not null,
  title           text not null check (length(trim(title)) > 2),
  focus           text,                    -- le cap du cycle, en une phrase
  created_by      uuid references public.profiles(id) on delete set null default auth.uid(),
  published_at    timestamptz,
  closed_at       timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (period_end >= period_start),
  unique (project_id, kind, period_start)
);
create index if not exists operation_cycles_project_idx on public.operation_cycles(project_id, period_start desc);
create index if not exists operation_cycles_open_idx    on public.operation_cycles(status, period_end) where status = 'published';
drop trigger if exists operation_cycles_updated_at on public.operation_cycles;
create trigger operation_cycles_updated_at before update on public.operation_cycles
  for each row execute function public.set_updated_at();

-- Les grandes lignes : ce que les Opérations attendent du projet sur la période.
create table if not exists public.operation_items (
  id                uuid primary key default gen_random_uuid(),
  cycle_id          uuid not null references public.operation_cycles(id) on delete cascade,
  title             text not null check (length(trim(title)) > 2),
  detail            text,
  expected_outcome  text,                  -- le résultat attendu, vérifiable
  owner_id          uuid references public.profiles(id) on delete set null,
  due_date          date,
  status            public.ops_item_status not null default 'planned',
  position          double precision not null default extract(epoch from now()),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index if not exists operation_items_cycle_idx on public.operation_items(cycle_id, position);
drop trigger if exists operation_items_updated_at on public.operation_items;
create trigger operation_items_updated_at before update on public.operation_items
  for each row execute function public.set_updated_at();

-- Une tâche peut découler d'une grande ligne : c'est le lien entre le plan des
-- Opérations et le travail réel de l'équipe.
alter table public.tasks
  add column if not exists operation_item_id uuid references public.operation_items(id) on delete set null;
create index if not exists tasks_operation_item_idx on public.tasks(operation_item_id);

create table if not exists public.operation_reports (
  id           uuid primary key default gen_random_uuid(),
  cycle_id     uuid not null references public.operation_cycles(id) on delete cascade,
  project_id   uuid not null references public.projects(id) on delete cascade,
  author_id    uuid references public.profiles(id) on delete set null default auth.uid(),
  progress     int not null default 0 check (progress between 0 and 100),
  summary      text not null check (length(trim(summary)) > 10),
  blockers     text,
  next_steps   text,
  status       text not null default 'submitted' check (status in ('draft', 'submitted', 'acknowledged')),
  submitted_at timestamptz,
  reviewed_by  uuid references public.profiles(id) on delete set null,
  reviewed_at  timestamptz,
  review_note  text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists operation_reports_cycle_idx on public.operation_reports(cycle_id, created_at desc);
create index if not exists operation_reports_queue_idx on public.operation_reports(status) where status = 'submitted';
drop trigger if exists operation_reports_updated_at on public.operation_reports;
create trigger operation_reports_updated_at before update on public.operation_reports
  for each row execute function public.set_updated_at();

/** Qui écrit le calendrier : les Opérations, la direction, à défaut le chef de projet. */
create or replace function public.can_plan_project(p_project uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.has_perm('ops.plan') or public.has_perm('projects.admin') or public.is_ceo()
      or public.is_project_lead(p_project)
$$;
grant execute on function public.can_plan_project(uuid) to authenticated;

/** Publication : le mensuel passe par le CEO, l'hebdomadaire et le journalier non. */
create or replace function public.publish_operation_cycle(p_cycle uuid)
returns void language plpgsql security definer set search_path = public as $$
declare c public.operation_cycles; r record; v_project text;
begin
  select * into c from public.operation_cycles where id = p_cycle for update;
  if c.id is null then raise exception 'Cycle introuvable'; end if;
  if not public.can_plan_project(c.project_id) then raise exception 'Permission refusée' using errcode = '42501'; end if;
  if c.status = 'published' then return; end if;
  if not exists (select 1 from public.operation_items where cycle_id = p_cycle) then
    raise exception 'Ajoutez au moins une grande ligne avant de publier ce calendrier.';
  end if;

  if c.kind = 'monthly' and not public.is_ceo() and not public.approval_granted('operation_cycle', p_cycle) then
    update public.operation_cycles set status = 'pending_ceo' where id = p_cycle;
    select name into v_project from public.projects where id = c.project_id;
    perform public.request_approval('operation_cycle', p_cycle,
      'Calendrier mensuel — ' || coalesce(v_project, 'projet') || ' (' || to_char(c.period_start, 'MM/YYYY') || ')',
      null, c.focus, null, c.project_id);
    return;
  end if;

  update public.operation_cycles set status = 'published', published_at = now() where id = p_cycle;
  for r in
    select distinct m.profile_id from public.project_members m where m.project_id = c.project_id
    union select l.profile_id from public.project_liaisons l where l.project_id = c.project_id
  loop
    perform public.notify(r.profile_id, 'ops.cycle.published', 'Calendrier publié : ' || c.title,
      c.focus, '/projets/' || c.project_id || '?cycle=' || c.id);
  end loop;
end $$;
grant execute on function public.publish_operation_cycle(uuid) to authenticated;

-- L'accord du CEO publie le calendrier sans nouvelle manipulation.
create or replace function public.approval_requests_apply()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'approved' and old.status = 'pending' and new.kind = 'operation_cycle' and new.subject_id is not null then
    update public.operation_cycles set status = 'published', published_at = now()
     where id = new.subject_id and status <> 'published';
  end if;
  return null;
end $$;
drop trigger if exists approval_requests_apply_au on public.approval_requests;
create trigger approval_requests_apply_au after update on public.approval_requests
  for each row execute function public.approval_requests_apply();

/** Rapport du chef de projet aux Opérations, pour un cycle donné. */
create or replace function public.submit_operation_report(
  p_cycle uuid, p_progress int, p_summary text, p_blockers text default null, p_next text default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare c public.operation_cycles; v_id uuid; r record;
begin
  select * into c from public.operation_cycles where id = p_cycle;
  if c.id is null then raise exception 'Cycle introuvable'; end if;
  if not (public.is_project_lead(c.project_id) or public.can_manage_project(c.project_id)) then
    raise exception 'Seul le chef de projet rend compte de ce cycle' using errcode = '42501';
  end if;
  insert into public.operation_reports (cycle_id, project_id, progress, summary, blockers, next_steps, status, submitted_at)
  values (p_cycle, c.project_id, greatest(0, least(100, coalesce(p_progress, 0))), p_summary,
          nullif(trim(coalesce(p_blockers, '')), ''), nullif(trim(coalesce(p_next, '')), ''), 'submitted', now())
  returning id into v_id;

  for r in
    select g.profile_id from public.role_grants g
     where g.permission in ('ops.plan', 'ops.review') and (g.expires_at is null or g.expires_at > now())
    union select l.profile_id from public.project_liaisons l
     join public.org_units u on u.id = l.unit_id and u.domain = 'operations'
     where l.project_id = c.project_id
  loop
    perform public.notify(r.profile_id, 'ops.report.submitted', 'Rapport reçu : ' || c.title,
      left(p_summary, 140), '/operations?rapport=' || v_id);
  end loop;
  return v_id;
end $$;
grant execute on function public.submit_operation_report(uuid, int, text, text, text) to authenticated;

create or replace function public.acknowledge_operation_report(p_report uuid, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare r public.operation_reports;
begin
  if not (public.has_perm('ops.review') or public.has_perm('ops.plan') or public.is_ceo()) then
    raise exception 'Permission refusée' using errcode = '42501';
  end if;
  select * into r from public.operation_reports where id = p_report;
  if r.id is null then raise exception 'Rapport introuvable'; end if;
  update public.operation_reports
     set status = 'acknowledged', reviewed_by = auth.uid(), reviewed_at = now(),
         review_note = nullif(trim(coalesce(p_note, '')), '')
   where id = p_report;
  perform public.notify(r.author_id, 'ops.report.acknowledged', 'Rapport pris en compte',
    nullif(trim(coalesce(p_note, '')), ''), '/projets/' || r.project_id);
end $$;
grant execute on function public.acknowledge_operation_report(uuid, text) to authenticated;

alter table public.operation_cycles  enable row level security;
alter table public.operation_items   enable row level security;
alter table public.operation_reports enable row level security;
grant select, insert, update, delete on public.operation_cycles  to authenticated;
grant select, insert, update, delete on public.operation_items   to authenticated;
grant select, insert, update, delete on public.operation_reports to authenticated;

drop policy if exists "cycles: lecture" on public.operation_cycles;
create policy "cycles: lecture" on public.operation_cycles for select to authenticated
  using (public.can_view_project(project_id) or public.has_perm('ops.plan') or public.has_perm('ops.review'));
drop policy if exists "cycles: écriture" on public.operation_cycles;
create policy "cycles: écriture" on public.operation_cycles for insert to authenticated
  with check (public.can_plan_project(project_id));
drop policy if exists "cycles: modification" on public.operation_cycles;
create policy "cycles: modification" on public.operation_cycles for update to authenticated
  using (public.can_plan_project(project_id)) with check (public.can_plan_project(project_id));
drop policy if exists "cycles: suppression" on public.operation_cycles;
create policy "cycles: suppression" on public.operation_cycles for delete to authenticated
  using (public.can_plan_project(project_id) and status <> 'published');

drop policy if exists "lignes: lecture" on public.operation_items;
create policy "lignes: lecture" on public.operation_items for select to authenticated
  using (exists (select 1 from public.operation_cycles c where c.id = cycle_id
                  and (public.can_view_project(c.project_id) or public.has_perm('ops.plan'))));
drop policy if exists "lignes: gestion" on public.operation_items;
create policy "lignes: gestion" on public.operation_items for all to authenticated
  using (exists (select 1 from public.operation_cycles c where c.id = cycle_id and public.can_plan_project(c.project_id)))
  with check (exists (select 1 from public.operation_cycles c where c.id = cycle_id and public.can_plan_project(c.project_id)));

drop policy if exists "rapports: lecture" on public.operation_reports;
create policy "rapports: lecture" on public.operation_reports for select to authenticated
  using (public.can_view_project(project_id) or public.has_perm('ops.review') or public.has_perm('ops.plan') or public.has_perm('dashboard.exec'));
-- Écriture par submit_operation_report() / acknowledge_operation_report().

-- -----------------------------------------------------------------------------
-- 5. Juridique : le registre des contrats de la holding
-- -----------------------------------------------------------------------------
do $enum$ begin
  create type public.legal_contract_type as enum ('nda', 'partnership', 'client', 'supplier', 'licence', 'employment', 'statutory', 'other');
exception when duplicate_object then null;
end $enum$;
do $enum$ begin
  create type public.legal_contract_status as enum ('draft', 'legal_review', 'pending_ceo', 'signed', 'active', 'expired', 'terminated');
exception when duplicate_object then null;
end $enum$;

create sequence if not exists public.legal_contract_seq;

create table if not exists public.legal_contracts (
  id                  uuid primary key default gen_random_uuid(),
  reference           text unique not null default ('JUR-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('public.legal_contract_seq')::text, 4, '0')),
  title               text not null check (length(trim(title)) > 2),
  type                public.legal_contract_type   not null default 'other',
  status              public.legal_contract_status not null default 'draft',
  counterparty        text not null check (length(trim(counterparty)) > 1),
  account_id          uuid references public.accounts(id)    on delete set null,
  project_id          uuid references public.projects(id)    on delete set null,
  unit_id             uuid references public.org_units(id)   on delete set null,
  owner_id            uuid references public.profiles(id)    on delete set null default auth.uid(),
  document_id         uuid references public.documents(id)   on delete set null,
  amount              numeric(16,2),
  currency            text not null default 'XOF',
  risk                text not null default 'low' check (risk in ('low', 'medium', 'high')),
  signed_on           date,
  effective_date      date,
  end_date            date,
  renewal_notice_days int not null default 30 check (renewal_notice_days between 0 and 365),
  auto_renew          boolean not null default false,
  obligations         text,             -- engagements à tenir, en clair
  notes               text,
  created_by          uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  check (end_date is null or effective_date is null or end_date >= effective_date)
);
create index if not exists legal_contracts_status_idx  on public.legal_contracts(status, end_date);
create index if not exists legal_contracts_project_idx on public.legal_contracts(project_id);
create index if not exists legal_contracts_end_idx     on public.legal_contracts(end_date) where status in ('signed', 'active');
drop trigger if exists legal_contracts_updated_at on public.legal_contracts;
create trigger legal_contracts_updated_at before update on public.legal_contracts
  for each row execute function public.set_updated_at();
drop trigger if exists audit_legal_contracts on public.legal_contracts;
create trigger audit_legal_contracts after insert or update or delete on public.legal_contracts
  for each row execute function public.audit_trigger();

/** Signature : revue juridique puis accord du CEO. */
create or replace function public.legal_contracts_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status in ('signed', 'active') and (tg_op = 'INSERT' or old.status not in ('signed', 'active')) then
    if auth.uid() is not null and not public.is_ceo() and not public.approval_granted('legal_contract', new.id) then
      raise exception 'Ce contrat doit recevoir l''accord du CEO avant signature.' using errcode = '42501';
    end if;
    new.signed_on := coalesce(new.signed_on, current_date);
    new.effective_date := coalesce(new.effective_date, new.signed_on);
  end if;
  return new;
end $$;
drop trigger if exists legal_contracts_guard_biu on public.legal_contracts;
create trigger legal_contracts_guard_biu before insert or update on public.legal_contracts
  for each row execute function public.legal_contracts_guard();

/** Soumet un contrat à la signature du CEO (après revue juridique). */
create or replace function public.submit_contract_for_signature(p_contract uuid, p_justification text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare c public.legal_contracts; v_id uuid;
begin
  select * into c from public.legal_contracts where id = p_contract;
  if c.id is null then raise exception 'Contrat introuvable'; end if;
  if not (public.has_perm('legal.admin') or c.owner_id = auth.uid() or public.is_ceo()) then
    raise exception 'Permission refusée' using errcode = '42501';
  end if;
  update public.legal_contracts set status = 'pending_ceo' where id = p_contract and status in ('draft', 'legal_review');
  v_id := public.request_approval('legal_contract', p_contract,
    'Contrat ' || c.reference || ' — ' || c.title || ' (' || c.counterparty || ')',
    c.amount, p_justification, c.unit_id, c.project_id);
  return v_id;
end $$;
grant execute on function public.submit_contract_for_signature(uuid, text) to authenticated;

alter table public.legal_contracts enable row level security;
grant select, insert, update, delete on public.legal_contracts to authenticated;
drop policy if exists "contrats: lecture" on public.legal_contracts;
create policy "contrats: lecture" on public.legal_contracts for select to authenticated
  using (public.has_perm('legal.view') or public.has_perm('legal.admin') or public.has_perm('dashboard.exec')
         or owner_id = auth.uid()
         or (project_id is not null and public.is_project_lead(project_id)));
drop policy if exists "contrats: rédaction" on public.legal_contracts;
create policy "contrats: rédaction" on public.legal_contracts for insert to authenticated
  with check (public.has_perm('legal.admin') or public.is_ceo());
drop policy if exists "contrats: modification" on public.legal_contracts;
create policy "contrats: modification" on public.legal_contracts for update to authenticated
  using (public.has_perm('legal.admin') or public.is_ceo())
  with check (public.has_perm('legal.admin') or public.is_ceo());
drop policy if exists "contrats: suppression" on public.legal_contracts;
create policy "contrats: suppression" on public.legal_contracts for delete to authenticated
  using ((public.has_perm('legal.admin') or public.is_ceo()) and status = 'draft');

-- -----------------------------------------------------------------------------
-- 6. Tâches : répartition hiérarchique et vérification
-- -----------------------------------------------------------------------------
alter table public.tasks
  add column if not exists submitted_at timestamptz,
  add column if not exists reviewer_id  uuid references public.profiles(id) on delete set null,
  add column if not exists review_note  text;

/** Qui peut confier une tâche à qui : soi-même, son équipe projet, son unité. */
create or replace function public.can_assign_task(p_assignee uuid, p_project uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select case
    when p_assignee is null then true
    when p_assignee = auth.uid() then
      p_project is null or public.can_view_project(p_project)
    when public.has_perm('projects.admin') or public.is_ceo() then true
    when p_project is not null and public.can_manage_project(p_project) then
      exists (select 1 from public.project_members m where m.project_id = p_project and m.profile_id = p_assignee)
    when public.manages_profile(p_assignee) then true
    else exists (
      select 1 from public.unit_memberships m
      where m.profile_id = p_assignee and m.end_date is null and public.has_perm('unit.assign', m.unit_id))
  end
$$;
grant execute on function public.can_assign_task(uuid, uuid) to authenticated;

/**
 * Règles d'écriture des tâches :
 *   * on ne confie une tâche qu'à soi-même, à son équipe projet ou à son unité ;
 *   * une tâche confiée à quelqu'un d'autre passe par une vérification ;
 *   * le vérificateur est celui qui a assigné la tâche.
 */
create or replace function public.tasks_assignment_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null
     and new.assignee_id is not null
     and (tg_op = 'INSERT' or new.assignee_id is distinct from old.assignee_id)
     and not public.can_assign_task(new.assignee_id, new.project_id) then
    raise exception 'Vous ne pouvez confier une tâche qu''à vous-même ou aux personnes que vous encadrez.' using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    if new.assignee_id is not null and new.assignee_id is distinct from coalesce(new.reporter_id, auth.uid()) then
      new.requires_validation := true;
      new.reviewer_id := coalesce(new.reviewer_id, new.reporter_id, auth.uid());
    end if;
  elsif new.assignee_id is distinct from old.assignee_id and new.assignee_id is distinct from auth.uid() then
    new.reviewer_id := coalesce(new.reviewer_id, auth.uid());
  end if;
  return new;
end $$;
drop trigger if exists tasks_assignment_biu on public.tasks;
create trigger tasks_assignment_biu before insert or update on public.tasks
  for each row execute function public.tasks_assignment_guard();

/** Le titulaire soumet sa tâche à vérification. */
create or replace function public.submit_task(p_task uuid, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare t public.tasks; v_reviewer uuid; v_link text;
begin
  select * into t from public.tasks where id = p_task for update;
  if t.id is null then raise exception 'Tâche introuvable'; end if;
  if t.assignee_id is distinct from auth.uid() then
    raise exception 'Seule la personne en charge peut soumettre cette tâche' using errcode = '42501';
  end if;
  if t.status = 'done' then raise exception 'Cette tâche est déjà terminée'; end if;

  v_reviewer := coalesce(t.reviewer_id, t.reporter_id);
  v_link := case when t.project_id is not null then '/projets/' || t.project_id || '?tache=' || t.id else '/taches' end;

  if v_reviewer is null or v_reviewer = auth.uid() then
    -- Tâche personnelle : rien à vérifier, elle est terminée.
    update public.tasks set status = 'done', submitted_at = now(), review_note = nullif(trim(coalesce(p_note, '')), '')
     where id = p_task;
    return;
  end if;

  update public.tasks
     set status = 'review', submitted_at = now(), requires_validation = true,
         reviewer_id = v_reviewer, review_note = nullif(trim(coalesce(p_note, '')), '')
   where id = p_task;
  perform public.notify(v_reviewer, 'task.submitted', 'À vérifier : ' || t.title,
    nullif(trim(coalesce(p_note, '')), ''), v_link);
end $$;
grant execute on function public.submit_task(uuid, text) to authenticated;

/** Le vérificateur valide ou renvoie la tâche, motif à l'appui. */
create or replace function public.review_task(p_task uuid, p_approve boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare t public.tasks; v_link text;
begin
  select * into t from public.tasks where id = p_task for update;
  if t.id is null then raise exception 'Tâche introuvable'; end if;
  if not (coalesce(t.reviewer_id, t.reporter_id) = auth.uid()
          or (t.project_id is not null and public.can_manage_project(t.project_id))
          or public.is_ceo()) then
    raise exception 'Cette vérification revient à la personne qui a confié la tâche' using errcode = '42501';
  end if;
  if not p_approve and length(trim(coalesce(p_note, ''))) < 3 then
    raise exception 'Indiquez ce qui doit être repris';
  end if;

  v_link := case when t.project_id is not null then '/projets/' || t.project_id || '?tache=' || t.id else '/taches' end;

  if p_approve then
    update public.tasks
       set status = 'done', validated_by = auth.uid(), validated_at = now(),
           completed_at = coalesce(completed_at, now()), review_note = nullif(trim(coalesce(p_note, '')), '')
     where id = p_task;
    perform public.notify(t.assignee_id, 'task.validated', 'Tâche validée : ' || t.title, nullif(trim(coalesce(p_note, '')), ''), v_link);
  else
    update public.tasks
       set status = 'in_progress', submitted_at = null, review_note = trim(p_note)
     where id = p_task;
    perform public.notify(t.assignee_id, 'task.rejected', 'À reprendre : ' || t.title, trim(p_note), v_link);
  end if;
end $$;
grant execute on function public.review_task(uuid, boolean, text) to authenticated;

-- La validation passe désormais par review_task() : le titulaire ne clôt pas
-- lui-même une tâche qui lui a été confiée.
create or replace function public.tasks_before_write()
returns trigger language plpgsql security definer set search_path = public as $$
declare blocker text;
begin
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if new.status in ('in_progress', 'review', 'done') then
      select t.title into blocker
      from public.task_dependencies d join public.tasks t on t.id = d.depends_on_id
      where d.task_id = new.id and t.status <> 'done' limit 1;
      if blocker is not null then
        raise exception 'Tâche bloquée : « % » doit d''abord être terminée', blocker;
      end if;
    end if;

    if new.status = 'done' and new.requires_validation and auth.uid() is not null
       and new.validated_by is distinct from auth.uid() then
      if not (coalesce(new.reviewer_id, new.reporter_id) = auth.uid()
              or (new.project_id is not null and public.can_manage_project(new.project_id))) then
        raise exception 'Cette tâche doit être vérifiée : soumettez-la plutôt pour validation.';
      end if;
      new.validated_by := auth.uid();
      new.validated_at := now();
    end if;

    if new.status = 'done' then
      new.completed_at := coalesce(new.completed_at, now());
    else
      new.completed_at := null;
      new.validated_by := null;
      new.validated_at := null;
    end if;
  end if;

  if tg_op = 'INSERT' and new.status = 'done' then
    new.completed_at := now();
  end if;
  return new;
end $$;

create or replace function public.tasks_after_write()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  link text := case when new.project_id is not null then '/projets/' || new.project_id || '?tache=' || new.id else '/taches' end;
begin
  if new.assignee_id is not null and (tg_op = 'INSERT' or new.assignee_id is distinct from old.assignee_id) then
    perform public.notify(new.assignee_id, 'task.assigned', 'Nouvelle tâche : ' || new.title,
      case when new.due_date is not null then 'À rendre le ' || to_char(new.due_date, 'DD/MM/YYYY') else null end, link);
  end if;
  if tg_op = 'UPDATE' and new.status = 'review' and old.status <> 'review' and new.requires_validation then
    perform public.notify(coalesce(new.reviewer_id, new.reporter_id), 'task.submitted',
      'À vérifier : ' || new.title, null, link);
  end if;
  if tg_op = 'UPDATE' and new.status = 'done' and old.status <> 'done' and new.reporter_id is not null then
    perform public.notify(new.reporter_id, 'task.done', 'Tâche terminée : ' || new.title, null, link);
  end if;
  return null;
end $$;

-- -----------------------------------------------------------------------------
-- 7. Notifications : catégories des nouveaux événements
-- -----------------------------------------------------------------------------
create or replace function public.notification_category(p_kind text)
returns text language sql immutable as $$
  select case
    when p_kind like 'approval.%' or p_kind in ('task.review', 'task.submitted', 'leave.requested', 'reminder.reviews', 'reminder.leaves', 'reminder.approvals') then 'approvals'
    when p_kind like 'message.%'  then 'messages'
    when p_kind like 'ops.%' or p_kind like 'project.%' or p_kind = 'reminder.report' then 'projects'
    when p_kind like 'legal.%' or p_kind = 'reminder.contract' then 'legal'
    when p_kind like 'task.%' or p_kind in ('reminder.due', 'reminder.overdue') then 'tasks'
    when p_kind like 'drive.%'    then 'documents'
    when p_kind like 'meeting.%' or p_kind = 'reminder.meeting' then 'meetings'
    when p_kind like 'leave.%' or p_kind like 'hr.%' then 'hr'
    when p_kind = 'announcement'  then 'announcements'
    else 'other'
  end
$$;

-- Rappels quotidiens : contrats qui arrivent à échéance, décisions en attente,
-- rapports de cycle non rendus.
create or replace function public.generate_extra_reminders()
returns int language plpgsql security definer set search_path = public as $$
declare today date := (now() at time zone 'Africa/Porto-Novo')::date; n int := 0; r record;
begin
  -- Contrats dont le préavis de renouvellement court
  for r in
    select c.id, c.reference, c.title, c.end_date, c.owner_id
    from public.legal_contracts c
    where c.status in ('signed', 'active') and c.end_date is not null
      and c.end_date - c.renewal_notice_days <= today and c.end_date >= today
  loop
    perform public.notify(r.owner_id, 'reminder.contract',
      'Échéance contrat : ' || r.reference,
      r.title || ' arrive à terme le ' || to_char(r.end_date, 'DD/MM/YYYY') || '.', '/juridique?contrat=' || r.id);
    n := n + 1;
  end loop;

  -- Décisions en attente depuis plus de deux jours
  for r in
    select p.id from public.profiles p where p.status = 'active' and p.system_role = 'ceo'
      and exists (select 1 from public.approval_requests a where a.status = 'pending' and a.created_at < now() - interval '2 days')
  loop
    perform public.notify(r.id, 'reminder.approvals', 'Des décisions attendent votre accord', null, '/validations');
    n := n + 1;
  end loop;

  -- Cycles terminés sans rapport
  for r in
    select c.id, c.title, c.project_id, p.lead_id
    from public.operation_cycles c join public.projects p on p.id = c.project_id
    where c.status = 'published' and c.period_end < today and p.lead_id is not null
      and not exists (select 1 from public.operation_reports o where o.cycle_id = c.id)
  loop
    perform public.notify(r.lead_id, 'reminder.report', 'Rapport attendu : ' || r.title,
      'Le cycle est terminé : rendez compte aux Opérations.', '/projets/' || r.project_id || '?cycle=' || r.id);
    n := n + 1;
  end loop;
  return n;
end $$;
revoke execute on function public.generate_extra_reminders() from public, anon, authenticated;

do $$
begin
  perform cron.schedule('veriion-extra-reminders', '30 6 * * *', 'select public.generate_extra_reminders()');
exception when others then
  raise notice 'pg_cron non disponible : rappels juridiques et rapports à planifier plus tard (%)', sqlerrm;
end $$;

-- Les modèles de droits ont changé (Opérations, Juridique) : on recalcule les
-- droits automatiques de chacun, sinon seules les prochaines nominations en
-- bénéficieraient.
do $$ declare r record; begin
  for r in select id from public.profiles where status = 'active' loop
    perform public.sync_auto_grants(r.id);
  end loop;
end $$;
