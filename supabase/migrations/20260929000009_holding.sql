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
