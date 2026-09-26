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
