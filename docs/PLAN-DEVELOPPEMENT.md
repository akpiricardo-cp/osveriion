# Plan de développement de VERIION OS

> Établi le 9 octobre 2026, à partir de l'audit [`AUDIT-OS-VERIION.md`](AUDIT-OS-VERIION.md).
> Ce document traduit les phases de l'audit en **lots livrables** : pour chacun, ce qu'il faut changer (base, serveur, écrans), comment le vérifier et de quels autres lots il dépend.

---

## Sommaire

1. [Règles d'exécution](#1-règles-dexécution)
2. [Décisions attendues de la direction](#2-décisions-attendues-de-la-direction)
3. [Vue d'ensemble des lots](#3-vue-densemble-des-lots)
4. [Phase 0 — Gouvernance fiable](#4-phase-0--gouvernance-fiable)
5. [Phase 1 — Socle transverse](#5-phase-1--socle-transverse)
6. [Phase 2 — Les quatre opérations de bout en bout](#6-phase-2--les-quatre-opérations-de-bout-en-bout)
7. [Phase 3 — Profondeur métier](#7-phase-3--profondeur-métier)
8. [Phase 4 — Ouverture et intelligence](#8-phase-4--ouverture-et-intelligence)
9. [Calendrier indicatif](#9-calendrier-indicatif)
10. [Risques et parades](#10-risques-et-parades)

---

## 1. Règles d'exécution

### 1.1 Une règle, un lot, une pull request

- Chaque lot (`P0-01`, `P1-03`…) donne **une branche et une pull request**. Un lot trop gros pour être relu en une heure est découpé.
- Toute règle métier vit **dans la base** (politique RLS, trigger, fonction). L'écran ne fait qu'afficher et appeler. Une règle qui n'existe que côté écran est un défaut.
- Chaque migration est **rejouable**. Elle accorde explicitement ses droits (`grant` à `authenticated`, `revoke` à `anon`) au lieu de s'appuyer sur les privilèges par défaut de Supabase.
- Une fonction réécrite l'est **en entier** dans la migration qui la change, et sa version courante est recopiée dans `supabase/schema/` (lot `P0-09`). On sait ainsi toujours quelle version est en vigueur.

### 1.2 Définition de « terminé »

Un lot est terminé quand :

1. la migration s'applique sur une base vierge **et** sur une copie de la production ;
2. un scénario SQL couvre la règle : un cas autorisé, et au moins un cas refusé qui doit échouer avec `42501` ;
3. l'écran correspondant est branché, et un test de bout en bout couvre le parcours quand c'est un parcours utilisateur ;
4. typecheck, lint, build et tous les tests passent en intégration continue ;
5. le README (installation, modèle de droits) est mis à jour ;
6. une personne autre que l'auteur a relu la pull request.

### 1.3 Nommage

| Élément | Convention |
| --- | --- |
| Migration | `supabase/migrations/2026MMDDHHMMSS_<lot>_<sujet>.sql`, par ex. `20261013000011_p0_gouvernance.sql` |
| Test SQL | `supabase/tests/<NN>_<sujet>.sql` ; le script de preuve `docs/audit/poc_gouvernance.sql` devient `supabase/tests/70_gouvernance.sql` |
| Test E2E | `e2e/<module>/<parcours>.spec.ts` |
| Branche | `lot/<id>-<sujet>`, par ex. `lot/p0-01-seuil-ceo` |

---

## 2. Décisions attendues de la direction

Ces choix conditionnent des lots. Plus ils sont pris tôt, moins il y aura de travail à refaire.

| # | Décision | Bloque | À trancher avant |
| --- | --- | --- | --- |
| D1 | **Liste des entités** : holding et filiales (raison sociale, pays, RCCM, IFU, devise, régime de TVA) | P1-01 | Début de la phase 1 |
| D2 | **Matrice de délégation** : qui engage quoi, jusqu'à quel montant, pour quelle entité ; qui remplace le CEO absent | P0-03, P1-04 | Fin de la phase 0 |
| D3 | **Méthode de double authentification** : application TOTP, clés d'accès (passkeys), ou les deux | P0-07 | Début de la phase 0 |
| D4 | **Signature électronique** : prestataire externe (reconnu dans l'espace OHADA) ou signature avancée interne horodatée | P1-06, P2-02 | Milieu de la phase 1 |
| D5 | **Comptabilité** : tenue dans VERIION OS (SYSCOHADA) ou interface avec un logiciel comptable existant | P3-01 | Fin de la phase 2 |
| D6 | **Paie** : calcul interne ou interface avec un prestataire local | P3-03 | Fin de la phase 2 |
| D7 | **Durées de conservation** par type de document (contrats, pièces comptables, dossiers du personnel) | P1-06 | Milieu de la phase 1 |
| D8 | **Hébergement et région** des données (Supabase, région, sauvegardes), au regard des lois de protection des données des pays d'implantation | P0-10 | Début de la phase 0 |

---

## 3. Vue d'ensemble des lots

Taille : **S** ≈ 1 à 3 jours-développeur, **M** ≈ 4 à 8, **L** ≈ 9 à 15, **XL** > 15 (à découper avant de commencer).

| Lot | Titre | Taille | Dépend de |
| --- | --- | --- | --- |
| **Phase 0 — Gouvernance fiable** | | | |
| P0-00 | Intégration continue et tests réparés | M | — |
| P0-01 | Seuil et paramètres de gouvernance réservés au CEO | S | P0-00 |
| P0-02 | Protection du compte CEO | S | P0-00 |
| P0-03 | Permissions réservées et dérogations encadrées | M | P0-00 |
| P0-04 | Validations : instantané, consommation, séparation des tâches | L | P0-01, P0-03 |
| P0-05 | Tâches : colonnes de vérification protégées | S | P0-00 |
| P0-06 | Circuits budget, dépense et contrat de travail branchés dans l'interface | L | P0-04 |
| P0-07 | Double authentification obligatoire pour les rôles sensibles | M | P0-00, D3 |
| P0-08 | Intégrité financière minimale | M | P0-04 |
| P0-09 | Schéma de référence, types générés, corrections mineures | M | P0-00 |
| P0-10 | Exploitation : environnements, sauvegardes, supervision | M | D8 |
| **Phase 1 — Socle transverse** | | | |
| P1-01 | Multi-entités | XL → 3 sous-lots | P0 terminée, D1 |
| P1-02 | Journal d'événements métier | M | P0 terminée |
| P1-03 | Graphe d'objets et fiche 360° | L | P1-02 |
| P1-04 | Moteur de workflows | XL → 3 sous-lots | P1-02, D2 |
| P1-05 | Boîte « À traiter » | M | P1-04 |
| P1-06 | Modèles, génération de documents et registre des actes | L | P1-02, D7 |
| **Phase 2 — Les quatre opérations de bout en bout** | | | |
| P2-01 | Nomination | M | P1-04, P1-06 |
| P2-02 | Contrat : signature, archivage, obligations, renouvellement | L | P1-04, P1-06, D4 |
| P2-03 | Dépense : achats, fournisseurs, justificatifs, lignes budgétaires | XL → 3 sous-lots | P1-01, P1-04 |
| P2-04 | Projet : finance, contrats, décisions, santé | L | P2-02, P2-03 |
| P2-05 | Tests de bout en bout des quatre parcours | M | P2-01 à P2-04 |
| **Phase 3 — Profondeur métier** | | | |
| P3-01 | Comptabilité et trésorerie multi-entités | XL | P2-03, D5 |
| P3-02 | Gouvernance sociale et registre des décisions | L | P1-06 |
| P3-03 | RH complète | XL | P1-04, D6 |
| P3-04 | Indicateurs calculés et objectifs reliés | L | P1-02 |
| P3-05 | Réunions → décisions → tâches | M | P3-02 |
| **Phase 4 — Ouverture et intelligence** | | | |
| P4-01 | API publique et webhooks | L | P1-02 |
| P4-02 | SSO et calendriers | M | P0-07 |
| P4-03 | Banques et mobile money | L | P3-01 |
| P4-04 | Actifs, conformité, protection des données | L | P1-03 |
| P4-05 | Assistant IA sur le graphe d'objets | L | P1-03 |

---

## 4. Phase 0 — Gouvernance fiable

**But** : aucune règle de gouvernance ne peut plus être contournée, et les circuits existants fonctionnent depuis l'interface. **Aucune nouvelle fonctionnalité** n'est ajoutée pendant cette phase.

### P0-00 — Intégration continue et tests réparés · M

- **Tests SQL**
  - `10_permissions_scenario.sql` : rattacher la dépense de 1 200 000 à un accord, ou la ramener sous le seuil.
  - `20_insert_returning.sql` : utiliser les codes d'unités du `seed.sql` actuel.
  - `60_holding.sql` : accorder `legal_contract_seq` à `authenticated` dans une nouvelle migration (correctif réel, pas seulement du test).
  - `run.sh` : un seul passage par fichier et un code de sortie non nul au premier `ERREUR`. Aujourd'hui, `grep … || true` masque les échecs.
  - Reprendre `docs/audit/poc_gouvernance.sql` en `70_gouvernance.sql`, d'abord marqué « attendu en échec ». Chaque lot P0 retourne un des cas.
- **GitHub Actions** `.github/workflows/ci.yml` : `npm ci`, `tsc --noEmit`, ESLint (migration depuis `next lint`), `next build`, puis les tests SQL sur un service `postgres:16`.
- **Vitest** : premiers tests sur `src/lib/access-code.ts`, `sheet-engine.ts`, `converters.ts`.
- **Acceptation** : la CI est verte sur `main` ; une régression SQL volontaire la fait échouer.

### P0-01 — Seuil et paramètres de gouvernance réservés au CEO · S

- **Base**
  - Nouvelle table `governance_settings` (ligne unique) qui reprend `ceo_approval_threshold`, plus `approval_reminder_days` et `max_grant_days`.
  - RLS : lecture par tout collaborateur actif ; modification par `is_ceo()` seul.
  - Audit : trigger d'audit sur la table.
  - Compatibilité : `ceo_approval_threshold()` lit la nouvelle table ; la colonne de `company_settings` est supprimée après migration des données.
- **Écran** : section « Gouvernance » dans *Paramètres*, visible du CEO seul, avec l'historique des changements tiré du journal.
- **Acceptation** : le cas P2 de `70_gouvernance.sql` échoue avec `42501` ; le CEO modifie le seuil depuis l'écran.

### P0-02 — Protection du compte CEO · S

- **Base** : `profiles_guard` refuse toute modification de `status` ou `system_role` d'un CEO par quelqu'un qui n'est pas CEO.
- **Désignation d'un nouveau CEO** : fonction `transfer_ceo(p_to uuid)` appelable par le CEO seul. Elle est journalisée, et l'ancien CEO devient administrateur.
- **Serveur** : `setUserStatus` et `offboardUser` vérifient le retour de `auth.admin.updateUserById`, annulent le changement de statut en cas d'échec et refusent toute cible CEO.
- **Écran** : les actions sur un CEO sont masquées pour les administrateurs.
- **Acceptation** : le cas P3 échoue ; un test couvre le transfert de CEO.

### P0-03 — Permissions réservées et dérogations encadrées · M

- **Base**
  - Colonne `permissions.reserved boolean`, vraie pour `approvals.decide`, `finance.admin`, `finance.view`, `hr.admin`, `docs.confidential`, `grants.manage`, `dashboard.exec`.
  - Politique `grants: dérogation` : une permission réservée ne peut être accordée que par le CEO ; durée obligatoire et plafonnée à `max_grant_days`.
  - Règles automatiques : retirer `dashboard.exec` aux responsables Juridique et RH ; créer des permissions de lecture par domaine (`finance.view` existe déjà ; ajouter `projects.view_all` et `crm.view` pour la Direction).
  - Recalcul des droits de tous à la fin de la migration.
- **Écran** : *Administration > Droits* signale les permissions réservées et la date d'expiration.
- **Acceptation** : le cas P6 (partie dérogation) échoue ; le responsable RH ne lit plus la finance ; scénario de non-régression sur les droits actuels du CFO et du COO.

### P0-04 — Validations : instantané, consommation, séparation des tâches · L

- **Base**
  - Colonnes ajoutées à `approval_requests` :
    - `subject_snapshot jsonb` : copie des champs couverts au moment de la demande ;
    - `subject_hash text` : empreinte de cet instantané ;
    - `consumed_amount numeric` : somme déjà engagée sur l'accord.
  - `request_approval` :
    - dérive libellé, montant, unité et projet **du sujet** (fonction `approval_subject(kind, id)` par type), au lieu de les recevoir de l'appelant ;
    - n'autorise que le propriétaire du sujet ou son responsable ;
    - verrouille le sujet pendant l'attente (`pending`).
  - `decide_approval` refuse si `requested_by = auth.uid()`.
  - `approval_granted(kind, id)` recalcule l'empreinte du sujet : si elle diffère, l'accord ne vaut plus. Chaque garde (`budgets_guard`, `legal_contracts_guard`, `employment_contracts_guard`, `projects_guard`) l'utilise.
  - `transactions_guard` : `consumed_amount + new.amount ≤ amount`, puis incrément de `consumed_amount`.
  - Contrôle anti-fractionnement : alerte, sans blocage, si la somme des dépenses d'un même fournisseur ou d'une même catégorie dépasse le seuil sur 30 jours.
  - Le CEO passe aussi par une décision enregistrée : chaque garde crée, puis approuve automatiquement, une demande au nom du CEO. Le registre des validations devient complet.
- **Écran** : *Validations* affiche l'instantané validé, le montant consommé et le reste disponible ; un accord devenu caduc est signalé.
- **Acceptation** : les cas P4, P5 et P6 (auto-approbation) échouent ; scénario « contrat modifié après accord → signature refusée ».

### P0-05 — Tâches : colonnes de vérification protégées · S

- **Base**
  - Trigger `tasks_protect_review` : le titulaire ne peut pas modifier `requires_validation`, `reviewer_id`, `reporter_id`, `validated_by` ou `validated_at`.
  - Le passage à `done` d'une tâche qui exige une vérification ne se fait que par `review_task`, au moyen d'un drapeau de session posé par la fonction.
- **Écran** : la case « terminer » du titulaire devient « soumettre » quand une vérification est exigée (`task-drawer.tsx`, `my-tasks.tsx`, `kanban.tsx`).
- **Acceptation** : le cas P1 échoue ; le glisser-déposer vers « Terminé » propose la soumission.

### P0-06 — Circuits branchés dans l'interface · L

| Circuit | Changement |
| --- | --- |
| Budget d'unité | `setBudget` crée en `draft` ; bouton « Soumettre » (demande d'accord si le montant dépasse le seuil, activation directe sinon) ; état affiché ; seuls les budgets actifs entrent dans les consommations |
| Budget de projet | Onglet « Budget » sur la fiche projet (création par la finance, lecture par l'équipe) |
| Dépense au-dessus du seuil | Le formulaire propose les accords disponibles avec leur reste ; bouton « Demander l'accord » prérempli ; message clair au lieu de l'erreur SQL |
| Contrat de travail | `addContract` crée en `draft` ; actions « Soumettre au CEO » puis « Signer » ; le salaire ne s'applique qu'à la signature (trigger) |
| Contrat juridique | Machine à états stricte en base : `draft → legal_review → pending_ceo → signed → active → expired/terminated` ; tâche planifiée quotidienne pour `expired` |

- **Acceptation** : un test E2E par circuit ; les critères de sortie de la phase 0 (audit §5) sont remplis.

### P0-07 — Double authentification obligatoire · M

- **Supabase** : MFA activée (TOTP, plus passkeys selon D3).
- **Base**
  - Fonction `mfa_ok()` qui vaut `auth.jwt()->>'aal' = 'aal2'`.
  - Exigée dans les politiques d'écriture finance, RH et juridique, les décisions de validation et les fonctions d'administration (`offboard_employee`, `clear_access_code`, dérogations).
  - Exigée en lecture pour les salaires et les documents confidentiels.
- **Serveur et écran**
  - Enrôlement guidé au premier accès pour les rôles concernés.
  - Le middleware redirige vers la vérification quand le niveau `aal2` est requis.
  - Le code d'accès reste un verrou de confort.
  - Correction de la checklist d'arrivée (« Activer la double authentification » devient réel).
- **Documentation** : rectifier le README (cookies non `httpOnly`, rôle réel du code d'accès).
- **Acceptation** : avec une session de niveau `aal1`, un appel direct à l'API sur `salaries` renvoie zéro ligne et une écriture finance échoue.

### P0-08 — Intégrité financière minimale · M

- **Base**
  - Facture `sent` ou `paid` : lignes et montants verrouillés ; correction par avoir (nouvelle facture négative liée).
  - Transactions sans `delete` : annulation par contre-passation (`reverses_id`).
  - Repasser une facture « non payée » crée la contre-passation au lieu de supprimer le revenu.
  - Numérotation des factures par exercice sans trou, avec un compteur verrouillé par année. Elle passera par entité au lot P1-01.
  - `merge_org_units` ne réécrit plus `unit_id` des transactions et factures passées ; elle ajoute un lien de succession entre unités.
- **Serveur** : `updateInvoice` accepte une liste blanche de champs (`due_date`, `notes`, `account_id`, `tax_rate` en brouillon seulement) ; l'insertion de la première ligne de facture vérifie son erreur.
- **Acceptation** : scénarios SQL « facture payée immuable », « annulation = contre-passation », « numérotation continue ».

### P0-09 — Schéma de référence, types générés, corrections mineures · M

- `supabase/schema/` : la version courante de chaque fonction et politique, générée par un script et vérifiée en CI.
- `supabase gen types typescript` remplace `src/lib/types.ts` écrit à la main.
- Passage de `install.sql` et des instructions de rattrapage du README à `supabase db push`, avec suivi des versions.
- `revoke all … from anon` sur toutes les tables et fonctions créées depuis la migration 3.
- Inscriptions : refus en base de tout compte hors domaine ou hors invitation après l'amorçage.
- « Notification de test » : envoi limité à l'appelant (`parametres/actions.ts:43`).
- Fiche projet : dépendances filtrées sur les tâches du projet (`projets/[id]/page.tsx:43`).
- `explain()` couvre les codes d'erreur restants avec des messages en français.
- Libellés trompeurs corrigés (audit §2.3) : « Utilisateurs actifs » devient « Utilisateurs des plateformes (saisie manuelle) » ; « Toute connexion est journalisée » est retiré, ou rendu vrai par un journal des connexions.

### P0-10 — Exploitation · M

- **Environnements** : trois projets Supabase (dev, préprod, prod) et trois environnements Vercel ; préprod alimentée par une copie anonymisée.
- **Sauvegardes** : Point-in-Time Recovery activé ; **restauration testée** et documentée (`docs/exploitation/restauration.md`).
- **Supervision** : suivi des erreurs (Sentry ou équivalent), alerte si la file de notifications ne se vide pas, alerte sur les échecs de tâches planifiées (`cron.job_run_details`).
- **Secrets** : rotation documentée de `ACCESS_CODE_SECRET`, `CRON_SECRET` et des clés VAPID.

**Sortie de la phase 0** : les sept critères de l'audit (§5) sont cochés, et `70_gouvernance.sql` passe intégralement, c'est-à-dire que tous les contournements sont refusés.

---

## 5. Phase 1 — Socle transverse

**But** : construire ce qui permet de relier chaque opération à son contexte, avant tout nouveau module.

### P1-01 — Multi-entités · XL (3 sous-lots)

- **P1-01a Modèle**
  - Table `legal_entities` : `id`, `parent_id`, `name`, `legal_name`, `country`, `rccm`, `ifu`, `currency`, `vat_rate`, `fiscal_year_start`, `invoice_prefix`, `is_holding`.
  - `company_settings` devient le paramétrage du groupe ; les paramètres propres à une entité passent sur `legal_entities`.
- **P1-01b Rattachement**
  - Colonne `entity_id` (non nulle, valeur par défaut = holding pendant la migration) sur les tables métier : organisation, projets, budgets, transactions, factures, contrats juridiques, contrats de travail, salaires, documents de l'espace entreprise.
  - Organigramme : une racine par entité sous la holding.
  - Numérotation des factures et des contrats par entité.
- **P1-01c Droits et écrans**
  - `has_perm(perm, unit)` tient compte de l'entité.
  - Les dérogations peuvent être limitées à une entité.
  - Sélecteur d'entité dans la barre du haut ; vues consolidées pour la holding (conversion de devises via une table `fx_rates`).
- **Acceptation** : un CFO de filiale ne voit que sa filiale ; le CFO de la holding voit le consolidé ; scénario de migration d'une base existante sans perte.

### P1-02 — Journal d'événements métier · M

- **Base**
  - Table `domain_events (id, occurred_at, entity_id, type, subject_type, subject_id, actor_id, payload jsonb)`, en ajout seul : aucune modification ni suppression, même par le CEO.
  - Fonction `emit_event(...)` appelée par les transitions métier existantes : nomination, décision de validation, signature, publication de cycle, facture payée, départ.
  - Table `event_subscriptions` et traitement asynchrone (`pg_net` ou file traitée par `/api/events/dispatch`) pour les effets : notifications, documents, écritures.
- **Écran** : chronologie lisible par type d'objet.
- **Acceptation** : chaque transition listée produit exactement un événement ; scénario d'immutabilité.

### P1-03 — Graphe d'objets et fiche 360° · L

- **Base**
  - Table `object_links (source_type, source_id, relation, target_type, target_id, entity_id, created_by, created_at)` ; relations typées (`finance`, `justifie`, `concerne`, `remplace`, `découle_de`…).
  - Fonction `object_context(type, id)` qui ne renvoie que les objets lisibles par l'appelant.
  - Les clés étrangères existantes (`project_id`, `account_id`, `document_id`…) alimentent automatiquement des liens.
- **Écran**
  - Composant `ContextPanel` réutilisable : documents, contrats, budget, dépenses, réunions, décisions, chronologie.
  - Il est intégré aux fiches personne, projet, unité, contrat et compte.
  - La recherche globale passe par le graphe.
- **Acceptation** : la fiche projet montre ses contrats, budgets, dépenses et réunions sans requête spécifique.

### P1-04 — Moteur de workflows · XL (3 sous-lots)

- **P1-04a Modèle**
  - `workflow_definitions` (type d'objet, version, active) ;
  - `workflow_steps` (rôle ou permission attendu, condition de montant, délai, escalade) ;
  - `workflow_instances` (objet, définition, étape courante, instantané, empreinte) ;
  - `workflow_actions` (qui, quoi, quand, commentaire).
  - Règles universelles : pas de décision sur sa propre demande ; un refus est motivé ; une modification du contenu invalide l'instance.
- **P1-04b Migration des circuits**
  - Budget, dépense, contrat juridique, contrat de travail, lancement de projet, calendrier mensuel, congé et tâche vérifiée deviennent des définitions.
  - `approval_requests` est conservée en lecture pour l'historique.
  - La matrice de délégation (D2) est saisie comme données.
- **P1-04c Écrans** : éditeur de circuits pour le CEO (étapes, seuils, délégataires), relances et escalade planifiées, absence et intérim (délégation temporaire automatique).
- **Acceptation** : les scénarios de la phase 0 passent à l'identique sur le moteur ; un nouveau circuit se crée sans migration SQL.

### P1-05 — Boîte « À traiter » · M

- **Base** : vue `my_inbox()` qui regroupe les étapes de workflow attendues de l'utilisateur, les tâches à vérifier, les rapports à accuser, les signatures et les échéances de contrats.
- **Écran** : nouvelle page d'accueil par défaut, avec compteur dans la navigation, filtres par type et ancienneté, et actions en un geste (approuver, renvoyer, signer).

### P1-06 — Modèles, génération de documents, registre des actes · L

- **Base**
  - `document_templates` : type, entité, version, champs attendus, fichier DOCX ou HTML.
  - `generated_documents` : modèle, objet source, document du Drive, empreinte SHA-256, statut.
  - `acts_register` : numéro par entité et par année, type d'acte, objet, signataires, date d'effet.
  - Politique de conservation par catégorie (D7) et gel juridique (`legal_hold`), qui empêche la corbeille et la purge.
- **Serveur** : génération à partir des bibliothèques déjà présentes (`docx`) et conversion PDF ; abonnement aux événements (une nomination prononcée génère sa décision).
- **Écran** : bibliothèque de modèles, registre des actes consultable et exportable.

---

## 6. Phase 2 — Les quatre opérations de bout en bout

Chaque lot suit le tableau « cible » de l'audit (§4.2) et se termine par un test de bout en bout.

### P2-01 — Nomination · M

- Circuit **proposition → avis RH → décision** (selon D2), avec une date d'effet éventuellement future (application par une tâche planifiée).
- À la décision, plusieurs événements s'enchaînent :
  - génération de la **décision de nomination**, puis signature et inscription au registre des actes ;
  - mise à jour de l'organigramme et des droits (existant) ;
  - proposition d'avenant au contrat de travail si l'intitulé ou la rémunération change ;
  - passation des validations et dossiers en cours du prédécesseur ;
  - annonce interne si elle est demandée.

### P2-02 — Contrat · L

- Rédaction depuis un modèle, versions comparables, revue juridique obligatoire dont l'avis est tracé.
- Le circuit varie selon le risque et le montant ; l'accord porte sur une version figée.
- Signature électronique (D4) : envoi, suivi, relances, PDF signé archivé avec son empreinte.
- Les obligations deviennent des tâches datées avec un responsable ; les montants sont reliés aux factures et aux dépenses.
- Expiration automatique. Le renouvellement tacite crée l'avenant, et une décision « renouveler / renégocier / résilier » est soumise avant le préavis.
- Le contrat de travail RH et le contrat juridique `employment` sont unifiés.

### P2-03 — Dépense · XL (3 sous-lots)

- **P2-03a Fournisseurs**
  - Fiche fournisseur : identification, coordonnées bancaires vérifiées (double saisie et validation), contrat cadre.
  - Type `supplier` dans les comptes, ou table dédiée.
- **P2-03b Engagement**
  - Lignes budgétaires (`budget_lines` par catégorie) ; demande d'achat reliée à une ligne et à un projet, avec contrôle du disponible.
  - Circuit par montant ; bon de commande ; réception.
- **P2-03c Paiement**
  - Facture fournisseur et justificatif **obligatoires**, avec lecture automatique (OCR).
  - Rapprochement commande–réception–facture ; ordre de paiement validé.
  - Notes de frais avec reçus.
  - Indicateurs « engagé / consommé / disponible » par ligne, projet et entité.

### P2-04 — Projet · L

- Dossier de lancement unique (objectifs, budget, équipe, risques, jalons), validé comme un tout.
- La fiche projet affiche finance, contrats, réunions, décisions et documents (via P1-03).
- Jalons et livrables reliés aux cycles des Opérations ; avancement calculé à partir des tâches liées aux grandes lignes.
- Santé calculée (délais, budget, risques) avec alertes et escalade.
- Clôture : bilan, archivage, libération des ressources.

### P2-05 — Tests de bout en bout · M

- Playwright, avec le Chromium déjà disponible, sur la préprod réinitialisée par un script de données de test.
- Quatre parcours complets, plus les parcours de la phase 0, exécutés en CI sur chaque pull request qui touche `src/` ou `supabase/`.

---

## 7. Phase 3 — Profondeur métier

| Lot | Contenu |
| --- | --- |
| **P3-01 Comptabilité et trésorerie** (D5) | Plan SYSCOHADA par entité, journaux, écritures générées par les événements (facture, paiement, salaire), lettrage, rapprochement bancaire, clôtures mensuelles et annuelles, balance, grand livre, états financiers, consolidation de la holding |
| **P3-02 Gouvernance sociale** | Organes (conseil d'administration, comité de direction, comités de projet), séances, ordre du jour, quorum, procès-verbaux signés, décisions numérotées ; délégations de pouvoir formelles qui alimentent le moteur de workflows |
| **P3-03 RH complète** (D6) | Soldes de congés réels et jours fériés par pays ; recrutement (postes, candidats, entretiens, offre → contrat) ; dossier salarié ; entretiens annuels reliés aux objectifs ; paie interne ou interface |
| **P3-04 Indicateurs calculés** | Référentiel des KPI avec formule et source (finance, projets, RH, plateformes) ; calcul planifié ; résultats clés des OKR reliés à un KPI ; fin des saisies manuelles du dashboard |
| **P3-05 Réunions → décisions → tâches** | Compte rendu structuré ; décisions inscrites au registre ; actions converties en tâches avec responsable et échéance ; suivi à la réunion suivante |

---

## 8. Phase 4 — Ouverture et intelligence

| Lot | Contenu |
| --- | --- |
| **P4-01 API publique et webhooks** | Clés d'API par entité et par périmètre, limites de débit, webhooks signés à partir de `domain_events`, documentation OpenAPI ; alimentation automatique des métriques des plateformes (Oniix, iSkul, Wiix, Eduoo) |
| **P4-02 SSO et calendriers** | Connexion Google Workspace / Microsoft 365, synchronisation des réunions et des congés avec les agendas |
| **P4-03 Banques et mobile money** | Import des relevés, rapprochement automatique, initiation de paiements selon les possibilités des établissements |
| **P4-04 Actifs, conformité, données personnelles** | Inventaire du matériel et des licences repris au départ ; registre des risques et contrôles internes ; registre des traitements et exercice des droits des personnes |
| **P4-05 Assistant IA** | Recherche et synthèse sur le graphe d'objets **sous les droits de l'utilisateur** ; rédaction depuis les modèles ; résumé des rapports de cycle ; aucune action engageante sans validation humaine |

---

## 9. Calendrier indicatif

**Hypothèse** : une équipe de 3 développeurs (dont un à l'aise avec PostgreSQL), un référent métier disponible une demi-journée par semaine, des sprints de 2 semaines. Le calendrier glisse si les décisions de la section 2 tardent.

| Sprints | Lots | Jalon |
| --- | --- | --- |
| S1 | P0-00, P0-01, P0-02, P0-05, P0-10 (début) | CI verte, quatre contournements fermés |
| S2 | P0-03, P0-04, P0-09 | Tous les contournements fermés |
| S3 | P0-06, P0-07, P0-08, P0-10 (fin) | **Sortie de la phase 0** : gouvernance fiable |
| S4–S6 | P1-01, P1-02, P1-03 | Multi-entités en préprod, fiche 360° |
| S7–S9 | P1-04, P1-05, P1-06 | **Sortie de la phase 1** : moteur de workflows et boîte « À traiter » |
| S10–S14 | P2-01 à P2-05 | **Sortie de la phase 2** : quatre opérations de bout en bout |
| S15 et suivants | Phase 3, puis phase 4, priorisées avec la direction | — |

Soit environ **6 semaines** pour la phase 0, **4 à 5 mois** pour atteindre la fin de la phase 2.

---

## 10. Risques et parades

| Risque | Parade |
| --- | --- |
| Le multi-entités touche toutes les tables et casse l'existant | Valeur par défaut = holding, migration testée sur une copie de la production, sous-lots livrés séparément |
| Le moteur de workflows devient une usine à gaz | Commencer par les circuits existants, sans nouvelle capacité ; ne généraliser qu'au troisième besoin identique |
| Les politiques RLS deviennent lentes avec la volumétrie | Jeu de données de charge en préprod, `explain analyze` en revue, droits calculés une fois par requête |
| Les utilisateurs contournent l'outil (Excel, WhatsApp) quand un circuit bloque | Boîte « À traiter », relances, délégations d'absence, messages d'erreur qui disent quoi faire |
| La double authentification freine l'adoption | Passkeys en priorité, enrôlement accompagné, exigée seulement pour les rôles sensibles au départ |
| Les décisions de la direction tardent | Liste D1–D8 revue à chaque fin de sprint ; les lots bloqués sont décalés sans arrêter l'équipe |
| Une régression de sécurité réapparaît | `70_gouvernance.sql` et les scénarios de refus exécutés à chaque pull request ; revue obligatoire de toute migration touchant une politique |
