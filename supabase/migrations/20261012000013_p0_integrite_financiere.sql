-- =============================================================================
-- VERIION OS — Migration 13 : intégrité financière minimale (phase 0, lot P0-08)
-- =============================================================================
--   * une facture émise ne se modifie plus (montants, lignes, client) ;
--   * aucune facture ni opération ne se supprime : on annule par contre-passation ;
--   * annuler un encaissement passe une écriture inverse au lieu d'effacer le revenu ;
--   * numérotation des factures continue, par exercice ;
--   * la fusion d'unités ne réécrit plus l'historique financier.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Opérations : immuables, annulées par contre-passation
-- -----------------------------------------------------------------------------
alter table public.transactions
  add column if not exists reverses_id uuid references public.transactions(id) on delete restrict,
  add column if not exists reversed_by uuid references public.transactions(id) on delete set null,
  add column if not exists reversal_reason text;

alter table public.transactions drop constraint if exists transactions_amount_check;
alter table public.transactions drop constraint if exists transactions_amount_sign;
alter table public.transactions add constraint transactions_amount_sign
  check ((reverses_id is null and amount > 0) or (reverses_id is not null and amount < 0));
create unique index if not exists transactions_one_reversal on public.transactions(reverses_id) where reverses_id is not null;

-- Une facture ne porte qu'un revenu actif (non contre-passé).
alter table public.transactions drop constraint if exists transactions_invoice_id_key;
drop index if exists public.transactions_invoice_id_key;
create unique index if not exists transactions_invoice_active
  on public.transactions(invoice_id) where invoice_id is not null and reverses_id is null and reversed_by is null;


/** Contre-passe une opération : écriture inverse datée du jour, motivée. */
create or replace function public.reverse_transaction(p_id uuid, p_reason text)
returns uuid language plpgsql security definer set search_path = public as $$
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
revoke execute on function public.reverse_transaction(uuid, text) from public, anon;
grant execute on function public.reverse_transaction(uuid, text) to authenticated;

-- Le drapeau système autorise uniquement le marquage « contre-passée ».
create or replace function public.transactions_immutable()
returns trigger language plpgsql security definer set search_path = public as $$
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

drop trigger if exists transactions_immutable_bud on public.transactions;
create trigger transactions_immutable_bud before update or delete on public.transactions
  for each row execute function public.transactions_immutable();

drop policy if exists "transactions: gestion" on public.transactions;
drop policy if exists "transactions: saisie" on public.transactions;
drop policy if exists "transactions: correction" on public.transactions;
create policy "transactions: saisie" on public.transactions for insert to authenticated
  with check (public.has_perm('finance.admin') and reverses_id is null);
create policy "transactions: correction" on public.transactions for update to authenticated
  using (public.has_perm('finance.admin')) with check (public.has_perm('finance.admin'));
-- Aucune politique de suppression : la contre-passation est la seule voie.

-- -----------------------------------------------------------------------------
-- 2. Factures : numérotation continue, verrouillage après émission
-- -----------------------------------------------------------------------------
alter table public.invoices add column if not exists sent_at timestamptz;
update public.invoices set sent_at = coalesce(sent_at, updated_at) where status in ('sent', 'paid', 'overdue');

create table if not exists public.invoice_counters (
  scope text not null,          -- série (préfixe), par exemple « FAC »
  year  int  not null,
  last  int  not null default 0,
  primary key (scope, year)
);
alter table public.invoice_counters enable row level security;
revoke all on public.invoice_counters from anon, authenticated;

-- Reprend les numéros existants pour que la série continue sans collision.
insert into public.invoice_counters (scope, year, last)
select 'FAC', split_part(number, '-', 2)::int, max(split_part(number, '-', 3)::int)
  from public.invoices where number ~ '^FAC-[0-9]{4}-[0-9]+$'
 group by split_part(number, '-', 2)
on conflict (scope, year) do update set last = greatest(public.invoice_counters.last, excluded.last);

create or replace function public.next_invoice_number(p_scope text, p_date date)
returns text language plpgsql security definer set search_path = public as $$
declare v_year int := extract(year from coalesce(p_date, current_date))::int; v_n int;
begin
  insert into public.invoice_counters (scope, year, last) values (p_scope, v_year, 1)
  on conflict (scope, year) do update set last = public.invoice_counters.last + 1
  returning last into v_n;
  return p_scope || '-' || v_year || '-' || lpad(v_n::text, 5, '0');
end $$;
revoke execute on function public.next_invoice_number(text, date) from public, anon, authenticated;

alter table public.invoices alter column number drop default;

create or replace function public.invoices_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.number is null or auth.uid() is not null then
    new.number := public.next_invoice_number('FAC', new.issue_date);
  end if;
  new.status := 'draft';
  new.sent_at := null; new.paid_at := null;
  return new;
end $$;
drop trigger if exists invoices_bi on public.invoices;
create trigger invoices_bi before insert on public.invoices
  for each row execute function public.invoices_before_insert();

create or replace function public.invoices_before_update()
returns trigger language plpgsql as $$
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

-- Encaissement : revenu ; annulation de l'encaissement : contre-passation.
create or replace function public.invoices_after_update()
returns trigger language plpgsql security definer set search_path = public as $$
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

-- Les lignes ne changent qu'en brouillon ; le recalcul des totaux reste permis.
create or replace function public.invoice_lines_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_status public.invoice_status;
begin
  select status into v_status from public.invoices where id = coalesce(new.invoice_id, old.invoice_id);
  if auth.uid() is not null and v_status is distinct from 'draft' then
    raise exception 'Les lignes d''une facture émise ne se modifient plus.' using errcode = '42501';
  end if;
  return coalesce(new, old);
end $$;
drop trigger if exists invoice_lines_guard_biud on public.invoice_lines;
create trigger invoice_lines_guard_biud before insert or update or delete on public.invoice_lines
  for each row execute function public.invoice_lines_guard();

create or replace function public.recompute_invoice(p_invoice uuid)
returns void language plpgsql security definer set search_path = public as $$
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
revoke execute on function public.recompute_invoice(uuid) from public, anon, authenticated;

-- Pas de suppression de facture : on l'annule.
drop policy if exists "factures: gestion" on public.invoices;
drop policy if exists "factures: création" on public.invoices;
drop policy if exists "factures: modification" on public.invoices;
create policy "factures: création" on public.invoices for insert to authenticated
  with check (public.has_perm('finance.admin'));
create policy "factures: modification" on public.invoices for update to authenticated
  using (public.has_perm('finance.admin')) with check (public.has_perm('finance.admin'));

-- -----------------------------------------------------------------------------
-- 3. Fusion d'unités : l'historique financier garde son unité d'origine
-- -----------------------------------------------------------------------------
alter table public.org_units add column if not exists merged_into uuid references public.org_units(id) on delete set null;

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
