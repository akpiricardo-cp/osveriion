-- =============================================================================
-- VERIION OS — Installation complète (migrations + données initiales)
-- Généré à partir de supabase/migrations/*.sql et supabase/seed.sql.
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

-- >>>>>>>>>> supabase/seed.sql
-- =============================================================================
-- VERIION OS — Données initiales : structure de l'organisation et référentiel KPI
-- À exécuter une fois, après les migrations.
-- =============================================================================

do $$
declare
  root uuid; dg uuid; ops uuid; tech uuid; dev uuid; mkt uuid; biz uuid; fin uuid;
begin
  if exists (select 1 from public.org_units) then
    raise notice 'Organisation déjà initialisée — aucune action.';
    return;
  end if;

  insert into public.org_units (name, code, kind, domain, color, sort_order, description)
  values ('VERIION', 'VRN', 'company', 'direction', '#050816', 0, 'L''écosystème numérique de l''Afrique')
  returning id into root;

  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description) values
    (root, 'Direction Générale', 'DG',   'department', 'direction',  '#0B1F3A', 1, 'Vision, arbitrages et pilotage de l''entreprise')
  returning id into dg;
  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description) values
    (root, 'Opérations',         'OPS',  'department', 'operations', '#0E7490', 2, 'Exécution, gestion de projets et qualité')
  returning id into ops;
  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description) values
    (root, 'Technologie',        'TECH', 'department', 'technology', '#4F46E5', 3, 'Produits, plateformes et infrastructure')
  returning id into tech;
  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description) values
    (root, 'Marketing',          'MKT',  'department', 'marketing',  '#DB2777', 4, 'Acquisition, communication et contenu')
  returning id into mkt;
  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description) values
    (root, 'Business',           'BIZ',  'department', 'business',   '#EA580C', 5, 'Ventes et partenariats')
  returning id into biz;
  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description) values
    (root, 'Finance',            'FIN',  'department', 'finance',    '#059669', 6, 'Comptabilité, trésorerie et contrôle financier')
  returning id into fin;

  insert into public.org_units (parent_id, name, code, kind, color, sort_order) values
    (dg,   'Cabinet du CEO',      'DG-CAB',  'subdepartment', '#0B1F3A', 1),
    (ops,  'Gestion de projets',  'OPS-PMO', 'subdepartment', '#0E7490', 1),
    (ops,  'Qualité',             'OPS-QA',  'subdepartment', '#0E7490', 2),
    (tech, 'Infrastructure',      'TECH-INF','subdepartment', '#4F46E5', 2),
    (mkt,  'Acquisition',         'MKT-ACQ', 'subdepartment', '#DB2777', 1),
    (mkt,  'Communication',       'MKT-COM', 'subdepartment', '#DB2777', 2),
    (mkt,  'Contenu',             'MKT-CNT', 'subdepartment', '#DB2777', 3),
    (biz,  'Commercial',          'BIZ-COM', 'subdepartment', '#EA580C', 1),
    (biz,  'Partenariats',        'BIZ-PAR', 'subdepartment', '#EA580C', 2),
    (fin,  'Comptabilité',        'FIN-CPT', 'subdepartment', '#059669', 1),
    (fin,  'Contrôle financier',  'FIN-CTL', 'subdepartment', '#059669', 2);

  insert into public.org_units (parent_id, name, code, kind, color, sort_order)
  values (tech, 'Développement', 'TECH-DEV', 'subdepartment', '#4F46E5', 1)
  returning id into dev;

  insert into public.org_units (parent_id, name, code, kind, color, sort_order) values
    (dev, 'Backend',  'TECH-DEV-BE', 'team', '#4F46E5', 1),
    (dev, 'Frontend', 'TECH-DEV-FE', 'team', '#4F46E5', 2);

  -- Canal général de l'entreprise
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
