\set ON_ERROR_STOP 1
-- Suite de 30_drive_messaging.sql (mêmes personnes) : co-édition et notifications
insert into auth.users (id, email) values
 ('00000000-0000-0000-0000-00000000000a', 'awa.houngbo@veriion.com'),
 ('00000000-0000-0000-0000-0000000000b1', 'koffi.adjovi@veriion.com'),
 ('00000000-0000-0000-0000-0000000000c1', 'nadia.sossa@veriion.com'),
 ('00000000-0000-0000-0000-0000000000d1', 'yann.agbo@veriion.com');
create or replace function pg_temp.as_user(u text) returns void language plpgsql as $$
begin perform set_config('request.jwt.claim.sub', u, false); perform set_config('request.jwt.claims', '{"aal":"aal2"}', false); execute 'set role authenticated'; end $$;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select public.appoint_member((select id from org_units where code='MKT'), '00000000-0000-0000-0000-0000000000c1', 'head', 'CMO');
select public.appoint_member((select id from org_units where code='MKT-ACQ'), '00000000-0000-0000-0000-0000000000d1', 'member');
reset role;

-- ── Co-édition : l'état Yjs suit le contenu ────────────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
insert into documents (title, kind, folder_id, owner_id, content)
select 'Plan co-édité', 'doc', id, auth.uid(), '{"type":"doc"}' from folders where is_root and space='unit' and unit_id=(select id from org_units where code='MKT');
select public.save_document_content((select id from documents where title='Plan co-édité'), '{"type":"doc","content":[]}', 'v1', null, false, null, 'AAEC') as rev_with_ydoc;
do $$ begin
  if (select count(*) from document_ydocs y join documents d on d.id=y.document_id where d.title='Plan co-édité' and y.revision=d.revision) <> 1 then raise exception 'ERREUR: état Yjs non enregistré'; end if;
  raise notice 'OK : état Yjs enregistré avec la révision';
end $$;
-- Yann (membre du département) lit l'état ; Koffi (autre département) non
select pg_temp.as_user('00000000-0000-0000-0000-0000000000d1');
select count(*) as yann_reads_ydoc from document_ydocs;
reset role;
insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000e1', 'eric.dossou@veriion.com');
select pg_temp.as_user('00000000-0000-0000-0000-0000000000e1');
select count(*) as outsider_reads_ydoc from document_ydocs;
reset role;
-- Un enregistrement sans état Yjs (import, ancien client) invalide l'état
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
select public.save_document_content((select id from documents where title='Plan co-édité'), '{"type":"doc"}', 'v2') as rev_without_ydoc;
do $$ begin
  if exists (select 1 from document_ydocs) then raise exception 'ERREUR: état Yjs périmé conservé'; end if;
  raise notice 'OK : état Yjs invalidé par une écriture externe';
end $$;
-- Écriture directe interdite
do $$ begin
  insert into document_ydocs (document_id, state, revision) select id, 'x', 1 from documents where title='Plan co-édité';
  raise exception 'ERREUR: écriture directe de l''état Yjs autorisée';
exception when insufficient_privilege then raise notice 'OK : état Yjs protégé en écriture';
end $$;
reset role;

-- ── Préférences et appareils : chacun les siens ────────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000d1');
insert into notification_preferences (email_mode, push_off) values ('digest', '{announcements}');
select public.register_push_subscription('https://fcm.googleapis.com/fcm/send/abc', 'p256', 'auth', 'Chrome · Android');
do $$ begin
  perform public.register_push_subscription('http://evil.example/x', 'p', 'a');
  raise exception 'ERREUR: endpoint non HTTPS accepté';
exception when others then if sqlerrm like 'ERREUR%' then raise; end if; raise notice 'OK : endpoint non HTTPS refusé';
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
select count(*) as nadia_sees_yann_prefs from notification_preferences;
select count(*) as nadia_sees_yann_devices from push_subscriptions;
do $$ begin
  perform public.claim_email_batch();
  raise exception 'ERREUR: file d''envoi accessible à un utilisateur';
exception when insufficient_privilege then raise notice 'OK : files d''envoi réservées au serveur';
end $$;
reset role;

-- ── Catégories, files d'envoi, rappels ─────────────────────────────────────
select kind, public.notification_category(kind) from (values ('message.mention'), ('task.review'), ('leave.requested'), ('reminder.meeting'), ('drive.shared'), ('announcement'), ('org.appointed')) v(kind);
insert into notifications (profile_id, kind, title, created_at) values
  ('00000000-0000-0000-0000-0000000000c1', 'task.assigned', 'Tâche A', now() - interval '5 minutes'),
  ('00000000-0000-0000-0000-0000000000c1', 'task.assigned', 'Tâche récente', now()),
  ('00000000-0000-0000-0000-0000000000d1', 'announcement', 'Annonce (Yann en résumé)', now() - interval '5 minutes');
select title from public.claim_email_batch() order by title;       -- Tâche A uniquement (récente : trop tôt ; Yann : résumé)
select count(*) as second_claim from public.claim_email_batch();    -- rien en double
select count(*) as push_claimed from public.claim_push_batch();
select count(*) as push_second from public.claim_push_batch();
update notification_preferences set digest_hour = 0;
select title from public.claim_digest_batch();                      -- l'annonce de Yann
select count(*) as digest_again from public.claim_digest_batch();   -- une fois par jour
-- rappels : une tâche en retard pour Yann, une réunion dans 10 minutes
insert into tasks (title, assignee_id, due_date, status) values ('Rapport en retard', '00000000-0000-0000-0000-0000000000d1', current_date - 2, 'todo');
insert into meetings (title, starts_at, ends_at, organizer_id) values ('Point hebdo', now() + interval '10 minutes', now() + interval '40 minutes', '00000000-0000-0000-0000-0000000000c1');
insert into meeting_attendees (meeting_id, profile_id) select id, '00000000-0000-0000-0000-0000000000d1' from meetings where title='Point hebdo';
select public.generate_daily_reminders() > 0 as daily_ok;
select public.remind_upcoming_meetings() as meeting_reminders;
select public.remind_upcoming_meetings() as meeting_reminders_again;
select p.first_name, n.kind, n.title from notifications n join profiles p on p.id=n.profile_id where n.kind like 'reminder.%' order by 1, 2;
