-- Schéma de référence de VERIION OS (généré par scripts/dump-schema.sh, ne pas modifier à la main).
--
-- PostgreSQL database dump
--




--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: account_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.account_type AS ENUM (
    'prospect',
    'client',
    'partner'
);


--
-- Name: approval_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.approval_kind AS ENUM (
    'budget',
    'expense',
    'legal_contract',
    'operation_cycle',
    'project',
    'employment_contract',
    'other'
);


--
-- Name: approval_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.approval_status AS ENUM (
    'pending',
    'approved',
    'rejected',
    'cancelled'
);


--
-- Name: channel_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.channel_kind AS ENUM (
    'unit',
    'project',
    'group',
    'direct'
);


--
-- Name: contract_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contract_type AS ENUM (
    'cdi',
    'cdd',
    'internship',
    'freelance',
    'consultant'
);


--
-- Name: cycle_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.cycle_kind AS ENUM (
    'monthly',
    'weekly',
    'daily'
);


--
-- Name: cycle_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.cycle_status AS ENUM (
    'draft',
    'pending_ceo',
    'published',
    'closed'
);


--
-- Name: doc_category; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.doc_category AS ENUM (
    'contract',
    'procedure',
    'presentation',
    'policy',
    'technical',
    'minutes',
    'project',
    'other'
);


--
-- Name: doc_classification; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.doc_classification AS ENUM (
    'internal',
    'restricted',
    'confidential'
);


--
-- Name: doc_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.doc_kind AS ENUM (
    'file',
    'doc',
    'sheet',
    'slides'
);


--
-- Name: employee_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.employee_status AS ENUM (
    'active',
    'suspended',
    'offboarded'
);


--
-- Name: folder_space; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.folder_space AS ENUM (
    'personal',
    'unit',
    'project',
    'company'
);


--
-- Name: grant_source; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.grant_source AS ENUM (
    'auto',
    'manual'
);


--
-- Name: incident_severity; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.incident_severity AS ENUM (
    'low',
    'medium',
    'high',
    'critical'
);


--
-- Name: incident_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.incident_status AS ENUM (
    'open',
    'mitigated',
    'resolved'
);


--
-- Name: interaction_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.interaction_kind AS ENUM (
    'call',
    'email',
    'meeting',
    'note'
);


--
-- Name: invoice_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.invoice_status AS ENUM (
    'draft',
    'sent',
    'paid',
    'overdue',
    'cancelled'
);


--
-- Name: leave_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.leave_type AS ENUM (
    'annual',
    'sick',
    'maternity',
    'paternity',
    'unpaid',
    'other'
);


--
-- Name: legal_contract_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.legal_contract_status AS ENUM (
    'draft',
    'legal_review',
    'pending_ceo',
    'signed',
    'active',
    'expired',
    'terminated'
);


--
-- Name: legal_contract_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.legal_contract_type AS ENUM (
    'nda',
    'partnership',
    'client',
    'supplier',
    'licence',
    'employment',
    'statutory',
    'other'
);


--
-- Name: membership_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.membership_role AS ENUM (
    'head',
    'deputy',
    'member'
);


--
-- Name: objective_level; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.objective_level AS ENUM (
    'company',
    'unit',
    'individual'
);


--
-- Name: objective_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.objective_status AS ENUM (
    'on_track',
    'at_risk',
    'off_track',
    'done'
);


--
-- Name: opportunity_stage; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.opportunity_stage AS ENUM (
    'lead',
    'qualified',
    'proposal',
    'negotiation',
    'won',
    'lost'
);


--
-- Name: ops_item_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.ops_item_status AS ENUM (
    'planned',
    'in_progress',
    'done',
    'dropped'
);


--
-- Name: priority; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.priority AS ENUM (
    'low',
    'medium',
    'high',
    'urgent'
);


--
-- Name: project_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.project_status AS ENUM (
    'planned',
    'active',
    'on_hold',
    'completed',
    'cancelled'
);


--
-- Name: request_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.request_status AS ENUM (
    'pending',
    'approved',
    'rejected',
    'cancelled'
);


--
-- Name: share_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.share_role AS ENUM (
    'viewer',
    'editor',
    'manager'
);


--
-- Name: system_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.system_role AS ENUM (
    'ceo',
    'admin',
    'employee'
);


--
-- Name: task_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.task_status AS ENUM (
    'backlog',
    'todo',
    'in_progress',
    'review',
    'done'
);


--
-- Name: txn_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.txn_type AS ENUM (
    'revenue',
    'expense'
);


--
-- Name: unit_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.unit_kind AS ENUM (
    'company',
    'department',
    'subdepartment',
    'team'
);


--
-- Name: access_code_valid(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.access_code_valid(p_code text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
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
end $_$;


--
-- Name: access_codes_drop_on_offboard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.access_codes_drop_on_offboard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  delete from public.access_codes where profile_id = new.id;
  return null;
end $$;


--
-- Name: acknowledge_operation_report(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.acknowledge_operation_report(p_report uuid, p_note text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: activate_budget(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.activate_budget(p_budget uuid, p_justification text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: announcements_after_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.announcements_after_insert() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: appoint_member(uuid, uuid, public.membership_role, text, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.appoint_member(p_unit uuid, p_profile uuid, p_role public.membership_role, p_title text DEFAULT NULL::text, p_start date DEFAULT CURRENT_DATE) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: approval_freeze(public.approval_kind, uuid, jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approval_freeze(p_kind public.approval_kind, p_subject uuid, p_old jsonb, p_new jsonb) RETURNS void
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if auth.uid() is not null
     and public.approval_hash(p_kind, p_old) is distinct from public.approval_hash(p_kind, p_new)
     and public.approval_pending(p_kind, p_subject) then
    raise exception 'Une demande d''accord est en cours sur ce contenu : retirez-la avant de le modifier.' using errcode = '42501';
  end if;
end $$;


--
-- Name: approval_granted(public.approval_kind, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approval_granted(p_kind public.approval_kind, p_subject uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select public.approval_valid(p_kind, p_subject, public.approval_subject_row(p_kind, p_subject))
$$;


--
-- Name: approval_hash(public.approval_kind, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approval_hash(p_kind public.approval_kind, p_row jsonb) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  select case when public.approval_snapshot(p_kind, p_row) is null then null
              else encode(extensions.digest(public.approval_snapshot(p_kind, p_row)::text, 'sha256'), 'hex') end
$$;


--
-- Name: approval_is_stale(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approval_is_stale(p_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select a.subject_id is not null and a.subject_hash is not null and a.status in ('approved', 'pending')
     and public.approval_hash(a.kind, public.approval_subject_row(a.kind, a.subject_id)) is distinct from a.subject_hash
  from public.approval_requests a where a.id = p_id
$$;


--
-- Name: approval_pending(public.approval_kind, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approval_pending(p_kind public.approval_kind, p_subject uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (select 1 from public.approval_requests where kind = p_kind and subject_id = p_subject and status = 'pending')
$$;


--
-- Name: approval_requests_apply(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approval_requests_apply() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: approval_snapshot(public.approval_kind, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approval_snapshot(p_kind public.approval_kind, p_row jsonb) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    AS $$
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


--
-- Name: approval_subject_info(public.approval_kind, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approval_subject_info(p_kind public.approval_kind, p_subject uuid, OUT allowed boolean, OUT label text, OUT amount numeric, OUT currency text, OUT unit_id uuid, OUT project_id uuid) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: approval_subject_row(public.approval_kind, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approval_subject_row(p_kind public.approval_kind, p_subject uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: approval_valid(public.approval_kind, uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approval_valid(p_kind public.approval_kind, p_subject uuid, p_row jsonb) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.approval_requests
     where kind = p_kind and subject_id = p_subject and status = 'approved'
       and subject_hash is not distinct from public.approval_hash(p_kind, p_row)
  )
$$;


--
-- Name: audit_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.audit_trigger() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: available_expense_approvals(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.available_expense_approvals() RETURNS TABLE(id uuid, subject_label text, amount numeric, consumed_amount numeric, remaining numeric, currency text, decided_at timestamp with time zone, unit_id uuid, project_id uuid)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select a.id, a.subject_label, a.amount, a.consumed_amount, a.amount - a.consumed_amount, a.currency, a.decided_at,
         a.unit_id, a.project_id
  from public.approval_requests a
  where a.kind = 'expense' and a.status = 'approved' and coalesce(a.amount, 0) > a.consumed_amount
    and public.has_perm('finance.admin')
  order by a.decided_at desc
$$;


--
-- Name: budgets_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.budgets_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: can_access_channel(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_access_channel(p_channel uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: can_assign_task(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_assign_task(p_assignee uuid, p_project uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: can_contribute_project(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_contribute_project(p_project uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select public.can_manage_project(p_project)
      or coalesce(public.project_role(p_project) in ('lead', 'member'), false)
      or exists (select 1 from public.projects p where p.id = p_project and public.has_perm('unit.assign', p.unit_id))
$$;


--
-- Name: can_decide_approvals(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_decide_approvals() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select public.is_ceo() or public.has_perm('approvals.decide')
$$;


--
-- Name: can_decide_leave(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_decide_leave(p_request uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.leave_requests r
    where r.id = p_request and r.profile_id <> auth.uid()
      and (public.has_perm('hr.admin') or public.manages_profile(r.profile_id))
  )
$$;


--
-- Name: can_edit_objective(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_edit_objective(p_obj uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.objectives o where o.id = p_obj and (
      (o.level = 'company' and public.has_perm('objectives.admin'))
      or (o.level = 'unit' and (public.has_perm('unit.manage', o.unit_id) or public.has_perm('objectives.admin')))
      or (o.level = 'individual' and (o.owner_id = auth.uid() or public.manages_profile(o.owner_id)))
    )
  )
$$;


--
-- Name: can_edit_task(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_edit_task(p_task uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.tasks t where t.id = p_task and (
      t.assignee_id = auth.uid() or t.reporter_id = auth.uid()
      or (t.project_id is not null and public.can_contribute_project(t.project_id)))
  )
$$;


--
-- Name: can_manage_project(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_manage_project(p_project uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: can_plan_project(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_plan_project(p_project uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select public.has_perm('ops.plan') or public.has_perm('projects.admin') or public.is_ceo()
      or public.is_project_lead(p_project)
$$;


--
-- Name: can_read_crm(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_read_crm() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select public.has_perm('crm.view') or public.has_perm('crm.edit') or public.has_perm('crm.admin') or public.has_perm('dashboard.exec')
$$;


--
-- Name: can_read_document(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_read_document(p_doc uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select public.document_access(p_doc) >= 1
$$;


--
-- Name: can_read_finance(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_read_finance() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select public.has_perm('finance.view') or public.has_perm('finance.admin') or public.has_perm('dashboard.exec')
$$;


--
-- Name: can_view_project(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_view_project(p_project uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: can_view_task(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_view_task(p_task uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.tasks t where t.id = p_task and (
      t.assignee_id = auth.uid() or t.reporter_id = auth.uid()
      or (t.project_id is not null and public.can_view_project(t.project_id)))
  )
$$;


--
-- Name: can_view_unit(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_view_unit(p_unit uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select public.in_unit(p_unit) or public.has_perm('unit.manage', p_unit) or public.has_perm('dashboard.exec')
$$;


--
-- Name: cancel_approval(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cancel_approval(p_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  update public.approval_requests set status = 'cancelled'
   where id = p_id and status = 'pending' and (requested_by = auth.uid() or public.can_decide_approvals());
  if not found then raise exception 'Demande introuvable ou déjà tranchée'; end if;
end $$;


--
-- Name: ceo_approval_threshold(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ceo_approval_threshold() RETURNS numeric
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select coalesce((select ceo_approval_threshold from public.governance_settings where id), 500000)
$$;


--
-- Name: channel_people(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.channel_people(p_channel uuid) RETURNS TABLE(id uuid, full_name text, avatar_url text, job_title text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: channels_after_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.channels_after_insert() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if new.kind = 'group' and new.created_by is not null then
    insert into public.channel_members (channel_id, profile_id, role) values (new.id, new.created_by, 'owner')
    on conflict do nothing;
  end if;
  return null;
end $$;


--
-- Name: claim_digest_batch(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.claim_digest_batch() RETURNS TABLE(id uuid, profile_id uuid, kind text, category text, title text, body text, link text, created_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: claim_email_batch(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.claim_email_batch(p_limit integer DEFAULT 500) RETURNS TABLE(id uuid, profile_id uuid, kind text, category text, title text, body text, link text, created_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: claim_push_batch(integer, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.claim_push_batch(p_limit integer DEFAULT 200, p_profile uuid DEFAULT NULL::uuid) RETURNS TABLE(id uuid, profile_id uuid, kind text, category text, title text, body text, link text, created_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: clear_access_code(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clear_access_code(p_profile uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: decide_approval(uuid, boolean, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.decide_approval(p_id uuid, p_approve boolean, p_note text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: document_access(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.document_access(p_doc uuid) RETURNS integer
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: documents_move_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.documents_move_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: drive_listing(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.drive_listing(p_folder uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: drive_tree(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.drive_tree() RETURNS TABLE(id uuid, parent_id uuid, name text, space public.folder_space, depth integer, is_root boolean, access integer)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select f.id, f.parent_id, case when f.is_root and f.space = 'personal' then 'Mon espace' else f.name end,
         f.space, f.depth, f.is_root, public.folder_access(f.id)
  from public.folders f
  where f.deleted_at is null
    and (f.space <> 'personal' or f.owner_id = auth.uid() or exists (select 1 from public.shares s where s.folder_id = any(f.path)))
    and public.folder_access(f.id) >= 2
  order by f.depth, lower(f.name)
$$;


--
-- Name: duplicate_document(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.duplicate_document(p_doc uuid, p_folder uuid DEFAULT NULL::uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: employment_contracts_after_sign(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.employment_contracts_after_sign() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if new.status = 'signed' and (tg_op = 'INSERT' or old.status <> 'signed') and new.gross_monthly is not null then
    insert into public.salaries (profile_id, gross_monthly, effective_from, notes, created_by)
    values (new.profile_id, new.gross_monthly, new.start_date, 'Contrat signé', auth.uid());
  end if;
  return null;
end $$;


--
-- Name: employment_contracts_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.employment_contracts_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: employment_contracts_transition(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.employment_contracts_transition() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: end_membership(uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.end_membership(p_membership uuid, p_end date DEFAULT CURRENT_DATE) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare m public.unit_memberships;
begin
  select * into m from public.unit_memberships where id = p_membership and end_date is null;
  if not found then raise exception 'Affectation introuvable ou déjà clôturée'; end if;
  if not (public.has_perm('org.manage') or public.has_perm('unit.manage', m.unit_id)) then
    raise exception 'Permission refusée' using errcode = '42501';
  end if;
  update public.unit_memberships set end_date = greatest(m.start_date, p_end) where id = p_membership;
end $$;


--
-- Name: ensure_personal_root(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ensure_personal_root(p_profile uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: exec_dashboard(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.exec_dashboard(p_year integer DEFAULT NULL::integer) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: folder_access(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.folder_access(p_folder uuid) RETURNS integer
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: folders_compute(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.folders_compute() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: folders_move_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.folders_move_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: folders_propagate(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.folders_propagate() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.path is distinct from old.path then
    update public.folders set parent_id = parent_id where parent_id = new.id;
  end if;
  return null;
end $$;


--
-- Name: generate_daily_reminders(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_daily_reminders() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: generate_extra_reminders(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_extra_reminders() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: global_search(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.global_search(q text) RETURNS TABLE(kind text, id uuid, title text, subtitle text, link text)
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $$
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


--
-- Name: governance_settings_touch(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.governance_settings_touch() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end $$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: has_access_code(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.has_access_code(p_profile uuid DEFAULT NULL::uuid) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare target uuid := coalesce(p_profile, auth.uid());
begin
  if target is null then return false; end if;
  if target <> auth.uid() and not public.has_perm('users.admin') then
    raise exception 'Permission refusée' using errcode = '42501';
  end if;
  return exists (select 1 from public.access_codes where profile_id = target);
end $$;


--
-- Name: has_perm(text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.has_perm(p_perm text, p_unit uuid DEFAULT NULL::uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: in_unit(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.in_unit(p_unit uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select p_unit is not null and exists (
    select 1 from public.unit_memberships m
    join public.org_units u on u.id = m.unit_id
    where m.profile_id = auth.uid() and m.end_date is null and p_unit = any(u.path)
  )
$$;


--
-- Name: invoice_lines_after_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.invoice_lines_after_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  perform public.recompute_invoice(coalesce(new.invoice_id, old.invoice_id));
  return null;
end $$;


--
-- Name: invoice_lines_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.invoice_lines_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_status public.invoice_status;
begin
  select status into v_status from public.invoices where id = coalesce(new.invoice_id, old.invoice_id);
  if auth.uid() is not null and v_status is distinct from 'draft' then
    raise exception 'Les lignes d''une facture émise ne se modifient plus.' using errcode = '42501';
  end if;
  return coalesce(new, old);
end $$;


--
-- Name: invoices_after_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.invoices_after_update() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: invoices_before_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.invoices_before_insert() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if new.number is null or auth.uid() is not null then
    new.number := public.next_invoice_number('FAC', new.issue_date);
  end if;
  new.status := 'draft';
  new.sent_at := null; new.paid_at := null;
  return new;
end $$;


--
-- Name: invoices_before_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.invoices_before_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: is_active_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_active_user() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists(select 1 from public.profiles where id = auth.uid() and status = 'active')
$$;


--
-- Name: is_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists(select 1 from public.profiles where id = auth.uid() and status = 'active' and system_role in ('ceo', 'admin'))
$$;


--
-- Name: is_ceo(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_ceo() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists(select 1 from public.profiles where id = auth.uid() and status = 'active' and system_role = 'ceo')
$$;


--
-- Name: is_meeting_participant(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_meeting_participant(p_meeting uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (select 1 from public.meetings m where m.id = p_meeting and m.organizer_id = auth.uid())
      or exists (select 1 from public.meeting_attendees a where a.meeting_id = p_meeting and a.profile_id = auth.uid())
$$;


--
-- Name: is_project_lead(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_project_lead(p_project uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.projects p
    where p.id = p_project and (p.lead_id = auth.uid() or p.owner_id = auth.uid())
  ) or coalesce(public.project_role(p_project) = 'lead', false)
$$;


--
-- Name: is_project_liaison(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_project_liaison(p_project uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.project_liaisons l
    where l.project_id = p_project
      and (l.profile_id = auth.uid() or public.has_perm('unit.manage', l.unit_id))
  )
$$;


--
-- Name: job_title_for(uuid, public.membership_role); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.job_title_for(p_unit uuid, p_role public.membership_role) RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: leave_requests_after_write(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leave_requests_after_write() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: leave_requests_before_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leave_requests_before_update() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: legal_contracts_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legal_contracts_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: legal_contracts_transition(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legal_contracts_transition() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: manages_profile(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.manages_profile(p_profile uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select public.is_ceo()
      or exists (select 1 from public.profiles p where p.id = p_profile and p.manager_id = auth.uid())
      or exists (select 1 from public.unit_memberships m
                 where m.profile_id = p_profile and m.end_date is null
                   and public.has_perm('unit.manage', m.unit_id))
$$;


--
-- Name: mark_channel_read(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mark_channel_read(p_channel uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if not public.can_access_channel(p_channel) then raise exception 'Accès refusé' using errcode = '42501'; end if;
  insert into public.channel_members (channel_id, profile_id, last_read_at)
  values (p_channel, auth.uid(), now())
  on conflict (channel_id, profile_id) do update set last_read_at = now();
end $$;


--
-- Name: mark_overdue_invoices(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mark_overdue_invoices() RETURNS integer
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  with u as (
    update public.invoices set status = 'overdue'
    where status = 'sent' and due_date < current_date
    returning 1
  ) select count(*)::int from u
$$;


--
-- Name: max_grant_days(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.max_grant_days() RETURNS integer
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select coalesce((select max_grant_days from public.governance_settings where id), 90)
$$;


--
-- Name: meeting_attendees_after_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.meeting_attendees_after_insert() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare m public.meetings;
begin
  select * into m from public.meetings where id = new.meeting_id;
  perform public.notify(new.profile_id, 'meeting.invite', 'Invitation : ' || m.title,
    to_char(m.starts_at at time zone 'Africa/Porto-Novo', 'DD/MM à HH24:MI'), '/reunions');
  return null;
end $$;


--
-- Name: membership_rank(public.membership_role); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.membership_rank(r public.membership_role) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
  select case r when 'head' then 3 when 'deputy' then 2 else 1 end
$$;


--
-- Name: merge_org_units(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.merge_org_units(p_source uuid, p_target uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: message_reactions_before_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.message_reactions_before_insert() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  select channel_id into new.channel_id from public.messages where id = new.message_id;
  return new;
end $$;


--
-- Name: messages_after_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.messages_after_insert() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: messages_before_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.messages_before_insert() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: mfa_ok(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mfa_ok() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select auth.uid() is null
      or not coalesce((select mfa_enforced from public.governance_settings where id), true)
      or coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2'
$$;


--
-- Name: my_channels(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.my_channels() RETURNS TABLE(id uuid, kind public.channel_kind, name text, description text, unit_id uuid, project_id uuid, is_private boolean, last_message_at timestamp with time zone, unread integer, is_member boolean, other_profile_id uuid, other_name text, other_avatar text, other_title text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: my_drive_spaces(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.my_drive_spaces() RETURNS TABLE(id uuid, space public.folder_space, name text, unit_id uuid, project_id uuid, access integer, color text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: my_permissions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.my_permissions() RETURNS TABLE(permission text, scope_unit_id uuid)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select p.key, null::uuid from public.permissions p where public.is_ceo()
  union
  select p.key, null::uuid from public.permissions p
    where public.is_admin() and p.key in ('org.manage', 'users.admin', 'grants.manage', 'audit.view')
  union
  select g.permission, g.scope_unit_id from public.role_grants g
    where g.profile_id = auth.uid() and (g.expires_at is null or g.expires_at > now()) and public.is_active_user()
$$;


--
-- Name: next_invoice_number(text, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.next_invoice_number(p_scope text, p_date date) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_year int := extract(year from coalesce(p_date, current_date))::int; v_n int;
begin
  insert into public.invoice_counters (scope, year, last) values (p_scope, v_year, 1)
  on conflict (scope, year) do update set last = public.invoice_counters.last + 1
  returning last into v_n;
  return p_scope || '-' || v_year || '-' || lpad(v_n::text, 5, '0');
end $$;


--
-- Name: notification_category(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notification_category(p_kind text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
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


--
-- Name: notifications_dispatch(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notifications_dispatch() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
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
end $_$;


--
-- Name: notify(uuid, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify(p_profile uuid, p_kind text, p_title text, p_body text DEFAULT NULL::text, p_link text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if p_profile is null or p_profile = auth.uid() then return; end if;
  insert into public.notifications (profile_id, kind, title, body, link)
  values (p_profile, p_kind, p_title, p_body, p_link);
end $$;


--
-- Name: offboard_employee(uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offboard_employee(p_profile uuid, p_date date DEFAULT CURRENT_DATE) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: open_direct_channel(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.open_direct_channel(p_other uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: operation_cycles_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.operation_cycles_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  perform public.approval_freeze('operation_cycle', new.id, to_jsonb(old), to_jsonb(new));
  return new;
end $$;


--
-- Name: opportunities_before_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.opportunities_before_update() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: ops_health(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ops_health() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
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
end $_$;


--
-- Name: org_units_after_domain_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.org_units_after_domain_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare r record;
begin
  if new.domain is distinct from old.domain or new.archived_at is distinct from old.archived_at then
    for r in select distinct profile_id from public.unit_memberships where unit_id = new.id and end_date is null loop
      perform public.sync_auto_grants(r.profile_id);
    end loop;
  end if;
  return null;
end $$;


--
-- Name: org_units_after_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.org_units_after_insert() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if new.kind <> 'company' then
    insert into public.channels (kind, name, description, unit_id, is_private)
    values ('unit', new.name, 'Canal interne — ' || new.name, new.id, true);
  end if;
  return null;
end $$;


--
-- Name: org_units_compute_path(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.org_units_compute_path() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: org_units_drive_sync(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.org_units_drive_sync() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if tg_op = 'INSERT' and new.kind <> 'company' then
    insert into public.folders (space, name, unit_id, is_root) values ('unit', new.name, new.id, true)
    on conflict do nothing;
  elsif tg_op = 'UPDATE' and new.name is distinct from old.name then
    update public.folders set name = new.name where is_root and space = 'unit' and unit_id = new.id;
  end if;
  return null;
end $$;


--
-- Name: org_units_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.org_units_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: org_units_propagate_path(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.org_units_propagate_path() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.path is distinct from old.path then
    update public.org_units set parent_id = parent_id where parent_id = new.id;
  end if;
  return null;
end $$;


--
-- Name: permission_reserved(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.permission_reserved(p_perm text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select coalesce((select reserved from public.permissions where key = p_perm), true)
$$;


--
-- Name: process_contract_terms(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.process_contract_terms() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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




--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    email text NOT NULL,
    first_name text DEFAULT ''::text NOT NULL,
    last_name text DEFAULT ''::text NOT NULL,
    full_name text GENERATED ALWAYS AS (TRIM(BOTH FROM ((first_name || ' '::text) || last_name))) STORED,
    job_title text,
    phone text,
    avatar_url text,
    bio text,
    location text,
    system_role public.system_role DEFAULT 'employee'::public.system_role NOT NULL,
    status public.employee_status DEFAULT 'active'::public.employee_status NOT NULL,
    primary_unit_id uuid,
    manager_id uuid,
    hire_date date,
    birth_date date,
    last_seen_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    profile_completed_at timestamp with time zone
);


--
-- Name: profile_fields_complete(public.profiles); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.profile_fields_complete(p public.profiles) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  select length(trim(coalesce(p.first_name, ''))) > 1
     and length(trim(coalesce(p.last_name,  ''))) > 1
     and length(trim(coalesce(p.phone,      ''))) > 5
     and length(trim(coalesce(p.location,   ''))) > 1
$$;


--
-- Name: profile_in_channel(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.profile_in_channel(p_profile uuid, p_channel uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: profiles_after_insert_drive(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.profiles_after_insert_drive() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  perform public.ensure_personal_root(new.id);
  return null;
end $$;


--
-- Name: profiles_after_insert_onboarding(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.profiles_after_insert_onboarding() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: profiles_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.profiles_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: profiles_track_completion(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.profiles_track_completion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if public.profile_fields_complete(new) then
    new.profile_completed_at := coalesce(new.profile_completed_at, now());
  else
    new.profile_completed_at := null;
  end if;
  return new;
end $$;


--
-- Name: project_liaisons_after_write(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.project_liaisons_after_write() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: project_role(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.project_role(p_project uuid) RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select role from public.project_members where project_id = p_project and profile_id = auth.uid()
$$;


--
-- Name: projects_after_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.projects_after_insert() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if new.owner_id is not null then
    insert into public.project_members (project_id, profile_id, role) values (new.id, new.owner_id, 'lead')
    on conflict do nothing;
  end if;
  insert into public.channels (kind, name, description, project_id, unit_id, is_private, created_by)
  values ('project', new.name, 'Canal du projet ' || new.code, new.id, new.unit_id, true, new.owner_id);
  return null;
end $$;


--
-- Name: projects_drive_sync(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.projects_drive_sync() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if tg_op = 'INSERT' then
    insert into public.folders (space, name, project_id, is_root) values ('project', new.name, new.id, true)
    on conflict do nothing;
  elsif new.name is distinct from old.name then
    update public.folders set name = new.name where is_root and space = 'project' and project_id = new.id;
  end if;
  return null;
end $$;


--
-- Name: projects_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.projects_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: projects_sync_lead(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.projects_sync_lead() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: publish_operation_cycle(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.publish_operation_cycle(p_cycle uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: purge_trash(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.purge_trash() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare n int;
begin
  with d as (delete from public.documents where deleted_at < now() - interval '30 days' returning 1) select count(*) into n from d;
  delete from public.folders where deleted_at < now() - interval '30 days';
  return n;
end $$;


--
-- Name: recompute_invoice(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.recompute_invoice(p_invoice uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: record_ceo_decision(public.approval_kind, uuid, jsonb, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.record_ceo_decision(p_kind public.approval_kind, p_subject uuid, p_row jsonb, p_note text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: refresh_job_title(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_job_title(p_profile uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: register_push_subscription(text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.register_push_subscription(p_endpoint text, p_p256dh text, p_auth text, p_device text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if auth.uid() is null then raise exception 'Non connecté' using errcode = '42501'; end if;
  if p_endpoint !~ '^https://' then raise exception 'Abonnement invalide'; end if;
  insert into public.push_subscriptions (profile_id, endpoint, p256dh, auth, device)
  values (auth.uid(), p_endpoint, p_p256dh, p_auth, left(p_device, 120))
  on conflict (endpoint) do update set profile_id = auth.uid(), p256dh = excluded.p256dh, auth = excluded.auth,
    device = excluded.device, created_at = now();
end $$;


--
-- Name: remind_upcoming_meetings(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.remind_upcoming_meetings() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: replace_document_file(uuid, text, text, text, bigint, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.replace_document_file(p_doc uuid, p_storage_path text, p_file_name text, p_mime text, p_size bigint, p_note text DEFAULT NULL::text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: request_approval(public.approval_kind, uuid, text, numeric, text, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.request_approval(p_kind public.approval_kind, p_subject uuid, p_label text, p_amount numeric DEFAULT NULL::numeric, p_justification text DEFAULT NULL::text, p_unit uuid DEFAULT NULL::uuid, p_project uuid DEFAULT NULL::uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: require_approval(public.approval_kind, uuid, jsonb, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.require_approval(p_kind public.approval_kind, p_subject uuid, p_row jsonb, p_message text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if auth.uid() is null then return; end if;
  if public.approval_valid(p_kind, p_subject, p_row) then return; end if;
  if public.is_ceo() then
    perform public.record_ceo_decision(p_kind, p_subject, p_row);
    return;
  end if;
  raise exception '%', p_message using errcode = '42501';
end $$;


--
-- Name: require_mfa(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.require_mfa() RETURNS void
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if not public.mfa_ok() then
    raise exception 'Double authentification requise pour cette opération : validez votre code de sécurité.' using errcode = '42501';
  end if;
end $$;


--
-- Name: restore_document_version(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.restore_document_version(p_version uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: restore_item(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.restore_item(p_folder uuid DEFAULT NULL::uuid, p_doc uuid DEFAULT NULL::uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: reverse_transaction(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reverse_transaction(p_id uuid, p_reason text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: review_task(uuid, boolean, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.review_task(p_task uuid, p_approve boolean, p_note text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: role_templates_resync(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.role_templates_resync() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare r record;
begin
  for r in select distinct profile_id from public.unit_memberships where end_date is null loop
    perform public.sync_auto_grants(r.profile_id);
  end loop;
  return null;
end $$;


--
-- Name: save_document_content(uuid, jsonb, text, integer, boolean, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_document_content(p_doc uuid, p_content jsonb, p_text text, p_base_revision integer DEFAULT NULL::integer, p_snapshot boolean DEFAULT false, p_note text DEFAULT NULL::text, p_ydoc text DEFAULT NULL::text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: search_messages(text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_messages(q text, p_channel uuid DEFAULT NULL::uuid) RETURNS TABLE(id uuid, channel_id uuid, channel_name text, channel_kind public.channel_kind, author_id uuid, body text, created_at timestamp with time zone, parent_id uuid)
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $$
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


--
-- Name: set_access_code(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_access_code(p_code text, p_current text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at := now();
  return new;
end $$;


--
-- Name: share_rank(public.share_role); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.share_rank(r public.share_role) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
  select case r when 'manager' then 3 when 'editor' then 2 else 1 end
$$;


--
-- Name: shared_with_me(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.shared_with_me() RETURNS TABLE(kind text, id uuid, name text, doc_kind public.doc_kind, role public.share_role, shared_by uuid, shared_at timestamp with time zone, mime_type text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: shares_after_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.shares_after_insert() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: start_call(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.start_call(p_channel uuid, p_url text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare mid uuid;
begin
  if not public.can_access_channel(p_channel) then raise exception 'Accès refusé' using errcode = '42501'; end if;
  if p_url !~ '^https://' then raise exception 'Lien d''appel invalide'; end if;
  insert into public.messages (channel_id, author_id, kind, body, attachments)
  values (p_channel, auth.uid(), 'call', 'a lancé un appel vidéo', jsonb_build_array(jsonb_build_object('type', 'call', 'url', p_url)))
  returning id into mid;
  return mid;
end $$;


--
-- Name: submit_contract_for_signature(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.submit_contract_for_signature(p_contract uuid, p_justification text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: submit_employment_contract(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.submit_employment_contract(p_contract uuid, p_justification text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: submit_operation_report(uuid, integer, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.submit_operation_report(p_cycle uuid, p_progress integer, p_summary text, p_blockers text DEFAULT NULL::text, p_next text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: submit_task(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.submit_task(p_task uuid, p_note text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: sync_auto_grants(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_auto_grants(p_profile uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: task_comments_after_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.task_comments_after_insert() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare t public.tasks;
begin
  select * into t from public.tasks where id = new.task_id;
  perform public.notify(t.assignee_id, 'task.comment', 'Commentaire sur : ' || t.title, left(new.body, 140),
    case when t.project_id is not null then '/projets/' || t.project_id || '?tache=' || t.id else '/taches' end);
  return null;
end $$;


--
-- Name: tasks_after_write(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tasks_after_write() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: tasks_assignment_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tasks_assignment_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: tasks_before_write(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tasks_before_write() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: tasks_protect_review(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tasks_protect_review() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: toggle_pin(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.toggle_pin(p_message uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare m public.messages;
begin
  select * into m from public.messages where id = p_message;
  if m.id is null or not public.can_access_channel(m.channel_id) then raise exception 'Accès refusé' using errcode = '42501'; end if;
  update public.messages set pinned_at = case when pinned_at is null then now() end,
                             pinned_by = case when pinned_at is null then auth.uid() end
   where id = p_message;
  return m.pinned_at is null;
end $$;


--
-- Name: transactions_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.transactions_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: transactions_immutable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.transactions_immutable() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: transfer_ceo(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.transfer_ceo(p_to uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: trash_item(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trash_item(p_folder uuid DEFAULT NULL::uuid, p_doc uuid DEFAULT NULL::uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: try_uuid(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.try_uuid(t text) RETURNS uuid
    LANGUAGE plpgsql IMMUTABLE
    AS $$
begin
  return t::uuid;
exception when others then
  return null;
end $$;


--
-- Name: unit_memberships_after_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.unit_memberships_after_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: unit_memberships_notify(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.unit_memberships_notify() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare u text;
begin
  select name into u from public.org_units where id = new.unit_id;
  perform public.notify(new.profile_id, 'org.appointed',
    case new.role when 'head' then 'Vous êtes nommé(e) responsable de ' when 'deputy' then 'Vous êtes nommé(e) adjoint(e) de ' else 'Vous avez rejoint ' end || u,
    'Vos droits ont été mis à jour automatiquement.', '/organisation/' || new.unit_id);
  return null;
end $$;


--
-- Name: unit_overview(uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.unit_overview(p_unit uuid, p_year integer DEFAULT NULL::integer) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: verify_access_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.verify_access_code(p_code text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: access_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.access_codes (
    profile_id uuid NOT NULL,
    code_hash text NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    locked_until timestamp with time zone,
    last_unlock_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    type public.account_type DEFAULT 'prospect'::public.account_type NOT NULL,
    industry text,
    country text,
    city text,
    website text,
    email text,
    phone text,
    owner_id uuid DEFAULT auth.uid(),
    notes text,
    tags text[] DEFAULT '{}'::text[] NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: announcements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.announcements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    pinned boolean DEFAULT false NOT NULL,
    unit_id uuid,
    author_id uuid DEFAULT auth.uid(),
    published_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: approval_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.approval_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    kind public.approval_kind NOT NULL,
    subject_id uuid,
    subject_label text NOT NULL,
    amount numeric(16,2),
    currency text DEFAULT 'XOF'::text NOT NULL,
    justification text,
    unit_id uuid,
    project_id uuid,
    status public.approval_status DEFAULT 'pending'::public.approval_status NOT NULL,
    requested_by uuid DEFAULT auth.uid(),
    decided_by uuid,
    decided_at timestamp with time zone,
    decision_note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    subject_snapshot jsonb,
    subject_hash text,
    consumed_amount numeric(16,2) DEFAULT 0 NOT NULL,
    direct_decision boolean DEFAULT false NOT NULL
);


--
-- Name: approval_requests_status; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.approval_requests_status WITH (security_invoker='true') AS
 SELECT id,
    kind,
    subject_id,
    subject_label,
    amount,
    currency,
    justification,
    unit_id,
    project_id,
    status,
    requested_by,
    decided_by,
    decided_at,
    decision_note,
    created_at,
    updated_at,
    subject_snapshot,
    subject_hash,
    consumed_amount,
    direct_decision,
    public.approval_is_stale(id) AS stale
   FROM public.approval_requests a;


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    id bigint NOT NULL,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    actor_id uuid,
    action text NOT NULL,
    table_name text NOT NULL,
    record_id text,
    old_data jsonb,
    new_data jsonb,
    changed_fields text[]
);


--
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.audit_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: budgets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.budgets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    unit_id uuid,
    fiscal_year integer NOT NULL,
    amount numeric(16,2) NOT NULL,
    currency text DEFAULT 'XOF'::text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    project_id uuid,
    CONSTRAINT budgets_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT budgets_fiscal_year_check CHECK (((fiscal_year >= 2000) AND (fiscal_year <= 2100))),
    CONSTRAINT budgets_scope_chk CHECK (((unit_id IS NOT NULL) OR (project_id IS NOT NULL))),
    CONSTRAINT budgets_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text])))
);


--
-- Name: channel_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.channel_members (
    channel_id uuid NOT NULL,
    profile_id uuid NOT NULL,
    role text DEFAULT 'member'::text NOT NULL,
    last_read_at timestamp with time zone DEFAULT now() NOT NULL,
    muted boolean DEFAULT false NOT NULL,
    joined_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT channel_members_role_check CHECK ((role = ANY (ARRAY['owner'::text, 'member'::text])))
);


--
-- Name: channels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.channels (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    kind public.channel_kind DEFAULT 'group'::public.channel_kind NOT NULL,
    name text NOT NULL,
    description text,
    unit_id uuid,
    project_id uuid,
    is_private boolean DEFAULT false NOT NULL,
    dm_key text,
    created_by uuid DEFAULT auth.uid(),
    archived_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_message_at timestamp with time zone
);


--
-- Name: company_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.company_settings (
    id boolean DEFAULT true NOT NULL,
    company_name text DEFAULT 'VERIION'::text NOT NULL,
    email_domain text DEFAULT 'veriion.com'::text NOT NULL,
    currency text DEFAULT 'XOF'::text NOT NULL,
    timezone text DEFAULT 'Africa/Porto-Novo'::text NOT NULL,
    opening_cash numeric(16,2) DEFAULT 0 NOT NULL,
    default_tax_rate numeric(5,2) DEFAULT 18 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT company_settings_id_check CHECK (id)
);


--
-- Name: contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contacts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid,
    first_name text NOT NULL,
    last_name text,
    job_title text,
    email text,
    phone text,
    is_primary boolean DEFAULT false NOT NULL,
    notes text,
    owner_id uuid DEFAULT auth.uid(),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_recents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_recents (
    profile_id uuid DEFAULT auth.uid() NOT NULL,
    document_id uuid NOT NULL,
    opened_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_id uuid NOT NULL,
    revision integer NOT NULL,
    title text NOT NULL,
    content jsonb,
    storage_path text,
    file_name text,
    mime_type text,
    size_bytes bigint,
    note text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_ydocs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_ydocs (
    document_id uuid NOT NULL,
    state text NOT NULL,
    revision integer NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.documents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text DEFAULT 'Sans titre'::text NOT NULL,
    description text,
    category public.doc_category DEFAULT 'other'::public.doc_category NOT NULL,
    classification public.doc_classification DEFAULT 'internal'::public.doc_classification NOT NULL,
    unit_id uuid,
    project_id uuid,
    account_id uuid,
    owner_id uuid DEFAULT auth.uid(),
    storage_path text,
    file_name text,
    mime_type text,
    size_bytes bigint,
    version integer DEFAULT 1 NOT NULL,
    tags text[] DEFAULT '{}'::text[] NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    folder_id uuid,
    kind public.doc_kind DEFAULT 'file'::public.doc_kind NOT NULL,
    content jsonb,
    content_text text,
    revision integer DEFAULT 1 NOT NULL,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid,
    search tsvector GENERATED ALWAYS AS ((((setweight(to_tsvector('french'::regconfig, COALESCE(title, ''::text)), 'A'::"char") || setweight(to_tsvector('french'::regconfig, COALESCE(description, ''::text)), 'B'::"char")) || setweight(to_tsvector('simple'::regconfig, COALESCE(file_name, ''::text)), 'C'::"char")) || setweight(to_tsvector('french'::regconfig, "left"(COALESCE(content_text, ''::text), 100000)), 'D'::"char"))) STORED
);


--
-- Name: drive_favorites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.drive_favorites (
    profile_id uuid DEFAULT auth.uid() NOT NULL,
    folder_id uuid,
    document_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT drive_favorites_check CHECK ((num_nonnulls(folder_id, document_id) = 1))
);


--
-- Name: employment_contracts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employment_contracts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    profile_id uuid NOT NULL,
    type public.contract_type DEFAULT 'cdi'::public.contract_type NOT NULL,
    job_title text,
    start_date date NOT NULL,
    end_date date,
    weekly_hours numeric(4,1) DEFAULT 40,
    document_id uuid,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    approved_by uuid,
    approved_at timestamp with time zone,
    gross_monthly numeric(14,2),
    CONSTRAINT employment_contracts_check CHECK (((end_date IS NULL) OR (end_date >= start_date))),
    CONSTRAINT employment_contracts_gross_monthly_check CHECK (((gross_monthly IS NULL) OR (gross_monthly >= (0)::numeric))),
    CONSTRAINT employment_contracts_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'pending_ceo'::text, 'signed'::text, 'ended'::text])))
);


--
-- Name: folders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.folders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    parent_id uuid,
    space public.folder_space NOT NULL,
    name text NOT NULL,
    owner_id uuid,
    unit_id uuid,
    project_id uuid,
    color text,
    path uuid[] DEFAULT '{}'::uuid[] NOT NULL,
    depth integer DEFAULT 0 NOT NULL,
    is_root boolean DEFAULT false NOT NULL,
    created_by uuid DEFAULT auth.uid(),
    deleted_at timestamp with time zone,
    deleted_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT folders_name_check CHECK (((length(TRIM(BOTH FROM name)) >= 1) AND (length(TRIM(BOTH FROM name)) <= 120)))
);


--
-- Name: governance_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.governance_settings (
    id boolean DEFAULT true NOT NULL,
    ceo_approval_threshold numeric(16,2) DEFAULT 500000 NOT NULL,
    approval_reminder_days integer DEFAULT 2 NOT NULL,
    max_grant_days integer DEFAULT 90 NOT NULL,
    mfa_enforced boolean DEFAULT true NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    CONSTRAINT governance_settings_approval_reminder_days_check CHECK (((approval_reminder_days >= 1) AND (approval_reminder_days <= 30))),
    CONSTRAINT governance_settings_ceo_approval_threshold_check CHECK ((ceo_approval_threshold >= (0)::numeric)),
    CONSTRAINT governance_settings_id_check CHECK (id),
    CONSTRAINT governance_settings_max_grant_days_check CHECK (((max_grant_days >= 1) AND (max_grant_days <= 366)))
);


--
-- Name: incidents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.incidents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    description text,
    severity public.incident_severity DEFAULT 'medium'::public.incident_severity NOT NULL,
    status public.incident_status DEFAULT 'open'::public.incident_status NOT NULL,
    unit_id uuid,
    product text,
    reported_by uuid DEFAULT auth.uid(),
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: interactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    contact_id uuid,
    opportunity_id uuid,
    kind public.interaction_kind DEFAULT 'note'::public.interaction_kind NOT NULL,
    subject text NOT NULL,
    body text,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    author_id uuid DEFAULT auth.uid(),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: invoice_counters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoice_counters (
    scope text NOT NULL,
    year integer NOT NULL,
    last integer DEFAULT 0 NOT NULL
);


--
-- Name: invoice_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoice_lines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    invoice_id uuid NOT NULL,
    description text NOT NULL,
    quantity numeric(12,2) DEFAULT 1 NOT NULL,
    unit_price numeric(16,2) DEFAULT 0 NOT NULL,
    amount numeric(16,2) GENERATED ALWAYS AS (round((quantity * unit_price), 2)) STORED,
    "position" integer DEFAULT 0 NOT NULL,
    CONSTRAINT invoice_lines_quantity_check CHECK ((quantity > (0)::numeric)),
    CONSTRAINT invoice_lines_unit_price_check CHECK ((unit_price >= (0)::numeric))
);


--
-- Name: invoice_number_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invoice_number_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invoices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    number text NOT NULL,
    account_id uuid,
    opportunity_id uuid,
    unit_id uuid,
    status public.invoice_status DEFAULT 'draft'::public.invoice_status NOT NULL,
    issue_date date DEFAULT CURRENT_DATE NOT NULL,
    due_date date DEFAULT (CURRENT_DATE + 30) NOT NULL,
    currency text DEFAULT 'XOF'::text NOT NULL,
    subtotal numeric(16,2) DEFAULT 0 NOT NULL,
    tax_rate numeric(5,2) DEFAULT 18 NOT NULL,
    tax_amount numeric(16,2) DEFAULT 0 NOT NULL,
    total numeric(16,2) DEFAULT 0 NOT NULL,
    product text,
    country text,
    notes text,
    paid_at timestamp with time zone,
    created_by uuid DEFAULT auth.uid(),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    sent_at timestamp with time zone
);


--
-- Name: key_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.key_results (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    objective_id uuid NOT NULL,
    title text NOT NULL,
    metric_unit text,
    start_value numeric(16,2) DEFAULT 0 NOT NULL,
    target_value numeric(16,2) NOT NULL,
    current_value numeric(16,2) DEFAULT 0 NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT key_results_check CHECK ((target_value <> start_value))
);


--
-- Name: kpi_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.kpi_definitions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key text NOT NULL,
    name text NOT NULL,
    description text,
    formula text,
    source text,
    unit text,
    owner_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: leave_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leave_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    profile_id uuid DEFAULT auth.uid() NOT NULL,
    type public.leave_type DEFAULT 'annual'::public.leave_type NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    days numeric(5,1) GENERATED ALWAYS AS ((((end_date - start_date) + 1))::numeric) STORED,
    reason text,
    status public.request_status DEFAULT 'pending'::public.request_status NOT NULL,
    approver_id uuid,
    decided_at timestamp with time zone,
    decision_note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT leave_requests_check CHECK ((end_date >= start_date))
);


--
-- Name: legal_contract_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.legal_contract_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legal_contracts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legal_contracts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reference text DEFAULT ((('JUR-'::text || to_char(now(), 'YYYY'::text)) || '-'::text) || lpad((nextval('public.legal_contract_seq'::regclass))::text, 4, '0'::text)) NOT NULL,
    title text NOT NULL,
    type public.legal_contract_type DEFAULT 'other'::public.legal_contract_type NOT NULL,
    status public.legal_contract_status DEFAULT 'draft'::public.legal_contract_status NOT NULL,
    counterparty text NOT NULL,
    account_id uuid,
    project_id uuid,
    unit_id uuid,
    owner_id uuid DEFAULT auth.uid(),
    document_id uuid,
    amount numeric(16,2),
    currency text DEFAULT 'XOF'::text NOT NULL,
    risk text DEFAULT 'low'::text NOT NULL,
    signed_on date,
    effective_date date,
    end_date date,
    renewal_notice_days integer DEFAULT 30 NOT NULL,
    auto_renew boolean DEFAULT false NOT NULL,
    obligations text,
    notes text,
    created_by uuid DEFAULT auth.uid(),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT legal_contracts_check CHECK (((end_date IS NULL) OR (effective_date IS NULL) OR (end_date >= effective_date))),
    CONSTRAINT legal_contracts_counterparty_check CHECK ((length(TRIM(BOTH FROM counterparty)) > 1)),
    CONSTRAINT legal_contracts_renewal_notice_days_check CHECK (((renewal_notice_days >= 0) AND (renewal_notice_days <= 365))),
    CONSTRAINT legal_contracts_risk_check CHECK ((risk = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text]))),
    CONSTRAINT legal_contracts_title_check CHECK ((length(TRIM(BOTH FROM title)) > 2))
);


--
-- Name: lifecycle_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lifecycle_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    profile_id uuid NOT NULL,
    kind text NOT NULL,
    title text NOT NULL,
    assignee_id uuid,
    due_date date,
    done_at timestamp with time zone,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT lifecycle_items_kind_check CHECK ((kind = ANY (ARRAY['onboarding'::text, 'offboarding'::text])))
);


--
-- Name: meeting_attendees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meeting_attendees (
    meeting_id uuid NOT NULL,
    profile_id uuid NOT NULL,
    response text DEFAULT 'pending'::text NOT NULL,
    CONSTRAINT meeting_attendees_response_check CHECK ((response = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text])))
);


--
-- Name: meetings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meetings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    description text,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    location text,
    video_url text,
    unit_id uuid,
    project_id uuid,
    organizer_id uuid DEFAULT auth.uid(),
    minutes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    reminded_at timestamp with time zone,
    CONSTRAINT meetings_check CHECK ((ends_at > starts_at))
);


--
-- Name: message_reactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.message_reactions (
    message_id uuid NOT NULL,
    channel_id uuid NOT NULL,
    profile_id uuid DEFAULT auth.uid() NOT NULL,
    emoji text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT message_reactions_emoji_check CHECK (((length(emoji) >= 1) AND (length(emoji) <= 16)))
);


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    channel_id uuid NOT NULL,
    author_id uuid DEFAULT auth.uid(),
    parent_id uuid,
    body text DEFAULT ''::text NOT NULL,
    attachments jsonb DEFAULT '[]'::jsonb NOT NULL,
    edited_at timestamp with time zone,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    kind text DEFAULT 'text'::text NOT NULL,
    mentions uuid[] DEFAULT '{}'::uuid[] NOT NULL,
    reply_count integer DEFAULT 0 NOT NULL,
    last_reply_at timestamp with time zone,
    pinned_at timestamp with time zone,
    pinned_by uuid,
    CONSTRAINT messages_body_check CHECK (((length(body) <= 8000) AND ((length(body) >= 1) OR (jsonb_array_length(attachments) > 0)))),
    CONSTRAINT messages_kind_check CHECK ((kind = ANY (ARRAY['text'::text, 'call'::text, 'system'::text])))
);


--
-- Name: notification_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_preferences (
    profile_id uuid DEFAULT auth.uid() NOT NULL,
    email_mode text DEFAULT 'instant'::text NOT NULL,
    email_off text[] DEFAULT '{}'::text[] NOT NULL,
    push_off text[] DEFAULT '{}'::text[] NOT NULL,
    quiet_start time without time zone,
    quiet_end time without time zone,
    digest_hour integer DEFAULT 7 NOT NULL,
    last_digest_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT notification_preferences_digest_hour_check CHECK (((digest_hour >= 0) AND (digest_hour <= 23))),
    CONSTRAINT notification_preferences_email_mode_check CHECK ((email_mode = ANY (ARRAY['instant'::text, 'digest'::text, 'off'::text])))
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    profile_id uuid NOT NULL,
    kind text NOT NULL,
    title text NOT NULL,
    body text,
    link text,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    emailed_at timestamp with time zone,
    pushed_at timestamp with time zone
);


--
-- Name: objectives; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.objectives (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    parent_id uuid,
    level public.objective_level DEFAULT 'unit'::public.objective_level NOT NULL,
    unit_id uuid,
    owner_id uuid DEFAULT auth.uid(),
    title text NOT NULL,
    description text,
    period text DEFAULT ((to_char(now(), 'YYYY'::text) || '-T'::text) || to_char(now(), 'Q'::text)) NOT NULL,
    status public.objective_status DEFAULT 'on_track'::public.objective_status NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT objectives_check CHECK (((level <> 'unit'::public.objective_level) OR (unit_id IS NOT NULL)))
);


--
-- Name: objectives_progress; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.objectives_progress AS
SELECT
    NULL::uuid AS id,
    NULL::uuid AS parent_id,
    NULL::public.objective_level AS level,
    NULL::uuid AS unit_id,
    NULL::uuid AS owner_id,
    NULL::text AS title,
    NULL::text AS description,
    NULL::text AS period,
    NULL::public.objective_status AS status,
    NULL::timestamp with time zone AS created_at,
    NULL::timestamp with time zone AS updated_at,
    NULL::integer AS progress,
    NULL::integer AS key_result_count;


--
-- Name: operation_cycles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operation_cycles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    parent_cycle_id uuid,
    kind public.cycle_kind NOT NULL,
    status public.cycle_status DEFAULT 'draft'::public.cycle_status NOT NULL,
    period_start date NOT NULL,
    period_end date NOT NULL,
    title text NOT NULL,
    focus text,
    created_by uuid DEFAULT auth.uid(),
    published_at timestamp with time zone,
    closed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT operation_cycles_check CHECK ((period_end >= period_start)),
    CONSTRAINT operation_cycles_title_check CHECK ((length(TRIM(BOTH FROM title)) > 2))
);


--
-- Name: operation_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operation_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    cycle_id uuid NOT NULL,
    title text NOT NULL,
    detail text,
    expected_outcome text,
    owner_id uuid,
    due_date date,
    status public.ops_item_status DEFAULT 'planned'::public.ops_item_status NOT NULL,
    "position" double precision DEFAULT EXTRACT(epoch FROM now()) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT operation_items_title_check CHECK ((length(TRIM(BOTH FROM title)) > 2))
);


--
-- Name: operation_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operation_reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    cycle_id uuid NOT NULL,
    project_id uuid NOT NULL,
    author_id uuid DEFAULT auth.uid(),
    progress integer DEFAULT 0 NOT NULL,
    summary text NOT NULL,
    blockers text,
    next_steps text,
    status text DEFAULT 'submitted'::text NOT NULL,
    submitted_at timestamp with time zone,
    reviewed_by uuid,
    reviewed_at timestamp with time zone,
    review_note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT operation_reports_progress_check CHECK (((progress >= 0) AND (progress <= 100))),
    CONSTRAINT operation_reports_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'submitted'::text, 'acknowledged'::text]))),
    CONSTRAINT operation_reports_summary_check CHECK ((length(TRIM(BOTH FROM summary)) > 10))
);


--
-- Name: opportunities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.opportunities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    name text NOT NULL,
    stage public.opportunity_stage DEFAULT 'lead'::public.opportunity_stage NOT NULL,
    amount numeric(16,2) DEFAULT 0 NOT NULL,
    currency text DEFAULT 'XOF'::text NOT NULL,
    probability integer DEFAULT 10 NOT NULL,
    expected_close date,
    product text,
    owner_id uuid DEFAULT auth.uid(),
    lost_reason text,
    closed_at timestamp with time zone,
    project_id uuid,
    "position" double precision DEFAULT EXTRACT(epoch FROM now()) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT opportunities_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT opportunities_probability_check CHECK (((probability >= 0) AND (probability <= 100)))
);


--
-- Name: org_units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_units (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    parent_id uuid,
    name text NOT NULL,
    code text,
    kind public.unit_kind DEFAULT 'department'::public.unit_kind NOT NULL,
    domain text,
    description text,
    color text DEFAULT '#4F46E5'::text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    path uuid[] DEFAULT '{}'::uuid[] NOT NULL,
    depth integer DEFAULT 0 NOT NULL,
    archived_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    head_title text,
    deputy_title text,
    member_title text,
    is_core boolean DEFAULT false NOT NULL,
    merged_into uuid,
    CONSTRAINT org_units_name_check CHECK ((length(TRIM(BOTH FROM name)) > 1))
);


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permissions (
    key text NOT NULL,
    label text NOT NULL,
    description text,
    category text NOT NULL,
    scopable boolean DEFAULT false NOT NULL,
    reserved boolean DEFAULT false NOT NULL
);


--
-- Name: product_metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_metrics (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    metric_date date NOT NULL,
    product text DEFAULT 'VERIION'::text NOT NULL,
    country text DEFAULT 'ALL'::text NOT NULL,
    active_users integer DEFAULT 0 NOT NULL,
    new_users integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: project_code_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_code_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_liaisons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_liaisons (
    project_id uuid NOT NULL,
    unit_id uuid NOT NULL,
    profile_id uuid NOT NULL,
    note text,
    created_by uuid DEFAULT auth.uid(),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: project_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_members (
    project_id uuid NOT NULL,
    profile_id uuid NOT NULL,
    role text DEFAULT 'member'::text NOT NULL,
    added_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT project_members_role_check CHECK ((role = ANY (ARRAY['lead'::text, 'member'::text, 'viewer'::text])))
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text DEFAULT ('PRJ-'::text || lpad((nextval('public.project_code_seq'::regclass))::text, 4, '0'::text)) NOT NULL,
    name text NOT NULL,
    description text,
    unit_id uuid,
    owner_id uuid DEFAULT auth.uid(),
    status public.project_status DEFAULT 'planned'::public.project_status NOT NULL,
    priority public.priority DEFAULT 'medium'::public.priority NOT NULL,
    start_date date,
    due_date date,
    budget numeric(16,2),
    color text DEFAULT '#4F46E5'::text NOT NULL,
    archived_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    lead_id uuid,
    mission text,
    approved_by uuid,
    approved_at timestamp with time zone,
    CONSTRAINT projects_check CHECK (((due_date IS NULL) OR (start_date IS NULL) OR (due_date >= start_date)))
);


--
-- Name: push_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.push_subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    profile_id uuid DEFAULT auth.uid() NOT NULL,
    endpoint text NOT NULL,
    p256dh text NOT NULL,
    auth text NOT NULL,
    device text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_used_at timestamp with time zone
);


--
-- Name: role_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_grants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    profile_id uuid NOT NULL,
    permission text NOT NULL,
    scope_unit_id uuid,
    source public.grant_source DEFAULT 'manual'::public.grant_source NOT NULL,
    membership_id uuid,
    reason text,
    expires_at timestamp with time zone,
    granted_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT role_grants_check CHECK (((source = 'auto'::public.grant_source) OR ((reason IS NOT NULL) AND (length(TRIM(BOTH FROM reason)) > 3))))
);


--
-- Name: role_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    domain text,
    membership_role public.membership_role NOT NULL,
    permission text NOT NULL,
    scoped boolean DEFAULT false NOT NULL
);


--
-- Name: salaries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.salaries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    profile_id uuid NOT NULL,
    gross_monthly numeric(14,2) NOT NULL,
    currency text DEFAULT 'XOF'::text NOT NULL,
    effective_from date DEFAULT CURRENT_DATE NOT NULL,
    notes text,
    created_by uuid DEFAULT auth.uid(),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT salaries_gross_monthly_check CHECK ((gross_monthly >= (0)::numeric))
);


--
-- Name: shares; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shares (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    folder_id uuid,
    document_id uuid,
    profile_id uuid,
    unit_id uuid,
    role public.share_role DEFAULT 'viewer'::public.share_role NOT NULL,
    expires_at timestamp with time zone,
    created_by uuid DEFAULT auth.uid(),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT shares_check CHECK ((num_nonnulls(folder_id, document_id) = 1)),
    CONSTRAINT shares_check1 CHECK ((num_nonnulls(profile_id, unit_id) = 1))
);


--
-- Name: task_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_comments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    task_id uuid NOT NULL,
    author_id uuid DEFAULT auth.uid(),
    body text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: task_dependencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_dependencies (
    task_id uuid NOT NULL,
    depends_on_id uuid NOT NULL,
    CONSTRAINT task_dependencies_check CHECK ((task_id <> depends_on_id))
);


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid,
    parent_id uuid,
    title text NOT NULL,
    description text,
    status public.task_status DEFAULT 'todo'::public.task_status NOT NULL,
    priority public.priority DEFAULT 'medium'::public.priority NOT NULL,
    assignee_id uuid,
    reporter_id uuid DEFAULT auth.uid(),
    start_date date,
    due_date date,
    estimate_hours numeric(6,2),
    "position" double precision DEFAULT EXTRACT(epoch FROM now()) NOT NULL,
    requires_validation boolean DEFAULT false NOT NULL,
    validated_by uuid,
    validated_at timestamp with time zone,
    completed_at timestamp with time zone,
    objective_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    operation_item_id uuid,
    submitted_at timestamp with time zone,
    reviewer_id uuid,
    review_note text,
    CONSTRAINT tasks_title_check CHECK ((length(TRIM(BOTH FROM title)) > 0))
);


--
-- Name: transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    type public.txn_type NOT NULL,
    amount numeric(16,2) NOT NULL,
    currency text DEFAULT 'XOF'::text NOT NULL,
    occurred_on date DEFAULT CURRENT_DATE NOT NULL,
    category text DEFAULT 'Autre'::text NOT NULL,
    description text,
    unit_id uuid,
    project_id uuid,
    account_id uuid,
    invoice_id uuid,
    product text,
    country text,
    reference text,
    created_by uuid DEFAULT auth.uid(),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    approval_id uuid,
    reverses_id uuid,
    reversed_by uuid,
    reversal_reason text,
    CONSTRAINT transactions_amount_sign CHECK ((((reverses_id IS NULL) AND (amount > (0)::numeric)) OR ((reverses_id IS NOT NULL) AND (amount < (0)::numeric))))
);


--
-- Name: unit_domains; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.unit_domains (
    key text NOT NULL,
    label text NOT NULL,
    description text,
    sort_order integer DEFAULT 0 NOT NULL
);


--
-- Name: unit_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.unit_memberships (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    unit_id uuid NOT NULL,
    profile_id uuid NOT NULL,
    role public.membership_role DEFAULT 'member'::public.membership_role NOT NULL,
    title text,
    start_date date DEFAULT CURRENT_DATE NOT NULL,
    end_date date,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT unit_memberships_check CHECK (((end_date IS NULL) OR (end_date >= start_date)))
);


--
-- Name: access_codes access_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_codes
    ADD CONSTRAINT access_codes_pkey PRIMARY KEY (profile_id);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: announcements announcements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_pkey PRIMARY KEY (id);


--
-- Name: approval_requests approval_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_requests
    ADD CONSTRAINT approval_requests_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: budgets budgets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budgets
    ADD CONSTRAINT budgets_pkey PRIMARY KEY (id);


--
-- Name: budgets budgets_unit_id_fiscal_year_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budgets
    ADD CONSTRAINT budgets_unit_id_fiscal_year_key UNIQUE (unit_id, fiscal_year);


--
-- Name: channel_members channel_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel_members
    ADD CONSTRAINT channel_members_pkey PRIMARY KEY (channel_id, profile_id);


--
-- Name: channels channels_dm_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT channels_dm_key_key UNIQUE (dm_key);


--
-- Name: channels channels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT channels_pkey PRIMARY KEY (id);


--
-- Name: company_settings company_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_settings
    ADD CONSTRAINT company_settings_pkey PRIMARY KEY (id);


--
-- Name: contacts contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_pkey PRIMARY KEY (id);


--
-- Name: document_recents document_recents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_recents
    ADD CONSTRAINT document_recents_pkey PRIMARY KEY (profile_id, document_id);


--
-- Name: document_versions document_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_versions
    ADD CONSTRAINT document_versions_pkey PRIMARY KEY (id);


--
-- Name: document_ydocs document_ydocs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_ydocs
    ADD CONSTRAINT document_ydocs_pkey PRIMARY KEY (document_id);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: documents documents_storage_path_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_storage_path_key UNIQUE (storage_path);


--
-- Name: employment_contracts employment_contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employment_contracts
    ADD CONSTRAINT employment_contracts_pkey PRIMARY KEY (id);


--
-- Name: folders folders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folders
    ADD CONSTRAINT folders_pkey PRIMARY KEY (id);


--
-- Name: governance_settings governance_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.governance_settings
    ADD CONSTRAINT governance_settings_pkey PRIMARY KEY (id);


--
-- Name: incidents incidents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_pkey PRIMARY KEY (id);


--
-- Name: interactions interactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interactions
    ADD CONSTRAINT interactions_pkey PRIMARY KEY (id);


--
-- Name: invoice_counters invoice_counters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_counters
    ADD CONSTRAINT invoice_counters_pkey PRIMARY KEY (scope, year);


--
-- Name: invoice_lines invoice_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_lines
    ADD CONSTRAINT invoice_lines_pkey PRIMARY KEY (id);


--
-- Name: invoices invoices_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_number_key UNIQUE (number);


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


--
-- Name: key_results key_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.key_results
    ADD CONSTRAINT key_results_pkey PRIMARY KEY (id);


--
-- Name: kpi_definitions kpi_definitions_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kpi_definitions
    ADD CONSTRAINT kpi_definitions_key_key UNIQUE (key);


--
-- Name: kpi_definitions kpi_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kpi_definitions
    ADD CONSTRAINT kpi_definitions_pkey PRIMARY KEY (id);


--
-- Name: leave_requests leave_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leave_requests
    ADD CONSTRAINT leave_requests_pkey PRIMARY KEY (id);


--
-- Name: legal_contracts legal_contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_contracts
    ADD CONSTRAINT legal_contracts_pkey PRIMARY KEY (id);


--
-- Name: legal_contracts legal_contracts_reference_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_contracts
    ADD CONSTRAINT legal_contracts_reference_key UNIQUE (reference);


--
-- Name: lifecycle_items lifecycle_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_items
    ADD CONSTRAINT lifecycle_items_pkey PRIMARY KEY (id);


--
-- Name: meeting_attendees meeting_attendees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_attendees
    ADD CONSTRAINT meeting_attendees_pkey PRIMARY KEY (meeting_id, profile_id);


--
-- Name: meetings meetings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_pkey PRIMARY KEY (id);


--
-- Name: message_reactions message_reactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reactions
    ADD CONSTRAINT message_reactions_pkey PRIMARY KEY (message_id, profile_id, emoji);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: notification_preferences notification_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences
    ADD CONSTRAINT notification_preferences_pkey PRIMARY KEY (profile_id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: objectives objectives_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.objectives
    ADD CONSTRAINT objectives_pkey PRIMARY KEY (id);


--
-- Name: operation_cycles operation_cycles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operation_cycles
    ADD CONSTRAINT operation_cycles_pkey PRIMARY KEY (id);


--
-- Name: operation_cycles operation_cycles_project_id_kind_period_start_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operation_cycles
    ADD CONSTRAINT operation_cycles_project_id_kind_period_start_key UNIQUE (project_id, kind, period_start);


--
-- Name: operation_items operation_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operation_items
    ADD CONSTRAINT operation_items_pkey PRIMARY KEY (id);


--
-- Name: operation_reports operation_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operation_reports
    ADD CONSTRAINT operation_reports_pkey PRIMARY KEY (id);


--
-- Name: opportunities opportunities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.opportunities
    ADD CONSTRAINT opportunities_pkey PRIMARY KEY (id);


--
-- Name: org_units org_units_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_units
    ADD CONSTRAINT org_units_code_key UNIQUE (code);


--
-- Name: org_units org_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_units
    ADD CONSTRAINT org_units_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (key);


--
-- Name: product_metrics product_metrics_metric_date_product_country_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_metrics
    ADD CONSTRAINT product_metrics_metric_date_product_country_key UNIQUE (metric_date, product, country);


--
-- Name: product_metrics product_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_metrics
    ADD CONSTRAINT product_metrics_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_email_key UNIQUE (email);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: project_liaisons project_liaisons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_liaisons
    ADD CONSTRAINT project_liaisons_pkey PRIMARY KEY (project_id, unit_id);


--
-- Name: project_members project_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_members
    ADD CONSTRAINT project_members_pkey PRIMARY KEY (project_id, profile_id);


--
-- Name: projects projects_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_code_key UNIQUE (code);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: push_subscriptions push_subscriptions_endpoint_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_endpoint_key UNIQUE (endpoint);


--
-- Name: push_subscriptions push_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: role_grants role_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_grants
    ADD CONSTRAINT role_grants_pkey PRIMARY KEY (id);


--
-- Name: role_templates role_templates_domain_membership_role_permission_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_templates
    ADD CONSTRAINT role_templates_domain_membership_role_permission_key UNIQUE NULLS NOT DISTINCT (domain, membership_role, permission);


--
-- Name: role_templates role_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_templates
    ADD CONSTRAINT role_templates_pkey PRIMARY KEY (id);


--
-- Name: salaries salaries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.salaries
    ADD CONSTRAINT salaries_pkey PRIMARY KEY (id);


--
-- Name: shares shares_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shares
    ADD CONSTRAINT shares_pkey PRIMARY KEY (id);


--
-- Name: task_comments task_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_comments
    ADD CONSTRAINT task_comments_pkey PRIMARY KEY (id);


--
-- Name: task_dependencies task_dependencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_dependencies
    ADD CONSTRAINT task_dependencies_pkey PRIMARY KEY (task_id, depends_on_id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- Name: unit_domains unit_domains_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_domains
    ADD CONSTRAINT unit_domains_pkey PRIMARY KEY (key);


--
-- Name: unit_memberships unit_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_memberships
    ADD CONSTRAINT unit_memberships_pkey PRIMARY KEY (id);


--
-- Name: accounts_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX accounts_type_idx ON public.accounts USING btree (type);


--
-- Name: announcements_published_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX announcements_published_idx ON public.announcements USING btree (published_at DESC);


--
-- Name: approval_requests_author_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX approval_requests_author_idx ON public.approval_requests USING btree (requested_by, created_at DESC);


--
-- Name: approval_requests_pending_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX approval_requests_pending_subject ON public.approval_requests USING btree (kind, subject_id) WHERE ((status = 'pending'::public.approval_status) AND (subject_id IS NOT NULL));


--
-- Name: approval_requests_queue_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX approval_requests_queue_idx ON public.approval_requests USING btree (status, created_at DESC);


--
-- Name: audit_log_actor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_actor_idx ON public.audit_log USING btree (actor_id);


--
-- Name: audit_log_occurred_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_occurred_idx ON public.audit_log USING btree (occurred_at DESC);


--
-- Name: audit_log_table_record_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_table_record_idx ON public.audit_log USING btree (table_name, record_id);


--
-- Name: budgets_project_year; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX budgets_project_year ON public.budgets USING btree (project_id, fiscal_year) WHERE (project_id IS NOT NULL);


--
-- Name: channel_members_profile_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX channel_members_profile_idx ON public.channel_members USING btree (profile_id);


--
-- Name: contacts_account_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contacts_account_idx ON public.contacts USING btree (account_id);


--
-- Name: document_versions_doc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX document_versions_doc_idx ON public.document_versions USING btree (document_id, created_at DESC);


--
-- Name: documents_folder_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX documents_folder_idx ON public.documents USING btree (folder_id) WHERE (deleted_at IS NULL);


--
-- Name: documents_search_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX documents_search_idx ON public.documents USING gin (search);


--
-- Name: documents_unit_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX documents_unit_idx ON public.documents USING btree (unit_id);


--
-- Name: drive_favorites_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX drive_favorites_unique ON public.drive_favorites USING btree (profile_id, COALESCE(folder_id, document_id));


--
-- Name: employment_contracts_profile_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX employment_contracts_profile_idx ON public.employment_contracts USING btree (profile_id);


--
-- Name: folders_company_root; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX folders_company_root ON public.folders USING btree (space) WHERE (is_root AND (space = 'company'::public.folder_space));


--
-- Name: folders_parent_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX folders_parent_idx ON public.folders USING btree (parent_id) WHERE (deleted_at IS NULL);


--
-- Name: folders_path_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX folders_path_idx ON public.folders USING gin (path);


--
-- Name: folders_personal_root; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX folders_personal_root ON public.folders USING btree (owner_id) WHERE (is_root AND (space = 'personal'::public.folder_space));


--
-- Name: folders_project_root; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX folders_project_root ON public.folders USING btree (project_id) WHERE (is_root AND (space = 'project'::public.folder_space));


--
-- Name: folders_unique_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX folders_unique_name ON public.folders USING btree (parent_id, lower(name)) WHERE ((deleted_at IS NULL) AND (parent_id IS NOT NULL));


--
-- Name: folders_unit_root; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX folders_unit_root ON public.folders USING btree (unit_id) WHERE (is_root AND (space = 'unit'::public.folder_space));


--
-- Name: interactions_account_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX interactions_account_idx ON public.interactions USING btree (account_id, occurred_at DESC);


--
-- Name: invoice_lines_invoice_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX invoice_lines_invoice_idx ON public.invoice_lines USING btree (invoice_id);


--
-- Name: invoices_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX invoices_status_idx ON public.invoices USING btree (status, due_date);


--
-- Name: key_results_objective_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX key_results_objective_idx ON public.key_results USING btree (objective_id);


--
-- Name: leave_requests_pending_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX leave_requests_pending_idx ON public.leave_requests USING btree (status) WHERE (status = 'pending'::public.request_status);


--
-- Name: leave_requests_profile_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX leave_requests_profile_idx ON public.leave_requests USING btree (profile_id, start_date DESC);


--
-- Name: legal_contracts_end_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX legal_contracts_end_idx ON public.legal_contracts USING btree (end_date) WHERE (status = ANY (ARRAY['signed'::public.legal_contract_status, 'active'::public.legal_contract_status]));


--
-- Name: legal_contracts_project_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX legal_contracts_project_idx ON public.legal_contracts USING btree (project_id);


--
-- Name: legal_contracts_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX legal_contracts_status_idx ON public.legal_contracts USING btree (status, end_date);


--
-- Name: lifecycle_items_profile_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lifecycle_items_profile_idx ON public.lifecycle_items USING btree (profile_id, kind);


--
-- Name: meeting_attendees_profile_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX meeting_attendees_profile_idx ON public.meeting_attendees USING btree (profile_id);


--
-- Name: meetings_starts_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX meetings_starts_idx ON public.meetings USING btree (starts_at);


--
-- Name: message_reactions_channel_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX message_reactions_channel_idx ON public.message_reactions USING btree (channel_id);


--
-- Name: messages_body_fts; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_body_fts ON public.messages USING gin (to_tsvector('simple'::regconfig, body));


--
-- Name: messages_channel_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_channel_idx ON public.messages USING btree (channel_id, created_at DESC);


--
-- Name: messages_parent_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_parent_idx ON public.messages USING btree (parent_id, created_at) WHERE (parent_id IS NOT NULL);


--
-- Name: messages_pinned_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_pinned_idx ON public.messages USING btree (channel_id) WHERE (pinned_at IS NOT NULL);


--
-- Name: notifications_email_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notifications_email_queue ON public.notifications USING btree (created_at) WHERE ((emailed_at IS NULL) AND (read_at IS NULL));


--
-- Name: notifications_profile_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notifications_profile_idx ON public.notifications USING btree (profile_id, created_at DESC);


--
-- Name: notifications_push_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notifications_push_queue ON public.notifications USING btree (created_at) WHERE (pushed_at IS NULL);


--
-- Name: objectives_period_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX objectives_period_idx ON public.objectives USING btree (period, level);


--
-- Name: operation_cycles_open_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX operation_cycles_open_idx ON public.operation_cycles USING btree (status, period_end) WHERE (status = 'published'::public.cycle_status);


--
-- Name: operation_cycles_project_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX operation_cycles_project_idx ON public.operation_cycles USING btree (project_id, period_start DESC);


--
-- Name: operation_items_cycle_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX operation_items_cycle_idx ON public.operation_items USING btree (cycle_id, "position");


--
-- Name: operation_reports_cycle_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX operation_reports_cycle_idx ON public.operation_reports USING btree (cycle_id, created_at DESC);


--
-- Name: operation_reports_queue_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX operation_reports_queue_idx ON public.operation_reports USING btree (status) WHERE (status = 'submitted'::text);


--
-- Name: opportunities_stage_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX opportunities_stage_idx ON public.opportunities USING btree (stage);


--
-- Name: org_units_parent_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX org_units_parent_idx ON public.org_units USING btree (parent_id);


--
-- Name: org_units_path_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX org_units_path_idx ON public.org_units USING gin (path);


--
-- Name: profiles_manager_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX profiles_manager_idx ON public.profiles USING btree (manager_id);


--
-- Name: profiles_unit_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX profiles_unit_idx ON public.profiles USING btree (primary_unit_id);


--
-- Name: project_liaisons_profile_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX project_liaisons_profile_idx ON public.project_liaisons USING btree (profile_id);


--
-- Name: project_liaisons_unit_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX project_liaisons_unit_idx ON public.project_liaisons USING btree (unit_id);


--
-- Name: project_members_profile_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX project_members_profile_idx ON public.project_members USING btree (profile_id);


--
-- Name: projects_lead_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX projects_lead_idx ON public.projects USING btree (lead_id);


--
-- Name: projects_unit_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX projects_unit_idx ON public.projects USING btree (unit_id);


--
-- Name: push_subscriptions_profile_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX push_subscriptions_profile_idx ON public.push_subscriptions USING btree (profile_id);


--
-- Name: role_grants_profile_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX role_grants_profile_idx ON public.role_grants USING btree (profile_id, permission);


--
-- Name: salaries_profile_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX salaries_profile_idx ON public.salaries USING btree (profile_id, effective_from DESC);


--
-- Name: shares_doc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX shares_doc_idx ON public.shares USING btree (document_id);


--
-- Name: shares_folder_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX shares_folder_idx ON public.shares USING btree (folder_id);


--
-- Name: shares_profile_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX shares_profile_idx ON public.shares USING btree (profile_id);


--
-- Name: shares_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX shares_unique ON public.shares USING btree (COALESCE(folder_id, document_id), COALESCE(profile_id, unit_id));


--
-- Name: task_comments_task_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_comments_task_idx ON public.task_comments USING btree (task_id, created_at);


--
-- Name: tasks_assignee_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_assignee_idx ON public.tasks USING btree (assignee_id) WHERE (status <> 'done'::public.task_status);


--
-- Name: tasks_due_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_due_idx ON public.tasks USING btree (due_date) WHERE (status <> 'done'::public.task_status);


--
-- Name: tasks_operation_item_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_operation_item_idx ON public.tasks USING btree (operation_item_id);


--
-- Name: tasks_project_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_project_idx ON public.tasks USING btree (project_id, status, "position");


--
-- Name: transactions_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX transactions_date_idx ON public.transactions USING btree (occurred_on DESC);


--
-- Name: transactions_invoice_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX transactions_invoice_active ON public.transactions USING btree (invoice_id) WHERE ((invoice_id IS NOT NULL) AND (reverses_id IS NULL) AND (reversed_by IS NULL));


--
-- Name: transactions_one_reversal; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX transactions_one_reversal ON public.transactions USING btree (reverses_id) WHERE (reverses_id IS NOT NULL);


--
-- Name: transactions_unit_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX transactions_unit_idx ON public.transactions USING btree (unit_id);


--
-- Name: unit_memberships_one_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unit_memberships_one_active ON public.unit_memberships USING btree (unit_id, profile_id) WHERE (end_date IS NULL);


--
-- Name: unit_memberships_one_head; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unit_memberships_one_head ON public.unit_memberships USING btree (unit_id) WHERE ((role = 'head'::public.membership_role) AND (end_date IS NULL));


--
-- Name: unit_memberships_profile_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX unit_memberships_profile_idx ON public.unit_memberships USING btree (profile_id) WHERE (end_date IS NULL);


--
-- Name: objectives_progress _RETURN; Type: RULE; Schema: public; Owner: -
--

CREATE OR REPLACE VIEW public.objectives_progress WITH (security_invoker='true') AS
 SELECT o.id,
    o.parent_id,
    o.level,
    o.unit_id,
    o.owner_id,
    o.title,
    o.description,
    o.period,
    o.status,
    o.created_at,
    o.updated_at,
    (COALESCE(round((avg(GREATEST((0)::numeric, LEAST((1)::numeric, ((kr.current_value - kr.start_value) / (kr.target_value - kr.start_value))))) * (100)::numeric)), (0)::numeric))::integer AS progress,
    (count(kr.id))::integer AS key_result_count
   FROM (public.objectives o
     LEFT JOIN public.key_results kr ON ((kr.objective_id = o.id)))
  GROUP BY o.id;


--
-- Name: access_codes access_codes_touch; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER access_codes_touch BEFORE UPDATE ON public.access_codes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: accounts accounts_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER accounts_updated_at BEFORE UPDATE ON public.accounts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: announcements announcements_ai; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER announcements_ai AFTER INSERT ON public.announcements FOR EACH ROW EXECUTE FUNCTION public.announcements_after_insert();


--
-- Name: approval_requests approval_requests_apply_au; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER approval_requests_apply_au AFTER UPDATE ON public.approval_requests FOR EACH ROW EXECUTE FUNCTION public.approval_requests_apply();


--
-- Name: approval_requests approval_requests_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER approval_requests_updated_at BEFORE UPDATE ON public.approval_requests FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: access_codes audit_access_codes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_access_codes AFTER INSERT OR DELETE ON public.access_codes FOR EACH ROW EXECUTE FUNCTION public.audit_trigger('redact');


--
-- Name: accounts audit_accounts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_accounts AFTER INSERT OR DELETE OR UPDATE ON public.accounts FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: announcements audit_announcements; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_announcements AFTER INSERT OR DELETE OR UPDATE ON public.announcements FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: approval_requests audit_approval_requests; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_approval_requests AFTER INSERT OR DELETE OR UPDATE ON public.approval_requests FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: budgets audit_budgets; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_budgets AFTER INSERT OR DELETE OR UPDATE ON public.budgets FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: company_settings audit_company_settings; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_company_settings AFTER UPDATE ON public.company_settings FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: employment_contracts audit_contracts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_contracts AFTER INSERT OR DELETE OR UPDATE ON public.employment_contracts FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: documents audit_documents; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_documents AFTER INSERT OR DELETE OR UPDATE ON public.documents FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: folders audit_folders; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_folders AFTER INSERT OR DELETE OR UPDATE ON public.folders FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: governance_settings audit_governance_settings; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_governance_settings AFTER UPDATE ON public.governance_settings FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: incidents audit_incidents; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_incidents AFTER INSERT OR DELETE OR UPDATE ON public.incidents FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: invoices audit_invoices; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_invoices AFTER INSERT OR DELETE OR UPDATE ON public.invoices FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: leave_requests audit_leave_requests; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_leave_requests AFTER INSERT OR DELETE OR UPDATE ON public.leave_requests FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: legal_contracts audit_legal_contracts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_legal_contracts AFTER INSERT OR DELETE OR UPDATE ON public.legal_contracts FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: objectives audit_objectives; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_objectives AFTER INSERT OR DELETE OR UPDATE ON public.objectives FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: opportunities audit_opportunities; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_opportunities AFTER INSERT OR DELETE OR UPDATE ON public.opportunities FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: org_units audit_org_units; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_org_units AFTER INSERT OR DELETE OR UPDATE ON public.org_units FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: profiles audit_profiles; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_profiles AFTER INSERT OR DELETE OR UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: projects audit_projects; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_projects AFTER INSERT OR DELETE OR UPDATE ON public.projects FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: role_grants audit_role_grants; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_role_grants AFTER INSERT OR DELETE OR UPDATE ON public.role_grants FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: role_templates audit_role_templates; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_role_templates AFTER INSERT OR DELETE OR UPDATE ON public.role_templates FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: salaries audit_salaries; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_salaries AFTER INSERT OR DELETE OR UPDATE ON public.salaries FOR EACH ROW EXECUTE FUNCTION public.audit_trigger('redact');


--
-- Name: shares audit_shares; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_shares AFTER INSERT OR DELETE OR UPDATE ON public.shares FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: tasks audit_tasks; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_tasks AFTER INSERT OR DELETE OR UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: transactions audit_transactions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_transactions AFTER INSERT OR DELETE OR UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: unit_memberships audit_unit_memberships; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_unit_memberships AFTER INSERT OR DELETE OR UPDATE ON public.unit_memberships FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();


--
-- Name: budgets budgets_guard_biu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER budgets_guard_biu BEFORE INSERT OR UPDATE ON public.budgets FOR EACH ROW EXECUTE FUNCTION public.budgets_guard();


--
-- Name: budgets budgets_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER budgets_updated_at BEFORE UPDATE ON public.budgets FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: channels channels_ai; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER channels_ai AFTER INSERT ON public.channels FOR EACH ROW EXECUTE FUNCTION public.channels_after_insert();


--
-- Name: contacts contacts_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER contacts_updated_at BEFORE UPDATE ON public.contacts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: documents documents_move_guard_bu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER documents_move_guard_bu BEFORE UPDATE OF folder_id ON public.documents FOR EACH ROW EXECUTE FUNCTION public.documents_move_guard();


--
-- Name: documents documents_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER documents_updated_at BEFORE UPDATE ON public.documents FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: employment_contracts employment_contracts_aa_transition_biu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER employment_contracts_aa_transition_biu BEFORE INSERT OR UPDATE ON public.employment_contracts FOR EACH ROW EXECUTE FUNCTION public.employment_contracts_transition();


--
-- Name: employment_contracts employment_contracts_after_sign_aiu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER employment_contracts_after_sign_aiu AFTER INSERT OR UPDATE ON public.employment_contracts FOR EACH ROW EXECUTE FUNCTION public.employment_contracts_after_sign();


--
-- Name: employment_contracts employment_contracts_guard_biu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER employment_contracts_guard_biu BEFORE INSERT OR UPDATE ON public.employment_contracts FOR EACH ROW EXECUTE FUNCTION public.employment_contracts_guard();


--
-- Name: folders folders_compute_bi; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER folders_compute_bi BEFORE INSERT ON public.folders FOR EACH ROW EXECUTE FUNCTION public.folders_compute();


--
-- Name: folders folders_compute_bu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER folders_compute_bu BEFORE UPDATE OF parent_id ON public.folders FOR EACH ROW EXECUTE FUNCTION public.folders_compute();


--
-- Name: folders folders_move_guard_bu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER folders_move_guard_bu BEFORE UPDATE OF parent_id ON public.folders FOR EACH ROW EXECUTE FUNCTION public.folders_move_guard();


--
-- Name: folders folders_propagate_au; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER folders_propagate_au AFTER UPDATE OF parent_id ON public.folders FOR EACH ROW EXECUTE FUNCTION public.folders_propagate();


--
-- Name: folders folders_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER folders_updated_at BEFORE UPDATE ON public.folders FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: governance_settings governance_settings_touch_bu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER governance_settings_touch_bu BEFORE UPDATE ON public.governance_settings FOR EACH ROW EXECUTE FUNCTION public.governance_settings_touch();


--
-- Name: invoice_lines invoice_lines_aiud; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER invoice_lines_aiud AFTER INSERT OR DELETE OR UPDATE ON public.invoice_lines FOR EACH ROW EXECUTE FUNCTION public.invoice_lines_after_change();


--
-- Name: invoice_lines invoice_lines_guard_biud; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER invoice_lines_guard_biud BEFORE INSERT OR DELETE OR UPDATE ON public.invoice_lines FOR EACH ROW EXECUTE FUNCTION public.invoice_lines_guard();


--
-- Name: invoices invoices_au; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER invoices_au AFTER UPDATE ON public.invoices FOR EACH ROW EXECUTE FUNCTION public.invoices_after_update();


--
-- Name: invoices invoices_bi; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER invoices_bi BEFORE INSERT ON public.invoices FOR EACH ROW EXECUTE FUNCTION public.invoices_before_insert();


--
-- Name: invoices invoices_bu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER invoices_bu BEFORE UPDATE ON public.invoices FOR EACH ROW EXECUTE FUNCTION public.invoices_before_update();


--
-- Name: invoices invoices_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER invoices_updated_at BEFORE UPDATE ON public.invoices FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: key_results key_results_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER key_results_updated_at BEFORE UPDATE ON public.key_results FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: leave_requests leave_requests_aiu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER leave_requests_aiu AFTER INSERT OR UPDATE ON public.leave_requests FOR EACH ROW EXECUTE FUNCTION public.leave_requests_after_write();


--
-- Name: leave_requests leave_requests_bu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER leave_requests_bu BEFORE UPDATE ON public.leave_requests FOR EACH ROW EXECUTE FUNCTION public.leave_requests_before_update();


--
-- Name: legal_contracts legal_contracts_aa_transition_biu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER legal_contracts_aa_transition_biu BEFORE INSERT OR UPDATE ON public.legal_contracts FOR EACH ROW EXECUTE FUNCTION public.legal_contracts_transition();


--
-- Name: legal_contracts legal_contracts_guard_biu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER legal_contracts_guard_biu BEFORE INSERT OR UPDATE ON public.legal_contracts FOR EACH ROW EXECUTE FUNCTION public.legal_contracts_guard();


--
-- Name: legal_contracts legal_contracts_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER legal_contracts_updated_at BEFORE UPDATE ON public.legal_contracts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: meeting_attendees meeting_attendees_ai; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER meeting_attendees_ai AFTER INSERT ON public.meeting_attendees FOR EACH ROW EXECUTE FUNCTION public.meeting_attendees_after_insert();


--
-- Name: message_reactions message_reactions_bi; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER message_reactions_bi BEFORE INSERT ON public.message_reactions FOR EACH ROW EXECUTE FUNCTION public.message_reactions_before_insert();


--
-- Name: messages messages_ai; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER messages_ai AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.messages_after_insert();


--
-- Name: messages messages_bi; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER messages_bi BEFORE INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.messages_before_insert();


--
-- Name: notifications notifications_dispatch; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notifications_dispatch AFTER INSERT ON public.notifications FOR EACH STATEMENT EXECUTE FUNCTION public.notifications_dispatch();


--
-- Name: objectives objectives_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER objectives_updated_at BEFORE UPDATE ON public.objectives FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: operation_cycles operation_cycles_guard_bu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER operation_cycles_guard_bu BEFORE UPDATE ON public.operation_cycles FOR EACH ROW EXECUTE FUNCTION public.operation_cycles_guard();


--
-- Name: operation_cycles operation_cycles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER operation_cycles_updated_at BEFORE UPDATE ON public.operation_cycles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: operation_items operation_items_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER operation_items_updated_at BEFORE UPDATE ON public.operation_items FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: operation_reports operation_reports_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER operation_reports_updated_at BEFORE UPDATE ON public.operation_reports FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: opportunities opportunities_bu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER opportunities_bu BEFORE UPDATE ON public.opportunities FOR EACH ROW EXECUTE FUNCTION public.opportunities_before_update();


--
-- Name: opportunities opportunities_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER opportunities_updated_at BEFORE UPDATE ON public.opportunities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: org_units org_units_ai; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER org_units_ai AFTER INSERT ON public.org_units FOR EACH ROW EXECUTE FUNCTION public.org_units_after_insert();


--
-- Name: org_units org_units_domain_au; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER org_units_domain_au AFTER UPDATE OF domain, archived_at ON public.org_units FOR EACH ROW EXECUTE FUNCTION public.org_units_after_domain_change();


--
-- Name: org_units org_units_drive_aiu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER org_units_drive_aiu AFTER INSERT OR UPDATE OF name ON public.org_units FOR EACH ROW EXECUTE FUNCTION public.org_units_drive_sync();


--
-- Name: org_units org_units_guard_bu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER org_units_guard_bu BEFORE UPDATE ON public.org_units FOR EACH ROW EXECUTE FUNCTION public.org_units_guard();


--
-- Name: org_units org_units_path_au; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER org_units_path_au AFTER UPDATE OF parent_id ON public.org_units FOR EACH ROW EXECUTE FUNCTION public.org_units_propagate_path();


--
-- Name: org_units org_units_path_bi; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER org_units_path_bi BEFORE INSERT ON public.org_units FOR EACH ROW EXECUTE FUNCTION public.org_units_compute_path();


--
-- Name: org_units org_units_path_bu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER org_units_path_bu BEFORE UPDATE OF parent_id ON public.org_units FOR EACH ROW EXECUTE FUNCTION public.org_units_compute_path();


--
-- Name: org_units org_units_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER org_units_updated_at BEFORE UPDATE ON public.org_units FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: profiles profiles_ai_drive; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER profiles_ai_drive AFTER INSERT ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.profiles_after_insert_drive();


--
-- Name: profiles profiles_ai_onboarding; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER profiles_ai_onboarding AFTER INSERT ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.profiles_after_insert_onboarding();


--
-- Name: profiles profiles_completion_biu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER profiles_completion_biu BEFORE INSERT OR UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.profiles_track_completion();


--
-- Name: profiles profiles_drop_access_code; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER profiles_drop_access_code AFTER UPDATE OF status ON public.profiles FOR EACH ROW WHEN (((new.status = 'offboarded'::public.employee_status) AND (old.status <> 'offboarded'::public.employee_status))) EXECUTE FUNCTION public.access_codes_drop_on_offboard();


--
-- Name: profiles profiles_guard_bu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER profiles_guard_bu BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.profiles_guard();


--
-- Name: profiles profiles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: project_liaisons project_liaisons_aiu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER project_liaisons_aiu AFTER INSERT OR UPDATE ON public.project_liaisons FOR EACH ROW EXECUTE FUNCTION public.project_liaisons_after_write();


--
-- Name: projects projects_ai; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER projects_ai AFTER INSERT ON public.projects FOR EACH ROW EXECUTE FUNCTION public.projects_after_insert();


--
-- Name: projects projects_drive_aiu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER projects_drive_aiu AFTER INSERT OR UPDATE OF name ON public.projects FOR EACH ROW EXECUTE FUNCTION public.projects_drive_sync();


--
-- Name: projects projects_guard_biu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER projects_guard_biu BEFORE INSERT OR UPDATE ON public.projects FOR EACH ROW EXECUTE FUNCTION public.projects_guard();


--
-- Name: projects projects_lead_aiu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER projects_lead_aiu AFTER INSERT OR UPDATE OF lead_id ON public.projects FOR EACH ROW EXECUTE FUNCTION public.projects_sync_lead();


--
-- Name: projects projects_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER projects_updated_at BEFORE UPDATE ON public.projects FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: role_templates role_templates_resync_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER role_templates_resync_trg AFTER INSERT OR DELETE OR UPDATE ON public.role_templates FOR EACH STATEMENT EXECUTE FUNCTION public.role_templates_resync();


--
-- Name: shares shares_ai; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER shares_ai AFTER INSERT ON public.shares FOR EACH ROW EXECUTE FUNCTION public.shares_after_insert();


--
-- Name: task_comments task_comments_ai; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER task_comments_ai AFTER INSERT ON public.task_comments FOR EACH ROW EXECUTE FUNCTION public.task_comments_after_insert();


--
-- Name: tasks tasks_aiu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tasks_aiu AFTER INSERT OR UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.tasks_after_write();


--
-- Name: tasks tasks_assignment_biu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tasks_assignment_biu BEFORE INSERT OR UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.tasks_assignment_guard();


--
-- Name: tasks tasks_biu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tasks_biu BEFORE INSERT OR UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.tasks_before_write();


--
-- Name: tasks tasks_protect_review_bu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tasks_protect_review_bu BEFORE UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.tasks_protect_review();


--
-- Name: tasks tasks_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tasks_updated_at BEFORE UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: transactions transactions_guard_biu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER transactions_guard_biu BEFORE INSERT OR UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.transactions_guard();


--
-- Name: transactions transactions_immutable_bud; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER transactions_immutable_bud BEFORE DELETE OR UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.transactions_immutable();


--
-- Name: unit_memberships unit_memberships_notify_ai; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER unit_memberships_notify_ai AFTER INSERT ON public.unit_memberships FOR EACH ROW EXECUTE FUNCTION public.unit_memberships_notify();


--
-- Name: unit_memberships unit_memberships_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER unit_memberships_sync AFTER INSERT OR DELETE OR UPDATE ON public.unit_memberships FOR EACH ROW EXECUTE FUNCTION public.unit_memberships_after_change();


--
-- Name: access_codes access_codes_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_codes
    ADD CONSTRAINT access_codes_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: accounts accounts_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: announcements announcements_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: announcements announcements_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.org_units(id) ON DELETE CASCADE;


--
-- Name: approval_requests approval_requests_decided_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_requests
    ADD CONSTRAINT approval_requests_decided_by_fkey FOREIGN KEY (decided_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: approval_requests approval_requests_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_requests
    ADD CONSTRAINT approval_requests_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL;


--
-- Name: approval_requests approval_requests_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_requests
    ADD CONSTRAINT approval_requests_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: approval_requests approval_requests_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_requests
    ADD CONSTRAINT approval_requests_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.org_units(id) ON DELETE SET NULL;


--
-- Name: budgets budgets_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budgets
    ADD CONSTRAINT budgets_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: budgets budgets_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budgets
    ADD CONSTRAINT budgets_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.org_units(id) ON DELETE CASCADE;


--
-- Name: channel_members channel_members_channel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel_members
    ADD CONSTRAINT channel_members_channel_id_fkey FOREIGN KEY (channel_id) REFERENCES public.channels(id) ON DELETE CASCADE;


--
-- Name: channel_members channel_members_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel_members
    ADD CONSTRAINT channel_members_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: channels channels_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT channels_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: channels channels_project_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT channels_project_fk FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: channels channels_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT channels_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.org_units(id) ON DELETE CASCADE;


--
-- Name: contacts contacts_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE CASCADE;


--
-- Name: contacts contacts_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: document_recents document_recents_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_recents
    ADD CONSTRAINT document_recents_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id) ON DELETE CASCADE;


--
-- Name: document_recents document_recents_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_recents
    ADD CONSTRAINT document_recents_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: document_versions document_versions_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_versions
    ADD CONSTRAINT document_versions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: document_versions document_versions_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_versions
    ADD CONSTRAINT document_versions_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id) ON DELETE CASCADE;


--
-- Name: document_ydocs document_ydocs_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_ydocs
    ADD CONSTRAINT document_ydocs_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id) ON DELETE CASCADE;


--
-- Name: documents documents_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE SET NULL;


--
-- Name: documents documents_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: documents documents_folder_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_folder_id_fkey FOREIGN KEY (folder_id) REFERENCES public.folders(id) ON DELETE CASCADE;


--
-- Name: documents documents_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: documents documents_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL;


--
-- Name: documents documents_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.org_units(id) ON DELETE SET NULL;


--
-- Name: documents documents_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: drive_favorites drive_favorites_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drive_favorites
    ADD CONSTRAINT drive_favorites_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id) ON DELETE CASCADE;


--
-- Name: drive_favorites drive_favorites_folder_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drive_favorites
    ADD CONSTRAINT drive_favorites_folder_id_fkey FOREIGN KEY (folder_id) REFERENCES public.folders(id) ON DELETE CASCADE;


--
-- Name: drive_favorites drive_favorites_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drive_favorites
    ADD CONSTRAINT drive_favorites_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: employment_contracts employment_contracts_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employment_contracts
    ADD CONSTRAINT employment_contracts_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: employment_contracts employment_contracts_document_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employment_contracts
    ADD CONSTRAINT employment_contracts_document_fk FOREIGN KEY (document_id) REFERENCES public.documents(id) ON DELETE SET NULL;


--
-- Name: employment_contracts employment_contracts_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employment_contracts
    ADD CONSTRAINT employment_contracts_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: folders folders_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folders
    ADD CONSTRAINT folders_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: folders folders_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folders
    ADD CONSTRAINT folders_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: folders folders_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folders
    ADD CONSTRAINT folders_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: folders folders_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folders
    ADD CONSTRAINT folders_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.folders(id) ON DELETE CASCADE;


--
-- Name: folders folders_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folders
    ADD CONSTRAINT folders_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: folders folders_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folders
    ADD CONSTRAINT folders_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.org_units(id) ON DELETE CASCADE;


--
-- Name: governance_settings governance_settings_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.governance_settings
    ADD CONSTRAINT governance_settings_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: incidents incidents_reported_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_reported_by_fkey FOREIGN KEY (reported_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: incidents incidents_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.org_units(id) ON DELETE SET NULL;


--
-- Name: interactions interactions_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interactions
    ADD CONSTRAINT interactions_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE CASCADE;


--
-- Name: interactions interactions_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interactions
    ADD CONSTRAINT interactions_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: interactions interactions_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interactions
    ADD CONSTRAINT interactions_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contacts(id) ON DELETE SET NULL;


--
-- Name: interactions interactions_opportunity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interactions
    ADD CONSTRAINT interactions_opportunity_id_fkey FOREIGN KEY (opportunity_id) REFERENCES public.opportunities(id) ON DELETE SET NULL;


--
-- Name: invoice_lines invoice_lines_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_lines
    ADD CONSTRAINT invoice_lines_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE;


--
-- Name: invoices invoices_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE RESTRICT;


--
-- Name: invoices invoices_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: invoices invoices_opportunity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_opportunity_id_fkey FOREIGN KEY (opportunity_id) REFERENCES public.opportunities(id) ON DELETE SET NULL;


--
-- Name: invoices invoices_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.org_units(id) ON DELETE SET NULL;


--
-- Name: key_results key_results_objective_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.key_results
    ADD CONSTRAINT key_results_objective_id_fkey FOREIGN KEY (objective_id) REFERENCES public.objectives(id) ON DELETE CASCADE;


--
-- Name: kpi_definitions kpi_definitions_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kpi_definitions
    ADD CONSTRAINT kpi_definitions_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: leave_requests leave_requests_approver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leave_requests
    ADD CONSTRAINT leave_requests_approver_id_fkey FOREIGN KEY (approver_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: leave_requests leave_requests_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leave_requests
    ADD CONSTRAINT leave_requests_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: legal_contracts legal_contracts_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_contracts
    ADD CONSTRAINT legal_contracts_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE SET NULL;


--
-- Name: legal_contracts legal_contracts_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_contracts
    ADD CONSTRAINT legal_contracts_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: legal_contracts legal_contracts_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_contracts
    ADD CONSTRAINT legal_contracts_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id) ON DELETE SET NULL;


--
-- Name: legal_contracts legal_contracts_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_contracts
    ADD CONSTRAINT legal_contracts_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: legal_contracts legal_contracts_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_contracts
    ADD CONSTRAINT legal_contracts_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL;


--
-- Name: legal_contracts legal_contracts_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_contracts
    ADD CONSTRAINT legal_contracts_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.org_units(id) ON DELETE SET NULL;


--
-- Name: lifecycle_items lifecycle_items_assignee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_items
    ADD CONSTRAINT lifecycle_items_assignee_id_fkey FOREIGN KEY (assignee_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: lifecycle_items lifecycle_items_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_items
    ADD CONSTRAINT lifecycle_items_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: meeting_attendees meeting_attendees_meeting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_attendees
    ADD CONSTRAINT meeting_attendees_meeting_id_fkey FOREIGN KEY (meeting_id) REFERENCES public.meetings(id) ON DELETE CASCADE;


--
-- Name: meeting_attendees meeting_attendees_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_attendees
    ADD CONSTRAINT meeting_attendees_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: meetings meetings_organizer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_organizer_id_fkey FOREIGN KEY (organizer_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: meetings meetings_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL;


--
-- Name: meetings meetings_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.org_units(id) ON DELETE SET NULL;


--
-- Name: message_reactions message_reactions_channel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reactions
    ADD CONSTRAINT message_reactions_channel_id_fkey FOREIGN KEY (channel_id) REFERENCES public.channels(id) ON DELETE CASCADE;


--
-- Name: message_reactions message_reactions_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reactions
    ADD CONSTRAINT message_reactions_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(id) ON DELETE CASCADE;


--
-- Name: message_reactions message_reactions_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reactions
    ADD CONSTRAINT message_reactions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: messages messages_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: messages messages_channel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_channel_id_fkey FOREIGN KEY (channel_id) REFERENCES public.channels(id) ON DELETE CASCADE;


--
-- Name: messages messages_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.messages(id) ON DELETE CASCADE;


--
-- Name: messages messages_pinned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pinned_by_fkey FOREIGN KEY (pinned_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: notification_preferences notification_preferences_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences
    ADD CONSTRAINT notification_preferences_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: objectives objectives_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.objectives
    ADD CONSTRAINT objectives_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: objectives objectives_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.objectives
    ADD CONSTRAINT objectives_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.objectives(id) ON DELETE SET NULL;


--
-- Name: objectives objectives_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.objectives
    ADD CONSTRAINT objectives_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.org_units(id) ON DELETE CASCADE;


--
-- Name: operation_cycles operation_cycles_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operation_cycles
    ADD CONSTRAINT operation_cycles_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: operation_cycles operation_cycles_parent_cycle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operation_cycles
    ADD CONSTRAINT operation_cycles_parent_cycle_id_fkey FOREIGN KEY (parent_cycle_id) REFERENCES public.operation_cycles(id) ON DELETE SET NULL;


--
-- Name: operation_cycles operation_cycles_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operation_cycles
    ADD CONSTRAINT operation_cycles_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: operation_items operation_items_cycle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operation_items
    ADD CONSTRAINT operation_items_cycle_id_fkey FOREIGN KEY (cycle_id) REFERENCES public.operation_cycles(id) ON DELETE CASCADE;


--
-- Name: operation_items operation_items_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operation_items
    ADD CONSTRAINT operation_items_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: operation_reports operation_reports_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operation_reports
    ADD CONSTRAINT operation_reports_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: operation_reports operation_reports_cycle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operation_reports
    ADD CONSTRAINT operation_reports_cycle_id_fkey FOREIGN KEY (cycle_id) REFERENCES public.operation_cycles(id) ON DELETE CASCADE;


--
-- Name: operation_reports operation_reports_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operation_reports
    ADD CONSTRAINT operation_reports_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: operation_reports operation_reports_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operation_reports
    ADD CONSTRAINT operation_reports_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: opportunities opportunities_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.opportunities
    ADD CONSTRAINT opportunities_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE CASCADE;


--
-- Name: opportunities opportunities_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.opportunities
    ADD CONSTRAINT opportunities_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: opportunities opportunities_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.opportunities
    ADD CONSTRAINT opportunities_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL;


--
-- Name: org_units org_units_domain_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_units
    ADD CONSTRAINT org_units_domain_fk FOREIGN KEY (domain) REFERENCES public.unit_domains(key) ON UPDATE CASCADE;


--
-- Name: org_units org_units_merged_into_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_units
    ADD CONSTRAINT org_units_merged_into_fkey FOREIGN KEY (merged_into) REFERENCES public.org_units(id) ON DELETE SET NULL;


--
-- Name: org_units org_units_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_units
    ADD CONSTRAINT org_units_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.org_units(id) ON DELETE RESTRICT;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_manager_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_manager_id_fkey FOREIGN KEY (manager_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: profiles profiles_primary_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_primary_unit_id_fkey FOREIGN KEY (primary_unit_id) REFERENCES public.org_units(id) ON DELETE SET NULL;


--
-- Name: project_liaisons project_liaisons_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_liaisons
    ADD CONSTRAINT project_liaisons_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: project_liaisons project_liaisons_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_liaisons
    ADD CONSTRAINT project_liaisons_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: project_liaisons project_liaisons_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_liaisons
    ADD CONSTRAINT project_liaisons_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: project_liaisons project_liaisons_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_liaisons
    ADD CONSTRAINT project_liaisons_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.org_units(id) ON DELETE CASCADE;


--
-- Name: project_members project_members_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_members
    ADD CONSTRAINT project_members_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: project_members project_members_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_members
    ADD CONSTRAINT project_members_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: projects projects_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: projects projects_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: projects projects_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: projects projects_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.org_units(id) ON DELETE SET NULL;


--
-- Name: push_subscriptions push_subscriptions_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: role_grants role_grants_granted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_grants
    ADD CONSTRAINT role_grants_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: role_grants role_grants_membership_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_grants
    ADD CONSTRAINT role_grants_membership_id_fkey FOREIGN KEY (membership_id) REFERENCES public.unit_memberships(id) ON DELETE CASCADE;


--
-- Name: role_grants role_grants_permission_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_grants
    ADD CONSTRAINT role_grants_permission_fkey FOREIGN KEY (permission) REFERENCES public.permissions(key) ON DELETE CASCADE;


--
-- Name: role_grants role_grants_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_grants
    ADD CONSTRAINT role_grants_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: role_grants role_grants_scope_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_grants
    ADD CONSTRAINT role_grants_scope_unit_id_fkey FOREIGN KEY (scope_unit_id) REFERENCES public.org_units(id) ON DELETE CASCADE;


--
-- Name: role_templates role_templates_domain_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_templates
    ADD CONSTRAINT role_templates_domain_fk FOREIGN KEY (domain) REFERENCES public.unit_domains(key) ON UPDATE CASCADE;


--
-- Name: role_templates role_templates_permission_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_templates
    ADD CONSTRAINT role_templates_permission_fkey FOREIGN KEY (permission) REFERENCES public.permissions(key) ON DELETE CASCADE;


--
-- Name: salaries salaries_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.salaries
    ADD CONSTRAINT salaries_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: salaries salaries_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.salaries
    ADD CONSTRAINT salaries_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: shares shares_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shares
    ADD CONSTRAINT shares_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: shares shares_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shares
    ADD CONSTRAINT shares_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id) ON DELETE CASCADE;


--
-- Name: shares shares_folder_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shares
    ADD CONSTRAINT shares_folder_id_fkey FOREIGN KEY (folder_id) REFERENCES public.folders(id) ON DELETE CASCADE;


--
-- Name: shares shares_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shares
    ADD CONSTRAINT shares_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: shares shares_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shares
    ADD CONSTRAINT shares_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.org_units(id) ON DELETE CASCADE;


--
-- Name: task_comments task_comments_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_comments
    ADD CONSTRAINT task_comments_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: task_comments task_comments_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_comments
    ADD CONSTRAINT task_comments_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_dependencies task_dependencies_depends_on_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_dependencies
    ADD CONSTRAINT task_dependencies_depends_on_id_fkey FOREIGN KEY (depends_on_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_dependencies task_dependencies_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_dependencies
    ADD CONSTRAINT task_dependencies_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: tasks tasks_assignee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_assignee_id_fkey FOREIGN KEY (assignee_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: tasks tasks_objective_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_objective_fk FOREIGN KEY (objective_id) REFERENCES public.objectives(id) ON DELETE SET NULL;


--
-- Name: tasks tasks_operation_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_operation_item_id_fkey FOREIGN KEY (operation_item_id) REFERENCES public.operation_items(id) ON DELETE SET NULL;


--
-- Name: tasks tasks_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: tasks tasks_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: tasks tasks_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: tasks tasks_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: tasks tasks_validated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_validated_by_fkey FOREIGN KEY (validated_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: transactions transactions_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE SET NULL;


--
-- Name: transactions transactions_approval_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_approval_id_fkey FOREIGN KEY (approval_id) REFERENCES public.approval_requests(id) ON DELETE SET NULL;


--
-- Name: transactions transactions_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: transactions transactions_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE SET NULL;


--
-- Name: transactions transactions_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL;


--
-- Name: transactions transactions_reversed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_reversed_by_fkey FOREIGN KEY (reversed_by) REFERENCES public.transactions(id) ON DELETE SET NULL;


--
-- Name: transactions transactions_reverses_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_reverses_id_fkey FOREIGN KEY (reverses_id) REFERENCES public.transactions(id) ON DELETE RESTRICT;


--
-- Name: transactions transactions_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.org_units(id) ON DELETE SET NULL;


--
-- Name: unit_memberships unit_memberships_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_memberships
    ADD CONSTRAINT unit_memberships_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: unit_memberships unit_memberships_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_memberships
    ADD CONSTRAINT unit_memberships_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: unit_memberships unit_memberships_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_memberships
    ADD CONSTRAINT unit_memberships_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.org_units(id) ON DELETE CASCADE;


--
-- Name: access_codes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.access_codes ENABLE ROW LEVEL SECURITY;

--
-- Name: accounts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;

--
-- Name: announcements annonces: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "annonces: lecture" ON public.announcements FOR SELECT TO authenticated USING ((public.is_active_user() AND ((unit_id IS NULL) OR public.in_unit(unit_id) OR public.has_perm('unit.manage'::text, unit_id) OR (author_id = auth.uid()))));


--
-- Name: announcements annonces: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "annonces: modification" ON public.announcements FOR UPDATE TO authenticated USING (((author_id = auth.uid()) OR public.is_admin())) WITH CHECK (((author_id = auth.uid()) OR public.is_admin()));


--
-- Name: announcements annonces: publication; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "annonces: publication" ON public.announcements FOR INSERT TO authenticated WITH CHECK ((public.has_perm('announcements.publish'::text) AND (author_id = auth.uid())));


--
-- Name: announcements annonces: suppression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "annonces: suppression" ON public.announcements FOR DELETE TO authenticated USING (((author_id = auth.uid()) OR public.is_admin()));


--
-- Name: announcements; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

--
-- Name: approval_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.approval_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_log audit: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "audit: lecture" ON public.audit_log FOR SELECT TO authenticated USING (public.has_perm('audit.view'::text));


--
-- Name: audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: budgets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;

--
-- Name: budgets budgets: gestion; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "budgets: gestion" ON public.budgets TO authenticated USING (public.has_perm('finance.admin'::text)) WITH CHECK (public.has_perm('finance.admin'::text));


--
-- Name: budgets budgets: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "budgets: lecture" ON public.budgets FOR SELECT TO authenticated USING ((public.can_read_finance() OR public.has_perm('unit.manage'::text, unit_id) OR ((project_id IS NOT NULL) AND public.can_view_project(project_id))));


--
-- Name: channels canaux: création; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "canaux: création" ON public.channels FOR INSERT TO authenticated WITH CHECK ((public.is_active_user() AND (kind = 'group'::public.channel_kind) AND (created_by = auth.uid())));


--
-- Name: channels canaux: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "canaux: lecture" ON public.channels FOR SELECT TO authenticated USING (((created_by = auth.uid()) OR public.can_access_channel(id)));


--
-- Name: channels canaux: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "canaux: modification" ON public.channels FOR UPDATE TO authenticated USING (((created_by = auth.uid()) OR public.is_admin() OR ((kind = 'unit'::public.channel_kind) AND public.has_perm('unit.manage'::text, unit_id)) OR ((kind = 'project'::public.channel_kind) AND public.can_manage_project(project_id)))) WITH CHECK (((created_by = auth.uid()) OR public.is_admin() OR ((kind = 'unit'::public.channel_kind) AND public.has_perm('unit.manage'::text, unit_id)) OR ((kind = 'project'::public.channel_kind) AND public.can_manage_project(project_id))));


--
-- Name: channel_members; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.channel_members ENABLE ROW LEVEL SECURITY;

--
-- Name: channels; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;

--
-- Name: task_comments commentaires: ajout; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "commentaires: ajout" ON public.task_comments FOR INSERT TO authenticated WITH CHECK (((author_id = auth.uid()) AND public.can_view_task(task_id)));


--
-- Name: task_comments commentaires: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "commentaires: lecture" ON public.task_comments FOR SELECT TO authenticated USING (public.can_view_task(task_id));


--
-- Name: task_comments commentaires: suppression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "commentaires: suppression" ON public.task_comments FOR DELETE TO authenticated USING ((author_id = auth.uid()));


--
-- Name: company_settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.company_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: accounts comptes: création; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "comptes: création" ON public.accounts FOR INSERT TO authenticated WITH CHECK (public.has_perm('crm.edit'::text));


--
-- Name: accounts comptes: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "comptes: lecture" ON public.accounts FOR SELECT TO authenticated USING ((public.can_read_crm() OR (owner_id = auth.uid())));


--
-- Name: accounts comptes: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "comptes: modification" ON public.accounts FOR UPDATE TO authenticated USING ((public.has_perm('crm.edit'::text) OR (owner_id = auth.uid()))) WITH CHECK ((public.has_perm('crm.edit'::text) OR (owner_id = auth.uid())));


--
-- Name: accounts comptes: suppression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "comptes: suppression" ON public.accounts FOR DELETE TO authenticated USING (public.has_perm('crm.admin'::text));


--
-- Name: leave_requests congés: demande; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "congés: demande" ON public.leave_requests FOR INSERT TO authenticated WITH CHECK (((profile_id = auth.uid()) AND (status = 'pending'::public.request_status) AND public.is_active_user()));


--
-- Name: leave_requests congés: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "congés: lecture" ON public.leave_requests FOR SELECT TO authenticated USING (((profile_id = auth.uid()) OR public.has_perm('hr.view'::text) OR public.has_perm('hr.admin'::text) OR public.manages_profile(profile_id)));


--
-- Name: leave_requests congés: mise à jour; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "congés: mise à jour" ON public.leave_requests FOR UPDATE TO authenticated USING (((profile_id = auth.uid()) OR public.has_perm('hr.admin'::text) OR public.manages_profile(profile_id))) WITH CHECK (((profile_id = auth.uid()) OR public.has_perm('hr.admin'::text) OR public.manages_profile(profile_id)));


--
-- Name: leave_requests congés: suppression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "congés: suppression" ON public.leave_requests FOR DELETE TO authenticated USING (((profile_id = auth.uid()) AND (status = 'pending'::public.request_status)));


--
-- Name: contacts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contacts ENABLE ROW LEVEL SECURITY;

--
-- Name: contacts contacts: création; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "contacts: création" ON public.contacts FOR INSERT TO authenticated WITH CHECK (public.has_perm('crm.edit'::text));


--
-- Name: contacts contacts: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "contacts: lecture" ON public.contacts FOR SELECT TO authenticated USING ((public.can_read_crm() OR (owner_id = auth.uid())));


--
-- Name: contacts contacts: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "contacts: modification" ON public.contacts FOR UPDATE TO authenticated USING ((public.has_perm('crm.edit'::text) OR (owner_id = auth.uid()))) WITH CHECK ((public.has_perm('crm.edit'::text) OR (owner_id = auth.uid())));


--
-- Name: contacts contacts: suppression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "contacts: suppression" ON public.contacts FOR DELETE TO authenticated USING ((public.has_perm('crm.admin'::text) OR (owner_id = auth.uid())));


--
-- Name: employment_contracts contrats: gestion; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "contrats: gestion" ON public.employment_contracts TO authenticated USING (public.has_perm('hr.admin'::text)) WITH CHECK (public.has_perm('hr.admin'::text));


--
-- Name: employment_contracts contrats: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "contrats: lecture" ON public.employment_contracts FOR SELECT TO authenticated USING (((profile_id = auth.uid()) OR public.has_perm('hr.view'::text) OR public.has_perm('hr.admin'::text)));


--
-- Name: legal_contracts contrats: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "contrats: lecture" ON public.legal_contracts FOR SELECT TO authenticated USING ((public.has_perm('legal.view'::text) OR public.has_perm('legal.admin'::text) OR public.has_perm('dashboard.exec'::text) OR (owner_id = auth.uid()) OR ((project_id IS NOT NULL) AND public.is_project_lead(project_id))));


--
-- Name: legal_contracts contrats: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "contrats: modification" ON public.legal_contracts FOR UPDATE TO authenticated USING ((public.has_perm('legal.admin'::text) OR public.is_ceo())) WITH CHECK ((public.has_perm('legal.admin'::text) OR public.is_ceo()));


--
-- Name: legal_contracts contrats: rédaction; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "contrats: rédaction" ON public.legal_contracts FOR INSERT TO authenticated WITH CHECK ((public.has_perm('legal.admin'::text) OR public.is_ceo()));


--
-- Name: legal_contracts contrats: suppression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "contrats: suppression" ON public.legal_contracts FOR DELETE TO authenticated USING (((public.has_perm('legal.admin'::text) OR public.is_ceo()) AND (status = 'draft'::public.legal_contract_status)));


--
-- Name: operation_cycles cycles: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "cycles: lecture" ON public.operation_cycles FOR SELECT TO authenticated USING ((public.can_view_project(project_id) OR public.has_perm('ops.plan'::text) OR public.has_perm('ops.review'::text)));


--
-- Name: operation_cycles cycles: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "cycles: modification" ON public.operation_cycles FOR UPDATE TO authenticated USING (public.can_plan_project(project_id)) WITH CHECK (public.can_plan_project(project_id));


--
-- Name: operation_cycles cycles: suppression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "cycles: suppression" ON public.operation_cycles FOR DELETE TO authenticated USING ((public.can_plan_project(project_id) AND (status <> 'published'::public.cycle_status)));


--
-- Name: operation_cycles cycles: écriture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "cycles: écriture" ON public.operation_cycles FOR INSERT TO authenticated WITH CHECK (public.can_plan_project(project_id));


--
-- Name: document_recents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.document_recents ENABLE ROW LEVEL SECURITY;

--
-- Name: document_versions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.document_versions ENABLE ROW LEVEL SECURITY;

--
-- Name: document_ydocs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.document_ydocs ENABLE ROW LEVEL SECURITY;

--
-- Name: documents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;

--
-- Name: documents documents: création; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "documents: création" ON public.documents FOR INSERT TO authenticated WITH CHECK ((public.is_active_user() AND (owner_id = auth.uid()) AND ((folder_id IS NULL) OR (public.folder_access(folder_id) >= 2))));


--
-- Name: documents documents: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "documents: lecture" ON public.documents FOR SELECT TO authenticated USING (((owner_id = auth.uid()) OR (public.document_access(id) >= 1)));


--
-- Name: documents documents: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "documents: modification" ON public.documents FOR UPDATE TO authenticated USING ((public.document_access(id) >= 2)) WITH CHECK (((folder_id IS NULL) OR (public.folder_access(folder_id) >= 2) OR (public.document_access(id) >= 2)));


--
-- Name: documents documents: suppression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "documents: suppression" ON public.documents FOR DELETE TO authenticated USING ((public.document_access(id) = 3));


--
-- Name: unit_domains domaines: gestion; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "domaines: gestion" ON public.unit_domains TO authenticated USING (public.is_ceo()) WITH CHECK (public.is_ceo());


--
-- Name: unit_domains domaines: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "domaines: lecture" ON public.unit_domains FOR SELECT TO authenticated USING (public.is_active_user());


--
-- Name: folders dossiers: création; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "dossiers: création" ON public.folders FOR INSERT TO authenticated WITH CHECK (((parent_id IS NOT NULL) AND (public.folder_access(parent_id) >= 2) AND (NOT is_root)));


--
-- Name: folders dossiers: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "dossiers: lecture" ON public.folders FOR SELECT TO authenticated USING (((public.folder_access(id) >= 1) OR ((parent_id IS NOT NULL) AND (public.folder_access(parent_id) >= 1))));


--
-- Name: folders dossiers: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "dossiers: modification" ON public.folders FOR UPDATE TO authenticated USING (((public.folder_access(id) >= 2) AND (NOT is_root))) WITH CHECK (((NOT is_root) AND (parent_id IS NOT NULL) AND (public.folder_access(parent_id) >= 2)));


--
-- Name: folders dossiers: suppression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "dossiers: suppression" ON public.folders FOR DELETE TO authenticated USING (((public.folder_access(id) = 3) AND (NOT is_root)));


--
-- Name: drive_favorites; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.drive_favorites ENABLE ROW LEVEL SECURITY;

--
-- Name: task_dependencies dépendances: gestion; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "dépendances: gestion" ON public.task_dependencies TO authenticated USING (public.can_edit_task(task_id)) WITH CHECK ((public.can_edit_task(task_id) AND public.can_view_task(depends_on_id)));


--
-- Name: task_dependencies dépendances: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "dépendances: lecture" ON public.task_dependencies FOR SELECT TO authenticated USING (public.can_view_task(task_id));


--
-- Name: employment_contracts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.employment_contracts ENABLE ROW LEVEL SECURITY;

--
-- Name: invoices factures: création; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "factures: création" ON public.invoices FOR INSERT TO authenticated WITH CHECK (public.has_perm('finance.admin'::text));


--
-- Name: invoices factures: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "factures: lecture" ON public.invoices FOR SELECT TO authenticated USING (public.can_read_finance());


--
-- Name: invoices factures: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "factures: modification" ON public.invoices FOR UPDATE TO authenticated USING (public.has_perm('finance.admin'::text)) WITH CHECK (public.has_perm('finance.admin'::text));


--
-- Name: drive_favorites favoris: les miens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "favoris: les miens" ON public.drive_favorites TO authenticated USING ((profile_id = auth.uid())) WITH CHECK ((profile_id = auth.uid()));


--
-- Name: folders; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.folders ENABLE ROW LEVEL SECURITY;

--
-- Name: governance_settings gouvernance: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "gouvernance: lecture" ON public.governance_settings FOR SELECT TO authenticated USING (public.is_active_user());


--
-- Name: governance_settings gouvernance: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "gouvernance: modification" ON public.governance_settings FOR UPDATE TO authenticated USING ((public.is_ceo() AND public.mfa_ok())) WITH CHECK ((public.is_ceo() AND public.mfa_ok()));


--
-- Name: governance_settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.governance_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: role_grants grants: dérogation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "grants: dérogation" ON public.role_grants FOR INSERT TO authenticated WITH CHECK ((public.has_perm('grants.manage'::text) AND public.mfa_ok() AND (source = 'manual'::public.grant_source) AND (granted_by = auth.uid()) AND (profile_id <> auth.uid()) AND ((NOT public.permission_reserved(permission)) OR public.is_ceo()) AND (expires_at IS NOT NULL) AND (expires_at > now()) AND (expires_at <= ((now() + make_interval(days => public.max_grant_days())) + '01:00:00'::interval))));


--
-- Name: role_grants grants: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "grants: lecture" ON public.role_grants FOR SELECT TO authenticated USING (((profile_id = auth.uid()) OR public.has_perm('grants.manage'::text) OR public.has_perm('audit.view'::text)));


--
-- Name: role_grants grants: révocation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "grants: révocation" ON public.role_grants FOR DELETE TO authenticated USING ((public.has_perm('grants.manage'::text) AND (source = 'manual'::public.grant_source) AND public.mfa_ok()));


--
-- Name: incidents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;

--
-- Name: incidents incidents: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "incidents: lecture" ON public.incidents FOR SELECT TO authenticated USING (public.is_active_user());


--
-- Name: incidents incidents: signalement; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "incidents: signalement" ON public.incidents FOR INSERT TO authenticated WITH CHECK ((public.is_active_user() AND (reported_by = auth.uid())));


--
-- Name: incidents incidents: suivi; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "incidents: suivi" ON public.incidents FOR UPDATE TO authenticated USING ((public.has_perm('metrics.manage'::text) OR (reported_by = auth.uid()) OR public.has_perm('unit.manage'::text, unit_id))) WITH CHECK ((public.has_perm('metrics.manage'::text) OR (reported_by = auth.uid()) OR public.has_perm('unit.manage'::text, unit_id)));


--
-- Name: incidents incidents: suppression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "incidents: suppression" ON public.incidents FOR DELETE TO authenticated USING (public.has_perm('metrics.manage'::text));


--
-- Name: interactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.interactions ENABLE ROW LEVEL SECURITY;

--
-- Name: interactions interactions: création; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "interactions: création" ON public.interactions FOR INSERT TO authenticated WITH CHECK (((author_id = auth.uid()) AND (public.has_perm('crm.edit'::text) OR public.has_perm('crm.view'::text))));


--
-- Name: interactions interactions: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "interactions: lecture" ON public.interactions FOR SELECT TO authenticated USING ((public.can_read_crm() OR (author_id = auth.uid())));


--
-- Name: interactions interactions: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "interactions: modification" ON public.interactions FOR UPDATE TO authenticated USING (((author_id = auth.uid()) OR public.has_perm('crm.admin'::text))) WITH CHECK (((author_id = auth.uid()) OR public.has_perm('crm.admin'::text)));


--
-- Name: interactions interactions: suppression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "interactions: suppression" ON public.interactions FOR DELETE TO authenticated USING (((author_id = auth.uid()) OR public.has_perm('crm.admin'::text)));


--
-- Name: invoice_counters; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.invoice_counters ENABLE ROW LEVEL SECURITY;

--
-- Name: invoice_lines; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.invoice_lines ENABLE ROW LEVEL SECURITY;

--
-- Name: invoices; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

--
-- Name: key_results; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.key_results ENABLE ROW LEVEL SECURITY;

--
-- Name: kpi_definitions kpi: gestion; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "kpi: gestion" ON public.kpi_definitions TO authenticated USING ((public.has_perm('dashboard.exec'::text) OR public.has_perm('objectives.admin'::text))) WITH CHECK ((public.has_perm('dashboard.exec'::text) OR public.has_perm('objectives.admin'::text)));


--
-- Name: kpi_definitions kpi: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "kpi: lecture" ON public.kpi_definitions FOR SELECT TO authenticated USING (public.is_active_user());


--
-- Name: kpi_definitions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.kpi_definitions ENABLE ROW LEVEL SECURITY;

--
-- Name: leave_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leave_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: legal_contracts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.legal_contracts ENABLE ROW LEVEL SECURITY;

--
-- Name: lifecycle_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_items ENABLE ROW LEVEL SECURITY;

--
-- Name: invoice_lines lignes facture: gestion; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "lignes facture: gestion" ON public.invoice_lines TO authenticated USING (public.has_perm('finance.admin'::text)) WITH CHECK (public.has_perm('finance.admin'::text));


--
-- Name: invoice_lines lignes facture: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "lignes facture: lecture" ON public.invoice_lines FOR SELECT TO authenticated USING (public.can_read_finance());


--
-- Name: operation_items lignes: gestion; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "lignes: gestion" ON public.operation_items TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.operation_cycles c
  WHERE ((c.id = operation_items.cycle_id) AND public.can_plan_project(c.project_id))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.operation_cycles c
  WHERE ((c.id = operation_items.cycle_id) AND public.can_plan_project(c.project_id)))));


--
-- Name: operation_items lignes: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "lignes: lecture" ON public.operation_items FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.operation_cycles c
  WHERE ((c.id = operation_items.cycle_id) AND (public.can_view_project(c.project_id) OR public.has_perm('ops.plan'::text))))));


--
-- Name: meeting_attendees; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.meeting_attendees ENABLE ROW LEVEL SECURITY;

--
-- Name: meetings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.meetings ENABLE ROW LEVEL SECURITY;

--
-- Name: unit_memberships memberships: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "memberships: lecture" ON public.unit_memberships FOR SELECT TO authenticated USING (public.is_active_user());


--
-- Name: channel_members membres canal: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "membres canal: lecture" ON public.channel_members FOR SELECT TO authenticated USING (((profile_id = auth.uid()) OR public.can_access_channel(channel_id)));


--
-- Name: channel_members membres canal: préférences; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "membres canal: préférences" ON public.channel_members FOR UPDATE TO authenticated USING ((profile_id = auth.uid())) WITH CHECK ((profile_id = auth.uid()));


--
-- Name: channel_members membres canal: quitter / retirer; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "membres canal: quitter / retirer" ON public.channel_members FOR DELETE TO authenticated USING (((profile_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.channels c
  WHERE ((c.id = channel_members.channel_id) AND (c.created_by = auth.uid()))))));


--
-- Name: channel_members membres canal: rejoindre / ajouter; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "membres canal: rejoindre / ajouter" ON public.channel_members FOR INSERT TO authenticated WITH CHECK ((((profile_id = auth.uid()) AND public.can_access_channel(channel_id)) OR (EXISTS ( SELECT 1
   FROM public.channels c
  WHERE ((c.id = channel_members.channel_id) AND (c.kind = 'group'::public.channel_kind) AND (c.created_by = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM public.channel_members m
  WHERE ((m.channel_id = channel_members.channel_id) AND (m.profile_id = auth.uid()) AND (m.role = 'owner'::text))))));


--
-- Name: project_members membres projet: gestion; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "membres projet: gestion" ON public.project_members TO authenticated USING (public.can_manage_project(project_id)) WITH CHECK (public.can_manage_project(project_id));


--
-- Name: project_members membres projet: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "membres projet: lecture" ON public.project_members FOR SELECT TO authenticated USING (public.can_view_project(project_id));


--
-- Name: message_reactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;

--
-- Name: messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: messages messages: envoi; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "messages: envoi" ON public.messages FOR INSERT TO authenticated WITH CHECK (((author_id = auth.uid()) AND public.can_access_channel(channel_id) AND (EXISTS ( SELECT 1
   FROM public.channels c
  WHERE ((c.id = messages.channel_id) AND (c.archived_at IS NULL))))));


--
-- Name: messages messages: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "messages: lecture" ON public.messages FOR SELECT TO authenticated USING (public.can_access_channel(channel_id));


--
-- Name: messages messages: édition; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "messages: édition" ON public.messages FOR UPDATE TO authenticated USING ((author_id = auth.uid())) WITH CHECK ((author_id = auth.uid()));


--
-- Name: budgets mfa: delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: delete" ON public.budgets AS RESTRICTIVE FOR DELETE TO authenticated USING (public.mfa_ok());


--
-- Name: company_settings mfa: delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: delete" ON public.company_settings AS RESTRICTIVE FOR DELETE TO authenticated USING (public.mfa_ok());


--
-- Name: employment_contracts mfa: delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: delete" ON public.employment_contracts AS RESTRICTIVE FOR DELETE TO authenticated USING (public.mfa_ok());


--
-- Name: invoice_lines mfa: delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: delete" ON public.invoice_lines AS RESTRICTIVE FOR DELETE TO authenticated USING (public.mfa_ok());


--
-- Name: invoices mfa: delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: delete" ON public.invoices AS RESTRICTIVE FOR DELETE TO authenticated USING (public.mfa_ok());


--
-- Name: legal_contracts mfa: delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: delete" ON public.legal_contracts AS RESTRICTIVE FOR DELETE TO authenticated USING (public.mfa_ok());


--
-- Name: transactions mfa: delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: delete" ON public.transactions AS RESTRICTIVE FOR DELETE TO authenticated USING (public.mfa_ok());


--
-- Name: budgets mfa: insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: insert" ON public.budgets AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.mfa_ok());


--
-- Name: company_settings mfa: insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: insert" ON public.company_settings AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.mfa_ok());


--
-- Name: employment_contracts mfa: insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: insert" ON public.employment_contracts AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.mfa_ok());


--
-- Name: invoice_lines mfa: insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: insert" ON public.invoice_lines AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.mfa_ok());


--
-- Name: invoices mfa: insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: insert" ON public.invoices AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.mfa_ok());


--
-- Name: legal_contracts mfa: insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: insert" ON public.legal_contracts AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.mfa_ok());


--
-- Name: transactions mfa: insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: insert" ON public.transactions AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.mfa_ok());


--
-- Name: salaries mfa: salaires; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: salaires" ON public.salaries AS RESTRICTIVE TO authenticated USING (((profile_id = auth.uid()) OR public.mfa_ok())) WITH CHECK (public.mfa_ok());


--
-- Name: budgets mfa: update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: update" ON public.budgets AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.mfa_ok());


--
-- Name: company_settings mfa: update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: update" ON public.company_settings AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.mfa_ok());


--
-- Name: employment_contracts mfa: update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: update" ON public.employment_contracts AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.mfa_ok());


--
-- Name: invoice_lines mfa: update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: update" ON public.invoice_lines AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.mfa_ok());


--
-- Name: invoices mfa: update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: update" ON public.invoices AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.mfa_ok());


--
-- Name: legal_contracts mfa: update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: update" ON public.legal_contracts AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.mfa_ok());


--
-- Name: transactions mfa: update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "mfa: update" ON public.transactions AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.mfa_ok());


--
-- Name: product_metrics métriques: gestion; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "métriques: gestion" ON public.product_metrics TO authenticated USING (public.has_perm('metrics.manage'::text)) WITH CHECK (public.has_perm('metrics.manage'::text));


--
-- Name: product_metrics métriques: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "métriques: lecture" ON public.product_metrics FOR SELECT TO authenticated USING ((public.has_perm('dashboard.exec'::text) OR public.has_perm('metrics.manage'::text)));


--
-- Name: notification_preferences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications notifications: les miennes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "notifications: les miennes" ON public.notifications FOR SELECT TO authenticated USING ((profile_id = auth.uid()));


--
-- Name: notifications notifications: marquer lue; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "notifications: marquer lue" ON public.notifications FOR UPDATE TO authenticated USING ((profile_id = auth.uid())) WITH CHECK ((profile_id = auth.uid()));


--
-- Name: notifications notifications: supprimer; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "notifications: supprimer" ON public.notifications FOR DELETE TO authenticated USING ((profile_id = auth.uid()));


--
-- Name: objectives objectifs: création; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "objectifs: création" ON public.objectives FOR INSERT TO authenticated WITH CHECK ((((level = 'company'::public.objective_level) AND public.has_perm('objectives.admin'::text)) OR ((level = 'unit'::public.objective_level) AND (public.has_perm('unit.manage'::text, unit_id) OR public.has_perm('objectives.admin'::text))) OR ((level = 'individual'::public.objective_level) AND ((owner_id = auth.uid()) OR public.manages_profile(owner_id)))));


--
-- Name: objectives objectifs: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "objectifs: lecture" ON public.objectives FOR SELECT TO authenticated USING ((public.is_active_user() AND ((level = ANY (ARRAY['company'::public.objective_level, 'unit'::public.objective_level])) OR (owner_id = auth.uid()) OR public.manages_profile(owner_id) OR public.has_perm('hr.admin'::text))));


--
-- Name: objectives objectifs: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "objectifs: modification" ON public.objectives FOR UPDATE TO authenticated USING (public.can_edit_objective(id)) WITH CHECK ((((level = 'company'::public.objective_level) AND public.has_perm('objectives.admin'::text)) OR ((level = 'unit'::public.objective_level) AND (public.has_perm('unit.manage'::text, unit_id) OR public.has_perm('objectives.admin'::text))) OR ((level = 'individual'::public.objective_level) AND ((owner_id = auth.uid()) OR public.manages_profile(owner_id)))));


--
-- Name: objectives objectifs: suppression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "objectifs: suppression" ON public.objectives FOR DELETE TO authenticated USING (public.can_edit_objective(id));


--
-- Name: objectives; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.objectives ENABLE ROW LEVEL SECURITY;

--
-- Name: operation_cycles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.operation_cycles ENABLE ROW LEVEL SECURITY;

--
-- Name: operation_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.operation_items ENABLE ROW LEVEL SECURITY;

--
-- Name: operation_reports; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.operation_reports ENABLE ROW LEVEL SECURITY;

--
-- Name: opportunities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.opportunities ENABLE ROW LEVEL SECURITY;

--
-- Name: opportunities opportunités: création; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "opportunités: création" ON public.opportunities FOR INSERT TO authenticated WITH CHECK (public.has_perm('crm.edit'::text));


--
-- Name: opportunities opportunités: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "opportunités: lecture" ON public.opportunities FOR SELECT TO authenticated USING ((public.can_read_crm() OR (owner_id = auth.uid())));


--
-- Name: opportunities opportunités: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "opportunités: modification" ON public.opportunities FOR UPDATE TO authenticated USING ((public.has_perm('crm.edit'::text) OR (owner_id = auth.uid()))) WITH CHECK ((public.has_perm('crm.edit'::text) OR (owner_id = auth.uid())));


--
-- Name: opportunities opportunités: suppression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "opportunités: suppression" ON public.opportunities FOR DELETE TO authenticated USING (public.has_perm('crm.admin'::text));


--
-- Name: org_units; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.org_units ENABLE ROW LEVEL SECURITY;

--
-- Name: lifecycle_items parcours: avancement; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "parcours: avancement" ON public.lifecycle_items FOR UPDATE TO authenticated USING (((profile_id = auth.uid()) OR (assignee_id = auth.uid()) OR public.has_perm('hr.admin'::text) OR public.manages_profile(profile_id))) WITH CHECK (((profile_id = auth.uid()) OR (assignee_id = auth.uid()) OR public.has_perm('hr.admin'::text) OR public.manages_profile(profile_id)));


--
-- Name: lifecycle_items parcours: gestion; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "parcours: gestion" ON public.lifecycle_items FOR INSERT TO authenticated WITH CHECK ((public.has_perm('hr.admin'::text) OR public.manages_profile(profile_id)));


--
-- Name: lifecycle_items parcours: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "parcours: lecture" ON public.lifecycle_items FOR SELECT TO authenticated USING (((profile_id = auth.uid()) OR (assignee_id = auth.uid()) OR public.has_perm('hr.view'::text) OR public.has_perm('hr.admin'::text) OR public.manages_profile(profile_id)));


--
-- Name: lifecycle_items parcours: suppression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "parcours: suppression" ON public.lifecycle_items FOR DELETE TO authenticated USING ((public.has_perm('hr.admin'::text) OR public.manages_profile(profile_id)));


--
-- Name: shares partages: création; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "partages: création" ON public.shares FOR INSERT TO authenticated WITH CHECK (((created_by = auth.uid()) AND (((public.share_rank(role) <= COALESCE(public.folder_access(folder_id), 0)) AND (public.folder_access(folder_id) >= 2)) OR ((public.share_rank(role) <= COALESCE(public.document_access(document_id), 0)) AND (public.document_access(document_id) >= 2)))));


--
-- Name: shares partages: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "partages: lecture" ON public.shares FOR SELECT TO authenticated USING (((profile_id = auth.uid()) OR ((unit_id IS NOT NULL) AND public.in_unit(unit_id)) OR (public.folder_access(folder_id) >= 2) OR (public.document_access(document_id) >= 2)));


--
-- Name: shares partages: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "partages: modification" ON public.shares FOR UPDATE TO authenticated USING (((public.folder_access(folder_id) = 3) OR (public.document_access(document_id) = 3))) WITH CHECK (((public.folder_access(folder_id) = 3) OR (public.document_access(document_id) = 3)));


--
-- Name: shares partages: retrait; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "partages: retrait" ON public.shares FOR DELETE TO authenticated USING (((created_by = auth.uid()) OR (public.folder_access(folder_id) = 3) OR (public.document_access(document_id) = 3)));


--
-- Name: meeting_attendees participants: invitation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "participants: invitation" ON public.meeting_attendees FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.meetings m
  WHERE ((m.id = meeting_attendees.meeting_id) AND (m.organizer_id = auth.uid())))));


--
-- Name: meeting_attendees participants: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "participants: lecture" ON public.meeting_attendees FOR SELECT TO authenticated USING (((profile_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.meetings m
  WHERE (m.id = meeting_attendees.meeting_id)))));


--
-- Name: meeting_attendees participants: retrait; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "participants: retrait" ON public.meeting_attendees FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.meetings m
  WHERE ((m.id = meeting_attendees.meeting_id) AND (m.organizer_id = auth.uid())))));


--
-- Name: meeting_attendees participants: réponse; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "participants: réponse" ON public.meeting_attendees FOR UPDATE TO authenticated USING ((profile_id = auth.uid())) WITH CHECK ((profile_id = auth.uid()));


--
-- Name: permissions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;

--
-- Name: permissions permissions: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "permissions: lecture" ON public.permissions FOR SELECT TO authenticated USING (public.is_active_user());


--
-- Name: product_metrics; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.product_metrics ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles profiles: annuaire; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "profiles: annuaire" ON public.profiles FOR SELECT TO authenticated USING (public.is_active_user());


--
-- Name: profiles profiles: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "profiles: modification" ON public.profiles FOR UPDATE TO authenticated USING (((id = auth.uid()) OR public.has_perm('users.admin'::text) OR public.manages_profile(id))) WITH CHECK (((id = auth.uid()) OR public.has_perm('users.admin'::text) OR public.manages_profile(id)));


--
-- Name: project_liaisons; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.project_liaisons ENABLE ROW LEVEL SECURITY;

--
-- Name: project_members; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.project_members ENABLE ROW LEVEL SECURITY;

--
-- Name: projects; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;

--
-- Name: projects projets: création; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "projets: création" ON public.projects FOR INSERT TO authenticated WITH CHECK ((public.is_active_user() AND (owner_id = auth.uid()) AND ((unit_id IS NULL) OR public.in_unit(unit_id) OR public.has_perm('unit.assign'::text, unit_id) OR public.has_perm('projects.admin'::text))));


--
-- Name: projects projets: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "projets: lecture" ON public.projects FOR SELECT TO authenticated USING (((owner_id = auth.uid()) OR (public.project_role(id) IS NOT NULL) OR public.in_unit(unit_id) OR public.has_perm('projects.admin'::text) OR public.has_perm('unit.manage'::text, unit_id) OR public.has_perm('dashboard.exec'::text)));


--
-- Name: projects projets: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "projets: modification" ON public.projects FOR UPDATE TO authenticated USING (public.can_manage_project(id)) WITH CHECK (public.can_manage_project(id));


--
-- Name: projects projets: suppression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "projets: suppression" ON public.projects FOR DELETE TO authenticated USING ((public.has_perm('projects.admin'::text) OR (owner_id = auth.uid())));


--
-- Name: notification_preferences préférences: les miennes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "préférences: les miennes" ON public.notification_preferences TO authenticated USING ((profile_id = auth.uid())) WITH CHECK ((profile_id = auth.uid()));


--
-- Name: push_subscriptions push: mes appareils; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "push: mes appareils" ON public.push_subscriptions TO authenticated USING ((profile_id = auth.uid())) WITH CHECK ((profile_id = auth.uid()));


--
-- Name: push_subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: operation_reports rapports: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "rapports: lecture" ON public.operation_reports FOR SELECT TO authenticated USING ((public.can_view_project(project_id) OR public.has_perm('ops.review'::text) OR public.has_perm('ops.plan'::text) OR public.has_perm('dashboard.exec'::text)));


--
-- Name: role_grants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.role_grants ENABLE ROW LEVEL SECURITY;

--
-- Name: role_templates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.role_templates ENABLE ROW LEVEL SECURITY;

--
-- Name: message_reactions réactions: ajout; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "réactions: ajout" ON public.message_reactions FOR INSERT TO authenticated WITH CHECK (((profile_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM public.messages m
  WHERE ((m.id = message_reactions.message_id) AND public.can_access_channel(m.channel_id))))));


--
-- Name: message_reactions réactions: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "réactions: lecture" ON public.message_reactions FOR SELECT TO authenticated USING (public.can_access_channel(channel_id));


--
-- Name: message_reactions réactions: retrait; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "réactions: retrait" ON public.message_reactions FOR DELETE TO authenticated USING ((profile_id = auth.uid()));


--
-- Name: document_recents récents: les miens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "récents: les miens" ON public.document_recents TO authenticated USING ((profile_id = auth.uid())) WITH CHECK (((profile_id = auth.uid()) AND (public.document_access(document_id) >= 1)));


--
-- Name: project_liaisons référents: désignation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "référents: désignation" ON public.project_liaisons TO authenticated USING ((public.has_perm('org.manage'::text) OR public.has_perm('unit.manage'::text, unit_id))) WITH CHECK ((public.has_perm('org.manage'::text) OR public.has_perm('unit.manage'::text, unit_id)));


--
-- Name: project_liaisons référents: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "référents: lecture" ON public.project_liaisons FOR SELECT TO authenticated USING ((public.is_active_user() AND (public.can_view_project(project_id) OR public.can_view_unit(unit_id))));


--
-- Name: key_results résultats clés: gestion; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "résultats clés: gestion" ON public.key_results TO authenticated USING (public.can_edit_objective(objective_id)) WITH CHECK (public.can_edit_objective(objective_id));


--
-- Name: key_results résultats clés: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "résultats clés: lecture" ON public.key_results FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.objectives o
  WHERE (o.id = key_results.objective_id))));


--
-- Name: meetings réunions: création; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "réunions: création" ON public.meetings FOR INSERT TO authenticated WITH CHECK ((public.is_active_user() AND (organizer_id = auth.uid())));


--
-- Name: meetings réunions: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "réunions: lecture" ON public.meetings FOR SELECT TO authenticated USING (((organizer_id = auth.uid()) OR public.is_meeting_participant(id) OR ((unit_id IS NOT NULL) AND public.in_unit(unit_id)) OR ((project_id IS NOT NULL) AND public.can_view_project(project_id))));


--
-- Name: meetings réunions: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "réunions: modification" ON public.meetings FOR UPDATE TO authenticated USING (((organizer_id = auth.uid()) OR public.is_admin())) WITH CHECK (((organizer_id = auth.uid()) OR public.is_admin()));


--
-- Name: meetings réunions: suppression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "réunions: suppression" ON public.meetings FOR DELETE TO authenticated USING (((organizer_id = auth.uid()) OR public.is_admin()));


--
-- Name: salaries salaires: gestion; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "salaires: gestion" ON public.salaries TO authenticated USING ((public.has_perm('hr.admin'::text) OR public.has_perm('finance.admin'::text))) WITH CHECK ((public.has_perm('hr.admin'::text) OR public.has_perm('finance.admin'::text)));


--
-- Name: salaries salaires: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "salaires: lecture" ON public.salaries FOR SELECT TO authenticated USING (((profile_id = auth.uid()) OR public.has_perm('hr.admin'::text) OR public.has_perm('finance.admin'::text)));


--
-- Name: salaries; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.salaries ENABLE ROW LEVEL SECURITY;

--
-- Name: company_settings settings: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "settings: lecture" ON public.company_settings FOR SELECT TO authenticated USING (public.is_active_user());


--
-- Name: company_settings settings: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "settings: modification" ON public.company_settings FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: shares; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.shares ENABLE ROW LEVEL SECURITY;

--
-- Name: task_comments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.task_comments ENABLE ROW LEVEL SECURITY;

--
-- Name: task_dependencies; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.task_dependencies ENABLE ROW LEVEL SECURITY;

--
-- Name: tasks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

--
-- Name: role_templates templates: gestion; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "templates: gestion" ON public.role_templates TO authenticated USING ((public.is_ceo() AND public.mfa_ok())) WITH CHECK ((public.is_ceo() AND public.mfa_ok()));


--
-- Name: role_templates templates: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "templates: lecture" ON public.role_templates FOR SELECT TO authenticated USING (public.is_active_user());


--
-- Name: transactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: transactions transactions: correction; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "transactions: correction" ON public.transactions FOR UPDATE TO authenticated USING (public.has_perm('finance.admin'::text)) WITH CHECK (public.has_perm('finance.admin'::text));


--
-- Name: transactions transactions: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "transactions: lecture" ON public.transactions FOR SELECT TO authenticated USING ((public.can_read_finance() OR public.has_perm('unit.manage'::text, unit_id)));


--
-- Name: transactions transactions: saisie; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "transactions: saisie" ON public.transactions FOR INSERT TO authenticated WITH CHECK ((public.has_perm('finance.admin'::text) AND (reverses_id IS NULL)));


--
-- Name: tasks tâches: création; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "tâches: création" ON public.tasks FOR INSERT TO authenticated WITH CHECK ((public.is_active_user() AND (reporter_id = auth.uid()) AND ((project_id IS NULL) OR public.can_contribute_project(project_id))));


--
-- Name: tasks tâches: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "tâches: lecture" ON public.tasks FOR SELECT TO authenticated USING (((assignee_id = auth.uid()) OR (reporter_id = auth.uid()) OR ((project_id IS NOT NULL) AND public.can_view_project(project_id))));


--
-- Name: tasks tâches: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "tâches: modification" ON public.tasks FOR UPDATE TO authenticated USING (((assignee_id = auth.uid()) OR (reporter_id = auth.uid()) OR ((project_id IS NOT NULL) AND public.can_contribute_project(project_id)))) WITH CHECK (((project_id IS NULL) OR public.can_contribute_project(project_id) OR (assignee_id = auth.uid()) OR (reporter_id = auth.uid())));


--
-- Name: tasks tâches: suppression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "tâches: suppression" ON public.tasks FOR DELETE TO authenticated USING (((reporter_id = auth.uid()) OR ((project_id IS NOT NULL) AND public.can_manage_project(project_id))));


--
-- Name: unit_domains; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.unit_domains ENABLE ROW LEVEL SECURITY;

--
-- Name: unit_memberships; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.unit_memberships ENABLE ROW LEVEL SECURITY;

--
-- Name: org_units units: création; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "units: création" ON public.org_units FOR INSERT TO authenticated WITH CHECK ((public.has_perm('org.manage'::text) OR ((parent_id IS NOT NULL) AND public.has_perm('unit.manage'::text, parent_id))));


--
-- Name: org_units units: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "units: lecture" ON public.org_units FOR SELECT TO authenticated USING (public.is_active_user());


--
-- Name: org_units units: modification; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "units: modification" ON public.org_units FOR UPDATE TO authenticated USING ((public.has_perm('org.manage'::text) OR public.has_perm('unit.manage'::text, id))) WITH CHECK ((public.has_perm('org.manage'::text) OR public.has_perm('unit.manage'::text, id)));


--
-- Name: org_units units: suppression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "units: suppression" ON public.org_units FOR DELETE TO authenticated USING (public.has_perm('org.manage'::text));


--
-- Name: approval_requests validations: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "validations: lecture" ON public.approval_requests FOR SELECT TO authenticated USING ((public.is_active_user() AND ((requested_by = auth.uid()) OR public.can_decide_approvals() OR public.has_perm('dashboard.exec'::text) OR ((unit_id IS NOT NULL) AND public.has_perm('unit.manage'::text, unit_id)) OR ((project_id IS NOT NULL) AND public.can_view_project(project_id)))));


--
-- Name: document_versions versions: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "versions: lecture" ON public.document_versions FOR SELECT TO authenticated USING ((public.document_access(document_id) >= 1));


--
-- Name: document_ydocs ydoc: lecture; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "ydoc: lecture" ON public.document_ydocs FOR SELECT TO authenticated USING ((public.document_access(document_id) >= 1));


--
-- PostgreSQL database dump complete
--


