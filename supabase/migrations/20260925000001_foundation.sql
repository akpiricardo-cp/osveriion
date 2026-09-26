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
