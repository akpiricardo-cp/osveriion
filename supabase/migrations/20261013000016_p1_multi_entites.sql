-- =============================================================================
-- VERIION OS — Migration 16 : multi-entités (phase 1, lot P1-01)
-- =============================================================================
-- La holding et ses filiales sont des entités juridiques distinctes : chacune a
-- sa raison sociale, ses identifiants (RCCM, IFU), sa devise, sa TVA et ses
-- séries de numérotation. Toute donnée financière, contractuelle ou RH porte
-- son entité ; les droits peuvent être limités à une entité.
--
--   * legal_entities           : holding + filiales ;
--   * org_units.entity_id      : une filiale est une branche de l'organigramme
--                                (unité « company » sous la holding) ;
--   * entity_id                : dérivé automatiquement de l'unité, du projet ou
--                                de la personne sur budgets, opérations, factures,
--                                contrats, contrats de travail, salaires, demandes ;
--   * role_grants.scope_entity_id : un droit « global » obtenu dans une filiale
--                                ne vaut que pour cette filiale ;
--   * fx_rates                 : conversion vers la devise du groupe pour la
--                                consolidation.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Entités juridiques
-- -----------------------------------------------------------------------------
create table if not exists public.legal_entities (
  id               uuid primary key default gen_random_uuid(),
  code             text not null unique check (code ~ '^[A-Z0-9]{2,10}$'),
  name             text not null check (length(trim(name)) > 1),
  legal_name       text,
  country          text not null default 'BJ',
  rccm             text,
  ifu              text,
  address          text,
  currency         text not null default 'XOF',
  vat_rate         numeric(5,2) not null default 18,
  fiscal_year_start int not null default 1 check (fiscal_year_start between 1 and 12),
  invoice_prefix   text not null default 'FAC' check (invoice_prefix ~ '^[A-Z0-9]{2,8}$'),
  contract_prefix  text not null default 'JUR' check (contract_prefix ~ '^[A-Z0-9]{2,8}$'),
  is_holding       boolean not null default false,
  root_unit_id     uuid references public.org_units(id) on delete set null,
  archived_at      timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create unique index if not exists legal_entities_one_holding on public.legal_entities(is_holding) where is_holding;
create unique index if not exists legal_entities_invoice_prefix on public.legal_entities(invoice_prefix);
create unique index if not exists legal_entities_contract_prefix on public.legal_entities(contract_prefix);
drop trigger if exists legal_entities_updated_at on public.legal_entities;
create trigger legal_entities_updated_at before update on public.legal_entities
  for each row execute function public.set_updated_at();
drop trigger if exists audit_legal_entities on public.legal_entities;
create trigger audit_legal_entities after insert or update or delete on public.legal_entities
  for each row execute function public.audit_trigger();

-- La holding : reprise des paramètres de l'entreprise.
insert into public.legal_entities (code, name, legal_name, currency, vat_rate, is_holding, root_unit_id)
select 'HOLD', s.company_name, s.company_name, s.currency, s.default_tax_rate, true,
       (select id from public.org_units where parent_id is null order by created_at limit 1)
from public.company_settings s
where not exists (select 1 from public.legal_entities where is_holding);

create or replace function public.holding_entity_id()
returns uuid language sql stable security definer set search_path = public as $$
  select id from public.legal_entities where is_holding
$$;

alter table public.legal_entities enable row level security;
revoke all on public.legal_entities from anon;
grant select, insert, update on public.legal_entities to authenticated;
drop policy if exists "entités: lecture" on public.legal_entities;
create policy "entités: lecture" on public.legal_entities for select to authenticated using (public.is_active_user());
drop policy if exists "entités: gestion" on public.legal_entities;
create policy "entités: gestion" on public.legal_entities for update to authenticated
  using (public.is_ceo() and public.mfa_ok()) with check (public.is_ceo() and public.mfa_ok());
-- La création passe par create_entity() (crée aussi la branche d'organigramme).

-- -----------------------------------------------------------------------------
-- 2. Organigramme : chaque unité appartient à une entité
-- -----------------------------------------------------------------------------
alter table public.org_units add column if not exists entity_id uuid references public.legal_entities(id) on delete restrict;
update public.org_units set entity_id = public.holding_entity_id() where entity_id is null;

create or replace function public.org_units_compute_path()
returns trigger language plpgsql as $$
declare
  parent public.org_units;
begin
  if new.parent_id is null then
    new.path  := array[new.id];
    new.depth := 0;
    new.domain := coalesce(new.domain, 'direction');
    new.entity_id := coalesce(new.entity_id, public.holding_entity_id());
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
    -- Une filiale (unité « company » rattachée à une entité) garde son entité ;
    -- toute autre unité hérite de celle de son parent.
    if not (new.kind = 'company' and new.entity_id is not null
            and exists (select 1 from public.legal_entities e where e.id = new.entity_id and not e.is_holding)) then
      new.entity_id := parent.entity_id;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists org_units_path_bu on public.org_units;
create trigger org_units_path_bu before update of parent_id, entity_id on public.org_units
  for each row execute function public.org_units_compute_path();

create or replace function public.org_units_propagate_path()
returns trigger language plpgsql as $$
begin
  if new.path is distinct from old.path or new.entity_id is distinct from old.entity_id then
    update public.org_units set parent_id = parent_id where parent_id = new.id;
  end if;
  return null;
end $$;
drop trigger if exists org_units_path_au on public.org_units;
create trigger org_units_path_au after update of parent_id, entity_id on public.org_units
  for each row execute function public.org_units_propagate_path();

-- Entité d'une personne : celle de son unité principale (à défaut, la holding).
create or replace function public.profile_entity(p_profile uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select coalesce(
    (select u.entity_id from public.profiles p join public.org_units u on u.id = p.primary_unit_id where p.id = p_profile),
    public.holding_entity_id())
$$;

/** Crée une filiale : l'entité juridique et sa branche dans l'organigramme. */
create or replace function public.create_entity(
  p_code text, p_name text, p_legal_name text default null, p_country text default 'BJ',
  p_currency text default 'XOF', p_vat_rate numeric default 18, p_rccm text default null, p_ifu text default null,
  p_invoice_prefix text default null, p_contract_prefix text default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_unit uuid; v_root uuid; v_code text := upper(trim(p_code));
begin
  if not public.is_ceo() then raise exception 'Seul le CEO crée une filiale' using errcode = '42501'; end if;
  perform public.require_mfa();
  select id into v_root from public.org_units where parent_id is null order by created_at limit 1;
  if v_root is null then raise exception 'Organigramme de la holding introuvable'; end if;

  insert into public.legal_entities (code, name, legal_name, country, currency, vat_rate, rccm, ifu, invoice_prefix, contract_prefix)
  values (v_code, trim(p_name), nullif(trim(coalesce(p_legal_name, '')), ''), upper(coalesce(p_country, 'BJ')),
          upper(coalesce(p_currency, 'XOF')), coalesce(p_vat_rate, 18), nullif(trim(coalesce(p_rccm, '')), ''),
          nullif(trim(coalesce(p_ifu, '')), ''), upper(coalesce(nullif(trim(p_invoice_prefix), ''), 'F' || v_code)),
          upper(coalesce(nullif(trim(p_contract_prefix), ''), 'J' || v_code)))
  returning id into v_id;

  insert into public.org_units (parent_id, name, code, kind, domain, entity_id, head_title, deputy_title, description, is_core)
  values (v_root, trim(p_name), v_code, 'company', 'direction', v_id,
          'Directeur Général — ' || trim(p_name), 'Directeur Général Adjoint — ' || trim(p_name),
          'Filiale ' || coalesce(nullif(trim(coalesce(p_legal_name, '')), ''), trim(p_name)), false)
  returning id into v_unit;
  update public.legal_entities set root_unit_id = v_unit where id = v_id;
  return v_id;
end $$;
revoke execute on function public.create_entity(text, text, text, text, text, numeric, text, text, text, text) from public, anon;
grant execute on function public.create_entity(text, text, text, text, text, numeric, text, text, text, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Rattachement des données à une entité
-- -----------------------------------------------------------------------------
create or replace function public.assign_entity()
returns trigger language plpgsql security definer set search_path = public as $$
declare j jsonb := to_jsonb(new); o jsonb;
begin
  if tg_op = 'UPDATE' then
    o := to_jsonb(old);
    -- Entité changée explicitement, ou rattachements inchangés : on ne touche à rien.
    if new.entity_id is distinct from old.entity_id
       or ((j->'unit_id') is not distinct from (o->'unit_id')
           and (j->'project_id') is not distinct from (o->'project_id')
           and (j->'profile_id') is not distinct from (o->'profile_id')) then
      return new;
    end if;
  elsif new.entity_id is not null then
    return new;
  end if;
  new.entity_id := coalesce(
    (select entity_id from public.org_units where id = nullif(j->>'unit_id', '')::uuid),
    (select entity_id from public.projects where id = nullif(j->>'project_id', '')::uuid),
    case when j ? 'profile_id' and nullif(j->>'profile_id', '') is not null then public.profile_entity((j->>'profile_id')::uuid) end,
    case when tg_op = 'UPDATE' then old.entity_id end,
    public.holding_entity_id());
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['projects', 'budgets', 'transactions', 'invoices', 'legal_contracts',
                           'employment_contracts', 'salaries', 'approval_requests'] loop
    execute format('alter table public.%I add column if not exists entity_id uuid references public.legal_entities(id) on delete restrict', t);
    execute format('drop trigger if exists %I on public.%I', t || '_aa_entity', t);
    execute format('create trigger %I before insert or update on public.%I for each row execute function public.assign_entity()', t || '_aa_entity', t);
    execute format('create index if not exists %I on public.%I(entity_id)', t || '_entity_idx', t);
  end loop;
end $$;

-- Reprise de l'existant (le système, sans utilisateur, passe toutes les gardes).
update public.projects p set entity_id = coalesce((select entity_id from public.org_units where id = p.unit_id), public.holding_entity_id()) where entity_id is null;
update public.budgets b set entity_id = coalesce((select entity_id from public.org_units where id = b.unit_id),
  (select entity_id from public.projects where id = b.project_id), public.holding_entity_id()) where entity_id is null;
update public.transactions t set entity_id = coalesce((select entity_id from public.org_units where id = t.unit_id),
  (select entity_id from public.projects where id = t.project_id), public.holding_entity_id()) where entity_id is null;
update public.invoices i set entity_id = coalesce((select entity_id from public.org_units where id = i.unit_id), public.holding_entity_id()) where entity_id is null;
update public.legal_contracts c set entity_id = coalesce((select entity_id from public.org_units where id = c.unit_id),
  (select entity_id from public.projects where id = c.project_id), public.holding_entity_id()) where entity_id is null;
update public.employment_contracts c set entity_id = public.profile_entity(c.profile_id) where entity_id is null;
update public.salaries s set entity_id = public.profile_entity(s.profile_id) where entity_id is null;
update public.approval_requests a set entity_id = coalesce((select entity_id from public.org_units where id = a.unit_id),
  (select entity_id from public.projects where id = a.project_id), public.holding_entity_id()) where entity_id is null;

-- -----------------------------------------------------------------------------
-- 4. Numérotation par entité (factures, contrats)
-- -----------------------------------------------------------------------------
create or replace function public.next_number(p_scope text, p_date date, p_width int default 5)
returns text language plpgsql security definer set search_path = public as $$
declare v_year int := extract(year from coalesce(p_date, current_date))::int; v_n int;
begin
  insert into public.invoice_counters (scope, year, last) values (p_scope, v_year, 1)
  on conflict (scope, year) do update set last = public.invoice_counters.last + 1
  returning last into v_n;
  return p_scope || '-' || v_year || '-' || lpad(v_n::text, p_width, '0');
end $$;
revoke execute on function public.next_number(text, date, int) from public, anon, authenticated;

create or replace function public.invoices_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.number is null or auth.uid() is not null then
    new.number := public.next_number(
      coalesce((select invoice_prefix from public.legal_entities where id = new.entity_id), 'FAC'), new.issue_date, 5);
  end if;
  -- Devise par défaut : celle de l'entité émettrice.
  if coalesce(new.currency, 'XOF') = 'XOF' then
    new.currency := coalesce((select currency from public.legal_entities where id = new.entity_id), 'XOF');
  end if;
  new.status := 'draft';
  new.sent_at := null; new.paid_at := null;
  return new;
end $$;

-- Contrats : la série reprend les références existantes « JUR-AAAA-NNNN ».
insert into public.invoice_counters (scope, year, last)
select 'JUR', split_part(reference, '-', 2)::int, max(split_part(reference, '-', 3)::int)
  from public.legal_contracts where reference ~ '^JUR-[0-9]{4}-[0-9]+$'
 group by split_part(reference, '-', 2)
on conflict (scope, year) do update set last = greatest(public.invoice_counters.last, excluded.last);
alter table public.legal_contracts alter column reference drop default;

create or replace function public.legal_contracts_reference()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.reference := public.next_number(
    coalesce((select contract_prefix from public.legal_entities where id = new.entity_id), 'JUR'), current_date, 4);
  return new;
end $$;
drop trigger if exists legal_contracts_ab_reference_bi on public.legal_contracts;
create trigger legal_contracts_ab_reference_bi before insert on public.legal_contracts
  for each row execute function public.legal_contracts_reference();

-- -----------------------------------------------------------------------------
-- 5. Droits limités à une entité
-- -----------------------------------------------------------------------------
alter table public.role_grants add column if not exists scope_entity_id uuid references public.legal_entities(id) on delete cascade;

create or replace function public.sync_auto_grants(p_profile uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.role_grants where profile_id = p_profile and source = 'auto';
  insert into public.role_grants (profile_id, permission, scope_unit_id, scope_entity_id, source, membership_id)
  select distinct on (t.permission, case when t.scoped then m.unit_id end,
                      case when t.scoped or coalesce(e.is_holding, true) then null else u.entity_id end)
         m.profile_id, t.permission,
         case when t.scoped then m.unit_id end,
         -- Un droit « global » acquis dans une filiale ne vaut que pour cette filiale.
         case when t.scoped or coalesce(e.is_holding, true) then null else u.entity_id end,
         'auto', m.id
  from public.unit_memberships m
  join public.org_units u       on u.id = m.unit_id and u.archived_at is null
  left join public.legal_entities e on e.id = u.entity_id
  join public.role_templates t  on (t.domain is null or t.domain = u.domain)
                               and public.membership_rank(m.role) >= public.membership_rank(t.membership_role)
                               and (t.scoped or t.membership_role = 'member' or u.kind in ('company', 'department'))
  where m.profile_id = p_profile
    and m.end_date is null
  order by t.permission, case when t.scoped then m.unit_id end,
           case when t.scoped or coalesce(e.is_holding, true) then null else u.entity_id end,
           public.membership_rank(m.role) desc;
end $$;

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
          (g.scope_unit_id is null and g.scope_entity_id is null)
          or (g.scope_unit_id is not null and p_unit is not null and exists (
                select 1 from public.org_units u where u.id = p_unit and g.scope_unit_id = any(u.path)))
          or (g.scope_unit_id is null and g.scope_entity_id is not null and p_unit is not null and exists (
                select 1 from public.org_units u where u.id = p_unit and u.entity_id = g.scope_entity_id))
        )
    )
  end
$$;

/** Permission détenue pour une entité : globale (groupe) ou limitée à cette entité. */
create or replace function public.has_perm_entity(p_perm text, p_entity uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select case
    when not public.is_active_user() then false
    when public.is_ceo() then true
    when p_perm in ('org.manage', 'users.admin', 'grants.manage', 'audit.view') and public.is_admin() then true
    else exists (
      select 1 from public.role_grants g
      where g.profile_id = auth.uid() and g.permission = p_perm
        and (g.expires_at is null or g.expires_at > now())
        and g.scope_unit_id is null
        and (g.scope_entity_id is null or g.scope_entity_id = p_entity)
    )
  end
$$;
grant execute on function public.has_perm_entity(text, uuid) to authenticated;

create or replace function public.can_read_finance_entity(p_entity uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.has_perm_entity('finance.view', p_entity) or public.has_perm_entity('finance.admin', p_entity)
      or public.has_perm('dashboard.exec')
$$;
grant execute on function public.can_read_finance_entity(uuid) to authenticated;

drop function if exists public.my_permissions();
create or replace function public.my_permissions()
returns table (permission text, scope_unit_id uuid, scope_entity_id uuid)
language sql stable security definer set search_path = public as $$
  select p.key, null::uuid, null::uuid from public.permissions p where public.is_ceo()
  union
  select p.key, null::uuid, null::uuid from public.permissions p
    where public.is_admin() and p.key in ('org.manage', 'users.admin', 'grants.manage', 'audit.view')
  union
  select g.permission, g.scope_unit_id, g.scope_entity_id from public.role_grants g
    where g.profile_id = auth.uid() and (g.expires_at is null or g.expires_at > now()) and public.is_active_user()
$$;
grant execute on function public.my_permissions() to authenticated;

-- Politiques des données financières, contractuelles et RH : par entité.
drop policy if exists "budgets: lecture" on public.budgets;
create policy "budgets: lecture" on public.budgets for select to authenticated
  using (public.can_read_finance_entity(entity_id) or public.has_perm('unit.manage', unit_id)
         or (project_id is not null and public.can_view_project(project_id)));
drop policy if exists "budgets: gestion" on public.budgets;
create policy "budgets: gestion" on public.budgets for all to authenticated
  using (public.has_perm_entity('finance.admin', entity_id)) with check (public.has_perm_entity('finance.admin', entity_id));

drop policy if exists "factures: lecture" on public.invoices;
create policy "factures: lecture" on public.invoices for select to authenticated using (public.can_read_finance_entity(entity_id));
drop policy if exists "factures: création" on public.invoices;
create policy "factures: création" on public.invoices for insert to authenticated with check (public.has_perm_entity('finance.admin', entity_id));
drop policy if exists "factures: modification" on public.invoices;
create policy "factures: modification" on public.invoices for update to authenticated
  using (public.has_perm_entity('finance.admin', entity_id)) with check (public.has_perm_entity('finance.admin', entity_id));

drop policy if exists "lignes facture: lecture" on public.invoice_lines;
create policy "lignes facture: lecture" on public.invoice_lines for select to authenticated
  using (exists (select 1 from public.invoices i where i.id = invoice_id and public.can_read_finance_entity(i.entity_id)));
drop policy if exists "lignes facture: gestion" on public.invoice_lines;
create policy "lignes facture: gestion" on public.invoice_lines for all to authenticated
  using (exists (select 1 from public.invoices i where i.id = invoice_id and public.has_perm_entity('finance.admin', i.entity_id)))
  with check (exists (select 1 from public.invoices i where i.id = invoice_id and public.has_perm_entity('finance.admin', i.entity_id)));

drop policy if exists "transactions: lecture" on public.transactions;
create policy "transactions: lecture" on public.transactions for select to authenticated
  using (public.can_read_finance_entity(entity_id) or public.has_perm('unit.manage', unit_id));
drop policy if exists "transactions: saisie" on public.transactions;
create policy "transactions: saisie" on public.transactions for insert to authenticated
  with check (public.has_perm_entity('finance.admin', entity_id) and reverses_id is null);
drop policy if exists "transactions: correction" on public.transactions;
create policy "transactions: correction" on public.transactions for update to authenticated
  using (public.has_perm_entity('finance.admin', entity_id)) with check (public.has_perm_entity('finance.admin', entity_id));

drop policy if exists "contrats: lecture" on public.legal_contracts;
create policy "contrats: lecture" on public.legal_contracts for select to authenticated
  using (public.has_perm_entity('legal.view', entity_id) or public.has_perm_entity('legal.admin', entity_id)
         or public.has_perm('dashboard.exec') or owner_id = auth.uid()
         or (project_id is not null and public.is_project_lead(project_id)));
drop policy if exists "contrats: rédaction" on public.legal_contracts;
create policy "contrats: rédaction" on public.legal_contracts for insert to authenticated
  with check (public.has_perm_entity('legal.admin', entity_id) or public.is_ceo());
drop policy if exists "contrats: modification" on public.legal_contracts;
create policy "contrats: modification" on public.legal_contracts for update to authenticated
  using (public.has_perm_entity('legal.admin', entity_id) or public.is_ceo())
  with check (public.has_perm_entity('legal.admin', entity_id) or public.is_ceo());
drop policy if exists "contrats: suppression" on public.legal_contracts;
create policy "contrats: suppression" on public.legal_contracts for delete to authenticated
  using ((public.has_perm_entity('legal.admin', entity_id) or public.is_ceo()) and status = 'draft');

drop policy if exists "contrats: lecture" on public.employment_contracts;
create policy "contrats: lecture" on public.employment_contracts for select to authenticated
  using (profile_id = auth.uid() or public.has_perm_entity('hr.view', entity_id) or public.has_perm_entity('hr.admin', entity_id));
drop policy if exists "contrats: gestion" on public.employment_contracts;
create policy "contrats: gestion" on public.employment_contracts for all to authenticated
  using (public.has_perm_entity('hr.admin', entity_id)) with check (public.has_perm_entity('hr.admin', entity_id));

drop policy if exists "salaires: lecture" on public.salaries;
create policy "salaires: lecture" on public.salaries for select to authenticated
  using (profile_id = auth.uid() or public.has_perm_entity('hr.admin', entity_id) or public.has_perm_entity('finance.admin', entity_id));
drop policy if exists "salaires: gestion" on public.salaries;
create policy "salaires: gestion" on public.salaries for all to authenticated
  using (public.has_perm_entity('hr.admin', entity_id) or public.has_perm_entity('finance.admin', entity_id))
  with check (public.has_perm_entity('hr.admin', entity_id) or public.has_perm_entity('finance.admin', entity_id));

-- Fonctions métier : contrôles par entité.
create or replace function public.activate_budget(p_budget uuid, p_justification text default null)
returns text language plpgsql security definer set search_path = public as $$
declare b public.budgets;
begin
  select * into b from public.budgets where id = p_budget for update;
  if b.id is null then raise exception 'Budget introuvable'; end if;
  if not public.has_perm_entity('finance.admin', b.entity_id) then raise exception 'Seule la finance active un budget' using errcode = '42501'; end if;
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

create or replace function public.submit_employment_contract(p_contract uuid, p_justification text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare c public.employment_contracts; v_id uuid;
begin
  select * into c from public.employment_contracts where id = p_contract;
  if c.id is null then raise exception 'Contrat introuvable'; end if;
  if not public.has_perm_entity('hr.admin', c.entity_id) then raise exception 'Permission refusée' using errcode = '42501'; end if;
  if c.status <> 'draft' then raise exception 'Seul un contrat en brouillon se soumet'; end if;
  v_id := public.request_approval('employment_contract', p_contract, null, null, p_justification);
  if public.approval_valid('employment_contract', p_contract, to_jsonb(c)) then
    return v_id;
  end if;
  update public.employment_contracts set status = 'pending_ceo' where id = p_contract;
  return v_id;
end $$;

create or replace function public.submit_contract_for_signature(p_contract uuid, p_justification text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare c public.legal_contracts; v_id uuid;
begin
  select * into c from public.legal_contracts where id = p_contract;
  if c.id is null then raise exception 'Contrat introuvable'; end if;
  if not (public.has_perm_entity('legal.admin', c.entity_id) or public.is_ceo()) then
    raise exception 'La soumission à signature revient au Juridique' using errcode = '42501';
  end if;
  if c.status <> 'legal_review' then
    raise exception 'Le contrat doit d''abord passer en revue juridique.';
  end if;
  v_id := public.request_approval('legal_contract', p_contract, null, null, p_justification);
  update public.legal_contracts set status = 'pending_ceo' where id = p_contract;
  return v_id;
end $$;

create or replace function public.reverse_transaction(p_id uuid, p_reason text)
returns uuid language plpgsql security definer set search_path = public as $$
declare t public.transactions; v_id uuid;
begin
  select * into t from public.transactions where id = p_id for update;
  if t.id is null then raise exception 'Opération introuvable'; end if;
  if not public.has_perm_entity('finance.admin', t.entity_id) then raise exception 'Permission refusée' using errcode = '42501'; end if;
  perform public.require_mfa();
  if length(trim(coalesce(p_reason, ''))) < 3 then raise exception 'Indiquez le motif de l''annulation'; end if;
  if t.reverses_id is not null then raise exception 'Une contre-passation ne se contre-passe pas'; end if;
  if t.reversed_by is not null then raise exception 'Cette opération a déjà été annulée'; end if;
  if t.invoice_id is not null and auth.uid() is not null and current_setting('veriion.invoice_flow', true) is distinct from 'on' then
    raise exception 'Ce revenu provient d''une facture : annulez l''encaissement depuis la facture.';
  end if;

  insert into public.transactions (type, amount, currency, occurred_on, category, description, unit_id, project_id,
                                   account_id, product, country, reference, reverses_id, reversal_reason, created_by, entity_id)
  values (t.type, -t.amount, t.currency, current_date, t.category, 'Annulation — ' || coalesce(t.description, t.category),
          t.unit_id, t.project_id, t.account_id, t.product, t.country, t.reference, t.id, trim(p_reason), auth.uid(), t.entity_id)
  returning id into v_id;

  perform set_config('veriion.txn_system', 'on', true);
  update public.transactions set reversed_by = v_id, reversal_reason = trim(p_reason) where id = t.id;
  perform set_config('veriion.txn_system', 'off', true);

  if t.approval_id is not null and t.type = 'expense' then
    update public.approval_requests set consumed_amount = greatest(0, consumed_amount - t.amount) where id = t.approval_id;
  end if;
  return v_id;
end $$;

create or replace function public.available_expense_approvals()
returns table (id uuid, subject_label text, amount numeric, consumed_amount numeric, remaining numeric,
               currency text, decided_at timestamptz, unit_id uuid, project_id uuid)
language sql stable security definer set search_path = public as $$
  select a.id, a.subject_label, a.amount, a.consumed_amount, a.amount - a.consumed_amount, a.currency, a.decided_at,
         a.unit_id, a.project_id
  from public.approval_requests a
  where a.kind = 'expense' and a.status = 'approved' and coalesce(a.amount, 0) > a.consumed_amount
    and public.has_perm_entity('finance.admin', a.entity_id)
  order by a.decided_at desc
$$;

-- Qui peut demander un accord : contrôles par entité pour la finance, le juridique et les RH.
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
    else
      allowed := false;
  end case;
end $$;

-- -----------------------------------------------------------------------------
-- 6. Taux de change et consolidation
-- -----------------------------------------------------------------------------
create table if not exists public.fx_rates (
  currency    text not null check (currency ~ '^[A-Z]{3}$'),
  valid_from  date not null default current_date,
  rate        numeric(18,8) not null check (rate > 0),   -- 1 unité de la devise = « rate » unités de la devise du groupe
  created_by  uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at  timestamptz not null default now(),
  primary key (currency, valid_from)
);
alter table public.fx_rates enable row level security;
revoke all on public.fx_rates from anon;
grant select, insert, update, delete on public.fx_rates to authenticated;
drop policy if exists "change: lecture" on public.fx_rates;
create policy "change: lecture" on public.fx_rates for select to authenticated using (public.is_active_user());
drop policy if exists "change: gestion" on public.fx_rates;
create policy "change: gestion" on public.fx_rates for all to authenticated
  using (public.has_perm('finance.admin') and public.mfa_ok()) with check (public.has_perm('finance.admin') and public.mfa_ok());
-- L'euro est arrimé au franc CFA (parité fixe).
insert into public.fx_rates (currency, valid_from, rate) values ('EUR', '1999-01-01', 655.957) on conflict do nothing;

create or replace function public.group_currency()
returns text language sql stable security definer set search_path = public as $$
  select coalesce((select currency from public.legal_entities where is_holding), 'XOF')
$$;

/** Montant converti dans la devise du groupe, au taux en vigueur à la date donnée. */
create or replace function public.to_group_amount(p_amount numeric, p_currency text, p_on date default current_date)
returns numeric language sql stable security definer set search_path = public as $$
  select case
    when p_amount is null then null
    when coalesce(p_currency, public.group_currency()) = public.group_currency() then p_amount
    else p_amount * coalesce(
      (select rate from public.fx_rates where currency = p_currency and valid_from <= coalesce(p_on, current_date)
        order by valid_from desc limit 1), 1)
  end
$$;
grant execute on function public.to_group_amount(numeric, text, date) to authenticated;

-- Tableau de bord consolidé, éventuellement limité à une entité.
alter function public.exec_dashboard(int) rename to exec_dashboard_core;
revoke execute on function public.exec_dashboard_core(int) from public, anon, authenticated;

/** Opérations converties dans la devise du groupe, éventuellement limitées à une entité. */
create or replace function public.dash_tx(p_entity uuid)
returns table (type public.txn_type, amount numeric, occurred_on date, product text, country text)
language sql stable security definer set search_path = public as $$
  select t.type, public.to_group_amount(t.amount, t.currency, t.occurred_on), t.occurred_on, t.product, t.country
  from public.transactions t where p_entity is null or t.entity_id = p_entity
$$;
revoke execute on function public.dash_tx(uuid) from public, anon, authenticated;

create or replace function public.exec_dashboard(p_year int default null, p_entity uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  y   int := coalesce(p_year, extract(year from current_date)::int);
  res jsonb;
begin
  if not public.has_perm('dashboard.exec') then
    raise exception 'Permission refusée' using errcode = '42501';
  end if;
  res := public.exec_dashboard_core(y);

  res := jsonb_set(res, '{kpis,revenue_ytd}',  to_jsonb((select coalesce(sum(amount), 0) from public.dash_tx(p_entity) where type = 'revenue' and extract(year from occurred_on) = y)));
  res := jsonb_set(res, '{kpis,expense_ytd}',  to_jsonb((select coalesce(sum(amount), 0) from public.dash_tx(p_entity) where type = 'expense' and extract(year from occurred_on) = y)));
  res := jsonb_set(res, '{kpis,revenue_prev}', to_jsonb((select coalesce(sum(amount), 0) from public.dash_tx(p_entity) where type = 'revenue'
                                                         and extract(year from occurred_on) = y - 1 and occurred_on <= (current_date - interval '1 year'))));
  res := jsonb_set(res, '{kpis,cash}', to_jsonb(
    (case when p_entity is null or p_entity = public.holding_entity_id() then (select opening_cash from public.company_settings) else 0 end)
    + (select coalesce(sum(case when type = 'revenue' then amount else -amount end), 0) from public.dash_tx(p_entity))));
  res := jsonb_set(res, '{kpis,receivables}', to_jsonb((select coalesce(sum(public.to_group_amount(total, currency, issue_date)), 0)
                                                        from public.invoices where status in ('sent', 'overdue') and (p_entity is null or entity_id = p_entity))));
  res := jsonb_set(res, '{kpis,overdue_invoices}', to_jsonb((select coalesce(sum(public.to_group_amount(total, currency, issue_date)), 0)
                                                             from public.invoices where status = 'overdue' and (p_entity is null or entity_id = p_entity))));
  res := jsonb_set(res, '{monthly}', (
    select jsonb_agg(jsonb_build_object(
      'month', m,
      'revenue', coalesce((select sum(amount) from public.dash_tx(p_entity) where type = 'revenue' and extract(year from occurred_on) = y and extract(month from occurred_on) = m), 0),
      'expense', coalesce((select sum(amount) from public.dash_tx(p_entity) where type = 'expense' and extract(year from occurred_on) = y and extract(month from occurred_on) = m), 0)
    ) order by m) from generate_series(1, 12) m));
  res := jsonb_set(res, '{revenue_by_product}', (
    select coalesce(jsonb_agg(jsonb_build_object('label', k, 'value', v) order by v desc), '[]'::jsonb) from (
      select coalesce(product, 'Non affecté') k, sum(amount) v from public.dash_tx(p_entity)
      where type = 'revenue' and extract(year from occurred_on) = y group by 1) s));
  res := jsonb_set(res, '{revenue_by_country}', (
    select coalesce(jsonb_agg(jsonb_build_object('label', k, 'value', v) order by v desc), '[]'::jsonb) from (
      select coalesce(country, 'Non affecté') k, sum(amount) v from public.dash_tx(p_entity)
      where type = 'revenue' and extract(year from occurred_on) = y group by 1) s));

  -- Une ligne par entité : la vue consolidée de la holding.
  res := res || jsonb_build_object(
    'currency', public.group_currency(),
    'entity_id', p_entity,
    'entities', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', e.id, 'code', e.code, 'name', e.name, 'currency', e.currency, 'is_holding', e.is_holding,
        'revenue_ytd', coalesce((select sum(amount) from public.dash_tx(e.id) where type = 'revenue' and extract(year from occurred_on) = y), 0),
        'expense_ytd', coalesce((select sum(amount) from public.dash_tx(e.id) where type = 'expense' and extract(year from occurred_on) = y), 0),
        'headcount', (select count(*) from public.profiles p where p.status = 'active' and public.profile_entity(p.id) = e.id)
      ) order by e.is_holding desc, e.name), '[]'::jsonb)
      from public.legal_entities e where e.archived_at is null));
  return res;
end $$;
revoke execute on function public.exec_dashboard(int, uuid) from public, anon;
grant execute on function public.exec_dashboard(int, uuid) to authenticated;

-- Les droits sont recalculés pour tout le monde (portée par entité).
do $$ declare r record; begin
  for r in select id from public.profiles where status = 'active' loop
    perform public.sync_auto_grants(r.id);
  end loop;
end $$;
