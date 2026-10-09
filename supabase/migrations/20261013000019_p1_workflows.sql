-- =============================================================================
-- VERIION OS — Migration 19 : moteur de workflows et boîte « À traiter »
-- (phase 1, lots P1-04 et P1-05)
-- =============================================================================
-- Toutes les décisions passent par un même moteur :
--   * workflow_definitions / workflow_steps : circuits versionnés et paramétrables
--     par le CEO (qui décide à quelle étape, à partir de quel montant, en
--     combien de temps) ;
--   * approval_requests reste l'instance d'un circuit (étape courante,
--     instantané du contenu validé, empreinte) ;
--   * workflow_actions : chaque geste (soumission, accord, refus, relance) ;
--   * approval_delegations : intérim pendant une absence ;
--   * les congés y entrent (validation par le responsable ou les RH) ;
--   * my_inbox() : tout ce qui attend une action de la personne.
-- Règles universelles : personne ne statue sur sa propre demande ; un refus est
-- motivé ; une modification du contenu rend l'accord caduc.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Modèle
-- -----------------------------------------------------------------------------
create table if not exists public.workflow_definitions (
  id          uuid primary key default gen_random_uuid(),
  kind        public.approval_kind not null,
  version     int not null default 1,
  name        text not null,
  active      boolean not null default true,
  created_by  uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at  timestamptz not null default now(),
  unique (kind, version)
);
create unique index if not exists workflow_definitions_one_active on public.workflow_definitions(kind) where active;

create table if not exists public.workflow_steps (
  id                  uuid primary key default gen_random_uuid(),
  definition_id       uuid not null references public.workflow_definitions(id) on delete cascade,
  position            int not null check (position >= 1),
  name                text not null check (length(trim(name)) > 1),
  approver_type       text not null check (approver_type in ('ceo', 'permission', 'unit_head', 'manager', 'manager_or_hr')),
  approver_permission text references public.permissions(key),
  min_amount          numeric(16,2) check (min_amount is null or min_amount >= 0),
  sla_hours           int not null default 48 check (sla_hours between 1 and 2160),
  unique (definition_id, position),
  check (approver_type <> 'permission' or approver_permission is not null)
);

alter table public.approval_requests
  add column if not exists definition_id   uuid references public.workflow_definitions(id) on delete set null,
  add column if not exists current_step    int,
  add column if not exists step_started_at timestamptz,
  add column if not exists escalated_step  int;

create table if not exists public.workflow_actions (
  id            bigint generated always as identity primary key,
  request_id    uuid not null references public.approval_requests(id) on delete cascade,
  step_position int,
  step_name     text,
  actor_id      uuid references public.profiles(id) on delete set null,
  action        text not null check (action in ('submit', 'approve', 'reject', 'escalate', 'cancel')),
  note          text,
  on_behalf_of  uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now()
);
create index if not exists workflow_actions_request_idx on public.workflow_actions(request_id, created_at);

create table if not exists public.approval_delegations (
  id           uuid primary key default gen_random_uuid(),
  from_profile uuid not null references public.profiles(id) on delete cascade default auth.uid(),
  to_profile   uuid not null references public.profiles(id) on delete cascade,
  starts_on    date not null default current_date,
  ends_on      date not null,
  reason       text not null check (length(trim(reason)) > 3),
  revoked_at   timestamptz,
  created_at   timestamptz not null default now(),
  check (ends_on >= starts_on),
  check (from_profile <> to_profile)
);
drop trigger if exists audit_approval_delegations on public.approval_delegations;
create trigger audit_approval_delegations after insert or update or delete on public.approval_delegations
  for each row execute function public.audit_trigger();

-- Circuits par défaut : le comportement actuel (une décision du CEO), et les
-- congés validés par le responsable ou les RH.
do $$
declare k public.approval_kind; v_def uuid;
begin
  foreach k in array array['budget', 'expense', 'legal_contract', 'operation_cycle', 'project', 'employment_contract', 'other', 'leave']::public.approval_kind[] loop
    if not exists (select 1 from public.workflow_definitions where kind = k) then
      insert into public.workflow_definitions (kind, version, name, active, created_by)
      values (k, 1, case k when 'leave' then 'Congé — validation du responsable' else 'Décision du CEO' end, true, null)
      returning id into v_def;
      if k = 'leave' then
        insert into public.workflow_steps (definition_id, position, name, approver_type, sla_hours)
        values (v_def, 1, 'Validation du responsable ou des RH', 'manager_or_hr', 72);
      else
        insert into public.workflow_steps (definition_id, position, name, approver_type, sla_hours)
        values (v_def, 1, 'Décision du CEO', 'ceo', 48);
      end if;
    end if;
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- 2. Congés : sujet d'un circuit
-- -----------------------------------------------------------------------------
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
    when 'leave' then jsonb_build_object(
      'profile_id', p_row->'profile_id', 'type', p_row->'type',
      'start_date', p_row->'start_date', 'end_date', p_row->'end_date')
    else null
  end
$$;

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
    when 'leave'               then select to_jsonb(l) into r from public.leave_requests l where l.id = p_subject;
    else r := null;
  end case;
  return r;
end $$;

create or replace function public.approval_subject_info(p_kind public.approval_kind, p_subject uuid,
  out allowed boolean, out label text, out amount numeric, out currency text, out unit_id uuid, out project_id uuid)
language plpgsql stable security definer set search_path = public as $$
declare r jsonb := public.approval_subject_row(p_kind, p_subject); v_entity uuid;
begin
  allowed := false;
  if r is null then return; end if;
  currency := coalesce(r->>'currency', 'XOF');
  v_entity := nullif(r->>'entity_id', '')::uuid;
  case p_kind
    when 'budget' then
      allowed := public.has_perm_entity('finance.admin', v_entity)
              or ((r->>'unit_id') is not null and public.has_perm('unit.manage', (r->>'unit_id')::uuid))
              or ((r->>'project_id') is not null and public.can_manage_project((r->>'project_id')::uuid));
      amount := (r->>'amount')::numeric;
      unit_id := (r->>'unit_id')::uuid; project_id := (r->>'project_id')::uuid;
      label := 'Budget ' || (r->>'fiscal_year') || ' — ' || coalesce(
        (select name from public.org_units where id = (r->>'unit_id')::uuid),
        (select name from public.projects where id = (r->>'project_id')::uuid), 'sans rattachement');
    when 'legal_contract' then
      allowed := public.has_perm_entity('legal.admin', v_entity) or (r->>'owner_id')::uuid = auth.uid();
      amount := (r->>'amount')::numeric;
      unit_id := (r->>'unit_id')::uuid; project_id := (r->>'project_id')::uuid;
      label := 'Contrat ' || (r->>'reference') || ' — ' || (r->>'title') || ' (' || (r->>'counterparty') || ')';
    when 'employment_contract' then
      allowed := public.has_perm_entity('hr.admin', v_entity);
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
    when 'leave' then
      allowed := (r->>'profile_id')::uuid = auth.uid();
      amount := null;
      unit_id := (select primary_unit_id from public.profiles where id = (r->>'profile_id')::uuid);
      label := 'Congé — ' || coalesce((select full_name from public.profiles where id = (r->>'profile_id')::uuid), '?')
               || ' (' || to_char((r->>'start_date')::date, 'DD/MM') || ' → ' || to_char((r->>'end_date')::date, 'DD/MM')
               || ', ' || (r->>'days') || ' j)';
    else
      allowed := false;
  end case;
end $$;

-- -----------------------------------------------------------------------------
-- 3. Qui agit à quelle étape
-- -----------------------------------------------------------------------------
create or replace function public.active_delegation_from(p_from uuid, p_to uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.approval_delegations d
                  where d.from_profile = p_from and d.to_profile = p_to and d.revoked_at is null
                    and current_date between d.starts_on and d.ends_on)
$$;

create or replace function public.workflow_current_step(p_request uuid)
returns public.workflow_steps language sql stable security definer set search_path = public as $$
  select s.* from public.approval_requests a
  join public.workflow_steps s on s.definition_id = a.definition_id and s.position = a.current_step
  where a.id = p_request
$$;

/** Prochaine étape applicable après « p_after » (les étapes à seuil ne s'appliquent qu'au-delà de leur montant). */
create or replace function public.workflow_next_step(p_definition uuid, p_amount numeric, p_after int)
returns public.workflow_steps language sql stable security definer set search_path = public as $$
  select s.* from public.workflow_steps s
  where s.definition_id = p_definition and s.position > coalesce(p_after, 0)
    and (s.min_amount is null or coalesce(p_amount, 0) >= s.min_amount)
  order by s.position limit 1
$$;

create or replace function public.can_act_on_step(p_request uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare a public.approval_requests; s public.workflow_steps;
begin
  select * into a from public.approval_requests where id = p_request;
  if a.id is null or a.status <> 'pending' or not public.is_active_user() then return false; end if;
  if a.requested_by = auth.uid() then return false; end if;
  s := public.workflow_current_step(p_request);
  if s.id is null then
    -- Demande antérieure au moteur : décision du CEO.
    return public.can_decide_approvals();
  end if;
  return case s.approver_type
    when 'ceo' then public.can_decide_approvals()
      or exists (select 1 from public.profiles c where c.system_role = 'ceo' and c.status = 'active'
                  and public.active_delegation_from(c.id, auth.uid()))
    when 'permission' then public.is_ceo() or public.has_perm_entity(s.approver_permission, a.entity_id)
    when 'unit_head' then public.is_ceo() or (a.unit_id is not null and public.has_perm('unit.manage', a.unit_id))
    when 'manager' then public.manages_profile(a.requested_by)
      or exists (select 1 from public.profiles p where p.id = a.requested_by and public.active_delegation_from(p.manager_id, auth.uid()))
    when 'manager_or_hr' then public.manages_profile(a.requested_by) or public.has_perm_entity('hr.admin', a.entity_id)
      or exists (select 1 from public.profiles p where p.id = a.requested_by and public.active_delegation_from(p.manager_id, auth.uid()))
    else false
  end;
end $$;
grant execute on function public.can_act_on_step(uuid) to authenticated;

/** Personnes à prévenir pour l'étape courante d'une demande. */
create or replace function public.step_approvers(p_request uuid)
returns setof uuid language plpgsql stable security definer set search_path = public as $$
declare a public.approval_requests; s public.workflow_steps;
begin
  select * into a from public.approval_requests where id = p_request;
  s := public.workflow_current_step(p_request);
  return query
  select distinct x.id from (
    select p.id from public.profiles p where p.status = 'active' and p.system_role = 'ceo'
      and (s.id is null or s.approver_type in ('ceo', 'permission', 'unit_head'))
    union
    select g.profile_id from public.role_grants g
     where (s.id is null or s.approver_type = 'ceo') and g.permission = 'approvals.decide'
       and (g.expires_at is null or g.expires_at > now())
    union
    select d.to_profile from public.approval_delegations d
      join public.profiles c on c.id = d.from_profile and c.system_role = 'ceo'
     where (s.id is null or s.approver_type = 'ceo') and d.revoked_at is null and current_date between d.starts_on and d.ends_on
    union
    select g.profile_id from public.role_grants g
     where s.approver_type = 'permission' and g.permission = s.approver_permission and g.scope_unit_id is null
       and (g.scope_entity_id is null or g.scope_entity_id = a.entity_id) and (g.expires_at is null or g.expires_at > now())
    union
    select g.profile_id from public.role_grants g join public.org_units u on u.id = a.unit_id
     where s.approver_type in ('unit_head', 'manager', 'manager_or_hr') and g.permission = 'unit.manage'
       and g.scope_unit_id = any(u.path) and (g.expires_at is null or g.expires_at > now())
    union
    select p.manager_id from public.profiles p
     where s.approver_type in ('manager', 'manager_or_hr') and p.id = a.requested_by and p.manager_id is not null
    union
    select g.profile_id from public.role_grants g
     where s.approver_type = 'manager_or_hr' and g.permission = 'hr.admin'
       and (g.scope_entity_id is null or g.scope_entity_id = a.entity_id) and (g.expires_at is null or g.expires_at > now())
  ) x
  join public.profiles p on p.id = x.id and p.status = 'active'
  where x.id is distinct from a.requested_by;
end $$;
revoke execute on function public.step_approvers(uuid) from public, anon, authenticated;

create or replace function public.notify_step(p_request uuid)
returns void language plpgsql security definer set search_path = public as $$
declare a public.approval_requests; s public.workflow_steps; r record;
begin
  select * into a from public.approval_requests where id = p_request;
  s := public.workflow_current_step(p_request);
  for r in select public.step_approvers(p_request) as id loop
    perform public.notify(r.id, 'approval.requested',
      'Décision attendue : ' || a.subject_label,
      coalesce(s.name, 'Décision du CEO') || case when a.amount is not null and a.kind <> 'leave'
        then ' · ' || to_char(a.amount, 'FM999G999G999G990') || ' ' || a.currency else '' end,
      case when a.kind = 'leave' then '/rh?onglet=validation' else '/validations?demande=' || a.id end);
  end loop;
end $$;
revoke execute on function public.notify_step(uuid) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. Soumettre, décider, retirer
-- -----------------------------------------------------------------------------
create or replace function public.request_approval(
  p_kind public.approval_kind, p_subject uuid, p_label text,
  p_amount numeric default null, p_justification text default null,
  p_unit uuid default null, p_project uuid default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; info record; v_row jsonb; v_label text; v_amount numeric; v_currency text := 'XOF';
        v_def uuid; s public.workflow_steps;
begin
  if not public.is_active_user() then raise exception 'Compte inactif' using errcode = '42501'; end if;

  select id into v_id from public.approval_requests
   where kind = p_kind and subject_id = p_subject and status = 'pending' and p_subject is not null;
  if v_id is not null then return v_id; end if;

  v_row := case when p_subject is not null then public.approval_subject_row(p_kind, p_subject) end;
  if public.approval_snapshot(p_kind, '{}'::jsonb) is not null then
    if v_row is null then raise exception 'Objet de la demande introuvable'; end if;
    select * into info from public.approval_subject_info(p_kind, p_subject);
    if not info.allowed then
      raise exception 'Seul le responsable de cet objet peut en demander l''accord' using errcode = '42501';
    end if;
    v_label := info.label; v_amount := info.amount; v_currency := coalesce(info.currency, 'XOF');
    p_unit := info.unit_id; p_project := info.project_id;
  else
    if length(trim(coalesce(p_label, ''))) < 3 then raise exception 'Précisez l''objet de la demande'; end if;
    v_label := trim(p_label); v_amount := p_amount;
    if p_kind = 'expense' and coalesce(p_amount, 0) <= 0 then raise exception 'Indiquez le montant de la dépense'; end if;
  end if;

  -- Le CEO décide directement (sauf pour ses propres congés, qui suivent le circuit
  -- et sont alors approuvés d'office, faute de supérieur).
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

  select id into v_def from public.workflow_definitions where kind = p_kind and active;
  s := case when v_def is not null then public.workflow_next_step(v_def, v_amount, 0) end;

  insert into public.approval_requests (kind, subject_id, subject_label, amount, currency, justification, unit_id, project_id,
                                        subject_snapshot, subject_hash, definition_id, current_step, step_started_at)
  values (p_kind, p_subject, v_label, v_amount, v_currency, nullif(trim(coalesce(p_justification, '')), ''), p_unit, p_project,
          public.approval_snapshot(p_kind, v_row), public.approval_hash(p_kind, v_row),
          v_def, s.position, now())
  returning id into v_id;

  insert into public.workflow_actions (request_id, step_position, step_name, actor_id, action, note)
  values (v_id, 0, 'Soumission', auth.uid(), 'submit', nullif(trim(coalesce(p_justification, '')), ''));

  -- Aucune étape applicable (circuit vide sous ce montant) : accord d'office, tracé.
  if v_def is not null and s.id is null then
    update public.approval_requests set status = 'approved', decided_at = now(), decision_note = 'Aucune étape requise pour ce montant'
     where id = v_id;
    return v_id;
  end if;

  perform public.notify_step(v_id);
  return v_id;
end $$;

create or replace function public.decide_approval(p_id uuid, p_approve boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare a public.approval_requests; v_row jsonb; s public.workflow_steps; nxt public.workflow_steps; v_behalf uuid;
begin
  select * into a from public.approval_requests where id = p_id for update;
  if a.id is null then raise exception 'Demande introuvable'; end if;
  if a.status <> 'pending' then raise exception 'Cette demande a déjà été traitée'; end if;
  if a.requested_by = auth.uid() then
    raise exception 'Vous ne pouvez pas statuer sur votre propre demande' using errcode = '42501';
  end if;
  if not public.can_act_on_step(p_id) then
    raise exception 'Cette décision ne vous revient pas à cette étape du circuit' using errcode = '42501';
  end if;
  if a.kind <> 'leave' then perform public.require_mfa(); end if;
  if not p_approve and length(trim(coalesce(p_note, ''))) < 3 then
    raise exception 'Motivez le refus : la personne doit savoir quoi corriger';
  end if;
  if p_approve and a.subject_id is not null and a.subject_hash is not null then
    v_row := public.approval_subject_row(a.kind, a.subject_id);
    if public.approval_hash(a.kind, v_row) is distinct from a.subject_hash then
      raise exception 'Le contenu a changé depuis la demande : elle doit être soumise à nouveau.';
    end if;
  end if;

  s := public.workflow_current_step(p_id);
  -- Intérim : décision prise au nom du titulaire absent.
  select d.from_profile into v_behalf from public.approval_delegations d
   where d.to_profile = auth.uid() and d.revoked_at is null and current_date between d.starts_on and d.ends_on
   order by d.created_at desc limit 1;

  insert into public.workflow_actions (request_id, step_position, step_name, actor_id, action, note, on_behalf_of)
  values (p_id, a.current_step, coalesce(s.name, 'Décision du CEO'), auth.uid(),
          case when p_approve then 'approve' else 'reject' end, nullif(trim(coalesce(p_note, '')), ''), v_behalf);

  if p_approve and s.id is not null then
    nxt := public.workflow_next_step(a.definition_id, a.amount, a.current_step);
    if nxt.id is not null then
      update public.approval_requests set current_step = nxt.position, step_started_at = now() where id = p_id;
      perform public.notify_step(p_id);
      perform public.notify(a.requested_by, 'approval.progress', 'Étape franchie : ' || a.subject_label,
        coalesce(s.name, '') || ' — prochaine étape : ' || nxt.name, '/validations?demande=' || a.id);
      return;
    end if;
  end if;

  update public.approval_requests
     set status = case when p_approve then 'approved' else 'rejected' end::public.approval_status,
         decided_by = auth.uid(), decided_at = now(), decision_note = nullif(trim(coalesce(p_note, '')), '')
   where id = p_id;

  -- Les congés préviennent eux-mêmes le demandeur (leave_requests_after_write).
  if a.kind <> 'leave' then
    perform public.notify(a.requested_by,
      case when p_approve then 'approval.approved' else 'approval.rejected' end,
      case when p_approve then 'Accord : ' else 'Refus : ' end || a.subject_label,
      nullif(trim(coalesce(p_note, '')), ''), '/validations?demande=' || a.id);
  end if;
end $$;

create or replace function public.cancel_approval(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.approval_requests set status = 'cancelled'
   where id = p_id and status = 'pending' and (requested_by = auth.uid() or public.can_decide_approvals());
  if not found then raise exception 'Demande introuvable ou déjà tranchée'; end if;
  insert into public.workflow_actions (request_id, actor_id, action) values (p_id, auth.uid(), 'cancel');
end $$;

/** Peut agir sur l'étape courante (lecture du guichet). */
create or replace function public.can_act_on_approval(p_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.can_act_on_step(p_id)
$$;
grant execute on function public.can_act_on_approval(uuid) to authenticated;

drop policy if exists "validations: lecture" on public.approval_requests;
create policy "validations: lecture" on public.approval_requests for select to authenticated
  using (public.is_active_user() and (
    requested_by = auth.uid() or public.can_decide_approvals()
    or public.has_perm('dashboard.exec')
    or (unit_id is not null and public.has_perm('unit.manage', unit_id))
    or (project_id is not null and public.can_view_project(project_id))
    or (kind = 'leave' and public.has_perm_entity('hr.admin', entity_id))
    or public.can_act_on_step(id)));

drop view if exists public.approval_requests_status;
create view public.approval_requests_status with (security_invoker = true) as
  select a.*, public.approval_is_stale(a.id) as stale,
         public.can_act_on_step(a.id) as can_act,
         (select s.name from public.workflow_steps s where s.definition_id = a.definition_id and s.position = a.current_step) as current_step_name,
         (select count(*) from public.workflow_steps s where s.definition_id = a.definition_id
            and (s.min_amount is null or coalesce(a.amount, 0) >= s.min_amount))::int as steps_total,
         (select count(*) from public.workflow_steps s where s.definition_id = a.definition_id and s.position < coalesce(a.current_step, 0)
            and (s.min_amount is null or coalesce(a.amount, 0) >= s.min_amount))::int + 1 as step_index
  from public.approval_requests a;
revoke all on public.approval_requests_status from anon;
grant select on public.approval_requests_status to authenticated;

-- -----------------------------------------------------------------------------
-- 5. Congés : soumis au circuit, décidés uniquement par lui
-- -----------------------------------------------------------------------------
create or replace function public.leave_requests_before_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status and auth.uid() is not null then
    if new.status in ('approved', 'rejected') then
      if current_setting('veriion.workflow', true) is distinct from 'on' then
        raise exception 'La décision passe par le circuit de validation (onglet Validation des RH ou boîte « À traiter »).' using errcode = '42501';
      end if;
      new.approver_id := auth.uid();
      new.decided_at := now();
    elsif new.status = 'cancelled' and old.profile_id <> auth.uid() and not public.has_perm('hr.admin') then
      raise exception 'Seul le demandeur peut annuler' using errcode = '42501';
    end if;
  end if;
  if old.status = 'pending' and new.status = 'pending'
     and (new.start_date, new.end_date, new.type) is distinct from (old.start_date, old.end_date, old.type)
     and auth.uid() is not null then
    raise exception 'Une demande en cours ne se modifie pas : annulez-la et faites-en une nouvelle.' using errcode = '42501';
  end if;
  return new;
end $$;

create or replace function public.leave_requests_after_write()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_req uuid; v_status public.approval_status;
begin
  if tg_op = 'INSERT' then
    v_req := public.request_approval('leave', new.id, null, null, new.reason);
    select status into v_status from public.approval_requests where id = v_req;
    -- Congé du CEO (décision directe) ou circuit sans étape : approuvé d'office.
    if v_status = 'approved' then
      perform set_config('veriion.workflow', 'on', true);
      update public.leave_requests set status = 'approved', decision_note = 'Validé d''office' where id = new.id;
      perform set_config('veriion.workflow', 'off', true);
    end if;
  elsif new.status is distinct from old.status then
    if new.status in ('approved', 'rejected') then
      perform public.notify(new.profile_id, 'leave.decided',
        case when new.status = 'approved' then 'Congé approuvé' else 'Congé refusé' end,
        coalesce(new.decision_note, to_char(new.start_date, 'DD/MM') || ' → ' || to_char(new.end_date, 'DD/MM')), '/rh');
    elsif new.status = 'cancelled' then
      update public.approval_requests set status = 'cancelled' where kind = 'leave' and subject_id = new.id and status = 'pending';
    end if;
  end if;
  return null;
end $$;

-- Effets d'une décision : publication, activation, congé, retour en rédaction.
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
    elsif new.kind = 'leave' then
      perform set_config('veriion.workflow', 'on', true);
      update public.leave_requests set status = 'approved', decision_note = new.decision_note
       where id = new.subject_id and status = 'pending';
      perform set_config('veriion.workflow', 'off', true);
    end if;
  elsif new.status in ('rejected', 'cancelled') then
    if new.kind = 'operation_cycle' then
      update public.operation_cycles set status = 'draft' where id = new.subject_id and status = 'pending_ceo';
    elsif new.kind = 'legal_contract' then
      update public.legal_contracts set status = 'legal_review' where id = new.subject_id and status = 'pending_ceo';
    elsif new.kind = 'employment_contract' then
      update public.employment_contracts set status = 'draft' where id = new.subject_id and status = 'pending_ceo';
    elsif new.kind = 'leave' and new.status = 'rejected' then
      perform set_config('veriion.workflow', 'on', true);
      update public.leave_requests set status = 'rejected', decision_note = new.decision_note
       where id = new.subject_id and status = 'pending';
      perform set_config('veriion.workflow', 'off', true);
    end if;
  end if;
  return null;
end $$;

-- Demandes de congé en attente : rattachées au circuit.
do $$
declare l record; v_def uuid; v_id uuid;
begin
  select id into v_def from public.workflow_definitions where kind = 'leave' and active;
  for l in select r.* from public.leave_requests r
            where r.status = 'pending' and not exists (select 1 from public.approval_requests a where a.kind = 'leave' and a.subject_id = r.id)
  loop
    insert into public.approval_requests (kind, subject_id, subject_label, requested_by, unit_id, definition_id, current_step,
                                          step_started_at, subject_snapshot, subject_hash, justification)
    values ('leave', l.id,
            'Congé — ' || coalesce((select full_name from public.profiles where id = l.profile_id), '?')
              || ' (' || to_char(l.start_date, 'DD/MM') || ' → ' || to_char(l.end_date, 'DD/MM') || ', ' || l.days || ' j)',
            l.profile_id, (select primary_unit_id from public.profiles where id = l.profile_id), v_def, 1, l.created_at,
            public.approval_snapshot('leave', to_jsonb(l)), public.approval_hash('leave', to_jsonb(l)), l.reason)
    returning id into v_id;
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- 6. Délais : relance et escalade au CEO
-- -----------------------------------------------------------------------------
create or replace function public.process_workflow_sla()
returns int language plpgsql security definer set search_path = public as $$
declare a record; n int := 0; r record;
begin
  for a in
    select q.*, s.name as step_name, s.sla_hours
    from public.approval_requests q
    join public.workflow_steps s on s.definition_id = q.definition_id and s.position = q.current_step
    where q.status = 'pending' and q.step_started_at + make_interval(hours => s.sla_hours) < now()
      and q.escalated_step is distinct from q.current_step
  loop
    perform public.notify_step(a.id);
    for r in select p.id from public.profiles p where p.status = 'active' and p.system_role = 'ceo' loop
      perform public.notify(r.id, 'approval.overdue', 'Décision en retard : ' || a.subject_label,
        'Étape « ' || a.step_name || ' » en attente depuis plus de ' || a.sla_hours || ' h.',
        case when a.kind = 'leave' then '/rh?onglet=validation' else '/validations?demande=' || a.id end);
    end loop;
    update public.approval_requests set escalated_step = current_step where id = a.id;
    insert into public.workflow_actions (request_id, step_position, step_name, action, note)
    values (a.id, a.current_step, a.step_name, 'escalate', 'Délai de ' || a.sla_hours || ' h dépassé : relance et alerte du CEO');
    n := n + 1;
  end loop;
  return n;
end $$;
revoke execute on function public.process_workflow_sla() from public, anon, authenticated;

do $$
begin
  perform cron.schedule('veriion-workflow-sla', '7 * * * *', 'select public.process_workflow_sla()');
exception when others then
  raise notice 'pg_cron non disponible : délais des circuits à planifier plus tard (%)', sqlerrm;
end $$;

-- -----------------------------------------------------------------------------
-- 7. Paramétrage des circuits (CEO)
-- -----------------------------------------------------------------------------
-- p_steps : [{"name": "…", "approver_type": "ceo|permission|unit_head|manager|manager_or_hr",
--             "approver_permission": "finance.admin", "min_amount": 1000000, "sla_hours": 48}, …]
create or replace function public.save_workflow(p_kind public.approval_kind, p_name text, p_steps jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_version int; st jsonb; i int := 0;
begin
  if not public.is_ceo() then raise exception 'Seul le CEO paramètre les circuits' using errcode = '42501'; end if;
  perform public.require_mfa();
  if jsonb_typeof(p_steps) <> 'array' or jsonb_array_length(p_steps) = 0 then
    raise exception 'Un circuit compte au moins une étape';
  end if;
  select coalesce(max(version), 0) + 1 into v_version from public.workflow_definitions where kind = p_kind;
  update public.workflow_definitions set active = false where kind = p_kind and active;
  insert into public.workflow_definitions (kind, version, name, active)
  values (p_kind, v_version, coalesce(nullif(trim(p_name), ''), 'Circuit ' || p_kind), true)
  returning id into v_id;
  for st in select * from jsonb_array_elements(p_steps) loop
    i := i + 1;
    insert into public.workflow_steps (definition_id, position, name, approver_type, approver_permission, min_amount, sla_hours)
    values (v_id, i, trim(st->>'name'), st->>'approver_type', nullif(st->>'approver_permission', ''),
            nullif(st->>'min_amount', '')::numeric, coalesce(nullif(st->>'sla_hours', '')::int, 48));
  end loop;
  return v_id;
end $$;
revoke execute on function public.save_workflow(public.approval_kind, text, jsonb) from public, anon;
grant execute on function public.save_workflow(public.approval_kind, text, jsonb) to authenticated;

alter table public.workflow_definitions enable row level security;
alter table public.workflow_steps enable row level security;
alter table public.workflow_actions enable row level security;
alter table public.approval_delegations enable row level security;
revoke all on public.workflow_definitions, public.workflow_steps, public.workflow_actions, public.approval_delegations from anon;
revoke insert, update, delete on public.workflow_definitions, public.workflow_steps, public.workflow_actions from authenticated;
grant select on public.workflow_definitions, public.workflow_steps, public.workflow_actions to authenticated;
grant select, insert, update on public.approval_delegations to authenticated;

drop policy if exists "circuits: lecture" on public.workflow_definitions;
create policy "circuits: lecture" on public.workflow_definitions for select to authenticated using (public.is_active_user());
drop policy if exists "étapes: lecture" on public.workflow_steps;
create policy "étapes: lecture" on public.workflow_steps for select to authenticated using (public.is_active_user());
drop policy if exists "gestes: lecture" on public.workflow_actions;
create policy "gestes: lecture" on public.workflow_actions for select to authenticated
  using (exists (select 1 from public.approval_requests a where a.id = request_id));
drop policy if exists "délégations: lecture" on public.approval_delegations;
create policy "délégations: lecture" on public.approval_delegations for select to authenticated
  using (from_profile = auth.uid() or to_profile = auth.uid() or public.is_admin());
drop policy if exists "délégations: création" on public.approval_delegations;
create policy "délégations: création" on public.approval_delegations for insert to authenticated
  with check (from_profile = auth.uid() and public.is_active_user()
              and exists (select 1 from public.profiles p where p.id = to_profile and p.status = 'active'));
drop policy if exists "délégations: révocation" on public.approval_delegations;
create policy "délégations: révocation" on public.approval_delegations for update to authenticated
  using (from_profile = auth.uid()) with check (from_profile = auth.uid());

-- -----------------------------------------------------------------------------
-- 8. Boîte « À traiter »
-- -----------------------------------------------------------------------------
create or replace function public.my_inbox()
returns table (kind text, item_id uuid, title text, detail text, url text, since timestamptz, urgent boolean)
language sql stable security definer set search_path = public as $$
  -- Décisions attendues de moi à l'étape courante d'un circuit
  select 'decision', a.id, a.subject_label,
         coalesce((select s.name from public.workflow_steps s where s.definition_id = a.definition_id and s.position = a.current_step), 'Décision du CEO'),
         case when a.kind = 'leave' then '/rh?onglet=validation' else '/validations?demande=' || a.id end,
         coalesce(a.step_started_at, a.created_at),
         coalesce(a.step_started_at, a.created_at) < now() - interval '2 days'
  from public.approval_requests a
  where a.status = 'pending' and public.can_act_on_step(a.id)
  union all
  -- Tâches soumises à ma vérification
  select 'task_review', t.id, t.title, 'Tâche à vérifier',
         case when t.project_id is not null then '/projets/' || t.project_id || '?tache=' || t.id else '/taches' end,
         coalesce(t.submitted_at, t.updated_at), coalesce(t.submitted_at, t.updated_at) < now() - interval '2 days'
  from public.tasks t
  where t.status = 'review' and coalesce(t.reviewer_id, t.reporter_id) = auth.uid() and t.assignee_id is distinct from auth.uid()
  union all
  -- Mes tâches en retard ou dues aujourd'hui
  select 'task_due', t.id, t.title, case when t.due_date < current_date then 'En retard' else 'À rendre aujourd''hui' end,
         case when t.project_id is not null then '/projets/' || t.project_id || '?tache=' || t.id else '/taches' end,
         t.due_date::timestamptz, t.due_date < current_date
  from public.tasks t
  where t.assignee_id = auth.uid() and t.status not in ('done', 'review') and t.due_date <= current_date
  union all
  -- Rapports de cycle à prendre en compte (Opérations)
  select 'report', o.id, 'Rapport — ' || coalesce(c.title, ''), coalesce(p.name, ''), '/operations?rapport=' || o.id,
         coalesce(o.submitted_at, o.created_at), coalesce(o.submitted_at, o.created_at) < now() - interval '3 days'
  from public.operation_reports o
  join public.operation_cycles c on c.id = o.cycle_id
  left join public.projects p on p.id = o.project_id
  where o.status = 'submitted' and (public.has_perm('ops.review') or public.has_perm('ops.plan'))
  union all
  -- Contrats dont je suis responsable et dont le préavis court
  select 'contract_term', c.id, c.reference || ' — ' || c.title, 'Échéance le ' || to_char(c.end_date, 'DD/MM/YYYY'),
         '/juridique/' || c.id, (c.end_date - c.renewal_notice_days)::timestamptz, c.end_date - current_date <= 15
  from public.legal_contracts c
  where c.owner_id = auth.uid() and c.status in ('signed', 'active') and c.end_date is not null
    and c.end_date - c.renewal_notice_days <= current_date and c.end_date >= current_date
  union all
  -- Contrats juridiques approuvés, en attente de la signature
  select 'signature', c.id, c.reference || ' — ' || c.title, 'Accord du CEO obtenu : à signer', '/juridique/' || c.id,
         c.updated_at, false
  from public.legal_contracts c
  where c.status = 'pending_ceo' and public.has_perm_entity('legal.admin', c.entity_id) and public.approval_granted('legal_contract', c.id)
  union all
  -- Contrats de travail approuvés, en attente de la signature
  select 'signature', c.id, 'Contrat de travail — ' || coalesce(p.full_name, '?'), 'Accord du CEO obtenu : à signer', '/rh?onglet=effectif',
         c.approved_at, false
  from public.employment_contracts c
  left join public.profiles p on p.id = c.profile_id
  where c.status in ('draft', 'pending_ceo') and public.has_perm_entity('hr.admin', c.entity_id)
    and public.approval_granted('employment_contract', c.id)
  union all
  -- Étapes d'intégration ou de départ qui me sont confiées
  select 'lifecycle', l.id, l.title, case l.kind when 'onboarding' then 'Intégration — ' else 'Départ — ' end || coalesce(p.full_name, ''),
         '/rh?onglet=parcours', coalesce(l.due_date::timestamptz, l.created_at), l.due_date < current_date
  from public.lifecycle_items l
  left join public.profiles p on p.id = l.profile_id
  where l.assignee_id = auth.uid() and l.done_at is null
$$;
grant execute on function public.my_inbox() to authenticated;

create or replace function public.my_inbox_count()
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int from public.my_inbox()
$$;
grant execute on function public.my_inbox_count() to authenticated;
