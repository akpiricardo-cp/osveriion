\set ON_ERROR_STOP 1
-- Socle transverse : événements, graphe d'objets, moteur de workflows,
-- boîte « À traiter », documents générés et registre des actes.
insert into auth.users (id, email) values
 ('00000000-0000-0000-0000-0000000000a1', 'ceo.x@veriion.com'),
 ('00000000-0000-0000-0000-0000000000c1', 'cfo.x@veriion.com'),
 ('00000000-0000-0000-0000-0000000000d1', 'lead.x@veriion.com'),
 ('00000000-0000-0000-0000-0000000000e1', 'dev.x@veriion.com'),
 ('00000000-0000-0000-0000-0000000000f1', 'juriste.x@veriion.com'),
 ('00000000-0000-0000-0000-0000000000b1', 'dga.x@veriion.com');

create or replace function pg_temp.as_user(u text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', u, false);
  perform set_config('request.jwt.claims', '{"aal":"aal2"}', false);
  execute 'set role authenticated';
end $$;

select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.appoint_member((select id from org_units where code = 'FIN'), '00000000-0000-0000-0000-0000000000c1', 'head');
select public.appoint_member((select id from org_units where code = 'LEG'), '00000000-0000-0000-0000-0000000000f1', 'head');
select public.appoint_member((select id from org_units where code = 'TECH'), '00000000-0000-0000-0000-0000000000d1', 'head');
select public.appoint_member((select id from org_units where code = 'TECH-DEV'), '00000000-0000-0000-0000-0000000000e1', 'member');
insert into projects (id, name, owner_id, lead_id, unit_id) values ('11111111-1111-1111-1111-111111111111', 'Oniix', auth.uid(), '00000000-0000-0000-0000-0000000000d1', (select id from org_units where code = 'TECH'));
reset role;

-- ── Événements et graphe : un contrat et une dépense se rattachent au projet ──
select pg_temp.as_user('00000000-0000-0000-0000-0000000000f1');
insert into legal_contracts (id, title, type, counterparty, amount, project_id)
values ('66666666-6666-6666-6666-666666666666', 'Hébergement', 'supplier', 'Cloud SA', 300000, '11111111-1111-1111-1111-111111111111');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
insert into transactions (type, amount, category, project_id) values ('expense', 250000, 'Infrastructure', '11111111-1111-1111-1111-111111111111');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000d1');
do $$ declare n int; begin
  select count(*) into n from public.object_context('project', '11111111-1111-1111-1111-111111111111')
   where other_type in ('contract', 'transaction');
  if n <> 1 then raise exception 'ERREUR: le chef de projet devrait voir le contrat (lien) mais pas l''opération financière (vu %)', n; end if;
  raise notice 'OK : la fiche projet montre ce que son lecteur a le droit de voir (contrat oui, finance non)';
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
do $$ declare n int; begin
  select count(*) into n from public.object_context('project', '11111111-1111-1111-1111-111111111111')
   where other_type in ('contract', 'transaction', 'unit', 'person');
  if n < 4 then raise exception 'ERREUR: contexte projet incomplet pour le CEO (%)', n; end if;
  if not exists (select 1 from public.object_timeline('project', '11111111-1111-1111-1111-111111111111') where type = 'contract.drafted') then
    raise exception 'ERREUR: la chronologie du projet n''inclut pas le contrat lié';
  end if;
  raise notice 'OK : contexte et chronologie du projet (contrat, dépense, unité, chef de projet)';
end $$;
select public.link_objects('project', '11111111-1111-1111-1111-111111111111', 'concerne', 'person', '00000000-0000-0000-0000-0000000000e1', 'Référent technique');
reset role;
do $$ begin
  update domain_events set summary = 'falsifié';
  raise exception 'ERREUR: journal modifiable';
exception when insufficient_privilege then raise notice 'OK : le journal des événements est immuable';
end $$;

-- ── Circuit à deux étapes : finance, puis CEO au-delà d'un million ───────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.save_workflow('expense', 'Dépense : finance puis CEO', '[
  {"name": "Visa de la finance", "approver_type": "permission", "approver_permission": "finance.admin", "sla_hours": 24},
  {"name": "Décision du CEO", "approver_type": "ceo", "min_amount": 1000000, "sla_hours": 48}]'::jsonb) is not null as circuit;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000d1');
select public.request_approval('expense', null, 'Licences', 400000) is not null as petite;
select public.request_approval('expense', null, 'Serveurs', 3000000) is not null as grosse;
do $$ begin
  perform public.decide_approval((select id from approval_requests where subject_label = 'Serveurs'), true, null);
  raise exception 'ERREUR: le demandeur a statué';
exception when insufficient_privilege then raise notice 'OK : pas de décision sur sa propre demande';
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
do $$ begin
  -- Le CEO peut agir à toute étape « permission » ; on vérifie surtout que la finance est sollicitée d'abord.
  if (select current_step from approval_requests where subject_label = 'Serveurs') <> 1 then raise exception 'ERREUR: étape initiale'; end if;
  raise notice 'OK : la demande démarre à l''étape « Visa de la finance »';
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
do $$ begin
  if not exists (select 1 from public.my_inbox() where kind = 'decision' and title = 'Serveurs') then
    raise exception 'ERREUR: la décision n''apparaît pas dans la boîte du CFO';
  end if;
  raise notice 'OK : la boîte « À traiter » du CFO contient la décision attendue';
end $$;
select public.decide_approval((select id from approval_requests where subject_label = 'Licences'), true, 'Visa');
select public.decide_approval((select id from approval_requests where subject_label = 'Serveurs'), true, 'Visa');
do $$ begin
  perform public.decide_approval((select id from approval_requests where subject_label = 'Serveurs'), true, 'encore');
  raise exception 'ERREUR: le CFO décide aussi l''étape du CEO';
exception when insufficient_privilege then raise notice 'OK : l''étape du CEO ne revient pas au CFO';
end $$;
reset role;
do $$ begin
  if (select status from approval_requests where subject_label = 'Licences') <> 'approved' then
    raise exception 'ERREUR: sous le seuil, le visa de la finance suffit';
  end if;
  if (select status from approval_requests where subject_label = 'Serveurs') <> 'pending'
     or (select current_step from approval_requests where subject_label = 'Serveurs') <> 2 then
    raise exception 'ERREUR: au-delà du seuil, la demande doit passer au CEO';
  end if;
  raise notice 'OK : étape à seuil — finance seule sous 1 M, puis CEO au-delà';
end $$;

-- ── Intérim : le CEO délègue pendant son absence ──────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
insert into approval_delegations (to_profile, ends_on, reason) values ('00000000-0000-0000-0000-0000000000b1', current_date + 7, 'Mission à l''étranger');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
select public.decide_approval((select id from approval_requests where subject_label = 'Serveurs'), true, 'Accordé en intérim');
reset role;
do $$ begin
  if (select status from approval_requests where subject_label = 'Serveurs') <> 'approved'
     or not exists (select 1 from workflow_actions where on_behalf_of = '00000000-0000-0000-0000-0000000000a1') then
    raise exception 'ERREUR: décision par intérim non tracée';
  end if;
  raise notice 'OK : décision prise en intérim, au nom du CEO, tracée';
end $$;

-- ── Délais : relance et escalade ──────────────────────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000d1');
select public.request_approval('expense', null, 'Formation', 200000) is not null;
reset role;
update approval_requests set step_started_at = now() - interval '3 days' where subject_label = 'Formation';
select public.process_workflow_sla() as relances;
do $$ begin
  if not exists (select 1 from workflow_actions w join approval_requests a on a.id = w.request_id where a.subject_label = 'Formation' and w.action = 'escalate')
     or not exists (select 1 from notifications where kind = 'approval.overdue') then
    raise exception 'ERREUR: dépassement de délai non signalé';
  end if;
  raise notice 'OK : un délai dépassé relance les décideurs et alerte le CEO';
end $$;

-- ── Congés : décidés par le circuit, jamais en direct ─────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000e1');
insert into leave_requests (start_date, end_date, type) values (current_date + 10, current_date + 12, 'annual');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000d1');
do $$ begin
  update leave_requests set status = 'approved';
  raise exception 'ERREUR: congé approuvé hors circuit';
exception when insufficient_privilege then raise notice 'OK : un congé ne s''approuve que par le circuit';
end $$;
select public.decide_approval((select id from approval_requests where kind = 'leave'), true, 'Bon repos');
reset role;
do $$ begin
  if (select status from leave_requests) <> 'approved' then raise exception 'ERREUR: congé non appliqué'; end if;
  raise notice 'OK : le responsable approuve le congé par le circuit';
end $$;

-- ── Nomination → décision générée, inscrite au registre des actes ─────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.appoint_member((select id from org_units where code = 'OPS'), '00000000-0000-0000-0000-0000000000b1', 'head');
reset role;
select public.process_event_jobs();
do $$ declare j record; v_doc uuid; begin
  select * into j from public.claim_document_jobs(10) where subject_id = '00000000-0000-0000-0000-0000000000b1';
  if j.job_id is null then raise exception 'ERREUR: la nomination n''a pas déclenché sa décision'; end if;
  if j.context->'nomination'->>'role' <> 'responsable' or j.context->'personne'->>'nom_complet' is null then
    raise exception 'ERREUR: données de la décision incomplètes';
  end if;
  v_doc := public.complete_document_job(j.job_id, 'actes/HOLD/test.docx', 'decision.docx', 1234, repeat('a', 64), 'Décision');
  if not exists (select 1 from acts_register where reference like 'ACT-HOLD-%-0001' and document_id = v_doc) then
    raise exception 'ERREUR: acte non inscrit au registre';
  end if;
  raise notice 'OK : la nomination produit sa décision, numérotée au registre des actes';
end $$;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
do $$ begin
  if not exists (select 1 from documents where title like 'Décision de nomination%') then
    raise exception 'ERREUR: la personne nommée ne voit pas sa décision';
  end if;
  if not exists (select 1 from acts_register) then raise exception 'ERREUR: la personne nommée ne voit pas son acte'; end if;
  raise notice 'OK : la personne nommée reçoit et voit sa décision';
end $$;
reset role;
do $$ begin
  update acts_register set reference = 'X';
  raise exception 'ERREUR: registre des actes modifiable';
exception when insufficient_privilege then raise notice 'OK : le registre des actes est immuable';
end $$;

-- ── Gel juridique ─────────────────────────────────────────────────────────
select id as held_doc from documents where title like 'Décision de nomination%' \gset
select pg_temp.as_user('00000000-0000-0000-0000-0000000000f1');
select public.set_legal_hold(:'held_doc', true, 'Contentieux prud''homal');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
do $$ begin
  perform public.trash_item(null, (select id from documents where title like 'Décision de nomination%' and legal_hold));
  raise exception 'ERREUR: document gelé mis à la corbeille';
exception when others then
  if sqlerrm like 'ERREUR%' then raise; end if;
  raise notice 'OK : un document sous gel juridique ne se supprime pas';
end $$;
reset role;
