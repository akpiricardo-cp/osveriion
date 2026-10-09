\set ON_ERROR_STOP 0
-- Preuves de contournement de la gouvernance (audit du 9 octobre 2026, docs/AUDIT-OS-VERIION.md §3.1).
-- À exécuter après 00_supabase_stub.sql, les migrations et seed.sql. Chaque ligne P* affichée = contournement réussi.
-- Après correction, chaque scénario doit échouer avec une erreur 42501.
-- Le grant ci-dessous compense l'absence des privilèges par défaut de Supabase dans le stub de test.
grant usage, select on all sequences in schema public to authenticated;
insert into auth.users (id, email) values
 ('00000000-0000-0000-0000-0000000000a1', 'ceo.x@veriion.com'),
 ('00000000-0000-0000-0000-0000000000b1', 'admin.un@veriion.com'),
 ('00000000-0000-0000-0000-0000000000b2', 'admin.deux@veriion.com'),
 ('00000000-0000-0000-0000-0000000000c1', 'cfo.x@veriion.com'),
 ('00000000-0000-0000-0000-0000000000d1', 'lead.x@veriion.com'),
 ('00000000-0000-0000-0000-0000000000e1', 'dev.x@veriion.com');
update profiles set system_role='admin' where email like 'admin.%';
create or replace function pg_temp.as_user(u text) returns void language plpgsql as $$
begin perform set_config('request.jwt.claim.sub', u, false); execute 'set role authenticated'; end $$;

select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.appoint_member((select id from org_units where code='FIN'), '00000000-0000-0000-0000-0000000000c1', 'head');
insert into projects (id, name, owner_id) values ('11111111-1111-1111-1111-111111111111', 'Projet PoC', '00000000-0000-0000-0000-0000000000a1');
insert into project_members values ('11111111-1111-1111-1111-111111111111','00000000-0000-0000-0000-0000000000d1','lead'),
                                   ('11111111-1111-1111-1111-111111111111','00000000-0000-0000-0000-0000000000e1','member');
reset role;

\echo '== P1 : le titulaire contourne la vérification de sa tâche'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tasks (id, project_id, title, assignee_id) values ('22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111','Livrable','00000000-0000-0000-0000-0000000000e1');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000e1');
update tasks set requires_validation=false, status='done' where id='22222222-2222-2222-2222-222222222222';
reset role;
select 'P1 statut='||status||' validated_by='||coalesce(validated_by::text,'∅') from tasks where id='22222222-2222-2222-2222-222222222222';

\echo '== P2 : un administrateur relève le seuil des validations du CEO'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
update company_settings set ceo_approval_threshold = 999999999999 where id;
reset role;
select 'P2 seuil='||ceo_approval_threshold from company_settings;
update company_settings set ceo_approval_threshold = 500000 where id;

\echo '== P3 : un administrateur suspend le CEO'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
update profiles set status='suspended' where email='ceo.x@veriion.com';
reset role;
select 'P3 statut CEO='||status from profiles where email='ceo.x@veriion.com';
update profiles set status='active' where email='ceo.x@veriion.com';

\echo '== P4 : budget approuvé puis gonflé après accord'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
insert into budgets (id, unit_id, fiscal_year, amount) values ('33333333-3333-3333-3333-333333333333',(select id from org_units where code='FIN'),2027,1000000);
select public.request_approval('budget','33333333-3333-3333-3333-333333333333','Budget FIN 2027',1000000);
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.decide_approval((select id from approval_requests where kind='budget'), true, 'ok');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
update budgets set status='active' where id='33333333-3333-3333-3333-333333333333';
update budgets set amount=900000000 where id='33333333-3333-3333-3333-333333333333';
reset role;
select 'P4 budget='||amount||' statut='||status from budgets where id='33333333-3333-3333-3333-333333333333';

\echo '== P5 : un seul accord de dépense réutilisé plusieurs fois'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
select public.request_approval('expense', null, 'Serveurs', 2000000);
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.decide_approval((select id from approval_requests where kind='expense'), true, 'ok');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
insert into transactions (type, amount, approval_id) select 'expense', 2000000, (select id from approval_requests where kind='expense') from generate_series(1,3);
reset role;
select 'P5 dépenses sur un seul accord='||count(*) from transactions where approval_id is not null;

\echo '== P6 : un admin donne approvals.decide / finance.admin à un autre admin'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
insert into role_grants (profile_id, permission, source, reason, granted_by) values
 ('00000000-0000-0000-0000-0000000000b2','approvals.decide','manual','intérim direction','00000000-0000-0000-0000-0000000000b1'),
 ('00000000-0000-0000-0000-0000000000b2','finance.admin','manual','intérim finance','00000000-0000-0000-0000-0000000000b1');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2');
select public.request_approval('other', null, 'Ma propre demande', 10);
select public.decide_approval((select id from approval_requests where subject_label='Ma propre demande'), true, null);
reset role;
select 'P6 auto-approbation: demandeur=décideur ? '||(requested_by=decided_by) from approval_requests where subject_label='Ma propre demande';
