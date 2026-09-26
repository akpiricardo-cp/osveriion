-- =============================================================================
-- VERIION OS — Données de démonstration (OPTIONNEL)
-- Remplit la finance, le CRM, les métriques produit et les budgets pour voir
-- les tableaux de bord vivants. À NE PAS exécuter en production réelle.
-- Pour tout effacer : voir le bloc « Nettoyage » en bas de fichier.
-- =============================================================================

do $$
declare
  y int := extract(year from current_date)::int;
  m int;
  products text[] := array['Oniix', 'iSkul', 'Wiix', 'Eduoo'];
  countries text[] := array['BJ', 'CI', 'SN', 'TG', 'NG'];
  cats text[] := array['Salaires', 'Infrastructure cloud', 'Marketing digital', 'Locaux', 'Déplacements', 'Logiciels'];
  u record;
begin
  if exists (select 1 from public.transactions where reference like 'DEMO-%') then
    raise notice 'Démo déjà chargée.'; return;
  end if;

  -- Budgets annuels par département
  for u in select id, code from public.org_units where depth = 1 loop
    insert into public.budgets (unit_id, fiscal_year, amount)
    values (u.id, y, case u.code when 'TECH' then 180000000 when 'MKT' then 90000000 when 'BIZ' then 60000000
                                 when 'OPS' then 45000000 when 'FIN' then 30000000 else 40000000 end)
    on conflict (unit_id, fiscal_year) do nothing;
  end loop;

  -- Revenus et dépenses mensuels jusqu'au mois courant
  for m in 1 .. extract(month from current_date)::int loop
    for i in 1 .. 4 loop
      insert into public.transactions (type, amount, occurred_on, category, product, country, reference, description)
      values ('revenue', round((6000000 + random() * 9000000 + m * 900000)::numeric, -3),
              make_date(y, m, 1 + (random() * 26)::int), 'Ventes',
              products[1 + (random() * 3)::int], countries[1 + (random() * 4)::int],
              'DEMO-R-' || m || '-' || i, 'Revenus abonnements');
    end loop;
    for u in select o.id, b.amount as budget from public.org_units o join public.budgets b on b.unit_id = o.id and b.fiscal_year = y where o.depth = 1 loop
      insert into public.transactions (type, amount, occurred_on, category, unit_id, reference, description)
      values ('expense', round((u.budget / 12 * (0.55 + random() * 0.4))::numeric, -3),
              make_date(y, m, 1 + (random() * 26)::int), cats[1 + (random() * 5)::int], u.id,
              'DEMO-D-' || m || '-' || u.id, 'Dépense opérationnelle');
    end loop;
  end loop;

  -- Métriques produit : 120 jours
  for i in 0 .. 119 loop
    insert into public.product_metrics (metric_date, product, country, active_users, new_users)
    values (current_date - (119 - i), 'VERIION', 'ALL',
            (180000 + i * 1450 + (random() * 9000))::int, (2500 + random() * 1800)::int)
    on conflict do nothing;
  end loop;

  -- CRM
  insert into public.accounts (name, type, industry, country, city, website, owner_id) values
    ('Ministère de l''Économie Numérique', 'client',   'Secteur public',  'BJ', 'Cotonou',  'https://numerique.gouv.bj', null),
    ('MTN Bénin',                         'partner',  'Télécoms',        'BJ', 'Cotonou',  'https://mtn.bj', null),
    ('Université d''Abomey-Calavi',        'client',   'Éducation',       'BJ', 'Calavi',   null, null),
    ('Ecobank',                           'prospect', 'Banque',          'TG', 'Lomé',     'https://ecobank.com', null),
    ('Groupe Sonatel',                    'prospect', 'Télécoms',        'SN', 'Dakar',    null, null),
    ('Lycée Technique Coulibaly',         'prospect', 'Éducation',       'CI', 'Abidjan',  null, null),
    ('Wave Mobile Money',                 'partner',  'Fintech',         'SN', 'Dakar',    null, null);

  insert into public.opportunities (account_id, name, stage, amount, probability, expected_close, product)
  select id, x.name, x.stage::public.opportunity_stage, x.amount, x.prob, current_date + x.days, x.product
  from (values
    ('Ecobank',                    'Formation digitale des agents',     'proposal',    42000000, 50, 30, 'iSkul'),
    ('Groupe Sonatel',             'Contenus vidéo premium',            'negotiation', 85000000, 70, 20, 'Oniix'),
    ('Lycée Technique Coulibaly',  'Plateforme scolaire',               'qualified',   12000000, 30, 60, 'Eduoo'),
    ('Ministère de l''Économie Numérique', 'Extension nationale',       'lead',       150000000, 10, 120, 'Wiix'),
    ('Université d''Abomey-Calavi', 'Campus numérique — phase 2',       'proposal',    38000000, 45, 45, 'iSkul')
  ) as x(acc, name, stage, amount, prob, days, product)
  join public.accounts a2 on a2.name = x.acc;

  insert into public.incidents (title, severity, status, product, occurred_at, reported_by) values
    ('Latence élevée sur le streaming Oniix (Afrique de l''Ouest)', 'high',   'mitigated', 'Oniix', now() - interval '2 days', null),
    ('Échec intermittent des paiements Mobile Money',               'critical','open',     'Wiix',  now() - interval '5 hours', null);
end $$;

-- -----------------------------------------------------------------------------
-- Nettoyage de la démo (décommentez pour exécuter)
-- -----------------------------------------------------------------------------
-- delete from public.transactions where reference like 'DEMO-%';
-- delete from public.product_metrics where product = 'VERIION' and country = 'ALL';
-- delete from public.accounts where owner_id is null;
-- delete from public.incidents where reported_by is null;
-- delete from public.budgets;
