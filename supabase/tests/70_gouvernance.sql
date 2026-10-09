\set ON_ERROR_STOP 1
-- Gouvernance : les six contournements relevés par l'audit du 9 octobre 2026
-- (docs/audit/poc_gouvernance.sql) doivent tous être refusés, et les circuits
-- normaux continuer de fonctionner.
insert into auth.users (id, email) values
 ('00000000-0000-0000-0000-0000000000a1', 'ceo.x@veriion.com'),
 ('00000000-0000-0000-0000-0000000000b1', 'admin.un@veriion.com'),
 ('00000000-0000-0000-0000-0000000000b2', 'admin.deux@veriion.com'),
 ('00000000-0000-0000-0000-0000000000c1', 'cfo.x@veriion.com'),
 ('00000000-0000-0000-0000-0000000000d1', 'lead.x@veriion.com'),
 ('00000000-0000-0000-0000-0000000000e1', 'dev.x@veriion.com');
update profiles set system_role = 'admin' where email like 'admin.%';

create or replace function pg_temp.as_user(u text, aal text default 'aal2') returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', u, false);
  perform set_config('request.jwt.claims', json_build_object('aal', aal)::text, false);
  execute 'set role authenticated';
end $$;

select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.appoint_member((select id from org_units where code = 'FIN'), '00000000-0000-0000-0000-0000000000c1', 'head');
insert into projects (id, name, owner_id) values ('11111111-1111-1111-1111-111111111111', 'Projet', '00000000-0000-0000-0000-0000000000a1');
insert into project_members values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-0000000000d1', 'lead'),
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-0000000000e1', 'member');
reset role;

-- ── P1 : le titulaire ne lève pas la vérification de sa tâche ─────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tasks (id, project_id, title, assignee_id)
values ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Livrable', '00000000-0000-0000-0000-0000000000e1');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000e1');
do $$ begin
  update tasks set requires_validation = false, status = 'done' where id = '22222222-2222-2222-2222-222222222222';
  raise exception 'ERREUR: P1 — tâche close sans vérification';
exception when insufficient_privilege then raise notice 'OK : P1 — le titulaire ne lève pas la vérification';
end $$;
do $$ begin
  update tasks set reviewer_id = auth.uid() where id = '22222222-2222-2222-2222-222222222222';
  raise exception 'ERREUR: P1 — le titulaire se désigne vérificateur';
exception when insufficient_privilege then raise notice 'OK : P1 — le titulaire ne se désigne pas vérificateur';
end $$;
select public.submit_task('22222222-2222-2222-2222-222222222222', 'Prêt');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000d1');
select public.review_task('22222222-2222-2222-2222-222222222222', true, 'Bon travail');
reset role;
do $$ begin
  if (select status from tasks where id = '22222222-2222-2222-2222-222222222222') <> 'done' then
    raise exception 'ERREUR: la soumission puis la validation ne ferment plus la tâche';
  end if;
  raise notice 'OK : soumission et validation fonctionnent toujours';
end $$;

-- ── P2 : un administrateur ne touche pas au seuil ─────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
update governance_settings set ceo_approval_threshold = 999999999999 where id;
reset role;
do $$ begin
  if public.ceo_approval_threshold() <> 500000 then raise exception 'ERREUR: P2 — seuil modifié par un administrateur'; end if;
  raise notice 'OK : P2 — le seuil n''est modifiable que par le CEO';
end $$;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'aal1');
update governance_settings set ceo_approval_threshold = 1 where id;
reset role;
do $$ begin
  if public.ceo_approval_threshold() <> 500000 then raise exception 'ERREUR: seuil modifié sans double authentification'; end if;
  raise notice 'OK : le CEO lui-même doit avoir validé sa double authentification';
end $$;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
update governance_settings set ceo_approval_threshold = 600000 where id;
reset role;
do $$ begin
  if public.ceo_approval_threshold() <> 600000 then raise exception 'ERREUR: le CEO ne peut pas régler le seuil'; end if;
  raise notice 'OK : le CEO règle le seuil';
end $$;
update governance_settings set ceo_approval_threshold = 500000 where id;

-- ── P3 : un administrateur ne suspend pas le CEO ──────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
do $$ begin
  update profiles set status = 'suspended' where email = 'ceo.x@veriion.com';
  raise exception 'ERREUR: P3 — CEO suspendu par un administrateur';
exception when insufficient_privilege then raise notice 'OK : P3 — le CEO n''est pas suspendable par un administrateur';
end $$;
do $$ begin
  perform public.offboard_employee('00000000-0000-0000-0000-0000000000a1');
  raise exception 'ERREUR: P3 — départ du CEO prononcé par un administrateur';
exception when insufficient_privilege then raise notice 'OK : P3 — pas de départ forcé du CEO';
end $$;
reset role;

-- ── P4 : un accord porte sur un montant figé ──────────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
insert into budgets (id, unit_id, fiscal_year, amount) values ('33333333-3333-3333-3333-333333333333', (select id from org_units where code = 'FIN'), 2027, 1000000);
select public.request_approval('budget', '33333333-3333-3333-3333-333333333333', 'Petit budget', 10);
do $$ begin
  if (select subject_label from approval_requests where kind = 'budget') not like 'Budget 2027%'
     or (select amount from approval_requests where kind = 'budget') <> 1000000 then
    raise exception 'ERREUR: libellé ou montant de la demande fournis par le demandeur';
  end if;
  raise notice 'OK : libellé et montant de la demande dérivés du budget lui-même';
end $$;
do $$ begin
  update budgets set amount = 2000000 where id = '33333333-3333-3333-3333-333333333333';
  raise exception 'ERREUR: budget modifié pendant l''attente de la décision';
exception when insufficient_privilege then raise notice 'OK : contenu gelé pendant l''attente';
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.decide_approval((select id from approval_requests where kind = 'budget'), true, 'ok');
reset role;
do $$ begin
  if (select status from budgets where id = '33333333-3333-3333-3333-333333333333') <> 'active' then
    raise exception 'ERREUR: l''accord n''a pas activé le budget';
  end if;
  raise notice 'OK : l''accord active le budget';
end $$;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
do $$ begin
  update budgets set amount = 900000000 where id = '33333333-3333-3333-3333-333333333333';
  raise exception 'ERREUR: P4 — budget gonflé après accord';
exception when insufficient_privilege then raise notice 'OK : P4 — un budget approuvé ne se gonfle pas';
end $$;
reset role;

-- ── P5 : un accord de dépense se consomme ─────────────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
select public.request_approval('expense', null, 'Serveurs', 2000000);
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.decide_approval((select id from approval_requests where kind = 'expense'), true, 'ok');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
insert into transactions (type, amount, approval_id) values ('expense', 1500000, (select id from approval_requests where kind = 'expense'));
do $$ begin
  insert into transactions (type, amount, approval_id) values ('expense', 1500000, (select id from approval_requests where kind = 'expense'));
  raise exception 'ERREUR: P5 — accord réutilisé au-delà de son montant';
exception when insufficient_privilege then raise notice 'OK : P5 — un accord ne couvre pas plus que son montant';
end $$;
insert into transactions (type, amount, approval_id) values ('expense', 500000, (select id from approval_requests where kind = 'expense'));
reset role;
do $$ begin
  if (select consumed_amount from approval_requests where kind = 'expense') <> 2000000 then
    raise exception 'ERREUR: consommation de l''accord mal comptée';
  end if;
  raise notice 'OK : le solde consommé de l''accord est tenu';
end $$;

-- ── P6 : dérogations réservées et séparation des tâches ───────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
do $$ begin
  insert into role_grants (profile_id, permission, source, reason, granted_by, expires_at)
  values ('00000000-0000-0000-0000-0000000000b2', 'approvals.decide', 'manual', 'intérim direction', auth.uid(), now() + interval '7 days');
  raise exception 'ERREUR: P6 — un administrateur délègue la décision du CEO';
exception when insufficient_privilege then raise notice 'OK : P6 — permission réservée refusée à l''administrateur';
end $$;
do $$ begin
  insert into role_grants (profile_id, permission, source, reason, granted_by)
  values ('00000000-0000-0000-0000-0000000000b2', 'crm.view', 'manual', 'mission CRM', auth.uid());
  raise exception 'ERREUR: dérogation sans échéance';
exception when insufficient_privilege then raise notice 'OK : toute dérogation a une échéance';
end $$;
insert into role_grants (profile_id, permission, source, reason, granted_by, expires_at)
values ('00000000-0000-0000-0000-0000000000b2', 'crm.view', 'manual', 'mission CRM', auth.uid(), now() + interval '30 days');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
insert into role_grants (profile_id, permission, source, reason, granted_by, expires_at)
values ('00000000-0000-0000-0000-0000000000b2', 'approvals.decide', 'manual', 'intérim direction', auth.uid(), now() + interval '7 days');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2');
select public.request_approval('other', null, 'Ma propre demande', 10);
do $$ begin
  perform public.decide_approval((select id from approval_requests where subject_label = 'Ma propre demande'), true, null);
  raise exception 'ERREUR: P6 — auto-approbation';
exception when insufficient_privilege then raise notice 'OK : P6 — pas de décision sur sa propre demande';
end $$;
reset role;

-- ── Décision directe du CEO : tracée ──────────────────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
update projects set status = 'active' where id = '11111111-1111-1111-1111-111111111111';
reset role;
do $$ begin
  if not exists (select 1 from approval_requests where kind = 'project' and direct_decision and status = 'approved') then
    raise exception 'ERREUR: la décision directe du CEO n''est pas tracée';
  end if;
  raise notice 'OK : décision directe du CEO inscrite au registre';
end $$;

-- ── Double authentification : niveau aal1 refusé pour la finance ──────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1', 'aal1');
do $$ begin
  insert into transactions (type, amount) values ('expense', 1000);
  raise exception 'ERREUR: écriture financière sans double authentification';
exception when insufficient_privilege then raise notice 'OK : écriture financière refusée sans double authentification';
end $$;
reset role;

-- ── Le registre des validations ne s'écrit pas directement ────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
do $$ begin
  insert into approval_requests (kind, subject_label, status) values ('expense', 'Faux accord', 'approved');
  raise exception 'ERREUR: accord inscrit directement';
exception when insufficient_privilege then raise notice 'OK : aucun accord ne s''inscrit hors des fonctions';
end $$;
reset role;

-- ── Le hachage des codes d'accès n'est accordé à personne ─────────────────
do $$ begin
  if has_table_privilege('authenticated', 'public.access_codes', 'select')
     or has_table_privilege('anon', 'public.governance_settings', 'select') then
    raise exception 'ERREUR: privilèges implicites encore présents';
  end if;
  raise notice 'OK : aucun privilège implicite sur les tables sensibles';
end $$;
