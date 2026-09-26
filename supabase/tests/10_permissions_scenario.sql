\set ON_ERROR_STOP 1
-- Scénario : CEO, CFO, CMO, développeur. Vérifie droits automatiques et RLS.
insert into auth.users (id, email, raw_user_meta_data) values
 ('00000000-0000-0000-0000-00000000000a', 'awa.ceo@veriion.com',   '{"first_name":"Awa","last_name":"Houngbo"}'),
 ('00000000-0000-0000-0000-00000000000b', 'koffi.cfo@veriion.com', '{"first_name":"Koffi","last_name":"Adjovi"}'),
 ('00000000-0000-0000-0000-00000000000c', 'nadia.cmo@veriion.com', '{"first_name":"Nadia","last_name":"Sossa"}'),
 ('00000000-0000-0000-0000-00000000000d', 'yann.dev@veriion.com',  '{}');

select email, system_role, full_name from public.profiles order by email;

create or replace function pg_temp.as_user(u text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', u, false);
  execute 'set role authenticated';
end $$;

-- ===== CEO nomme les responsables
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select public.appoint_member((select id from org_units where code='FIN'), '00000000-0000-0000-0000-00000000000b', 'head', 'CFO');
select public.appoint_member((select id from org_units where code='MKT'), '00000000-0000-0000-0000-00000000000c', 'head', 'CMO');
select public.appoint_member((select id from org_units where code='TECH-DEV-BE'), '00000000-0000-0000-0000-00000000000d', 'member');
reset role;

select p.email, g.permission, u.code as scope from role_grants g join profiles p on p.id=g.profile_id left join org_units u on u.id=g.scope_unit_id order by 1,2;

-- ===== CFO
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
select 'cfo finance.admin' t, public.has_perm('finance.admin') v
union all select 'cfo unit.manage FIN-CPT', public.has_perm('unit.manage', (select id from org_units where code='FIN-CPT'))
union all select 'cfo unit.manage MKT', public.has_perm('unit.manage', (select id from org_units where code='MKT'))
union all select 'cfo crm.view', public.has_perm('crm.view');
insert into budgets (unit_id, fiscal_year, amount) values ((select id from org_units where code='MKT'), 2026, 50000000);
insert into transactions (type, amount, category, unit_id, occurred_on) values ('expense', 1200000, 'Publicité', (select id from org_units where code='MKT-ACQ'), '2026-03-10');
insert into transactions (type, amount, category, product, country, occurred_on) values ('revenue', 9000000, 'Ventes', 'Oniix', 'BJ', '2026-04-02');
select count(*) as cfo_sees_transactions from transactions;
reset role;

-- ===== CMO : voit son budget, pas les revenus globaux
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select count(*) as cmo_budgets from budgets;
select count(*) as cmo_transactions_visible from transactions;  -- attendu : 1 (dépense Marketing)
select public.has_perm('dashboard.exec') as cmo_dashboard;
do $$ begin
  insert into transactions (type, amount) values ('expense', 10);
  raise exception 'ERREUR: le CMO a pu saisir une transaction';
exception when insufficient_privilege then raise notice 'OK : CMO ne peut pas saisir de transaction';
end $$;
-- Le CMO nomme un membre dans son sous-département
select public.appoint_member((select id from org_units where code='MKT-ACQ'), '00000000-0000-0000-0000-00000000000d', 'member') is not null as cmo_appoint_ok;
-- mais ne peut pas nommer le responsable du Marketing lui-même
do $$ begin
  perform public.appoint_member((select id from org_units where code='FIN'), '00000000-0000-0000-0000-00000000000c', 'head');
  raise exception 'ERREUR';
exception when insufficient_privilege then raise notice 'OK : CMO ne peut pas se nommer à la Finance';
end $$;
-- Le CMO crée un projet dans son unité
insert into projects (name, unit_id, status, due_date) values ('Campagne Q4', (select id from org_units where code='MKT'), 'active', '2026-01-01') ;
reset role;

-- ===== Développeur
select pg_temp.as_user('00000000-0000-0000-0000-00000000000d');
select count(*) as dev_transactions from transactions;   -- attendu 0
select count(*) as dev_budgets from budgets;              -- attendu 0
select count(*) as dev_projects from projects;            -- membre de MKT-ACQ -> voit le projet Marketing (in_unit sur MKT) : attendu 0 ? (MKT-ACQ ⊂ MKT)
select count(*) as dev_org_units from org_units;
do $$ begin
  update profiles set system_role='ceo' where id = auth.uid();
  raise exception 'ERREUR';
exception when insufficient_privilege then raise notice 'OK : escalade de rôle bloquée';
end $$;
update profiles set job_title = 'Ingénieur Backend' where id = auth.uid();
-- Tâche personnelle + congé
insert into tasks (title, due_date) values ('Préparer la revue de code', current_date - 2);
insert into leave_requests (start_date, end_date, type) values (current_date + 10, current_date + 14, 'annual');
select public.open_direct_channel('00000000-0000-0000-0000-00000000000c') is not null as dm_ok;
insert into messages (channel_id, body) select id, 'Bonjour Nadia' from channels where kind='direct';
select name, unread from public.my_channels();
select kind, title from public.global_search('Campagne');
reset role;

-- ===== CMO approuve le congé (responsable du Marketing, développeur dans MKT-ACQ)
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select count(*) as cmo_sees_leave from leave_requests;
update leave_requests set status='approved', decision_note='Bon repos' where status='pending';
select name, unread from public.my_channels() where kind='direct';
reset role;
select status, approver_id is not null as has_approver from leave_requests;
select profile_id = '00000000-0000-0000-0000-00000000000d' as to_dev, title from notifications order by created_at;

-- ===== Changement de responsable : l'historique est conservé, les droits suivent
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select public.appoint_member((select id from org_units where code='MKT'), '00000000-0000-0000-0000-00000000000d', 'head', 'CMO par intérim');
reset role;
select p.email, m.role, m.start_date, m.end_date from unit_memberships m join profiles p on p.id=m.profile_id
 where m.unit_id=(select id from org_units where code='MKT') order by m.created_at;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select public.has_perm('unit.manage', (select id from org_units where code='MKT')) as ancien_cmo_encore_manager;
reset role;

-- ===== Opportunité gagnée -> client + projet + facture
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
insert into accounts (name, type, country) values ('Ministère du Numérique', 'prospect', 'BJ');
insert into opportunities (account_id, name, amount, stage, product) select id, 'Plateforme e-éducation', 25000000, 'negotiation', 'iSkul' from accounts;
update opportunities set stage = 'won';
select a.type, o.probability, o.project_id is not null as projet, i.number, i.subtotal, i.total, i.status from opportunities o join accounts a on a.id=o.account_id join invoices i on i.opportunity_id=o.id;
update invoices set status='paid';
select type, amount, reference from transactions where invoice_id is not null;
insert into product_metrics (metric_date, active_users, new_users) values (current_date - 31, 10000, 500), (current_date, 12500, 700);
select jsonb_pretty(public.exec_dashboard()->'kpis');
select public.unit_overview((select id from org_units where code='MKT'));
reset role;

-- ===== Dépendances et validation
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
insert into projects (name, status) values ('Lancement VERIION OS', 'active');
insert into tasks (project_id, title, requires_validation) select id, 'A - Socle', true from projects where name='Lancement VERIION OS';
insert into tasks (project_id, title, requires_validation) select id, 'B - Modules', false from projects where name='Lancement VERIION OS';
insert into task_dependencies select b.id, a.id from tasks a, tasks b where a.title='A - Socle' and b.title='B - Modules';
do $$ begin
  update tasks set status='in_progress' where title='B - Modules';
  raise exception 'ERREUR';
exception when raise_exception then
  if sqlerrm like 'Tâche bloquée%' then raise notice 'OK : %', sqlerrm; else raise; end if;
end $$;
update tasks set status='done' where title='A - Socle';
update tasks set status='in_progress' where title='B - Modules';
select title, status, validated_by is not null as validated, completed_at is not null as completed from tasks where project_id is not null order by title;
reset role;

select count(*) as audit_entries, count(distinct table_name) as audited_tables from audit_log;
-- Offboarding
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select public.offboard_employee('00000000-0000-0000-0000-00000000000d');
reset role;
select status from profiles where email='yann.dev@veriion.com';
select count(*) as grants_after_offboarding from role_grants where profile_id='00000000-0000-0000-0000-00000000000d';
