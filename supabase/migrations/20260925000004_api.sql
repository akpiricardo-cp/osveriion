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
