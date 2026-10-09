-- =============================================================================
-- VERIION OS — Migration 12 : durcissement des privilèges (phase 0, lot P0-09)
-- =============================================================================
-- Sur Supabase, tout objet créé dans « public » est accordé par défaut aux rôles
-- de l'API (anon, authenticated). Les migrations 5 à 11 s'appuyaient sur ces
-- privilèges implicites : la table access_codes, censée n'être accessible par
-- aucun grant, l'était donc en lecture (la RLS sans politique la protégeait
-- seule). On retire ici explicitement tout accès anonyme et les grants non voulus.
-- =============================================================================

-- 1. Le rôle anonyme n'a accès à rien dans le schéma public.
revoke all on all tables    in schema public from anon;
revoke all on all sequences in schema public from anon;

-- Fonctions : retire l'exécution à PUBLIC et à anon, en conservant pour
-- « authenticated » exactement ce qu'il pouvait déjà exécuter.
do $$
declare f record; keep boolean;
begin
  for f in
    select p.oid, p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
  loop
    keep := has_function_privilege('authenticated', f.oid, 'execute');
    execute format('revoke execute on function %s from public, anon', f.sig);
    if keep then execute format('grant execute on function %s to authenticated', f.sig); end if;
  end loop;
end $$;

-- Et pour les objets créés par les prochaines migrations.
alter default privileges in schema public revoke all on tables    from anon;
alter default privileges in schema public revoke all on sequences from anon;
alter default privileges in schema public revoke execute on functions from public, anon;

-- 2. Tables qui ne doivent être lues que par leurs fonctions security definer.
revoke all on public.access_codes from authenticated;

-- 3. Inscriptions : seul le domaine de l'entreprise est accepté, invitation ou non.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  has_ceo boolean;
  v_domain text := coalesce((select email_domain from public.company_settings where id), 'veriion.com');
begin
  if lower(split_part(coalesce(new.email, ''), '@', 2)) <> lower(v_domain) then
    raise exception 'Seules les adresses @% peuvent ouvrir un compte VERIION OS', v_domain using errcode = '42501';
  end if;
  select exists(select 1 from public.profiles where system_role = 'ceo') into has_ceo;
  insert into public.profiles (id, email, first_name, last_name, job_title, primary_unit_id, system_role, hire_date)
  values (
    new.id,
    lower(new.email),
    coalesce(nullif(meta->>'first_name', ''), initcap(split_part(split_part(new.email, '@', 1), '.', 1))),
    coalesce(nullif(meta->>'last_name', ''),  initcap(split_part(split_part(new.email, '@', 1), '.', 2))),
    meta->>'job_title',
    nullif(meta->>'primary_unit_id', '')::uuid,
    case when has_ceo then 'employee'::public.system_role else 'ceo'::public.system_role end,
    current_date
  )
  on conflict (id) do nothing;
  return new;
end $$;
