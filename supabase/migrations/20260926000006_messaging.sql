-- =============================================================================
-- VERIION OS — Migration 6 : Messagerie complète
-- Pièces jointes, fils de discussion, mentions, réactions, messages épinglés,
-- recherche, appels, notifications des messages directs.
-- =============================================================================

alter table public.messages
  add column kind          text not null default 'text' check (kind in ('text', 'call', 'system')),
  add column mentions      uuid[] not null default '{}',
  add column reply_count   int not null default 0,
  add column last_reply_at timestamptz,
  add column pinned_at     timestamptz,
  add column pinned_by     uuid references public.profiles(id) on delete set null;

alter table public.messages drop constraint if exists messages_body_check;
alter table public.messages add constraint messages_body_check
  check (length(body) <= 8000 and (length(body) >= 1 or jsonb_array_length(attachments) > 0));
alter table public.messages alter column body set default '';

create index messages_parent_idx on public.messages(parent_id, created_at) where parent_id is not null;
create index messages_pinned_idx on public.messages(channel_id) where pinned_at is not null;
create index messages_body_fts on public.messages using gin (to_tsvector('simple', body));

create table public.message_reactions (
  message_id  uuid not null references public.messages(id) on delete cascade,
  channel_id  uuid not null references public.channels(id) on delete cascade,
  profile_id  uuid not null references public.profiles(id) on delete cascade default auth.uid(),
  emoji       text not null check (length(emoji) between 1 and 16),
  created_at  timestamptz not null default now(),
  primary key (message_id, profile_id, emoji)
);
create index message_reactions_channel_idx on public.message_reactions(channel_id);

-- Une personne donnée peut-elle lire ce canal ? (pour filtrer les notifications de mention)
create or replace function public.profile_in_channel(p_profile uuid, p_channel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.channels c
    where c.id = p_channel and (
      exists (select 1 from public.channel_members cm where cm.channel_id = c.id and cm.profile_id = p_profile)
      or (c.kind = 'group' and not c.is_private)
      or (c.kind = 'unit' and exists (select 1 from public.unit_memberships m join public.org_units u on u.id = m.unit_id
                                      where m.profile_id = p_profile and m.end_date is null and c.unit_id = any(u.path)))
      or (c.kind = 'project' and exists (select 1 from public.project_members pm where pm.project_id = c.project_id and pm.profile_id = p_profile))
      or exists (select 1 from public.profiles p where p.id = p_profile and p.system_role = 'ceo'))
  )
$$;

-- Mentions : syntaxe @[Nom](uuid) dans le corps du message
create or replace function public.messages_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare parent public.messages;
begin
  select coalesce(array_agg(distinct public.try_uuid(m[1])) filter (where public.try_uuid(m[1]) is not null), '{}')
    into new.mentions
  from regexp_matches(coalesce(new.body, ''), '@\[[^\]]{1,80}\]\(([0-9a-fA-F-]{36})\)', 'g') as m;
  if new.parent_id is not null then
    select * into parent from public.messages where id = new.parent_id;
    if parent.id is null or parent.channel_id <> new.channel_id then raise exception 'Fil de discussion invalide'; end if;
    if parent.parent_id is not null then new.parent_id := parent.parent_id; end if;  -- un seul niveau de fil
  end if;
  return new;
end $$;
create trigger messages_bi before insert on public.messages for each row execute function public.messages_before_insert();

create or replace function public.messages_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  ch public.channels;
  author text;
  target uuid;
  preview text := left(regexp_replace(coalesce(new.body, ''), '@\[([^\]]+)\]\([0-9a-fA-F-]{36}\)', '@\1', 'g'), 140);
  link text := '/messages/' || new.channel_id;
begin
  select * into ch from public.channels where id = new.channel_id;
  select full_name into author from public.profiles where id = new.author_id;
  if preview = '' and jsonb_array_length(new.attachments) > 0 then preview := '📎 Pièce jointe'; end if;

  if new.parent_id is null then
    update public.channels set last_message_at = new.created_at where id = new.channel_id;
  else
    update public.messages set reply_count = reply_count + 1, last_reply_at = new.created_at where id = new.parent_id;
    link := link || '?fil=' || new.parent_id;
    -- L'auteur du message d'origine et les participants du fil sont notifiés
    for target in
      select distinct x from (
        select author_id as x from public.messages where id = new.parent_id
        union select author_id from public.messages where parent_id = new.parent_id
      ) t where x is not null and x <> coalesce(new.author_id, '00000000-0000-0000-0000-000000000000'::uuid)
    loop
      perform public.notify(target, 'message.thread', coalesce(author, 'Quelqu''un') || ' a répondu dans un fil', preview, link);
    end loop;
  end if;

  if new.author_id is not null then
    insert into public.channel_members (channel_id, profile_id, last_read_at)
    values (new.channel_id, new.author_id, new.created_at)
    on conflict (channel_id, profile_id) do update set last_read_at = excluded.last_read_at;
  end if;

  -- Mentions
  foreach target in array new.mentions loop
    if target <> coalesce(new.author_id, '00000000-0000-0000-0000-000000000000'::uuid) and public.profile_in_channel(target, new.channel_id) then
      perform public.notify(target, 'message.mention', coalesce(author, 'Quelqu''un') || ' vous a mentionné'
        || case when ch.kind = 'direct' then '' else ' dans #' || ch.name end, preview, link);
    end if;
  end loop;

  -- Messages directs : une notification par conversation tant qu'elle n'a pas été lue
  if ch.kind = 'direct' and new.parent_id is null then
    for target in select profile_id from public.channel_members where channel_id = ch.id and profile_id <> new.author_id loop
      if not exists (select 1 from public.notifications n where n.profile_id = target and n.kind = 'message.direct'
                       and n.link = '/messages/' || ch.id and n.read_at is null) and not (target = any(new.mentions)) then
        perform public.notify(target, 'message.direct', 'Nouveau message de ' || coalesce(author, 'un collègue'), preview, '/messages/' || ch.id);
      end if;
    end loop;
  end if;
  return null;
end $$;

create or replace function public.message_reactions_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  select channel_id into new.channel_id from public.messages where id = new.message_id;
  return new;
end $$;
create trigger message_reactions_bi before insert on public.message_reactions for each row execute function public.message_reactions_before_insert();

-- Épingler / désépingler (tout participant du canal)
create or replace function public.toggle_pin(p_message uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare m public.messages;
begin
  select * into m from public.messages where id = p_message;
  if m.id is null or not public.can_access_channel(m.channel_id) then raise exception 'Accès refusé' using errcode = '42501'; end if;
  update public.messages set pinned_at = case when pinned_at is null then now() end,
                             pinned_by = case when pinned_at is null then auth.uid() end
   where id = p_message;
  return m.pinned_at is null;
end $$;

-- Lancer un appel vidéo dans une conversation : publie un message « appel » avec le lien de la salle
create or replace function public.start_call(p_channel uuid, p_url text)
returns uuid language plpgsql security definer set search_path = public as $$
declare mid uuid;
begin
  if not public.can_access_channel(p_channel) then raise exception 'Accès refusé' using errcode = '42501'; end if;
  if p_url !~ '^https://' then raise exception 'Lien d''appel invalide'; end if;
  insert into public.messages (channel_id, author_id, kind, body, attachments)
  values (p_channel, auth.uid(), 'call', 'a lancé un appel vidéo', jsonb_build_array(jsonb_build_object('type', 'call', 'url', p_url)))
  returning id into mid;
  return mid;
end $$;

-- Recherche dans les conversations accessibles
create or replace function public.search_messages(q text, p_channel uuid default null)
returns table (id uuid, channel_id uuid, channel_name text, channel_kind public.channel_kind, author_id uuid, body text, created_at timestamptz, parent_id uuid)
language plpgsql stable security invoker set search_path = public as $$
declare pat text := '%' || replace(replace(replace(coalesce(trim(q), ''), '\', '\\'), '%', '\%'), '_', '\_') || '%';
begin
  if length(coalesce(trim(q), '')) < 2 then return; end if;
  return query
  select m.id, m.channel_id, c.name, c.kind, m.author_id, m.body, m.created_at, m.parent_id
  from public.messages m join public.channels c on c.id = m.channel_id
  where m.deleted_at is null and m.kind = 'text' and m.body ilike pat
    and (p_channel is null or m.channel_id = p_channel)
  order by m.created_at desc limit 40;
end $$;

-- Membres d'un canal (pour les mentions et le panneau « membres »)
create or replace function public.channel_people(p_channel uuid)
returns table (id uuid, full_name text, avatar_url text, job_title text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare c public.channels;
begin
  if not public.can_access_channel(p_channel) then raise exception 'Accès refusé' using errcode = '42501'; end if;
  select * into c from public.channels where id = p_channel;
  return query
  select p.id, p.full_name, p.avatar_url, p.job_title from public.profiles p
  where p.status = 'active' and (
    exists (select 1 from public.channel_members cm where cm.channel_id = c.id and cm.profile_id = p.id)
    or (c.kind = 'group' and not c.is_private)
    or (c.kind = 'unit' and exists (select 1 from public.unit_memberships m join public.org_units u on u.id = m.unit_id
                                    where m.profile_id = p.id and m.end_date is null and c.unit_id = any(u.path)))
    or (c.kind = 'project' and exists (select 1 from public.project_members pm where pm.project_id = c.project_id and pm.profile_id = p.id)))
  order by p.first_name;
end $$;

-- -----------------------------------------------------------------------------
-- Sécurité
-- -----------------------------------------------------------------------------
alter table public.message_reactions enable row level security;
grant select, insert, delete on public.message_reactions to authenticated;

create policy "réactions: lecture" on public.message_reactions for select to authenticated using (public.can_access_channel(channel_id));
create policy "réactions: ajout" on public.message_reactions for insert to authenticated
  with check (profile_id = auth.uid() and exists (select 1 from public.messages m where m.id = message_id and public.can_access_channel(m.channel_id)));
create policy "réactions: retrait" on public.message_reactions for delete to authenticated using (profile_id = auth.uid());

-- Pièces jointes de la messagerie : chemin = <channel_id>/<fichier>
insert into storage.buckets (id, name, public, file_size_limit)
values ('chat', 'chat', false, 26214400)
on conflict (id) do nothing;

create policy "chat: lecture" on storage.objects for select to authenticated
  using (bucket_id = 'chat' and public.can_access_channel(public.try_uuid((storage.foldername(objects.name))[1])));
create policy "chat: dépôt" on storage.objects for insert to authenticated
  with check (bucket_id = 'chat' and public.can_access_channel(public.try_uuid((storage.foldername(objects.name))[1])));

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.message_reactions;
  end if;
end $$;

grant execute on function public.toggle_pin(uuid), public.start_call(uuid, text), public.search_messages(text, uuid), public.channel_people(uuid) to authenticated;

revoke execute on function public.profile_in_channel(uuid, uuid) from public, anon, authenticated;
