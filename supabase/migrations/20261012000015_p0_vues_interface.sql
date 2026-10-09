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
