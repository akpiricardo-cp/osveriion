\set ON_ERROR_STOP 1
-- Multi-entités : une filiale a ses propres données, droits et séries ; la holding consolide.
insert into auth.users (id, email) values
 ('00000000-0000-0000-0000-0000000000a1', 'ceo.x@veriion.com'),
 ('00000000-0000-0000-0000-0000000000c1', 'cfo.holding@veriion.com'),
 ('00000000-0000-0000-0000-0000000000c2', 'cfo.filiale@veriion.com');

create or replace function pg_temp.as_user(u text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', u, false);
  perform set_config('request.jwt.claims', '{"aal":"aal2"}', false);
  execute 'set role authenticated';
end $$;

-- ── Création d'une filiale par le CEO ─────────────────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.create_entity('ONX', 'Oniix Nigeria', 'Oniix Nigeria Ltd', 'NG', 'NGN', 7.5, 'RC-123', null, 'ONX', 'JONX') is not null as filiale;
insert into org_units (parent_id, name, code, kind, domain)
values ((select id from org_units where code = 'ONX'), 'Finance Oniix NG', 'ONX-FIN', 'department', 'finance');
select public.appoint_member((select id from org_units where code = 'FIN'), '00000000-0000-0000-0000-0000000000c1', 'head');
select public.appoint_member((select id from org_units where code = 'ONX-FIN'), '00000000-0000-0000-0000-0000000000c2', 'head');
insert into fx_rates (currency, valid_from, rate) values ('NGN', '2020-01-01', 0.4);
reset role;

do $$ begin
  if (select e.code from org_units u join legal_entities e on e.id = u.entity_id where u.code = 'ONX-FIN') <> 'ONX' then
    raise exception 'ERREUR: le département de la filiale n''hérite pas de son entité';
  end if;
  if not exists (select 1 from role_grants g join legal_entities e on e.id = g.scope_entity_id
                 where g.profile_id = '00000000-0000-0000-0000-0000000000c2' and g.permission = 'finance.admin' and e.code = 'ONX') then
    raise exception 'ERREUR: les droits du CFO de filiale ne sont pas limités à sa filiale';
  end if;
  raise notice 'OK : la filiale hérite de son entité et limite les droits de ses responsables';
end $$;

-- ── Chaque CFO saisit dans son entité ─────────────────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
insert into transactions (type, amount, category, unit_id) values ('revenue', 1000000, 'Ventes', (select id from org_units where code = 'FIN'));
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c2');
insert into transactions (type, amount, currency, category, unit_id) values ('revenue', 500000, 'NGN', 'Ventes', (select id from org_units where code = 'ONX-FIN'));
do $$ begin
  if (select count(*) from transactions) <> 1 then raise exception 'ERREUR: le CFO de filiale voit les opérations de la holding'; end if;
  raise notice 'OK : le CFO de filiale ne voit que sa filiale';
end $$;
do $$ begin
  insert into transactions (type, amount, category, unit_id) values ('expense', 1000, 'Divers', (select id from org_units where code = 'FIN'));
  raise exception 'ERREUR: le CFO de filiale saisit dans la holding';
exception when insufficient_privilege then raise notice 'OK : pas de saisie hors de sa filiale';
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
do $$ begin
  if (select count(*) from transactions) <> 2 then raise exception 'ERREUR: le CFO de la holding ne voit pas le groupe'; end if;
  raise notice 'OK : la finance de la holding voit tout le groupe';
end $$;
reset role;

-- ── Séries de numérotation par entité ─────────────────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
insert into accounts (name) values ('Client NG');
insert into invoices (account_id, unit_id) values ((select id from accounts), (select id from org_units where code = 'ONX-FIN'));
insert into invoices (account_id, unit_id) values ((select id from accounts), (select id from org_units where code = 'FIN'));
insert into legal_contracts (title, type, counterparty, unit_id) values ('Bail Lagos', 'supplier', 'Lagos Estates', (select id from org_units where code = 'ONX-FIN'));
reset role;
do $$ begin
  if not exists (select 1 from invoices where number like 'ONX-%' and currency = 'NGN')
     or not exists (select 1 from invoices where number like 'FAC-%' and currency = 'XOF')
     or not exists (select 1 from legal_contracts where reference like 'JONX-%') then
    raise exception 'ERREUR: séries ou devise par entité incorrectes';
  end if;
  raise notice 'OK : chaque entité a ses séries et sa devise';
end $$;

-- ── Consolidation dans la devise du groupe ────────────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
do $$ declare d jsonb; begin
  d := public.exec_dashboard();
  if (d->'kpis'->>'revenue_ytd')::numeric <> 1200000 then
    raise exception 'ERREUR: consolidation incorrecte (%)', d->'kpis'->>'revenue_ytd';
  end if;
  if (public.exec_dashboard(null, (select id from legal_entities where code = 'ONX'))->'kpis'->>'revenue_ytd')::numeric <> 200000 then
    raise exception 'ERREUR: vue par entité incorrecte';
  end if;
  if jsonb_array_length(d->'entities') <> 2 then raise exception 'ERREUR: liste des entités'; end if;
  raise notice 'OK : tableau de bord consolidé en XOF et vue par entité';
end $$;
reset role;
