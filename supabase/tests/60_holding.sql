\set ON_ERROR_STOP 1
-- Holding : intitulés automatiques, fusion d'unités, référents de projet,
-- calendrier opérationnel, validations du CEO, contrats et tâches vérifiées.
insert into auth.users (id, email) values
 ('00000000-0000-0000-0000-0000000000a1', 'awa.houngbo@veriion.com'),   -- premier compte => CEO
 ('00000000-0000-0000-0000-0000000000b1', 'koffi.adjovi@veriion.com'),  -- COO
 ('00000000-0000-0000-0000-0000000000c1', 'nadia.sossa@veriion.com'),   -- CFO
 ('00000000-0000-0000-0000-0000000000d1', 'yann.agbo@veriion.com'),     -- Chief Product
 ('00000000-0000-0000-0000-0000000000e1', 'eric.dossou@veriion.com'),   -- équipe projet
 ('00000000-0000-0000-0000-0000000000f1', 'lina.kpade@veriion.com');    -- juriste

create or replace function pg_temp.as_user(u text) returns void language plpgsql as $$
begin perform set_config('request.jwt.claim.sub', u, false); execute 'set role authenticated'; end $$;

-- ── Profil obligatoire : une fiche vide n'est pas complète ─────────────────
do $$ begin
  if (select profile_completed_at from public.profiles where email = 'koffi.adjovi@veriion.com') is not null then
    raise exception 'ERREUR: profil vide considéré comme complet';
  end if;
  raise notice 'OK : profil incomplet détecté';
end $$;
update public.profiles set phone = '+229 01 00 00 00 01', location = 'Cotonou, Bénin';
do $$ begin
  if (select count(*) from public.profiles where profile_completed_at is null) <> 0 then
    raise exception 'ERREUR: profil complet non reconnu';
  end if;
  raise notice 'OK : profil complet reconnu dès que les champs sont remplis';
end $$;

-- ── Nomination : l'intitulé vient de l'unité, pas de la saisie ─────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.appoint_member((select id from org_units where code = 'VRN'),  '00000000-0000-0000-0000-0000000000a1', 'head');
select public.appoint_member((select id from org_units where code = 'OPS'),  '00000000-0000-0000-0000-0000000000b1', 'head');
select public.appoint_member((select id from org_units where code = 'FIN'),  '00000000-0000-0000-0000-0000000000c1', 'head');
select public.appoint_member((select id from org_units where code = 'LEG'),  '00000000-0000-0000-0000-0000000000f1', 'head');
select public.appoint_member((select id from org_units where code = 'TECH'), '00000000-0000-0000-0000-0000000000e1', 'member');
reset role;

select email, job_title from public.profiles
 where email in ('awa.houngbo@veriion.com', 'koffi.adjovi@veriion.com', 'nadia.sossa@veriion.com')
 order by email;
do $$ begin
  if (select job_title from public.profiles where email = 'nadia.sossa@veriion.com') not like 'CFO%' then
    raise exception 'ERREUR: intitulé du CFO non attribué automatiquement';
  end if;
  raise notice 'OK : intitulé de poste attribué à la nomination';
end $$;

-- Les droits du domaine suivent : le COO planifie, le juriste administre le registre.
do $$ begin
  if not exists (select 1 from role_grants where profile_id = '00000000-0000-0000-0000-0000000000b1' and permission = 'ops.plan') then
    raise exception 'ERREUR: le COO n''a pas reçu ops.plan';
  end if;
  if not exists (select 1 from role_grants where profile_id = '00000000-0000-0000-0000-0000000000f1' and permission = 'legal.admin') then
    raise exception 'ERREUR: le juriste n''a pas reçu legal.admin';
  end if;
  raise notice 'OK : droits automatiques des domaines Opérations et Juridique';
end $$;

-- ── Projet : Chief Product et référents départementaux ────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.projects (name, description, owner_id, lead_id, status)
values ('Oniix', 'Plateforme de gestion scolaire', auth.uid(), '00000000-0000-0000-0000-0000000000d1', 'planned');

do $$ begin
  if (select job_title from public.profiles where email = 'yann.agbo@veriion.com') <> 'Chief Product — Oniix' then
    raise exception 'ERREUR: intitulé du chef de projet non appliqué';
  end if;
  if not exists (select 1 from project_members m join projects p on p.id = m.project_id
                  where p.name = 'Oniix' and m.profile_id = '00000000-0000-0000-0000-0000000000d1' and m.role = 'lead') then
    raise exception 'ERREUR: le chef de projet n''est pas membre de son projet';
  end if;
  raise notice 'OK : Chief Product nommé, intitulé et équipe synchronisés';
end $$;

-- La finance désigne son référent : il rejoint le canal et voit le projet.
insert into public.project_liaisons (project_id, unit_id, profile_id, note)
select p.id, u.id, '00000000-0000-0000-0000-0000000000c1', 'Suivi budgétaire mensuel'
from public.projects p, public.org_units u where p.name = 'Oniix' and u.code = 'FIN';
reset role;

do $$ begin
  if not exists (
    select 1 from channel_members m join channels c on c.id = m.channel_id join projects p on p.id = c.project_id
     where p.name = 'Oniix' and m.profile_id = '00000000-0000-0000-0000-0000000000c1') then
    raise exception 'ERREUR: le référent n''a pas rejoint le canal du projet';
  end if;
  raise notice 'OK : le référent rejoint le canal du projet';
end $$;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
select public.can_view_project((select id from projects where name = 'Oniix')) as referent_voit_le_projet;
reset role;

-- ── Lancement du projet : accord du CEO ───────────────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000d1');
do $$ begin
  update public.projects set status = 'active' where name = 'Oniix';
  raise exception 'ERREUR: projet lancé sans accord du CEO';
exception when insufficient_privilege then raise notice 'OK : lancement de projet bloqué sans accord du CEO';
end $$;
select public.request_approval('project', (select id from projects where name = 'Oniix'), 'Lancement du projet Oniix') is not null as demande_creee;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
do $$ declare a uuid; begin
  select id into a from approval_requests where kind = 'project' and status = 'pending';
  begin
    perform public.decide_approval(a, false);
    raise exception 'ERREUR: refus accepté sans motif';
  exception when others then
    if sqlerrm like 'ERREUR%' then raise; end if;
    raise notice 'OK : un refus doit être motivé';
  end;
  perform public.decide_approval(a, true, 'Budget confirmé, équipe en place.');
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000d1');
update public.projects set status = 'active' where name = 'Oniix';
select status from public.projects where name = 'Oniix';
reset role;

-- ── Calendrier opérationnel : écrit par les Opérations, visé par le CEO ───
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
insert into public.operation_cycles (project_id, kind, period_start, period_end, title, focus)
select id, 'monthly', date_trunc('month', current_date)::date, (date_trunc('month', current_date) + interval '1 month - 1 day')::date,
       'Mois 1 — ouverture de la bêta', 'Ouvrir l''inscription aux 500 premiers établissements'
from public.projects where name = 'Oniix';

do $$ begin
  perform public.publish_operation_cycle((select id from operation_cycles limit 1));
  raise exception 'ERREUR: calendrier vide publié';
exception when others then
  if sqlerrm like 'ERREUR%' then raise; end if;
  raise notice 'OK : un calendrier sans grande ligne ne se publie pas';
end $$;

insert into public.operation_items (cycle_id, title, expected_outcome, due_date)
select id, 'Ouvrir les inscriptions', '500 établissements inscrits', current_date + 20 from public.operation_cycles limit 1;
select public.publish_operation_cycle((select id from operation_cycles limit 1));
select status from public.operation_cycles;   -- pending_ceo : le mensuel passe par le CEO
reset role;

select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.decide_approval((select id from approval_requests where kind = 'operation_cycle' and status = 'pending'), true, 'Cap validé.');
reset role;
do $$ begin
  if (select status from public.operation_cycles) <> 'published' then
    raise exception 'ERREUR: l''accord du CEO n''a pas publié le calendrier';
  end if;
  raise notice 'OK : l''accord du CEO publie le calendrier au projet';
end $$;

-- ── Tâches : répartition hiérarchique et vérification ─────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.project_members (project_id, profile_id, role)
select id, '00000000-0000-0000-0000-0000000000e1', 'member' from public.projects where name = 'Oniix';

insert into public.tasks (title, project_id, assignee_id, reporter_id, operation_item_id, status)
select 'Préparer le formulaire d''inscription', p.id, '00000000-0000-0000-0000-0000000000e1', auth.uid(), i.id, 'todo'
from public.projects p, public.operation_items i where p.name = 'Oniix';

do $$ begin
  if not (select requires_validation from public.tasks limit 1) then
    raise exception 'ERREUR: une tâche confiée à autrui devrait exiger une vérification';
  end if;
  raise notice 'OK : tâche confiée => vérification exigée, vérificateur = celui qui assigne';
end $$;
reset role;

-- Un membre ne confie pas de tâche en dehors de son périmètre.
select pg_temp.as_user('00000000-0000-0000-0000-0000000000e1');
do $$ begin
  insert into public.tasks (title, project_id, assignee_id, reporter_id)
  select 'Refaire le budget', id, '00000000-0000-0000-0000-0000000000c1', auth.uid() from public.projects where name = 'Oniix';
  raise exception 'ERREUR: assignation hors périmètre acceptée';
exception when insufficient_privilege then raise notice 'OK : on ne confie une tâche qu''à soi-même ou à son équipe';
end $$;

-- Le titulaire ne clôt pas lui-même : il soumet.
do $$ begin
  update public.tasks set status = 'done' where assignee_id = auth.uid();
  raise exception 'ERREUR: tâche close par son titulaire sans vérification';
exception when others then
  if sqlerrm like 'ERREUR%' then raise; end if;
  raise notice 'OK : le titulaire ne clôt pas une tâche soumise à vérification';
end $$;
select public.submit_task((select id from public.tasks where assignee_id = auth.uid()), 'Formulaire en ligne, testé sur mobile.');
select status, submitted_at is not null as soumise from public.tasks;

do $$ begin
  perform public.review_task((select id from public.tasks), true);
  raise exception 'ERREUR: le titulaire a validé sa propre tâche';
exception when insufficient_privilege then raise notice 'OK : la vérification revient à celui qui a confié la tâche';
end $$;
reset role;

select pg_temp.as_user('00000000-0000-0000-0000-0000000000d1');
select public.review_task((select id from public.tasks), false, 'Ajouter la validation du numéro de téléphone.');
select status, review_note from public.tasks;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000e1');
select public.submit_task((select id from public.tasks where assignee_id = auth.uid()));
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000d1');
select public.review_task((select id from public.tasks), true, 'Conforme.');
do $$ begin
  if (select status from public.tasks) <> 'done' or (select validated_by from public.tasks) is null then
    raise exception 'ERREUR: la validation n''a pas clôturé la tâche';
  end if;
  raise notice 'OK : renvoi puis validation — la tâche est close par son vérificateur';
end $$;

-- ── Rapport de cycle aux Opérations ───────────────────────────────────────
select public.submit_operation_report((select id from operation_cycles), 80, 'Inscriptions ouvertes, 320 établissements à ce jour.', 'Lenteur du serveur SMS.', 'Campagne de relance.') is not null as rapport_transmis;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
select public.acknowledge_operation_report((select id from operation_reports), 'Bien reçu, on renforce le SMS.');
select status, reviewed_by is not null as accuse from public.operation_reports;
reset role;

-- ── Dépense au-dessus du seuil : accord du CEO obligatoire ────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
do $$ begin
  insert into public.transactions (type, amount, category, description)
  values ('expense', 2000000, 'Infrastructure cloud', 'Serveurs de production');
  raise exception 'ERREUR: dépense au-dessus du seuil enregistrée sans accord';
exception when insufficient_privilege then raise notice 'OK : dépense au-dessus du seuil bloquée sans accord du CEO';
end $$;
select public.request_approval('expense', gen_random_uuid(), 'Serveurs de production', 2500000, 'Capacité doublée pour la bêta') as demande;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.decide_approval((select id from approval_requests where kind = 'expense' and status = 'pending'), true, 'Accordé.');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
insert into public.transactions (type, amount, category, description, approval_id)
values ('expense', 2000000, 'Infrastructure cloud', 'Serveurs de production',
        (select id from approval_requests where kind = 'expense' and status = 'approved'));
select count(*) as depense_enregistree from public.transactions;
-- Une dépense sous le seuil ne demande rien.
insert into public.transactions (type, amount, category, description) values ('expense', 120000, 'Logiciels', 'Licences');
reset role;

-- ── Juridique : pas de signature sans accord du CEO ───────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000f1');
insert into public.legal_contracts (title, type, counterparty, amount, end_date)
values ('Hébergement cloud 2026', 'supplier', 'Cloud Afrique SA', 9000000, current_date + 365);
do $$ begin
  update public.legal_contracts set status = 'active';
  raise exception 'ERREUR: contrat signé sans accord du CEO';
exception when insufficient_privilege then raise notice 'OK : signature de contrat bloquée sans accord du CEO';
end $$;
select public.submit_contract_for_signature((select id from legal_contracts), 'Renouvellement annuel') is not null as soumis;
select status from public.legal_contracts;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.decide_approval((select id from approval_requests where kind = 'legal_contract' and status = 'pending'), true, 'Signé.');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000f1');
update public.legal_contracts set status = 'active';
select status, signed_on is not null as date_de_signature from public.legal_contracts;
reset role;

-- ── Fusion de deux départements ───────────────────────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select public.merge_org_units((select id from org_units where code = 'BIZ'), (select id from org_units where code = 'MKT'));
reset role;
do $$ declare mkt uuid; begin
  select id into mkt from public.org_units where code = 'MKT';
  if (select archived_at from public.org_units where code = 'BIZ') is null then
    raise exception 'ERREUR: l''unité absorbée n''a pas été archivée';
  end if;
  if exists (select 1 from public.org_units where code = 'BIZ-COM' and parent_id <> mkt) then
    raise exception 'ERREUR: les sous-unités n''ont pas suivi la fusion';
  end if;
  raise notice 'OK : fusion — sous-unités déplacées, unité absorbée archivée';
end $$;

-- Impossible de fusionner un parent dans son propre descendant.
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
do $$ begin
  perform public.merge_org_units((select id from org_units where code = 'MKT'), (select id from org_units where code = 'MKT-ACQ'));
  raise exception 'ERREUR: fusion circulaire acceptée';
exception when others then
  if sqlerrm like 'ERREUR%' then raise; end if;
  raise notice 'OK : fusion circulaire refusée';
end $$;
reset role;
