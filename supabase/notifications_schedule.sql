-- =============================================================================
-- VERIION OS — Activation de l'envoi des notifications (e-mail et push)
-- À exécuter UNE fois dans Supabase > SQL Editor, après le déploiement de l'application.
--
-- Prérequis : Database > Extensions > activez « pg_cron » et « pg_net ».
-- Remplacez les deux valeurs ci-dessous :
--   * l'adresse publique de l'application (sans / final)
--   * la même valeur que la variable CRON_SECRET de l'application (32 caractères aléatoires)
-- =============================================================================

insert into private.settings (key, value) values
  ('app_url',     'https://os.veriion.com'),
  ('cron_secret', 'REMPLACEZ-PAR-LA-VALEUR-DE-CRON_SECRET')
on conflict (key) do update set value = excluded.value;

-- Chaque minute : e-mails regroupés, résumés quotidiens et rattrapage des push.
-- (Les push partent déjà instantanément à la création de chaque notification.)
select cron.unschedule(jobid) from cron.job where jobname = 'veriion-notifications';
select cron.schedule('veriion-notifications', '* * * * *', $$
  select net.http_post(
    url     := private.setting('app_url') || '/api/notifications/dispatch',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || private.setting('cron_secret')),
    body    := '{"reason":"cron"}'::jsonb,
    timeout_milliseconds := 55000)
$$);

-- Rappels (normalement déjà planifiés par la migration 7 si pg_cron était actif) :
select cron.unschedule(jobid) from cron.job where jobname in ('veriion-daily-reminders', 'veriion-meeting-reminders');
select cron.schedule('veriion-daily-reminders', '0 6 * * *', 'select public.generate_daily_reminders()');     -- 7 h à Porto-Novo
select cron.schedule('veriion-meeting-reminders', '*/5 * * * *', 'select public.remind_upcoming_meetings()');

-- Vérification : les tâches planifiées et les derniers appels
select jobname, schedule, active from cron.job where jobname like 'veriion-%' order by 1;
-- select status_code, created from net._http_response order by created desc limit 5;
