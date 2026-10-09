-- =============================================================================
-- VERIION OS — Migration 14 : circuits branchés de bout en bout (phase 0, lot P0-06)
-- =============================================================================
--   * budget : brouillon → activation directe sous le seuil, accord du CEO au-delà ;
--   * contrat de travail : brouillon → accord du CEO → signature (le salaire suit) ;
--   * contrat juridique : machine à états stricte, revue juridique obligatoire,
--     expiration et renouvellement tacite automatiques.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Budgets
-- -----------------------------------------------------------------------------
/** Active un budget : directement sous le seuil, sinon demande l'accord du CEO. Renvoie l'état obtenu. */
create or replace function public.activate_budget(p_budget uuid, p_justification text default null)
returns text language plpgsql security definer set search_path = public as $$
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
revoke execute on function public.activate_budget(uuid, text) from public, anon;
grant execute on function public.activate_budget(uuid, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Contrats de travail
-- -----------------------------------------------------------------------------
create or replace function public.submit_employment_contract(p_contract uuid, p_justification text default null)
returns uuid language plpgsql security definer set search_path = public as $$
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
revoke execute on function public.submit_employment_contract(uuid, text) from public, anon;
grant execute on function public.submit_employment_contract(uuid, text) to authenticated;

create or replace function public.employment_contracts_transition()
returns trigger language plpgsql security definer set search_path = public as $$
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
drop trigger if exists employment_contracts_aa_transition_biu on public.employment_contracts;
create trigger employment_contracts_aa_transition_biu before insert or update on public.employment_contracts
  for each row execute function public.employment_contracts_transition();

-- -----------------------------------------------------------------------------
-- 3. Contrats juridiques : machine à états
-- -----------------------------------------------------------------------------
create or replace function public.legal_contracts_transition()
returns trigger language plpgsql security definer set search_path = public as $$
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
drop trigger if exists legal_contracts_aa_transition_biu on public.legal_contracts;
create trigger legal_contracts_aa_transition_biu before insert or update on public.legal_contracts
  for each row execute function public.legal_contracts_transition();

/** La revue juridique est obligatoire avant la signature du CEO. */
create or replace function public.submit_contract_for_signature(p_contract uuid, p_justification text default null)
returns uuid language plpgsql security definer set search_path = public as $$
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

/**
 * Tâche quotidienne : contrats arrivés à terme. Renouvellement tacite pour une
 * durée égale à la précédente, sinon expiration. Le propriétaire est prévenu.
 */
create or replace function public.process_contract_terms()
returns int language plpgsql security definer set search_path = public as $$
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
revoke execute on function public.process_contract_terms() from public, anon, authenticated;

do $$
begin
  perform cron.schedule('veriion-contract-terms', '15 5 * * *', 'select public.process_contract_terms()');
exception when others then
  raise notice 'pg_cron non disponible : échéances des contrats à planifier plus tard (%)', sqlerrm;
end $$;
