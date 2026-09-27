-- =============================================================================
-- VERIION OS — Données initiales : structure de la holding et référentiel KPI
-- À exécuter une fois, après les migrations.
-- =============================================================================
-- VERIION est une holding : une équipe administrative transverse, et autant de
-- projets que de produits. Les départements ci-dessous coordonnent chaque
-- projet ; les projets, eux, se créent depuis l'application (un Chief Product,
-- une équipe, un référent par département).
-- =============================================================================

do $$
declare
  root uuid; dg uuid; ops uuid; tech uuid; dev uuid; mkt uuid; biz uuid; fin uuid; leg uuid; rh uuid;
begin
  if exists (select 1 from public.org_units) then
    raise notice 'Organisation déjà initialisée — aucune action.';
    return;
  end if;

  insert into public.org_units (name, code, kind, domain, color, sort_order, description, head_title, deputy_title, is_core)
  values ('VERIION', 'VRN', 'company', 'direction', '#050816', 0,
          'La holding : l''écosystème numérique de l''Afrique',
          'CEO — Directeur Général', 'Directeur Général Adjoint', true)
  returning id into root;

  -- ── Équipe administrative : les fonctions transverses de la holding ────────
  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description, head_title, deputy_title, member_title, is_core) values
    (root, 'Direction Générale',   'DG',   'department', 'direction',  '#0B1F3A', 1,
     'Vision, arbitrages, validations et pilotage de la holding',
     'CEO — Directeur Général', 'Directeur Général Adjoint', 'Chargé de mission', true)
  returning id into dg;

  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description, head_title, deputy_title, member_title, is_core) values
    (root, 'Opérations',           'OPS',  'department', 'operations', '#0E7490', 2,
     'Calendrier opérationnel des projets, exécution, qualité et reporting',
     'COO — Directeur des Opérations', 'Responsable des Opérations', 'Chargé des opérations', true)
  returning id into ops;

  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description, head_title, deputy_title, member_title, is_core) values
    (root, 'Technologie',          'TECH', 'department', 'technology', '#4F46E5', 3,
     'Plateformes, architecture, infrastructure et sécurité des produits',
     'CTO — Directeur Technique', 'Responsable Technique', 'Ingénieur', true)
  returning id into tech;

  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description, head_title, deputy_title, member_title, is_core) values
    (root, 'Finance',              'FIN',  'department', 'finance',    '#059669', 4,
     'Budgets, trésorerie, facturation et contrôle financier des projets',
     'CFO — Directeur Financier', 'Responsable Financier', 'Chargé de gestion', true)
  returning id into fin;

  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description, head_title, deputy_title, member_title, is_core) values
    (root, 'Business',             'BIZ',  'department', 'business',   '#EA580C', 5,
     'Ventes, partenariats et développement commercial des produits',
     'CBO — Directeur Business', 'Responsable Business', 'Chargé d''affaires', true)
  returning id into biz;

  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description, head_title, deputy_title, member_title, is_core) values
    (root, 'Marketing',            'MKT',  'department', 'marketing',  '#DB2777', 6,
     'Acquisition, marque, communication et contenu',
     'CMO — Directeur Marketing', 'Responsable Marketing', 'Chargé marketing', true)
  returning id into mkt;

  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description, head_title, deputy_title, member_title, is_core) values
    (root, 'Juridique',            'LEG',  'department', 'legal',      '#7C3AED', 7,
     'Contrats, conformité, propriété intellectuelle et contentieux',
     'Directeur Juridique', 'Juriste principal', 'Juriste', true)
  returning id into leg;

  insert into public.org_units (parent_id, name, code, kind, domain, color, sort_order, description, head_title, deputy_title, member_title, is_core) values
    (root, 'Ressources Humaines',  'RH',   'department', 'hr',         '#0D9488', 8,
     'Recrutement, contrats de travail, paie et parcours des collaborateurs',
     'CHRO — Directeur des Ressources Humaines', 'Responsable RH', 'Chargé RH', true)
  returning id into rh;

  -- ── Sous-départements : la coordination fine des projets ──────────────────
  insert into public.org_units (parent_id, name, code, kind, color, sort_order, description, head_title) values
    (dg,   'Cabinet du CEO',         'DG-CAB',  'subdepartment', '#0B1F3A', 1, 'Préparation des arbitrages et suivi des décisions', 'Chef de cabinet'),
    (ops,  'Planification',          'OPS-PLN', 'subdepartment', '#0E7490', 1, 'Écrit les calendriers mensuels, hebdomadaires et journaliers des projets', 'Responsable planification'),
    (ops,  'Qualité & Process',      'OPS-QA',  'subdepartment', '#0E7490', 2, 'Méthodes, qualité de livraison et amélioration continue', 'Responsable qualité'),
    (tech, 'Infrastructure',         'TECH-INF','subdepartment', '#4F46E5', 2, 'Hébergement, sécurité et disponibilité des plateformes', 'Responsable infrastructure'),
    (fin,  'Comptabilité',           'FIN-CPT', 'subdepartment', '#059669', 1, 'Tenue des comptes et facturation', 'Chef comptable'),
    (fin,  'Contrôle financier',     'FIN-CTL', 'subdepartment', '#059669', 2, 'Budgets des projets et contrôle des dépenses', 'Contrôleur de gestion'),
    (biz,  'Commercial',             'BIZ-COM', 'subdepartment', '#EA580C', 1, 'Ventes et relation client', 'Responsable commercial'),
    (biz,  'Partenariats',           'BIZ-PAR', 'subdepartment', '#EA580C', 2, 'Alliances et développement de l''écosystème', 'Responsable partenariats'),
    (mkt,  'Acquisition',            'MKT-ACQ', 'subdepartment', '#DB2777', 1, 'Croissance et acquisition d''utilisateurs', 'Responsable acquisition'),
    (mkt,  'Communication',          'MKT-COM', 'subdepartment', '#DB2777', 2, 'Marque, relations publiques et réseaux', 'Responsable communication'),
    (mkt,  'Contenu',                'MKT-CNT', 'subdepartment', '#DB2777', 3, 'Production éditoriale et créative', 'Responsable contenu'),
    (leg,  'Contrats',               'LEG-CTR', 'subdepartment', '#7C3AED', 1, 'Rédaction, revue et suivi des contrats de la holding', 'Responsable contrats'),
    (leg,  'Conformité',             'LEG-CMP', 'subdepartment', '#7C3AED', 2, 'Conformité réglementaire, données personnelles et risques', 'Responsable conformité'),
    (rh,   'Recrutement',            'RH-REC',  'subdepartment', '#0D9488', 1, 'Sourcing, entretiens et intégration', 'Responsable recrutement'),
    (rh,   'Administration du personnel', 'RH-ADP', 'subdepartment', '#0D9488', 2, 'Contrats, paie, congés et dossiers du personnel', 'Responsable administration RH');

  insert into public.org_units (parent_id, name, code, kind, color, sort_order, description, head_title)
  values (tech, 'Développement', 'TECH-DEV', 'subdepartment', '#4F46E5', 1, 'Conception et développement des produits', 'Responsable développement')
  returning id into dev;

  insert into public.org_units (parent_id, name, code, kind, color, sort_order, head_title) values
    (dev, 'Backend',  'TECH-DEV-BE', 'team', '#4F46E5', 1, 'Chef d''équipe Backend'),
    (dev, 'Frontend', 'TECH-DEV-FE', 'team', '#4F46E5', 2, 'Chef d''équipe Frontend'),
    (dev, 'Mobile',   'TECH-DEV-MB', 'team', '#4F46E5', 3, 'Chef d''équipe Mobile');

  -- Canal général de la holding
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
