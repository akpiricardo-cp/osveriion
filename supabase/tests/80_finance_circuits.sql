\set ON_ERROR_STOP 1
-- Intégrité financière et circuits : factures figées, contre-passations,
-- numérotation continue, budgets, contrats de travail et juridiques.
insert into auth.users (id, email) values
 ('00000000-0000-0000-0000-0000000000a1', 'ceo.x@veriion.com'),
 ('00000000-0000-0000-0000-0000000000c1', 'cfo.x@veriion.com'),
 ('00000000-0000-0000-0000-0000000000b1', 'rh.x@veriion.com'),
 ('00000000-0000-0000-0000-0000000000f1', 'juriste.x@veriion.com'),
 ('00000000-0000-0000-0000-0000000000e1', 'dev.x@veriion.com');

create or replace function pg_temp.as_user(u text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', u, false);
  perform set_config('request.jwt.claims', '{"aal":"aal2"}', false);
  execute 'set role authenticated';
end $$;

select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.appoint_member((select id from org_units where code = 'FIN'), '00000000-0000-0000-0000-0000000000c1', 'head');
select public.appoint_member((select id from org_units where code = 'RH'),  '00000000-0000-0000-0000-0000000000b1', 'head');
select public.appoint_member((select id from org_units where code = 'LEG'), '00000000-0000-0000-0000-0000000000f1', 'head');
reset role;

-- ── Factures ──────────────────────────────────────────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
insert into accounts (name) values ('Client SA');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
insert into invoices (account_id, number) values ((select id from accounts), 'FAC-1999-99999');
insert into invoices (account_id) values ((select id from accounts));
do $$ begin
  if exists (select 1 from invoices where number = 'FAC-1999-99999') then
    raise exception 'ERREUR: numéro de facture imposé par l''utilisateur';
  end if;
  if (select count(distinct number) from invoices) <> 2
     or (select max(split_part(number, '-', 3)::int) - min(split_part(number, '-', 3)::int) from invoices) <> 1 then
    raise exception 'ERREUR: numérotation non continue';
  end if;
  raise notice 'OK : numérotation des factures continue et attribuée par le système';
end $$;
insert into invoice_lines (invoice_id, description, quantity, unit_price)
select id, 'Prestation', 1, 100000 from invoices order by number limit 1;
update invoices set status = 'sent' where id = (select id from invoices order by number limit 1);
do $$ begin
  insert into invoice_lines (invoice_id, description, quantity, unit_price)
  select id, 'Ajout', 1, 5 from invoices order by number limit 1;
  raise exception 'ERREUR: ligne ajoutée à une facture émise';
exception when insufficient_privilege then raise notice 'OK : une facture émise est figée (lignes)';
end $$;
do $$ begin
  update invoices set tax_rate = 0 where id = (select id from invoices order by number limit 1);
  raise exception 'ERREUR: TVA modifiée sur une facture émise';
exception when insufficient_privilege then raise notice 'OK : une facture émise est figée (montants)';
end $$;
update invoices set status = 'paid' where id = (select id from invoices order by number limit 1);
update invoices set status = 'sent' where id = (select id from invoices order by number limit 1);
update invoices set status = 'paid' where id = (select id from invoices order by number limit 1);
reset role;
do $$ begin
  if (select sum(amount) from transactions where type = 'revenue') <> 118000 then
    raise exception 'ERREUR: revenu net faux après annulation puis nouvel encaissement (%)', (select sum(amount) from transactions where type = 'revenue');
  end if;
  if (select count(*) from transactions where reverses_id is not null) <> 1 then
    raise exception 'ERREUR: l''annulation d''encaissement n''a pas passé de contre-passation';
  end if;
  raise notice 'OK : annuler un encaissement contre-passe le revenu, sans l''effacer';
end $$;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
do $$ begin
  delete from invoices;
  if exists (select 1 from invoices) then raise notice 'OK : une facture ne se supprime pas'; else raise exception 'ERREUR: facture supprimée'; end if;
end $$;

-- ── Opérations : immuables, contre-passées ────────────────────────────────
insert into transactions (type, amount, category) values ('expense', 120000, 'Logiciels');
do $$ begin
  update transactions set amount = 1 where category = 'Logiciels';
  raise exception 'ERREUR: montant d''opération modifié';
exception when insufficient_privilege then raise notice 'OK : le montant d''une opération ne se modifie pas';
end $$;
do $$ begin
  delete from transactions where category = 'Logiciels';
  if not exists (select 1 from transactions where category = 'Logiciels') then raise exception 'ERREUR: opération supprimée'; end if;
  raise notice 'OK : une opération ne se supprime pas';
end $$;
select public.reverse_transaction((select id from transactions where category = 'Logiciels' and reverses_id is null), 'Saisie en double') is not null as contre_passee;
reset role;
do $$ begin
  if (select sum(amount) from transactions where category = 'Logiciels') <> 0 then
    raise exception 'ERREUR: contre-passation incorrecte';
  end if;
  raise notice 'OK : la contre-passation annule l''opération en conservant la trace';
end $$;

-- ── Budget : activation selon le seuil ────────────────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
insert into budgets (id, unit_id, fiscal_year, amount) values
  ('44444444-4444-4444-4444-444444444441', (select id from org_units where code = 'MKT'), 2027, 300000),
  ('44444444-4444-4444-4444-444444444442', (select id from org_units where code = 'TECH'), 2027, 9000000);
select public.activate_budget('44444444-4444-4444-4444-444444444441') as petit_budget;
select public.activate_budget('44444444-4444-4444-4444-444444444442', 'Recrutements') as gros_budget;
reset role;
do $$ begin
  if (select status from budgets where id = '44444444-4444-4444-4444-444444444441') <> 'active'
     or (select status from budgets where id = '44444444-4444-4444-4444-444444444442') <> 'draft'
     or not exists (select 1 from approval_requests where kind = 'budget' and status = 'pending') then
    raise exception 'ERREUR: activation des budgets selon le seuil incorrecte';
  end if;
  raise notice 'OK : budget activé sous le seuil, soumis au CEO au-delà';
end $$;

-- ── Contrat de travail : accord puis signature, le salaire suit ───────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
insert into employment_contracts (id, profile_id, type, job_title, start_date, gross_monthly)
values ('55555555-5555-5555-5555-555555555555', '00000000-0000-0000-0000-0000000000e1', 'cdi', 'Développeur', current_date, 800000);
do $$ begin
  update employment_contracts set status = 'signed' where id = '55555555-5555-5555-5555-555555555555';
  raise exception 'ERREUR: contrat de travail signé sans accord';
exception when insufficient_privilege then raise notice 'OK : contrat de travail non signable sans accord du CEO';
end $$;
select public.submit_employment_contract('55555555-5555-5555-5555-555555555555') is not null as soumis;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.decide_approval((select id from approval_requests where kind = 'employment_contract'), true, 'Bienvenue');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
update employment_contracts set status = 'signed' where id = '55555555-5555-5555-5555-555555555555';
reset role;
do $$ begin
  if not exists (select 1 from salaries where profile_id = '00000000-0000-0000-0000-0000000000e1' and gross_monthly = 800000) then
    raise exception 'ERREUR: le salaire n''a pas suivi la signature';
  end if;
  raise notice 'OK : accord, signature, puis salaire appliqué';
end $$;

-- ── Contrat juridique : revue obligatoire, échéance automatique ───────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000f1');
insert into legal_contracts (id, title, type, counterparty, amount, effective_date, end_date)
values ('66666666-6666-6666-6666-666666666666', 'Licence logicielle', 'licence', 'Editeur SA', 100000, current_date - 400, current_date - 1);
do $$ begin
  perform public.submit_contract_for_signature('66666666-6666-6666-6666-666666666666');
  raise exception 'ERREUR: contrat soumis sans revue juridique';
exception when others then
  if sqlerrm like 'ERREUR%' then raise; end if;
  raise notice 'OK : la revue juridique est obligatoire';
end $$;
do $$ begin
  update legal_contracts set status = 'active' where id = '66666666-6666-6666-6666-666666666666';
  raise exception 'ERREUR: saut d''étape accepté';
exception when check_violation then raise notice 'OK : pas de saut d''étape dans le circuit du contrat';
end $$;
update legal_contracts set status = 'legal_review' where id = '66666666-6666-6666-6666-666666666666';
select public.submit_contract_for_signature('66666666-6666-6666-6666-666666666666') is not null as soumis;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.decide_approval((select id from approval_requests where kind = 'legal_contract'), true, 'ok');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000f1');
update legal_contracts set status = 'active' where id = '66666666-6666-6666-6666-666666666666';
reset role;
select public.process_contract_terms();
do $$ begin
  if (select status from legal_contracts where id = '66666666-6666-6666-6666-666666666666') <> 'expired' then
    raise exception 'ERREUR: contrat échu non marqué expiré';
  end if;
  raise notice 'OK : un contrat échu passe automatiquement « expiré »';
end $$;

-- ── Vues d'appui : accord caduc, accords disponibles, santé ───────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.decide_approval((select id from approval_requests where kind = 'budget' and status = 'pending'), true, 'ok');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
update budgets set status = 'draft', amount = 9500000 where id = '44444444-4444-4444-4444-444444444442';
do $$ begin
  if not (select stale from approval_requests_status where kind = 'budget' and subject_id = '44444444-4444-4444-4444-444444444442') then
    raise exception 'ERREUR: accord non signalé caduc après modification du montant';
  end if;
  raise notice 'OK : un accord devient caduc quand le contenu change';
end $$;
select public.request_approval('expense', null, 'Matériel', 900000);
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.decide_approval((select id from approval_requests where kind = 'expense' and subject_label = 'Matériel'), true, 'ok');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
do $$ begin
  if (select remaining from public.available_expense_approvals() where subject_label = 'Matériel') <> 900000 then
    raise exception 'ERREUR: accord de dépense disponible mal calculé';
  end if;
  raise notice 'OK : accords de dépense disponibles listés avec leur reste';
end $$;
reset role;
do $$ begin
  if (public.ops_health()->>'database') <> 'ok' then raise exception 'ERREUR: ops_health'; end if;
  raise notice 'OK : point de santé opérationnel';
end $$;
