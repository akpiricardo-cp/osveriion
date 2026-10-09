\set ON_ERROR_STOP 1
-- Code d'accès personnel : définition, vérification, blocage, réinitialisation.
insert into auth.users (id, email) values
 ('00000000-0000-0000-0000-00000000000a', 'awa.houngbo@veriion.com'),   -- premier compte => CEO
 ('00000000-0000-0000-0000-0000000000b1', 'koffi.adjovi@veriion.com');
create or replace function pg_temp.as_user(u text) returns void language plpgsql as $$
begin perform set_config('request.jwt.claim.sub', u, false); perform set_config('request.jwt.claims', '{"aal":"aal2"}', false); execute 'set role authenticated'; end $$;

-- ── Forme du code ──────────────────────────────────────────────────────────
select code, public.access_code_valid(code) as accepte
from (values ('7K4m9Q'), ('bonjour2026'), ('12345'), ('123456'), ('000000'), ('654321'), ('mon code')) v(code);

-- ── Définition puis vérification ───────────────────────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
do $$ begin
  perform public.set_access_code('123456');
  raise exception 'ERREUR: suite évidente acceptée comme code';
exception when others then if sqlerrm like 'ERREUR%' then raise; end if; raise notice 'OK : code trop faible refusé';
end $$;
select public.set_access_code('Koffi-2026');
select public.has_access_code() as koffi_a_un_code;
-- Le hachage n'est lisible par personne, pas même son propriétaire
do $$ begin
  perform 1 from public.access_codes;
  raise exception 'ERREUR: table access_codes lisible';
exception when insufficient_privilege then raise notice 'OK : hachage du code inaccessible en lecture';
end $$;
select public.verify_access_code('Koffi-2026') as bon_code;
select public.verify_access_code('mauvais-code') as mauvais_code;   -- 3 tentatives restantes

-- ── Blocage temporaire après 5 échecs consécutifs ───────────────────────────
select public.verify_access_code('x') as essai_2;
select public.verify_access_code('x') as essai_3;
select public.verify_access_code('x') as essai_4;
select (public.verify_access_code('x') -> 'locked_until') is not null as bloque_au_5e_essai;
do $$ begin
  if coalesce((public.verify_access_code('Koffi-2026')->>'ok')::boolean, false) then
    raise exception 'ERREUR: le bon code passe malgré le blocage';
  end if;
  raise notice 'OK : saisie bloquée 15 minutes, même avec le bon code';
end $$;
-- Le changement de code est soumis au même blocage (pas de contournement)
do $$ begin
  perform public.set_access_code('Nouveau-2026', 'Koffi-2026');
  raise exception 'ERREUR: changement de code autorisé pendant le blocage';
exception when insufficient_privilege then raise notice 'OK : changement de code bloqué lui aussi';
end $$;

-- ── Changement de code, une fois le blocage levé ────────────────────────────
reset role;
update public.access_codes set locked_until = null, attempts = 0
 where profile_id = '00000000-0000-0000-0000-0000000000b1';
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
do $$ begin
  perform public.set_access_code('Nouveau-2026', 'pas-le-bon');
  raise exception 'ERREUR: code actuel non vérifié';
exception when insufficient_privilege then raise notice 'OK : changement refusé sans le code actuel';
end $$;
reset role;
update public.access_codes set locked_until = null, attempts = 0
 where profile_id = '00000000-0000-0000-0000-0000000000b1';
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
select public.set_access_code('Nouveau-2026', 'Koffi-2026');
select public.verify_access_code('Nouveau-2026') as nouveau_code_ok;
select public.verify_access_code('Koffi-2026') as ancien_code_refuse;
-- Personne ne consulte le code d'un autre, ni ne le réinitialise
do $$ begin
  perform public.has_access_code('00000000-0000-0000-0000-00000000000a');
  raise exception 'ERREUR: état du code d''un collègue consultable';
exception when insufficient_privilege then raise notice 'OK : état du code d''autrui réservé aux administrateurs';
end $$;
do $$ begin
  perform public.clear_access_code('00000000-0000-0000-0000-00000000000a');
  raise exception 'ERREUR: réinitialisation possible sans droit';
exception when insufficient_privilege then raise notice 'OK : réinitialisation réservée aux administrateurs';
end $$;
reset role;

-- ── Réinitialisation par l'administration ──────────────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select public.has_access_code('00000000-0000-0000-0000-0000000000b1') as ceo_voit_l_etat;
select public.clear_access_code('00000000-0000-0000-0000-0000000000b1');
select public.has_access_code('00000000-0000-0000-0000-0000000000b1') as koffi_doit_en_choisir_un;
select public.verify_access_code('Nouveau-2026') as ceo_sans_code;   -- { missing: true }
-- La création et la suppression sont tracées, sans jamais le hachage
select action, table_name, (old_data is null and new_data is null) as contenu_masque
from public.audit_log where table_name = 'access_codes' order by id;
reset role;

-- ── Un départ efface le code ───────────────────────────────────────────────
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1');
select public.set_access_code('Koffi-2027');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select public.offboard_employee('00000000-0000-0000-0000-0000000000b1');
select public.has_access_code('00000000-0000-0000-0000-0000000000b1') as code_apres_depart;
reset role;
