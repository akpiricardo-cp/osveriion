-- =============================================================================
-- VERIION OS — Migration 8 : code d'accès personnel
-- =============================================================================
-- Remplace la double authentification TOTP (application d'authentification) par
-- un code personnel choisi par le collaborateur :
--   * il le définit lui-même, une fois, et le change quand il veut ;
--   * il le saisit à chaque nouvelle session pour rouvrir son espace — la
--     session Supabase n'est jamais fermée, l'application est simplement
--     verrouillée jusqu'à la saisie du code ;
--   * seul un hachage bcrypt est conservé. La table n'est lisible par personne,
--     pas même son propriétaire : tout passe par les fonctions ci-dessous.
-- =============================================================================

create table public.access_codes (
  profile_id     uuid primary key references public.profiles(id) on delete cascade,
  code_hash      text        not null,
  attempts       int         not null default 0,   -- échecs consécutifs depuis le dernier succès
  locked_until   timestamptz,                      -- blocage temporaire après trop d'échecs
  last_unlock_at timestamptz,                      -- dernier déverrouillage réussi
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
-- RLS active et volontairement sans aucune policy ni grant : la table est
-- inaccessible depuis l'API, les fonctions security definer en sont la seule porte.
alter table public.access_codes enable row level security;

create trigger access_codes_touch before update on public.access_codes
  for each row execute function public.set_updated_at();
-- Audit sans le contenu des lignes (« redact ») : on trace la création et la
-- suppression d'un code, jamais son hachage ni les tentatives.
create trigger audit_access_codes after insert or delete on public.access_codes
  for each row execute function public.audit_trigger('redact');

-- -----------------------------------------------------------------------------
-- Forme acceptée : 6 à 32 caractères, sans espace, ni caractère répété
-- (000000), ni suite de chiffres évidente (123456, 654321).
-- -----------------------------------------------------------------------------
create or replace function public.access_code_valid(p_code text)
returns boolean language plpgsql immutable as $$
declare n int; i int; ascending boolean; descending boolean;
begin
  if p_code is null then return false; end if;
  n := length(p_code);
  if n < 6 or n > 32 then return false; end if;
  if p_code ~ '\s' then return false; end if;
  if p_code ~ '^(.)\1*$' then return false; end if;
  if p_code ~ '^\d+$' then
    ascending := true; descending := true;
    for i in 2..n loop
      if ascii(substr(p_code, i, 1)) <> ascii(substr(p_code, i - 1, 1)) + 1 then ascending := false; end if;
      if ascii(substr(p_code, i, 1)) <> ascii(substr(p_code, i - 1, 1)) - 1 then descending := false; end if;
    end loop;
    if ascending or descending then return false; end if;
  end if;
  return true;
end $$;

-- -----------------------------------------------------------------------------
-- Un code est-il défini ? (pour soi, ou pour un collaborateur si l'on administre)
-- -----------------------------------------------------------------------------
create or replace function public.has_access_code(p_profile uuid default null)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare target uuid := coalesce(p_profile, auth.uid());
begin
  if target is null then return false; end if;
  if target <> auth.uid() and not public.has_perm('users.admin') then
    raise exception 'Permission refusée' using errcode = '42501';
  end if;
  return exists (select 1 from public.access_codes where profile_id = target);
end $$;
grant execute on function public.has_access_code(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- Vérifier son code pour rouvrir son espace.
-- Retourne { ok:true } ou { ok:false, remaining } / { ok:false, locked_until } /
-- { ok:false, missing:true } si aucun code n'est encore défini.
-- 5 échecs consécutifs bloquent la saisie pendant 15 minutes.
-- -----------------------------------------------------------------------------
create or replace function public.verify_access_code(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  rec          public.access_codes;
  max_attempts constant int      := 5;
  lock_delay   constant interval := interval '15 minutes';
  until_ts     timestamptz;
  remaining    int;
begin
  if auth.uid() is null then raise exception 'Non connecté' using errcode = '42501'; end if;
  select * into rec from public.access_codes where profile_id = auth.uid() for update;
  if rec.profile_id is null then return jsonb_build_object('ok', false, 'missing', true); end if;
  if rec.locked_until is not null and rec.locked_until > now() then
    return jsonb_build_object('ok', false, 'remaining', 0, 'locked_until', rec.locked_until);
  end if;
  if p_code is not null and rec.code_hash = extensions.crypt(p_code, rec.code_hash) then
    update public.access_codes set attempts = 0, locked_until = null, last_unlock_at = now()
     where profile_id = auth.uid();
    return jsonb_build_object('ok', true);
  end if;
  if rec.attempts + 1 >= max_attempts then
    update public.access_codes set attempts = 0, locked_until = now() + lock_delay
     where profile_id = auth.uid() returning locked_until into until_ts;
    return jsonb_build_object('ok', false, 'remaining', 0, 'locked_until', until_ts);
  end if;
  update public.access_codes set attempts = rec.attempts + 1
   where profile_id = auth.uid() returning max_attempts - attempts into remaining;
  return jsonb_build_object('ok', false, 'remaining', remaining);
end $$;
grant execute on function public.verify_access_code(text) to authenticated;

-- -----------------------------------------------------------------------------
-- Définir ou changer son code. Le changement exige le code actuel, vérifié par
-- `verify_access_code` : le changement de code est donc soumis au même compteur
-- d'échecs et au même blocage temporaire que le déverrouillage.
-- -----------------------------------------------------------------------------
create or replace function public.set_access_code(p_code text, p_current text default null)
returns void language plpgsql security definer set search_path = public as $$
declare existing public.access_codes; verdict jsonb;
begin
  if auth.uid() is null then raise exception 'Non connecté' using errcode = '42501'; end if;
  if not public.is_active_user() then raise exception 'Compte inactif' using errcode = '42501'; end if;
  if not public.access_code_valid(p_code) then
    raise exception 'Le code doit contenir de 6 à 32 caractères, sans espace, et ne pas être un caractère répété ni une suite évidente.';
  end if;
  select * into existing from public.access_codes where profile_id = auth.uid();
  if existing.profile_id is not null then
    verdict := public.verify_access_code(p_current);
    if not coalesce((verdict->>'ok')::boolean, false) then
      if verdict ? 'locked_until' then
        raise exception 'Trop de tentatives. Réessayez dans quelques minutes ou demandez une réinitialisation à l''administration.' using errcode = '42501';
      end if;
      raise exception 'Code actuel incorrect.' using errcode = '42501';
    end if;
    update public.access_codes
       set code_hash = extensions.crypt(p_code, extensions.gen_salt('bf', 10)),
           attempts = 0, locked_until = null, last_unlock_at = now()
     where profile_id = auth.uid();
  else
    insert into public.access_codes (profile_id, code_hash, last_unlock_at)
    values (auth.uid(), extensions.crypt(p_code, extensions.gen_salt('bf', 10)), now());
  end if;
end $$;
grant execute on function public.set_access_code(text, text) to authenticated;

-- -----------------------------------------------------------------------------
-- Code oublié : un administrateur l'efface, la personne en redéfinit un à sa
-- prochaine ouverture. L'opération est journalisée (audit).
-- -----------------------------------------------------------------------------
create or replace function public.clear_access_code(p_profile uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.has_perm('users.admin') then
    raise exception 'Action réservée aux administrateurs' using errcode = '42501';
  end if;
  delete from public.access_codes where profile_id = p_profile;
end $$;
grant execute on function public.clear_access_code(uuid) to authenticated;

-- Un départ efface le code d'accès : plus rien ne subsiste de l'accès personnel.
create or replace function public.access_codes_drop_on_offboard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.access_codes where profile_id = new.id;
  return null;
end $$;
create trigger profiles_drop_access_code after update of status on public.profiles
  for each row when (new.status = 'offboarded' and old.status <> 'offboarded')
  execute function public.access_codes_drop_on_offboard();
