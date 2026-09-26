-- =============================================================================
-- VERIION OS — Données initiales : structure de l'organisation et référentiel KPI
-- À exécuter une fois, après les migrations.
-- =============================================================================

do $$
declare
  root uuid; dg uuid; ops uuid; tech uuid; dev uuid; mkt uuid; biz uuid; fin uuid;
begin
  if exists (select 1 from public.org_units) then
    raise notice 'Organisation déjà initialisée — aucune action.';
    return;
  end if;

  insert into public.org_units (name, code, kind, domain, color, sort_order, description)
  values ('VERIION', 'VRN', 'company', 'direction', '#050816', 0, 'L''écosystème numérique de l''Afrique')
  returning id into root;

  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description) values
    (root, 'Direction Générale', 'DG',   'department', 'direction',  '#0B1F3A', 1, 'Vision, arbitrages et pilotage de l''entreprise')
  returning id into dg;
  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description) values
    (root, 'Opérations',         'OPS',  'department', 'operations', '#0E7490', 2, 'Exécution, gestion de projets et qualité')
  returning id into ops;
  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description) values
    (root, 'Technologie',        'TECH', 'department', 'technology', '#4F46E5', 3, 'Produits, plateformes et infrastructure')
  returning id into tech;
  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description) values
    (root, 'Marketing',          'MKT',  'department', 'marketing',  '#DB2777', 4, 'Acquisition, communication et contenu')
  returning id into mkt;
  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description) values
    (root, 'Business',           'BIZ',  'department', 'business',   '#EA580C', 5, 'Ventes et partenariats')
  returning id into biz;
  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description) values
    (root, 'Finance',            'FIN',  'department', 'finance',    '#059669', 6, 'Comptabilité, trésorerie et contrôle financier')
  returning id into fin;

  insert into public.org_units (parent_id, name, code, kind, color, sort_order) values
    (dg,   'Cabinet du CEO',      'DG-CAB',  'subdepartment', '#0B1F3A', 1),
    (ops,  'Gestion de projets',  'OPS-PMO', 'subdepartment', '#0E7490', 1),
    (ops,  'Qualité',             'OPS-QA',  'subdepartment', '#0E7490', 2),
    (tech, 'Infrastructure',      'TECH-INF','subdepartment', '#4F46E5', 2),
    (mkt,  'Acquisition',         'MKT-ACQ', 'subdepartment', '#DB2777', 1),
    (mkt,  'Communication',       'MKT-COM', 'subdepartment', '#DB2777', 2),
    (mkt,  'Contenu',             'MKT-CNT', 'subdepartment', '#DB2777', 3),
    (biz,  'Commercial',          'BIZ-COM', 'subdepartment', '#EA580C', 1),
    (biz,  'Partenariats',        'BIZ-PAR', 'subdepartment', '#EA580C', 2),
    (fin,  'Comptabilité',        'FIN-CPT', 'subdepartment', '#059669', 1),
    (fin,  'Contrôle financier',  'FIN-CTL', 'subdepartment', '#059669', 2);

  insert into public.org_units (parent_id, name, code, kind, color, sort_order)
  values (tech, 'Développement', 'TECH-DEV', 'subdepartment', '#4F46E5', 1)
  returning id into dev;

  insert into public.org_units (parent_id, name, code, kind, color, sort_order) values
    (dev, 'Backend',  'TECH-DEV-BE', 'team', '#4F46E5', 1),
    (dev, 'Frontend', 'TECH-DEV-FE', 'team', '#4F46E5', 2);

  -- Canal général de l'entreprise
  insert into public.channels (kind, name, description, is_private)
  values ('group', 'général', 'Échanges ouverts à toute l''équipe VERIION', false);
end $$;

insert into public.kpi_definitions (key, name, description, formula, source, unit) values
  ('active_users',   'Utilisateurs actifs',        'Utilisateurs uniques actifs sur les plateformes VERIION', 'Somme des utilisateurs actifs du dernier jour mesuré (tous produits)', 'product_metrics', 'utilisateurs'),
  ('revenue_ytd',    'Revenus cumulés',            'Revenus encaissés depuis le 1er janvier',                 'Σ transactions de type revenu de l''année', 'transactions', 'XOF'),
  ('burn',           'Dépenses cumulées',          'Dépenses engagées depuis le 1er janvier',                 'Σ transactions de type dépense de l''année', 'transactions', 'XOF'),
  ('cash',           'Trésorerie',                 'Position de trésorerie estimée',                          'Trésorerie d''ouverture + Σ revenus − Σ dépenses', 'transactions + company_settings', 'XOF'),
  ('pipeline',       'Pipeline pondéré',           'Valeur attendue des opportunités ouvertes',               'Σ montant × probabilité', 'opportunities', 'XOF'),
  ('tasks_overdue',  'Tâches en retard',           'Tâches non terminées dont l''échéance est dépassée',      'count(tasks) où statut ≠ terminé et échéance < aujourd''hui', 'tasks', 'tâches'),
  ('budget_usage',   'Consommation budgétaire',    'Part du budget annuel consommée par unité',               'Σ dépenses de l''unité ÷ budget de l''unité', 'budgets + transactions', '%')
on conflict (key) do nothing;
