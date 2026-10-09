-- =============================================================================
-- VERIION OS — Installation complète (migrations + données initiales)
-- Généré à partir de supabase/migrations/*.sql et supabase/seed.sql (npm run build:install).
-- Collez ce fichier dans Supabase > SQL Editor et exécutez-le UNE fois.
-- =============================================================================

-- >>>>>>>>>> supabase/migrations/20260925000001_foundation.sql
-- =============================================================================
-- VERIION OS — Migration 1 : Socle (identité, organisation, permissions, audit)
-- =============================================================================
-- Principes :
--   * Une identité unique : auth.users  ->  public.profiles (1:1)
--   * L'organisation pilote les droits : unit_memberships -> role_grants (auto)
--   * Moindre privilège : toutes les tables sont protégées par RLS
--   * Historique immuable : audit_log alimenté par triggers
-- =============================================================================

create extension if not exists pgcrypto with schema extensions;

-- -----------------------------------------------------------------------------
-- Types
-- -----------------------------------------------------------------------------
create type public.system_role     as enum ('ceo', 'admin', 'employee');
create type public.employee_status as enum ('active', 'suspended', 'offboarded');
create type public.unit_kind       as enum ('company', 'department', 'subdepartment', 'team');
create type public.unit_domain     as enum ('direction', 'operations', 'technology', 'marketing', 'business', 'finance', 'hr', 'other');
create type public.membership_role as enum ('head', 'deputy', 'member');
create type public.grant_source    as enum ('auto', 'manual');

-- -----------------------------------------------------------------------------
-- Utilitaires
-- -----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

create or replace function public.membership_rank(r public.membership_role)
returns int language sql immutable as $$
  select case r when 'head' then 3 when 'deputy' then 2 else 1 end
$$;

-- -----------------------------------------------------------------------------
-- Paramètres de l'entreprise (ligne unique)
-- -----------------------------------------------------------------------------
create table public.company_settings (
  id              boolean primary key default true check (id),
  company_name    text        not null default 'VERIION',
  email_domain    text        not null default 'veriion.com',
  currency        text        not null default 'XOF',
  timezone        text        not null default 'Africa/Porto-Novo',
  opening_cash    numeric(16,2) not null default 0,
  default_tax_rate numeric(5,2) not null default 18,
  updated_at      timestamptz not null default now()
);
insert into public.company_settings default values;

-- -----------------------------------------------------------------------------
-- Organisation : Entreprise -> Département -> Sous-département -> Équipe
-- -----------------------------------------------------------------------------
create table public.org_units (
  id           uuid primary key default gen_random_uuid(),
  parent_id    uuid references public.org_units(id) on delete restrict,
  name         text not null check (length(trim(name)) > 1),
  code         text unique,
  kind         public.unit_kind not null default 'department',
  domain       public.unit_domain,
  description  text,
  color        text not null default '#4F46E5',
  sort_order   int  not null default 0,
  path         uuid[] not null default '{}',   -- ancêtres + soi-même, de la racine à l'unité
  depth        int  not null default 0,
  archived_at  timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index org_units_parent_idx on public.org_units(parent_id);
create index org_units_path_idx   on public.org_units using gin(path);

-- Calcule le chemin, la profondeur, hérite du domaine du parent, empêche les cycles.
create or replace function public.org_units_compute_path()
returns trigger language plpgsql as $$
declare
  parent public.org_units;
begin
  if new.parent_id is null then
    new.path  := array[new.id];
    new.depth := 0;
    new.domain := coalesce(new.domain, 'direction');
  else
    select * into parent from public.org_units where id = new.parent_id;
    if parent.id is null then
      raise exception 'Unité parente introuvable';
    end if;
    if new.id = any(parent.path) then
      raise exception 'Déplacement impossible : cela créerait une boucle dans l''organigramme';
    end if;
    new.path  := parent.path || new.id;
    new.depth := parent.depth + 1;
    new.domain := coalesce(new.domain, parent.domain, 'other');
  end if;
  return new;
end $$;

create trigger org_units_path_bi before insert on public.org_units
  for each row execute function public.org_units_compute_path();
create trigger org_units_path_bu before update of parent_id on public.org_units
  for each row execute function public.org_units_compute_path();
create trigger org_units_updated_at before update on public.org_units
  for each row execute function public.set_updated_at();

-- Propage un changement de chemin aux descendants.
create or replace function public.org_units_propagate_path()
returns trigger language plpgsql as $$
begin
  if new.path is distinct from old.path then
    update public.org_units set parent_id = parent_id where parent_id = new.id;
  end if;
  return null;
end $$;
create trigger org_units_path_au after update of parent_id on public.org_units
  for each row execute function public.org_units_propagate_path();

-- -----------------------------------------------------------------------------
-- Profils (1:1 avec auth.users)
-- -----------------------------------------------------------------------------
create table public.profiles (
  id               uuid primary key references auth.users(id) on delete cascade,
  email            text not null unique,
  first_name       text not null default '',
  last_name        text not null default '',
  full_name        text generated always as (trim(first_name || ' ' || last_name)) stored,
  job_title        text,
  phone            text,
  avatar_url       text,
  bio              text,
  location         text,
  system_role      public.system_role     not null default 'employee',
  status           public.employee_status not null default 'active',
  primary_unit_id  uuid references public.org_units(id) on delete set null,
  manager_id       uuid references public.profiles(id) on delete set null,
  hire_date        date,
  birth_date       date,
  last_seen_at     timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index profiles_unit_idx    on public.profiles(primary_unit_id);
create index profiles_manager_idx on public.profiles(manager_id);
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- Création automatique du profil à l'inscription / l'invitation.
-- Le tout premier compte devient CEO (amorçage). Désactivez ensuite les
-- inscriptions publiques dans Supabase (Auth > Providers > Email).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  has_ceo boolean;
begin
  select exists(select 1 from public.profiles where system_role = 'ceo') into has_ceo;
  insert into public.profiles (id, email, first_name, last_name, job_title, primary_unit_id, system_role, hire_date)
  values (
    new.id,
    lower(new.email),
    coalesce(nullif(meta->>'first_name', ''), initcap(split_part(split_part(new.email, '@', 1), '.', 1))),
    coalesce(nullif(meta->>'last_name', ''),  initcap(split_part(split_part(new.email, '@', 1), '.', 2))),
    meta->>'job_title',
    nullif(meta->>'primary_unit_id', '')::uuid,
    case when has_ceo then 'employee'::public.system_role else 'ceo'::public.system_role end,
    current_date
  )
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- Appartenances (historisées) : une personne dans une unité, avec un rôle daté
-- -----------------------------------------------------------------------------
create table public.unit_memberships (
  id          uuid primary key default gen_random_uuid(),
  unit_id     uuid not null references public.org_units(id) on delete cascade,
  profile_id  uuid not null references public.profiles(id)  on delete cascade,
  role        public.membership_role not null default 'member',
  title       text,
  start_date  date not null default current_date,
  end_date    date,
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  check (end_date is null or end_date >= start_date)
);
-- Un seul responsable actif par unité, une seule appartenance active par personne et par unité.
create unique index unit_memberships_one_head   on public.unit_memberships(unit_id) where role = 'head' and end_date is null;
create unique index unit_memberships_one_active on public.unit_memberships(unit_id, profile_id) where end_date is null;
create index unit_memberships_profile_idx on public.unit_memberships(profile_id) where end_date is null;

-- -----------------------------------------------------------------------------
-- Permissions : catalogue, modèles automatiques, attributions
-- -----------------------------------------------------------------------------
create table public.permissions (
  key          text primary key,
  label        text not null,
  description  text,
  category     text not null,
  scopable     boolean not null default false
);

create table public.role_templates (
  id               uuid primary key default gen_random_uuid(),
  domain           public.unit_domain,              -- null = toutes les unités
  membership_role  public.membership_role not null, -- rang minimum requis
  permission       text not null references public.permissions(key) on delete cascade,
  scoped           boolean not null default false,  -- limité à l'unité (et ses descendants)
  unique nulls not distinct (domain, membership_role, permission)
);

create table public.role_grants (
  id             uuid primary key default gen_random_uuid(),
  profile_id     uuid not null references public.profiles(id) on delete cascade,
  permission     text not null references public.permissions(key) on delete cascade,
  scope_unit_id  uuid references public.org_units(id) on delete cascade,
  source         public.grant_source not null default 'manual',
  membership_id  uuid references public.unit_memberships(id) on delete cascade,
  reason         text,
  expires_at     timestamptz,
  granted_by     uuid references public.profiles(id) on delete set null,
  created_at     timestamptz not null default now(),
  check (source = 'auto' or (reason is not null and length(trim(reason)) > 3))
);
create index role_grants_profile_idx on public.role_grants(profile_id, permission);

insert into public.permissions (key, label, description, category, scopable) values
  ('org.manage',            'Gérer l''organisation',      'Créer, déplacer, archiver des unités et nommer les responsables', 'Administration', false),
  ('users.admin',           'Gérer les comptes',          'Inviter, suspendre, désactiver des employés',                     'Administration', false),
  ('grants.manage',         'Gérer les dérogations',      'Attribuer des droits manuels temporaires',                        'Administration', false),
  ('audit.view',            'Consulter le journal',       'Accès au journal d''activité complet',                            'Administration', false),
  ('unit.manage',           'Administrer une unité',      'Gestion de l''unité, de ses membres, objectifs et budget',         'Organisation',   true),
  ('unit.assign',           'Attribuer des tâches',       'Attribuer et suivre les tâches des membres de l''unité',           'Organisation',   true),
  ('dashboard.exec',        'Dashboard de direction',     'Vue consolidée de l''entreprise',                                  'Pilotage',       false),
  ('objectives.admin',      'Objectifs entreprise',       'Définir les objectifs de niveau entreprise',                      'Pilotage',       false),
  ('metrics.manage',        'Indicateurs produit',        'Saisir les métriques produit et les incidents',                   'Pilotage',       false),
  ('announcements.publish', 'Publier des annonces',       'Publier des annonces internes',                                   'Communication',  false),
  ('projects.admin',        'Administrer les projets',    'Accès à tous les projets',                                        'Projets',        false),
  ('crm.view',              'Consulter le CRM',           'Lecture des comptes, contacts et opportunités',                   'CRM',            false),
  ('crm.edit',              'Modifier le CRM',            'Créer et mettre à jour comptes, contacts, opportunités',          'CRM',            false),
  ('crm.admin',             'Administrer le CRM',         'Suppression et réattribution',                                     'CRM',            false),
  ('finance.view',          'Consulter la finance',       'Lecture des revenus, dépenses, factures, budgets',                'Finance',        false),
  ('finance.admin',         'Administrer la finance',     'Saisie et validation financière, paie',                           'Finance',        false),
  ('hr.view',               'Consulter les RH',           'Lecture des dossiers RH (hors salaires)',                          'RH',             false),
  ('hr.admin',              'Administrer les RH',         'Contrats, congés, salaires, onboarding',                           'RH',             false),
  ('docs.confidential',     'Documents confidentiels',    'Accès à tous les documents confidentiels',                         'Documents',      false);

-- Modèles : ce qu'un rôle dans une unité donne automatiquement.
insert into public.role_templates (domain, membership_role, permission, scoped) values
  (null,         'head',   'unit.manage',           true),
  (null,         'deputy', 'unit.assign',           true),
  (null,         'head',   'announcements.publish', false),
  ('direction',  'head',   'dashboard.exec',        false),
  ('direction',  'head',   'objectives.admin',      false),
  ('direction',  'deputy', 'dashboard.exec',        false),
  ('finance',    'member', 'finance.view',          false),
  ('finance',    'deputy', 'finance.admin',         false),
  ('finance',    'head',   'dashboard.exec',        false),
  ('business',   'member', 'crm.view',              false),
  ('business',   'member', 'crm.edit',              false),
  ('business',   'head',   'crm.admin',             false),
  ('marketing',  'head',   'crm.view',              false),
  ('hr',         'member', 'hr.view',               false),
  ('hr',         'deputy', 'hr.admin',              false),
  ('operations', 'head',   'projects.admin',        false),
  ('technology', 'head',   'metrics.manage',        false);

-- Recalcule les droits automatiques d'une personne à partir de ses appartenances actives.
create or replace function public.sync_auto_grants(p_profile uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.role_grants where profile_id = p_profile and source = 'auto';
  insert into public.role_grants (profile_id, permission, scope_unit_id, source, membership_id)
  select distinct on (t.permission, case when t.scoped then m.unit_id end)
         m.profile_id, t.permission, case when t.scoped then m.unit_id end, 'auto', m.id
  from public.unit_memberships m
  join public.org_units u       on u.id = m.unit_id and u.archived_at is null
  join public.role_templates t  on (t.domain is null or t.domain = u.domain)
                               and public.membership_rank(m.role) >= public.membership_rank(t.membership_role)
                               -- Les droits globaux de responsable/adjoint ne sont donnés qu'au niveau département ;
                               -- dans une sous-unité, seules les règles de membre et les droits limités à l'unité s'appliquent.
                               and (t.scoped or t.membership_role = 'member' or u.kind in ('company', 'department'))
  where m.profile_id = p_profile
    and m.end_date is null
  order by t.permission, case when t.scoped then m.unit_id end, public.membership_rank(m.role) desc;
end $$;

create or replace function public.unit_memberships_after_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform public.sync_auto_grants(old.profile_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    perform public.sync_auto_grants(new.profile_id);
    -- L'unité principale suit la première appartenance
    update public.profiles set primary_unit_id = new.unit_id
      where id = new.profile_id and primary_unit_id is null and new.end_date is null;
  end if;
  return null;
end $$;
create trigger unit_memberships_sync after insert or update or delete on public.unit_memberships
  for each row execute function public.unit_memberships_after_change();

create or replace function public.org_units_after_domain_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare r record;
begin
  if new.domain is distinct from old.domain or new.archived_at is distinct from old.archived_at then
    for r in select distinct profile_id from public.unit_memberships where unit_id = new.id and end_date is null loop
      perform public.sync_auto_grants(r.profile_id);
    end loop;
  end if;
  return null;
end $$;
create trigger org_units_domain_au after update of domain, archived_at on public.org_units
  for each row execute function public.org_units_after_domain_change();

-- -----------------------------------------------------------------------------
-- Fonctions d'autorisation (utilisées par toutes les politiques RLS)
-- -----------------------------------------------------------------------------
create or replace function public.is_active_user()
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and status = 'active')
$$;

create or replace function public.is_ceo()
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and status = 'active' and system_role = 'ceo')
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and status = 'active' and system_role in ('ceo', 'admin'))
$$;

-- Vrai si l'utilisateur courant détient la permission, globalement ou sur une unité ancêtre de p_unit.
create or replace function public.has_perm(p_perm text, p_unit uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  select case
    when not public.is_active_user() then false
    when public.is_ceo() then true
    when p_perm in ('org.manage', 'users.admin', 'grants.manage', 'audit.view') and public.is_admin() then true
    else exists (
      select 1 from public.role_grants g
      where g.profile_id = auth.uid()
        and g.permission = p_perm
        and (g.expires_at is null or g.expires_at > now())
        and (
          g.scope_unit_id is null
          or (p_unit is not null and exists (
                select 1 from public.org_units u where u.id = p_unit and g.scope_unit_id = any(u.path)))
        )
    )
  end
$$;

-- Vrai si l'utilisateur courant est membre actif de p_unit ou d'une de ses sous-unités.
create or replace function public.in_unit(p_unit uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_unit is not null and exists (
    select 1 from public.unit_memberships m
    join public.org_units u on u.id = m.unit_id
    where m.profile_id = auth.uid() and m.end_date is null and p_unit = any(u.path)
  )
$$;

-- Vrai si l'utilisateur courant peut voir les données internes d'une unité.
create or replace function public.can_view_unit(p_unit uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.in_unit(p_unit) or public.has_perm('unit.manage', p_unit) or public.has_perm('dashboard.exec')
$$;

-- Vrai si l'utilisateur courant encadre p_profile (manager direct ou responsable d'une unité de la personne).
create or replace function public.manages_profile(p_profile uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_ceo()
      or exists (select 1 from public.profiles p where p.id = p_profile and p.manager_id = auth.uid())
      or exists (select 1 from public.unit_memberships m
                 where m.profile_id = p_profile and m.end_date is null
                   and public.has_perm('unit.manage', m.unit_id))
$$;

-- Liste des permissions effectives de l'utilisateur courant (pour l'interface).
create or replace function public.my_permissions()
returns table (permission text, scope_unit_id uuid)
language sql stable security definer set search_path = public as $$
  select p.key, null::uuid from public.permissions p where public.is_ceo()
  union
  select p.key, null::uuid from public.permissions p
    where public.is_admin() and p.key in ('org.manage', 'users.admin', 'grants.manage', 'audit.view')
  union
  select g.permission, g.scope_unit_id from public.role_grants g
    where g.profile_id = auth.uid() and (g.expires_at is null or g.expires_at > now()) and public.is_active_user()
$$;

-- -----------------------------------------------------------------------------
-- Opérations organisationnelles (transactionnelles, contrôlées, historisées)
-- -----------------------------------------------------------------------------

-- Nomme un responsable / adjoint / membre. Clôture l'affectation précédente sans l'effacer.
create or replace function public.appoint_member(
  p_unit uuid, p_profile uuid, p_role public.membership_role,
  p_title text default null, p_start date default current_date
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_parent uuid;
  v_id uuid;
begin
  select parent_id into v_parent from public.org_units where id = p_unit and archived_at is null;
  if not found then raise exception 'Unité introuvable ou archivée'; end if;

  -- Nommer un responsable : org.manage ou gestion de l'unité parente. Membres/adjoints : gestion de l'unité.
  if not (public.has_perm('org.manage')
          or (p_role = 'head' and v_parent is not null and public.has_perm('unit.manage', v_parent))
          or (p_role <> 'head' and public.has_perm('unit.manage', p_unit))) then
    raise exception 'Permission refusée' using errcode = '42501';
  end if;

  if p_role = 'head' then
    update public.unit_memberships
       set end_date = greatest(start_date, p_start - 1)
     where unit_id = p_unit and role = 'head' and end_date is null and profile_id <> p_profile;
  end if;

  -- Clôture l'éventuelle affectation active de la personne dans cette unité (changement de rôle).
  update public.unit_memberships
     set end_date = greatest(start_date, p_start - 1)
   where unit_id = p_unit and profile_id = p_profile and end_date is null;

  insert into public.unit_memberships (unit_id, profile_id, role, title, start_date, created_by)
  values (p_unit, p_profile, p_role, p_title, p_start, auth.uid())
  returning id into v_id;
  return v_id;
end $$;

-- Retire une personne d'une unité (clôture datée).
create or replace function public.end_membership(p_membership uuid, p_end date default current_date)
returns void language plpgsql security definer set search_path = public as $$
declare m public.unit_memberships;
begin
  select * into m from public.unit_memberships where id = p_membership and end_date is null;
  if not found then raise exception 'Affectation introuvable ou déjà clôturée'; end if;
  if not (public.has_perm('org.manage') or public.has_perm('unit.manage', m.unit_id)) then
    raise exception 'Permission refusée' using errcode = '42501';
  end if;
  update public.unit_memberships set end_date = greatest(m.start_date, p_end) where id = p_membership;
end $$;

-- -----------------------------------------------------------------------------
-- Journal d'audit
-- -----------------------------------------------------------------------------
create table public.audit_log (
  id              bigint generated always as identity primary key,
  occurred_at     timestamptz not null default now(),
  actor_id        uuid,
  action          text not null,
  table_name      text not null,
  record_id       text,
  old_data        jsonb,
  new_data        jsonb,
  changed_fields  text[]
);
create index audit_log_table_record_idx on public.audit_log(table_name, record_id);
create index audit_log_occurred_idx     on public.audit_log(occurred_at desc);
create index audit_log_actor_idx        on public.audit_log(actor_id);

create or replace function public.audit_trigger()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  o jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  n jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
  changed text[];
  redact boolean := coalesce(tg_argv[0], '') = 'redact';
begin
  if tg_op = 'UPDATE' then
    select array_agg(k) into changed
    from jsonb_object_keys(n) k
    where k not in ('updated_at', 'search') and n->k is distinct from o->k;
    if changed is null then return null; end if;
  end if;
  insert into public.audit_log (actor_id, action, table_name, record_id, old_data, new_data, changed_fields)
  values (
    auth.uid(), lower(tg_op), tg_table_name,
    coalesce(n->>'id', o->>'id', n->>'profile_id', o->>'profile_id'),
    case when redact then null else o - 'search' end,
    case when redact then null else n - 'search' end,
    changed
  );
  return null;
end $$;

create trigger audit_org_units        after insert or update or delete on public.org_units        for each row execute function public.audit_trigger();
create trigger audit_profiles         after insert or update or delete on public.profiles         for each row execute function public.audit_trigger();
create trigger audit_unit_memberships after insert or update or delete on public.unit_memberships for each row execute function public.audit_trigger();
create trigger audit_role_grants      after insert or update or delete on public.role_grants      for each row execute function public.audit_trigger();
create trigger audit_role_templates   after insert or update or delete on public.role_templates   for each row execute function public.audit_trigger();
create trigger audit_company_settings after update on public.company_settings for each row execute function public.audit_trigger();

-- -----------------------------------------------------------------------------
-- Protection des champs sensibles du profil
-- -----------------------------------------------------------------------------
create or replace function public.profiles_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return new; end if;  -- service role / SQL editor
  if not public.has_perm('users.admin') then
    if new.system_role is distinct from old.system_role
       or new.status is distinct from old.status
       or new.email is distinct from old.email
       or new.hire_date is distinct from old.hire_date then
      raise exception 'Seuls les administrateurs peuvent modifier ce champ' using errcode = '42501';
    end if;
    if (new.manager_id is distinct from old.manager_id or new.primary_unit_id is distinct from old.primary_unit_id)
       and not public.manages_profile(old.id) then
      raise exception 'Seul un responsable peut modifier le rattachement' using errcode = '42501';
    end if;
  end if;
  if new.system_role = 'ceo' and old.system_role <> 'ceo' and not public.is_ceo() then
    raise exception 'Seul le CEO peut désigner un CEO' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger profiles_guard_bu before update on public.profiles
  for each row execute function public.profiles_guard();

-- >>>>>>>>>> supabase/migrations/20260925000002_modules.sql
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

-- >>>>>>>>>> supabase/migrations/20260925000003_security.sql
-- =============================================================================
-- VERIION OS — Migration 3 : Sécurité (RLS, privilèges)
-- Chaque table est fermée par défaut ; chaque politique découle des fonctions
-- d'autorisation définies dans la migration 1 (has_perm, in_unit, ...).
-- =============================================================================

-- Privilèges de base : l'accès réel est décidé par RLS.
revoke all on all tables    in schema public from anon;
revoke all on all sequences in schema public from anon;
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- Fonctions internes : jamais appelables depuis l'API.
revoke execute on function public.notify(uuid, text, text, text, text)  from public, anon, authenticated;
revoke execute on function public.sync_auto_grants(uuid)                 from public, anon, authenticated;
revoke execute on function public.recompute_invoice(uuid)                from public, anon, authenticated;
revoke execute on function public.mark_overdue_invoices()                from public, anon, authenticated;

-- Garde : seuls org.manage (ou le responsable de l'unité parente) déplacent / archivent une unité.
create or replace function public.org_units_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or public.has_perm('org.manage') then return new; end if;
  if new.parent_id is distinct from old.parent_id
     or new.kind is distinct from old.kind
     or new.domain is distinct from old.domain
     or new.archived_at is distinct from old.archived_at then
    if not public.has_perm('unit.manage', old.parent_id) then
      raise exception 'Seule la direction peut restructurer cette unité' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
create trigger org_units_guard_bu before update on public.org_units
  for each row execute function public.org_units_guard();

-- Toute modification d'un modèle de rôle recalcule les droits de tous.
create or replace function public.role_templates_resync()
returns trigger language plpgsql security definer set search_path = public as $$
declare r record;
begin
  for r in select distinct profile_id from public.unit_memberships where end_date is null loop
    perform public.sync_auto_grants(r.profile_id);
  end loop;
  return null;
end $$;
create trigger role_templates_resync_trg after insert or update or delete on public.role_templates
  for each statement execute function public.role_templates_resync();

-- -----------------------------------------------------------------------------
-- Activation RLS
-- -----------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'company_settings','org_units','profiles','unit_memberships','permissions','role_templates','role_grants','audit_log',
    'notifications','announcements','channels','channel_members','messages',
    'projects','project_members','tasks','task_dependencies','task_comments',
    'accounts','contacts','opportunities','interactions',
    'budgets','invoices','invoice_lines','transactions',
    'employment_contracts','salaries','leave_requests','lifecycle_items',
    'documents','objectives','key_results','kpi_definitions','product_metrics','incidents',
    'meetings','meeting_attendees'
  ] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- Socle
-- -----------------------------------------------------------------------------
create policy "settings: lecture"      on public.company_settings for select to authenticated using (public.is_active_user());
create policy "settings: modification" on public.company_settings for update to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "units: lecture"   on public.org_units for select to authenticated using (public.is_active_user());
create policy "units: création"  on public.org_units for insert to authenticated
  with check (public.has_perm('org.manage') or (parent_id is not null and public.has_perm('unit.manage', parent_id)));
create policy "units: modification" on public.org_units for update to authenticated
  using (public.has_perm('org.manage') or public.has_perm('unit.manage', id))
  with check (public.has_perm('org.manage') or public.has_perm('unit.manage', id));
create policy "units: suppression" on public.org_units for delete to authenticated using (public.has_perm('org.manage'));

create policy "profiles: annuaire" on public.profiles for select to authenticated using (public.is_active_user());
create policy "profiles: modification" on public.profiles for update to authenticated
  using (id = auth.uid() or public.has_perm('users.admin') or public.manages_profile(id))
  with check (id = auth.uid() or public.has_perm('users.admin') or public.manages_profile(id));

create policy "memberships: lecture" on public.unit_memberships for select to authenticated using (public.is_active_user());
-- écriture uniquement via appoint_member() / end_membership()

create policy "permissions: lecture" on public.permissions    for select to authenticated using (public.is_active_user());
create policy "templates: lecture"   on public.role_templates for select to authenticated using (public.is_active_user());
create policy "templates: gestion"   on public.role_templates for all to authenticated
  using (public.is_ceo()) with check (public.is_ceo());

create policy "grants: lecture" on public.role_grants for select to authenticated
  using (profile_id = auth.uid() or public.has_perm('grants.manage') or public.has_perm('audit.view'));
create policy "grants: dérogation" on public.role_grants for insert to authenticated
  with check (public.has_perm('grants.manage') and source = 'manual' and granted_by = auth.uid() and profile_id <> auth.uid());
create policy "grants: révocation" on public.role_grants for delete to authenticated
  using (public.has_perm('grants.manage') and source = 'manual');

create policy "audit: lecture" on public.audit_log for select to authenticated using (public.has_perm('audit.view'));

create policy "notifications: les miennes" on public.notifications for select to authenticated using (profile_id = auth.uid());
create policy "notifications: marquer lue"  on public.notifications for update to authenticated using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "notifications: supprimer"    on public.notifications for delete to authenticated using (profile_id = auth.uid());

-- -----------------------------------------------------------------------------
-- Communication
-- -----------------------------------------------------------------------------
create policy "annonces: lecture" on public.announcements for select to authenticated
  using (public.is_active_user() and (unit_id is null or public.in_unit(unit_id) or public.has_perm('unit.manage', unit_id) or author_id = auth.uid()));
create policy "annonces: publication" on public.announcements for insert to authenticated
  with check (public.has_perm('announcements.publish') and author_id = auth.uid());
create policy "annonces: modification" on public.announcements for update to authenticated
  using (author_id = auth.uid() or public.is_admin()) with check (author_id = auth.uid() or public.is_admin());
create policy "annonces: suppression" on public.announcements for delete to authenticated
  using (author_id = auth.uid() or public.is_admin());

create or replace function public.can_access_channel(p_channel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.channels c
    where c.id = p_channel and public.is_active_user() and (
      c.created_by = auth.uid()
      or exists (select 1 from public.channel_members m where m.channel_id = c.id and m.profile_id = auth.uid())
      or (c.kind = 'group'   and not c.is_private)
      or (c.kind = 'unit'    and (public.in_unit(c.unit_id) or public.has_perm('unit.manage', c.unit_id)))
      or (c.kind = 'project' and public.can_view_project(c.project_id))
    )
  )
$$;

-- Le créateur d'un groupe en est propriétaire.
create or replace function public.channels_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.kind = 'group' and new.created_by is not null then
    insert into public.channel_members (channel_id, profile_id, role) values (new.id, new.created_by, 'owner')
    on conflict do nothing;
  end if;
  return null;
end $$;
create trigger channels_ai after insert on public.channels
  for each row execute function public.channels_after_insert();

create policy "canaux: lecture" on public.channels for select to authenticated
  using (created_by = auth.uid() or public.can_access_channel(id));
create policy "canaux: création" on public.channels for insert to authenticated
  with check (public.is_active_user() and kind = 'group' and created_by = auth.uid());
create policy "canaux: modification" on public.channels for update to authenticated
  using (created_by = auth.uid() or public.is_admin()
         or (kind = 'unit' and public.has_perm('unit.manage', unit_id))
         or (kind = 'project' and public.can_manage_project(project_id)))
  with check (created_by = auth.uid() or public.is_admin()
         or (kind = 'unit' and public.has_perm('unit.manage', unit_id))
         or (kind = 'project' and public.can_manage_project(project_id)));

create policy "membres canal: lecture" on public.channel_members for select to authenticated
  using (profile_id = auth.uid() or public.can_access_channel(channel_id));
create policy "membres canal: rejoindre / ajouter" on public.channel_members for insert to authenticated
  with check (
    (profile_id = auth.uid() and public.can_access_channel(channel_id))
    or exists (select 1 from public.channels c where c.id = channel_id and c.kind = 'group' and c.created_by = auth.uid())
    or exists (select 1 from public.channel_members m where m.channel_id = channel_members.channel_id and m.profile_id = auth.uid() and m.role = 'owner')
  );
create policy "membres canal: préférences" on public.channel_members for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "membres canal: quitter / retirer" on public.channel_members for delete to authenticated
  using (profile_id = auth.uid() or exists (select 1 from public.channels c where c.id = channel_id and c.created_by = auth.uid()));

create policy "messages: lecture" on public.messages for select to authenticated using (public.can_access_channel(channel_id));
create policy "messages: envoi" on public.messages for insert to authenticated
  with check (author_id = auth.uid() and public.can_access_channel(channel_id)
              and exists (select 1 from public.channels c where c.id = channel_id and c.archived_at is null));
create policy "messages: édition" on public.messages for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());

-- -----------------------------------------------------------------------------
-- Projets & tâches
-- -----------------------------------------------------------------------------
create policy "projets: lecture" on public.projects for select to authenticated
  using (owner_id = auth.uid() or public.project_role(id) is not null or public.in_unit(unit_id)
         or public.has_perm('projects.admin') or public.has_perm('unit.manage', unit_id) or public.has_perm('dashboard.exec'));
create policy "projets: création" on public.projects for insert to authenticated
  with check (public.is_active_user() and owner_id = auth.uid()
              and (unit_id is null or public.in_unit(unit_id) or public.has_perm('unit.assign', unit_id) or public.has_perm('projects.admin')));
create policy "projets: modification" on public.projects for update to authenticated
  using (public.can_manage_project(id)) with check (public.can_manage_project(id));
create policy "projets: suppression" on public.projects for delete to authenticated
  using (public.has_perm('projects.admin') or owner_id = auth.uid());

create policy "membres projet: lecture" on public.project_members for select to authenticated using (public.can_view_project(project_id));
create policy "membres projet: gestion" on public.project_members for all to authenticated
  using (public.can_manage_project(project_id)) with check (public.can_manage_project(project_id));

create or replace function public.can_view_task(p_task uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.tasks t where t.id = p_task and (
      t.assignee_id = auth.uid() or t.reporter_id = auth.uid()
      or (t.project_id is not null and public.can_view_project(t.project_id)))
  )
$$;

create or replace function public.can_edit_task(p_task uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.tasks t where t.id = p_task and (
      t.assignee_id = auth.uid() or t.reporter_id = auth.uid()
      or (t.project_id is not null and public.can_contribute_project(t.project_id)))
  )
$$;

create policy "tâches: lecture" on public.tasks for select to authenticated
  using (assignee_id = auth.uid() or reporter_id = auth.uid() or (project_id is not null and public.can_view_project(project_id)));
create policy "tâches: création" on public.tasks for insert to authenticated
  with check (public.is_active_user() and reporter_id = auth.uid()
              and (project_id is null or public.can_contribute_project(project_id)));
create policy "tâches: modification" on public.tasks for update to authenticated
  using (assignee_id = auth.uid() or reporter_id = auth.uid() or (project_id is not null and public.can_contribute_project(project_id)))
  with check (project_id is null or public.can_contribute_project(project_id) or assignee_id = auth.uid() or reporter_id = auth.uid());
create policy "tâches: suppression" on public.tasks for delete to authenticated
  using (reporter_id = auth.uid() or (project_id is not null and public.can_manage_project(project_id)));

create policy "dépendances: lecture" on public.task_dependencies for select to authenticated using (public.can_view_task(task_id));
create policy "dépendances: gestion" on public.task_dependencies for all to authenticated
  using (public.can_edit_task(task_id)) with check (public.can_edit_task(task_id) and public.can_view_task(depends_on_id));

create policy "commentaires: lecture" on public.task_comments for select to authenticated using (public.can_view_task(task_id));
create policy "commentaires: ajout" on public.task_comments for insert to authenticated
  with check (author_id = auth.uid() and public.can_view_task(task_id));
create policy "commentaires: suppression" on public.task_comments for delete to authenticated using (author_id = auth.uid());

-- -----------------------------------------------------------------------------
-- CRM
-- -----------------------------------------------------------------------------
create or replace function public.can_read_crm()
returns boolean language sql stable security definer set search_path = public as $$
  select public.has_perm('crm.view') or public.has_perm('crm.edit') or public.has_perm('crm.admin') or public.has_perm('dashboard.exec')
$$;

create policy "comptes: lecture"      on public.accounts for select to authenticated using (public.can_read_crm() or owner_id = auth.uid());
create policy "comptes: création"     on public.accounts for insert to authenticated with check (public.has_perm('crm.edit'));
create policy "comptes: modification" on public.accounts for update to authenticated
  using (public.has_perm('crm.edit') or owner_id = auth.uid()) with check (public.has_perm('crm.edit') or owner_id = auth.uid());
create policy "comptes: suppression"  on public.accounts for delete to authenticated using (public.has_perm('crm.admin'));

create policy "contacts: lecture"      on public.contacts for select to authenticated using (public.can_read_crm() or owner_id = auth.uid());
create policy "contacts: création"     on public.contacts for insert to authenticated with check (public.has_perm('crm.edit'));
create policy "contacts: modification" on public.contacts for update to authenticated
  using (public.has_perm('crm.edit') or owner_id = auth.uid()) with check (public.has_perm('crm.edit') or owner_id = auth.uid());
create policy "contacts: suppression"  on public.contacts for delete to authenticated using (public.has_perm('crm.admin') or owner_id = auth.uid());

create policy "opportunités: lecture"      on public.opportunities for select to authenticated using (public.can_read_crm() or owner_id = auth.uid());
create policy "opportunités: création"     on public.opportunities for insert to authenticated with check (public.has_perm('crm.edit'));
create policy "opportunités: modification" on public.opportunities for update to authenticated
  using (public.has_perm('crm.edit') or owner_id = auth.uid()) with check (public.has_perm('crm.edit') or owner_id = auth.uid());
create policy "opportunités: suppression"  on public.opportunities for delete to authenticated using (public.has_perm('crm.admin'));

create policy "interactions: lecture"  on public.interactions for select to authenticated using (public.can_read_crm() or author_id = auth.uid());
create policy "interactions: création" on public.interactions for insert to authenticated
  with check (author_id = auth.uid() and (public.has_perm('crm.edit') or public.has_perm('crm.view')));
create policy "interactions: modification" on public.interactions for update to authenticated
  using (author_id = auth.uid() or public.has_perm('crm.admin')) with check (author_id = auth.uid() or public.has_perm('crm.admin'));
create policy "interactions: suppression" on public.interactions for delete to authenticated
  using (author_id = auth.uid() or public.has_perm('crm.admin'));

-- -----------------------------------------------------------------------------
-- Finance
-- -----------------------------------------------------------------------------
create or replace function public.can_read_finance()
returns boolean language sql stable security definer set search_path = public as $$
  select public.has_perm('finance.view') or public.has_perm('finance.admin') or public.has_perm('dashboard.exec')
$$;

create policy "budgets: lecture" on public.budgets for select to authenticated
  using (public.can_read_finance() or public.has_perm('unit.manage', unit_id));
create policy "budgets: gestion" on public.budgets for all to authenticated
  using (public.has_perm('finance.admin')) with check (public.has_perm('finance.admin'));

create policy "factures: lecture" on public.invoices for select to authenticated using (public.can_read_finance());
create policy "factures: gestion" on public.invoices for all to authenticated
  using (public.has_perm('finance.admin')) with check (public.has_perm('finance.admin'));

create policy "lignes facture: lecture" on public.invoice_lines for select to authenticated using (public.can_read_finance());
create policy "lignes facture: gestion" on public.invoice_lines for all to authenticated
  using (public.has_perm('finance.admin')) with check (public.has_perm('finance.admin'));

create policy "transactions: lecture" on public.transactions for select to authenticated
  using (public.can_read_finance() or public.has_perm('unit.manage', unit_id));
create policy "transactions: gestion" on public.transactions for all to authenticated
  using (public.has_perm('finance.admin')) with check (public.has_perm('finance.admin'));

-- -----------------------------------------------------------------------------
-- RH
-- -----------------------------------------------------------------------------
create policy "contrats: lecture" on public.employment_contracts for select to authenticated
  using (profile_id = auth.uid() or public.has_perm('hr.view') or public.has_perm('hr.admin'));
create policy "contrats: gestion" on public.employment_contracts for all to authenticated
  using (public.has_perm('hr.admin')) with check (public.has_perm('hr.admin'));

create policy "salaires: lecture" on public.salaries for select to authenticated
  using (profile_id = auth.uid() or public.has_perm('hr.admin') or public.has_perm('finance.admin'));
create policy "salaires: gestion" on public.salaries for all to authenticated
  using (public.has_perm('hr.admin') or public.has_perm('finance.admin'))
  with check (public.has_perm('hr.admin') or public.has_perm('finance.admin'));

create policy "congés: lecture" on public.leave_requests for select to authenticated
  using (profile_id = auth.uid() or public.has_perm('hr.view') or public.has_perm('hr.admin') or public.manages_profile(profile_id));
create policy "congés: demande" on public.leave_requests for insert to authenticated
  with check (profile_id = auth.uid() and status = 'pending' and public.is_active_user());
create policy "congés: mise à jour" on public.leave_requests for update to authenticated
  using (profile_id = auth.uid() or public.has_perm('hr.admin') or public.manages_profile(profile_id))
  with check (profile_id = auth.uid() or public.has_perm('hr.admin') or public.manages_profile(profile_id));
create policy "congés: suppression" on public.leave_requests for delete to authenticated
  using (profile_id = auth.uid() and status = 'pending');

create policy "parcours: lecture" on public.lifecycle_items for select to authenticated
  using (profile_id = auth.uid() or assignee_id = auth.uid() or public.has_perm('hr.view') or public.has_perm('hr.admin') or public.manages_profile(profile_id));
create policy "parcours: gestion" on public.lifecycle_items for insert to authenticated
  with check (public.has_perm('hr.admin') or public.manages_profile(profile_id));
create policy "parcours: avancement" on public.lifecycle_items for update to authenticated
  using (profile_id = auth.uid() or assignee_id = auth.uid() or public.has_perm('hr.admin') or public.manages_profile(profile_id))
  with check (profile_id = auth.uid() or assignee_id = auth.uid() or public.has_perm('hr.admin') or public.manages_profile(profile_id));
create policy "parcours: suppression" on public.lifecycle_items for delete to authenticated
  using (public.has_perm('hr.admin') or public.manages_profile(profile_id));

-- -----------------------------------------------------------------------------
-- Documents
-- -----------------------------------------------------------------------------
create policy "documents: lecture" on public.documents for select to authenticated
  using (owner_id = auth.uid() or public.can_read_document(id));
create policy "documents: dépôt" on public.documents for insert to authenticated
  with check (public.is_active_user() and owner_id = auth.uid());
create policy "documents: modification" on public.documents for update to authenticated
  using (owner_id = auth.uid() or public.has_perm('docs.confidential') or public.has_perm('unit.manage', unit_id))
  with check (owner_id = auth.uid() or public.has_perm('docs.confidential') or public.has_perm('unit.manage', unit_id));
create policy "documents: suppression" on public.documents for delete to authenticated
  using (owner_id = auth.uid() or public.has_perm('docs.confidential') or public.is_admin());

-- -----------------------------------------------------------------------------
-- Objectifs & pilotage
-- -----------------------------------------------------------------------------
create policy "objectifs: lecture" on public.objectives for select to authenticated
  using (public.is_active_user() and (level in ('company', 'unit') or owner_id = auth.uid()
         or public.manages_profile(owner_id) or public.has_perm('hr.admin')));
create policy "objectifs: création" on public.objectives for insert to authenticated
  with check (
    (level = 'company'    and public.has_perm('objectives.admin'))
    or (level = 'unit'    and (public.has_perm('unit.manage', unit_id) or public.has_perm('objectives.admin')))
    or (level = 'individual' and (owner_id = auth.uid() or public.manages_profile(owner_id)))
  );
create policy "objectifs: modification" on public.objectives for update to authenticated
  using (public.can_edit_objective(id))
  with check (
    (level = 'company'    and public.has_perm('objectives.admin'))
    or (level = 'unit'    and (public.has_perm('unit.manage', unit_id) or public.has_perm('objectives.admin')))
    or (level = 'individual' and (owner_id = auth.uid() or public.manages_profile(owner_id)))
  );
create policy "objectifs: suppression" on public.objectives for delete to authenticated using (public.can_edit_objective(id));

create policy "résultats clés: lecture" on public.key_results for select to authenticated
  using (exists (select 1 from public.objectives o where o.id = objective_id));
create policy "résultats clés: gestion" on public.key_results for all to authenticated
  using (public.can_edit_objective(objective_id)) with check (public.can_edit_objective(objective_id));

create policy "kpi: lecture" on public.kpi_definitions for select to authenticated using (public.is_active_user());
create policy "kpi: gestion" on public.kpi_definitions for all to authenticated
  using (public.has_perm('dashboard.exec') or public.has_perm('objectives.admin'))
  with check (public.has_perm('dashboard.exec') or public.has_perm('objectives.admin'));

create policy "métriques: lecture" on public.product_metrics for select to authenticated
  using (public.has_perm('dashboard.exec') or public.has_perm('metrics.manage'));
create policy "métriques: gestion" on public.product_metrics for all to authenticated
  using (public.has_perm('metrics.manage')) with check (public.has_perm('metrics.manage'));

create policy "incidents: lecture"  on public.incidents for select to authenticated using (public.is_active_user());
create policy "incidents: signalement" on public.incidents for insert to authenticated
  with check (public.is_active_user() and reported_by = auth.uid());
create policy "incidents: suivi" on public.incidents for update to authenticated
  using (public.has_perm('metrics.manage') or reported_by = auth.uid() or public.has_perm('unit.manage', unit_id))
  with check (public.has_perm('metrics.manage') or reported_by = auth.uid() or public.has_perm('unit.manage', unit_id));
create policy "incidents: suppression" on public.incidents for delete to authenticated using (public.has_perm('metrics.manage'));

-- -----------------------------------------------------------------------------
-- Réunions
-- -----------------------------------------------------------------------------
create policy "réunions: lecture" on public.meetings for select to authenticated
  using (organizer_id = auth.uid() or public.is_meeting_participant(id)
         or (unit_id is not null and public.in_unit(unit_id))
         or (project_id is not null and public.can_view_project(project_id)));
create policy "réunions: création" on public.meetings for insert to authenticated
  with check (public.is_active_user() and organizer_id = auth.uid());
create policy "réunions: modification" on public.meetings for update to authenticated
  using (organizer_id = auth.uid() or public.is_admin()) with check (organizer_id = auth.uid() or public.is_admin());
create policy "réunions: suppression" on public.meetings for delete to authenticated
  using (organizer_id = auth.uid() or public.is_admin());

create policy "participants: lecture" on public.meeting_attendees for select to authenticated
  using (profile_id = auth.uid() or exists (select 1 from public.meetings m where m.id = meeting_id));
create policy "participants: invitation" on public.meeting_attendees for insert to authenticated
  with check (exists (select 1 from public.meetings m where m.id = meeting_id and m.organizer_id = auth.uid()));
create policy "participants: réponse" on public.meeting_attendees for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "participants: retrait" on public.meeting_attendees for delete to authenticated
  using (exists (select 1 from public.meetings m where m.id = meeting_id and m.organizer_id = auth.uid()));

-- >>>>>>>>>> supabase/migrations/20260925000004_api.sql
-- =============================================================================
-- VERIION OS — Migration 4 : API (RPC), pilotage, recherche, stockage, temps réel
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Messagerie
-- -----------------------------------------------------------------------------
create or replace function public.open_direct_channel(p_other uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  k   text;
  cid uuid;
begin
  if not public.is_active_user() then raise exception 'Compte inactif' using errcode = '42501'; end if;
  if p_other = auth.uid() then raise exception 'Impossible d''ouvrir une conversation avec soi-même'; end if;
  if not exists (select 1 from public.profiles where id = p_other and status = 'active') then
    raise exception 'Destinataire introuvable';
  end if;
  k := least(auth.uid()::text, p_other::text) || ':' || greatest(auth.uid()::text, p_other::text);
  select id into cid from public.channels where dm_key = k;
  if cid is null then
    insert into public.channels (kind, name, is_private, dm_key, created_by)
    values ('direct', 'Conversation directe', true, k, auth.uid())
    returning id into cid;
    insert into public.channel_members (channel_id, profile_id, role)
    values (cid, auth.uid(), 'owner'), (cid, p_other, 'owner');
  end if;
  return cid;
end $$;

create or replace function public.my_channels()
returns table (
  id uuid, kind public.channel_kind, name text, description text, unit_id uuid, project_id uuid,
  is_private boolean, last_message_at timestamptz, unread int, is_member boolean,
  other_profile_id uuid, other_name text, other_avatar text, other_title text
) language sql stable security definer set search_path = public as $$
  select c.id, c.kind,
         case when c.kind = 'direct' then coalesce(o.full_name, 'Conversation') else c.name end,
         c.description, c.unit_id, c.project_id, c.is_private, c.last_message_at,
         -- Non-lus : seulement pour les canaux dont on est membre direct (pas via un droit de supervision)
         case when cm.profile_id is not null
                or (c.kind = 'unit' and public.in_unit(c.unit_id))
                or (c.kind = 'project' and public.project_role(c.project_id) is not null)
           then (select count(*)::int from public.messages m
                  where m.channel_id = c.id and m.deleted_at is null
                    and m.author_id is distinct from auth.uid()
                    and m.created_at > coalesce(cm.last_read_at, now() - interval '14 days'))
           else 0 end,
         cm.profile_id is not null,
         o.id, o.full_name, o.avatar_url, o.job_title
  from public.channels c
  left join public.channel_members cm on cm.channel_id = c.id and cm.profile_id = auth.uid()
  left join lateral (
    select p.* from public.channel_members x join public.profiles p on p.id = x.profile_id
    where c.kind = 'direct' and x.channel_id = c.id and x.profile_id <> auth.uid() limit 1
  ) o on true
  where c.archived_at is null and public.can_access_channel(c.id)
  order by c.last_message_at desc nulls last, c.name
$$;

create or replace function public.mark_channel_read(p_channel uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.can_access_channel(p_channel) then raise exception 'Accès refusé' using errcode = '42501'; end if;
  insert into public.channel_members (channel_id, profile_id, last_read_at)
  values (p_channel, auth.uid(), now())
  on conflict (channel_id, profile_id) do update set last_read_at = now();
end $$;

-- -----------------------------------------------------------------------------
-- Recherche globale (respecte RLS : security invoker)
-- -----------------------------------------------------------------------------
create or replace function public.global_search(q text)
returns table (kind text, id uuid, title text, subtitle text, link text)
language plpgsql stable security invoker set search_path = public as $$
declare
  pat text := '%' || replace(replace(replace(coalesce(trim(q), ''), '\', '\\'), '%', '\%'), '_', '\_') || '%';
begin
  if length(coalesce(trim(q), '')) < 2 then return; end if;
  return query
  (select 'person'::text, p.id, p.full_name, coalesce(p.job_title, p.email), '/annuaire/' || p.id
     from public.profiles p where p.status = 'active' and (p.full_name ilike pat or p.email ilike pat) limit 6)
  union all
  (select 'unit', u.id, u.name, initcap(u.kind::text), '/organisation/' || u.id
     from public.org_units u where u.archived_at is null and u.name ilike pat limit 4)
  union all
  (select 'project', pr.id, pr.name, pr.code, '/projets/' || pr.id
     from public.projects pr where pr.archived_at is null and (pr.name ilike pat or pr.code ilike pat) limit 5)
  union all
  (select 'task', t.id, t.title, coalesce(pr.name, 'Tâche personnelle'),
          case when t.project_id is null then '/taches' else '/projets/' || t.project_id || '?tache=' || t.id end
     from public.tasks t left join public.projects pr on pr.id = t.project_id
     where t.title ilike pat order by t.updated_at desc limit 6)
  union all
  (select 'account', a.id, a.name, initcap(a.type::text), '/crm/comptes/' || a.id
     from public.accounts a where a.name ilike pat limit 5)
  union all
  (select 'document', d.id, d.title, coalesce(d.file_name, d.category::text), '/documents?doc=' || d.id
     from public.documents d
     where d.search @@ websearch_to_tsquery('french', q) or d.title ilike pat
     order by ts_rank(d.search, websearch_to_tsquery('french', q)) desc limit 6);
end $$;

-- -----------------------------------------------------------------------------
-- Cycle de vie des employés
-- -----------------------------------------------------------------------------
create or replace function public.offboard_employee(p_profile uuid, p_date date default current_date)
returns void language plpgsql security definer set search_path = public as $$
declare v_manager uuid; v_name text;
begin
  if not public.has_perm('users.admin') then raise exception 'Permission refusée' using errcode = '42501'; end if;
  if p_profile = auth.uid() then raise exception 'Vous ne pouvez pas vous désactiver vous-même'; end if;
  select manager_id, full_name into v_manager, v_name from public.profiles where id = p_profile;

  update public.unit_memberships set end_date = greatest(start_date, p_date) where profile_id = p_profile and end_date is null;
  delete from public.role_grants where profile_id = p_profile and source = 'manual';
  update public.tasks set assignee_id = null where assignee_id = p_profile and status <> 'done';
  update public.profiles set status = 'offboarded' where id = p_profile;

  insert into public.lifecycle_items (profile_id, kind, title, position, due_date, assignee_id) values
    (p_profile, 'offboarding', 'Récupérer le matériel',                      1, p_date, v_manager),
    (p_profile, 'offboarding', 'Transférer les dossiers et documents',       2, p_date, v_manager),
    (p_profile, 'offboarding', 'Réattribuer les tâches ouvertes',            3, p_date, v_manager),
    (p_profile, 'offboarding', 'Solde de tout compte',                       4, p_date + 15, null),
    (p_profile, 'offboarding', 'Entretien de départ',                        5, p_date, v_manager);

  perform public.notify(v_manager, 'hr.offboarding', 'Départ de ' || coalesce(v_name, 'un collaborateur'),
    'Ses tâches ouvertes ont été désassignées. Checklist de départ créée.', '/rh?onglet=parcours');
end $$;

-- -----------------------------------------------------------------------------
-- Vue d'une unité (page département)
-- -----------------------------------------------------------------------------
create or replace function public.unit_overview(p_unit uuid, p_year int default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  y int := coalesce(p_year, extract(year from current_date)::int);
  can_budget boolean := public.can_read_finance() or public.has_perm('unit.manage', p_unit);
  res jsonb;
begin
  if not public.is_active_user() then raise exception 'Accès refusé' using errcode = '42501'; end if;

  with subtree as (select id from public.org_units where p_unit = any(path) and archived_at is null),
  members as (select distinct m.profile_id from public.unit_memberships m where m.end_date is null and m.unit_id in (select id from subtree)),
  proj as (select id from public.projects where unit_id in (select id from subtree) and archived_at is null)
  select jsonb_build_object(
    'headcount',        (select count(*) from members),
    'projects_active',  (select count(*) from public.projects where id in (select id from proj) and status = 'active'),
    'tasks_open',       (select count(*) from public.tasks where project_id in (select id from proj) and status <> 'done'),
    'tasks_overdue',    (select count(*) from public.tasks where project_id in (select id from proj) and status <> 'done' and due_date < current_date),
    'tasks_done_30d',   (select count(*) from public.tasks where project_id in (select id from proj) and completed_at > now() - interval '30 days'),
    'objectives',       (select count(*) from public.objectives where level = 'unit' and unit_id = p_unit),
    'objectives_progress', (select coalesce(round(avg(progress)), 0) from public.objectives_progress where level = 'unit' and unit_id = p_unit),
    'budget',           case when can_budget then (select coalesce(sum(amount), 0) from public.budgets where fiscal_year = y and unit_id in (select id from subtree)) end,
    'spent',            case when can_budget then (select coalesce(sum(amount), 0) from public.transactions
                                                   where type = 'expense' and extract(year from occurred_on) = y and unit_id in (select id from subtree)) end,
    'meetings_upcoming',(select count(*) from public.meetings where unit_id in (select id from subtree) and starts_at > now()),
    'documents',        (select count(*) from public.documents where unit_id in (select id from subtree))
  ) into res;
  return res;
end $$;

-- -----------------------------------------------------------------------------
-- Dashboard de direction
-- -----------------------------------------------------------------------------
create or replace function public.exec_dashboard(p_year int default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  y        int  := coalesce(p_year, extract(year from current_date)::int);
  last_day date := (select max(metric_date) from public.product_metrics);
  res      jsonb;
begin
  if not public.has_perm('dashboard.exec') then
    raise exception 'Permission refusée' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'year', y,
    'kpis', jsonb_build_object(
      'revenue_ytd',  (select coalesce(sum(amount), 0) from public.transactions where type = 'revenue' and extract(year from occurred_on) = y),
      'expense_ytd',  (select coalesce(sum(amount), 0) from public.transactions where type = 'expense' and extract(year from occurred_on) = y),
      'revenue_prev', (select coalesce(sum(amount), 0) from public.transactions where type = 'revenue' and extract(year from occurred_on) = y - 1
                        and occurred_on <= (current_date - interval '1 year')),
      'cash',         (select opening_cash from public.company_settings)
                      + (select coalesce(sum(case when type = 'revenue' then amount else -amount end), 0) from public.transactions),
      'active_users', (select coalesce(sum(active_users), 0) from public.product_metrics where metric_date = last_day and country = 'ALL'),
      'active_users_prev', (select coalesce(sum(active_users), 0) from public.product_metrics
                             where country = 'ALL' and metric_date = (select max(metric_date) from public.product_metrics where metric_date <= last_day - 30)),
      'new_users_30d', (select coalesce(sum(new_users), 0) from public.product_metrics where country = 'ALL' and metric_date > last_day - 30),
      'headcount',    (select count(*) from public.profiles where status = 'active'),
      'projects_active', (select count(*) from public.projects where status = 'active' and archived_at is null),
      'tasks_open',   (select count(*) from public.tasks where status <> 'done'),
      'tasks_overdue',(select count(*) from public.tasks where status <> 'done' and due_date < current_date),
      'pipeline_weighted', (select coalesce(sum(amount * probability / 100.0), 0) from public.opportunities where stage not in ('won', 'lost')),
      'pipeline_total',    (select coalesce(sum(amount), 0) from public.opportunities where stage not in ('won', 'lost')),
      'clients',      (select count(*) from public.accounts where type = 'client'),
      'partners',     (select count(*) from public.accounts where type = 'partner'),
      'open_incidents', (select count(*) from public.incidents where status <> 'resolved'),
      'receivables',  (select coalesce(sum(total), 0) from public.invoices where status in ('sent', 'overdue')),
      'overdue_invoices', (select coalesce(sum(total), 0) from public.invoices where status = 'overdue'),
      'pending_leaves', (select count(*) from public.leave_requests where status = 'pending')
    ),
    'monthly', (
      select jsonb_agg(jsonb_build_object(
        'month', m,
        'revenue', coalesce((select sum(amount) from public.transactions where type = 'revenue' and extract(year from occurred_on) = y and extract(month from occurred_on) = m), 0),
        'expense', coalesce((select sum(amount) from public.transactions where type = 'expense' and extract(year from occurred_on) = y and extract(month from occurred_on) = m), 0)
      ) order by m) from generate_series(1, 12) m
    ),
    'active_users_series', (
      select coalesce(jsonb_agg(jsonb_build_object('date', d, 'value', v) order by d), '[]'::jsonb) from (
        select metric_date d, sum(active_users) v from public.product_metrics
        where country = 'ALL' and metric_date > coalesce(last_day, current_date) - 90
        group by metric_date) s
    ),
    'revenue_by_product', (
      select coalesce(jsonb_agg(jsonb_build_object('label', k, 'value', v) order by v desc), '[]'::jsonb) from (
        select coalesce(product, 'Non affecté') k, sum(amount) v from public.transactions
        where type = 'revenue' and extract(year from occurred_on) = y group by 1) s
    ),
    'revenue_by_country', (
      select coalesce(jsonb_agg(jsonb_build_object('label', k, 'value', v) order by v desc), '[]'::jsonb) from (
        select coalesce(country, 'Non affecté') k, sum(amount) v from public.transactions
        where type = 'revenue' and extract(year from occurred_on) = y group by 1) s
    ),
    'pipeline', (
      select jsonb_agg(jsonb_build_object('stage', s, 'count', coalesce(c, 0), 'amount', coalesce(a, 0)) order by ord)
      from (select s, ord from unnest(enum_range(null::public.opportunity_stage)) with ordinality as e(s, ord)) st
      left join (select stage, count(*) c, sum(amount) a from public.opportunities group by stage) o on o.stage = st.s
    ),
    'departments', (
      select coalesce(jsonb_agg(d order by (d->>'sort')::int, d->>'name'), '[]'::jsonb) from (
        select jsonb_build_object(
          'id', u.id, 'name', u.name, 'color', u.color, 'sort', u.sort_order,
          'head', (select p.full_name from public.unit_memberships m join public.profiles p on p.id = m.profile_id
                   where m.unit_id = u.id and m.role = 'head' and m.end_date is null),
          'headcount', (select count(distinct m.profile_id) from public.unit_memberships m join public.org_units x on x.id = m.unit_id
                        where m.end_date is null and u.id = any(x.path)),
          'tasks_open', (select count(*) from public.tasks t join public.projects p on p.id = t.project_id join public.org_units x on x.id = p.unit_id
                         where t.status <> 'done' and u.id = any(x.path)),
          'tasks_overdue', (select count(*) from public.tasks t join public.projects p on p.id = t.project_id join public.org_units x on x.id = p.unit_id
                            where t.status <> 'done' and t.due_date < current_date and u.id = any(x.path)),
          'budget', (select coalesce(sum(b.amount), 0) from public.budgets b join public.org_units x on x.id = b.unit_id
                     where b.fiscal_year = y and u.id = any(x.path)),
          'spent', (select coalesce(sum(t.amount), 0) from public.transactions t join public.org_units x on x.id = t.unit_id
                    where t.type = 'expense' and extract(year from t.occurred_on) = y and u.id = any(x.path)),
          'objectives_progress', (select coalesce(round(avg(o.progress)), 0) from public.objectives_progress o join public.org_units x on x.id = o.unit_id
                                  where o.level = 'unit' and u.id = any(x.path))
        ) d
        from public.org_units u
        where u.depth = 1 and u.archived_at is null
      ) s
    ),
    'late_tasks', (
      select coalesce(jsonb_agg(x), '[]'::jsonb) from (
        select t.id, t.title, t.due_date, t.priority, t.project_id, p.name as project, a.full_name as assignee
        from public.tasks t left join public.projects p on p.id = t.project_id left join public.profiles a on a.id = t.assignee_id
        where t.status <> 'done' and t.due_date < current_date
        order by t.due_date, t.priority desc limit 8) x
    ),
    'incidents', (
      select coalesce(jsonb_agg(x), '[]'::jsonb) from (
        select id, title, severity, status, occurred_at, product from public.incidents
        where status <> 'resolved' order by
          case severity when 'critical' then 0 when 'high' then 1 when 'medium' then 2 else 3 end, occurred_at desc limit 6) x
    ),
    'company_objectives', (
      select coalesce(jsonb_agg(x), '[]'::jsonb) from (
        select id, title, progress, status, period from public.objectives_progress
        where level = 'company' order by created_at limit 6) x
    )
  ) into res;
  return res;
end $$;

-- -----------------------------------------------------------------------------
-- Stockage (Supabase Storage)
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit)
values ('documents', 'documents', false, 52428800),
       ('avatars',   'avatars',   true,  5242880)
on conflict (id) do nothing;

create policy "documents: lecture des fichiers" on storage.objects for select to authenticated
  using (bucket_id = 'documents' and (
    (storage.foldername(objects.name))[1] = auth.uid()::text
    or exists (select 1 from public.documents d where d.storage_path = objects.name and public.can_read_document(d.id))
  ));
create policy "documents: dépôt dans son dossier" on storage.objects for insert to authenticated
  with check (bucket_id = 'documents' and (storage.foldername(objects.name))[1] = auth.uid()::text and public.is_active_user());
create policy "documents: suppression" on storage.objects for delete to authenticated
  using (bucket_id = 'documents' and (
    (storage.foldername(objects.name))[1] = auth.uid()::text
    or public.has_perm('docs.confidential') or public.is_admin()
  ));

create policy "avatars: lecture" on storage.objects for select to authenticated using (bucket_id = 'avatars');
create policy "avatars: dépôt" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(objects.name))[1] = auth.uid()::text);
create policy "avatars: remplacement" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(objects.name))[1] = auth.uid()::text);
create policy "avatars: suppression" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(objects.name))[1] = auth.uid()::text);

-- -----------------------------------------------------------------------------
-- Temps réel
-- -----------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.messages, public.notifications, public.tasks;
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- Tâches planifiées (pg_cron, si disponible)
-- -----------------------------------------------------------------------------
do $$
begin
  create extension if not exists pg_cron;
  perform cron.schedule('veriion-overdue-invoices', '0 6 * * *', 'select public.mark_overdue_invoices()');
exception when others then
  raise notice 'pg_cron non disponible (%). Activez-le dans Database > Extensions puis relancez ce bloc.', sqlerrm;
end $$;

-- Privilèges des nouvelles fonctions
grant execute on function public.open_direct_channel(uuid)  to authenticated;
grant execute on function public.my_channels()              to authenticated;
grant execute on function public.mark_channel_read(uuid)    to authenticated;
grant execute on function public.global_search(text)        to authenticated;
grant execute on function public.offboard_employee(uuid, date) to authenticated;
grant execute on function public.unit_overview(uuid, int)   to authenticated;
grant execute on function public.exec_dashboard(int)        to authenticated;
grant select on public.objectives_progress to authenticated;

-- >>>>>>>>>> supabase/migrations/20260926000005_drive.sql
-- =============================================================================
-- VERIION OS — Migration 5 : Espace documentaire (« Drive »)
-- Dossiers et sous-dossiers par personne, unité, projet et entreprise ;
-- partages ; documents natifs éditables (texte, tableur, présentation) ;
-- historique des versions ; favoris ; récents ; corbeille.
-- =============================================================================

create type public.folder_space as enum ('personal', 'unit', 'project', 'company');
create type public.share_role   as enum ('viewer', 'editor', 'manager');
create type public.doc_kind     as enum ('file', 'doc', 'sheet', 'slides');

create or replace function public.share_rank(r public.share_role)
returns int language sql immutable as $$
  select case r when 'manager' then 3 when 'editor' then 2 else 1 end
$$;

create or replace function public.try_uuid(t text)
returns uuid language plpgsql immutable as $$
begin
  return t::uuid;
exception when others then
  return null;
end $$;

-- -----------------------------------------------------------------------------
-- Dossiers
-- -----------------------------------------------------------------------------
create table public.folders (
  id          uuid primary key default gen_random_uuid(),
  parent_id   uuid references public.folders(id) on delete cascade,
  space       public.folder_space not null,
  name        text not null check (length(trim(name)) between 1 and 120),
  owner_id    uuid references public.profiles(id) on delete cascade,     -- espace personnel
  unit_id     uuid references public.org_units(id) on delete cascade,    -- espace d'unité
  project_id  uuid references public.projects(id) on delete cascade,     -- espace de projet
  color       text,
  path        uuid[] not null default '{}',
  depth       int not null default 0,
  is_root     boolean not null default false,
  created_by  uuid references public.profiles(id) on delete set null default auth.uid(),
  deleted_at  timestamptz,
  deleted_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index folders_parent_idx on public.folders(parent_id) where deleted_at is null;
create index folders_path_idx   on public.folders using gin(path);
create unique index folders_unique_name on public.folders(parent_id, lower(name)) where deleted_at is null and parent_id is not null;
create unique index folders_personal_root on public.folders(owner_id)   where is_root and space = 'personal';
create unique index folders_unit_root     on public.folders(unit_id)    where is_root and space = 'unit';
create unique index folders_project_root  on public.folders(project_id) where is_root and space = 'project';
create unique index folders_company_root  on public.folders(space)      where is_root and space = 'company';
create trigger folders_updated_at before update on public.folders for each row execute function public.set_updated_at();

-- Un sous-dossier hérite de l'espace, du propriétaire, de l'unité et du projet de son parent.
create or replace function public.folders_compute()
returns trigger language plpgsql as $$
declare p public.folders;
begin
  if new.parent_id is null then
    if not new.is_root then raise exception 'Un dossier doit avoir un dossier parent'; end if;
    new.path := array[new.id];
    new.depth := 0;
  else
    select * into p from public.folders where id = new.parent_id;
    if p.id is null then raise exception 'Dossier parent introuvable'; end if;
    if new.id = any(p.path) then raise exception 'Impossible de déplacer un dossier dans lui-même'; end if;
    if p.deleted_at is not null then raise exception 'Le dossier de destination est dans la corbeille'; end if;
    new.is_root := false;
    new.space := p.space;
    new.owner_id := p.owner_id;
    new.unit_id := p.unit_id;
    new.project_id := p.project_id;
    new.path := p.path || new.id;
    new.depth := p.depth + 1;
    if new.depth > 12 then raise exception 'Arborescence trop profonde (12 niveaux maximum)'; end if;
  end if;
  return new;
end $$;
create trigger folders_compute_bi before insert on public.folders for each row execute function public.folders_compute();
create trigger folders_compute_bu before update of parent_id on public.folders for each row execute function public.folders_compute();

create or replace function public.folders_propagate()
returns trigger language plpgsql as $$
begin
  if new.path is distinct from old.path then
    update public.folders set parent_id = parent_id where parent_id = new.id;
  end if;
  return null;
end $$;
create trigger folders_propagate_au after update of parent_id on public.folders for each row execute function public.folders_propagate();

-- Changer un dossier d'espace (ex. d'un département vers un espace personnel) retire l'accès aux autres :
-- cela exige le droit de gestion sur le dossier d'origine.
create or replace function public.folders_move_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare src_root uuid; dst_root uuid;
begin
  if auth.uid() is null or new.parent_id is not distinct from old.parent_id then return new; end if;
  src_root := old.path[1];
  select path[1] into dst_root from public.folders where id = new.parent_id;
  if src_root is distinct from dst_root and public.folder_access(old.id) < 3 then
    raise exception 'Déplacer ce dossier vers un autre espace nécessite le droit de gestion' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger folders_move_guard_bu before update of parent_id on public.folders for each row execute function public.folders_move_guard();

-- -----------------------------------------------------------------------------
-- Partages (dossier ou document ; personne ou unité)
-- -----------------------------------------------------------------------------
create table public.shares (
  id           uuid primary key default gen_random_uuid(),
  folder_id    uuid references public.folders(id) on delete cascade,
  document_id  uuid references public.documents(id) on delete cascade,
  profile_id   uuid references public.profiles(id) on delete cascade,
  unit_id      uuid references public.org_units(id) on delete cascade,
  role         public.share_role not null default 'viewer',
  expires_at   timestamptz,
  created_by   uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at   timestamptz not null default now(),
  check (num_nonnulls(folder_id, document_id) = 1),
  check (num_nonnulls(profile_id, unit_id) = 1)
);
create unique index shares_unique on public.shares (coalesce(folder_id, document_id), coalesce(profile_id, unit_id));
create index shares_profile_idx on public.shares(profile_id);
create index shares_folder_idx  on public.shares(folder_id);
create index shares_doc_idx     on public.shares(document_id);

-- -----------------------------------------------------------------------------
-- Documents : extension pour les documents natifs et l'arborescence
-- -----------------------------------------------------------------------------
alter table public.documents
  add column folder_id   uuid references public.folders(id) on delete cascade,
  add column kind        public.doc_kind not null default 'file',
  add column content     jsonb,
  add column content_text text,
  add column revision    int not null default 1,
  add column updated_by  uuid references public.profiles(id) on delete set null,
  add column deleted_at  timestamptz,
  add column deleted_by  uuid references public.profiles(id) on delete set null;

-- La recherche plein texte couvre désormais le contenu des documents natifs.
drop index if exists public.documents_search_idx;
alter table public.documents drop column search;
alter table public.documents add column search tsvector generated always as (
  setweight(to_tsvector('french', coalesce(title, '')), 'A') ||
  setweight(to_tsvector('french', coalesce(description, '')), 'B') ||
  setweight(to_tsvector('simple', coalesce(file_name, '')), 'C') ||
  setweight(to_tsvector('french', left(coalesce(content_text, ''), 100000)), 'D')
) stored;
create index documents_search_idx on public.documents using gin(search);
create index documents_folder_idx on public.documents(folder_id) where deleted_at is null;
alter table public.documents alter column title set default 'Sans titre';

create table public.document_versions (
  id            uuid primary key default gen_random_uuid(),
  document_id   uuid not null references public.documents(id) on delete cascade,
  revision      int not null,
  title         text not null,
  content       jsonb,
  storage_path  text,
  file_name     text,
  mime_type     text,
  size_bytes    bigint,
  note          text,
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now()
);
create index document_versions_doc_idx on public.document_versions(document_id, created_at desc);

create table public.drive_favorites (
  profile_id   uuid not null references public.profiles(id) on delete cascade default auth.uid(),
  folder_id    uuid references public.folders(id) on delete cascade,
  document_id  uuid references public.documents(id) on delete cascade,
  created_at   timestamptz not null default now(),
  check (num_nonnulls(folder_id, document_id) = 1)
);
create unique index drive_favorites_unique on public.drive_favorites(profile_id, coalesce(folder_id, document_id));

create table public.document_recents (
  profile_id   uuid not null references public.profiles(id) on delete cascade default auth.uid(),
  document_id  uuid not null references public.documents(id) on delete cascade,
  opened_at    timestamptz not null default now(),
  primary key (profile_id, document_id)
);

-- -----------------------------------------------------------------------------
-- Résolution des droits
--   0 = aucun · 1 = lecture · 2 = modification · 3 = gestion (partage, suppression)
-- -----------------------------------------------------------------------------
create or replace function public.folder_access(p_folder uuid)
returns int language plpgsql stable security definer set search_path = public as $$
declare
  f public.folders;
  r int := 0;
  s int;
begin
  if p_folder is null or not public.is_active_user() then return 0; end if;
  select * into f from public.folders where id = p_folder;
  if f.id is null then return 0; end if;

  if f.space = 'personal' then
    -- L'espace personnel est privé, y compris vis-à-vis de la direction : seuls les partages l'ouvrent.
    if f.owner_id = auth.uid() then return 3; end if;
  elsif public.is_ceo() then
    return 3;
  elsif f.space = 'unit' then
    if public.has_perm('unit.manage', f.unit_id) then return 3; end if;
    if public.in_unit(f.unit_id) then r := 2; end if;
  elsif f.space = 'project' then
    if public.can_manage_project(f.project_id) then return 3; end if;
    if public.can_contribute_project(f.project_id) then r := 2;
    elsif public.can_view_project(f.project_id) then r := 1; end if;
  elsif f.space = 'company' then
    if public.has_perm('org.manage') then return 3; end if;
    r := 1;
  end if;

  select max(public.share_rank(sh.role)) into s
  from public.shares sh
  where sh.folder_id = any(f.path)
    and (sh.expires_at is null or sh.expires_at > now())
    and (sh.profile_id = auth.uid() or (sh.unit_id is not null and public.in_unit(sh.unit_id)));
  return greatest(r, coalesce(s, 0));
end $$;

create or replace function public.document_access(p_doc uuid)
returns int language plpgsql stable security definer set search_path = public as $$
declare
  d public.documents;
  r int := 0;
  direct int;
begin
  if p_doc is null or not public.is_active_user() then return 0; end if;
  select * into d from public.documents where id = p_doc;
  if d.id is null then return 0; end if;

  if d.owner_id = auth.uid() then return 3; end if;
  if d.folder_id is not null then r := public.folder_access(d.folder_id); end if;
  if d.account_id is not null and public.can_read_crm() then r := greatest(r, 1); end if;

  select max(public.share_rank(sh.role)) into direct
  from public.shares sh
  where sh.document_id = d.id
    and (sh.expires_at is null or sh.expires_at > now())
    and (sh.profile_id = auth.uid() or (sh.unit_id is not null and public.in_unit(sh.unit_id)));
  direct := coalesce(direct, 0);

  -- Niveaux de confidentialité appliqués par-dessus les droits du dossier
  if d.classification = 'restricted' and r < 2 then r := 0; end if;
  if d.classification = 'confidential' and r < 3 and not public.has_perm('docs.confidential') then r := 0; end if;
  if d.classification = 'confidential' and public.has_perm('docs.confidential') then r := greatest(r, 1); end if;

  return greatest(r, direct);
end $$;

-- Compatibilité : les politiques existantes (stockage) utilisent can_read_document.
create or replace function public.can_read_document(p_doc uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.document_access(p_doc) >= 1
$$;

-- -----------------------------------------------------------------------------
-- Racines automatiques : chaque personne, unité et projet a son espace
-- -----------------------------------------------------------------------------
create or replace function public.ensure_personal_root(p_profile uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare fid uuid;
begin
  select id into fid from public.folders where is_root and space = 'personal' and owner_id = p_profile;
  if fid is null then
    insert into public.folders (space, name, owner_id, is_root, created_by)
    values ('personal', 'Mon espace', p_profile, true, p_profile)
    returning id into fid;
  end if;
  return fid;
end $$;

create or replace function public.profiles_after_insert_drive()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.ensure_personal_root(new.id);
  return null;
end $$;
create trigger profiles_ai_drive after insert on public.profiles for each row execute function public.profiles_after_insert_drive();

create or replace function public.org_units_drive_sync()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' and new.kind <> 'company' then
    insert into public.folders (space, name, unit_id, is_root) values ('unit', new.name, new.id, true)
    on conflict do nothing;
  elsif tg_op = 'UPDATE' and new.name is distinct from old.name then
    update public.folders set name = new.name where is_root and space = 'unit' and unit_id = new.id;
  end if;
  return null;
end $$;
create trigger org_units_drive_aiu after insert or update of name on public.org_units for each row execute function public.org_units_drive_sync();

create or replace function public.projects_drive_sync()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into public.folders (space, name, project_id, is_root) values ('project', new.name, new.id, true)
    on conflict do nothing;
  elsif new.name is distinct from old.name then
    update public.folders set name = new.name where is_root and space = 'project' and project_id = new.id;
  end if;
  return null;
end $$;
create trigger projects_drive_aiu after insert or update of name on public.projects for each row execute function public.projects_drive_sync();

-- Même règle pour les documents déplacés d'un espace à un autre
create or replace function public.documents_move_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare src_root uuid; dst_root uuid;
begin
  if auth.uid() is null or new.folder_id is not distinct from old.folder_id or old.folder_id is null then return new; end if;
  select path[1] into src_root from public.folders where id = old.folder_id;
  select path[1] into dst_root from public.folders where id = new.folder_id;
  if src_root is distinct from dst_root and public.document_access(old.id) < 3 then
    raise exception 'Déplacer ce document vers un autre espace nécessite le droit de gestion' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger documents_move_guard_bu before update of folder_id on public.documents for each row execute function public.documents_move_guard();

-- Initialisation pour les données existantes
do $$
declare r record; root uuid;
begin
  insert into public.folders (space, name, is_root) values ('company', 'Entreprise', true) returning id into root;
  insert into public.folders (parent_id, space, name) values
    (root, 'company', 'Politiques internes'),
    (root, 'company', 'Procédures'),
    (root, 'company', 'Modèles'),
    (root, 'company', 'Présentations institutionnelles'),
    (root, 'company', 'Juridique & contrats');
  for r in select id from public.profiles loop perform public.ensure_personal_root(r.id); end loop;
  insert into public.folders (space, name, unit_id, is_root)
    select 'unit', u.name, u.id, true from public.org_units u where u.kind <> 'company' on conflict do nothing;
  insert into public.folders (space, name, project_id, is_root)
    select 'project', p.name, p.id, true from public.projects p on conflict do nothing;
  -- Les documents existants rejoignent l'espace de leur unité, de leur projet ou de leur auteur.
  update public.documents d set folder_id = coalesce(
    (select f.id from public.folders f where f.is_root and f.space = 'project' and f.project_id = d.project_id),
    (select f.id from public.folders f where f.is_root and f.space = 'unit' and f.unit_id = d.unit_id),
    (select f.id from public.folders f where f.is_root and f.space = 'personal' and f.owner_id = d.owner_id))
  where d.folder_id is null;
end $$;

-- -----------------------------------------------------------------------------
-- Opérations
-- -----------------------------------------------------------------------------

-- Enregistrement du contenu d'un document natif, avec contrôle de version (verrou optimiste)
-- et instantané automatique dans l'historique (au plus un toutes les 10 minutes, ou sur demande).
create or replace function public.save_document_content(
  p_doc uuid, p_content jsonb, p_text text, p_base_revision int default null, p_snapshot boolean default false, p_note text default null
) returns int language plpgsql security definer set search_path = public as $$
declare
  d public.documents;
begin
  if public.document_access(p_doc) < 2 then raise exception 'Vous ne pouvez pas modifier ce document' using errcode = '42501'; end if;
  select * into d from public.documents where id = p_doc for update;
  if d.deleted_at is not null then raise exception 'Ce document est dans la corbeille'; end if;
  if p_base_revision is not null and d.revision <> p_base_revision then
    raise exception 'Le document a été modifié par quelqu''un d''autre (révision %). Rechargez-le.', d.revision using errcode = '40001';
  end if;
  if d.content is not null and (p_snapshot or not exists (
       select 1 from public.document_versions v where v.document_id = p_doc and v.created_at > now() - interval '10 minutes')) then
    insert into public.document_versions (document_id, revision, title, content, note, created_by)
    values (p_doc, d.revision, d.title, d.content, p_note, coalesce(d.updated_by, d.owner_id));
  end if;
  update public.documents
     set content = p_content, content_text = left(coalesce(p_text, ''), 200000),
         revision = d.revision + 1, updated_by = auth.uid(), updated_at = now()
   where id = p_doc;
  return d.revision + 1;
end $$;

-- Nouvelle version d'un fichier : l'ancienne est conservée dans l'historique.
create or replace function public.replace_document_file(
  p_doc uuid, p_storage_path text, p_file_name text, p_mime text, p_size bigint, p_note text default null
) returns int language plpgsql security definer set search_path = public as $$
declare d public.documents;
begin
  if public.document_access(p_doc) < 2 then raise exception 'Vous ne pouvez pas modifier ce document' using errcode = '42501'; end if;
  select * into d from public.documents where id = p_doc for update;
  if d.storage_path is not null then
    insert into public.document_versions (document_id, revision, title, storage_path, file_name, mime_type, size_bytes, note, created_by)
    values (p_doc, d.revision, d.title, d.storage_path, d.file_name, d.mime_type, d.size_bytes, p_note, coalesce(d.updated_by, d.owner_id));
  end if;
  update public.documents set storage_path = p_storage_path, file_name = p_file_name, mime_type = p_mime, size_bytes = p_size,
         version = d.version + 1, revision = d.revision + 1, updated_by = auth.uid()
   where id = p_doc;
  return d.version + 1;
end $$;

create or replace function public.restore_document_version(p_version uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v public.document_versions; d public.documents;
begin
  select * into v from public.document_versions where id = p_version;
  if v.id is null then raise exception 'Version introuvable'; end if;
  if public.document_access(v.document_id) < 2 then raise exception 'Permission refusée' using errcode = '42501'; end if;
  select * into d from public.documents where id = v.document_id for update;
  insert into public.document_versions (document_id, revision, title, content, storage_path, file_name, mime_type, size_bytes, note, created_by)
  values (d.id, d.revision, d.title, d.content, d.storage_path, d.file_name, d.mime_type, d.size_bytes, 'Avant restauration', auth.uid());
  update public.documents set
    content = coalesce(v.content, d.content),
    storage_path = coalesce(v.storage_path, d.storage_path), file_name = coalesce(v.file_name, d.file_name),
    mime_type = coalesce(v.mime_type, d.mime_type), size_bytes = coalesce(v.size_bytes, d.size_bytes),
    revision = d.revision + 1, updated_by = auth.uid()
  where id = d.id;
end $$;

-- Corbeille : un dossier supprimé emporte son contenu ; la restauration le ramène à l'identique.
create or replace function public.trash_item(p_folder uuid default null, p_doc uuid default null)
returns void language plpgsql security definer set search_path = public as $$
declare f public.folders; ts timestamptz := now();
begin
  if p_folder is not null then
    select * into f from public.folders where id = p_folder;
    if f.is_root then raise exception 'L''espace racine ne peut pas être supprimé'; end if;
    if public.folder_access(p_folder) < 2 then raise exception 'Permission refusée' using errcode = '42501'; end if;
    update public.folders set deleted_at = ts, deleted_by = auth.uid() where p_folder = any(path) and deleted_at is null;
    update public.documents set deleted_at = ts, deleted_by = auth.uid()
     where deleted_at is null and folder_id in (select id from public.folders where p_folder = any(path));
  elsif p_doc is not null then
    if public.document_access(p_doc) < 2 then raise exception 'Permission refusée' using errcode = '42501'; end if;
    update public.documents set deleted_at = ts, deleted_by = auth.uid() where id = p_doc;
  end if;
end $$;

create or replace function public.restore_item(p_folder uuid default null, p_doc uuid default null)
returns void language plpgsql security definer set search_path = public as $$
declare f public.folders; d public.documents;
begin
  if p_folder is not null then
    select * into f from public.folders where id = p_folder;
    if f.deleted_at is null then return; end if;
    if public.folder_access(p_folder) < 2 then raise exception 'Permission refusée' using errcode = '42501'; end if;
    if exists (select 1 from public.folders pf where pf.id = f.parent_id and pf.deleted_at is not null) then
      raise exception 'Restaurez d''abord le dossier parent';
    end if;
    update public.documents set deleted_at = null, deleted_by = null
     where deleted_at = f.deleted_at and folder_id in (select id from public.folders where p_folder = any(path));
    update public.folders set deleted_at = null, deleted_by = null where p_folder = any(path) and deleted_at = f.deleted_at;
  elsif p_doc is not null then
    select * into d from public.documents where id = p_doc;
    if public.document_access(p_doc) < 2 then raise exception 'Permission refusée' using errcode = '42501'; end if;
    if exists (select 1 from public.folders pf where pf.id = d.folder_id and pf.deleted_at is not null) then
      raise exception 'Le dossier de ce document est dans la corbeille : restaurez-le d''abord';
    end if;
    update public.documents set deleted_at = null, deleted_by = null where id = p_doc;
  end if;
end $$;

create or replace function public.purge_trash()
returns int language plpgsql security definer set search_path = public as $$
declare n int;
begin
  with d as (delete from public.documents where deleted_at < now() - interval '30 days' returning 1) select count(*) into n from d;
  delete from public.folders where deleted_at < now() - interval '30 days';
  return n;
end $$;

create or replace function public.duplicate_document(p_doc uuid, p_folder uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare d public.documents; nid uuid; target uuid;
begin
  if public.document_access(p_doc) < 1 then raise exception 'Permission refusée' using errcode = '42501'; end if;
  select * into d from public.documents where id = p_doc;
  target := coalesce(p_folder, d.folder_id);
  if public.folder_access(target) < 2 then target := public.ensure_personal_root(auth.uid()); end if;
  insert into public.documents (title, description, category, classification, folder_id, kind, content, content_text, owner_id, tags,
                                storage_path, file_name, mime_type, size_bytes)
  values ('Copie de ' || d.title, d.description, d.category,
          case when d.classification = 'confidential' then 'confidential' else d.classification end,
          target, d.kind, d.content, d.content_text, auth.uid(), d.tags,
          null, d.file_name, d.mime_type, d.size_bytes)
  returning id into nid;
  return nid;
end $$;

-- Contenu d'un dossier avec les droits de l'utilisateur (une seule requête pour l'explorateur)
create or replace function public.drive_listing(p_folder uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare lvl int := public.folder_access(p_folder);
begin
  if lvl < 1 then raise exception 'Accès refusé à ce dossier' using errcode = '42501'; end if;
  return jsonb_build_object(
    'access', lvl,
    'folder', (select to_jsonb(f) from public.folders f where f.id = p_folder),
    'breadcrumb', (select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'name', a.name) order by a.depth), '[]'::jsonb)
                    from public.folders f join public.folders a on a.id = any(f.path)
                    where f.id = p_folder and public.folder_access(a.id) >= 1),
    'folders', (select coalesce(jsonb_agg(x order by lower(x->>'name')), '[]'::jsonb) from (
                  select to_jsonb(c) || jsonb_build_object(
                    'access', public.folder_access(c.id),
                    'items', (select count(*) from public.documents dd where dd.folder_id = c.id and dd.deleted_at is null)
                           + (select count(*) from public.folders ff where ff.parent_id = c.id and ff.deleted_at is null),
                    'shared', exists (select 1 from public.shares s where s.folder_id = c.id)) as x
                  from public.folders c where c.parent_id = p_folder and c.deleted_at is null and public.folder_access(c.id) >= 1) q),
    'documents', (select coalesce(jsonb_agg(x order by x->>'updated_at' desc), '[]'::jsonb) from (
                  select (to_jsonb(d) - 'content' - 'content_text' - 'search') || jsonb_build_object(
                    'access', public.document_access(d.id),
                    'shared', exists (select 1 from public.shares s where s.document_id = d.id)) as x
                  from public.documents d where d.folder_id = p_folder and d.deleted_at is null and public.document_access(d.id) >= 1) q),
    'shares', (select coalesce(jsonb_agg(to_jsonb(s)), '[]'::jsonb) from public.shares s where s.folder_id = p_folder)
  );
end $$;

-- Espaces accessibles à l'utilisateur
create or replace function public.my_drive_spaces()
returns table (id uuid, space public.folder_space, name text, unit_id uuid, project_id uuid, access int, color text)
language sql stable security definer set search_path = public as $$
  select f.id, f.space,
         case f.space when 'personal' then 'Mon espace' else f.name end,
         f.unit_id, f.project_id, public.folder_access(f.id),
         coalesce(u.color, p.color, f.color)
  from public.folders f
  left join public.org_units u on u.id = f.unit_id
  left join public.projects p on p.id = f.project_id
  where f.is_root and f.deleted_at is null
    and (f.space <> 'personal' or f.owner_id = auth.uid())
    and (f.space <> 'project' or p.archived_at is null)
    and (f.space <> 'unit' or u.archived_at is null)
    and public.folder_access(f.id) >= 1
  order by case f.space when 'personal' then 0 when 'company' then 1 when 'unit' then 2 else 3 end, u.depth nulls first, f.name
$$;

-- Dossiers dans lesquels l'utilisateur peut écrire (destinations de déplacement / création)
create or replace function public.drive_tree()
returns table (id uuid, parent_id uuid, name text, space public.folder_space, depth int, is_root boolean, access int)
language sql stable security definer set search_path = public as $$
  select f.id, f.parent_id, case when f.is_root and f.space = 'personal' then 'Mon espace' else f.name end,
         f.space, f.depth, f.is_root, public.folder_access(f.id)
  from public.folders f
  where f.deleted_at is null
    and (f.space <> 'personal' or f.owner_id = auth.uid() or exists (select 1 from public.shares s where s.folder_id = any(f.path)))
    and public.folder_access(f.id) >= 2
  order by f.depth, lower(f.name)
$$;

-- Éléments partagés directement avec moi (ou avec une de mes unités)
create or replace function public.shared_with_me()
returns table (kind text, id uuid, name text, doc_kind public.doc_kind, role public.share_role, shared_by uuid, shared_at timestamptz, mime_type text)
language sql stable security definer set search_path = public as $$
  select 'folder', f.id, f.name, null::public.doc_kind, s.role, s.created_by, s.created_at, null
  from public.shares s join public.folders f on f.id = s.folder_id
  where (s.profile_id = auth.uid() or (s.unit_id is not null and public.in_unit(s.unit_id)))
    and f.deleted_at is null and (s.expires_at is null or s.expires_at > now())
    and f.owner_id is distinct from auth.uid()
  union all
  select 'document', d.id, d.title, d.kind, s.role, s.created_by, s.created_at, d.mime_type
  from public.shares s join public.documents d on d.id = s.document_id
  where (s.profile_id = auth.uid() or (s.unit_id is not null and public.in_unit(s.unit_id)))
    and d.deleted_at is null and (s.expires_at is null or s.expires_at > now())
    and d.owner_id is distinct from auth.uid()
  order by 7 desc
$$;

-- Notification lors d'un partage nominatif
create or replace function public.shares_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare label text; link text; who text;
begin
  if new.profile_id is null then return null; end if;
  select full_name into who from public.profiles where id = new.created_by;
  if new.folder_id is not null then
    select name into label from public.folders where id = new.folder_id;
    link := '/documents?dossier=' || new.folder_id;
  else
    select title into label from public.documents where id = new.document_id;
    link := '/documents/d/' || new.document_id;
  end if;
  perform public.notify(new.profile_id, 'drive.shared', coalesce(who, 'Un collègue') || ' a partagé « ' || label || ' »',
    case new.role when 'viewer' then 'Accès en lecture' when 'editor' then 'Accès en modification' else 'Accès en gestion' end, link);
  return null;
end $$;
create trigger shares_ai after insert on public.shares for each row execute function public.shares_after_insert();

-- L'audit ignore le contenu des documents (l'historique des versions en garde la trace)
create or replace function public.audit_trigger()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  o jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) - 'search' - 'content' - 'content_text' end;
  n jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) - 'search' - 'content' - 'content_text' end;
  changed text[];
  redact boolean := coalesce(tg_argv[0], '') = 'redact';
begin
  if tg_op = 'UPDATE' then
    select array_agg(k) into changed
    from jsonb_object_keys(n) k
    where k not in ('updated_at', 'revision', 'updated_by', 'last_seen_at') and n->k is distinct from o->k;
    if changed is null then return null; end if;
  end if;
  insert into public.audit_log (actor_id, action, table_name, record_id, old_data, new_data, changed_fields)
  values (
    auth.uid(), lower(tg_op), tg_table_name,
    coalesce(n->>'id', o->>'id', n->>'profile_id', o->>'profile_id'),
    case when redact then null else o end,
    case when redact then null else n end,
    changed
  );
  return null;
end $$;
create trigger audit_folders after insert or update or delete on public.folders for each row execute function public.audit_trigger();
create trigger audit_shares  after insert or update or delete on public.shares  for each row execute function public.audit_trigger();

-- -----------------------------------------------------------------------------
-- Sécurité
-- -----------------------------------------------------------------------------
alter table public.folders           enable row level security;
alter table public.shares            enable row level security;
alter table public.document_versions enable row level security;
alter table public.drive_favorites   enable row level security;
alter table public.document_recents  enable row level security;

grant select, insert, update, delete on public.folders, public.shares, public.document_versions, public.drive_favorites, public.document_recents to authenticated;

create policy "dossiers: lecture" on public.folders for select to authenticated
  using (public.folder_access(id) >= 1 or (parent_id is not null and public.folder_access(parent_id) >= 1));
create policy "dossiers: création" on public.folders for insert to authenticated
  with check (parent_id is not null and public.folder_access(parent_id) >= 2 and not is_root);
create policy "dossiers: modification" on public.folders for update to authenticated
  using (public.folder_access(id) >= 2 and not is_root)
  with check (not is_root and parent_id is not null and public.folder_access(parent_id) >= 2);
create policy "dossiers: suppression" on public.folders for delete to authenticated
  using (public.folder_access(id) = 3 and not is_root);

drop policy "documents: lecture"      on public.documents;
drop policy "documents: dépôt"        on public.documents;
drop policy "documents: modification" on public.documents;
drop policy "documents: suppression"  on public.documents;
create policy "documents: lecture" on public.documents for select to authenticated
  using (owner_id = auth.uid() or public.document_access(id) >= 1);
create policy "documents: création" on public.documents for insert to authenticated
  with check (public.is_active_user() and owner_id = auth.uid() and (folder_id is null or public.folder_access(folder_id) >= 2));
create policy "documents: modification" on public.documents for update to authenticated
  using (public.document_access(id) >= 2)
  with check (folder_id is null or public.folder_access(folder_id) >= 2 or public.document_access(id) >= 2);
create policy "documents: suppression" on public.documents for delete to authenticated
  using (public.document_access(id) = 3);

create policy "partages: lecture" on public.shares for select to authenticated
  using (profile_id = auth.uid() or (unit_id is not null and public.in_unit(unit_id))
         or public.folder_access(folder_id) >= 2 or public.document_access(document_id) >= 2);
create policy "partages: création" on public.shares for insert to authenticated
  with check (created_by = auth.uid() and (
    public.share_rank(role) <= coalesce(public.folder_access(folder_id), 0) and public.folder_access(folder_id) >= 2
    or public.share_rank(role) <= coalesce(public.document_access(document_id), 0) and public.document_access(document_id) >= 2));
create policy "partages: modification" on public.shares for update to authenticated
  using (public.folder_access(folder_id) = 3 or public.document_access(document_id) = 3)
  with check (public.folder_access(folder_id) = 3 or public.document_access(document_id) = 3);
create policy "partages: retrait" on public.shares for delete to authenticated
  using (created_by = auth.uid() or public.folder_access(folder_id) = 3 or public.document_access(document_id) = 3);

create policy "versions: lecture" on public.document_versions for select to authenticated
  using (public.document_access(document_id) >= 1);

create policy "favoris: les miens" on public.drive_favorites for all to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "récents: les miens" on public.document_recents for all to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid() and public.document_access(document_id) >= 1);

-- Stockage : images insérées dans les documents natifs (chemin = <document_id>/<fichier>)
insert into storage.buckets (id, name, public, file_size_limit)
values ('doc-assets', 'doc-assets', false, 10485760)
on conflict (id) do nothing;

create policy "doc-assets: lecture" on storage.objects for select to authenticated
  using (bucket_id = 'doc-assets' and public.document_access(public.try_uuid((storage.foldername(objects.name))[1])) >= 1);
create policy "doc-assets: dépôt" on storage.objects for insert to authenticated
  with check (bucket_id = 'doc-assets' and public.document_access(public.try_uuid((storage.foldername(objects.name))[1])) >= 2);

-- Stockage : anciennes versions des fichiers
create policy "documents: lecture des versions" on storage.objects for select to authenticated
  using (bucket_id = 'documents' and exists (
    select 1 from public.document_versions v where v.storage_path = objects.name and public.document_access(v.document_id) >= 1));

grant execute on function public.folder_access(uuid), public.document_access(uuid), public.drive_listing(uuid),
  public.my_drive_spaces(), public.shared_with_me(), public.drive_tree(), public.save_document_content(uuid, jsonb, text, int, boolean, text),
  public.replace_document_file(uuid, text, text, text, bigint, text), public.restore_document_version(uuid),
  public.trash_item(uuid, uuid), public.restore_item(uuid, uuid), public.duplicate_document(uuid, uuid) to authenticated;
revoke execute on function public.purge_trash() from public, anon, authenticated;
revoke execute on function public.ensure_personal_root(uuid) from public, anon, authenticated;

do $$
begin
  perform cron.schedule('veriion-purge-trash', '30 3 * * *', 'select public.purge_trash()');
exception when others then
  raise notice 'pg_cron non disponible : la corbeille ne sera pas vidée automatiquement (%).', sqlerrm;
end $$;

-- >>>>>>>>>> supabase/migrations/20260926000006_messaging.sql
-- =============================================================================
-- VERIION OS — Migration 6 : Messagerie complète
-- Pièces jointes, fils de discussion, mentions, réactions, messages épinglés,
-- recherche, appels, notifications des messages directs.
-- =============================================================================

alter table public.messages
  add column kind          text not null default 'text' check (kind in ('text', 'call', 'system')),
  add column mentions      uuid[] not null default '{}',
  add column reply_count   int not null default 0,
  add column last_reply_at timestamptz,
  add column pinned_at     timestamptz,
  add column pinned_by     uuid references public.profiles(id) on delete set null;

alter table public.messages drop constraint if exists messages_body_check;
alter table public.messages add constraint messages_body_check
  check (length(body) <= 8000 and (length(body) >= 1 or jsonb_array_length(attachments) > 0));
alter table public.messages alter column body set default '';

create index messages_parent_idx on public.messages(parent_id, created_at) where parent_id is not null;
create index messages_pinned_idx on public.messages(channel_id) where pinned_at is not null;
create index messages_body_fts on public.messages using gin (to_tsvector('simple', body));

create table public.message_reactions (
  message_id  uuid not null references public.messages(id) on delete cascade,
  channel_id  uuid not null references public.channels(id) on delete cascade,
  profile_id  uuid not null references public.profiles(id) on delete cascade default auth.uid(),
  emoji       text not null check (length(emoji) between 1 and 16),
  created_at  timestamptz not null default now(),
  primary key (message_id, profile_id, emoji)
);
create index message_reactions_channel_idx on public.message_reactions(channel_id);

-- Une personne donnée peut-elle lire ce canal ? (pour filtrer les notifications de mention)
create or replace function public.profile_in_channel(p_profile uuid, p_channel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.channels c
    where c.id = p_channel and (
      exists (select 1 from public.channel_members cm where cm.channel_id = c.id and cm.profile_id = p_profile)
      or (c.kind = 'group' and not c.is_private)
      or (c.kind = 'unit' and exists (select 1 from public.unit_memberships m join public.org_units u on u.id = m.unit_id
                                      where m.profile_id = p_profile and m.end_date is null and c.unit_id = any(u.path)))
      or (c.kind = 'project' and exists (select 1 from public.project_members pm where pm.project_id = c.project_id and pm.profile_id = p_profile))
      or exists (select 1 from public.profiles p where p.id = p_profile and p.system_role = 'ceo'))
  )
$$;

-- Mentions : syntaxe @[Nom](uuid) dans le corps du message
create or replace function public.messages_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare parent public.messages;
begin
  select coalesce(array_agg(distinct public.try_uuid(m[1])) filter (where public.try_uuid(m[1]) is not null), '{}')
    into new.mentions
  from regexp_matches(coalesce(new.body, ''), '@\[[^\]]{1,80}\]\(([0-9a-fA-F-]{36})\)', 'g') as m;
  if new.parent_id is not null then
    select * into parent from public.messages where id = new.parent_id;
    if parent.id is null or parent.channel_id <> new.channel_id then raise exception 'Fil de discussion invalide'; end if;
    if parent.parent_id is not null then new.parent_id := parent.parent_id; end if;  -- un seul niveau de fil
  end if;
  return new;
end $$;
create trigger messages_bi before insert on public.messages for each row execute function public.messages_before_insert();

create or replace function public.messages_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  ch public.channels;
  author text;
  target uuid;
  preview text := left(regexp_replace(coalesce(new.body, ''), '@\[([^\]]+)\]\([0-9a-fA-F-]{36}\)', '@\1', 'g'), 140);
  link text := '/messages/' || new.channel_id;
begin
  select * into ch from public.channels where id = new.channel_id;
  select full_name into author from public.profiles where id = new.author_id;
  if preview = '' and jsonb_array_length(new.attachments) > 0 then preview := '📎 Pièce jointe'; end if;

  if new.parent_id is null then
    update public.channels set last_message_at = new.created_at where id = new.channel_id;
  else
    update public.messages set reply_count = reply_count + 1, last_reply_at = new.created_at where id = new.parent_id;
    link := link || '?fil=' || new.parent_id;
    -- L'auteur du message d'origine et les participants du fil sont notifiés
    for target in
      select distinct x from (
        select author_id as x from public.messages where id = new.parent_id
        union select author_id from public.messages where parent_id = new.parent_id
      ) t where x is not null and x <> coalesce(new.author_id, '00000000-0000-0000-0000-000000000000'::uuid)
    loop
      perform public.notify(target, 'message.thread', coalesce(author, 'Quelqu''un') || ' a répondu dans un fil', preview, link);
    end loop;
  end if;

  if new.author_id is not null then
    insert into public.channel_members (channel_id, profile_id, last_read_at)
    values (new.channel_id, new.author_id, new.created_at)
    on conflict (channel_id, profile_id) do update set last_read_at = excluded.last_read_at;
  end if;

  -- Mentions
  foreach target in array new.mentions loop
    if target <> coalesce(new.author_id, '00000000-0000-0000-0000-000000000000'::uuid) and public.profile_in_channel(target, new.channel_id) then
      perform public.notify(target, 'message.mention', coalesce(author, 'Quelqu''un') || ' vous a mentionné'
        || case when ch.kind = 'direct' then '' else ' dans #' || ch.name end, preview, link);
    end if;
  end loop;

  -- Messages directs : une notification par conversation tant qu'elle n'a pas été lue
  if ch.kind = 'direct' and new.parent_id is null then
    for target in select profile_id from public.channel_members where channel_id = ch.id and profile_id <> new.author_id loop
      if not exists (select 1 from public.notifications n where n.profile_id = target and n.kind = 'message.direct'
                       and n.link = '/messages/' || ch.id and n.read_at is null) and not (target = any(new.mentions)) then
        perform public.notify(target, 'message.direct', 'Nouveau message de ' || coalesce(author, 'un collègue'), preview, '/messages/' || ch.id);
      end if;
    end loop;
  end if;
  return null;
end $$;

create or replace function public.message_reactions_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  select channel_id into new.channel_id from public.messages where id = new.message_id;
  return new;
end $$;
create trigger message_reactions_bi before insert on public.message_reactions for each row execute function public.message_reactions_before_insert();

-- Épingler / désépingler (tout participant du canal)
create or replace function public.toggle_pin(p_message uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare m public.messages;
begin
  select * into m from public.messages where id = p_message;
  if m.id is null or not public.can_access_channel(m.channel_id) then raise exception 'Accès refusé' using errcode = '42501'; end if;
  update public.messages set pinned_at = case when pinned_at is null then now() end,
                             pinned_by = case when pinned_at is null then auth.uid() end
   where id = p_message;
  return m.pinned_at is null;
end $$;

-- Lancer un appel vidéo dans une conversation : publie un message « appel » avec le lien de la salle
create or replace function public.start_call(p_channel uuid, p_url text)
returns uuid language plpgsql security definer set search_path = public as $$
declare mid uuid;
begin
  if not public.can_access_channel(p_channel) then raise exception 'Accès refusé' using errcode = '42501'; end if;
  if p_url !~ '^https://' then raise exception 'Lien d''appel invalide'; end if;
  insert into public.messages (channel_id, author_id, kind, body, attachments)
  values (p_channel, auth.uid(), 'call', 'a lancé un appel vidéo', jsonb_build_array(jsonb_build_object('type', 'call', 'url', p_url)))
  returning id into mid;
  return mid;
end $$;

-- Recherche dans les conversations accessibles
create or replace function public.search_messages(q text, p_channel uuid default null)
returns table (id uuid, channel_id uuid, channel_name text, channel_kind public.channel_kind, author_id uuid, body text, created_at timestamptz, parent_id uuid)
language plpgsql stable security invoker set search_path = public as $$
declare pat text := '%' || replace(replace(replace(coalesce(trim(q), ''), '\', '\\'), '%', '\%'), '_', '\_') || '%';
begin
  if length(coalesce(trim(q), '')) < 2 then return; end if;
  return query
  select m.id, m.channel_id, c.name, c.kind, m.author_id, m.body, m.created_at, m.parent_id
  from public.messages m join public.channels c on c.id = m.channel_id
  where m.deleted_at is null and m.kind = 'text' and m.body ilike pat
    and (p_channel is null or m.channel_id = p_channel)
  order by m.created_at desc limit 40;
end $$;

-- Membres d'un canal (pour les mentions et le panneau « membres »)
create or replace function public.channel_people(p_channel uuid)
returns table (id uuid, full_name text, avatar_url text, job_title text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare c public.channels;
begin
  if not public.can_access_channel(p_channel) then raise exception 'Accès refusé' using errcode = '42501'; end if;
  select * into c from public.channels where id = p_channel;
  return query
  select p.id, p.full_name, p.avatar_url, p.job_title from public.profiles p
  where p.status = 'active' and (
    exists (select 1 from public.channel_members cm where cm.channel_id = c.id and cm.profile_id = p.id)
    or (c.kind = 'group' and not c.is_private)
    or (c.kind = 'unit' and exists (select 1 from public.unit_memberships m join public.org_units u on u.id = m.unit_id
                                    where m.profile_id = p.id and m.end_date is null and c.unit_id = any(u.path)))
    or (c.kind = 'project' and exists (select 1 from public.project_members pm where pm.project_id = c.project_id and pm.profile_id = p.id)))
  order by p.first_name;
end $$;

-- -----------------------------------------------------------------------------
-- Sécurité
-- -----------------------------------------------------------------------------
alter table public.message_reactions enable row level security;
grant select, insert, delete on public.message_reactions to authenticated;

create policy "réactions: lecture" on public.message_reactions for select to authenticated using (public.can_access_channel(channel_id));
create policy "réactions: ajout" on public.message_reactions for insert to authenticated
  with check (profile_id = auth.uid() and exists (select 1 from public.messages m where m.id = message_id and public.can_access_channel(m.channel_id)));
create policy "réactions: retrait" on public.message_reactions for delete to authenticated using (profile_id = auth.uid());

-- Pièces jointes de la messagerie : chemin = <channel_id>/<fichier>
insert into storage.buckets (id, name, public, file_size_limit)
values ('chat', 'chat', false, 26214400)
on conflict (id) do nothing;

create policy "chat: lecture" on storage.objects for select to authenticated
  using (bucket_id = 'chat' and public.can_access_channel(public.try_uuid((storage.foldername(objects.name))[1])));
create policy "chat: dépôt" on storage.objects for insert to authenticated
  with check (bucket_id = 'chat' and public.can_access_channel(public.try_uuid((storage.foldername(objects.name))[1])));

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.message_reactions;
  end if;
end $$;

grant execute on function public.toggle_pin(uuid), public.start_call(uuid, text), public.search_messages(text, uuid), public.channel_people(uuid) to authenticated;

revoke execute on function public.profile_in_channel(uuid, uuid) from public, anon, authenticated;

-- >>>>>>>>>> supabase/migrations/20260927000007_collab_notifications.sql
-- =============================================================================
-- VERIION OS — Migration 7 : co-édition simultanée et notifications hors plateforme
-- =============================================================================
--   * Co-édition : l'état Yjs du document (fusion des modifications simultanées)
--     est conservé à côté du contenu JSON, qui reste la référence pour la
--     recherche, les exports et l'historique.
--   * Notifications : préférences par personne et par catégorie, e-mails
--     (immédiats ou résumé quotidien), notifications push sur téléphone et
--     ordinateur, rappels automatiques (échéances, retards, validations,
--     congés à traiter, réunions imminentes).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Co-édition
-- -----------------------------------------------------------------------------
-- État Yjs du document (fusion des modifications simultanées), séparé de la table
-- documents pour ne pas alourdir les listes, la recherche ni le journal d'audit.
create table public.document_ydocs (
  document_id  uuid primary key references public.documents(id) on delete cascade,
  state        text not null,                 -- mise à jour Yjs complète, encodée en base64
  revision     int not null,                  -- révision du document à laquelle l'état correspond
  updated_at   timestamptz not null default now()
);
alter table public.document_ydocs enable row level security;
grant select on public.document_ydocs to authenticated;
create policy "ydoc: lecture" on public.document_ydocs for select to authenticated
  using (public.document_access(document_id) >= 1);

-- Enregistrement : l'état Yjs accompagne le contenu. Un enregistrement sans état
-- Yjs (import, ancien client) le remet à zéro : il sera reconstruit depuis le JSON.
drop function if exists public.save_document_content(uuid, jsonb, text, int, boolean, text);
create or replace function public.save_document_content(
  p_doc uuid, p_content jsonb, p_text text, p_base_revision int default null,
  p_snapshot boolean default false, p_note text default null, p_ydoc text default null
) returns int language plpgsql security definer set search_path = public as $$
declare
  d public.documents;
begin
  if public.document_access(p_doc) < 2 then raise exception 'Vous ne pouvez pas modifier ce document' using errcode = '42501'; end if;
  select * into d from public.documents where id = p_doc for update;
  if d.deleted_at is not null then raise exception 'Ce document est dans la corbeille'; end if;
  if p_base_revision is not null and d.revision <> p_base_revision then
    raise exception 'Le document a été modifié par quelqu''un d''autre (révision %). Rechargez-le.', d.revision using errcode = '40001';
  end if;
  if d.content is not null and (p_snapshot or not exists (
       select 1 from public.document_versions v where v.document_id = p_doc and v.created_at > now() - interval '10 minutes')) then
    insert into public.document_versions (document_id, revision, title, content, note, created_by)
    values (p_doc, d.revision, d.title, d.content, p_note, coalesce(d.updated_by, d.owner_id));
  end if;
  update public.documents
     set content = p_content, content_text = left(coalesce(p_text, ''), 200000),
         revision = d.revision + 1, updated_by = auth.uid(), updated_at = now()
   where id = p_doc;
  if p_ydoc is not null then
    insert into public.document_ydocs (document_id, state, revision) values (p_doc, p_ydoc, d.revision + 1)
    on conflict (document_id) do update set state = excluded.state, revision = excluded.revision, updated_at = now();
  else
    delete from public.document_ydocs where document_id = p_doc;
  end if;
  return d.revision + 1;
end $$;
grant execute on function public.save_document_content(uuid, jsonb, text, int, boolean, text, text) to authenticated;

-- Restaurer une version remplace le contenu : l'état Yjs est invalidé.
create or replace function public.restore_document_version(p_version uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v public.document_versions; d public.documents;
begin
  select * into v from public.document_versions where id = p_version;
  if v.id is null then raise exception 'Version introuvable'; end if;
  if public.document_access(v.document_id) < 2 then raise exception 'Permission refusée' using errcode = '42501'; end if;
  select * into d from public.documents where id = v.document_id for update;
  insert into public.document_versions (document_id, revision, title, content, storage_path, file_name, mime_type, size_bytes, note, created_by)
  values (d.id, d.revision, d.title, d.content, d.storage_path, d.file_name, d.mime_type, d.size_bytes, 'Avant restauration', auth.uid());
  update public.documents set
    content = coalesce(v.content, d.content),
    storage_path = coalesce(v.storage_path, d.storage_path), file_name = coalesce(v.file_name, d.file_name),
    mime_type = coalesce(v.mime_type, d.mime_type), size_bytes = coalesce(v.size_bytes, d.size_bytes),
    revision = d.revision + 1, updated_by = auth.uid()
  where id = d.id;
  if v.content is not null then delete from public.document_ydocs where document_id = d.id; end if;
end $$;

-- -----------------------------------------------------------------------------
-- 2. Notifications : catégories et préférences
-- -----------------------------------------------------------------------------
alter table public.notifications
  add column if not exists emailed_at timestamptz,
  add column if not exists pushed_at  timestamptz;
create index if not exists notifications_email_queue on public.notifications(created_at) where emailed_at is null and read_at is null;
create index if not exists notifications_push_queue  on public.notifications(created_at) where pushed_at is null;

-- Catégorie d'une notification (sert aux préférences). Doit rester alignée sur src/lib/notifications.ts.
create or replace function public.notification_category(p_kind text)
returns text language sql immutable as $$
  select case
    when p_kind in ('task.review', 'leave.requested', 'reminder.reviews', 'reminder.leaves') then 'approvals'
    when p_kind like 'message.%'  then 'messages'
    when p_kind like 'task.%' or p_kind in ('reminder.due', 'reminder.overdue') then 'tasks'
    when p_kind like 'drive.%'    then 'documents'
    when p_kind like 'meeting.%' or p_kind = 'reminder.meeting' then 'meetings'
    when p_kind like 'leave.%' or p_kind like 'hr.%' then 'hr'
    when p_kind = 'announcement'  then 'announcements'
    else 'other'
  end
$$;

create table public.notification_preferences (
  profile_id   uuid primary key references public.profiles(id) on delete cascade default auth.uid(),
  email_mode   text not null default 'instant' check (email_mode in ('instant', 'digest', 'off')),
  email_off    text[] not null default '{}',   -- catégories sans e-mail
  push_off     text[] not null default '{}',   -- catégories sans notification push
  quiet_start  time,                            -- plage « ne pas déranger » pour le push (heure de Porto-Novo)
  quiet_end    time,
  digest_hour  int not null default 7 check (digest_hour between 0 and 23),
  last_digest_at timestamptz,
  updated_at   timestamptz not null default now()
);

create table public.push_subscriptions (
  id            uuid primary key default gen_random_uuid(),
  profile_id    uuid not null references public.profiles(id) on delete cascade default auth.uid(),
  endpoint      text not null unique,
  p256dh        text not null,
  auth          text not null,
  device        text,
  created_at    timestamptz not null default now(),
  last_used_at  timestamptz
);
create index push_subscriptions_profile_idx on public.push_subscriptions(profile_id);

alter table public.notification_preferences enable row level security;
alter table public.push_subscriptions enable row level security;
grant select, insert, update, delete on public.notification_preferences, public.push_subscriptions to authenticated;

create policy "préférences: les miennes" on public.notification_preferences for all to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "push: mes appareils" on public.push_subscriptions for all to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- Enregistrer un appareil (un même navigateur peut changer de titulaire : l'endpoint est réattribué)
create or replace function public.register_push_subscription(p_endpoint text, p_p256dh text, p_auth text, p_device text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Non connecté' using errcode = '42501'; end if;
  if p_endpoint !~ '^https://' then raise exception 'Abonnement invalide'; end if;
  insert into public.push_subscriptions (profile_id, endpoint, p256dh, auth, device)
  values (auth.uid(), p_endpoint, p_p256dh, p_auth, left(p_device, 120))
  on conflict (endpoint) do update set profile_id = auth.uid(), p256dh = excluded.p256dh, auth = excluded.auth,
    device = excluded.device, created_at = now();
end $$;
grant execute on function public.register_push_subscription(text, text, text, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Déclenchement immédiat de l'envoi (push) via pg_net
-- -----------------------------------------------------------------------------
-- Réglages privés (schéma non exposé par l'API) : adresse de l'application et secret partagé.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
create table if not exists private.settings (key text primary key, value text not null);
revoke all on private.settings from public, anon, authenticated;

create or replace function private.setting(p_key text)
returns text language sql stable security definer set search_path = private as $$
  select value from private.settings where key = p_key
$$;

-- Appelle /api/notifications/dispatch sans jamais bloquer ni faire échouer l'écriture d'origine.
create or replace function public.notifications_dispatch()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  url text := private.setting('app_url');
  secret text := private.setting('cron_secret');
begin
  if url is null or secret is null or not exists (select 1 from pg_extension where extname = 'pg_net') then return null; end if;
  begin
    execute 'select net.http_post(url := $1, body := $2, headers := $3, timeout_milliseconds := 5000)'
      using rtrim(url, '/') || '/api/notifications/dispatch',
            jsonb_build_object('reason', 'insert'),
            jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || secret);
  exception when others then
    raise warning 'Notification : appel de l''application impossible (%)', sqlerrm;
  end;
  return null;
end $$;
-- Un appel par lot d'insertions (une annonce crée des centaines de notifications)
create trigger notifications_dispatch after insert on public.notifications
  for each statement execute function public.notifications_dispatch();

-- File d'envoi lue par l'application (clé service_role uniquement)
create or replace function public.claim_push_batch(p_limit int default 200)
returns table (id uuid, profile_id uuid, kind text, category text, title text, body text, link text, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  return query
  with c as (
    select n.id from public.notifications n
    where n.pushed_at is null and n.read_at is null and n.created_at > now() - interval '30 minutes'
    order by n.created_at
    limit p_limit
    for update skip locked
  )
  update public.notifications n set pushed_at = now()
  from c where n.id = c.id
  returning n.id, n.profile_id, n.kind, public.notification_category(n.kind), n.title, n.body, n.link, n.created_at;
end $$;

-- E-mails immédiats : non lues après 3 minutes (le temps de les voir dans l'application)
create or replace function public.claim_email_batch(p_limit int default 500)
returns table (id uuid, profile_id uuid, kind text, category text, title text, body text, link text, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  return query
  with c as (
    select n.id from public.notifications n
    left join public.notification_preferences p on p.profile_id = n.profile_id
    where n.emailed_at is null and n.read_at is null
      and n.created_at < now() - interval '3 minutes' and n.created_at > now() - interval '3 days'
      and coalesce(p.email_mode, 'instant') = 'instant'
    order by n.created_at
    limit p_limit
    for update of n skip locked
  )
  update public.notifications n set emailed_at = now()
  from c where n.id = c.id
  returning n.id, n.profile_id, n.kind, public.notification_category(n.kind), n.title, n.body, n.link, n.created_at;
end $$;

-- Résumé quotidien : personnes en mode « résumé » dont l'heure est arrivée
create or replace function public.claim_digest_batch()
returns table (id uuid, profile_id uuid, kind text, category text, title text, body text, link text, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare local_now timestamp := now() at time zone 'Africa/Porto-Novo';
begin
  return query
  with who as (
    update public.notification_preferences p set last_digest_at = now()
    where p.email_mode = 'digest' and extract(hour from local_now) >= p.digest_hour
      and (p.last_digest_at is null or (p.last_digest_at at time zone 'Africa/Porto-Novo')::date < local_now::date)
    returning p.profile_id
  ), c as (
    select n.id from public.notifications n join who on who.profile_id = n.profile_id
    where n.emailed_at is null and n.read_at is null and n.created_at > now() - interval '36 hours'
  )
  update public.notifications n set emailed_at = now()
  from c where n.id = c.id
  returning n.id, n.profile_id, n.kind, public.notification_category(n.kind), n.title, n.body, n.link, n.created_at;
end $$;

revoke execute on function public.claim_push_batch(int), public.claim_email_batch(int), public.claim_digest_batch() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. Rappels automatiques
-- -----------------------------------------------------------------------------
-- Chaque matin (7 h, heure de Porto-Novo) : échéances du jour, retards, validations et congés en attente.
create or replace function public.generate_daily_reminders()
returns int language plpgsql security definer set search_path = public as $$
declare
  today date := (now() at time zone 'Africa/Porto-Novo')::date;
  n int := 0;
  r record;
begin
  -- Tâches à rendre aujourd'hui
  for r in
    select t.assignee_id, count(*) c, min(t.title) first_title
    from public.tasks t join public.profiles p on p.id = t.assignee_id and p.status = 'active'
    where t.due_date = today and t.status <> 'done' group by t.assignee_id
  loop
    perform public.notify(r.assignee_id, 'reminder.due',
      case when r.c = 1 then 'Échéance aujourd''hui : ' || r.first_title else r.c || ' tâches arrivent à échéance aujourd''hui' end,
      null, '/taches');
    n := n + 1;
  end loop;

  -- Tâches en retard
  for r in
    select t.assignee_id, count(*) c
    from public.tasks t join public.profiles p on p.id = t.assignee_id and p.status = 'active'
    where t.due_date < today and t.status <> 'done' group by t.assignee_id
  loop
    perform public.notify(r.assignee_id, 'reminder.overdue',
      case when r.c = 1 then '1 tâche en retard' else r.c || ' tâches en retard' end, 'Pensez à les terminer ou à revoir leur échéance.', '/taches');
    n := n + 1;
  end loop;

  -- Validations en attente depuis plus d'un jour (chef de projet)
  for r in
    select pr.owner_id, count(*) c
    from public.tasks t join public.projects pr on pr.id = t.project_id
    where t.status = 'review' and t.requires_validation and t.updated_at < now() - interval '1 day' and pr.owner_id is not null
    group by pr.owner_id
  loop
    perform public.notify(r.owner_id, 'reminder.reviews',
      r.c || case when r.c = 1 then ' tâche attend' else ' tâches attendent' end || ' votre validation', null, '/taches');
    n := n + 1;
  end loop;

  -- Demandes de congé à traiter (responsables et managers)
  for r in
    select x.approver, count(distinct x.req) c from (
      select g.profile_id approver, l.id req
      from public.leave_requests l
      join public.unit_memberships m on m.profile_id = l.profile_id and m.end_date is null
      join public.org_units u on u.id = m.unit_id
      join public.role_grants g on g.permission = 'unit.manage' and g.scope_unit_id = any(u.path) and g.profile_id <> l.profile_id
      where l.status = 'pending'
      union
      select p.manager_id, l.id from public.leave_requests l join public.profiles p on p.id = l.profile_id
      where l.status = 'pending' and p.manager_id is not null
    ) x group by x.approver
  loop
    perform public.notify(r.approver, 'reminder.leaves',
      r.c || case when r.c = 1 then ' demande de congé attend' else ' demandes de congé attendent' end || ' votre décision', null, '/rh?onglet=validation');
    n := n + 1;
  end loop;
  return n;
end $$;

-- Toutes les 5 minutes : réunions qui commencent dans les 15 prochaines minutes
alter table public.meetings add column if not exists reminded_at timestamptz;
create or replace function public.remind_upcoming_meetings()
returns int language plpgsql security definer set search_path = public as $$
declare m record; a record; n int := 0;
begin
  for m in
    update public.meetings set reminded_at = now()
    where reminded_at is null and starts_at between now() and now() + interval '15 minutes'
    returning *
  loop
    for a in select profile_id from public.meeting_attendees where meeting_id = m.id and response <> 'declined'
             union select m.organizer_id where m.organizer_id is not null
    loop
      insert into public.notifications (profile_id, kind, title, body, link)
      values (a.profile_id, 'reminder.meeting', 'Réunion à ' || to_char(m.starts_at at time zone 'Africa/Porto-Novo', 'HH24:MI') || ' : ' || m.title,
              coalesce(m.location, case when m.video_url is not null then 'Visioconférence' end), coalesce(m.video_url, '/reunions'));
      n := n + 1;
    end loop;
  end loop;
  return n;
end $$;
revoke execute on function public.generate_daily_reminders(), public.remind_upcoming_meetings() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 5. Tâches planifiées
-- -----------------------------------------------------------------------------
do $$
begin
  perform cron.schedule('veriion-daily-reminders', '0 6 * * *', 'select public.generate_daily_reminders()');   -- 7 h à Porto-Novo
  perform cron.schedule('veriion-meeting-reminders', '*/5 * * * *', 'select public.remind_upcoming_meetings()');
exception when others then
  raise notice 'pg_cron non disponible : rappels automatiques à planifier plus tard (%)', sqlerrm;
end $$;

-- L'envoi des e-mails (immédiats et résumés) et le rattrapage des push sont faits
-- par l'application : /api/notifications/dispatch, appelé chaque minute.
-- Voir le README (section Notifications) pour activer l'appel avec pg_cron + pg_net :
--   insert into private.settings values ('app_url', 'https://os.veriion.com'), ('cron_secret', '<CRON_SECRET>');
--   select cron.schedule('veriion-notifications', '* * * * *', $$select net.http_post(
--     url := private.setting('app_url') || '/api/notifications/dispatch',
--     headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' || private.setting('cron_secret')),
--     body := '{"reason":"cron"}'::jsonb)$$);

-- Temps réel pour les préférences inutile ; publication des notifications déjà active.

-- L'application (clé service_role) dépile les files d'envoi et peut déclencher les rappels
grant execute on function public.claim_push_batch(int), public.claim_email_batch(int), public.claim_digest_batch(),
  public.generate_daily_reminders(), public.remind_upcoming_meetings() to service_role;
grant select, insert, update, delete on public.notifications, public.notification_preferences, public.push_subscriptions to service_role;
grant select on public.profiles to service_role;

-- >>>>>>>>>> supabase/migrations/20260928000008_access_code.sql
-- =============================================================================
-- VERIION OS — Migration 8 : code d'accès personnel
-- =============================================================================
-- Remplace la double authentification TOTP (application d'authentification) par
-- un code personnel choisi par le collaborateur :
--   * il le définit lui-même, une fois, et le change quand il veut ;
--   * il le saisit à chaque nouvelle session pour rouvrir son espace — la
--     session Supabase n'est jamais fermée, l'application est simplement
--     verrouillée jusqu'à la saisie du code ;
--   * seul un hachage bcrypt est conservé. La table n'est lisible par personne,
--     pas même son propriétaire : tout passe par les fonctions ci-dessous.
-- =============================================================================

create table public.access_codes (
  profile_id     uuid primary key references public.profiles(id) on delete cascade,
  code_hash      text        not null,
  attempts       int         not null default 0,   -- échecs consécutifs depuis le dernier succès
  locked_until   timestamptz,                      -- blocage temporaire après trop d'échecs
  last_unlock_at timestamptz,                      -- dernier déverrouillage réussi
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
-- RLS active et volontairement sans aucune policy ni grant : la table est
-- inaccessible depuis l'API, les fonctions security definer en sont la seule porte.
alter table public.access_codes enable row level security;

create trigger access_codes_touch before update on public.access_codes
  for each row execute function public.set_updated_at();
-- Audit sans le contenu des lignes (« redact ») : on trace la création et la
-- suppression d'un code, jamais son hachage ni les tentatives.
create trigger audit_access_codes after insert or delete on public.access_codes
  for each row execute function public.audit_trigger('redact');

-- -----------------------------------------------------------------------------
-- Forme acceptée : 6 à 32 caractères, sans espace, ni caractère répété
-- (000000), ni suite de chiffres évidente (123456, 654321).
-- -----------------------------------------------------------------------------
create or replace function public.access_code_valid(p_code text)
returns boolean language plpgsql immutable as $$
declare n int; i int; ascending boolean; descending boolean;
begin
  if p_code is null then return false; end if;
  n := length(p_code);
  if n < 6 or n > 32 then return false; end if;
  if p_code ~ '\s' then return false; end if;
  if p_code ~ '^(.)\1*$' then return false; end if;
  if p_code ~ '^\d+$' then
    ascending := true; descending := true;
    for i in 2..n loop
      if ascii(substr(p_code, i, 1)) <> ascii(substr(p_code, i - 1, 1)) + 1 then ascending := false; end if;
      if ascii(substr(p_code, i, 1)) <> ascii(substr(p_code, i - 1, 1)) - 1 then descending := false; end if;
    end loop;
    if ascending or descending then return false; end if;
  end if;
  return true;
end $$;

-- -----------------------------------------------------------------------------
-- Un code est-il défini ? (pour soi, ou pour un collaborateur si l'on administre)
-- -----------------------------------------------------------------------------
create or replace function public.has_access_code(p_profile uuid default null)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare target uuid := coalesce(p_profile, auth.uid());
begin
  if target is null then return false; end if;
  if target <> auth.uid() and not public.has_perm('users.admin') then
    raise exception 'Permission refusée' using errcode = '42501';
  end if;
  return exists (select 1 from public.access_codes where profile_id = target);
end $$;
grant execute on function public.has_access_code(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- Vérifier son code pour rouvrir son espace.
-- Retourne { ok:true } ou { ok:false, remaining } / { ok:false, locked_until } /
-- { ok:false, missing:true } si aucun code n'est encore défini.
-- 5 échecs consécutifs bloquent la saisie pendant 15 minutes.
-- -----------------------------------------------------------------------------
create or replace function public.verify_access_code(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  rec          public.access_codes;
  max_attempts constant int      := 5;
  lock_delay   constant interval := interval '15 minutes';
  until_ts     timestamptz;
  remaining    int;
begin
  if auth.uid() is null then raise exception 'Non connecté' using errcode = '42501'; end if;
  select * into rec from public.access_codes where profile_id = auth.uid() for update;
  if rec.profile_id is null then return jsonb_build_object('ok', false, 'missing', true); end if;
  if rec.locked_until is not null and rec.locked_until > now() then
    return jsonb_build_object('ok', false, 'remaining', 0, 'locked_until', rec.locked_until);
  end if;
  if p_code is not null and rec.code_hash = extensions.crypt(p_code, rec.code_hash) then
    update public.access_codes set attempts = 0, locked_until = null, last_unlock_at = now()
     where profile_id = auth.uid();
    return jsonb_build_object('ok', true);
  end if;
  if rec.attempts + 1 >= max_attempts then
    update public.access_codes set attempts = 0, locked_until = now() + lock_delay
     where profile_id = auth.uid() returning locked_until into until_ts;
    return jsonb_build_object('ok', false, 'remaining', 0, 'locked_until', until_ts);
  end if;
  update public.access_codes set attempts = rec.attempts + 1
   where profile_id = auth.uid() returning max_attempts - attempts into remaining;
  return jsonb_build_object('ok', false, 'remaining', remaining);
end $$;
grant execute on function public.verify_access_code(text) to authenticated;

-- -----------------------------------------------------------------------------
-- Définir ou changer son code. Le changement exige le code actuel, vérifié par
-- `verify_access_code` : le changement de code est donc soumis au même compteur
-- d'échecs et au même blocage temporaire que le déverrouillage.
-- -----------------------------------------------------------------------------
create or replace function public.set_access_code(p_code text, p_current text default null)
returns void language plpgsql security definer set search_path = public as $$
declare existing public.access_codes; verdict jsonb;
begin
  if auth.uid() is null then raise exception 'Non connecté' using errcode = '42501'; end if;
  if not public.is_active_user() then raise exception 'Compte inactif' using errcode = '42501'; end if;
  if not public.access_code_valid(p_code) then
    raise exception 'Le code doit contenir de 6 à 32 caractères, sans espace, et ne pas être un caractère répété ni une suite évidente.';
  end if;
  select * into existing from public.access_codes where profile_id = auth.uid();
  if existing.profile_id is not null then
    verdict := public.verify_access_code(p_current);
    if not coalesce((verdict->>'ok')::boolean, false) then
      if verdict ? 'locked_until' then
        raise exception 'Trop de tentatives. Réessayez dans quelques minutes ou demandez une réinitialisation à l''administration.' using errcode = '42501';
      end if;
      raise exception 'Code actuel incorrect.' using errcode = '42501';
    end if;
    update public.access_codes
       set code_hash = extensions.crypt(p_code, extensions.gen_salt('bf', 10)),
           attempts = 0, locked_until = null, last_unlock_at = now()
     where profile_id = auth.uid();
  else
    insert into public.access_codes (profile_id, code_hash, last_unlock_at)
    values (auth.uid(), extensions.crypt(p_code, extensions.gen_salt('bf', 10)), now());
  end if;
end $$;
grant execute on function public.set_access_code(text, text) to authenticated;

-- -----------------------------------------------------------------------------
-- Code oublié : un administrateur l'efface, la personne en redéfinit un à sa
-- prochaine ouverture. L'opération est journalisée (audit).
-- -----------------------------------------------------------------------------
create or replace function public.clear_access_code(p_profile uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.has_perm('users.admin') then
    raise exception 'Action réservée aux administrateurs' using errcode = '42501';
  end if;
  delete from public.access_codes where profile_id = p_profile;
end $$;
grant execute on function public.clear_access_code(uuid) to authenticated;

-- Un départ efface le code d'accès : plus rien ne subsiste de l'accès personnel.
create or replace function public.access_codes_drop_on_offboard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.access_codes where profile_id = new.id;
  return null;
end $$;
create trigger profiles_drop_access_code after update of status on public.profiles
  for each row when (new.status = 'offboarded' and old.status <> 'offboarded')
  execute function public.access_codes_drop_on_offboard();

-- >>>>>>>>>> supabase/migrations/20260929000009_holding.sql
-- =============================================================================
-- VERIION OS — Migration 9 : la holding et ses projets
-- =============================================================================
-- VERIION est une holding qui pilote plusieurs projets tech. Deux axes se
-- croisent, et c'est ce croisement que cette migration installe :
--
--   * l'axe administratif — les départements transverses de la holding
--     (Direction Générale, Opérations, Technologie, Finance, Business,
--     Marketing, Juridique, Ressources Humaines), chacun dirigé par un officier
--     dont l'intitulé est porté par l'unité (CEO, COO, CTO, CFO, CBO, CMO…) ;
--
--   * l'axe produit — les projets, chacun dirigé par un Chief Product et son
--     équipe.
--
-- Le lien entre les deux : chaque département désigne un **référent** par
-- projet. C'est le point de contact direct du chef de projet pour cette
-- fonction. Le référent rejoint automatiquement le canal du projet : la
-- coordination se fait de personne à personne, pas de service à service.
--
-- Cette migration apporte aussi :
--   * l'intitulé de poste calculé à la nomination (plus de saisie libre) ;
--   * la fusion de deux unités, pour que le CEO puisse réduire ou regrouper
--     des départements sans perdre l'historique ;
--   * le profil obligatoire : une fiche incomplète ne donne pas accès à l'outil.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Domaines métier : ouverture au juridique et au produit
-- -----------------------------------------------------------------------------
-- Le domaine reste la clé des droits automatiques (role_templates). Il devient
-- du texte contraint plutôt qu'un type énuméré : ajouter un domaine ne demande
-- plus de migration lourde, et la liste reste vérifiée par la base.
-- Le trigger de resynchronisation des droits cite la colonne (« update of domain ») :
-- PostgreSQL refuse d'en changer le type tant qu'il existe. On le repose juste apres.
drop trigger if exists org_units_domain_au on public.org_units;

alter table public.org_units      alter column domain type text using domain::text;
alter table public.role_templates alter column domain type text using domain::text;
drop type if exists public.unit_domain;

drop trigger if exists org_units_domain_au on public.org_units;
create trigger org_units_domain_au after update of domain, archived_at on public.org_units
  for each row execute function public.org_units_after_domain_change();

create table if not exists public.unit_domains (
  key         text primary key,
  label       text not null,
  description text,
  sort_order  int  not null default 0
);
insert into public.unit_domains (key, label, description, sort_order) values
  ('direction',  'Direction',     'Vision, arbitrages et pilotage de la holding',          1),
  ('operations', 'Opérations',    'Calendrier opérationnel, exécution et qualité',          2),
  ('technology', 'Technologie',   'Plateformes, infrastructure et sécurité',                3),
  ('product',    'Produit',       'Conception et pilotage des produits',                    4),
  ('marketing',  'Marketing',     'Acquisition, communication et contenu',                  5),
  ('business',   'Business',      'Ventes, partenariats et développement',                  6),
  ('finance',    'Finance',       'Comptabilité, trésorerie et contrôle',                   7),
  ('legal',      'Juridique',     'Contrats, conformité et contentieux',                    8),
  ('hr',         'Ressources humaines', 'Recrutement, contrats de travail, paie',           9),
  ('other',      'Autre',         'Fonction transverse ou support',                        99);

alter table public.org_units drop constraint if exists org_units_domain_fk;
alter table public.org_units add constraint org_units_domain_fk foreign key (domain) references public.unit_domains(key) on update cascade;
alter table public.role_templates drop constraint if exists role_templates_domain_fk;
alter table public.role_templates add constraint role_templates_domain_fk foreign key (domain) references public.unit_domains(key) on update cascade;

grant select, insert, update, delete on public.unit_domains to authenticated;
alter table public.unit_domains enable row level security;
drop policy if exists "domaines: lecture" on public.unit_domains;
create policy "domaines: lecture" on public.unit_domains for select to authenticated using (public.is_active_user());
drop policy if exists "domaines: gestion" on public.unit_domains;
create policy "domaines: gestion" on public.unit_domains for all to authenticated
  using (public.is_ceo()) with check (public.is_ceo());

-- -----------------------------------------------------------------------------
-- 2. L'unité porte les intitulés de poste
-- -----------------------------------------------------------------------------
-- Nommer quelqu'un responsable d'un département lui donne le titre du poste :
-- personne ne saisit plus « CFO » à la main, et un changement de titre suit
-- automatiquement la personne en poste.
alter table public.org_units
  add column if not exists head_title   text,   -- ex. « CFO — Directeur Financier »
  add column if not exists deputy_title text,
  add column if not exists member_title text,
  add column if not exists is_core      boolean not null default false;  -- département fondateur de la holding

comment on column public.org_units.head_title is 'Intitulé attribué automatiquement au responsable de l''unité.';
comment on column public.org_units.is_core    is 'Département structurant de la holding : signalé dans l''organigramme, fusion déconseillée.';

-- Intitulé attendu pour un rôle dans une unité (utilisé à la nomination).
create or replace function public.job_title_for(p_unit uuid, p_role public.membership_role)
returns text language sql stable security definer set search_path = public as $$
  select case p_role
    when 'head' then coalesce(u.head_title, case u.kind
        when 'company'       then 'CEO'
        when 'department'    then 'Directeur — ' || u.name
        when 'subdepartment' then 'Responsable — ' || u.name
        else 'Chef d''équipe — ' || u.name end)
    when 'deputy' then coalesce(u.deputy_title, case u.kind
        when 'company'       then 'Directeur Général Adjoint'
        when 'department'    then 'Directeur adjoint — ' || u.name
        else 'Adjoint — ' || u.name end)
    else u.member_title
  end
  from public.org_units u where u.id = p_unit
$$;
grant execute on function public.job_title_for(uuid, public.membership_role) to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Projets : des produits de la holding, dirigés par un Chief Product
-- -----------------------------------------------------------------------------
alter table public.projects
  add column if not exists lead_id uuid references public.profiles(id) on delete set null,
  add column if not exists mission text;
comment on column public.projects.lead_id is 'Chief Product : dirige le projet, son équipe et la répartition des tâches.';

update public.projects set lead_id = owner_id where lead_id is null;
create index if not exists projects_lead_idx on public.projects(lead_id);

-- Référent d'un département pour un projet : le point de contact direct du
-- chef de projet pour cette fonction (opérations, finance, juridique…).
create table if not exists public.project_liaisons (
  project_id  uuid not null references public.projects(id)  on delete cascade,
  unit_id     uuid not null references public.org_units(id) on delete cascade,
  profile_id  uuid not null references public.profiles(id)  on delete cascade,
  note        text,
  created_by  uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at  timestamptz not null default now(),
  primary key (project_id, unit_id)
);
create index if not exists project_liaisons_profile_idx on public.project_liaisons(profile_id);
create index if not exists project_liaisons_unit_idx    on public.project_liaisons(unit_id);

-- Le chef de projet dirige ; le référent d'un département voit le projet et
-- échange dans son canal, sans pouvoir répartir les tâches de l'équipe.
create or replace function public.is_project_lead(p_project uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.projects p
    where p.id = p_project and (p.lead_id = auth.uid() or p.owner_id = auth.uid())
  ) or coalesce(public.project_role(p_project) = 'lead', false)
$$;
grant execute on function public.is_project_lead(uuid) to authenticated;

create or replace function public.is_project_liaison(p_project uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.project_liaisons l
    where l.project_id = p_project
      and (l.profile_id = auth.uid() or public.has_perm('unit.manage', l.unit_id))
  )
$$;
grant execute on function public.is_project_liaison(uuid) to authenticated;

create or replace function public.can_manage_project(p_project uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.projects p
    where p.id = p_project and (
      p.owner_id = auth.uid() or p.lead_id = auth.uid()
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
      or p.owner_id = auth.uid() or p.lead_id = auth.uid()
      or public.in_unit(p.unit_id)
      or public.has_perm('projects.admin')
      or public.has_perm('unit.manage', p.unit_id)
      or public.has_perm('dashboard.exec')
    )
  ) or public.is_project_liaison(p_project)
$$;

alter table public.project_liaisons enable row level security;
grant select, insert, update, delete on public.project_liaisons to authenticated;
drop policy if exists "référents: lecture" on public.project_liaisons;
create policy "référents: lecture" on public.project_liaisons for select to authenticated
  using (public.is_active_user() and (public.can_view_project(project_id) or public.can_view_unit(unit_id)));
drop policy if exists "référents: désignation" on public.project_liaisons;
create policy "référents: désignation" on public.project_liaisons for all to authenticated
  using (public.has_perm('org.manage') or public.has_perm('unit.manage', unit_id))
  with check (public.has_perm('org.manage') or public.has_perm('unit.manage', unit_id));

-- Désigner un référent l'ajoute au canal du projet et le prévient : la
-- coordination démarre dans la foulée, sans démarche supplémentaire.
create or replace function public.project_liaisons_after_write()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_channel uuid; v_project text; v_unit text;
begin
  select name into v_project from public.projects  where id = new.project_id;
  select name into v_unit    from public.org_units where id = new.unit_id;
  select id into v_channel from public.channels where project_id = new.project_id and kind = 'project' limit 1;
  if v_channel is not null then
    insert into public.channel_members (channel_id, profile_id) values (v_channel, new.profile_id)
    on conflict do nothing;
  end if;
  perform public.notify(new.profile_id, 'project.liaison',
    'Référent ' || coalesce(v_unit, 'département') || ' — ' || coalesce(v_project, 'projet'),
    'Vous coordonnez ce projet pour votre département.', '/projets/' || new.project_id);
  perform public.notify(p.lead_id, 'project.liaison',
    coalesce(v_unit, 'Un département') || ' a désigné un référent',
    'Votre point de contact pour ce département est à jour.', '/projets/' || new.project_id)
    from public.projects p where p.id = new.project_id and p.lead_id is distinct from new.profile_id;
  return null;
end $$;
drop trigger if exists project_liaisons_aiu on public.project_liaisons;
create trigger project_liaisons_aiu after insert or update on public.project_liaisons
  for each row execute function public.project_liaisons_after_write();

-- Le chef de projet est membre de son projet, et le reste s'il change.
create or replace function public.projects_sync_lead()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.lead_id is not null then
    insert into public.project_members (project_id, profile_id, role) values (new.id, new.lead_id, 'lead')
    on conflict (project_id, profile_id) do update set role = 'lead';
    if tg_op = 'UPDATE' and old.lead_id is distinct from new.lead_id then
      update public.project_members set role = 'member'
       where project_id = new.id and profile_id = old.lead_id;
      perform public.notify(new.lead_id, 'project.lead', 'Vous dirigez « ' || new.name || ' »',
        'Le pilotage de ce projet vous est confié.', '/projets/' || new.id);
    end if;
    perform public.refresh_job_title(new.lead_id);
  end if;
  if tg_op = 'UPDATE' and old.lead_id is not null and old.lead_id is distinct from new.lead_id then
    perform public.refresh_job_title(old.lead_id);
  end if;
  return null;
end $$;

-- -----------------------------------------------------------------------------
-- 4. L'intitulé de poste suit les nominations
-- -----------------------------------------------------------------------------
-- Règle : le poste le plus élevé l'emporte (responsable avant adjoint, unité la
-- plus haute avant une équipe), puis la direction d'un projet, puis l'intitulé
-- de membre défini par l'unité.
create or replace function public.refresh_job_title(p_profile uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_title text;
begin
  select public.job_title_for(m.unit_id, m.role) into v_title
  from public.unit_memberships m
  join public.org_units u on u.id = m.unit_id and u.archived_at is null
  where m.profile_id = p_profile and m.end_date is null
    and public.job_title_for(m.unit_id, m.role) is not null
  order by public.membership_rank(m.role) desc, u.depth asc, m.start_date asc
  limit 1;

  if v_title is null then
    select 'Chief Product — ' || p.name into v_title
    from public.projects p
    where p.lead_id = p_profile and p.archived_at is null
    order by p.created_at asc limit 1;
  end if;

  if v_title is not null then
    update public.profiles set job_title = v_title where id = p_profile and job_title is distinct from v_title;
  end if;
end $$;
grant execute on function public.refresh_job_title(uuid) to authenticated;

drop trigger if exists projects_lead_aiu on public.projects;
create trigger projects_lead_aiu after insert or update of lead_id on public.projects
  for each row execute function public.projects_sync_lead();

-- Le passage par les appartenances reste le seul chemin : on étend le trigger
-- existant pour qu'il rafraîchisse aussi l'intitulé.
create or replace function public.unit_memberships_after_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform public.sync_auto_grants(old.profile_id);
    perform public.refresh_job_title(old.profile_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    perform public.sync_auto_grants(new.profile_id);
    update public.profiles set primary_unit_id = new.unit_id
      where id = new.profile_id and primary_unit_id is null and new.end_date is null;
    perform public.refresh_job_title(new.profile_id);
  end if;
  return null;
end $$;

-- Nomination : l'intitulé est calculé, sauf titre explicite (rare, et tracé).
create or replace function public.appoint_member(
  p_unit uuid, p_profile uuid, p_role public.membership_role,
  p_title text default null, p_start date default current_date
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_parent uuid;
  v_id uuid;
  v_title text;
begin
  select parent_id into v_parent from public.org_units where id = p_unit and archived_at is null;
  if not found then raise exception 'Unité introuvable ou archivée'; end if;

  -- Nommer un responsable : org.manage ou gestion de l'unité parente. Membres/adjoints : gestion de l'unité.
  if not (public.has_perm('org.manage')
          or (p_role = 'head' and v_parent is not null and public.has_perm('unit.manage', v_parent))
          or (p_role <> 'head' and public.has_perm('unit.manage', p_unit))) then
    raise exception 'Permission refusée' using errcode = '42501';
  end if;

  v_title := coalesce(nullif(trim(coalesce(p_title, '')), ''), public.job_title_for(p_unit, p_role));

  if p_role = 'head' then
    update public.unit_memberships
       set end_date = greatest(start_date, p_start - 1)
     where unit_id = p_unit and role = 'head' and end_date is null and profile_id <> p_profile;
  end if;

  update public.unit_memberships
     set end_date = greatest(start_date, p_start - 1)
   where unit_id = p_unit and profile_id = p_profile and end_date is null;

  insert into public.unit_memberships (unit_id, profile_id, role, title, start_date, created_by)
  values (p_unit, p_profile, p_role, v_title, p_start, auth.uid())
  returning id into v_id;
  return v_id;
end $$;

-- -----------------------------------------------------------------------------
-- 5. Fusionner deux unités (le CEO réduit ou regroupe son organisation)
-- -----------------------------------------------------------------------------
-- Tout ce qui pendait à l'unité absorbée bascule sur l'unité d'accueil :
-- personnes, sous-unités, canaux, budgets, projets, annonces, objectifs,
-- dossiers. L'unité absorbée est archivée, jamais supprimée : l'historique des
-- nominations et le journal d'audit restent lisibles.
create or replace function public.merge_org_units(p_source uuid, p_target uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  s public.org_units;
  t public.org_units;
  m record;
  v_role public.membership_role;
  v_src_root uuid;
  v_tgt_root uuid;
begin
  if not public.has_perm('org.manage') then
    raise exception 'Seule la direction peut fusionner des unités' using errcode = '42501';
  end if;
  if p_source = p_target then raise exception 'Choisissez deux unités différentes'; end if;
  select * into s from public.org_units where id = p_source;
  select * into t from public.org_units where id = p_target;
  if s.id is null or t.id is null then raise exception 'Unité introuvable'; end if;
  if s.parent_id is null then raise exception 'L''entreprise elle-même ne peut pas être fusionnée'; end if;
  if s.id = any(t.path) then raise exception 'L''unité d''accueil dépend de l''unité à fusionner : choisissez l''autre sens'; end if;

  -- Les personnes suivent, en conservant leur rang quand la place est libre.
  for m in select * from public.unit_memberships where unit_id = p_source and end_date is null loop
    v_role := m.role;
    if v_role = 'head' and exists (
      select 1 from public.unit_memberships where unit_id = p_target and role = 'head' and end_date is null
    ) then
      v_role := 'deputy';
    end if;
    if exists (select 1 from public.unit_memberships where unit_id = p_target and profile_id = m.profile_id and end_date is null) then
      update public.unit_memberships set end_date = current_date where id = m.id;
    else
      update public.unit_memberships
         set unit_id = p_target, role = v_role, title = public.job_title_for(p_target, v_role)
       where id = m.id;
    end if;
  end loop;

  update public.org_units    set parent_id = p_target where parent_id = p_source;
  update public.channels     set unit_id   = p_target where unit_id = p_source;
  update public.projects     set unit_id   = p_target where unit_id = p_source;
  update public.announcements set unit_id  = p_target where unit_id = p_source;
  update public.objectives   set unit_id   = p_target where unit_id = p_source;
  update public.invoices     set unit_id   = p_target where unit_id = p_source;
  update public.transactions set unit_id   = p_target where unit_id = p_source;
  update public.project_liaisons l set unit_id = p_target where unit_id = p_source
     and not exists (select 1 from public.project_liaisons x where x.project_id = l.project_id and x.unit_id = p_target);
  delete from public.project_liaisons where unit_id = p_source;

  -- Les budgets se cumulent sur l'exercice, plutôt que de se perdre.
  update public.budgets b set amount = b.amount + s2.amount
    from public.budgets s2
   where b.unit_id = p_target and s2.unit_id = p_source and s2.fiscal_year = b.fiscal_year;
  update public.budgets set unit_id = p_target
   where unit_id = p_source and fiscal_year not in (select fiscal_year from public.budgets where unit_id = p_target);
  delete from public.budgets where unit_id = p_source;

  -- Drive : l'espace de l'unité absorbée se déverse dans celui de l'unité d'accueil,
  -- en suffixant les dossiers dont le nom existe déjà des deux côtés.
  select id into v_src_root from public.folders where is_root and space = 'unit' and unit_id = p_source;
  select id into v_tgt_root from public.folders where is_root and space = 'unit' and unit_id = p_target;
  if v_src_root is not null and v_tgt_root is not null then
    for m in select * from public.folders where parent_id = v_src_root and deleted_at is null loop
      if exists (select 1 from public.folders f
                  where f.parent_id = v_tgt_root and lower(f.name) = lower(m.name) and f.deleted_at is null) then
        update public.folders set parent_id = v_tgt_root, name = m.name || ' (' || s.name || ')' where id = m.id;
      else
        update public.folders set parent_id = v_tgt_root where id = m.id;
      end if;
    end loop;
    update public.documents set folder_id = v_tgt_root where folder_id = v_src_root;
    update public.folders set unit_id = p_target where unit_id = p_source and not is_root;
    update public.folders set deleted_at = now() where id = v_src_root;
  end if;

  update public.profiles set primary_unit_id = p_target where primary_unit_id = p_source;
  update public.org_units set archived_at = now() where id = p_source;
end $$;
grant execute on function public.merge_org_units(uuid, uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 6. Profil obligatoire
-- -----------------------------------------------------------------------------
-- Un annuaire ne vaut que si les fiches sont remplies : tant que la sienne ne
-- l'est pas, l'application reste fermée (contrôle côté interface, la donnée
-- restant vérifiée ici).
alter table public.profiles add column if not exists profile_completed_at timestamptz;

create or replace function public.profile_fields_complete(p public.profiles)
returns boolean language sql immutable as $$
  select length(trim(coalesce(p.first_name, ''))) > 1
     and length(trim(coalesce(p.last_name,  ''))) > 1
     and length(trim(coalesce(p.phone,      ''))) > 5
     and length(trim(coalesce(p.location,   ''))) > 1
$$;

create or replace function public.profiles_track_completion()
returns trigger language plpgsql as $$
begin
  if public.profile_fields_complete(new) then
    new.profile_completed_at := coalesce(new.profile_completed_at, now());
  else
    new.profile_completed_at := null;
  end if;
  return new;
end $$;
drop trigger if exists profiles_completion_biu on public.profiles;
create trigger profiles_completion_biu before insert or update on public.profiles
  for each row execute function public.profiles_track_completion();

update public.profiles set updated_at = updated_at;  -- réévalue les fiches existantes

-- -----------------------------------------------------------------------------
-- 7. La holding : départements structurants et intitulés des officiers
-- -----------------------------------------------------------------------------
do $$
declare root uuid; v_id uuid;
begin
  select id into root from public.org_units where parent_id is null order by created_at limit 1;
  if root is null then return; end if;   -- base neuve : seed.sql pose la structure

  update public.org_units set head_title = 'CEO — Directeur Général', is_core = true, domain = 'direction'
   where id = root;

  -- Intitulés des officiers, sur les départements déjà en place
  update public.org_units set head_title = 'CEO — Directeur Général',        deputy_title = 'Directeur Général Adjoint',  is_core = true where code = 'DG';
  update public.org_units set head_title = 'COO — Directeur des Opérations', deputy_title = 'Responsable des Opérations', is_core = true where code = 'OPS';
  update public.org_units set head_title = 'CTO — Directeur Technique',      deputy_title = 'Responsable Technique',      is_core = true where code = 'TECH';
  update public.org_units set head_title = 'CFO — Directeur Financier',      deputy_title = 'Responsable Financier',      is_core = true where code = 'FIN';
  update public.org_units set head_title = 'CBO — Directeur Business',       deputy_title = 'Responsable Business',       is_core = true where code = 'BIZ';
  update public.org_units set head_title = 'CMO — Directeur Marketing',      deputy_title = 'Responsable Marketing',      is_core = true where code = 'MKT';

  -- Départements manquants de la holding
  if not exists (select 1 from public.org_units where code = 'LEG') then
    insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description, head_title, deputy_title, is_core)
    values (root, 'Juridique', 'LEG', 'department', 'legal', '#7C3AED', 7,
            'Contrats, conformité, propriété intellectuelle et contentieux',
            'Directeur Juridique', 'Juriste principal', true);
  end if;
  if not exists (select 1 from public.org_units where code = 'RH') then
    insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description, head_title, deputy_title, is_core)
    values (root, 'Ressources Humaines', 'RH', 'department', 'hr', '#0D9488', 8,
            'Recrutement, contrats de travail, paie et parcours des collaborateurs',
            'CHRO — Directeur des Ressources Humaines', 'Responsable RH', true);
  end if;

  -- Intitulés par défaut des niveaux inférieurs
  update public.org_units set member_title = null where member_title = '';
end $$;

-- Droits automatiques des deux nouveaux domaines.
insert into public.role_templates (domain, membership_role, permission, scoped) values
  ('legal', 'head',   'docs.confidential', false),
  ('legal', 'head',   'dashboard.exec',    false),
  ('hr',    'head',   'hr.admin',          false),
  ('hr',    'head',   'dashboard.exec',    false),
  ('hr',    'member', 'hr.view',           false)
on conflict do nothing;

-- Recalcule droits et intitulés pour tout le monde (les modèles ont changé).
do $$ declare r record; begin
  for r in select id from public.profiles where status = 'active' loop
    perform public.sync_auto_grants(r.id);
    perform public.refresh_job_title(r.id);
  end loop;
end $$;

-- >>>>>>>>>> supabase/migrations/20260930000010_operations_legal.sql
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

-- >>>>>>>>>> supabase/migrations/20261012000011_p0_gouvernance.sql
-- =============================================================================
-- VERIION OS — Migration 11 : gouvernance fiable (phase 0, lots P0-01 à P0-05, P0-07)
-- =============================================================================
-- Corrige les contournements mis en évidence par l'audit du 9 octobre 2026 :
--   P0-01  le seuil des validations et les paramètres de gouvernance ne sont
--          modifiables que par le CEO ;
--   P0-02  personne d'autre que le CEO ne peut suspendre, rétrograder ou faire
--          partir un CEO ; la succession passe par transfer_ceo() ;
--   P0-03  les permissions sensibles ne s'accordent que sur décision du CEO, et
--          toute dérogation a une durée plafonnée ;
--   P0-04  un accord porte sur un contenu figé (instantané + empreinte), se
--          consomme au fil des dépenses, ne peut pas être donné par le
--          demandeur lui-même, et le CEO laisse lui aussi une décision tracée ;
--   P0-05  le titulaire d'une tâche ne peut plus lever sa propre vérification ;
--   P0-07  les opérations sensibles exigent la double authentification (aal2).
-- Rejouable : tout est conditionné.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. Correctif : la séquence des contrats juridiques n'était pas accordée.
-- -----------------------------------------------------------------------------
grant usage, select on sequence public.legal_contract_seq to authenticated;

-- -----------------------------------------------------------------------------
-- P0-01. Paramètres de gouvernance (CEO uniquement)
-- -----------------------------------------------------------------------------
create table if not exists public.governance_settings (
  id                      boolean primary key default true check (id),
  ceo_approval_threshold  numeric(16,2) not null default 500000 check (ceo_approval_threshold >= 0),
  approval_reminder_days  int not null default 2  check (approval_reminder_days between 1 and 30),
  max_grant_days          int not null default 90 check (max_grant_days between 1 and 366),
  mfa_enforced            boolean not null default true,
  updated_at              timestamptz not null default now(),
  updated_by              uuid references public.profiles(id) on delete set null
);

do $$
begin
  if not exists (select 1 from public.governance_settings) then
    insert into public.governance_settings (ceo_approval_threshold)
    select coalesce((select ceo_approval_threshold from public.company_settings where id), 500000);
  end if;
end $$;

-- Le seuil quitte company_settings (modifiable par les administrateurs).
create or replace function public.ceo_approval_threshold()
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce((select ceo_approval_threshold from public.governance_settings where id), 500000)
$$;
alter table public.company_settings drop column if exists ceo_approval_threshold;

-- Double authentification : niveau aal2 exigé pour les opérations sensibles.
-- Les traitements serveur (service role, tâches planifiées) n'ont pas d'utilisateur.
create or replace function public.mfa_ok()
returns boolean language sql stable security definer set search_path = public as $$
  select auth.uid() is null
      or not coalesce((select mfa_enforced from public.governance_settings where id), true)
      or coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2'
$$;
grant execute on function public.mfa_ok() to authenticated;

create or replace function public.require_mfa()
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if not public.mfa_ok() then
    raise exception 'Double authentification requise pour cette opération : validez votre code de sécurité.' using errcode = '42501';
  end if;
end $$;
grant execute on function public.require_mfa() to authenticated;

create or replace function public.governance_settings_touch()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end $$;
drop trigger if exists governance_settings_touch_bu on public.governance_settings;
create trigger governance_settings_touch_bu before update on public.governance_settings
  for each row execute function public.governance_settings_touch();
drop trigger if exists audit_governance_settings on public.governance_settings;
create trigger audit_governance_settings after update on public.governance_settings
  for each row execute function public.audit_trigger();

alter table public.governance_settings enable row level security;
revoke all on public.governance_settings from anon;
grant select, update on public.governance_settings to authenticated;
drop policy if exists "gouvernance: lecture" on public.governance_settings;
create policy "gouvernance: lecture" on public.governance_settings for select to authenticated
  using (public.is_active_user());
drop policy if exists "gouvernance: modification" on public.governance_settings;
create policy "gouvernance: modification" on public.governance_settings for update to authenticated
  using (public.is_ceo() and public.mfa_ok()) with check (public.is_ceo() and public.mfa_ok());

-- -----------------------------------------------------------------------------
-- P0-02. Protection du compte CEO
-- -----------------------------------------------------------------------------
create or replace function public.profiles_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return new; end if;  -- service role / SQL editor
  if not public.has_perm('users.admin') then
    if new.system_role is distinct from old.system_role
       or new.status is distinct from old.status
       or new.email is distinct from old.email
       or new.hire_date is distinct from old.hire_date then
      raise exception 'Seuls les administrateurs peuvent modifier ce champ' using errcode = '42501';
    end if;
    if (new.manager_id is distinct from old.manager_id or new.primary_unit_id is distinct from old.primary_unit_id)
       and not public.manages_profile(old.id) then
      raise exception 'Seul un responsable peut modifier le rattachement' using errcode = '42501';
    end if;
  end if;
  -- Le compte du CEO n'est modifiable, sur ces champs, que par un CEO.
  if old.system_role = 'ceo'
     and (new.system_role is distinct from old.system_role or new.status is distinct from old.status)
     and not public.is_ceo() then
    raise exception 'Seul le CEO peut modifier le statut ou le rôle d''un CEO' using errcode = '42501';
  end if;
  if new.system_role = 'ceo' and old.system_role <> 'ceo' and not public.is_ceo() then
    raise exception 'Seul le CEO peut désigner un CEO' using errcode = '42501';
  end if;
  if (new.system_role is distinct from old.system_role or new.status is distinct from old.status) then
    perform public.require_mfa();
  end if;
  return new;
end $$;

/** Succession : le CEO transmet sa fonction et devient administrateur. */
create or replace function public.transfer_ceo(p_to uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_ceo() then raise exception 'Seul le CEO peut transmettre sa fonction' using errcode = '42501'; end if;
  perform public.require_mfa();
  if p_to = auth.uid() then raise exception 'Choisissez une autre personne'; end if;
  if not exists (select 1 from public.profiles where id = p_to and status = 'active') then
    raise exception 'Successeur introuvable ou inactif';
  end if;
  update public.profiles set system_role = 'ceo' where id = p_to;
  update public.profiles set system_role = 'admin' where id = auth.uid();
  perform public.notify(p_to, 'governance.ceo', 'Vous êtes désormais CEO de VERIION', null, '/');
end $$;
revoke execute on function public.transfer_ceo(uuid) from public, anon;
grant execute on function public.transfer_ceo(uuid) to authenticated;

create or replace function public.offboard_employee(p_profile uuid, p_date date default current_date)
returns void language plpgsql security definer set search_path = public as $$
declare v_manager uuid; v_name text; v_role public.system_role;
begin
  if not public.has_perm('users.admin') then raise exception 'Permission refusée' using errcode = '42501'; end if;
  perform public.require_mfa();
  if p_profile = auth.uid() then raise exception 'Vous ne pouvez pas vous désactiver vous-même'; end if;
  select manager_id, full_name, system_role into v_manager, v_name, v_role from public.profiles where id = p_profile;
  if v_role = 'ceo' then
    raise exception 'Le départ d''un CEO passe d''abord par la transmission de sa fonction' using errcode = '42501';
  end if;

  update public.unit_memberships set end_date = greatest(start_date, p_date) where profile_id = p_profile and end_date is null;
  delete from public.role_grants where profile_id = p_profile and source = 'manual';
  update public.tasks set assignee_id = null where assignee_id = p_profile and status <> 'done';
  update public.profiles set status = 'offboarded' where id = p_profile;

  insert into public.lifecycle_items (profile_id, kind, title, position, due_date, assignee_id) values
    (p_profile, 'offboarding', 'Récupérer le matériel',                      1, p_date, v_manager),
    (p_profile, 'offboarding', 'Transférer les dossiers et documents',       2, p_date, v_manager),
    (p_profile, 'offboarding', 'Réattribuer les tâches ouvertes',            3, p_date, v_manager),
    (p_profile, 'offboarding', 'Solde de tout compte',                       4, p_date + 15, null),
    (p_profile, 'offboarding', 'Entretien de départ',                        5, p_date, v_manager);

  perform public.notify(v_manager, 'hr.offboarding', 'Départ de ' || coalesce(v_name, 'un collaborateur'),
    'Ses tâches ouvertes ont été désassignées. Checklist de départ créée.', '/rh?onglet=parcours');
end $$;

create or replace function public.clear_access_code(p_profile uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.has_perm('users.admin') then
    raise exception 'Action réservée aux administrateurs' using errcode = '42501';
  end if;
  perform public.require_mfa();
  if exists (select 1 from public.profiles where id = p_profile and system_role = 'ceo') and not public.is_ceo() then
    raise exception 'Seul le CEO peut réinitialiser le code d''un CEO' using errcode = '42501';
  end if;
  delete from public.access_codes where profile_id = p_profile;
end $$;

-- -----------------------------------------------------------------------------
-- P0-03. Permissions réservées et dérogations encadrées
-- -----------------------------------------------------------------------------
alter table public.permissions add column if not exists reserved boolean not null default false;
update public.permissions set reserved = true
 where key in ('approvals.decide', 'finance.admin', 'finance.view', 'hr.admin', 'docs.confidential', 'grants.manage', 'dashboard.exec');

create or replace function public.permission_reserved(p_perm text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select reserved from public.permissions where key = p_perm), true)
$$;

create or replace function public.max_grant_days()
returns int language sql stable security definer set search_path = public as $$
  select coalesce((select max_grant_days from public.governance_settings where id), 90)
$$;

drop policy if exists "grants: dérogation" on public.role_grants;
create policy "grants: dérogation" on public.role_grants for insert to authenticated
  with check (
    public.has_perm('grants.manage') and public.mfa_ok()
    and source = 'manual' and granted_by = auth.uid() and profile_id <> auth.uid()
    and (not public.permission_reserved(permission) or public.is_ceo())
    and expires_at is not null
    and expires_at > now()
    and expires_at <= now() + make_interval(days => public.max_grant_days()) + interval '1 hour'
  );
drop policy if exists "grants: révocation" on public.role_grants;
create policy "grants: révocation" on public.role_grants for delete to authenticated
  using (public.has_perm('grants.manage') and source = 'manual' and public.mfa_ok());

drop policy if exists "templates: gestion" on public.role_templates;
create policy "templates: gestion" on public.role_templates for all to authenticated
  using (public.is_ceo() and public.mfa_ok()) with check (public.is_ceo() and public.mfa_ok());

-- dashboard.exec ouvrait toute la finance, le CRM et tous les projets aux
-- responsables Juridique et RH : il revient à la Direction (et au CFO).
delete from public.role_templates where permission = 'dashboard.exec' and domain in ('legal', 'hr');

-- -----------------------------------------------------------------------------
-- P0-04. Validations : instantané, empreinte, consommation, séparation des tâches
-- -----------------------------------------------------------------------------
alter table public.approval_requests
  add column if not exists subject_snapshot jsonb,
  add column if not exists subject_hash     text,
  add column if not exists consumed_amount  numeric(16,2) not null default 0,
  add column if not exists direct_decision  boolean not null default false;

-- Champs couverts par l'accord, selon le type de sujet. Toute modification de
-- l'un d'eux rend l'accord caduc.
create or replace function public.approval_snapshot(p_kind public.approval_kind, p_row jsonb)
returns jsonb language sql immutable as $$
  select case p_kind
    when 'budget' then jsonb_build_object(
      'unit_id', p_row->'unit_id', 'project_id', p_row->'project_id',
      'fiscal_year', p_row->'fiscal_year', 'amount', p_row->'amount', 'currency', p_row->'currency')
    when 'legal_contract' then jsonb_build_object(
      'title', p_row->'title', 'type', p_row->'type', 'counterparty', p_row->'counterparty',
      'amount', p_row->'amount', 'currency', p_row->'currency', 'effective_date', p_row->'effective_date',
      'end_date', p_row->'end_date', 'auto_renew', p_row->'auto_renew', 'document_id', p_row->'document_id',
      'obligations', p_row->'obligations')
    when 'employment_contract' then jsonb_build_object(
      'profile_id', p_row->'profile_id', 'type', p_row->'type', 'job_title', p_row->'job_title',
      'start_date', p_row->'start_date', 'end_date', p_row->'end_date', 'weekly_hours', p_row->'weekly_hours',
      'gross_monthly', p_row->'gross_monthly')
    when 'project' then jsonb_build_object(
      'name', p_row->'name', 'unit_id', p_row->'unit_id', 'budget', p_row->'budget', 'lead_id', p_row->'lead_id')
    when 'operation_cycle' then jsonb_build_object(
      'project_id', p_row->'project_id', 'kind', p_row->'kind',
      'period_start', p_row->'period_start', 'period_end', p_row->'period_end')
    else null
  end
$$;

create or replace function public.approval_hash(p_kind public.approval_kind, p_row jsonb)
returns text language sql immutable as $$
  select case when public.approval_snapshot(p_kind, p_row) is null then null
              else encode(extensions.digest(public.approval_snapshot(p_kind, p_row)::text, 'sha256'), 'hex') end
$$;

-- Ligne courante du sujet, sous forme JSON.
create or replace function public.approval_subject_row(p_kind public.approval_kind, p_subject uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r jsonb;
begin
  case p_kind
    when 'budget'              then select to_jsonb(b) into r from public.budgets b where b.id = p_subject;
    when 'legal_contract'      then select to_jsonb(c) into r from public.legal_contracts c where c.id = p_subject;
    when 'employment_contract' then select to_jsonb(c) into r from public.employment_contracts c where c.id = p_subject;
    when 'project'             then select to_jsonb(p) into r from public.projects p where p.id = p_subject;
    when 'operation_cycle'     then select to_jsonb(c) into r from public.operation_cycles c where c.id = p_subject;
    else r := null;
  end case;
  return r;
end $$;

/** Accord valide pour exactement ce contenu ? */
create or replace function public.approval_valid(p_kind public.approval_kind, p_subject uuid, p_row jsonb)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.approval_requests
     where kind = p_kind and subject_id = p_subject and status = 'approved'
       and subject_hash is not distinct from public.approval_hash(p_kind, p_row)
  )
$$;

create or replace function public.approval_granted(p_kind public.approval_kind, p_subject uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.approval_valid(p_kind, p_subject, public.approval_subject_row(p_kind, p_subject))
$$;

create or replace function public.approval_pending(p_kind public.approval_kind, p_subject uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.approval_requests where kind = p_kind and subject_id = p_subject and status = 'pending')
$$;

/** Qui peut demander un accord pour ce sujet ; libellé, montant et rattachements dérivés du sujet. */
create or replace function public.approval_subject_info(p_kind public.approval_kind, p_subject uuid,
  out allowed boolean, out label text, out amount numeric, out currency text, out unit_id uuid, out project_id uuid)
language plpgsql stable security definer set search_path = public as $$
declare r jsonb := public.approval_subject_row(p_kind, p_subject);
begin
  allowed := false;
  if r is null then return; end if;
  currency := coalesce(r->>'currency', 'XOF');
  case p_kind
    when 'budget' then
      allowed := public.has_perm('finance.admin')
              or ((r->>'unit_id') is not null and public.has_perm('unit.manage', (r->>'unit_id')::uuid))
              or ((r->>'project_id') is not null and public.can_manage_project((r->>'project_id')::uuid));
      amount := (r->>'amount')::numeric;
      unit_id := (r->>'unit_id')::uuid; project_id := (r->>'project_id')::uuid;
      label := 'Budget ' || (r->>'fiscal_year') || ' — ' || coalesce(
        (select name from public.org_units where id = (r->>'unit_id')::uuid),
        (select name from public.projects where id = (r->>'project_id')::uuid), 'sans rattachement');
    when 'legal_contract' then
      allowed := public.has_perm('legal.admin') or (r->>'owner_id')::uuid = auth.uid();
      amount := (r->>'amount')::numeric;
      unit_id := (r->>'unit_id')::uuid; project_id := (r->>'project_id')::uuid;
      label := 'Contrat ' || (r->>'reference') || ' — ' || (r->>'title') || ' (' || (r->>'counterparty') || ')';
    when 'employment_contract' then
      allowed := public.has_perm('hr.admin');
      amount := (r->>'gross_monthly')::numeric;
      label := 'Contrat de travail — ' || coalesce((select full_name from public.profiles where id = (r->>'profile_id')::uuid), '?')
               || coalesce(' · ' || (r->>'job_title'), '') || ' (' || upper(r->>'type') || ')';
    when 'project' then
      allowed := public.can_manage_project(p_subject);
      amount := (r->>'budget')::numeric;
      unit_id := (r->>'unit_id')::uuid; project_id := p_subject;
      label := 'Lancement du projet ' || (r->>'name');
    when 'operation_cycle' then
      allowed := public.can_plan_project((r->>'project_id')::uuid);
      project_id := (r->>'project_id')::uuid;
      label := 'Calendrier mensuel — ' || coalesce((select name from public.projects where id = (r->>'project_id')::uuid), 'projet')
               || ' (' || to_char((r->>'period_start')::date, 'MM/YYYY') || ')';
    else
      allowed := false;
  end case;
end $$;

/** Décision directe du CEO : tracée dans le registre comme un accord auto-approuvé. */
create or replace function public.record_ceo_decision(p_kind public.approval_kind, p_subject uuid, p_row jsonb, p_note text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; info record;
begin
  select * into info from public.approval_subject_info(p_kind, p_subject);
  update public.approval_requests set status = 'cancelled'
   where kind = p_kind and subject_id = p_subject and status = 'pending';
  insert into public.approval_requests (kind, subject_id, subject_label, amount, currency, unit_id, project_id,
                                        status, requested_by, decided_by, decided_at, decision_note,
                                        subject_snapshot, subject_hash, direct_decision)
  values (p_kind, p_subject, coalesce(info.label, p_kind::text), info.amount, coalesce(info.currency, 'XOF'),
          info.unit_id, info.project_id, 'approved', auth.uid(), auth.uid(), now(),
          coalesce(p_note, 'Décision directe du CEO'),
          public.approval_snapshot(p_kind, p_row), public.approval_hash(p_kind, p_row), true)
  returning id into v_id;
  return v_id;
end $$;
revoke execute on function public.record_ceo_decision(public.approval_kind, uuid, jsonb, text) from public, anon, authenticated;

/**
 * Garde commune : l'opération engageante n'est permise qu'avec un accord valide
 * pour ce contenu. Le CEO passe, mais sa décision est enregistrée.
 */
create or replace function public.require_approval(p_kind public.approval_kind, p_subject uuid, p_row jsonb, p_message text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  if public.approval_valid(p_kind, p_subject, p_row) then return; end if;
  if public.is_ceo() then
    perform public.record_ceo_decision(p_kind, p_subject, p_row);
    return;
  end if;
  raise exception '%', p_message using errcode = '42501';
end $$;
revoke execute on function public.require_approval(public.approval_kind, uuid, jsonb, text) from public, anon, authenticated;

/** Pendant l'attente d'une décision, le contenu soumis est gelé. */
create or replace function public.approval_freeze(p_kind public.approval_kind, p_subject uuid, p_old jsonb, p_new jsonb)
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is not null
     and public.approval_hash(p_kind, p_old) is distinct from public.approval_hash(p_kind, p_new)
     and public.approval_pending(p_kind, p_subject) then
    raise exception 'Une demande d''accord est en cours sur ce contenu : retirez-la avant de le modifier.' using errcode = '42501';
  end if;
end $$;
revoke execute on function public.approval_freeze(public.approval_kind, uuid, jsonb, jsonb) from public, anon, authenticated;

/** Soumet une décision au CEO. Renvoie la demande déjà en attente s'il y en a une. */
create or replace function public.request_approval(
  p_kind public.approval_kind, p_subject uuid, p_label text,
  p_amount numeric default null, p_justification text default null,
  p_unit uuid default null, p_project uuid default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; r record; info record; v_row jsonb; v_label text; v_amount numeric; v_currency text := 'XOF';
begin
  if not public.is_active_user() then raise exception 'Compte inactif' using errcode = '42501'; end if;

  select id into v_id from public.approval_requests
   where kind = p_kind and subject_id = p_subject and status = 'pending' and p_subject is not null;
  if v_id is not null then return v_id; end if;

  v_row := case when p_subject is not null then public.approval_subject_row(p_kind, p_subject) end;
  if public.approval_snapshot(p_kind, '{}'::jsonb) is not null then
    -- Sujet réel : la base, et non le demandeur, décrit ce qui est soumis.
    if v_row is null then raise exception 'Objet de la demande introuvable'; end if;
    select * into info from public.approval_subject_info(p_kind, p_subject);
    if not info.allowed then
      raise exception 'Seul le responsable de cet objet peut en demander l''accord' using errcode = '42501';
    end if;
    v_label := info.label; v_amount := info.amount; v_currency := coalesce(info.currency, 'XOF');
    p_unit := info.unit_id; p_project := info.project_id;
  else
    -- Dépense ou décision libre : décrite par le demandeur.
    if length(trim(coalesce(p_label, ''))) < 3 then raise exception 'Précisez l''objet de la demande'; end if;
    v_label := trim(p_label); v_amount := p_amount;
    if p_kind = 'expense' and coalesce(p_amount, 0) <= 0 then raise exception 'Indiquez le montant de la dépense'; end if;
  end if;

  -- Le CEO décide directement : sa demande est enregistrée comme décision.
  if public.is_ceo() then
    if v_row is not null then
      return public.record_ceo_decision(p_kind, p_subject, v_row, nullif(trim(coalesce(p_justification, '')), ''));
    end if;
    insert into public.approval_requests (kind, subject_id, subject_label, amount, currency, justification, unit_id, project_id,
                                          status, requested_by, decided_by, decided_at, decision_note, direct_decision)
    values (p_kind, p_subject, v_label, v_amount, v_currency, nullif(trim(coalesce(p_justification, '')), ''), p_unit, p_project,
            'approved', auth.uid(), auth.uid(), now(), 'Décision directe du CEO', true)
    returning id into v_id;
    return v_id;
  end if;

  insert into public.approval_requests (kind, subject_id, subject_label, amount, currency, justification, unit_id, project_id,
                                        subject_snapshot, subject_hash)
  values (p_kind, p_subject, v_label, v_amount, v_currency, nullif(trim(coalesce(p_justification, '')), ''), p_unit, p_project,
          public.approval_snapshot(p_kind, v_row), public.approval_hash(p_kind, v_row))
  returning id into v_id;

  for r in
    select p.id from public.profiles p where p.status = 'active' and p.system_role = 'ceo'
    union
    select g.profile_id from public.role_grants g
     where g.permission = 'approvals.decide' and (g.expires_at is null or g.expires_at > now())
  loop
    if r.id is distinct from auth.uid() then
      perform public.notify(r.id, 'approval.requested', 'Décision attendue : ' || v_label,
        case when v_amount is not null then to_char(v_amount, 'FM999G999G999G990') || ' ' || v_currency else null end,
        '/validations?demande=' || v_id);
    end if;
  end loop;
  return v_id;
end $$;

/** Accord ou refus : jamais sur sa propre demande, toujours motivé côté refus. */
create or replace function public.decide_approval(p_id uuid, p_approve boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare a public.approval_requests; v_row jsonb;
begin
  if not public.can_decide_approvals() then
    raise exception 'Cette décision revient au CEO' using errcode = '42501';
  end if;
  perform public.require_mfa();
  select * into a from public.approval_requests where id = p_id for update;
  if a.id is null then raise exception 'Demande introuvable'; end if;
  if a.status <> 'pending' then raise exception 'Cette demande a déjà été traitée'; end if;
  if a.requested_by = auth.uid() then
    raise exception 'Vous ne pouvez pas statuer sur votre propre demande' using errcode = '42501';
  end if;
  if not p_approve and length(trim(coalesce(p_note, ''))) < 3 then
    raise exception 'Motivez le refus : la personne doit savoir quoi corriger';
  end if;
  -- Le contenu a-t-il changé depuis la demande ? (gel contourné par le service role, par ex.)
  if p_approve and a.subject_id is not null and a.subject_hash is not null then
    v_row := public.approval_subject_row(a.kind, a.subject_id);
    if public.approval_hash(a.kind, v_row) is distinct from a.subject_hash then
      raise exception 'Le contenu a changé depuis la demande : elle doit être soumise à nouveau.';
    end if;
  end if;

  update public.approval_requests
     set status = case when p_approve then 'approved' else 'rejected' end::public.approval_status,
         decided_by = auth.uid(), decided_at = now(), decision_note = nullif(trim(coalesce(p_note, '')), '')
   where id = p_id;

  perform public.notify(a.requested_by,
    case when p_approve then 'approval.approved' else 'approval.rejected' end,
    case when p_approve then 'Accord : ' else 'Refus : ' end || a.subject_label,
    nullif(trim(coalesce(p_note, '')), ''), '/validations?demande=' || a.id);
end $$;

-- Budgets : activation au-delà du seuil soumise à un accord sur ce montant précis.
create or replace function public.budgets_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' then
    perform public.approval_freeze('budget', new.id, to_jsonb(old), to_jsonb(new));
  end if;
  if new.status = 'active' and new.amount > public.ceo_approval_threshold() then
    perform public.require_approval('budget', new.id, to_jsonb(new),
      'Ce budget dépasse le seuil : l''accord du CEO sur ce montant est requis avant activation.');
  end if;
  return new;
end $$;

-- Dépenses : un accord se consomme ; au-delà du seuil, il est obligatoire.
create or replace function public.transactions_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare a public.approval_requests; v_cum numeric; r record;
begin
  if tg_op <> 'INSERT' or new.type <> 'expense' or new.amount <= 0 then return new; end if;

  if new.approval_id is not null then
    select * into a from public.approval_requests where id = new.approval_id for update;
    if a.id is null or a.kind <> 'expense' or a.status <> 'approved' then
      raise exception 'L''accord indiqué n''est pas un accord de dépense valide.' using errcode = '42501';
    end if;
    if a.consumed_amount + new.amount > coalesce(a.amount, 0) then
      raise exception 'Accord insuffisant : % XOF déjà engagés sur % accordés.',
        to_char(a.consumed_amount, 'FM999G999G999G990'), to_char(coalesce(a.amount, 0), 'FM999G999G999G990')
        using errcode = '42501';
    end if;
    update public.approval_requests set consumed_amount = consumed_amount + new.amount where id = a.id;
  elsif auth.uid() is not null and new.amount > public.ceo_approval_threshold() then
    if public.is_ceo() then
      insert into public.approval_requests (kind, subject_label, amount, currency, status, requested_by, decided_by,
                                            decided_at, decision_note, consumed_amount, direct_decision)
      values ('expense', coalesce(new.description, new.category), new.amount, new.currency, 'approved',
              auth.uid(), auth.uid(), now(), 'Décision directe du CEO', new.amount, true)
      returning id into new.approval_id;
    else
      raise exception 'Dépense au-dessus du seuil : rattachez-la à un accord du CEO portant au moins ce montant.' using errcode = '42501';
    end if;
  elsif auth.uid() is not null then
    -- Contrôle anti-fractionnement : alerte (sans blocage) si les dépenses
    -- d'un même objet dépassent le seuil sur 30 jours.
    select coalesce(sum(t.amount), 0) + new.amount into v_cum
      from public.transactions t
     where t.type = 'expense' and t.amount > 0 and t.approval_id is null
       and t.occurred_on > new.occurred_on - 30
       and (t.category = new.category or (new.account_id is not null and t.account_id = new.account_id));
    if v_cum > public.ceo_approval_threshold() then
      for r in select p.id from public.profiles p where p.status = 'active' and p.system_role = 'ceo' loop
        perform public.notify(r.id, 'approval.split_alert', 'Dépenses cumulées au-dessus du seuil',
          'Catégorie « ' || new.category || ' » : ' || to_char(v_cum, 'FM999G999G999G990') || ' XOF sur 30 jours sans accord.',
          '/finance?onglet=operations');
      end loop;
    end if;
  end if;
  return new;
end $$;

create or replace function public.projects_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' then
    perform public.approval_freeze('project', new.id, to_jsonb(old), to_jsonb(new));
  end if;
  if new.status = 'active' and (tg_op = 'INSERT' or old.status <> 'active') then
    perform public.require_approval('project', new.id, to_jsonb(new),
      'Le lancement d''un projet demande l''accord du CEO. Soumettez-le depuis la fiche du projet.');
    new.approved_at := coalesce(new.approved_at, now());
    new.approved_by := coalesce(new.approved_by, auth.uid());
  end if;
  return new;
end $$;

alter table public.employment_contracts add column if not exists gross_monthly numeric(14,2) check (gross_monthly is null or gross_monthly >= 0);

create or replace function public.employment_contracts_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' then
    perform public.approval_freeze('employment_contract', new.id, to_jsonb(old), to_jsonb(new));
    if old.status in ('signed', 'ended') and auth.uid() is not null
       and public.approval_hash('employment_contract', to_jsonb(old)) is distinct from public.approval_hash('employment_contract', to_jsonb(new)) then
      raise exception 'Un contrat signé ne se modifie pas : établissez un avenant (nouveau contrat).' using errcode = '42501';
    end if;
  end if;
  if new.status = 'signed' and (tg_op = 'INSERT' or old.status <> 'signed') then
    perform public.require_approval('employment_contract', new.id, to_jsonb(new),
      'La signature d''un contrat de travail demande l''accord du CEO.');
    new.approved_at := coalesce(new.approved_at, now());
    new.approved_by := coalesce(new.approved_by, auth.uid());
  end if;
  return new;
end $$;

-- Le salaire convenu s'applique à la signature, pas avant.
create or replace function public.employment_contracts_after_sign()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'signed' and (tg_op = 'INSERT' or old.status <> 'signed') and new.gross_monthly is not null then
    insert into public.salaries (profile_id, gross_monthly, effective_from, notes, created_by)
    values (new.profile_id, new.gross_monthly, new.start_date, 'Contrat signé', auth.uid());
  end if;
  return null;
end $$;
drop trigger if exists employment_contracts_after_sign_aiu on public.employment_contracts;
create trigger employment_contracts_after_sign_aiu after insert or update on public.employment_contracts
  for each row execute function public.employment_contracts_after_sign();

create or replace function public.legal_contracts_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' then
    perform public.approval_freeze('legal_contract', new.id, to_jsonb(old), to_jsonb(new));
    if old.status in ('signed', 'active', 'expired', 'terminated') and auth.uid() is not null
       and public.approval_hash('legal_contract', to_jsonb(old)) is distinct from public.approval_hash('legal_contract', to_jsonb(new)) then
      raise exception 'Un contrat signé ne se modifie pas : établissez un avenant.' using errcode = '42501';
    end if;
  end if;
  if new.status in ('signed', 'active') and (tg_op = 'INSERT' or old.status not in ('signed', 'active')) then
    perform public.require_approval('legal_contract', new.id, to_jsonb(new),
      'Ce contrat doit recevoir l''accord du CEO avant signature.');
    new.signed_on := coalesce(new.signed_on, current_date);
    new.effective_date := coalesce(new.effective_date, new.signed_on);
  end if;
  return new;
end $$;

create or replace function public.operation_cycles_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.approval_freeze('operation_cycle', new.id, to_jsonb(old), to_jsonb(new));
  return new;
end $$;
drop trigger if exists operation_cycles_guard_bu on public.operation_cycles;
create trigger operation_cycles_guard_bu before update on public.operation_cycles
  for each row execute function public.operation_cycles_guard();

create or replace function public.publish_operation_cycle(p_cycle uuid)
returns void language plpgsql security definer set search_path = public as $$
declare c public.operation_cycles; r record;
begin
  select * into c from public.operation_cycles where id = p_cycle for update;
  if c.id is null then raise exception 'Cycle introuvable'; end if;
  if not public.can_plan_project(c.project_id) then raise exception 'Permission refusée' using errcode = '42501'; end if;
  if c.status = 'published' then return; end if;
  if not exists (select 1 from public.operation_items where cycle_id = p_cycle) then
    raise exception 'Ajoutez au moins une grande ligne avant de publier ce calendrier.';
  end if;

  if c.kind = 'monthly' then
    if public.is_ceo() then
      if not public.approval_valid('operation_cycle', p_cycle, to_jsonb(c)) then
        perform public.record_ceo_decision('operation_cycle', p_cycle, to_jsonb(c));
      end if;
    elsif not public.approval_valid('operation_cycle', p_cycle, to_jsonb(c)) then
      perform public.request_approval('operation_cycle', p_cycle, null, null, c.focus);
      update public.operation_cycles set status = 'pending_ceo' where id = p_cycle;
      return;
    end if;
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

-- Effets d'une décision : publication, activation, retour en rédaction.
create or replace function public.approval_requests_apply()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = old.status or old.status <> 'pending' or new.subject_id is null then return null; end if;
  if new.status = 'approved' then
    if new.kind = 'operation_cycle' then
      update public.operation_cycles set status = 'published', published_at = now()
       where id = new.subject_id and status <> 'published';
    elsif new.kind = 'budget' then
      update public.budgets set status = 'active' where id = new.subject_id and status = 'draft';
    end if;
  elsif new.status in ('rejected', 'cancelled') then
    if new.kind = 'operation_cycle' then
      update public.operation_cycles set status = 'draft' where id = new.subject_id and status = 'pending_ceo';
    elsif new.kind = 'legal_contract' then
      update public.legal_contracts set status = 'legal_review' where id = new.subject_id and status = 'pending_ceo';
    elsif new.kind = 'employment_contract' then
      update public.employment_contracts set status = 'draft' where id = new.subject_id and status = 'pending_ceo';
    end if;
  end if;
  return null;
end $$;

-- Le registre des validations ne s'écrit que par les fonctions ci-dessus.
revoke insert, update, delete on public.approval_requests from authenticated, anon;

-- -----------------------------------------------------------------------------
-- P0-05. Tâches : la vérification ne se lève pas par le titulaire
-- -----------------------------------------------------------------------------
create or replace function public.tasks_protect_review()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or current_setting('veriion.task_flow', true) = 'on' then return new; end if;
  if old.assignee_id = auth.uid()
     and coalesce(old.reviewer_id, old.reporter_id) is distinct from auth.uid()
     and not (old.project_id is not null and public.can_manage_project(old.project_id)) then
    if new.requires_validation is distinct from old.requires_validation
       or new.reviewer_id is distinct from old.reviewer_id
       or new.reporter_id is distinct from old.reporter_id
       or new.validated_by is distinct from old.validated_by
       or new.validated_at is distinct from old.validated_at then
      raise exception 'La vérification de cette tâche revient à la personne qui l''a confiée.' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists tasks_protect_review_bu on public.tasks;
create trigger tasks_protect_review_bu before update on public.tasks
  for each row execute function public.tasks_protect_review();

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
  perform set_config('veriion.task_flow', 'on', true);

  v_reviewer := coalesce(t.reviewer_id, t.reporter_id);
  v_link := case when t.project_id is not null then '/projets/' || t.project_id || '?tache=' || t.id else '/taches' end;

  if v_reviewer is null or v_reviewer = auth.uid() then
    update public.tasks set status = 'done', submitted_at = now(), review_note = nullif(trim(coalesce(p_note, '')), '')
     where id = p_task;
  else
    update public.tasks
       set status = 'review', submitted_at = now(), requires_validation = true,
           reviewer_id = v_reviewer, review_note = nullif(trim(coalesce(p_note, '')), '')
     where id = p_task;
    perform public.notify(v_reviewer, 'task.submitted', 'À vérifier : ' || t.title,
      nullif(trim(coalesce(p_note, '')), ''), v_link);
  end if;
  perform set_config('veriion.task_flow', 'off', true);
end $$;

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
  if t.assignee_id = auth.uid() and coalesce(t.reviewer_id, t.reporter_id) is distinct from auth.uid() and not public.is_ceo() then
    raise exception 'Vous ne pouvez pas valider votre propre tâche' using errcode = '42501';
  end if;
  if not p_approve and length(trim(coalesce(p_note, ''))) < 3 then
    raise exception 'Indiquez ce qui doit être repris';
  end if;
  perform set_config('veriion.task_flow', 'on', true);

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
  perform set_config('veriion.task_flow', 'off', true);
end $$;

-- -----------------------------------------------------------------------------
-- P0-07. Double authentification sur les opérations sensibles
-- -----------------------------------------------------------------------------
-- Politiques restrictives : elles s'ajoutent (ET logique) aux politiques existantes.
do $$
declare t text; c text;
begin
  foreach t in array array['budgets', 'invoices', 'invoice_lines', 'transactions', 'employment_contracts', 'legal_contracts', 'company_settings'] loop
    foreach c in array array['insert', 'update', 'delete'] loop
      execute format('drop policy if exists %I on public.%I', 'mfa: ' || c, t);
      if c = 'insert' then
        execute format('create policy %I on public.%I as restrictive for insert to authenticated with check (public.mfa_ok())', 'mfa: ' || c, t);
      else
        execute format('create policy %I on public.%I as restrictive for %s to authenticated using (public.mfa_ok())', 'mfa: ' || c, t, c);
      end if;
    end loop;
  end loop;
end $$;

-- Salaires : chacun voit le sien ; les autres lectures exigent la double authentification.
drop policy if exists "mfa: salaires" on public.salaries;
create policy "mfa: salaires" on public.salaries as restrictive for all to authenticated
  using (profile_id = auth.uid() or public.mfa_ok()) with check (public.mfa_ok());

-- Documents confidentiels : double authentification exigée (sauf pour leur auteur).
create or replace function public.document_access(p_doc uuid)
returns int language plpgsql stable security definer set search_path = public as $$
declare
  d public.documents;
  r int := 0;
  direct int;
begin
  if p_doc is null or not public.is_active_user() then return 0; end if;
  select * into d from public.documents where id = p_doc;
  if d.id is null then return 0; end if;

  if d.owner_id = auth.uid() then return 3; end if;
  if d.classification = 'confidential' and not public.mfa_ok() then return 0; end if;
  if d.folder_id is not null then r := public.folder_access(d.folder_id); end if;
  if d.account_id is not null and public.can_read_crm() then r := greatest(r, 1); end if;

  select max(public.share_rank(sh.role)) into direct
  from public.shares sh
  where sh.document_id = d.id
    and (sh.expires_at is null or sh.expires_at > now())
    and (sh.profile_id = auth.uid() or (sh.unit_id is not null and public.in_unit(sh.unit_id)));
  direct := coalesce(direct, 0);

  if d.classification = 'restricted' and r < 2 then r := 0; end if;
  if d.classification = 'confidential' and r < 3 and not public.has_perm('docs.confidential') then r := 0; end if;
  if d.classification = 'confidential' and public.has_perm('docs.confidential') then r := greatest(r, 1); end if;

  return greatest(r, direct);
end $$;

-- -----------------------------------------------------------------------------
-- Rappel des décisions en attente : délai pris dans les paramètres de gouvernance.
-- -----------------------------------------------------------------------------
create or replace function public.generate_extra_reminders()
returns int language plpgsql security definer set search_path = public as $$
declare today date := (now() at time zone 'Africa/Porto-Novo')::date; n int := 0; r record;
  v_days int := coalesce((select approval_reminder_days from public.governance_settings where id), 2);
begin
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

  for r in
    select p.id from public.profiles p where p.status = 'active' and p.system_role = 'ceo'
      and exists (select 1 from public.approval_requests a where a.status = 'pending' and a.created_at < now() - make_interval(days => v_days))
  loop
    perform public.notify(r.id, 'reminder.approvals', 'Des décisions attendent votre accord', null, '/validations');
    n := n + 1;
  end loop;

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

-- Les modèles de droits ont changé : recalcul pour tous.
do $$ declare r record; begin
  for r in select id from public.profiles where status = 'active' loop
    perform public.sync_auto_grants(r.id);
  end loop;
end $$;

-- >>>>>>>>>> supabase/migrations/20261012000012_p0_durcissement.sql
-- =============================================================================
-- VERIION OS — Migration 12 : durcissement des privilèges (phase 0, lot P0-09)
-- =============================================================================
-- Sur Supabase, tout objet créé dans « public » est accordé par défaut aux rôles
-- de l'API (anon, authenticated). Les migrations 5 à 11 s'appuyaient sur ces
-- privilèges implicites : la table access_codes, censée n'être accessible par
-- aucun grant, l'était donc en lecture (la RLS sans politique la protégeait
-- seule). On retire ici explicitement tout accès anonyme et les grants non voulus.
-- =============================================================================

-- 1. Le rôle anonyme n'a accès à rien dans le schéma public.
revoke all on all tables    in schema public from anon;
revoke all on all sequences in schema public from anon;

-- Fonctions : retire l'exécution à PUBLIC et à anon, en conservant pour
-- « authenticated » exactement ce qu'il pouvait déjà exécuter.
do $$
declare f record; keep boolean;
begin
  for f in
    select p.oid, p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
  loop
    keep := has_function_privilege('authenticated', f.oid, 'execute');
    execute format('revoke execute on function %s from public, anon', f.sig);
    if keep then execute format('grant execute on function %s to authenticated', f.sig); end if;
  end loop;
end $$;

-- Et pour les objets créés par les prochaines migrations.
alter default privileges in schema public revoke all on tables    from anon;
alter default privileges in schema public revoke all on sequences from anon;
alter default privileges in schema public revoke execute on functions from public, anon;

-- 2. Tables qui ne doivent être lues que par leurs fonctions security definer.
revoke all on public.access_codes from authenticated;

-- 3. Inscriptions : seul le domaine de l'entreprise est accepté, invitation ou non.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  has_ceo boolean;
  v_domain text := coalesce((select email_domain from public.company_settings where id), 'veriion.com');
begin
  if lower(split_part(coalesce(new.email, ''), '@', 2)) <> lower(v_domain) then
    raise exception 'Seules les adresses @% peuvent ouvrir un compte VERIION OS', v_domain using errcode = '42501';
  end if;
  select exists(select 1 from public.profiles where system_role = 'ceo') into has_ceo;
  insert into public.profiles (id, email, first_name, last_name, job_title, primary_unit_id, system_role, hire_date)
  values (
    new.id,
    lower(new.email),
    coalesce(nullif(meta->>'first_name', ''), initcap(split_part(split_part(new.email, '@', 1), '.', 1))),
    coalesce(nullif(meta->>'last_name', ''),  initcap(split_part(split_part(new.email, '@', 1), '.', 2))),
    meta->>'job_title',
    nullif(meta->>'primary_unit_id', '')::uuid,
    case when has_ceo then 'employee'::public.system_role else 'ceo'::public.system_role end,
    current_date
  )
  on conflict (id) do nothing;
  return new;
end $$;

-- >>>>>>>>>> supabase/migrations/20261012000013_p0_integrite_financiere.sql
-- =============================================================================
-- VERIION OS — Migration 13 : intégrité financière minimale (phase 0, lot P0-08)
-- =============================================================================
--   * une facture émise ne se modifie plus (montants, lignes, client) ;
--   * aucune facture ni opération ne se supprime : on annule par contre-passation ;
--   * annuler un encaissement passe une écriture inverse au lieu d'effacer le revenu ;
--   * numérotation des factures continue, par exercice ;
--   * la fusion d'unités ne réécrit plus l'historique financier.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Opérations : immuables, annulées par contre-passation
-- -----------------------------------------------------------------------------
alter table public.transactions
  add column if not exists reverses_id uuid references public.transactions(id) on delete restrict,
  add column if not exists reversed_by uuid references public.transactions(id) on delete set null,
  add column if not exists reversal_reason text;

alter table public.transactions drop constraint if exists transactions_amount_check;
alter table public.transactions drop constraint if exists transactions_amount_sign;
alter table public.transactions add constraint transactions_amount_sign
  check ((reverses_id is null and amount > 0) or (reverses_id is not null and amount < 0));
create unique index if not exists transactions_one_reversal on public.transactions(reverses_id) where reverses_id is not null;

-- Une facture ne porte qu'un revenu actif (non contre-passé).
alter table public.transactions drop constraint if exists transactions_invoice_id_key;
drop index if exists public.transactions_invoice_id_key;
create unique index if not exists transactions_invoice_active
  on public.transactions(invoice_id) where invoice_id is not null and reverses_id is null and reversed_by is null;


/** Contre-passe une opération : écriture inverse datée du jour, motivée. */
create or replace function public.reverse_transaction(p_id uuid, p_reason text)
returns uuid language plpgsql security definer set search_path = public as $$
declare t public.transactions; v_id uuid;
begin
  if not public.has_perm('finance.admin') then raise exception 'Permission refusée' using errcode = '42501'; end if;
  perform public.require_mfa();
  if length(trim(coalesce(p_reason, ''))) < 3 then raise exception 'Indiquez le motif de l''annulation'; end if;
  select * into t from public.transactions where id = p_id for update;
  if t.id is null then raise exception 'Opération introuvable'; end if;
  if t.reverses_id is not null then raise exception 'Une contre-passation ne se contre-passe pas'; end if;
  if t.reversed_by is not null then raise exception 'Cette opération a déjà été annulée'; end if;
  if t.invoice_id is not null and auth.uid() is not null and current_setting('veriion.invoice_flow', true) is distinct from 'on' then
    raise exception 'Ce revenu provient d''une facture : annulez l''encaissement depuis la facture.';
  end if;

  insert into public.transactions (type, amount, currency, occurred_on, category, description, unit_id, project_id,
                                   account_id, product, country, reference, reverses_id, reversal_reason, created_by)
  values (t.type, -t.amount, t.currency, current_date, t.category, 'Annulation — ' || coalesce(t.description, t.category),
          t.unit_id, t.project_id, t.account_id, t.product, t.country, t.reference, t.id, trim(p_reason), auth.uid())
  returning id into v_id;

  -- Seule mise à jour système permise sur la ligne d'origine.
  perform set_config('veriion.txn_system', 'on', true);
  update public.transactions set reversed_by = v_id, reversal_reason = trim(p_reason) where id = t.id;
  perform set_config('veriion.txn_system', 'off', true);

  -- Un accord de dépense retrouve le montant libéré.
  if t.approval_id is not null and t.type = 'expense' then
    update public.approval_requests set consumed_amount = greatest(0, consumed_amount - t.amount) where id = t.approval_id;
  end if;
  return v_id;
end $$;
revoke execute on function public.reverse_transaction(uuid, text) from public, anon;
grant execute on function public.reverse_transaction(uuid, text) to authenticated;

-- Le drapeau système autorise uniquement le marquage « contre-passée ».
create or replace function public.transactions_immutable()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    if auth.uid() is not null then
      raise exception 'Une opération enregistrée ne se supprime pas : contre-passez-la.' using errcode = '42501';
    end if;
    return old;
  end if;
  if current_setting('veriion.txn_system', true) = 'on'
     and new.reversed_by is distinct from old.reversed_by
     and (to_jsonb(new) - 'reversed_by' - 'reversal_reason') = (to_jsonb(old) - 'reversed_by' - 'reversal_reason') then
    return new;
  end if;
  if auth.uid() is not null and (
       new.type is distinct from old.type or new.amount is distinct from old.amount
    or new.currency is distinct from old.currency or new.occurred_on is distinct from old.occurred_on
    or new.unit_id is distinct from old.unit_id or new.project_id is distinct from old.project_id
    or new.account_id is distinct from old.account_id or new.invoice_id is distinct from old.invoice_id
    or new.approval_id is distinct from old.approval_id or new.reverses_id is distinct from old.reverses_id
    or new.reversed_by is distinct from old.reversed_by) then
    raise exception 'Le montant, la date et les rattachements d''une opération ne se modifient pas : contre-passez-la puis ressaisissez-la.' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists transactions_immutable_bud on public.transactions;
create trigger transactions_immutable_bud before update or delete on public.transactions
  for each row execute function public.transactions_immutable();

drop policy if exists "transactions: gestion" on public.transactions;
drop policy if exists "transactions: saisie" on public.transactions;
drop policy if exists "transactions: correction" on public.transactions;
create policy "transactions: saisie" on public.transactions for insert to authenticated
  with check (public.has_perm('finance.admin') and reverses_id is null);
create policy "transactions: correction" on public.transactions for update to authenticated
  using (public.has_perm('finance.admin')) with check (public.has_perm('finance.admin'));
-- Aucune politique de suppression : la contre-passation est la seule voie.

-- -----------------------------------------------------------------------------
-- 2. Factures : numérotation continue, verrouillage après émission
-- -----------------------------------------------------------------------------
alter table public.invoices add column if not exists sent_at timestamptz;
update public.invoices set sent_at = coalesce(sent_at, updated_at) where status in ('sent', 'paid', 'overdue');

create table if not exists public.invoice_counters (
  scope text not null,          -- série (préfixe), par exemple « FAC »
  year  int  not null,
  last  int  not null default 0,
  primary key (scope, year)
);
alter table public.invoice_counters enable row level security;
revoke all on public.invoice_counters from anon, authenticated;

-- Reprend les numéros existants pour que la série continue sans collision.
insert into public.invoice_counters (scope, year, last)
select 'FAC', split_part(number, '-', 2)::int, max(split_part(number, '-', 3)::int)
  from public.invoices where number ~ '^FAC-[0-9]{4}-[0-9]+$'
 group by split_part(number, '-', 2)
on conflict (scope, year) do update set last = greatest(public.invoice_counters.last, excluded.last);

create or replace function public.next_invoice_number(p_scope text, p_date date)
returns text language plpgsql security definer set search_path = public as $$
declare v_year int := extract(year from coalesce(p_date, current_date))::int; v_n int;
begin
  insert into public.invoice_counters (scope, year, last) values (p_scope, v_year, 1)
  on conflict (scope, year) do update set last = public.invoice_counters.last + 1
  returning last into v_n;
  return p_scope || '-' || v_year || '-' || lpad(v_n::text, 5, '0');
end $$;
revoke execute on function public.next_invoice_number(text, date) from public, anon, authenticated;

alter table public.invoices alter column number drop default;

create or replace function public.invoices_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.number is null or auth.uid() is not null then
    new.number := public.next_invoice_number('FAC', new.issue_date);
  end if;
  new.status := 'draft';
  new.sent_at := null; new.paid_at := null;
  return new;
end $$;
drop trigger if exists invoices_bi on public.invoices;
create trigger invoices_bi before insert on public.invoices
  for each row execute function public.invoices_before_insert();

create or replace function public.invoices_before_update()
returns trigger language plpgsql as $$
declare allowed boolean;
begin
  -- Transitions de statut permises.
  if new.status is distinct from old.status then
    allowed := case old.status
      when 'draft'     then new.status in ('sent', 'cancelled')
      when 'sent'      then new.status in ('paid', 'overdue', 'cancelled')
      when 'overdue'   then new.status in ('paid', 'sent', 'cancelled')
      when 'paid'      then new.status in ('sent')
      when 'cancelled' then new.status = 'draft' and old.sent_at is null
      else false end;
    if not allowed then
      raise exception 'Passage de « % » à « % » impossible pour une facture.', old.status, new.status using errcode = '23514';
    end if;
  end if;

  -- Une facture émise est figée : seuls le statut, l'échéance et les notes évoluent.
  if old.status <> 'draft' and current_setting('veriion.invoice_recompute', true) is distinct from 'on' and (
       new.number is distinct from old.number or new.account_id is distinct from old.account_id
    or new.issue_date is distinct from old.issue_date or new.currency is distinct from old.currency
    or new.subtotal is distinct from old.subtotal or new.tax_rate is distinct from old.tax_rate
    or new.tax_amount is distinct from old.tax_amount or new.total is distinct from old.total
    or new.unit_id is distinct from old.unit_id or new.product is distinct from old.product
    or new.country is distinct from old.country or new.opportunity_id is distinct from old.opportunity_id) then
    raise exception 'Une facture émise ne se modifie plus : annulez-la et établissez-en une nouvelle.' using errcode = '42501';
  end if;
  if old.status = 'draft' and new.number is distinct from old.number then
    raise exception 'Le numéro de facture est attribué par le système.' using errcode = '42501';
  end if;

  if new.tax_rate is distinct from old.tax_rate then
    new.tax_amount := round(new.subtotal * new.tax_rate / 100, 2);
    new.total      := new.subtotal + new.tax_amount;
  end if;
  if new.status = 'sent' and old.status = 'draft' then new.sent_at := now(); end if;
  if new.status = 'paid' and old.status <> 'paid' then
    new.paid_at := coalesce(new.paid_at, now());
  elsif new.status <> 'paid' then
    new.paid_at := null;
  end if;
  return new;
end $$;

-- Encaissement : revenu ; annulation de l'encaissement : contre-passation.
create or replace function public.invoices_after_update()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_txn uuid;
begin
  if new.status = 'paid' and old.status <> 'paid' and new.total > 0 then
    insert into public.transactions (type, amount, currency, occurred_on, category, description,
                                     unit_id, account_id, invoice_id, product, country, reference, created_by)
    values ('revenue', new.total, new.currency, coalesce(new.paid_at, now())::date, 'Ventes',
            'Paiement facture ' || new.number, new.unit_id, new.account_id, new.id, new.product, new.country,
            new.number, auth.uid());
  elsif old.status = 'paid' and new.status <> 'paid' then
    select id into v_txn from public.transactions
     where invoice_id = new.id and reverses_id is null and reversed_by is null;
    if v_txn is not null then
      perform set_config('veriion.invoice_flow', 'on', true);
      perform public.reverse_transaction(v_txn, 'Encaissement de la facture ' || new.number || ' annulé');
      perform set_config('veriion.invoice_flow', 'off', true);
    end if;
  end if;
  return null;
end $$;

-- Les lignes ne changent qu'en brouillon ; le recalcul des totaux reste permis.
create or replace function public.invoice_lines_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_status public.invoice_status;
begin
  select status into v_status from public.invoices where id = coalesce(new.invoice_id, old.invoice_id);
  if auth.uid() is not null and v_status is distinct from 'draft' then
    raise exception 'Les lignes d''une facture émise ne se modifient plus.' using errcode = '42501';
  end if;
  return coalesce(new, old);
end $$;
drop trigger if exists invoice_lines_guard_biud on public.invoice_lines;
create trigger invoice_lines_guard_biud before insert or update or delete on public.invoice_lines
  for each row execute function public.invoice_lines_guard();

create or replace function public.recompute_invoice(p_invoice uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform set_config('veriion.invoice_recompute', 'on', true);
  update public.invoices i set
    subtotal   = coalesce(s.sum, 0),
    tax_amount = round(coalesce(s.sum, 0) * i.tax_rate / 100, 2),
    total      = coalesce(s.sum, 0) + round(coalesce(s.sum, 0) * i.tax_rate / 100, 2)
  from (select sum(amount) as sum from public.invoice_lines where invoice_id = p_invoice) s
  where i.id = p_invoice;
  perform set_config('veriion.invoice_recompute', 'off', true);
end $$;
revoke execute on function public.recompute_invoice(uuid) from public, anon, authenticated;

-- Pas de suppression de facture : on l'annule.
drop policy if exists "factures: gestion" on public.invoices;
drop policy if exists "factures: création" on public.invoices;
drop policy if exists "factures: modification" on public.invoices;
create policy "factures: création" on public.invoices for insert to authenticated
  with check (public.has_perm('finance.admin'));
create policy "factures: modification" on public.invoices for update to authenticated
  using (public.has_perm('finance.admin')) with check (public.has_perm('finance.admin'));

-- -----------------------------------------------------------------------------
-- 3. Fusion d'unités : l'historique financier garde son unité d'origine
-- -----------------------------------------------------------------------------
alter table public.org_units add column if not exists merged_into uuid references public.org_units(id) on delete set null;

create or replace function public.merge_org_units(p_source uuid, p_target uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  s public.org_units;
  t public.org_units;
  m record;
  v_role public.membership_role;
  v_src_root uuid;
  v_tgt_root uuid;
begin
  if not public.has_perm('org.manage') then
    raise exception 'Seule la direction peut fusionner des unités' using errcode = '42501';
  end if;
  perform public.require_mfa();
  if p_source = p_target then raise exception 'Choisissez deux unités différentes'; end if;
  select * into s from public.org_units where id = p_source;
  select * into t from public.org_units where id = p_target;
  if s.id is null or t.id is null then raise exception 'Unité introuvable'; end if;
  if s.parent_id is null then raise exception 'L''entreprise elle-même ne peut pas être fusionnée'; end if;
  if s.id = any(t.path) then raise exception 'L''unité d''accueil dépend de l''unité à fusionner : choisissez l''autre sens'; end if;

  for m in select * from public.unit_memberships where unit_id = p_source and end_date is null loop
    v_role := m.role;
    if v_role = 'head' and exists (
      select 1 from public.unit_memberships where unit_id = p_target and role = 'head' and end_date is null
    ) then
      v_role := 'deputy';
    end if;
    if exists (select 1 from public.unit_memberships where unit_id = p_target and profile_id = m.profile_id and end_date is null) then
      update public.unit_memberships set end_date = current_date where id = m.id;
    else
      update public.unit_memberships
         set unit_id = p_target, role = v_role, title = public.job_title_for(p_target, v_role)
       where id = m.id;
    end if;
  end loop;

  update public.org_units    set parent_id = p_target where parent_id = p_source;
  update public.channels     set unit_id   = p_target where unit_id = p_source;
  update public.projects     set unit_id   = p_target where unit_id = p_source;
  update public.announcements set unit_id  = p_target where unit_id = p_source;
  update public.objectives   set unit_id   = p_target where unit_id = p_source;
  -- Factures et opérations passées restent rattachées à l'unité d'origine
  -- (merged_into permet de les consolider avec l'unité d'accueil).
  update public.project_liaisons l set unit_id = p_target where unit_id = p_source
     and not exists (select 1 from public.project_liaisons x where x.project_id = l.project_id and x.unit_id = p_target);
  delete from public.project_liaisons where unit_id = p_source;

  update public.budgets b set amount = b.amount + s2.amount
    from public.budgets s2
   where b.unit_id = p_target and s2.unit_id = p_source and s2.fiscal_year = b.fiscal_year;
  update public.budgets set unit_id = p_target
   where unit_id = p_source and fiscal_year not in (select fiscal_year from public.budgets where unit_id = p_target);
  delete from public.budgets where unit_id = p_source;

  select id into v_src_root from public.folders where is_root and space = 'unit' and unit_id = p_source;
  select id into v_tgt_root from public.folders where is_root and space = 'unit' and unit_id = p_target;
  if v_src_root is not null and v_tgt_root is not null then
    for m in select * from public.folders where parent_id = v_src_root and deleted_at is null loop
      if exists (select 1 from public.folders f
                  where f.parent_id = v_tgt_root and lower(f.name) = lower(m.name) and f.deleted_at is null) then
        update public.folders set parent_id = v_tgt_root, name = m.name || ' (' || s.name || ')' where id = m.id;
      else
        update public.folders set parent_id = v_tgt_root where id = m.id;
      end if;
    end loop;
    update public.documents set folder_id = v_tgt_root where folder_id = v_src_root;
    update public.folders set unit_id = p_target where unit_id = p_source and not is_root;
    update public.folders set deleted_at = now() where id = v_src_root;
  end if;

  update public.profiles set primary_unit_id = p_target where primary_unit_id = p_source;
  update public.org_units set archived_at = now(), merged_into = p_target where id = p_source;
end $$;

-- >>>>>>>>>> supabase/migrations/20261012000014_p0_circuits.sql
-- =============================================================================
-- VERIION OS — Migration 14 : circuits branchés de bout en bout (phase 0, lot P0-06)
-- =============================================================================
--   * budget : brouillon → activation directe sous le seuil, accord du CEO au-delà ;
--   * contrat de travail : brouillon → accord du CEO → signature (le salaire suit) ;
--   * contrat juridique : machine à états stricte, revue juridique obligatoire,
--     expiration et renouvellement tacite automatiques.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Budgets
-- -----------------------------------------------------------------------------
/** Active un budget : directement sous le seuil, sinon demande l'accord du CEO. Renvoie l'état obtenu. */
create or replace function public.activate_budget(p_budget uuid, p_justification text default null)
returns text language plpgsql security definer set search_path = public as $$
declare b public.budgets;
begin
  select * into b from public.budgets where id = p_budget for update;
  if b.id is null then raise exception 'Budget introuvable'; end if;
  if not public.has_perm('finance.admin') then raise exception 'Seule la finance active un budget' using errcode = '42501'; end if;
  perform public.require_mfa();
  if b.status = 'active' then return 'active'; end if;
  if b.amount <= public.ceo_approval_threshold() or public.is_ceo()
     or public.approval_valid('budget', b.id, to_jsonb(b)) then
    update public.budgets set status = 'active' where id = p_budget;
    return 'active';
  end if;
  perform public.request_approval('budget', p_budget, null, null, p_justification);
  return 'pending';
end $$;
revoke execute on function public.activate_budget(uuid, text) from public, anon;
grant execute on function public.activate_budget(uuid, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Contrats de travail
-- -----------------------------------------------------------------------------
create or replace function public.submit_employment_contract(p_contract uuid, p_justification text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare c public.employment_contracts; v_id uuid;
begin
  select * into c from public.employment_contracts where id = p_contract;
  if c.id is null then raise exception 'Contrat introuvable'; end if;
  if not public.has_perm('hr.admin') then raise exception 'Permission refusée' using errcode = '42501'; end if;
  if c.status <> 'draft' then raise exception 'Seul un contrat en brouillon se soumet'; end if;
  v_id := public.request_approval('employment_contract', p_contract, null, null, p_justification);
  if public.approval_valid('employment_contract', p_contract, to_jsonb(c)) then
    return v_id;  -- décision directe du CEO : reste à signer
  end if;
  update public.employment_contracts set status = 'pending_ceo' where id = p_contract;
  return v_id;
end $$;
revoke execute on function public.submit_employment_contract(uuid, text) from public, anon;
grant execute on function public.submit_employment_contract(uuid, text) to authenticated;

create or replace function public.employment_contracts_transition()
returns trigger language plpgsql security definer set search_path = public as $$
declare allowed boolean;
begin
  if tg_op = 'INSERT' then
    if auth.uid() is not null and new.status not in ('draft') then
      raise exception 'Un contrat de travail commence en brouillon.' using errcode = '23514';
    end if;
    return new;
  end if;
  if new.status is distinct from old.status and auth.uid() is not null then
    allowed := case old.status
      when 'draft'       then new.status in ('pending_ceo', 'signed')
      when 'pending_ceo' then new.status in ('draft', 'signed')
      when 'signed'      then new.status = 'ended'
      else false end;
    if not allowed then
      raise exception 'Passage de « % » à « % » impossible pour un contrat de travail.', old.status, new.status using errcode = '23514';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists employment_contracts_aa_transition_biu on public.employment_contracts;
create trigger employment_contracts_aa_transition_biu before insert or update on public.employment_contracts
  for each row execute function public.employment_contracts_transition();

-- -----------------------------------------------------------------------------
-- 3. Contrats juridiques : machine à états
-- -----------------------------------------------------------------------------
create or replace function public.legal_contracts_transition()
returns trigger language plpgsql security definer set search_path = public as $$
declare allowed boolean;
begin
  if tg_op = 'INSERT' then
    if auth.uid() is not null and new.status <> 'draft' then
      raise exception 'Un contrat commence en brouillon.' using errcode = '23514';
    end if;
    return new;
  end if;
  if new.status is distinct from old.status and auth.uid() is not null then
    allowed := case old.status
      when 'draft'        then new.status in ('legal_review', 'terminated')
      when 'legal_review' then new.status in ('draft', 'pending_ceo', 'terminated')
      when 'pending_ceo'  then new.status in ('legal_review', 'signed', 'active')
      when 'signed'       then new.status in ('active', 'terminated')
      when 'active'       then new.status in ('terminated', 'expired')
      else false end;
    if not allowed then
      raise exception 'Passage de « % » à « % » impossible : le circuit est rédaction → revue juridique → accord du CEO → signature.',
        old.status, new.status using errcode = '23514';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists legal_contracts_aa_transition_biu on public.legal_contracts;
create trigger legal_contracts_aa_transition_biu before insert or update on public.legal_contracts
  for each row execute function public.legal_contracts_transition();

/** La revue juridique est obligatoire avant la signature du CEO. */
create or replace function public.submit_contract_for_signature(p_contract uuid, p_justification text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare c public.legal_contracts; v_id uuid;
begin
  select * into c from public.legal_contracts where id = p_contract;
  if c.id is null then raise exception 'Contrat introuvable'; end if;
  if not (public.has_perm('legal.admin') or public.is_ceo()) then
    raise exception 'La soumission à signature revient au Juridique' using errcode = '42501';
  end if;
  if c.status <> 'legal_review' then
    raise exception 'Le contrat doit d''abord passer en revue juridique.';
  end if;
  v_id := public.request_approval('legal_contract', p_contract, null, null, p_justification);
  update public.legal_contracts set status = 'pending_ceo' where id = p_contract;
  return v_id;
end $$;

/**
 * Tâche quotidienne : contrats arrivés à terme. Renouvellement tacite pour une
 * durée égale à la précédente, sinon expiration. Le propriétaire est prévenu.
 */
create or replace function public.process_contract_terms()
returns int language plpgsql security definer set search_path = public as $$
declare today date := (now() at time zone 'Africa/Porto-Novo')::date; n int := 0; r record; v_len int;
begin
  for r in
    select * from public.legal_contracts
     where status in ('signed', 'active') and end_date is not null and end_date < today
  loop
    if r.auto_renew then
      v_len := greatest(30, r.end_date - coalesce(r.effective_date, r.signed_on, r.end_date - 365));
      update public.legal_contracts
         set end_date = r.end_date + v_len, status = 'active',
             notes = trim(coalesce(notes, '') || E'\n' || 'Renouvelé tacitement le ' || to_char(today, 'DD/MM/YYYY')
                     || ' jusqu''au ' || to_char(r.end_date + v_len, 'DD/MM/YYYY') || '.')
       where id = r.id;
      perform public.notify(r.owner_id, 'legal.renewed', 'Contrat renouvelé : ' || r.reference,
        r.title || ' court jusqu''au ' || to_char(r.end_date + v_len, 'DD/MM/YYYY') || '.', '/juridique?contrat=' || r.id);
    else
      update public.legal_contracts set status = (case when status = 'signed' then 'terminated' else 'expired' end)::public.legal_contract_status
       where id = r.id;
      perform public.notify(r.owner_id, 'legal.expired', 'Contrat échu : ' || r.reference,
        r.title || ' est arrivé à terme le ' || to_char(r.end_date, 'DD/MM/YYYY') || '.', '/juridique?contrat=' || r.id);
    end if;
    n := n + 1;
  end loop;
  -- Contrats signés dont la date d'effet est atteinte : actifs.
  update public.legal_contracts set status = 'active'
   where status = 'signed' and coalesce(effective_date, signed_on) <= today;
  return n;
end $$;
revoke execute on function public.process_contract_terms() from public, anon, authenticated;

do $$
begin
  perform cron.schedule('veriion-contract-terms', '15 5 * * *', 'select public.process_contract_terms()');
exception when others then
  raise notice 'pg_cron non disponible : échéances des contrats à planifier plus tard (%)', sqlerrm;
end $$;

-- >>>>>>>>>> supabase/migrations/20261012000015_p0_vues_interface.sql
-- =============================================================================
-- VERIION OS — Migration 15 : vues d'appui à l'interface (phase 0)
-- =============================================================================

-- État d'un accord : caduc si le contenu couvert a changé depuis la décision.
create or replace function public.approval_is_stale(p_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select a.subject_id is not null and a.subject_hash is not null and a.status in ('approved', 'pending')
     and public.approval_hash(a.kind, public.approval_subject_row(a.kind, a.subject_id)) is distinct from a.subject_hash
  from public.approval_requests a where a.id = p_id
$$;
revoke execute on function public.approval_is_stale(uuid) from public, anon;
grant execute on function public.approval_is_stale(uuid) to authenticated;

-- Vue avec les droits de l'appelant (security_invoker) : mêmes lignes que la table.
create or replace view public.approval_requests_status with (security_invoker = true) as
  select a.*, public.approval_is_stale(a.id) as stale
  from public.approval_requests a;
revoke all on public.approval_requests_status from anon;
grant select on public.approval_requests_status to authenticated;

/** Accords de dépense encore disponibles pour l'appelant (avec leur reste). */
create or replace function public.available_expense_approvals()
returns table (id uuid, subject_label text, amount numeric, consumed_amount numeric, remaining numeric,
               currency text, decided_at timestamptz, unit_id uuid, project_id uuid)
language sql stable security definer set search_path = public as $$
  select a.id, a.subject_label, a.amount, a.consumed_amount, a.amount - a.consumed_amount, a.currency, a.decided_at,
         a.unit_id, a.project_id
  from public.approval_requests a
  where a.kind = 'expense' and a.status = 'approved' and coalesce(a.amount, 0) > a.consumed_amount
    and public.has_perm('finance.admin')
  order by a.decided_at desc
$$;
revoke execute on function public.available_expense_approvals() from public, anon;
grant execute on function public.available_expense_approvals() to authenticated;

-- File d'envoi push, éventuellement limitée à une personne (notification de test).
drop function if exists public.claim_push_batch(int);
create or replace function public.claim_push_batch(p_limit int default 200, p_profile uuid default null)
returns table (id uuid, profile_id uuid, kind text, category text, title text, body text, link text, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  return query
  with c as (
    select n.id from public.notifications n
    where n.pushed_at is null and n.read_at is null and n.created_at > now() - interval '30 minutes'
      and (p_profile is null or n.profile_id = p_profile)
    order by n.created_at
    limit p_limit
    for update skip locked
  )
  update public.notifications n set pushed_at = now()
  from c where n.id = c.id
  returning n.id, n.profile_id, n.kind, public.notification_category(n.kind), n.title, n.body, n.link, n.created_at;
end $$;
revoke execute on function public.claim_push_batch(int, uuid) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- Supervision (P0-10) : état de santé lu par /api/health (clé service_role).
-- -----------------------------------------------------------------------------
create or replace function public.ops_health()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_cron jsonb := '[]'::jsonb;
begin
  begin
    execute $q$
      select coalesce(jsonb_agg(jsonb_build_object('job', j.jobname, 'at', d.start_time, 'message', left(d.return_message, 200))), '[]'::jsonb)
      from cron.job_run_details d join cron.job j on j.jobid = d.jobid
      where d.status = 'failed' and d.start_time > now() - interval '24 hours'
    $q$ into v_cron;
  exception when others then
    v_cron := '[]'::jsonb;
  end;
  return jsonb_build_object(
    'database', 'ok',
    'push_backlog', (select count(*) from public.notifications where pushed_at is null and read_at is null
                       and created_at between now() - interval '30 minutes' and now() - interval '5 minutes'),
    'email_backlog', (select count(*) from public.notifications where emailed_at is null and read_at is null
                       and created_at between now() - interval '3 days' and now() - interval '15 minutes'),
    'pending_approvals', (select count(*) from public.approval_requests where status = 'pending'),
    'cron_failures_24h', v_cron
  );
end $$;
revoke execute on function public.ops_health() from public, anon, authenticated;

-- >>>>>>>>>> supabase/seed.sql
-- =============================================================================
-- VERIION OS — Données initiales : structure de la holding et référentiel KPI
-- À exécuter une fois, après les migrations.
-- =============================================================================
-- VERIION est une holding : une équipe administrative transverse, et autant de
-- projets que de produits. Les départements ci-dessous coordonnent chaque
-- projet ; les projets, eux, se créent depuis l'application (un Chief Product,
-- une équipe, un référent par département).
-- =============================================================================

do $$
declare
  root uuid; dg uuid; ops uuid; tech uuid; dev uuid; mkt uuid; biz uuid; fin uuid; leg uuid; rh uuid;
begin
  if exists (select 1 from public.org_units) then
    raise notice 'Organisation déjà initialisée — aucune action.';
    return;
  end if;

  insert into public.org_units (name, code, kind, domain, color, sort_order, description, head_title, deputy_title, is_core)
  values ('VERIION', 'VRN', 'company', 'direction', '#050816', 0,
          'La holding : l''écosystème numérique de l''Afrique',
          'CEO — Directeur Général', 'Directeur Général Adjoint', true)
  returning id into root;

  -- ── Équipe administrative : les fonctions transverses de la holding ────────
  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description, head_title, deputy_title, member_title, is_core) values
    (root, 'Direction Générale',   'DG',   'department', 'direction',  '#0B1F3A', 1,
     'Vision, arbitrages, validations et pilotage de la holding',
     'CEO — Directeur Général', 'Directeur Général Adjoint', 'Chargé de mission', true)
  returning id into dg;

  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description, head_title, deputy_title, member_title, is_core) values
    (root, 'Opérations',           'OPS',  'department', 'operations', '#0E7490', 2,
     'Calendrier opérationnel des projets, exécution, qualité et reporting',
     'COO — Directeur des Opérations', 'Responsable des Opérations', 'Chargé des opérations', true)
  returning id into ops;

  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description, head_title, deputy_title, member_title, is_core) values
    (root, 'Technologie',          'TECH', 'department', 'technology', '#4F46E5', 3,
     'Plateformes, architecture, infrastructure et sécurité des produits',
     'CTO — Directeur Technique', 'Responsable Technique', 'Ingénieur', true)
  returning id into tech;

  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description, head_title, deputy_title, member_title, is_core) values
    (root, 'Finance',              'FIN',  'department', 'finance',    '#059669', 4,
     'Budgets, trésorerie, facturation et contrôle financier des projets',
     'CFO — Directeur Financier', 'Responsable Financier', 'Chargé de gestion', true)
  returning id into fin;

  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description, head_title, deputy_title, member_title, is_core) values
    (root, 'Business',             'BIZ',  'department', 'business',   '#EA580C', 5,
     'Ventes, partenariats et développement commercial des produits',
     'CBO — Directeur Business', 'Responsable Business', 'Chargé d''affaires', true)
  returning id into biz;

  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description, head_title, deputy_title, member_title, is_core) values
    (root, 'Marketing',            'MKT',  'department', 'marketing',  '#DB2777', 6,
     'Acquisition, marque, communication et contenu',
     'CMO — Directeur Marketing', 'Responsable Marketing', 'Chargé marketing', true)
  returning id into mkt;

  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description, head_title, deputy_title, member_title, is_core) values
    (root, 'Juridique',            'LEG',  'department', 'legal',      '#7C3AED', 7,
     'Contrats, conformité, propriété intellectuelle et contentieux',
     'Directeur Juridique', 'Juriste principal', 'Juriste', true)
  returning id into leg;

  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description, head_title, deputy_title, member_title, is_core) values
    (root, 'Ressources Humaines',  'RH',   'department', 'hr',         '#0D9488', 8,
     'Recrutement, contrats de travail, paie et parcours des collaborateurs',
     'CHRO — Directeur des Ressources Humaines', 'Responsable RH', 'Chargé RH', true)
  returning id into rh;

  -- ── Sous-départements : la coordination fine des projets ──────────────────
  insert into public.org_units (parent_id, name, code, kind, color, sort_order, description, head_title) values
    (dg,   'Cabinet du CEO',         'DG-CAB',  'subdepartment', '#0B1F3A', 1, 'Préparation des arbitrages et suivi des décisions', 'Chef de cabinet'),
    (ops,  'Planification',          'OPS-PLN', 'subdepartment', '#0E7490', 1, 'Écrit les calendriers mensuels, hebdomadaires et journaliers des projets', 'Responsable planification'),
    (ops,  'Qualité & Process',      'OPS-QA',  'subdepartment', '#0E7490', 2, 'Méthodes, qualité de livraison et amélioration continue', 'Responsable qualité'),
    (tech, 'Infrastructure',         'TECH-INF','subdepartment', '#4F46E5', 2, 'Hébergement, sécurité et disponibilité des plateformes', 'Responsable infrastructure'),
    (fin,  'Comptabilité',           'FIN-CPT', 'subdepartment', '#059669', 1, 'Tenue des comptes et facturation', 'Chef comptable'),
    (fin,  'Contrôle financier',     'FIN-CTL', 'subdepartment', '#059669', 2, 'Budgets des projets et contrôle des dépenses', 'Contrôleur de gestion'),
    (biz,  'Commercial',             'BIZ-COM', 'subdepartment', '#EA580C', 1, 'Ventes et relation client', 'Responsable commercial'),
    (biz,  'Partenariats',           'BIZ-PAR', 'subdepartment', '#EA580C', 2, 'Alliances et développement de l''écosystème', 'Responsable partenariats'),
    (mkt,  'Acquisition',            'MKT-ACQ', 'subdepartment', '#DB2777', 1, 'Croissance et acquisition d''utilisateurs', 'Responsable acquisition'),
    (mkt,  'Communication',          'MKT-COM', 'subdepartment', '#DB2777', 2, 'Marque, relations publiques et réseaux', 'Responsable communication'),
    (mkt,  'Contenu',                'MKT-CNT', 'subdepartment', '#DB2777', 3, 'Production éditoriale et créative', 'Responsable contenu'),
    (leg,  'Contrats',               'LEG-CTR', 'subdepartment', '#7C3AED', 1, 'Rédaction, revue et suivi des contrats de la holding', 'Responsable contrats'),
    (leg,  'Conformité',             'LEG-CMP', 'subdepartment', '#7C3AED', 2, 'Conformité réglementaire, données personnelles et risques', 'Responsable conformité'),
    (rh,   'Recrutement',            'RH-REC',  'subdepartment', '#0D9488', 1, 'Sourcing, entretiens et intégration', 'Responsable recrutement'),
    (rh,   'Administration du personnel', 'RH-ADP', 'subdepartment', '#0D9488', 2, 'Contrats, paie, congés et dossiers du personnel', 'Responsable administration RH');

  insert into public.org_units (parent_id, name, code, kind, color, sort_order, description, head_title)
  values (tech, 'Développement', 'TECH-DEV', 'subdepartment', '#4F46E5', 1, 'Conception et développement des produits', 'Responsable développement')
  returning id into dev;

  insert into public.org_units (parent_id, name, code, kind, color, sort_order, head_title) values
    (dev, 'Backend',  'TECH-DEV-BE', 'team', '#4F46E5', 1, 'Chef d''équipe Backend'),
    (dev, 'Frontend', 'TECH-DEV-FE', 'team', '#4F46E5', 2, 'Chef d''équipe Frontend'),
    (dev, 'Mobile',   'TECH-DEV-MB', 'team', '#4F46E5', 3, 'Chef d''équipe Mobile');

  -- Canal général de la holding
  insert into public.channels (kind, name, description, is_private)
  values ('group', 'général', 'Échanges ouverts à toute l''équipe VERIION', false);
end $$;

insert into public.kpi_definitions (key, name, description, formula, source, unit) values
  ('active_users',   'Utilisateurs actifs',        'Utilisateurs uniques actifs sur les plateformes VERIION', 'Somme des utilisateurs actifs du dernier jour mesuré (tous produits)', 'product_metrics', 'utilisateurs'),
  ('revenue_ytd',    'Revenus cumulés',            'Revenus encaissés depuis le 1er janvier',                 'Σ transactions de type revenu de l''année', 'transactions', 'XOF'),
  ('burn',           'Dépenses cumulées',          'Dépenses engagées depuis le 1er janvier',                 'Σ transactions de type dépense de l''année', 'transactions', 'XOF'),
  ('cash',           'Trésorerie',                 'Position de trésorerie estimée',                          'Trésorerie d''ouverture + Σ revenus − Σ dépenses', 'transactions + company_settings', 'XOF'),
  ('pipeline',       'Pipeline pondéré',           'Valeur attendue des opportunités ouvertes',               'Σ montant × probabilité', 'opportunities', 'XOF'),
  ('tasks_overdue',  'Tâches en retard',           'Tâches non terminées dont l''échéance est dépassée',      'count(tasks) où statut ≠ terminé et échéance < aujourd''hui', 'tasks', 'tâches'),
  ('budget_usage',   'Consommation budgétaire',    'Part du budget annuel consommée par unité',               'Σ dépenses de l''unité ÷ budget de l''unité', 'budgets + transactions', '%')
on conflict (key) do nothing;
