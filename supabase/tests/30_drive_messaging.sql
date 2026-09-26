\set ON_ERROR_STOP 1
insert into auth.users (id, email) values
 ('00000000-0000-0000-0000-00000000000a', 'awa.houngbo@veriion.com'),
 ('00000000-0000-0000-0000-0000000000b1', 'koffi.adjovi@veriion.com'),
 ('00000000-0000-0000-0000-0000000000c1', 'nadia.sossa@veriion.com'),
 ('00000000-0000-0000-0000-0000000000d1', 'yann.agbo@veriion.com');
create or replace function pg_temp.as_user(u text) returns void language plpgsql as $$
begin perform set_config('request.jwt.claim.sub', u, false); execute 'set role authenticated'; end $$;
select count(*) as personal_roots from folders where space='personal';
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select public.appoint_member((select id from org_units where code='FIN'), '00000000-0000-0000-0000-0000000000b1', 'head', 'CFO');
select public.appoint_member((select id from org_units where code='MKT'), '00000000-0000-0000-0000-0000000000c1', 'head', 'CMO');
select public.appoint_member((select id from org_units where code='MKT-ACQ'), '00000000-0000-0000-0000-0000000000d1', 'member');
reset role;

-- Nadia (CMO) : espaces visibles
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
select name, space, access from public.my_drive_spaces();
-- crée un dossier dans l'espace Marketing, un sous-dossier, un document texte
insert into folders (parent_id, space, name) select id, 'unit', 'Campagnes 2026' from folders where is_root and space='unit' and unit_id=(select id from org_units where code='MKT') returning name, space, depth;
insert into folders (parent_id, space, name) select id, 'unit', 'Côte d''Ivoire' from folders where name='Campagnes 2026' returning name, depth;
insert into documents (title, kind, folder_id, owner_id, content) select 'Plan média CI', 'doc', id, auth.uid(), '{"type":"doc"}' from folders where name='Côte d''Ivoire' returning id, title;
select public.save_document_content((select id from documents where title='Plan média CI'), '{"type":"doc","content":[1]}', 'Budget radio et TV', 1) as rev;
do $$ begin
  perform public.save_document_content((select id from documents where title='Plan média CI'), '{}', 'x', 1);
  raise exception 'ERREUR: conflit non détecté';
exception when sqlstate '40001' then raise notice 'OK : conflit de révision détecté';
end $$;
-- dossier personnel privé
insert into folders (parent_id, space, name) select id, 'personal', 'Brouillons' from folders where is_root and space='personal' and owner_id=auth.uid();
insert into documents (title, kind, folder_id, owner_id) select 'Note perso', 'doc', id, auth.uid() from folders where name='Brouillons';
reset role;

-- Yann (membre de MKT-ACQ, donc du département Marketing) : contributeur de l'espace Marketing
select pg_temp.as_user('00000000-0000-0000-0000-0000000000d1');
select name, access from public.my_drive_spaces();
select count(*) as yann_sees_plan from documents where title='Plan média CI';
reset role;

-- Awa (CEO) : voit Marketing (3) mais PAS l'espace personnel de Nadia
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select count(*) as ceo_sees_plan from documents where title='Plan média CI';
select count(*) as ceo_sees_personal_note from documents where title='Note perso';
select count(*) as ceo_sees_brouillons from folders where name='Brouillons';
reset role;

-- Nadia partage « Campagnes 2026 » avec Koffi (Finance) en lecture
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
insert into shares (folder_id, profile_id, role) select id, '00000000-0000-0000-0000-0000000000b1', 'viewer' from folders where name='Campagnes 2026';
-- document confidentiel dans l'espace Marketing
insert into documents (title, kind, folder_id, owner_id, classification) select 'Budget confidentiel', 'sheet', id, auth.uid(), 'confidential' from folders where name='Campagnes 2026';
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
select title, public.document_access(id) as access from documents where deleted_at is null order by title;
do $$ begin
  update documents set title='hack' where title='Plan média CI';
  if found then raise exception 'ERREUR: un lecteur a modifié'; end if;
  raise notice 'OK : lecteur ne peut pas modifier';
end $$;
select kind, name, role from public.shared_with_me();
select title from notifications where title like '%partagé%';
reset role;

-- Corbeille et restauration
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
select public.trash_item((select id from folders where name='Campagnes 2026'), null);
select count(*) filter (where deleted_at is not null) as trashed_docs from documents where title in ('Plan média CI','Budget confidentiel');
select public.restore_item((select id from folders where name='Campagnes 2026'), null);
select count(*) filter (where deleted_at is null) as restored_docs from documents where title in ('Plan média CI','Budget confidentiel');
select jsonb_array_length(public.drive_listing((select id from folders where name='Campagnes 2026'))->'folders') as subfolders;
-- déplacement d'un dossier (Nadia gère l'espace Marketing : autorisé)
update folders set parent_id = (select id from folders where is_root and space='personal' and owner_id=auth.uid()) where name='Côte d''Ivoire' returning space, depth;
select count(*) as versions from document_versions;
reset role;
-- Yann (contributeur) ne peut pas sortir un dossier du département vers son espace personnel
select pg_temp.as_user('00000000-0000-0000-0000-0000000000d1');
do $$ begin
  update folders set parent_id = (select id from folders where is_root and space='personal' and owner_id=auth.uid()) where name='Campagnes 2026';
  raise exception 'ERREUR: exfiltration possible';
exception when insufficient_privilege then raise notice 'OK : déplacement hors du département refusé';
end $$;
reset role;

-- ===== Messagerie
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c1');
insert into messages (channel_id, body, author_id) select id, 'Bonjour @[Yann Agbo](00000000-0000-0000-0000-0000000000d1) et @[Koffi](00000000-0000-0000-0000-0000000000b1) !', auth.uid() from channels where kind='unit' and name='Marketing' returning mentions;
insert into messages (channel_id, body, author_id, parent_id) select channel_id, 'Réponse en fil', auth.uid(), id from messages where body like 'Bonjour%';
select reply_count from messages where body like 'Bonjour%';
select public.toggle_pin((select id from messages where body like 'Bonjour%')) as pinned;
insert into message_reactions (message_id, emoji) select id, '👍' from messages where body like 'Bonjour%' returning channel_id is not null as has_channel;
select public.open_direct_channel('00000000-0000-0000-0000-0000000000d1') is not null;
insert into messages (channel_id, body, author_id) select id, 'Salut Yann', auth.uid() from channels where kind='direct';
insert into messages (channel_id, body, author_id) select id, 'Tu es là ?', auth.uid() from channels where kind='direct';
select count(*) as search_hits from public.search_messages('Bonjour');
select count(*) as people from public.channel_people((select id from channels where kind='unit' and name='Marketing'));
reset role;
select profile_id = '00000000-0000-0000-0000-0000000000d1' as to_yann, kind, title from notifications where kind like 'message.%' order by created_at;
