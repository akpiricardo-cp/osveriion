-- =============================================================================
-- VERIION OS — Migration 7 : co-édition simultanée et notifications hors plateforme
-- =============================================================================
--   * Co-édition : l'état Yjs du document (fusion des modifications simultanées)
--     est conservé à côté du contenu JSON, qui reste la référence pour la
--     recherche, les exports et l'historique.
--   * Notifications : préférences par personne et par catégorie, e-mails
--     (immédiats ou résumé quotidien), notifications push sur téléphone et
--     ordinateur, rappels automatiques (échéances, retards, validations,
--     congés à traiter, réunions imminentes).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Co-édition
-- -----------------------------------------------------------------------------
-- État Yjs du document (fusion des modifications simultanées), séparé de la table
-- documents pour ne pas alourdir les listes, la recherche ni le journal d'audit.
create table public.document_ydocs (
  document_id  uuid primary key references public.documents(id) on delete cascade,
  state        text not null,                 -- mise à jour Yjs complète, encodée en base64
  revision     int not null,                  -- révision du document à laquelle l'état correspond
  updated_at   timestamptz not null default now()
);
alter table public.document_ydocs enable row level security;
grant select on public.document_ydocs to authenticated;
create policy "ydoc: lecture" on public.document_ydocs for select to authenticated
  using (public.document_access(document_id) >= 1);

-- Enregistrement : l'état Yjs accompagne le contenu. Un enregistrement sans état
-- Yjs (import, ancien client) le remet à zéro : il sera reconstruit depuis le JSON.
drop function if exists public.save_document_content(uuid, jsonb, text, int, boolean, text);
create or replace function public.save_document_content(
  p_doc uuid, p_content jsonb, p_text text, p_base_revision int default null,
  p_snapshot boolean default false, p_note text default null, p_ydoc text default null
) returns int language plpgsql security definer set search_path = public as $$
declare
  d public.documents;
begin
  if public.document_access(p_doc) < 2 then raise exception 'Vous ne pouvez pas modifier ce document' using errcode = '42501'; end if;
  select * into d from public.documents where id = p_doc for update;
  if d.deleted_at is not null then raise exception 'Ce document est dans la corbeille'; end if;
  if p_base_revision is not null and d.revision <> p_base_revision then
    raise exception 'Le document a été modifié par quelqu''un d''autre (révision %). Rechargez-le.', d.revision using errcode = '40001';
  end if;
  if d.content is not null and (p_snapshot or not exists (
       select 1 from public.document_versions v where v.document_id = p_doc and v.created_at > now() - interval '10 minutes')) then
    insert into public.document_versions (document_id, revision, title, content, note, created_by)
    values (p_doc, d.revision, d.title, d.content, p_note, coalesce(d.updated_by, d.owner_id));
  end if;
  update public.documents
     set content = p_content, content_text = left(coalesce(p_text, ''), 200000),
         revision = d.revision + 1, updated_by = auth.uid(), updated_at = now()
   where id = p_doc;
  if p_ydoc is not null then
    insert into public.document_ydocs (document_id, state, revision) values (p_doc, p_ydoc, d.revision + 1)
    on conflict (document_id) do update set state = excluded.state, revision = excluded.revision, updated_at = now();
  else
    delete from public.document_ydocs where document_id = p_doc;
  end if;
  return d.revision + 1;
end $$;
grant execute on function public.save_document_content(uuid, jsonb, text, int, boolean, text, text) to authenticated;

-- Restaurer une version remplace le contenu : l'état Yjs est invalidé.
create or replace function public.restore_document_version(p_version uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v public.document_versions; d public.documents;
begin
  select * into v from public.document_versions where id = p_version;
  if v.id is null then raise exception 'Version introuvable'; end if;
  if public.document_access(v.document_id) < 2 then raise exception 'Permission refusée' using errcode = '42501'; end if;
  select * into d from public.documents where id = v.document_id for update;
  insert into public.document_versions (document_id, revision, title, content, storage_path, file_name, mime_type, size_bytes, note, created_by)
  values (d.id, d.revision, d.title, d.content, d.storage_path, d.file_name, d.mime_type, d.size_bytes, 'Avant restauration', auth.uid());
  update public.documents set
    content = coalesce(v.content, d.content),
    storage_path = coalesce(v.storage_path, d.storage_path), file_name = coalesce(v.file_name, d.file_name),
    mime_type = coalesce(v.mime_type, d.mime_type), size_bytes = coalesce(v.size_bytes, d.size_bytes),
    revision = d.revision + 1, updated_by = auth.uid()
  where id = d.id;
  if v.content is not null then delete from public.document_ydocs where document_id = d.id; end if;
end $$;

-- -----------------------------------------------------------------------------
-- 2. Notifications : catégories et préférences
-- -----------------------------------------------------------------------------
alter table public.notifications
  add column if not exists emailed_at timestamptz,
  add column if not exists pushed_at  timestamptz;
create index if not exists notifications_email_queue on public.notifications(created_at) where emailed_at is null and read_at is null;
create index if not exists notifications_push_queue  on public.notifications(created_at) where pushed_at is null;

-- Catégorie d'une notification (sert aux préférences). Doit rester alignée sur src/lib/notifications.ts.
create or replace function public.notification_category(p_kind text)
returns text language sql immutable as $$
  select case
    when p_kind in ('task.review', 'leave.requested', 'reminder.reviews', 'reminder.leaves') then 'approvals'
    when p_kind like 'message.%'  then 'messages'
    when p_kind like 'task.%' or p_kind in ('reminder.due', 'reminder.overdue') then 'tasks'
    when p_kind like 'drive.%'    then 'documents'
    when p_kind like 'meeting.%' or p_kind = 'reminder.meeting' then 'meetings'
    when p_kind like 'leave.%' or p_kind like 'hr.%' then 'hr'
    when p_kind = 'announcement'  then 'announcements'
    else 'other'
  end
$$;

create table public.notification_preferences (
  profile_id   uuid primary key references public.profiles(id) on delete cascade default auth.uid(),
  email_mode   text not null default 'instant' check (email_mode in ('instant', 'digest', 'off')),
  email_off    text[] not null default '{}',   -- catégories sans e-mail
  push_off     text[] not null default '{}',   -- catégories sans notification push
  quiet_start  time,                            -- plage « ne pas déranger » pour le push (heure de Porto-Novo)
  quiet_end    time,
  digest_hour  int not null default 7 check (digest_hour between 0 and 23),
  last_digest_at timestamptz,
  updated_at   timestamptz not null default now()
);

create table public.push_subscriptions (
  id            uuid primary key default gen_random_uuid(),
  profile_id    uuid not null references public.profiles(id) on delete cascade default auth.uid(),
  endpoint      text not null unique,
  p256dh        text not null,
  auth          text not null,
  device        text,
  created_at    timestamptz not null default now(),
  last_used_at  timestamptz
);
create index push_subscriptions_profile_idx on public.push_subscriptions(profile_id);

alter table public.notification_preferences enable row level security;
alter table public.push_subscriptions enable row level security;
grant select, insert, update, delete on public.notification_preferences, public.push_subscriptions to authenticated;

create policy "préférences: les miennes" on public.notification_preferences for all to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "push: mes appareils" on public.push_subscriptions for all to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- Enregistrer un appareil (un même navigateur peut changer de titulaire : l'endpoint est réattribué)
create or replace function public.register_push_subscription(p_endpoint text, p_p256dh text, p_auth text, p_device text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Non connecté' using errcode = '42501'; end if;
  if p_endpoint !~ '^https://' then raise exception 'Abonnement invalide'; end if;
  insert into public.push_subscriptions (profile_id, endpoint, p256dh, auth, device)
  values (auth.uid(), p_endpoint, p_p256dh, p_auth, left(p_device, 120))
  on conflict (endpoint) do update set profile_id = auth.uid(), p256dh = excluded.p256dh, auth = excluded.auth,
    device = excluded.device, created_at = now();
end $$;
grant execute on function public.register_push_subscription(text, text, text, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Déclenchement immédiat de l'envoi (push) via pg_net
-- -----------------------------------------------------------------------------
-- Réglages privés (schéma non exposé par l'API) : adresse de l'application et secret partagé.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
create table if not exists private.settings (key text primary key, value text not null);
revoke all on private.settings from public, anon, authenticated;

create or replace function private.setting(p_key text)
returns text language sql stable security definer set search_path = private as $$
  select value from private.settings where key = p_key
$$;

-- Appelle /api/notifications/dispatch sans jamais bloquer ni faire échouer l'écriture d'origine.
create or replace function public.notifications_dispatch()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  url text := private.setting('app_url');
  secret text := private.setting('cron_secret');
begin
  if url is null or secret is null or not exists (select 1 from pg_extension where extname = 'pg_net') then return null; end if;
  begin
    execute 'select net.http_post(url := $1, body := $2, headers := $3, timeout_milliseconds := 5000)'
      using rtrim(url, '/') || '/api/notifications/dispatch',
            jsonb_build_object('reason', 'insert'),
            jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || secret);
  exception when others then
    raise warning 'Notification : appel de l''application impossible (%)', sqlerrm;
  end;
  return null;
end $$;
-- Un appel par lot d'insertions (une annonce crée des centaines de notifications)
create trigger notifications_dispatch after insert on public.notifications
  for each statement execute function public.notifications_dispatch();

-- File d'envoi lue par l'application (clé service_role uniquement)
create or replace function public.claim_push_batch(p_limit int default 200)
returns table (id uuid, profile_id uuid, kind text, category text, title text, body text, link text, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  return query
  with c as (
    select n.id from public.notifications n
    where n.pushed_at is null and n.read_at is null and n.created_at > now() - interval '30 minutes'
    order by n.created_at
    limit p_limit
    for update skip locked
  )
  update public.notifications n set pushed_at = now()
  from c where n.id = c.id
  returning n.id, n.profile_id, n.kind, public.notification_category(n.kind), n.title, n.body, n.link, n.created_at;
end $$;

-- E-mails immédiats : non lues après 3 minutes (le temps de les voir dans l'application)
create or replace function public.claim_email_batch(p_limit int default 500)
returns table (id uuid, profile_id uuid, kind text, category text, title text, body text, link text, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  return query
  with c as (
    select n.id from public.notifications n
    left join public.notification_preferences p on p.profile_id = n.profile_id
    where n.emailed_at is null and n.read_at is null
      and n.created_at < now() - interval '3 minutes' and n.created_at > now() - interval '3 days'
      and coalesce(p.email_mode, 'instant') = 'instant'
    order by n.created_at
    limit p_limit
    for update of n skip locked
  )
  update public.notifications n set emailed_at = now()
  from c where n.id = c.id
  returning n.id, n.profile_id, n.kind, public.notification_category(n.kind), n.title, n.body, n.link, n.created_at;
end $$;

-- Résumé quotidien : personnes en mode « résumé » dont l'heure est arrivée
create or replace function public.claim_digest_batch()
returns table (id uuid, profile_id uuid, kind text, category text, title text, body text, link text, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare local_now timestamp := now() at time zone 'Africa/Porto-Novo';
begin
  return query
  with who as (
    update public.notification_preferences p set last_digest_at = now()
    where p.email_mode = 'digest' and extract(hour from local_now) >= p.digest_hour
      and (p.last_digest_at is null or (p.last_digest_at at time zone 'Africa/Porto-Novo')::date < local_now::date)
    returning p.profile_id
  ), c as (
    select n.id from public.notifications n join who on who.profile_id = n.profile_id
    where n.emailed_at is null and n.read_at is null and n.created_at > now() - interval '36 hours'
  )
  update public.notifications n set emailed_at = now()
  from c where n.id = c.id
  returning n.id, n.profile_id, n.kind, public.notification_category(n.kind), n.title, n.body, n.link, n.created_at;
end $$;

revoke execute on function public.claim_push_batch(int), public.claim_email_batch(int), public.claim_digest_batch() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. Rappels automatiques
-- -----------------------------------------------------------------------------
-- Chaque matin (7 h, heure de Porto-Novo) : échéances du jour, retards, validations et congés en attente.
create or replace function public.generate_daily_reminders()
returns int language plpgsql security definer set search_path = public as $$
declare
  today date := (now() at time zone 'Africa/Porto-Novo')::date;
  n int := 0;
  r record;
begin
  -- Tâches à rendre aujourd'hui
  for r in
    select t.assignee_id, count(*) c, min(t.title) first_title
    from public.tasks t join public.profiles p on p.id = t.assignee_id and p.status = 'active'
    where t.due_date = today and t.status <> 'done' group by t.assignee_id
  loop
    perform public.notify(r.assignee_id, 'reminder.due',
      case when r.c = 1 then 'Échéance aujourd''hui : ' || r.first_title else r.c || ' tâches arrivent à échéance aujourd''hui' end,
      null, '/taches');
    n := n + 1;
  end loop;

  -- Tâches en retard
  for r in
    select t.assignee_id, count(*) c
    from public.tasks t join public.profiles p on p.id = t.assignee_id and p.status = 'active'
    where t.due_date < today and t.status <> 'done' group by t.assignee_id
  loop
    perform public.notify(r.assignee_id, 'reminder.overdue',
      case when r.c = 1 then '1 tâche en retard' else r.c || ' tâches en retard' end, 'Pensez à les terminer ou à revoir leur échéance.', '/taches');
    n := n + 1;
  end loop;

  -- Validations en attente depuis plus d'un jour (chef de projet)
  for r in
    select pr.owner_id, count(*) c
    from public.tasks t join public.projects pr on pr.id = t.project_id
    where t.status = 'review' and t.requires_validation and t.updated_at < now() - interval '1 day' and pr.owner_id is not null
    group by pr.owner_id
  loop
    perform public.notify(r.owner_id, 'reminder.reviews',
      r.c || case when r.c = 1 then ' tâche attend' else ' tâches attendent' end || ' votre validation', null, '/taches');
    n := n + 1;
  end loop;

  -- Demandes de congé à traiter (responsables et managers)
  for r in
    select x.approver, count(distinct x.req) c from (
      select g.profile_id approver, l.id req
      from public.leave_requests l
      join public.unit_memberships m on m.profile_id = l.profile_id and m.end_date is null
      join public.org_units u on u.id = m.unit_id
      join public.role_grants g on g.permission = 'unit.manage' and g.scope_unit_id = any(u.path) and g.profile_id <> l.profile_id
      where l.status = 'pending'
      union
      select p.manager_id, l.id from public.leave_requests l join public.profiles p on p.id = l.profile_id
      where l.status = 'pending' and p.manager_id is not null
    ) x group by x.approver
  loop
    perform public.notify(r.approver, 'reminder.leaves',
      r.c || case when r.c = 1 then ' demande de congé attend' else ' demandes de congé attendent' end || ' votre décision', null, '/rh?onglet=validation');
    n := n + 1;
  end loop;
  return n;
end $$;

-- Toutes les 5 minutes : réunions qui commencent dans les 15 prochaines minutes
alter table public.meetings add column if not exists reminded_at timestamptz;
create or replace function public.remind_upcoming_meetings()
returns int language plpgsql security definer set search_path = public as $$
declare m record; a record; n int := 0;
begin
  for m in
    update public.meetings set reminded_at = now()
    where reminded_at is null and starts_at between now() and now() + interval '15 minutes'
    returning *
  loop
    for a in select profile_id from public.meeting_attendees where meeting_id = m.id and response <> 'declined'
             union select m.organizer_id where m.organizer_id is not null
    loop
      insert into public.notifications (profile_id, kind, title, body, link)
      values (a.profile_id, 'reminder.meeting', 'Réunion à ' || to_char(m.starts_at at time zone 'Africa/Porto-Novo', 'HH24:MI') || ' : ' || m.title,
              coalesce(m.location, case when m.video_url is not null then 'Visioconférence' end), coalesce(m.video_url, '/reunions'));
      n := n + 1;
    end loop;
  end loop;
  return n;
end $$;
revoke execute on function public.generate_daily_reminders(), public.remind_upcoming_meetings() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 5. Tâches planifiées
-- -----------------------------------------------------------------------------
do $$
begin
  perform cron.schedule('veriion-daily-reminders', '0 6 * * *', 'select public.generate_daily_reminders()');   -- 7 h à Porto-Novo
  perform cron.schedule('veriion-meeting-reminders', '*/5 * * * *', 'select public.remind_upcoming_meetings()');
exception when others then
  raise notice 'pg_cron non disponible : rappels automatiques à planifier plus tard (%)', sqlerrm;
end $$;

-- L'envoi des e-mails (immédiats et résumés) et le rattrapage des push sont faits
-- par l'application : /api/notifications/dispatch, appelé chaque minute.
-- Voir le README (section Notifications) pour activer l'appel avec pg_cron + pg_net :
--   insert into private.settings values ('app_url', 'https://os.veriion.com'), ('cron_secret', '<CRON_SECRET>');
--   select cron.schedule('veriion-notifications', '* * * * *', $$select net.http_post(
--     url := private.setting('app_url') || '/api/notifications/dispatch',
--     headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' || private.setting('cron_secret')),
--     body := '{"reason":"cron"}'::jsonb)$$);

-- Temps réel pour les préférences inutile ; publication des notifications déjà active.

-- L'application (clé service_role) dépile les files d'envoi et peut déclencher les rappels
grant execute on function public.claim_push_batch(int), public.claim_email_batch(int), public.claim_digest_batch(),
  public.generate_daily_reminders(), public.remind_upcoming_meetings() to service_role;
grant select, insert, update, delete on public.notifications, public.notification_preferences, public.push_subscriptions to service_role;
grant select on public.profiles to service_role;
