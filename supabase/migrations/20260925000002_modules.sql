-- =============================================================================
-- VERIION OS — Migration 2 : Modules métier
-- Communication · Projets & tâches · CRM · Finance · RH · Documents ·
-- Objectifs & KPI · Réunions · Notifications · Pilotage
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Notifications (utilisées par les autres modules)
-- -----------------------------------------------------------------------------
create table public.notifications (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  kind        text not null,
  title       text not null,
  body        text,
  link        text,
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);
create index notifications_profile_idx on public.notifications(profile_id, created_at desc);

create or replace function public.notify(p_profile uuid, p_kind text, p_title text, p_body text default null, p_link text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_profile is null or p_profile = auth.uid() then return; end if;
  insert into public.notifications (profile_id, kind, title, body, link)
  values (p_profile, p_kind, p_title, p_body, p_link);
end $$;

-- -----------------------------------------------------------------------------
-- Communication interne
-- -----------------------------------------------------------------------------
create table public.announcements (
  id            uuid primary key default gen_random_uuid(),
  title         text not null,
  body          text not null,
  pinned        boolean not null default false,
  unit_id       uuid references public.org_units(id) on delete cascade,  -- null = toute l'entreprise
  author_id     uuid references public.profiles(id) on delete set null default auth.uid(),
  published_at  timestamptz not null default now(),
  created_at    timestamptz not null default now()
);
create index announcements_published_idx on public.announcements(published_at desc);

create type public.channel_kind as enum ('unit', 'project', 'group', 'direct');

create table public.channels (
  id           uuid primary key default gen_random_uuid(),
  kind         public.channel_kind not null default 'group',
  name         text not null,
  description  text,
  unit_id      uuid references public.org_units(id) on delete cascade,
  project_id   uuid,  -- FK ajoutée après la table projects
  is_private   boolean not null default false,
  dm_key       text unique,       -- pour les conversations directes : "uuidA:uuidB" trié
  created_by   uuid references public.profiles(id) on delete set null default auth.uid(),
  archived_at  timestamptz,
  created_at   timestamptz not null default now(),
  last_message_at timestamptz
);

create table public.channel_members (
  channel_id    uuid not null references public.channels(id) on delete cascade,
  profile_id    uuid not null references public.profiles(id) on delete cascade,
  role          text not null default 'member' check (role in ('owner', 'member')),
  last_read_at  timestamptz not null default now(),
  muted         boolean not null default false,
  joined_at     timestamptz not null default now(),
  primary key (channel_id, profile_id)
);
create index channel_members_profile_idx on public.channel_members(profile_id);

create table public.messages (
  id           uuid primary key default gen_random_uuid(),
  channel_id   uuid not null references public.channels(id) on delete cascade,
  author_id    uuid references public.profiles(id) on delete set null default auth.uid(),
  parent_id    uuid references public.messages(id) on delete cascade,
  body         text not null check (length(body) between 1 and 8000),
  attachments  jsonb not null default '[]'::jsonb,
  edited_at    timestamptz,
  deleted_at   timestamptz,
  created_at   timestamptz not null default now()
);
create index messages_channel_idx on public.messages(channel_id, created_at desc);

create or replace function public.messages_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.channels set last_message_at = new.created_at where id = new.channel_id;
  if new.author_id is not null then
    insert into public.channel_members (channel_id, profile_id, last_read_at)
    values (new.channel_id, new.author_id, new.created_at)
    on conflict (channel_id, profile_id) do update set last_read_at = excluded.last_read_at;
  end if;
  return null;
end $$;
create trigger messages_ai after insert on public.messages
  for each row execute function public.messages_after_insert();

-- -----------------------------------------------------------------------------
-- Projets & tâches
-- -----------------------------------------------------------------------------
create type public.project_status as enum ('planned', 'active', 'on_hold', 'completed', 'cancelled');
create type public.task_status    as enum ('backlog', 'todo', 'in_progress', 'review', 'done');
create type public.priority       as enum ('low', 'medium', 'high', 'urgent');

create sequence public.project_code_seq;

create table public.projects (
  id           uuid primary key default gen_random_uuid(),
  code         text unique not null default ('PRJ-' || lpad(nextval('public.project_code_seq')::text, 4, '0')),
  name         text not null,
  description  text,
  unit_id      uuid references public.org_units(id) on delete set null,
  owner_id     uuid references public.profiles(id) on delete set null default auth.uid(),
  status       public.project_status not null default 'planned',
  priority     public.priority not null default 'medium',
  start_date   date,
  due_date     date,
  budget       numeric(16,2),
  color        text not null default '#4F46E5',
  archived_at  timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  check (due_date is null or start_date is null or due_date >= start_date)
);
create index projects_unit_idx on public.projects(unit_id);
create trigger projects_updated_at before update on public.projects for each row execute function public.set_updated_at();

alter table public.channels add constraint channels_project_fk foreign key (project_id) references public.projects(id) on delete cascade;

create table public.project_members (
  project_id  uuid not null references public.projects(id) on delete cascade,
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  role        text not null default 'member' check (role in ('lead', 'member', 'viewer')),
  added_at    timestamptz not null default now(),
  primary key (project_id, profile_id)
);
create index project_members_profile_idx on public.project_members(profile_id);

create table public.tasks (
  id                   uuid primary key default gen_random_uuid(),
  project_id           uuid references public.projects(id) on delete cascade,
  parent_id            uuid references public.tasks(id) on delete cascade,
  title                text not null check (length(trim(title)) > 0),
  description          text,
  status               public.task_status not null default 'todo',
  priority             public.priority    not null default 'medium',
  assignee_id          uuid references public.profiles(id) on delete set null,
  reporter_id          uuid references public.profiles(id) on delete set null default auth.uid(),
  start_date           date,
  due_date             date,
  estimate_hours       numeric(6,2),
  position             double precision not null default extract(epoch from now()),
  requires_validation  boolean not null default false,
  validated_by         uuid references public.profiles(id) on delete set null,
  validated_at         timestamptz,
  completed_at         timestamptz,
  objective_id         uuid,  -- FK ajoutée après objectives
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
create index tasks_project_idx  on public.tasks(project_id, status, position);
create index tasks_assignee_idx on public.tasks(assignee_id) where status <> 'done';
create index tasks_due_idx      on public.tasks(due_date) where status <> 'done';
create trigger tasks_updated_at before update on public.tasks for each row execute function public.set_updated_at();

create table public.task_dependencies (
  task_id        uuid not null references public.tasks(id) on delete cascade,
  depends_on_id  uuid not null references public.tasks(id) on delete cascade,
  primary key (task_id, depends_on_id),
  check (task_id <> depends_on_id)
);

create table public.task_comments (
  id          uuid primary key default gen_random_uuid(),
  task_id     uuid not null references public.tasks(id) on delete cascade,
  author_id   uuid references public.profiles(id) on delete set null default auth.uid(),
  body        text not null,
  created_at  timestamptz not null default now()
);
create index task_comments_task_idx on public.task_comments(task_id, created_at);

-- Droits projet
create or replace function public.project_role(p_project uuid)
returns text language sql stable security definer set search_path = public as $$
  select role from public.project_members where project_id = p_project and profile_id = auth.uid()
$$;

create or replace function public.can_manage_project(p_project uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.projects p
    where p.id = p_project and (
      p.owner_id = auth.uid()
      or public.project_role(p.id) = 'lead'
      or public.has_perm('projects.admin')
      or public.has_perm('unit.manage', p.unit_id)
    )
  )
$$;

create or replace function public.can_view_project(p_project uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.projects p
    where p.id = p_project and (
      public.project_role(p.id) is not null
      or p.owner_id = auth.uid()
      or public.in_unit(p.unit_id)
      or public.has_perm('projects.admin')
      or public.has_perm('unit.manage', p.unit_id)
      or public.has_perm('dashboard.exec')
    )
  )
$$;

create or replace function public.can_contribute_project(p_project uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.can_manage_project(p_project)
      or coalesce(public.project_role(p_project) in ('lead', 'member'), false)
      or exists (select 1 from public.projects p where p.id = p_project and public.has_perm('unit.assign', p.unit_id))
$$;

-- Règles métier des tâches : dépendances, validation, dates de complétion, notifications.
create or replace function public.tasks_before_write()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  blocker text;
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

    if new.status = 'done' and new.requires_validation and auth.uid() is not null then
      if new.project_id is null or not public.can_manage_project(new.project_id) then
        raise exception 'Cette tâche doit être validée par le responsable du projet. Passez-la « En revue ».';
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
create trigger tasks_biu before insert or update on public.tasks
  for each row execute function public.tasks_before_write();

create or replace function public.tasks_after_write()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  link text := case when new.project_id is not null then '/projets/' || new.project_id || '?tache=' || new.id else '/taches' end;
begin
  if new.assignee_id is not null and (tg_op = 'INSERT' or new.assignee_id is distinct from old.assignee_id) then
    perform public.notify(new.assignee_id, 'task.assigned', 'Nouvelle tâche : ' || new.title, null, link);
  end if;
  if tg_op = 'UPDATE' and new.status = 'review' and old.status <> 'review' and new.requires_validation then
    perform public.notify(p.owner_id, 'task.review', 'Validation demandée : ' || new.title, null, link)
      from public.projects p where p.id = new.project_id;
  end if;
  if tg_op = 'UPDATE' and new.status = 'done' and old.status <> 'done' and new.reporter_id is not null then
    perform public.notify(new.reporter_id, 'task.done', 'Tâche terminée : ' || new.title, null, link);
  end if;
  return null;
end $$;
create trigger tasks_aiu after insert or update on public.tasks
  for each row execute function public.tasks_after_write();

create or replace function public.task_comments_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare t public.tasks;
begin
  select * into t from public.tasks where id = new.task_id;
  perform public.notify(t.assignee_id, 'task.comment', 'Commentaire sur : ' || t.title, left(new.body, 140),
    case when t.project_id is not null then '/projets/' || t.project_id || '?tache=' || t.id else '/taches' end);
  return null;
end $$;
create trigger task_comments_ai after insert on public.task_comments
  for each row execute function public.task_comments_after_insert();

-- Le créateur d'un projet en devient responsable ; un canal projet est créé.
create or replace function public.projects_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.owner_id is not null then
    insert into public.project_members (project_id, profile_id, role) values (new.id, new.owner_id, 'lead')
    on conflict do nothing;
  end if;
  insert into public.channels (kind, name, description, project_id, unit_id, is_private, created_by)
  values ('project', new.name, 'Canal du projet ' || new.code, new.id, new.unit_id, true, new.owner_id);
  return null;
end $$;
create trigger projects_ai after insert on public.projects
  for each row execute function public.projects_after_insert();

-- Un canal par département / sous-département / équipe.
create or replace function public.org_units_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.kind <> 'company' then
    insert into public.channels (kind, name, description, unit_id, is_private)
    values ('unit', new.name, 'Canal interne — ' || new.name, new.id, true);
  end if;
  return null;
end $$;
create trigger org_units_ai after insert on public.org_units
  for each row execute function public.org_units_after_insert();

-- -----------------------------------------------------------------------------
-- CRM & partenariats
-- -----------------------------------------------------------------------------
create type public.account_type      as enum ('prospect', 'client', 'partner');
create type public.opportunity_stage as enum ('lead', 'qualified', 'proposal', 'negotiation', 'won', 'lost');
create type public.interaction_kind  as enum ('call', 'email', 'meeting', 'note');

create table public.accounts (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  type        public.account_type not null default 'prospect',
  industry    text,
  country     text,
  city        text,
  website     text,
  email       text,
  phone       text,
  owner_id    uuid references public.profiles(id) on delete set null default auth.uid(),
  notes       text,
  tags        text[] not null default '{}',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index accounts_type_idx on public.accounts(type);
create trigger accounts_updated_at before update on public.accounts for each row execute function public.set_updated_at();

create table public.contacts (
  id          uuid primary key default gen_random_uuid(),
  account_id  uuid references public.accounts(id) on delete cascade,
  first_name  text not null,
  last_name   text,
  job_title   text,
  email       text,
  phone       text,
  is_primary  boolean not null default false,
  notes       text,
  owner_id    uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index contacts_account_idx on public.contacts(account_id);
create trigger contacts_updated_at before update on public.contacts for each row execute function public.set_updated_at();

create table public.opportunities (
  id              uuid primary key default gen_random_uuid(),
  account_id      uuid not null references public.accounts(id) on delete cascade,
  name            text not null,
  stage           public.opportunity_stage not null default 'lead',
  amount          numeric(16,2) not null default 0 check (amount >= 0),
  currency        text not null default 'XOF',
  probability     int not null default 10 check (probability between 0 and 100),
  expected_close  date,
  product         text,
  owner_id        uuid references public.profiles(id) on delete set null default auth.uid(),
  lost_reason     text,
  closed_at       timestamptz,
  project_id      uuid references public.projects(id) on delete set null,
  position        double precision not null default extract(epoch from now()),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index opportunities_stage_idx on public.opportunities(stage);
create trigger opportunities_updated_at before update on public.opportunities for each row execute function public.set_updated_at();

create table public.interactions (
  id              uuid primary key default gen_random_uuid(),
  account_id      uuid not null references public.accounts(id) on delete cascade,
  contact_id      uuid references public.contacts(id) on delete set null,
  opportunity_id  uuid references public.opportunities(id) on delete set null,
  kind            public.interaction_kind not null default 'note',
  subject         text not null,
  body            text,
  occurred_at     timestamptz not null default now(),
  author_id       uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at      timestamptz not null default now()
);
create index interactions_account_idx on public.interactions(account_id, occurred_at desc);

-- -----------------------------------------------------------------------------
-- Finance
-- -----------------------------------------------------------------------------
create type public.txn_type       as enum ('revenue', 'expense');
create type public.invoice_status as enum ('draft', 'sent', 'paid', 'overdue', 'cancelled');

create table public.budgets (
  id           uuid primary key default gen_random_uuid(),
  unit_id      uuid not null references public.org_units(id) on delete cascade,
  fiscal_year  int  not null check (fiscal_year between 2000 and 2100),
  amount       numeric(16,2) not null check (amount >= 0),
  currency     text not null default 'XOF',
  notes        text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (unit_id, fiscal_year)
);
create trigger budgets_updated_at before update on public.budgets for each row execute function public.set_updated_at();

create sequence public.invoice_number_seq;

create table public.invoices (
  id              uuid primary key default gen_random_uuid(),
  number          text unique not null default ('FAC-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('public.invoice_number_seq')::text, 5, '0')),
  account_id      uuid references public.accounts(id) on delete restrict,
  opportunity_id  uuid references public.opportunities(id) on delete set null,
  unit_id         uuid references public.org_units(id) on delete set null,
  status          public.invoice_status not null default 'draft',
  issue_date      date not null default current_date,
  due_date        date not null default (current_date + 30),
  currency        text not null default 'XOF',
  subtotal        numeric(16,2) not null default 0,
  tax_rate        numeric(5,2)  not null default 18,
  tax_amount      numeric(16,2) not null default 0,
  total           numeric(16,2) not null default 0,
  product         text,
  country         text,
  notes           text,
  paid_at         timestamptz,
  created_by      uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index invoices_status_idx on public.invoices(status, due_date);
create trigger invoices_updated_at before update on public.invoices for each row execute function public.set_updated_at();

create table public.invoice_lines (
  id           uuid primary key default gen_random_uuid(),
  invoice_id   uuid not null references public.invoices(id) on delete cascade,
  description  text not null,
  quantity     numeric(12,2) not null default 1 check (quantity > 0),
  unit_price   numeric(16,2) not null default 0 check (unit_price >= 0),
  amount       numeric(16,2) generated always as (round(quantity * unit_price, 2)) stored,
  position     int not null default 0
);
create index invoice_lines_invoice_idx on public.invoice_lines(invoice_id);

create table public.transactions (
  id           uuid primary key default gen_random_uuid(),
  type         public.txn_type not null,
  amount       numeric(16,2) not null check (amount > 0),
  currency     text not null default 'XOF',
  occurred_on  date not null default current_date,
  category     text not null default 'Autre',
  description  text,
  unit_id      uuid references public.org_units(id) on delete set null,
  project_id   uuid references public.projects(id) on delete set null,
  account_id   uuid references public.accounts(id) on delete set null,
  invoice_id   uuid references public.invoices(id) on delete set null unique,
  product      text,
  country      text,
  reference    text,
  created_by   uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at   timestamptz not null default now()
);
create index transactions_date_idx on public.transactions(occurred_on desc);
create index transactions_unit_idx on public.transactions(unit_id);

-- Totaux de facture calculés depuis les lignes
create or replace function public.recompute_invoice(p_invoice uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.invoices i set
    subtotal   = coalesce(s.sum, 0),
    tax_amount = round(coalesce(s.sum, 0) * i.tax_rate / 100, 2),
    total      = coalesce(s.sum, 0) + round(coalesce(s.sum, 0) * i.tax_rate / 100, 2)
  from (select sum(amount) as sum from public.invoice_lines where invoice_id = p_invoice) s
  where i.id = p_invoice;
end $$;

create or replace function public.invoice_lines_after_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.recompute_invoice(coalesce(new.invoice_id, old.invoice_id));
  return null;
end $$;
create trigger invoice_lines_aiud after insert or update or delete on public.invoice_lines
  for each row execute function public.invoice_lines_after_change();

create or replace function public.invoices_before_update()
returns trigger language plpgsql as $$
begin
  if new.tax_rate is distinct from old.tax_rate then
    new.tax_amount := round(new.subtotal * new.tax_rate / 100, 2);
    new.total      := new.subtotal + new.tax_amount;
  end if;
  if new.status = 'paid' and old.status <> 'paid' then
    new.paid_at := coalesce(new.paid_at, now());
  elsif new.status <> 'paid' then
    new.paid_at := null;
  end if;
  return new;
end $$;
create trigger invoices_bu before update on public.invoices
  for each row execute function public.invoices_before_update();

-- Une facture payée génère le revenu correspondant (et l'annule si elle repasse impayée).
create or replace function public.invoices_after_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'paid' and old.status <> 'paid' and new.total > 0 then
    insert into public.transactions (type, amount, currency, occurred_on, category, description,
                                     unit_id, account_id, invoice_id, product, country, reference, created_by)
    values ('revenue', new.total, new.currency, coalesce(new.paid_at, now())::date, 'Ventes',
            'Paiement facture ' || new.number, new.unit_id, new.account_id, new.id, new.product, new.country,
            new.number, auth.uid())
    on conflict (invoice_id) do nothing;
  elsif old.status = 'paid' and new.status <> 'paid' then
    delete from public.transactions where invoice_id = new.id;
  end if;
  return null;
end $$;
create trigger invoices_au after update on public.invoices
  for each row execute function public.invoices_after_update();

create or replace function public.mark_overdue_invoices()
returns int language sql security definer set search_path = public as $$
  with u as (
    update public.invoices set status = 'overdue'
    where status = 'sent' and due_date < current_date
    returning 1
  ) select count(*)::int from u
$$;

-- Opportunité gagnée : le compte devient client, un projet de livraison et une facture brouillon sont créés.
create or replace function public.opportunities_before_update()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_unit uuid;
  v_invoice uuid;
  v_account public.accounts;
begin
  if new.stage in ('won', 'lost') and old.stage not in ('won', 'lost') then
    new.closed_at := now();
    new.probability := case when new.stage = 'won' then 100 else 0 end;
  elsif new.stage not in ('won', 'lost') then
    new.closed_at := null;
  end if;

  if new.stage = 'won' and old.stage <> 'won' then
    select * into v_account from public.accounts where id = new.account_id;
    update public.accounts set type = 'client' where id = new.account_id and type = 'prospect';
    select primary_unit_id into v_unit from public.profiles where id = new.owner_id;

    if new.project_id is null then
      insert into public.projects (name, description, unit_id, owner_id, status, start_date)
      values ('Livraison — ' || new.name, 'Projet créé automatiquement à la signature de l''opportunité « ' || new.name || ' »',
              v_unit, new.owner_id, 'planned', current_date)
      returning id into new.project_id;
    end if;

    if not exists (select 1 from public.invoices where opportunity_id = new.id) and new.amount > 0 then
      insert into public.invoices (account_id, opportunity_id, unit_id, currency, product, country, notes, created_by)
      values (new.account_id, new.id, v_unit, new.currency, new.product, v_account.country,
              'Facture prévisionnelle — ' || new.name, new.owner_id)
      returning id into v_invoice;
      insert into public.invoice_lines (invoice_id, description, quantity, unit_price)
      values (v_invoice, new.name, 1, new.amount);
    end if;
  end if;
  return new;
end $$;
create trigger opportunities_bu before update on public.opportunities
  for each row execute function public.opportunities_before_update();

-- -----------------------------------------------------------------------------
-- RH
-- -----------------------------------------------------------------------------
create type public.contract_type  as enum ('cdi', 'cdd', 'internship', 'freelance', 'consultant');
create type public.leave_type     as enum ('annual', 'sick', 'maternity', 'paternity', 'unpaid', 'other');
create type public.request_status as enum ('pending', 'approved', 'rejected', 'cancelled');

create table public.employment_contracts (
  id           uuid primary key default gen_random_uuid(),
  profile_id   uuid not null references public.profiles(id) on delete cascade,
  type         public.contract_type not null default 'cdi',
  job_title    text,
  start_date   date not null,
  end_date     date,
  weekly_hours numeric(4,1) default 40,
  document_id  uuid,  -- FK ajoutée après documents
  notes        text,
  created_at   timestamptz not null default now(),
  check (end_date is null or end_date >= start_date)
);
create index employment_contracts_profile_idx on public.employment_contracts(profile_id);

create table public.salaries (
  id              uuid primary key default gen_random_uuid(),
  profile_id      uuid not null references public.profiles(id) on delete cascade,
  gross_monthly   numeric(14,2) not null check (gross_monthly >= 0),
  currency        text not null default 'XOF',
  effective_from  date not null default current_date,
  notes           text,
  created_by      uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at      timestamptz not null default now()
);
create index salaries_profile_idx on public.salaries(profile_id, effective_from desc);

create table public.leave_requests (
  id             uuid primary key default gen_random_uuid(),
  profile_id     uuid not null references public.profiles(id) on delete cascade default auth.uid(),
  type           public.leave_type not null default 'annual',
  start_date     date not null,
  end_date       date not null,
  days           numeric(5,1) generated always as ((end_date - start_date + 1)::numeric) stored,
  reason         text,
  status         public.request_status not null default 'pending',
  approver_id    uuid references public.profiles(id) on delete set null,
  decided_at     timestamptz,
  decision_note  text,
  created_at     timestamptz not null default now(),
  check (end_date >= start_date)
);
create index leave_requests_profile_idx on public.leave_requests(profile_id, start_date desc);
create index leave_requests_pending_idx on public.leave_requests(status) where status = 'pending';

create table public.lifecycle_items (
  id           uuid primary key default gen_random_uuid(),
  profile_id   uuid not null references public.profiles(id) on delete cascade,
  kind         text not null check (kind in ('onboarding', 'offboarding')),
  title        text not null,
  assignee_id  uuid references public.profiles(id) on delete set null,
  due_date     date,
  done_at      timestamptz,
  position     int not null default 0,
  created_at   timestamptz not null default now()
);
create index lifecycle_items_profile_idx on public.lifecycle_items(profile_id, kind);

create or replace function public.can_decide_leave(p_request uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.leave_requests r
    where r.id = p_request and r.profile_id <> auth.uid()
      and (public.has_perm('hr.admin') or public.manages_profile(r.profile_id))
  )
$$;

create or replace function public.leave_requests_before_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status and auth.uid() is not null then
    if new.status in ('approved', 'rejected') then
      if not public.can_decide_leave(old.id) then
        raise exception 'Vous ne pouvez pas statuer sur cette demande' using errcode = '42501';
      end if;
      new.approver_id := auth.uid();
      new.decided_at := now();
    elsif new.status = 'cancelled' and old.profile_id <> auth.uid() and not public.has_perm('hr.admin') then
      raise exception 'Seul le demandeur peut annuler' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
create trigger leave_requests_bu before update on public.leave_requests
  for each row execute function public.leave_requests_before_update();

create or replace function public.leave_requests_after_write()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  r record;
  who text;
begin
  if tg_op = 'INSERT' then
    select full_name into who from public.profiles where id = new.profile_id;
    for r in
      select distinct g.profile_id
      from public.role_grants g
      join public.unit_memberships m on m.profile_id = new.profile_id and m.end_date is null
      join public.org_units u on u.id = m.unit_id
      where g.permission = 'unit.manage' and g.scope_unit_id = any(u.path) and g.profile_id <> new.profile_id
      union
      select manager_id from public.profiles where id = new.profile_id and manager_id is not null
    loop
      perform public.notify(r.profile_id, 'leave.requested', 'Demande de congé : ' || coalesce(who, ''),
        to_char(new.start_date, 'DD/MM') || ' → ' || to_char(new.end_date, 'DD/MM'), '/rh?onglet=validation');
    end loop;
  elsif new.status is distinct from old.status and new.status in ('approved', 'rejected') then
    perform public.notify(new.profile_id, 'leave.decided',
      case when new.status = 'approved' then 'Congé approuvé' else 'Congé refusé' end,
      coalesce(new.decision_note, to_char(new.start_date, 'DD/MM') || ' → ' || to_char(new.end_date, 'DD/MM')), '/rh');
  end if;
  return null;
end $$;
create trigger leave_requests_aiu after insert or update on public.leave_requests
  for each row execute function public.leave_requests_after_write();

-- Onboarding standard : checklist créée à l'arrivée d'un employé
create or replace function public.profiles_after_insert_onboarding()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.lifecycle_items (profile_id, kind, title, position, due_date) values
    (new.id, 'onboarding', 'Compléter son profil et sa photo',               1, current_date + 2),
    (new.id, 'onboarding', 'Activer l''authentification à deux facteurs',    2, current_date + 1),
    (new.id, 'onboarding', 'Signer le contrat de travail',                    3, current_date + 5),
    (new.id, 'onboarding', 'Lire les politiques internes',                    4, current_date + 7),
    (new.id, 'onboarding', 'Rencontrer son responsable et son équipe',        5, current_date + 7),
    (new.id, 'onboarding', 'Recevoir le matériel et les accès métier',        6, current_date + 3);
  return null;
end $$;
create trigger profiles_ai_onboarding after insert on public.profiles
  for each row execute function public.profiles_after_insert_onboarding();

-- -----------------------------------------------------------------------------
-- Documents & connaissances
-- -----------------------------------------------------------------------------
create type public.doc_classification as enum ('internal', 'restricted', 'confidential');
create type public.doc_category       as enum ('contract', 'procedure', 'presentation', 'policy', 'technical', 'minutes', 'project', 'other');

create table public.documents (
  id              uuid primary key default gen_random_uuid(),
  title           text not null,
  description     text,
  category        public.doc_category not null default 'other',
  classification  public.doc_classification not null default 'internal',
  unit_id         uuid references public.org_units(id) on delete set null,
  project_id      uuid references public.projects(id) on delete set null,
  account_id      uuid references public.accounts(id) on delete set null,
  owner_id        uuid references public.profiles(id) on delete set null default auth.uid(),
  storage_path    text unique,
  file_name       text,
  mime_type       text,
  size_bytes      bigint,
  version         int not null default 1,
  tags            text[] not null default '{}',
  search          tsvector generated always as (
                    setweight(to_tsvector('french', coalesce(title, '')), 'A') ||
                    setweight(to_tsvector('french', coalesce(description, '')), 'B') ||
                    setweight(to_tsvector('simple', coalesce(file_name, '')), 'C')
                  ) stored,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index documents_search_idx on public.documents using gin(search);
create index documents_unit_idx   on public.documents(unit_id);
create trigger documents_updated_at before update on public.documents for each row execute function public.set_updated_at();

alter table public.employment_contracts add constraint employment_contracts_document_fk
  foreign key (document_id) references public.documents(id) on delete set null;

create or replace function public.can_read_document(p_doc uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.documents d
    where d.id = p_doc and public.is_active_user() and (
      d.owner_id = auth.uid()
      or public.has_perm('docs.confidential')
      or public.has_perm('unit.manage', d.unit_id)
      or (d.classification = 'internal')
      or (d.classification = 'restricted' and (
            public.in_unit(d.unit_id)
            or (d.project_id is not null and public.can_view_project(d.project_id))
            or (d.account_id is not null and public.has_perm('crm.view'))
            or (d.unit_id is null and d.project_id is null and d.account_id is null)))
    )
  )
$$;

-- -----------------------------------------------------------------------------
-- Objectifs & performance
-- -----------------------------------------------------------------------------
create type public.objective_level  as enum ('company', 'unit', 'individual');
create type public.objective_status as enum ('on_track', 'at_risk', 'off_track', 'done');

create table public.objectives (
  id           uuid primary key default gen_random_uuid(),
  parent_id    uuid references public.objectives(id) on delete set null,
  level        public.objective_level not null default 'unit',
  unit_id      uuid references public.org_units(id) on delete cascade,
  owner_id     uuid references public.profiles(id) on delete set null default auth.uid(),
  title        text not null,
  description  text,
  period       text not null default to_char(now(), 'YYYY') || '-T' || to_char(now(), 'Q'),
  status       public.objective_status not null default 'on_track',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  check (level <> 'unit' or unit_id is not null)
);
create index objectives_period_idx on public.objectives(period, level);
create trigger objectives_updated_at before update on public.objectives for each row execute function public.set_updated_at();

alter table public.tasks add constraint tasks_objective_fk foreign key (objective_id) references public.objectives(id) on delete set null;

create table public.key_results (
  id             uuid primary key default gen_random_uuid(),
  objective_id   uuid not null references public.objectives(id) on delete cascade,
  title          text not null,
  metric_unit    text,
  start_value    numeric(16,2) not null default 0,
  target_value   numeric(16,2) not null,
  current_value  numeric(16,2) not null default 0,
  position       int not null default 0,
  updated_at     timestamptz not null default now(),
  check (target_value <> start_value)
);
create index key_results_objective_idx on public.key_results(objective_id);
create trigger key_results_updated_at before update on public.key_results for each row execute function public.set_updated_at();

create or replace view public.objectives_progress with (security_invoker = true) as
select o.*,
  coalesce(round(avg(greatest(0, least(1, (kr.current_value - kr.start_value) / (kr.target_value - kr.start_value)))) * 100), 0)::int as progress,
  count(kr.id)::int as key_result_count
from public.objectives o
left join public.key_results kr on kr.objective_id = o.id
group by o.id;

create or replace function public.can_edit_objective(p_obj uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.objectives o where o.id = p_obj and (
      (o.level = 'company' and public.has_perm('objectives.admin'))
      or (o.level = 'unit' and (public.has_perm('unit.manage', o.unit_id) or public.has_perm('objectives.admin')))
      or (o.level = 'individual' and (o.owner_id = auth.uid() or public.manages_profile(o.owner_id)))
    )
  )
$$;

-- Référentiel unique des KPI
create table public.kpi_definitions (
  id           uuid primary key default gen_random_uuid(),
  key          text unique not null,
  name         text not null,
  description  text,
  formula      text,
  source       text,
  unit         text,
  owner_id     uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now()
);

-- Métriques produit (utilisateurs actifs, etc.) — saisies ou alimentées par API
create table public.product_metrics (
  id            uuid primary key default gen_random_uuid(),
  metric_date   date not null,
  product       text not null default 'VERIION',
  country       text not null default 'ALL',
  active_users  int not null default 0,
  new_users     int not null default 0,
  created_at    timestamptz not null default now(),
  unique (metric_date, product, country)
);

create type public.incident_severity as enum ('low', 'medium', 'high', 'critical');
create type public.incident_status   as enum ('open', 'mitigated', 'resolved');

create table public.incidents (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  description  text,
  severity     public.incident_severity not null default 'medium',
  status       public.incident_status   not null default 'open',
  unit_id      uuid references public.org_units(id) on delete set null,
  product      text,
  reported_by  uuid references public.profiles(id) on delete set null default auth.uid(),
  occurred_at  timestamptz not null default now(),
  resolved_at  timestamptz,
  created_at   timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- Réunions
-- -----------------------------------------------------------------------------
create table public.meetings (
  id            uuid primary key default gen_random_uuid(),
  title         text not null,
  description   text,
  starts_at     timestamptz not null,
  ends_at       timestamptz not null,
  location      text,
  video_url     text,
  unit_id       uuid references public.org_units(id) on delete set null,
  project_id    uuid references public.projects(id) on delete set null,
  organizer_id  uuid references public.profiles(id) on delete set null default auth.uid(),
  minutes       text,
  created_at    timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index meetings_starts_idx on public.meetings(starts_at);

create table public.meeting_attendees (
  meeting_id  uuid not null references public.meetings(id) on delete cascade,
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  response    text not null default 'pending' check (response in ('pending', 'accepted', 'declined')),
  primary key (meeting_id, profile_id)
);
create index meeting_attendees_profile_idx on public.meeting_attendees(profile_id);

create or replace function public.meeting_attendees_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare m public.meetings;
begin
  select * into m from public.meetings where id = new.meeting_id;
  perform public.notify(new.profile_id, 'meeting.invite', 'Invitation : ' || m.title,
    to_char(m.starts_at at time zone 'Africa/Porto-Novo', 'DD/MM à HH24:MI'), '/reunions');
  return null;
end $$;
create trigger meeting_attendees_ai after insert on public.meeting_attendees
  for each row execute function public.meeting_attendees_after_insert();

create or replace function public.is_meeting_participant(p_meeting uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.meetings m where m.id = p_meeting and m.organizer_id = auth.uid())
      or exists (select 1 from public.meeting_attendees a where a.meeting_id = p_meeting and a.profile_id = auth.uid())
$$;

-- Annonce publiée : notification à tous les destinataires actifs.
create or replace function public.announcements_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (profile_id, kind, title, body, link)
  select p.id, 'announcement', 'Annonce : ' || new.title, left(new.body, 140), '/'
  from public.profiles p
  where p.status = 'active' and p.id <> coalesce(new.author_id, '00000000-0000-0000-0000-000000000000'::uuid)
    and (new.unit_id is null or exists (
      select 1 from public.unit_memberships m join public.org_units u on u.id = m.unit_id
      where m.profile_id = p.id and m.end_date is null and new.unit_id = any(u.path)));
  return null;
end $$;
create trigger announcements_ai after insert on public.announcements
  for each row execute function public.announcements_after_insert();

-- Nomination : la personne est notifiée.
create or replace function public.unit_memberships_notify()
returns trigger language plpgsql security definer set search_path = public as $$
declare u text;
begin
  select name into u from public.org_units where id = new.unit_id;
  perform public.notify(new.profile_id, 'org.appointed',
    case new.role when 'head' then 'Vous êtes nommé(e) responsable de ' when 'deputy' then 'Vous êtes nommé(e) adjoint(e) de ' else 'Vous avez rejoint ' end || u,
    'Vos droits ont été mis à jour automatiquement.', '/organisation/' || new.unit_id);
  return null;
end $$;
create trigger unit_memberships_notify_ai after insert on public.unit_memberships
  for each row execute function public.unit_memberships_notify();

-- -----------------------------------------------------------------------------
-- Audit des modules sensibles
-- -----------------------------------------------------------------------------
create trigger audit_projects        after insert or update or delete on public.projects             for each row execute function public.audit_trigger();
create trigger audit_tasks           after insert or update or delete on public.tasks                for each row execute function public.audit_trigger();
create trigger audit_accounts        after insert or update or delete on public.accounts             for each row execute function public.audit_trigger();
create trigger audit_opportunities   after insert or update or delete on public.opportunities        for each row execute function public.audit_trigger();
create trigger audit_budgets         after insert or update or delete on public.budgets              for each row execute function public.audit_trigger();
create trigger audit_invoices        after insert or update or delete on public.invoices             for each row execute function public.audit_trigger();
create trigger audit_transactions    after insert or update or delete on public.transactions         for each row execute function public.audit_trigger();
create trigger audit_contracts       after insert or update or delete on public.employment_contracts for each row execute function public.audit_trigger();
create trigger audit_salaries        after insert or update or delete on public.salaries             for each row execute function public.audit_trigger('redact');
create trigger audit_leave_requests  after insert or update or delete on public.leave_requests       for each row execute function public.audit_trigger();
create trigger audit_documents       after insert or update or delete on public.documents            for each row execute function public.audit_trigger();
create trigger audit_objectives      after insert or update or delete on public.objectives           for each row execute function public.audit_trigger();
create trigger audit_announcements   after insert or update or delete on public.announcements        for each row execute function public.audit_trigger();
create trigger audit_incidents       after insert or update or delete on public.incidents            for each row execute function public.audit_trigger();
