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
