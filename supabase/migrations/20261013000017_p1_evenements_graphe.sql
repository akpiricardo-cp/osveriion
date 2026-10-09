-- =============================================================================
-- VERIION OS — Migration 17 : journal d'événements métier et graphe d'objets
-- (phase 1, lots P1-02 et P1-03)
-- =============================================================================
-- Principe : aucune opération n'est isolée de son contexte.
--   * domain_events  : les faits métier, immuables (« contrat signé »,
--                      « nomination prononcée », « facture encaissée »…) ;
--                      des abonnements y déclenchent des effets (notifications,
--                      génération de documents) traités de manière asynchrone ;
--   * object_links   : les liens typés entre objets (une dépense → son budget,
--                      son projet, son accord ; un contrat → son projet, son
--                      document…), alimentés automatiquement et à la main ;
--   * object_context : tout ce qui entoure un objet, filtré selon les droits.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Types d'objets reconnus
-- -----------------------------------------------------------------------------
create or replace function public.object_type_valid(p_type text)
returns boolean language sql immutable as $$
  select p_type in ('person', 'unit', 'entity', 'project', 'task', 'contract', 'employment_contract', 'budget',
                    'transaction', 'invoice', 'document', 'decision', 'meeting', 'account', 'operation_cycle', 'act')
$$;

-- -----------------------------------------------------------------------------
-- 2. Journal d'événements métier
-- -----------------------------------------------------------------------------
create table if not exists public.domain_events (
  id            bigint generated always as identity primary key,
  occurred_at   timestamptz not null default now(),
  entity_id     uuid references public.legal_entities(id) on delete set null,
  type          text not null check (type ~ '^[a-z_]+\.[a-z_]+$'),
  subject_type  text not null check (public.object_type_valid(subject_type)),
  subject_id    uuid not null,
  actor_id      uuid references public.profiles(id) on delete set null,
  summary       text not null,
  payload       jsonb not null default '{}'::jsonb
);
create index if not exists domain_events_subject_idx on public.domain_events(subject_type, subject_id, occurred_at desc);
create index if not exists domain_events_type_idx on public.domain_events(type, occurred_at desc);

-- Immuable : ni modification ni suppression, même par le CEO.
create or replace function public.domain_events_immutable()
returns trigger language plpgsql as $$
begin
  -- Seule exception : la suppression d'un compte ou d'une entité met leurs références à vide.
  if tg_op = 'UPDATE'
     and (to_jsonb(new) - 'actor_id' - 'entity_id') = (to_jsonb(old) - 'actor_id' - 'entity_id')
     and (new.actor_id is null or new.actor_id = old.actor_id)
     and (new.entity_id is null or new.entity_id = old.entity_id) then
    return new;
  end if;
  raise exception 'Le journal des événements est immuable.' using errcode = '42501';
end $$;
drop trigger if exists domain_events_immutable_bud on public.domain_events;
create trigger domain_events_immutable_bud before update or delete on public.domain_events
  for each row execute function public.domain_events_immutable();

-- Abonnements : quels événements déclenchent quels effets.
create table if not exists public.event_subscriptions (
  id          uuid primary key default gen_random_uuid(),
  event_type  text not null,                 -- type exact, ou préfixe terminé par « .* »
  handler     text not null check (handler in ('notify', 'generate_document')),
  config      jsonb not null default '{}'::jsonb,
  active      boolean not null default true,
  description text,
  created_by  uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at  timestamptz not null default now()
);

create table if not exists public.event_jobs (
  id              bigint generated always as identity primary key,
  event_id        bigint not null references public.domain_events(id) on delete cascade,
  subscription_id uuid not null references public.event_subscriptions(id) on delete cascade,
  handler         text not null,
  status          text not null default 'pending' check (status in ('pending', 'running', 'done', 'failed')),
  attempts        int not null default 0,
  last_error      text,
  created_at      timestamptz not null default now(),
  done_at         timestamptz,
  unique (event_id, subscription_id)
);
create index if not exists event_jobs_pending_idx on public.event_jobs(handler, created_at) where status in ('pending', 'running');

create or replace function public.domain_events_fanout()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.event_jobs (event_id, subscription_id, handler)
  select new.id, s.id, s.handler from public.event_subscriptions s
   where s.active and (s.event_type = new.type
          or (right(s.event_type, 2) = '.*' and new.type like left(s.event_type, -1) || '%'))
  on conflict do nothing;
  return null;
end $$;
drop trigger if exists domain_events_fanout_ai on public.domain_events;
create trigger domain_events_fanout_ai after insert on public.domain_events
  for each row execute function public.domain_events_fanout();

/** Inscrit un fait métier. Interne : appelée par les triggers et fonctions métier. */
create or replace function public.emit_event(
  p_type text, p_subject_type text, p_subject_id uuid, p_summary text,
  p_payload jsonb default '{}'::jsonb, p_entity uuid default null
) returns bigint language plpgsql security definer set search_path = public as $$
declare v_id bigint;
begin
  if p_subject_id is null then return null; end if;
  insert into public.domain_events (type, subject_type, subject_id, actor_id, summary, payload, entity_id)
  values (p_type, p_subject_type, p_subject_id,
          (select id from public.profiles where id = auth.uid()),
          p_summary, coalesce(p_payload, '{}'::jsonb), coalesce(p_entity, public.holding_entity_id()))
  returning id into v_id;
  return v_id;
end $$;
revoke execute on function public.emit_event(text, text, uuid, text, jsonb, uuid) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 3. Graphe d'objets
-- -----------------------------------------------------------------------------
create table if not exists public.object_links (
  id           uuid primary key default gen_random_uuid(),
  source_type  text not null check (public.object_type_valid(source_type)),
  source_id    uuid not null,
  relation     text not null check (relation ~ '^[a-z_]+$'),
  target_type  text not null check (public.object_type_valid(target_type)),
  target_id    uuid not null,
  origin       text not null default 'auto' check (origin in ('auto', 'manual')),
  note         text,
  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  unique (source_type, source_id, relation, target_type, target_id),
  check (not (source_type = target_type and source_id = target_id))
);
create index if not exists object_links_source_idx on public.object_links(source_type, source_id);
create index if not exists object_links_target_idx on public.object_links(target_type, target_id);

create or replace function public.link_object(
  p_source_type text, p_source_id uuid, p_relation text, p_target_type text, p_target_id uuid,
  p_origin text default 'auto', p_note text default null
) returns void language plpgsql security definer set search_path = public as $$
begin
  if p_source_id is null or p_target_id is null then return; end if;
  insert into public.object_links (source_type, source_id, relation, target_type, target_id, origin, note, created_by)
  values (p_source_type, p_source_id, p_relation, p_target_type, p_target_id, p_origin, p_note,
          (select id from public.profiles where id = auth.uid()))
  on conflict do nothing;
end $$;
revoke execute on function public.link_object(text, uuid, text, text, uuid, text, text) from public, anon, authenticated;

/** Retire les liens automatiques d'un objet pour une relation (avant de les reposer). */
create or replace function public.unlink_auto(p_source_type text, p_source_id uuid, p_relation text)
returns void language sql security definer set search_path = public as $$
  delete from public.object_links
   where source_type = p_source_type and source_id = p_source_id and relation = p_relation and origin = 'auto'
$$;
revoke execute on function public.unlink_auto(text, uuid, text) from public, anon, authenticated;

/** L'utilisateur courant peut-il voir cet objet ? Les règles sont celles de chaque module. */
create or replace function public.object_can_read(p_type text, p_id uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare v_entity uuid; v_unit uuid; v_project uuid;
begin
  if p_id is null or not public.is_active_user() then return false; end if;
  case p_type
    when 'person', 'unit', 'entity' then return true;
    when 'project' then return public.can_view_project(p_id);
    when 'operation_cycle' then
      select project_id into v_project from public.operation_cycles where id = p_id;
      return v_project is not null and (public.can_view_project(v_project) or public.has_perm('ops.plan') or public.has_perm('ops.review'));
    when 'task' then return public.can_view_task(p_id);
    when 'document' then return public.document_access(p_id) >= 1;
    when 'account' then return public.can_read_crm() or exists (select 1 from public.accounts where id = p_id and owner_id = auth.uid());
    when 'meeting' then
      return exists (select 1 from public.meetings m where m.id = p_id and (
        m.organizer_id = auth.uid() or public.is_meeting_participant(m.id)
        or (m.unit_id is not null and public.in_unit(m.unit_id))
        or (m.project_id is not null and public.can_view_project(m.project_id))));
    when 'contract' then
      return exists (select 1 from public.legal_contracts c where c.id = p_id and (
        public.has_perm_entity('legal.view', c.entity_id) or public.has_perm_entity('legal.admin', c.entity_id)
        or public.has_perm('dashboard.exec') or c.owner_id = auth.uid()
        or (c.project_id is not null and public.is_project_lead(c.project_id))));
    when 'employment_contract' then
      return exists (select 1 from public.employment_contracts c where c.id = p_id and (
        c.profile_id = auth.uid() or public.has_perm_entity('hr.view', c.entity_id) or public.has_perm_entity('hr.admin', c.entity_id)));
    when 'budget' then
      select entity_id, unit_id, project_id into v_entity, v_unit, v_project from public.budgets where id = p_id;
      return public.can_read_finance_entity(v_entity) or public.has_perm('unit.manage', v_unit)
          or (v_project is not null and public.can_view_project(v_project));
    when 'transaction' then
      select entity_id, unit_id into v_entity, v_unit from public.transactions where id = p_id;
      return v_entity is not null and (public.can_read_finance_entity(v_entity) or public.has_perm('unit.manage', v_unit));
    when 'invoice' then
      select entity_id into v_entity from public.invoices where id = p_id;
      return v_entity is not null and public.can_read_finance_entity(v_entity);
    when 'decision' then
      return exists (select 1 from public.approval_requests a where a.id = p_id and (
        a.requested_by = auth.uid() or public.can_decide_approvals() or public.has_perm('dashboard.exec')
        or (a.unit_id is not null and public.has_perm('unit.manage', a.unit_id))
        or (a.project_id is not null and public.can_view_project(a.project_id))));
    when 'act' then
      return exists (select 1 from public.acts_register a where a.id = p_id);
    else return false;
  end case;
exception when undefined_table then
  return false;
end $$;
grant execute on function public.object_can_read(text, uuid) to authenticated;

/** Libellé lisible et lien d'un objet (pour la fiche 360° et la chronologie). */
create or replace function public.object_label(p_type text, p_id uuid, out label text, out url text)
language plpgsql stable security definer set search_path = public as $$
begin
  case p_type
    when 'person'   then select full_name, '/annuaire/' || id into label, url from public.profiles where id = p_id;
    when 'unit'     then select name, '/organisation/' || id into label, url from public.org_units where id = p_id;
    when 'entity'   then select name, '/admin?onglet=entites' into label, url from public.legal_entities where id = p_id;
    when 'project'  then select code || ' — ' || name, '/projets/' || id into label, url from public.projects where id = p_id;
    when 'operation_cycle' then select title, '/projets/' || project_id || '?cycle=' || id into label, url from public.operation_cycles where id = p_id;
    when 'task'     then select title, case when project_id is not null then '/projets/' || project_id || '?tache=' || id else '/taches' end into label, url from public.tasks where id = p_id;
    when 'contract' then select reference || ' — ' || title, '/juridique/' || id into label, url from public.legal_contracts where id = p_id;
    when 'employment_contract' then
      select 'Contrat de travail — ' || coalesce(p.full_name, '?'), '/annuaire/' || c.profile_id into label, url
        from public.employment_contracts c left join public.profiles p on p.id = c.profile_id where c.id = p_id;
    when 'budget'   then
      select 'Budget ' || b.fiscal_year || ' — ' || coalesce(u.name, pr.name, ''), '/finance?onglet=budgets&annee=' || b.fiscal_year into label, url
        from public.budgets b left join public.org_units u on u.id = b.unit_id left join public.projects pr on pr.id = b.project_id where b.id = p_id;
    when 'transaction' then
      select (case when type = 'revenue' then 'Revenu' else 'Dépense' end) || ' — ' || coalesce(description, category)
             || ' (' || to_char(amount, 'FM999G999G999G990') || ' ' || currency || ')',
             '/finance?onglet=operations&annee=' || extract(year from occurred_on) into label, url from public.transactions where id = p_id;
    when 'invoice'  then select 'Facture ' || number, '/finance/factures/' || id into label, url from public.invoices where id = p_id;
    when 'document' then select title, '/documents/d/' || id into label, url from public.documents where id = p_id;
    when 'decision' then select 'Décision — ' || subject_label, '/validations?demande=' || id into label, url from public.approval_requests where id = p_id;
    when 'meeting'  then select title, '/reunions?reunion=' || id into label, url from public.meetings where id = p_id;
    when 'account'  then select name, '/crm/comptes/' || id into label, url from public.accounts where id = p_id;
    when 'act'      then
      begin
        execute 'select reference || '' — '' || title, ''/admin?onglet=actes'' from public.acts_register where id = $1' into label, url using p_id;
      exception when undefined_table then label := null;
      end;
    else label := null;
  end case;
end $$;
grant execute on function public.object_label(text, uuid) to authenticated;

/** Tout ce qui entoure un objet, dans les deux sens, limité à ce que l'utilisateur peut voir. */
create or replace function public.object_context(p_type text, p_id uuid)
returns table (link_id uuid, relation text, direction text, other_type text, other_id uuid,
               label text, url text, origin text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select l.link_id, l.relation, l.direction, l.other_type, l.other_id, ol.label, ol.url, l.origin, l.created_at
  from (
    select id as link_id, relation, 'out'::text as direction, target_type as other_type, target_id as other_id, origin, created_at
      from public.object_links where source_type = p_type and source_id = p_id
    union all
    select id, relation, 'in', source_type, source_id, origin, created_at
      from public.object_links where target_type = p_type and target_id = p_id
  ) l
  cross join lateral public.object_label(l.other_type, l.other_id) ol
  where public.object_can_read(p_type, p_id)
    and public.object_can_read(l.other_type, l.other_id)
    and ol.label is not null
  order by l.created_at desc
$$;
grant execute on function public.object_context(text, uuid) to authenticated;

/** Un événement est-il visible ? Les changements de statut d'un compte restent réservés. */
create or replace function public.event_visible(p_type text, p_subject_type text, p_subject_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.object_can_read(p_subject_type, p_subject_id)
     and (p_subject_type <> 'person' or p_type not like 'employee.%' or p_subject_id = auth.uid()
          or public.is_admin() or public.has_perm('hr.view') or public.has_perm('hr.admin'))
$$;
grant execute on function public.event_visible(text, text, uuid) to authenticated;

/** Chronologie d'un objet : ses événements et ceux des objets qui lui sont liés directement. */
create or replace function public.object_timeline(p_type text, p_id uuid, p_limit int default 50)
returns table (id bigint, occurred_at timestamptz, type text, subject_type text, subject_id uuid,
               summary text, actor_id uuid, actor_name text)
language sql stable security definer set search_path = public as $$
  select e.id, e.occurred_at, e.type, e.subject_type, e.subject_id, e.summary, e.actor_id, p.full_name
  from public.domain_events e
  left join public.profiles p on p.id = e.actor_id
  where public.object_can_read(p_type, p_id)
    and ((e.subject_type = p_type and e.subject_id = p_id)
      or exists (select 1 from public.object_links l
                  where (l.source_type = p_type and l.source_id = p_id and l.target_type = e.subject_type and l.target_id = e.subject_id)
                     or (l.target_type = p_type and l.target_id = p_id and l.source_type = e.subject_type and l.source_id = e.subject_id)))
    and public.event_visible(e.type, e.subject_type, e.subject_id)
  order by e.occurred_at desc
  limit least(coalesce(p_limit, 50), 200)
$$;
grant execute on function public.object_timeline(text, uuid, int) to authenticated;

/** Lien posé à la main : il faut voir les deux objets. */
create or replace function public.link_objects(p_source_type text, p_source_id uuid, p_relation text,
  p_target_type text, p_target_id uuid, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (public.object_type_valid(p_source_type) and public.object_type_valid(p_target_type)) then
    raise exception 'Type d''objet inconnu';
  end if;
  if not (public.object_can_read(p_source_type, p_source_id) and public.object_can_read(p_target_type, p_target_id)) then
    raise exception 'Vous devez avoir accès aux deux éléments pour les relier' using errcode = '42501';
  end if;
  perform public.link_object(p_source_type, p_source_id, coalesce(nullif(trim(p_relation), ''), 'concerne'),
                             p_target_type, p_target_id, 'manual', nullif(trim(coalesce(p_note, '')), ''));
  perform public.emit_event('link.created', p_source_type, p_source_id,
    'Lien ajouté : ' || coalesce((public.object_label(p_target_type, p_target_id)).label, p_target_type));
end $$;
grant execute on function public.link_objects(text, uuid, text, text, uuid, text) to authenticated;

create or replace function public.unlink_objects(p_link uuid)
returns void language plpgsql security definer set search_path = public as $$
declare l public.object_links;
begin
  select * into l from public.object_links where id = p_link;
  if l.id is null then raise exception 'Lien introuvable'; end if;
  if l.origin <> 'manual' then raise exception 'Ce lien découle des données : il disparaîtra avec elles.'; end if;
  if not (l.created_by = auth.uid() or public.is_admin()) then
    raise exception 'Seul l''auteur du lien peut le retirer' using errcode = '42501';
  end if;
  delete from public.object_links where id = p_link;
end $$;
grant execute on function public.unlink_objects(uuid) to authenticated;

alter table public.domain_events enable row level security;
alter table public.event_subscriptions enable row level security;
alter table public.event_jobs enable row level security;
alter table public.object_links enable row level security;
revoke all on public.domain_events, public.event_subscriptions, public.event_jobs, public.object_links from anon;
revoke insert, update, delete on public.domain_events, public.event_jobs, public.object_links from authenticated;
grant select on public.domain_events, public.object_links to authenticated;
grant select, insert, update, delete on public.event_subscriptions to authenticated;

drop policy if exists "événements: lecture" on public.domain_events;
create policy "événements: lecture" on public.domain_events for select to authenticated
  using (public.event_visible(type, subject_type, subject_id));
drop policy if exists "liens: lecture" on public.object_links;
create policy "liens: lecture" on public.object_links for select to authenticated
  using (public.object_can_read(source_type, source_id) and public.object_can_read(target_type, target_id));
drop policy if exists "abonnements: lecture" on public.event_subscriptions;
create policy "abonnements: lecture" on public.event_subscriptions for select to authenticated using (public.is_admin());
drop policy if exists "abonnements: gestion" on public.event_subscriptions;
create policy "abonnements: gestion" on public.event_subscriptions for all to authenticated
  using (public.is_ceo() and public.mfa_ok()) with check (public.is_ceo() and public.mfa_ok());

-- -----------------------------------------------------------------------------
-- 4. Liens automatiques et événements émis par les modules
-- -----------------------------------------------------------------------------
create or replace function public.graph_transactions()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.link_object('transaction', new.id, 'project', 'project', new.project_id);
    perform public.link_object('transaction', new.id, 'unit', 'unit', new.unit_id);
    perform public.link_object('transaction', new.id, 'account', 'account', new.account_id);
    perform public.link_object('transaction', new.id, 'invoice', 'invoice', new.invoice_id);
    perform public.link_object('transaction', new.id, 'approval', 'decision', new.approval_id);
    perform public.link_object('transaction', new.id, 'reverses', 'transaction', new.reverses_id);
    perform public.link_object('transaction', new.id, 'budget', 'budget',
      (select b.id from public.budgets b where b.status = 'active' and b.fiscal_year = extract(year from new.occurred_on)
         and ((new.project_id is not null and b.project_id = new.project_id) or (b.unit_id = new.unit_id)) order by b.project_id nulls last limit 1));
    perform public.emit_event(case when new.reverses_id is not null then 'transaction.reversed' else 'transaction.recorded' end,
      'transaction', new.id,
      case when new.reverses_id is not null then 'Contre-passation : ' else (case when new.type = 'revenue' then 'Revenu : ' else 'Dépense : ' end) end
        || coalesce(new.description, new.category) || ' (' || to_char(abs(new.amount), 'FM999G999G999G990') || ' ' || new.currency || ')',
      jsonb_build_object('amount', new.amount, 'currency', new.currency, 'type', new.type), new.entity_id);
  end if;
  return null;
end $$;
drop trigger if exists graph_transactions_ai on public.transactions;
create trigger graph_transactions_ai after insert on public.transactions
  for each row execute function public.graph_transactions();

create or replace function public.graph_invoices()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' or new.account_id is distinct from old.account_id then
    perform public.unlink_auto('invoice', new.id, 'account');
    perform public.link_object('invoice', new.id, 'account', 'account', new.account_id);
  end if;
  if tg_op = 'INSERT' then
    perform public.link_object('invoice', new.id, 'unit', 'unit', new.unit_id);
    perform public.link_object('invoice', new.id, 'project', 'project',
      (select project_id from public.opportunities where id = new.opportunity_id));
  end if;
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    perform public.emit_event('invoice.' || new.status::text, 'invoice', new.id,
      'Facture ' || new.number || ' : ' || case new.status when 'sent' then 'émise' when 'paid' then 'encaissée'
        when 'overdue' then 'en retard' when 'cancelled' then 'annulée' else 'brouillon' end,
      jsonb_build_object('total', new.total, 'currency', new.currency), new.entity_id);
  end if;
  return null;
end $$;
drop trigger if exists graph_invoices_aiu on public.invoices;
create trigger graph_invoices_aiu after insert or update on public.invoices
  for each row execute function public.graph_invoices();

create or replace function public.graph_budgets()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.link_object('budget', new.id, 'unit', 'unit', new.unit_id);
    perform public.link_object('budget', new.id, 'project', 'project', new.project_id);
  end if;
  if tg_op = 'UPDATE' and new.status = 'active' and old.status <> 'active' then
    perform public.emit_event('budget.activated', 'budget', new.id,
      'Budget ' || new.fiscal_year || ' activé (' || to_char(new.amount, 'FM999G999G999G990') || ' ' || new.currency || ')',
      jsonb_build_object('amount', new.amount), new.entity_id);
  end if;
  return null;
end $$;
drop trigger if exists graph_budgets_aiu on public.budgets;
create trigger graph_budgets_aiu after insert or update on public.budgets
  for each row execute function public.graph_budgets();

create or replace function public.graph_legal_contracts()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' or new.project_id is distinct from old.project_id then
    perform public.unlink_auto('contract', new.id, 'project');
    perform public.link_object('contract', new.id, 'project', 'project', new.project_id);
  end if;
  if tg_op = 'INSERT' or new.account_id is distinct from old.account_id then
    perform public.unlink_auto('contract', new.id, 'account');
    perform public.link_object('contract', new.id, 'account', 'account', new.account_id);
  end if;
  if tg_op = 'INSERT' or new.document_id is distinct from old.document_id then
    perform public.unlink_auto('contract', new.id, 'document');
    perform public.link_object('contract', new.id, 'document', 'document', new.document_id);
  end if;
  if tg_op = 'INSERT' or new.unit_id is distinct from old.unit_id then
    perform public.unlink_auto('contract', new.id, 'unit');
    perform public.link_object('contract', new.id, 'unit', 'unit', new.unit_id);
  end if;
  if tg_op = 'INSERT' then
    perform public.link_object('contract', new.id, 'owner', 'person', new.owner_id);
    perform public.emit_event('contract.drafted', 'contract', new.id, 'Contrat ' || new.reference || ' rédigé : ' || new.title, '{}'::jsonb, new.entity_id);
  elsif new.status is distinct from old.status then
    perform public.emit_event('contract.' || new.status::text, 'contract', new.id,
      'Contrat ' || new.reference || ' : ' || case new.status when 'legal_review' then 'en revue juridique'
        when 'pending_ceo' then 'soumis au CEO' when 'signed' then 'signé' when 'active' then 'en vigueur'
        when 'expired' then 'échu' when 'terminated' then 'résilié' else 'en rédaction' end,
      jsonb_build_object('from', old.status, 'to', new.status), new.entity_id);
  elsif new.end_date is distinct from old.end_date and old.status in ('active', 'signed') then
    perform public.emit_event('contract.renewed', 'contract', new.id,
      'Contrat ' || new.reference || ' prolongé jusqu''au ' || to_char(new.end_date, 'DD/MM/YYYY'), '{}'::jsonb, new.entity_id);
  end if;
  return null;
end $$;
drop trigger if exists graph_legal_contracts_aiu on public.legal_contracts;
create trigger graph_legal_contracts_aiu after insert or update on public.legal_contracts
  for each row execute function public.graph_legal_contracts();

create or replace function public.graph_employment_contracts()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.link_object('employment_contract', new.id, 'employee', 'person', new.profile_id);
    perform public.link_object('employment_contract', new.id, 'document', 'document', new.document_id);
  elsif new.status is distinct from old.status then
    perform public.emit_event('employment.' || new.status, 'employment_contract', new.id,
      'Contrat de travail ' || case new.status when 'pending_ceo' then 'soumis au CEO' when 'signed' then 'signé'
        when 'ended' then 'clos' else 'en brouillon' end || coalesce(' — ' || new.job_title, ''),
      jsonb_build_object('profile_id', new.profile_id), new.entity_id);
  end if;
  return null;
end $$;
drop trigger if exists graph_employment_contracts_aiu on public.employment_contracts;
create trigger graph_employment_contracts_aiu after insert or update on public.employment_contracts
  for each row execute function public.graph_employment_contracts();

create or replace function public.graph_approvals()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_type text;
begin
  v_type := case new.kind when 'budget' then 'budget' when 'legal_contract' then 'contract'
                          when 'employment_contract' then 'employment_contract' when 'project' then 'project'
                          when 'operation_cycle' then 'operation_cycle' else null end;
  if tg_op = 'INSERT' then
    if v_type is not null then perform public.link_object('decision', new.id, 'subject', v_type, new.subject_id); end if;
    perform public.link_object('decision', new.id, 'project', 'project', new.project_id);
    perform public.link_object('decision', new.id, 'unit', 'unit', new.unit_id);
    perform public.emit_event(case when new.status = 'approved' then 'decision.direct' else 'decision.requested' end,
      'decision', new.id, case when new.status = 'approved' then 'Décision directe : ' else 'Accord demandé : ' end || new.subject_label,
      jsonb_build_object('kind', new.kind, 'amount', new.amount), new.entity_id);
  elsif new.status is distinct from old.status then
    perform public.emit_event('decision.' || new.status::text, 'decision', new.id,
      case new.status when 'approved' then 'Accord donné : ' when 'rejected' then 'Refus : ' when 'cancelled' then 'Demande retirée : ' else '' end
        || new.subject_label,
      jsonb_build_object('kind', new.kind, 'note', new.decision_note), new.entity_id);
    -- L'événement apparaît aussi dans la chronologie du sujet.
    if v_type is not null and new.status in ('approved', 'rejected') then
      perform public.emit_event('decision.' || new.status::text, v_type, new.subject_id,
        case new.status when 'approved' then 'Accord du CEO' else 'Refus du CEO' end || coalesce(' — ' || new.decision_note, ''),
        jsonb_build_object('decision_id', new.id), new.entity_id);
    end if;
  end if;
  return null;
end $$;
drop trigger if exists graph_approvals_aiu on public.approval_requests;
create trigger graph_approvals_aiu after insert or update on public.approval_requests
  for each row execute function public.graph_approvals();

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
      jsonb_build_object('membership_id', new.id, 'unit_id', new.unit_id, 'role', new.role, 'title', new.title, 'start_date', new.start_date),
      v_entity);
    perform public.emit_event('membership.appointed', 'unit', new.unit_id,
      coalesce(v_person, '?') || ' rejoint l''unité (' || case new.role when 'head' then 'responsable' when 'deputy' then 'adjoint(e)' else 'membre' end || ')',
      jsonb_build_object('membership_id', new.id, 'profile_id', new.profile_id, 'role', new.role), v_entity);
  elsif tg_op = 'UPDATE' and new.end_date is not null and old.end_date is null then
    perform public.emit_event('membership.ended', 'person', new.profile_id,
      'Fin de fonction — ' || coalesce(v_unit, '?'), jsonb_build_object('membership_id', new.id, 'unit_id', new.unit_id, 'role', new.role), v_entity);
  end if;
  return null;
end $$;
drop trigger if exists graph_memberships_aiu on public.unit_memberships;
create trigger graph_memberships_aiu after insert or update on public.unit_memberships
  for each row execute function public.graph_memberships();

create or replace function public.graph_projects()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.link_object('project', new.id, 'unit', 'unit', new.unit_id);
    perform public.link_object('project', new.id, 'lead', 'person', new.lead_id);
    perform public.emit_event('project.created', 'project', new.id, 'Projet créé : ' || new.name, '{}'::jsonb, new.entity_id);
  else
    if new.lead_id is distinct from old.lead_id then
      perform public.unlink_auto('project', new.id, 'lead');
      perform public.link_object('project', new.id, 'lead', 'person', new.lead_id);
    end if;
    if new.status is distinct from old.status then
      perform public.emit_event('project.' || new.status::text, 'project', new.id,
        'Projet ' || new.name || ' : ' || case new.status when 'active' then 'lancé' when 'on_hold' then 'suspendu'
          when 'completed' then 'terminé' when 'cancelled' then 'annulé' else 'planifié' end, '{}'::jsonb, new.entity_id);
    end if;
  end if;
  return null;
end $$;
drop trigger if exists graph_projects_aiu on public.projects;
create trigger graph_projects_aiu after insert or update on public.projects
  for each row execute function public.graph_projects();

create or replace function public.graph_documents()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.link_object('document', new.id, 'project', 'project', new.project_id);
    perform public.link_object('document', new.id, 'account', 'account', new.account_id);
  end if;
  return null;
end $$;
drop trigger if exists graph_documents_ai on public.documents;
create trigger graph_documents_ai after insert on public.documents
  for each row execute function public.graph_documents();

create or replace function public.graph_meetings()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.link_object('meeting', new.id, 'project', 'project', new.project_id);
    perform public.link_object('meeting', new.id, 'unit', 'unit', new.unit_id);
  end if;
  return null;
end $$;
drop trigger if exists graph_meetings_ai on public.meetings;
create trigger graph_meetings_ai after insert on public.meetings
  for each row execute function public.graph_meetings();

create or replace function public.graph_tasks()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' and new.status = 'done' and old.status <> 'done' and new.validated_by is not null then
    perform public.emit_event('task.validated', 'task', new.id, 'Tâche validée : ' || new.title, '{}'::jsonb,
      (select entity_id from public.projects where id = new.project_id));
  end if;
  return null;
end $$;
drop trigger if exists graph_tasks_au on public.tasks;
create trigger graph_tasks_au after update on public.tasks
  for each row execute function public.graph_tasks();

create or replace function public.graph_cycles()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.link_object('operation_cycle', new.id, 'project', 'project', new.project_id);
  elsif new.status = 'published' and old.status <> 'published' then
    perform public.emit_event('cycle.published', 'operation_cycle', new.id, 'Calendrier publié : ' || new.title, '{}'::jsonb,
      (select entity_id from public.projects where id = new.project_id));
  end if;
  return null;
end $$;
drop trigger if exists graph_cycles_aiu on public.operation_cycles;
create trigger graph_cycles_aiu after insert or update on public.operation_cycles
  for each row execute function public.graph_cycles();

create or replace function public.graph_profiles()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status then
    perform public.emit_event('employee.' || new.status::text, 'person', new.id,
      coalesce(new.full_name, '?') || ' : ' || case new.status when 'active' then 'compte réactivé'
        when 'suspended' then 'compte suspendu' else 'départ enregistré' end, '{}'::jsonb, public.profile_entity(new.id));
  end if;
  return null;
end $$;
drop trigger if exists graph_profiles_au on public.profiles;
create trigger graph_profiles_au after update of status on public.profiles
  for each row execute function public.graph_profiles();

-- -----------------------------------------------------------------------------
-- 5. Traitement des abonnements « notify » (les documents sont traités par
--    l'application : voir /api/notifications/dispatch).
-- -----------------------------------------------------------------------------
-- config : {"to": "ceo" | "subject" | "actor" | "finance" | "hr" | "legal", "title": "…"}
create or replace function public.process_event_jobs(p_limit int default 200)
returns int language plpgsql security definer set search_path = public as $$
declare j record; e public.domain_events; s public.event_subscriptions; n int := 0; r record; v_link text;
begin
  for j in
    select * from public.event_jobs where handler = 'notify' and status = 'pending'
    order by created_at limit p_limit for update skip locked
  loop
    begin
      select * into e from public.domain_events where id = j.event_id;
      select * into s from public.event_subscriptions where id = j.subscription_id;
      v_link := (public.object_label(e.subject_type, e.subject_id)).url;
      for r in
        select p.id from public.profiles p where p.status = 'active' and (
             (s.config->>'to' = 'ceo' and p.system_role = 'ceo')
          or (s.config->>'to' = 'subject' and e.subject_type = 'person' and p.id = e.subject_id)
          or (s.config->>'to' = 'actor' and p.id = e.actor_id)
          or (s.config->>'to' in ('finance', 'hr', 'legal') and exists (
                select 1 from public.role_grants g where g.profile_id = p.id
                  and g.permission = (s.config->>'to') || '.admin' and (g.expires_at is null or g.expires_at > now())
                  and (g.scope_entity_id is null or g.scope_entity_id = e.entity_id))))
      loop
        perform public.notify(r.id, 'event.' || e.type, coalesce(s.config->>'title', e.summary), e.summary, v_link);
      end loop;
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

-- Abonnements par défaut (désactivables par le CEO).
insert into public.event_subscriptions (event_type, handler, config, description)
select * from (values
  ('contract.expired', 'notify', '{"to": "legal", "title": "Un contrat est arrivé à terme"}'::jsonb, 'Prévenir le Juridique de l''échéance d''un contrat'),
  ('employment.signed', 'notify', '{"to": "payload_profile", "title": "Votre contrat de travail est signé"}'::jsonb, 'Prévenir le collaborateur de la signature de son contrat'),
  ('transaction.reversed', 'notify', '{"to": "finance", "title": "Une opération a été contre-passée"}'::jsonb, 'Informer la finance des annulations')
) v(event_type, handler, config, description)
where not exists (select 1 from public.event_subscriptions);

do $$
begin
  perform cron.schedule('veriion-event-jobs', '* * * * *', 'select public.process_event_jobs()');
exception when others then
  raise notice 'pg_cron non disponible : abonnements traités par /api/notifications/dispatch (%)', sqlerrm;
end $$;

-- -----------------------------------------------------------------------------
-- 6. Reprise de l'existant : liens dérivés des clés étrangères
-- -----------------------------------------------------------------------------
do $$
declare r record;
begin
  for r in select * from public.transactions loop
    perform public.link_object('transaction', r.id, 'project', 'project', r.project_id);
    perform public.link_object('transaction', r.id, 'unit', 'unit', r.unit_id);
    perform public.link_object('transaction', r.id, 'account', 'account', r.account_id);
    perform public.link_object('transaction', r.id, 'invoice', 'invoice', r.invoice_id);
    perform public.link_object('transaction', r.id, 'approval', 'decision', r.approval_id);
  end loop;
  for r in select * from public.invoices loop
    perform public.link_object('invoice', r.id, 'account', 'account', r.account_id);
    perform public.link_object('invoice', r.id, 'unit', 'unit', r.unit_id);
  end loop;
  for r in select * from public.budgets loop
    perform public.link_object('budget', r.id, 'unit', 'unit', r.unit_id);
    perform public.link_object('budget', r.id, 'project', 'project', r.project_id);
  end loop;
  for r in select * from public.legal_contracts loop
    perform public.link_object('contract', r.id, 'project', 'project', r.project_id);
    perform public.link_object('contract', r.id, 'account', 'account', r.account_id);
    perform public.link_object('contract', r.id, 'document', 'document', r.document_id);
    perform public.link_object('contract', r.id, 'unit', 'unit', r.unit_id);
    perform public.link_object('contract', r.id, 'owner', 'person', r.owner_id);
  end loop;
  for r in select * from public.employment_contracts loop
    perform public.link_object('employment_contract', r.id, 'employee', 'person', r.profile_id);
  end loop;
  for r in select * from public.projects loop
    perform public.link_object('project', r.id, 'unit', 'unit', r.unit_id);
    perform public.link_object('project', r.id, 'lead', 'person', r.lead_id);
  end loop;
  for r in select * from public.documents where project_id is not null or account_id is not null loop
    perform public.link_object('document', r.id, 'project', 'project', r.project_id);
    perform public.link_object('document', r.id, 'account', 'account', r.account_id);
  end loop;
  for r in select * from public.meetings loop
    perform public.link_object('meeting', r.id, 'project', 'project', r.project_id);
    perform public.link_object('meeting', r.id, 'unit', 'unit', r.unit_id);
  end loop;
  for r in select * from public.approval_requests loop
    perform public.link_object('decision', r.id, 'project', 'project', r.project_id);
    perform public.link_object('decision', r.id, 'unit', 'unit', r.unit_id);
  end loop;
end $$;
