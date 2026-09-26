\set ON_ERROR_STOP 1
insert into auth.users (id, email) values
 ('00000000-0000-0000-0000-00000000000a', 'awa.houngbo@veriion.com'),
 ('00000000-0000-0000-0000-0000000000e1', 'eric.sales@veriion.com'),
 ('00000000-0000-0000-0000-0000000000e2', 'fatou.ops@veriion.com');
select full_name from profiles order by 1;
create or replace function pg_temp.as_user(u text) returns void language plpgsql as $$
begin perform set_config('request.jwt.claim.sub', u, false); execute 'set role authenticated'; end $$;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select public.appoint_member((select id from org_units where code='BIZ-COM'), '00000000-0000-0000-0000-0000000000e1', 'member');
select public.appoint_member((select id from org_units where code='OPS-PMO'), '00000000-0000-0000-0000-0000000000e2', 'member');
insert into objectives (level, title) values ('company', 'Atteindre 1 M d''utilisateurs') returning id, period;
insert into key_results (objective_id, title, start_value, target_value, current_value) select id, 'Utilisateurs actifs', 0, 1000000, 250000 from objectives;
select title, progress from objectives_progress;
insert into announcements (title, body) values ('Bienvenue sur VERIION OS', 'La plateforme interne est en ligne.') returning id;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000e1');
insert into accounts (name, country) values ('Orange Bénin', 'BJ') returning id, owner_id is not null as has_owner;
insert into contacts (account_id, first_name) select id, 'Jean' from accounts returning id;
insert into opportunities (account_id, name, amount) select id, 'Partenariat data', 1000 from accounts returning id, stage;
insert into interactions (account_id, subject, kind) select id, 'Appel de découverte', 'call' from accounts returning id;
insert into channels (name, is_private) values ('ventes-privé', true) returning id, kind;
insert into channel_members (channel_id, profile_id) select id, '00000000-0000-0000-0000-0000000000e2' from channels where name='ventes-privé' returning channel_id;
insert into projects (name) values ('Projet perso') returning id, code;
insert into tasks (project_id, title, assignee_id) select id, 'Tâche 1', '00000000-0000-0000-0000-0000000000e2' from projects where name='Projet perso' returning id;
insert into documents (title, classification, unit_id, storage_path) values ('Proposition commerciale', 'restricted', (select id from org_units where code='BIZ'), '00000000-0000-0000-0000-0000000000e1/prop.pdf') returning id;
insert into storage.objects (bucket_id, name) values ('documents', '00000000-0000-0000-0000-0000000000e1/prop.pdf') returning id;
insert into meetings (title, starts_at, ends_at, unit_id) values ('Revue pipeline', now() + interval '1 day', now() + interval '1 day 1 hour', (select id from org_units where code='BIZ')) returning id;
insert into meeting_attendees (meeting_id, profile_id) select id, '00000000-0000-0000-0000-0000000000e2' from meetings returning meeting_id;
insert into objectives (level, title, owner_id) values ('individual', 'Signer 5 clients', auth.uid()) returning id;
insert into incidents (title, severity) values ('Lenteur API paiement', 'high') returning id;
select count(*) as sales_sees_announcement from announcements;
select count(*) as unread_notifications from notifications;
do $$ begin
  insert into announcements (title, body) values ('x', 'y');
  raise exception 'ERREUR';
exception when insufficient_privilege then raise notice 'OK : un commercial ne publie pas d''annonce';
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000e2');
select count(*) as ops_sees_accounts from accounts;             -- 0
select count(*) as ops_sees_restricted_doc from documents;      -- 0
select count(*) as ops_sees_storage_obj from storage.objects;   -- 0
select count(*) as ops_sees_task from tasks;                    -- 1 (assignée)
select count(*) as ops_sees_private_channel from channels where name='ventes-privé'; -- 1 (membre)
select count(*) as ops_sees_meeting from meetings;              -- 1 (invitée)
update tasks set status = 'in_progress' where title='Tâche 1' returning status;
update meeting_attendees set response='accepted' where profile_id = auth.uid() returning response;
select title from notifications order by created_at;
reset role;
