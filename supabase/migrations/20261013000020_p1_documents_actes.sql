-- =============================================================================
-- VERIION OS — Migration 20 : modèles, documents générés, registre des actes,
-- conservation légale (phase 1, lot P1-06)
-- =============================================================================
--   * document_templates : modèles avec champs {{…}} remplis depuis l'objet ;
--   * document_jobs      : file de génération (à la demande, ou déclenchée par
--                          un événement : une nomination produit sa décision) ;
--   * generated_documents / acts_register : chaque document officiel est
--     numéroté par entité, empreinte SHA-256 à l'appui, et relié à son objet ;
--   * retention_policies + legal_hold : durée de conservation par catégorie et
--     gel juridique qui empêche corbeille et purge.
-- La génération elle-même (DOCX) est faite par l'application, avec la clé
-- serveur : voir src/lib/server/documents.ts.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Conservation légale
-- -----------------------------------------------------------------------------
create table if not exists public.retention_policies (
  category     public.doc_category primary key,
  years        int not null check (years between 1 and 100),
  legal_basis  text,
  updated_at   timestamptz not null default now()
);
insert into public.retention_policies (category, years, legal_basis) values
  ('contract',     10, 'Actes et contrats : prescription commerciale (Acte uniforme OHADA)'),
  ('policy',       10, 'Politiques internes et décisions'),
  ('minutes',      10, 'Procès-verbaux et décisions des organes'),
  ('procedure',     5, 'Procédures'),
  ('presentation',  3, 'Présentations'),
  ('technical',     5, 'Documentation technique'),
  ('project',       5, 'Dossiers de projet'),
  ('other',         5, 'Par défaut')
on conflict (category) do nothing;

alter table public.documents
  add column if not exists legal_hold         boolean not null default false,
  add column if not exists legal_hold_reason  text,
  add column if not exists retain_until       date;

create or replace function public.documents_retention()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' or new.category is distinct from old.category then
    new.retain_until := (coalesce(new.created_at, now())
      + make_interval(years => coalesce((select years from public.retention_policies where category = new.category), 5)))::date;
  end if;
  if tg_op = 'UPDATE' and auth.uid() is not null
     and (new.legal_hold is distinct from old.legal_hold or new.legal_hold_reason is distinct from old.legal_hold_reason)
     and current_setting('veriion.legal_hold', true) is distinct from 'on' then
    raise exception 'Le gel juridique se pose et se lève par le Juridique.' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists documents_retention_biu on public.documents;
create trigger documents_retention_biu before insert or update on public.documents
  for each row execute function public.documents_retention();
update public.documents set category = category where retain_until is null;

/** Gel juridique : le document ne peut plus être mis à la corbeille ni purgé. */
create or replace function public.set_legal_hold(p_doc uuid, p_hold boolean, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (public.has_perm('legal.admin') or public.is_ceo()) then
    raise exception 'Le gel juridique revient au Juridique' using errcode = '42501';
  end if;
  if p_hold and length(trim(coalesce(p_reason, ''))) < 3 then raise exception 'Indiquez le motif du gel'; end if;
  if not exists (select 1 from public.documents where id = p_doc) then raise exception 'Document introuvable'; end if;
  perform set_config('veriion.legal_hold', 'on', true);
  update public.documents set legal_hold = p_hold, legal_hold_reason = case when p_hold then trim(p_reason) end where id = p_doc;
  perform set_config('veriion.legal_hold', 'off', true);
  if p_hold then
    update public.documents set deleted_at = null, deleted_by = null where id = p_doc and deleted_at is not null;
  end if;
  perform public.emit_event(case when p_hold then 'document.held' else 'document.released' end, 'document', p_doc,
    case when p_hold then 'Gel juridique : ' || trim(p_reason) else 'Gel juridique levé' end);
end $$;
grant execute on function public.set_legal_hold(uuid, boolean, text) to authenticated;

create or replace function public.trash_item(p_folder uuid default null, p_doc uuid default null)
returns void language plpgsql security definer set search_path = public as $$
declare f public.folders; ts timestamptz := now();
begin
  if p_folder is not null then
    select * into f from public.folders where id = p_folder;
    if f.is_root then raise exception 'L''espace racine ne peut pas être supprimé'; end if;
    if public.folder_access(p_folder) < 2 then raise exception 'Permission refusée' using errcode = '42501'; end if;
    if exists (select 1 from public.documents d join public.folders x on x.id = d.folder_id
                where p_folder = any(x.path) and d.legal_hold and d.deleted_at is null) then
      raise exception 'Ce dossier contient un document sous gel juridique : il ne peut pas être supprimé.';
    end if;
    update public.folders set deleted_at = ts, deleted_by = auth.uid() where p_folder = any(path) and deleted_at is null;
    update public.documents set deleted_at = ts, deleted_by = auth.uid()
     where deleted_at is null and folder_id in (select id from public.folders where p_folder = any(path));
  elsif p_doc is not null then
    if public.document_access(p_doc) < 2 then raise exception 'Permission refusée' using errcode = '42501'; end if;
    if exists (select 1 from public.documents where id = p_doc and legal_hold) then
      raise exception 'Document sous gel juridique : il ne peut pas être supprimé.';
    end if;
    update public.documents set deleted_at = ts, deleted_by = auth.uid() where id = p_doc;
  end if;
end $$;

-- La purge épargne les documents gelés ou encore dans leur durée de conservation
-- (ils restent dans la corbeille, restaurables).
create or replace function public.purge_trash()
returns int language plpgsql security definer set search_path = public as $$
declare n int;
begin
  with d as (
    delete from public.documents
     where deleted_at < now() - interval '30 days' and not legal_hold
       and (retain_until is null or retain_until <= current_date or category in ('presentation', 'other'))
    returning 1)
  select count(*) into n from d;
  delete from public.folders f where f.deleted_at < now() - interval '30 days'
    and not exists (select 1 from public.documents d join public.folders x on x.id = d.folder_id where f.id = any(x.path));
  return n;
end $$;
revoke execute on function public.purge_trash() from public, anon, authenticated;

alter table public.retention_policies enable row level security;
revoke all on public.retention_policies from anon;
grant select, update on public.retention_policies to authenticated;
drop policy if exists "conservation: lecture" on public.retention_policies;
create policy "conservation: lecture" on public.retention_policies for select to authenticated using (public.is_active_user());
drop policy if exists "conservation: gestion" on public.retention_policies;
create policy "conservation: gestion" on public.retention_policies for update to authenticated
  using (public.is_ceo() and public.mfa_ok()) with check (public.is_ceo() and public.mfa_ok());

-- -----------------------------------------------------------------------------
-- 2. Modèles
-- -----------------------------------------------------------------------------
create table if not exists public.document_templates (
  id           uuid primary key default gen_random_uuid(),
  entity_id    uuid references public.legal_entities(id) on delete cascade,   -- null : valable pour toutes les entités
  kind         text not null check (kind in ('nomination', 'attestation', 'contrat', 'decision', 'autre')),
  subject_type text not null default 'person' check (public.object_type_valid(subject_type)),
  name         text not null check (length(trim(name)) > 2),
  body         text not null,
  category     public.doc_category not null default 'policy',
  register_act boolean not null default true,     -- inscrire au registre des actes
  version      int not null default 1,
  active       boolean not null default true,
  created_by   uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create or replace function public.document_templates_version()
returns trigger language plpgsql as $$
begin
  if new.body is distinct from old.body or new.name is distinct from old.name then new.version := old.version + 1; end if;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists document_templates_version_bu on public.document_templates;
create trigger document_templates_version_bu before update on public.document_templates
  for each row execute function public.document_templates_version();
drop trigger if exists audit_document_templates on public.document_templates;
create trigger audit_document_templates after insert or update or delete on public.document_templates
  for each row execute function public.audit_trigger();

create or replace function public.can_manage_templates()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_ceo() or public.has_perm('hr.admin') or public.has_perm('legal.admin') or public.has_perm('org.manage')
$$;

alter table public.document_templates enable row level security;
revoke all on public.document_templates from anon;
grant select, insert, update on public.document_templates to authenticated;
drop policy if exists "modèles: lecture" on public.document_templates;
create policy "modèles: lecture" on public.document_templates for select to authenticated using (public.is_active_user());
drop policy if exists "modèles: création" on public.document_templates;
create policy "modèles: création" on public.document_templates for insert to authenticated
  with check (public.can_manage_templates() and public.mfa_ok());
drop policy if exists "modèles: modification" on public.document_templates;
create policy "modèles: modification" on public.document_templates for update to authenticated
  using (public.can_manage_templates() and public.mfa_ok()) with check (public.can_manage_templates() and public.mfa_ok());

insert into public.document_templates (kind, subject_type, name, category, body, created_by)
select * from (values
  ('nomination', 'person', 'Décision de nomination', 'policy'::public.doc_category,
$t$# DÉCISION DE NOMINATION

{{entite.raison_sociale}}
RCCM : {{entite.rccm}} · IFU : {{entite.ifu}}

Référence : {{acte.reference}}

Le Directeur Général de {{entite.nom}},

Vu l'organisation de {{entite.nom}} et les besoins du service,

## DÉCIDE

**Article 1.** {{personne.nom_complet}} est nommé(e) {{nomination.role}} de l'unité « {{nomination.unite}} », avec l'intitulé de poste « {{nomination.intitule}} ».

**Article 2.** La présente décision prend effet le {{nomination.date_effet}}.

**Article 3.** Les droits et responsabilités attachés à cette fonction sont ceux définis par l'organigramme et les règles de délégation en vigueur dans VERIION OS.

**Article 4.** La présente décision sera notifiée à l'intéressé(e) et communiquée à qui de droit.

Fait le {{date}}

Pour {{entite.nom}}
Le Directeur Général
$t$, null::uuid),
  ('attestation', 'person', 'Attestation de travail', 'policy'::public.doc_category,
$t$# ATTESTATION DE TRAVAIL

{{entite.raison_sociale}}
RCCM : {{entite.rccm}} · IFU : {{entite.ifu}}

Référence : {{acte.reference}}

Nous soussignés, {{entite.raison_sociale}}, attestons que {{personne.nom_complet}} fait partie de notre personnel depuis le {{personne.date_embauche}}, en qualité de {{personne.intitule}}.

La présente attestation est délivrée à l'intéressé(e) pour servir et valoir ce que de droit.

Fait le {{date}}

Pour {{entite.nom}}
Les Ressources Humaines
$t$, null::uuid),
  ('contrat', 'contract', 'Fiche de synthèse de contrat', 'contract'::public.doc_category,
$t$# FICHE DE SYNTHÈSE — CONTRAT {{contrat.reference}}

Entité : {{entite.raison_sociale}}

- Intitulé : {{contrat.titre}}
- Contrepartie : {{contrat.contrepartie}}
- Montant : {{contrat.montant}} {{contrat.devise}}
- Prise d'effet : {{contrat.date_effet}}
- Échéance : {{contrat.echeance}}
- Renouvellement tacite : {{contrat.renouvellement}}

## Engagements à tenir

{{contrat.engagements}}

Établie le {{date}}
$t$, null::uuid)
) v(kind, subject_type, name, category, body, created_by)
where not exists (select 1 from public.document_templates);

-- -----------------------------------------------------------------------------
-- 3. Registre des actes et documents générés
-- -----------------------------------------------------------------------------
create table if not exists public.acts_register (
  id              uuid primary key default gen_random_uuid(),
  entity_id       uuid not null references public.legal_entities(id) on delete restrict,
  year            int not null,
  number          int not null,
  reference       text not null unique,
  act_type        text not null,
  title           text not null,
  subject_type    text not null check (public.object_type_valid(subject_type)),
  subject_id      uuid not null,
  effective_date  date not null default current_date,
  document_id     uuid references public.documents(id) on delete set null,
  sha256          text,
  created_by      uuid references public.profiles(id) on delete set null,
  created_at      timestamptz not null default now(),
  unique (entity_id, year, number)
);
create or replace function public.acts_register_immutable()
returns trigger language plpgsql as $$
begin
  if tg_op = 'DELETE' or new.reference is distinct from old.reference or new.sha256 is distinct from old.sha256
     or new.subject_id is distinct from old.subject_id or new.number is distinct from old.number then
    raise exception 'Le registre des actes est immuable.' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists acts_register_immutable_bud on public.acts_register;
create trigger acts_register_immutable_bud before update or delete on public.acts_register
  for each row execute function public.acts_register_immutable();

create table if not exists public.document_jobs (
  id            uuid primary key default gen_random_uuid(),
  template_id   uuid not null references public.document_templates(id) on delete cascade,
  subject_type  text not null check (public.object_type_valid(subject_type)),
  subject_id    uuid not null,
  context       jsonb not null default '{}'::jsonb,   -- données propres au déclencheur (ex. la nomination)
  requested_by  uuid references public.profiles(id) on delete set null,
  status        text not null default 'pending' check (status in ('pending', 'running', 'done', 'failed')),
  attempts      int not null default 0,
  last_error    text,
  document_id   uuid references public.documents(id) on delete set null,
  act_id        uuid references public.acts_register(id) on delete set null,
  created_at    timestamptz not null default now(),
  done_at       timestamptz
);
create index if not exists document_jobs_pending_idx on public.document_jobs(created_at) where status in ('pending', 'running');

create table if not exists public.generated_documents (
  id               uuid primary key default gen_random_uuid(),
  template_id      uuid references public.document_templates(id) on delete set null,
  template_version int,
  subject_type     text not null,
  subject_id       uuid not null,
  document_id      uuid not null references public.documents(id) on delete cascade,
  act_id           uuid references public.acts_register(id) on delete set null,
  sha256           text not null,
  created_by       uuid references public.profiles(id) on delete set null,
  created_at       timestamptz not null default now()
);

alter table public.acts_register enable row level security;
alter table public.document_jobs enable row level security;
alter table public.generated_documents enable row level security;
revoke all on public.acts_register, public.document_jobs, public.generated_documents from anon;
revoke insert, update, delete on public.acts_register, public.document_jobs, public.generated_documents from authenticated;
grant select on public.acts_register, public.document_jobs, public.generated_documents to authenticated;

create or replace function public.can_read_act(p_entity uuid, p_subject_type text, p_subject_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.has_perm('dashboard.exec') or public.has_perm('org.manage')
      or public.has_perm_entity('hr.admin', p_entity) or public.has_perm_entity('hr.view', p_entity)
      or public.has_perm_entity('legal.view', p_entity) or public.has_perm_entity('legal.admin', p_entity)
      or (p_subject_type = 'person' and p_subject_id = auth.uid())
$$;
drop policy if exists "actes: lecture" on public.acts_register;
create policy "actes: lecture" on public.acts_register for select to authenticated
  using (public.can_read_act(entity_id, subject_type, subject_id));
drop policy if exists "générations: lecture" on public.document_jobs;
create policy "générations: lecture" on public.document_jobs for select to authenticated
  using (requested_by = auth.uid() or public.can_manage_templates());
drop policy if exists "documents générés: lecture" on public.generated_documents;
create policy "documents générés: lecture" on public.generated_documents for select to authenticated
  using (public.document_access(document_id) >= 1);

-- -----------------------------------------------------------------------------
-- 4. Données d'un objet pour remplir un modèle
-- -----------------------------------------------------------------------------
create or replace function public.document_context(p_subject_type text, p_subject_id uuid, p_extra jsonb default '{}'::jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare ctx jsonb := '{}'::jsonb; v_entity uuid; e public.legal_entities; p public.profiles; c public.legal_contracts;
begin
  if p_subject_type = 'person' then
    select * into p from public.profiles where id = p_subject_id;
    v_entity := public.profile_entity(p_subject_id);
    ctx := jsonb_build_object('personne', jsonb_build_object(
      'nom_complet', p.full_name, 'prenom', p.first_name, 'nom', p.last_name, 'email', p.email,
      'intitule', coalesce(p.job_title, '—'), 'telephone', p.phone,
      'date_embauche', coalesce(to_char(p.hire_date, 'DD/MM/YYYY'), '—'),
      'unite', (select name from public.org_units where id = p.primary_unit_id)));
  elsif p_subject_type = 'contract' then
    select * into c from public.legal_contracts where id = p_subject_id;
    v_entity := c.entity_id;
    ctx := jsonb_build_object('contrat', jsonb_build_object(
      'reference', c.reference, 'titre', c.title, 'contrepartie', c.counterparty,
      'montant', coalesce(to_char(c.amount, 'FM999G999G999G990'), '—'), 'devise', c.currency,
      'date_effet', coalesce(to_char(c.effective_date, 'DD/MM/YYYY'), '—'),
      'echeance', coalesce(to_char(c.end_date, 'DD/MM/YYYY'), '—'),
      'renouvellement', case when c.auto_renew then 'oui' else 'non' end,
      'engagements', coalesce(c.obligations, '—')));
  elsif p_subject_type = 'decision' then
    select entity_id into v_entity from public.approval_requests where id = p_subject_id;
    ctx := (select jsonb_build_object('decision', jsonb_build_object(
      'objet', a.subject_label, 'statut', a.status, 'note', coalesce(a.decision_note, ''),
      'montant', coalesce(to_char(a.amount, 'FM999G999G999G990'), '—'),
      'date', coalesce(to_char(a.decided_at, 'DD/MM/YYYY'), '—'),
      'decideur', coalesce((select full_name from public.profiles where id = a.decided_by), '—')))
      from public.approval_requests a where a.id = p_subject_id);
  end if;
  select * into e from public.legal_entities where id = coalesce(v_entity, public.holding_entity_id());
  ctx := ctx || jsonb_build_object(
    'entite', jsonb_build_object('nom', e.name, 'raison_sociale', coalesce(e.legal_name, e.name),
      'rccm', coalesce(e.rccm, '—'), 'ifu', coalesce(e.ifu, '—'), 'pays', e.country, 'adresse', coalesce(e.address, '')),
    'date', to_char((now() at time zone 'Africa/Porto-Novo')::date, 'DD/MM/YYYY'),
    '_entity_id', e.id);
  return ctx || coalesce(p_extra, '{}'::jsonb);
end $$;
revoke execute on function public.document_context(text, uuid, jsonb) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 5. Demander, réserver, terminer une génération
-- -----------------------------------------------------------------------------
create or replace function public.request_document(p_template uuid, p_subject_type text, p_subject_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare t public.document_templates; v_id uuid;
begin
  select * into t from public.document_templates where id = p_template and active;
  if t.id is null then raise exception 'Modèle introuvable ou inactif'; end if;
  if t.subject_type <> p_subject_type then raise exception 'Ce modèle s''applique à un autre type d''objet'; end if;
  if not public.object_can_read(p_subject_type, p_subject_id) then raise exception 'Accès refusé' using errcode = '42501'; end if;
  if not (public.can_manage_templates() or (t.kind = 'attestation' and p_subject_type = 'person' and p_subject_id = auth.uid())) then
    raise exception 'La génération de ce document revient aux RH, au Juridique ou à la direction' using errcode = '42501';
  end if;
  insert into public.document_jobs (template_id, subject_type, subject_id, requested_by)
  values (p_template, p_subject_type, p_subject_id, auth.uid())
  returning id into v_id;
  return v_id;
end $$;
grant execute on function public.request_document(uuid, text, uuid) to authenticated;

/** Réserve des générations à traiter (clé serveur). */
create or replace function public.claim_document_jobs(p_limit int default 20, p_job uuid default null)
returns table (job_id uuid, template_id uuid, template_name text, template_kind text, template_version int,
               body text, category public.doc_category, subject_type text, subject_id uuid, context jsonb)
language plpgsql security definer set search_path = public as $$
begin
  return query
  with c as (
    select j.id from public.document_jobs j
    where (j.status = 'pending' or (j.status = 'running' and j.created_at < now() - interval '10 minutes'))
      and j.attempts < 5 and (p_job is null or j.id = p_job)
    order by j.created_at limit p_limit for update skip locked
  )
  update public.document_jobs j set status = 'running', attempts = j.attempts + 1
  from c, public.document_templates t
  where j.id = c.id and t.id = j.template_id
  returning j.id, t.id, t.name, t.kind, t.version, t.body, t.category, j.subject_type, j.subject_id,
            public.document_context(j.subject_type, j.subject_id, j.context);
end $$;
revoke execute on function public.claim_document_jobs(int, uuid) from public, anon, authenticated;

/**
 * Enregistre le document produit : fiche Drive, inscription au registre des
 * actes (numéro par entité), liens vers l'objet, événement et notifications.
 */
create or replace function public.complete_document_job(
  p_job uuid, p_storage_path text, p_file_name text, p_size bigint, p_sha256 text, p_text text default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare j public.document_jobs; t public.document_templates; v_doc uuid; v_act uuid; v_entity uuid; v_owner uuid;
        v_ref text; v_year int := extract(year from current_date)::int; v_num int; v_code text; v_title text;
        v_unit uuid; v_folder uuid; v_label text;
begin
  select * into j from public.document_jobs where id = p_job for update;
  if j.id is null or j.status = 'done' then raise exception 'Génération introuvable ou déjà terminée'; end if;
  select * into t from public.document_templates where id = j.template_id;
  v_entity := nullif(public.document_context(j.subject_type, j.subject_id, j.context)->>'_entity_id', '')::uuid;
  v_owner := coalesce(j.requested_by, (select id from public.profiles where system_role = 'ceo' and status = 'active' limit 1));
  v_label := (public.object_label(j.subject_type, j.subject_id)).label;
  v_title := t.name || ' — ' || coalesce(v_label, '');

  -- Rangement : la décision de nomination dans l'espace de l'unité concernée ;
  -- les autres documents personnels restent privés (propriétaire + intéressé).
  v_unit := nullif(j.context->'nomination'->>'unit_id', '')::uuid;
  if v_unit is not null then
    select id into v_folder from public.folders where is_root and space = 'unit' and unit_id = v_unit;
  end if;

  insert into public.documents (title, description, category, classification, owner_id, storage_path, file_name, mime_type,
                                size_bytes, folder_id, unit_id, content_text)
  values (v_title, 'Document généré à partir du modèle « ' || t.name || ' » (version ' || t.version || ')', t.category,
          case when v_folder is not null then 'internal' else 'restricted' end::public.doc_classification,
          v_owner, p_storage_path, p_file_name,
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document', p_size, v_folder, v_unit, left(p_text, 100000))
  returning id into v_doc;

  if j.subject_type = 'person' and j.subject_id is distinct from v_owner then
    insert into public.shares (document_id, profile_id, role, created_by) values (v_doc, j.subject_id, 'viewer', v_owner)
    on conflict do nothing;
  end if;

  if t.register_act then
    select code into v_code from public.legal_entities where id = v_entity;
    insert into public.invoice_counters (scope, year, last) values ('ACT-' || coalesce(v_code, 'HOLD'), v_year, 1)
    on conflict (scope, year) do update set last = public.invoice_counters.last + 1
    returning last into v_num;
    v_ref := 'ACT-' || coalesce(v_code, 'HOLD') || '-' || v_year || '-' || lpad(v_num::text, 4, '0');
    insert into public.acts_register (entity_id, year, number, reference, act_type, title, subject_type, subject_id,
                                      effective_date, document_id, sha256, created_by)
    values (coalesce(v_entity, public.holding_entity_id()), v_year, v_num, v_ref, t.kind, v_title, j.subject_type, j.subject_id,
            coalesce(nullif(j.context->'nomination'->>'start_date', '')::date, current_date), v_doc, p_sha256, v_owner)
    returning id into v_act;
    perform public.link_object('act', v_act, 'subject', j.subject_type, j.subject_id);
    perform public.link_object('act', v_act, 'document', 'document', v_doc);
  end if;

  insert into public.generated_documents (template_id, template_version, subject_type, subject_id, document_id, act_id, sha256, created_by)
  values (t.id, t.version, j.subject_type, j.subject_id, v_doc, v_act, p_sha256, v_owner);
  perform public.link_object('document', v_doc, 'subject', j.subject_type, j.subject_id);

  update public.document_jobs set status = 'done', done_at = now(), document_id = v_doc, act_id = v_act, last_error = null
   where id = p_job;

  perform public.emit_event('document.generated', j.subject_type, j.subject_id,
    t.name || coalesce(' n° ' || v_ref, '') || ' établi(e)', jsonb_build_object('document_id', v_doc, 'act_id', v_act, 'sha256', p_sha256),
    v_entity);
  if j.requested_by is not null then
    perform public.notify(j.requested_by, 'drive.generated', 'Document prêt : ' || t.name, coalesce(v_ref, v_label), '/documents/d/' || v_doc);
  end if;
  if j.subject_type = 'person' and j.subject_id is distinct from j.requested_by then
    perform public.notify(j.subject_id, 'drive.generated', t.name || ' vous concernant', coalesce(v_ref, ''), '/documents/d/' || v_doc);
  end if;
  return v_doc;
end $$;
revoke execute on function public.complete_document_job(uuid, text, text, bigint, text, text) from public, anon, authenticated;

create or replace function public.fail_document_job(p_job uuid, p_error text)
returns void language sql security definer set search_path = public as $$
  update public.document_jobs set status = case when attempts >= 5 then 'failed' else 'pending' end, last_error = left(p_error, 500)
   where id = p_job
$$;
revoke execute on function public.fail_document_job(uuid, text) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 6. Événements → documents : une nomination produit sa décision
-- -----------------------------------------------------------------------------
-- config : {"template_kind": "nomination", "roles": ["head", "deputy"]}
create or replace function public.process_event_jobs(p_limit int default 200)
returns int language plpgsql security definer set search_path = public as $$
declare j record; e public.domain_events; s public.event_subscriptions; n int := 0; r record; v_link text; v_tpl uuid;
begin
  for j in
    select * from public.event_jobs where status = 'pending'
    order by created_at limit p_limit for update skip locked
  loop
    begin
      select * into e from public.domain_events where id = j.event_id;
      select * into s from public.event_subscriptions where id = j.subscription_id;
      if j.handler = 'notify' then
        v_link := (public.object_label(e.subject_type, e.subject_id)).url;
        for r in
          select p.id from public.profiles p where p.status = 'active' and (
               (s.config->>'to' = 'ceo' and p.system_role = 'ceo')
            or (s.config->>'to' = 'subject' and e.subject_type = 'person' and p.id = e.subject_id)
            or (s.config->>'to' = 'payload_profile' and p.id = nullif(e.payload->>'profile_id', '')::uuid)
            or (s.config->>'to' = 'actor' and p.id = e.actor_id)
            or (s.config->>'to' in ('finance', 'hr', 'legal') and exists (
                  select 1 from public.role_grants g where g.profile_id = p.id
                    and g.permission = (s.config->>'to') || '.admin' and (g.expires_at is null or g.expires_at > now())
                    and (g.scope_entity_id is null or g.scope_entity_id = e.entity_id))))
        loop
          perform public.notify(r.id, 'event.' || e.type, coalesce(s.config->>'title', e.summary), e.summary, v_link);
        end loop;
      elsif j.handler = 'generate_document' then
        if s.config ? 'roles' and not ((s.config->'roles') ? coalesce(e.payload->>'role', '')) then
          null;  -- rôle non concerné (ex. simple membre)
        else
          select id into v_tpl from public.document_templates
           where kind = s.config->>'template_kind' and subject_type = e.subject_type and active
             and (entity_id is null or entity_id = e.entity_id)
           order by entity_id nulls last, created_at limit 1;
          if v_tpl is not null then
            insert into public.document_jobs (template_id, subject_type, subject_id, context, requested_by)
            values (v_tpl, e.subject_type, e.subject_id,
                    jsonb_build_object('nomination', jsonb_build_object(
                      'unit_id', e.payload->>'unit_id',
                      'unite', (select name from public.org_units where id = nullif(e.payload->>'unit_id', '')::uuid),
                      'role', case e.payload->>'role' when 'head' then 'responsable' when 'deputy' then 'adjoint(e)' else 'membre' end,
                      'intitule', coalesce(e.payload->>'title', (select job_title from public.profiles where id = e.subject_id), '—'),
                      'start_date', e.payload->>'start_date',
                      'date_effet', to_char(coalesce(nullif(e.payload->>'start_date', '')::date, current_date), 'DD/MM/YYYY'))),
                    e.actor_id);
          end if;
        end if;
      end if;
      update public.event_jobs set status = 'done', done_at = now(), attempts = attempts + 1 where id = j.id;
      n := n + 1;
    exception when others then
      update public.event_jobs set status = case when attempts >= 4 then 'failed' else 'pending' end,
             attempts = attempts + 1, last_error = left(sqlerrm, 500) where id = j.id;
    end;
  end loop;
  return n;
end $$;
revoke execute on function public.process_event_jobs(int) from public, anon, authenticated;

insert into public.event_subscriptions (event_type, handler, config, description)
select 'membership.appointed', 'generate_document', '{"template_kind": "nomination", "roles": ["head", "deputy"]}'::jsonb,
       'Une nomination de responsable ou d''adjoint produit sa décision de nomination, inscrite au registre des actes'
where not exists (select 1 from public.event_subscriptions where handler = 'generate_document' and event_type = 'membership.appointed');

-- La nomination enregistre aussi la date d'effet dans l'événement (pour la décision).
create or replace function public.graph_memberships()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_unit text; v_person text; v_entity uuid;
begin
  select name, entity_id into v_unit, v_entity from public.org_units where id = new.unit_id;
  select full_name into v_person from public.profiles where id = new.profile_id;
  if tg_op = 'INSERT' and new.end_date is null then
    perform public.emit_event('membership.appointed', 'person', new.profile_id,
      coalesce(v_person, '?') || ' nommé(e) ' || case new.role when 'head' then 'responsable' when 'deputy' then 'adjoint(e)' else 'membre' end
        || ' — ' || coalesce(v_unit, '?') || coalesce(' (' || new.title || ')', ''),
      jsonb_build_object('membership_id', new.id, 'unit_id', new.unit_id, 'role', new.role,
                         'title', coalesce(new.title, public.job_title_for(new.unit_id, new.role)), 'start_date', new.start_date),
      v_entity);
    perform public.link_object('unit', new.unit_id, 'member', 'person', new.profile_id);
  elsif tg_op = 'UPDATE' and new.end_date is not null and old.end_date is null then
    perform public.emit_event('membership.ended', 'person', new.profile_id,
      'Fin de fonction — ' || coalesce(v_unit, '?'), jsonb_build_object('membership_id', new.id, 'unit_id', new.unit_id, 'role', new.role), v_entity);
  end if;
  return null;
end $$;
