# Audit de VERIION OS — état des lieux, corrections, feuille de route

> Audit réalisé le 9 octobre 2026 sur la branche `claude/audit-os-veriion-k6c0qr` (commit `bf1918c`).
> Objectif : faire de VERIION OS le **système d'exploitation organisationnel** de VERIION, de ses filiales, équipes et projets — et non un simple tableau de bord.

---

## Sommaire

0. [Synthèse pour la direction](#0-synthèse-pour-la-direction)
1. [Périmètre et méthode](#1-périmètre-et-méthode)
2. [Question 1 — Qu'avons-nous déjà développé ?](#2-question-1--quavons-nous-déjà-développé-)
3. [Question 2 — Que faut-il corriger ou renforcer ?](#3-question-2--que-faut-il-corriger-ou-renforcer-)
4. [Question 3 — Que faut-il construire ensuite ?](#4-question-3--que-faut-il-construire-ensuite-)
5. [Feuille de route par phases](#5-feuille-de-route-par-phases)
6. [Annexes](#6-annexes)

---

## 0. Synthèse pour la direction

**Verdict : une base technique solide, une gouvernance encore contournable, et des modules qui coexistent sans former un système.**

Ce qui est acquis :

- Une vraie application, pas une maquette : environ 18 000 lignes de TypeScript (Next.js 15 / React 19) et 5 000 lignes de SQL (Supabase / PostgreSQL), **17 modules branchés sur de vraies données**. Le typecheck, le lint et le build de production passent sans erreur.
- Un choix d'architecture juste : la base de données porte la sécurité (RLS sur toutes les tables, fonctions `has_perm` / `in_unit`) et une partie des règles métier (triggers).
- Des briques avancées déjà réelles : co-édition temps réel (Yjs), Drive avec espaces et partages, messagerie complète, notifications push/e-mail, organigramme historisé avec droits automatiques.

Ce qui bloque l'ambition « système d'exploitation » :

1. **La gouvernance du CEO se contourne.** Six contournements ont été **démontrés en base** (voir §3.1) : un administrateur peut relever le seuil des validations à l'infini, suspendre le CEO ou s'attribuer le droit de valider à sa place ; un budget approuvé peut être multiplié par 900 après l'accord ; un même accord de dépense couvre un nombre illimité de dépenses ; un collaborateur peut clôturer seul une tâche soumise à vérification.
2. **Les circuits de validation existent en base mais pas dans l'interface.** Les budgets créés depuis l'écran restent « brouillon » pour toujours ; aucune dépense au-dessus du seuil ne peut être saisie (aucun champ pour rattacher l'accord) ; les contrats de travail ne peuvent jamais être soumis ni signés.
3. **Les opérations restent isolées de leur contexte.** Une nomination ne produit aucun acte ; un contrat n'a ni signature réelle, ni version signée, ni renouvellement automatique ; une dépense n'a ni justificatif, ni ligne budgétaire, ni circuit sous le seuil ; la fiche projet n'affiche ni budget, ni dépenses, ni contrats.
4. **Le modèle ne connaît qu'une seule société.** Les filiales (entités juridiques, devises, fiscalité, comptabilité propres) n'existent pas dans le schéma.
5. **La qualité n'est pas outillée.** 3 des 6 scénarios de test SQL échouent sur la version actuelle ; il n'y a ni test applicatif, ni intégration continue.

Recommandation : **geler les nouvelles fonctionnalités le temps d'une phase 0 « gouvernance fiable »** (correctifs §3.1 et §3.2, tests rétablis, CI), puis construire le **socle transverse** (§4.1 : dossier unifié, moteur de workflows, journal d'événements, génération de documents, multi-entités) **avant** d'ajouter de nouveaux modules. Sans ce socle, chaque nouveau module ajoutera un îlot de plus.

### Maturité par module

| Module | État | En une phrase |
| --- | --- | --- |
| Identité, connexion, code d'accès | 🟢 Réel | Fonctionne ; le « code d'accès » est un verrou d'interface, pas une barrière de sécurité (§3.1-S8) |
| Organisation, nominations, droits automatiques | 🟢 Réel | Historisé et solide ; aucune pièce officielle produite à la nomination |
| Messagerie | 🟢 Réel | Complète (fils, mentions, pièces jointes, réactions, recherche) |
| Drive et éditeurs (texte, tableur, présentation) | 🟢 Réel | Le module le plus abouti ; manque la rétention légale et la signature |
| Notifications (in-app, push, e-mail, rappels) | 🟢 Réel | Fonctionne si pg_cron/pg_net et SMTP/VAPID sont configurés |
| Projets et tâches | 🟡 Partiel | Kanban, dépendances, vérification ; vérification contournable ; fiche projet sans finance ni contrats |
| Calendrier opérationnel (Opérations) | 🟡 Partiel | Cycles, grandes lignes, rapports, accord CEO du mensuel : réels ; pas de lien avec les tâches dans les indicateurs |
| Validations du CEO | 🟠 Fragile | Guichet réel mais contournable, réutilisable, et non relié aux écrans finance/RH |
| Juridique (registre des contrats) | 🟡 Partiel | Registre et rappels d'échéance ; signature = simple changement de statut ; pas d'expiration ni de renouvellement automatiques |
| Finance | 🟠 Fragile | Revenus/dépenses/factures/budgets ; pas de comptabilité, pas de justificatifs, circuit de dépense cassé dans l'interface |
| RH | 🟡 Partiel | Congés, contrats, salaires, parcours ; pas de solde de congés réel, pas de paie, contrats jamais signables |
| CRM | 🟢 Réel | Pipeline, interactions, opportunité gagnée → projet + facture brouillon |
| Objectifs et KPI | 🟡 Partiel | OKR à trois niveaux ; progression saisie à la main, non reliée aux données réelles |
| Réunions | 🟡 Partiel | Planification, invitations, Jitsi, compte rendu ; décisions et actions non extraites en tâches |
| Dashboard de direction | 🟡 Partiel | Données réelles, mais « utilisateurs actifs » et métriques produit sont **saisis à la main** |
| Administration et journal d'audit | 🟡 Partiel | Journal par triggers ; l'administrateur a trop de pouvoir sur la gouvernance |
| Filiales / multi-entités | 🔴 Absent | Une seule ligne `company_settings`, une seule devise, une seule racine |
| Comptabilité, paie, achats, fournisseurs | 🔴 Absent | — |
| Signature électronique, archivage probant | 🔴 Absent | — |
| Moteur de workflows, génération de documents | 🔴 Absent | Chaque circuit est codé à la main dans un trigger |

---

## 1. Périmètre et méthode

**Lu intégralement** : les 10 migrations SQL (`supabase/migrations/`), le middleware et toute la chaîne d'authentification, les routes API (`/api/storage`, `/api/notifications`), les actions serveur des modules Administration, Finance, RH, Validations, Paramètres, et les tests SQL. **Parcouru** : les écrans et composants de chaque module.

**Exécuté** :

| Contrôle | Résultat |
| --- | --- |
| `tsc --noEmit` (TypeScript strict) | ✅ 0 erreur |
| `next lint` | ✅ 0 avertissement |
| `next build` | ✅ build de production réussi, 30+ routes |
| `supabase/tests/run.sh` sur PostgreSQL 16 | ❌ **3 scénarios sur 6 passent** (Drive/messagerie, co-édition/notifications, code d'accès). `10_permissions` et `20_insert_returning` sont cassés par des migrations ultérieures ; `60_holding` s'arrête sur `permission denied for sequence legal_contract_seq` |
| Preuves de contournement (`docs/audit/poc_gouvernance.sql`) | ❌ **6 contournements sur 6 confirmés** (§3.1) |

Légende utilisée dans ce document :
- **Réel** : branché sur la base, utilisable de bout en bout.
- **Partiel** : fonctionne, mais une partie du circuit manque ou n'est pas reliée.
- **Simulé** : l'écran ou le libellé laisse croire à une automatisation qui n'existe pas (donnée saisie à la main, statut sans effet).
- **Absent** : rien dans le code.

---

## 2. Question 1 — Qu'avons-nous déjà développé ?

### 2.1 Ce qui fonctionne réellement

| Domaine | Ce qui est réel | Où |
| --- | --- | --- |
| **Identité** | Compte unique `prenom.nom@veriion.com`, invitation par e-mail (domaine imposé), mot de passe oublié, suspension et départ avec bannissement Supabase Auth, profil obligatoire avant d'entrer | `src/app/(auth)/`, `src/app/(app)/admin/actions.ts` |
| **Code d'accès** | Hachage bcrypt inaccessible même au propriétaire, 5 échecs → blocage 15 min, cookie signé HMAC 12 h, réinitialisation par l'administration journalisée | `migrations/…0008_access_code.sql`, `src/lib/access-code.ts` |
| **Organisation** | Arborescence entreprise → département → sous-unité → équipe ; nomination datée qui clôture l'affectation précédente sans l'effacer ; un seul responsable actif par unité ; fusion d'unités (membres, sous-unités, canaux, dossiers, budgets) ; intitulés de poste portés par l'unité | `…0001_foundation.sql`, `…0009_holding.sql` |
| **Droits** | Droits recalculés à chaque nomination à partir de règles (`role_templates`) ; dérogations nominatives, motivées, datées ; vérifiés par la base (RLS) et non par l'interface | `sync_auto_grants`, `has_perm` |
| **Messagerie** | Canaux directs, de groupe, d'unité et de projet créés automatiquement ; fils, mentions, réactions, épingles, pièces jointes privées, recherche, appel Jitsi | `…0006_messaging.sql`, `src/app/(app)/messages/` |
| **Drive** | 4 espaces (personnel, unité, projet, entreprise), dossiers illimités, partages à une personne ou une unité avec expiration, 3 niveaux de confidentialité, corbeille 30 jours, versions et restauration, recherche plein texte | `…0005_drive.sql`, `src/app/(app)/documents/` |
| **Éditeurs** | Texte (TipTap), tableur (formules FR/EN), présentations ; co-édition Yjs temps réel avec curseurs ; import/export Office et PDF | `src/components/editors/`, `src/lib/collab/` |
| **Projets et tâches** | Kanban glisser-déposer, sous-tâches, dépendances bloquantes en base, commentaires, assignation limitée à son périmètre (`can_assign_task`), soumission et vérification par celui qui a confié | `…0010_operations_legal.sql` §6 |
| **Calendrier opérationnel** | Cycles mensuels/hebdomadaires/journaliers, grandes lignes avec résultat attendu, publication, accord CEO du mensuel qui publie automatiquement, rapports de cycle et accusé de réception | `…0010` §4, `src/app/(app)/operations/` |
| **Validations du CEO** | File unique, refus obligatoirement motivé, notification du demandeur ; blocage en base du lancement de projet, de la publication du calendrier mensuel, de la signature de contrat, de l'activation de budget et des dépenses au-dessus du seuil | `…0010` §1-3 |
| **Juridique** | Registre (NDA, partenariat, client, fournisseur, licence, statuts), référence automatique, risque, échéance, préavis, rappel quotidien avant échéance | `…0010` §5 |
| **CRM** | Comptes, contacts, pipeline glisser-déposer, interactions ; **opportunité gagnée → compte client + projet de livraison + facture brouillon** | `opportunities_before_update` |
| **Finance** | Revenus, dépenses, factures avec lignes et TVA, budgets par unité ; **facture payée → revenu** ; factures en retard marquées chaque matin | `…0002_modules.sql` |
| **RH** | Demandes de congé validées par le responsable (pas par soi-même), contrats, salaires confidentiels (journal masqué), parcours d'arrivée créé automatiquement, départ qui clôture les affectations et désassigne les tâches | `leave_requests_before_update`, `offboard_employee` |
| **Notifications** | In-app temps réel, push Web (VAPID), e-mails regroupés ou résumé quotidien, préférences par catégorie, « ne pas déranger », rappels (échéances, retards, réunions, contrats, rapports) ; files réservées en base sans doublon | `…0007_collab_notifications.sql`, `src/lib/server/dispatch.ts` |
| **Audit** | Triggers d'audit sur les tables sensibles (acteur, avant/après, champs modifiés) | `audit_trigger` |

### 2.2 Ce qui est incomplet

| Élément | Ce qui manque |
| --- | --- |
| **Budgets** | L'écran crée les budgets sans statut → ils restent `draft` à vie ; l'accord du CEO n'est donc jamais demandé et l'écran affiche quand même le montant comme s'il était actif (`src/app/(app)/finance/actions.ts:40`). Aucun écran pour les **budgets de projet**, pourtant présents en base. Pas de lignes budgétaires (un seul montant par unité et par an). |
| **Dépenses au-dessus du seuil** | La base exige `approval_id`, mais le formulaire ne propose pas de le renseigner (`finance/actions.ts:14`) : **toute dépense au-dessus de 500 000 XOF échoue pour tout le monde sauf le CEO**. |
| **Contrats de travail** | La base prévoit `draft → pending_ceo → signed`, mais l'écran n'insère que des brouillons et n'offre ni soumission ni signature (`rh/actions.ts:44`). Le salaire est enregistré sans attendre l'accord. |
| **Seuil de validation** | Le README le dit « réglable dans Paramètres » : aucun écran ne permet de le modifier (il n'est que lu dans `validations/page.tsx`). |
| **Juridique** | Statuts `expired` / `terminated` jamais posés automatiquement ; `auto_renew` sans effet ; l'étape « revue juridique » n'est pas obligatoire (on peut soumettre un brouillon directement) ; aucun lien entre contrat juridique `employment` et contrat de travail RH. |
| **Congés** | Pas de solde (droits acquis, consommés) en base ; pas de contrôle de chevauchement ; jours calendaires (week-ends et fériés comptés). |
| **Fiche projet** | Affiche tâches, membres, cycles, rapports, dossier, canal ; n'affiche **ni budget, ni dépenses, ni factures, ni contrats, ni réunions**, alors que toutes ces tables portent un `project_id`. |
| **Objectifs** | Progression des résultats clés saisie à la main ; aucun lien vers un KPI calculé, une tâche ou une donnée financière. |
| **Réunions** | Le compte rendu est un texte libre ; décisions et actions ne deviennent ni tâches ni décisions tracées. |
| **Départ d'un collaborateur** | Les documents dont il est propriétaire, les projets qu'il dirige, ses rôles de référent et ses validations en attente ne sont pas transférés. |
| **Factures** | Numérotation par séquence globale (trous possibles, pas de remise à zéro annuelle, pas de série par entité) ; facture modifiable et supprimable après envoi ou paiement. |

### 2.3 Ce qui est simulé (l'écran promet plus que le système ne fait)

| Élément | Réalité |
| --- | --- |
| **« Utilisateurs actifs » du dashboard** | Ne compte pas les utilisateurs : additionne `product_metrics.active_users`, **saisi à la main** depuis le dashboard (`direction/actions.ts:13`). Aucune connexion aux plateformes (Oniix, iSkul, Wiix, Eduoo). |
| **Signature des contrats** | « Signer » = passer le statut à `active`. Aucune signature électronique, aucune version signée figée, aucune preuve. |
| **Code d'accès** | Présenté comme remplaçant la double authentification. C'est un **verrou d'interface** : la session Supabase reste valide et utilisable directement contre l'API sans le code (§3.1-S8). |
| **Checklist d'arrivée** | Contient « Activer l'authentification à deux facteurs » alors que la 2FA a été retirée (`…0002_modules.sql`, `profiles_after_insert_onboarding`). |
| **« Toute connexion est journalisée »** (écran de connexion) | Le journal de l'application ne trace pas les connexions ; seuls les journaux internes de Supabase Auth le font. |
| **« Accès révoqués »** au départ | Le bannissement Supabase est lancé sans vérifier son résultat (`admin/actions.ts:62`, `:77`). |
| **Données de démonstration** | `supabase/demo.sql` (optionnel) remplit les tableaux de bord de chiffres fictifs ; à ne jamais exécuter en production. |

### 2.4 Ce qui manque totalement

- **Multi-entités / filiales** : entité juridique, devise, fiscalité, numérotation, comptabilité, employeur propres.
- **Comptabilité** : plan comptable (SYSCOHADA), écritures en partie double, journaux, rapprochement bancaire, clôtures.
- **Achats et fournisseurs** : demande d'achat, bon de commande, réception, facture fournisseur, fournisseurs (le CRM ne connaît que prospect / client / partenaire).
- **Notes de frais et justificatifs** : pièce jointe obligatoire, OCR, remboursement.
- **Paie** : bulletins, cotisations, déclarations.
- **Registre des décisions et gouvernance sociale** : conseils d'administration, assemblées, procès-verbaux, délégations de pouvoir formalisées, registre des mandats.
- **Génération de documents officiels** à partir de modèles (décision de nomination, contrat, avenant, attestation).
- **Signature électronique** et **archivage probant** (empreinte, horodatage, rétention légale, gel juridique).
- **Moteur de workflows** paramétrable (étapes, rôles, seuils, délais, relances, escalade).
- **Recrutement** (postes ouverts, candidats, entretiens, offre → contrat).
- **Gestion des actifs** (matériel, licences, accès) et **gestion des risques / conformité**.
- **Intégrations** : API publique, webhooks, banques / mobile money, plateformes produit, calendrier (Google / Microsoft), SSO.
- **Tests applicatifs, intégration continue, environnements séparés** (développement, préproduction, production).

---

## 3. Question 2 — Que faut-il corriger ou renforcer ?

### 3.1 Sécurité et gouvernance — à corriger immédiatement

Les six premiers points ont été **reproduits** sur une base vierge avec `docs/audit/poc_gouvernance.sql` (résultats en annexe A).

| # | Gravité | Constat | Preuve | Correction |
| --- | --- | --- | --- | --- |
| **S1** | Critique | **Un administrateur désactive toutes les validations du CEO** en relevant `ceo_approval_threshold` : la politique `settings: modification` autorise `is_admin()` à modifier toute la ligne. | P2 : seuil passé à 999 999 999 999 | Sortir le seuil de `company_settings` (table de gouvernance modifiable par le CEO seul) ou trigger de garde sur la colonne ; journaliser chaque changement. `migrations/…0003_security.sql:75` |
| **S2** | Critique | **Un administrateur suspend (ou rétrograde) le CEO** : `profiles_guard` interdit seulement de *promouvoir* un CEO. L'action `setUserStatus` bannit ensuite le compte dans Supabase Auth. | P3 : statut du CEO = `suspended` | Interdire à quiconque n'est pas CEO de modifier `status` ou `system_role` d'un CEO ; exiger un second CEO / mandataire pour toute succession. `…0001_foundation.sql:507`, `admin/actions.ts:54` |
| **S3** | Critique | **Un administrateur s'octroie (via un complice) n'importe quel droit**, y compris `approvals.decide` et `finance.admin` : la politique `grants: dérogation` n'interdit que l'auto-attribution. Le README affirme pourtant que l'administrateur n'a pas accès à la finance. | P6 : `admin.deux` reçoit `approvals.decide` et `finance.admin` | Liste de permissions « réservées » (`approvals.decide`, `finance.*`, `hr.admin`, `docs.confidential`, `grants.manage`) attribuables par le CEO seul ; double validation des dérogations sensibles ; durée maximale imposée. `…0003_security.sql:100` |
| **S4** | Critique | **Auto-approbation** : un délégué `approvals.decide` peut valider ses propres demandes (`decide_approval` ne compare pas demandeur et décideur). | P6 : demandeur = décideur | `if a.requested_by = auth.uid() then raise` ; séparation des tâches systématique. `…0010:143` |
| **S5** | Élevée | **Un accord ne couvre pas un contenu figé** : `approval_granted(kind, subject)` ne vérifie que l'existence d'un accord. Budget approuvé à 1 M puis porté à 900 M → toujours valide. Idem pour un contrat modifié après accord (montant, contrepartie, durée). | P4 : budget 900 000 000, statut `active` | Stocker dans la demande un instantané (montant, champs clés, empreinte du document) ; invalider l'accord à toute modification d'un champ couvert ; verrouiller le sujet tant qu'une demande est en attente. `…0010:100` |
| **S6** | Élevée | **Un accord de dépense se réutilise sans limite** : `transactions_guard` vérifie `amount ≥ dépense`, sans décompter ce qui a déjà été consommé. Le fractionnement sous le seuil n'est pas détecté non plus. | P5 : 3 dépenses de 2 M sur un accord de 2 M | Solde consommé par accord (`sum(transactions.amount) ≤ approval.amount`) ; contrôle cumulé par fournisseur / objet / période ; demande liée à un objet précis (bon de commande). `…0010:237` |
| **S7** | Élevée | **Contournement de la vérification des tâches** : le titulaire peut, dans la même requête, passer `requires_validation` à `false` (ou se désigner `reviewer_id`) puis `status = done`. La politique `tâches: modification` lui permet de modifier toutes les colonnes. | P1 : tâche close, `validated_by` vide | Trigger qui interdit au titulaire de modifier `requires_validation`, `reviewer_id`, `reporter_id`, `validated_*` ; transitions de statut uniquement via `submit_task` / `review_task`. `…0003_security.sql:223`, `…0010:753` |
| **S8** | Élevée | **Le code d'accès ne protège pas les données** : il est vérifié uniquement par le middleware Next.js. Les cookies de session `@supabase/ssr` sont lisibles par le navigateur (non `httpOnly`, contrairement à ce qu'indique le README) : avec la session, l'API Supabase répond sans code. | Lecture de `src/lib/supabase/middleware.ts` et `access-code.ts` | Réintroduire une vraie MFA (TOTP / passkeys, AAL2 Supabase) exigée par les politiques RLS sensibles (`auth.jwt()->>'aal' = 'aal2'`) ; garder le code comme verrou de confort. |
| **S9** | Élevée | **Requête de validation trompeuse** : `request_approval` accepte de n'importe quel collaborateur un `subject_id` et un libellé **libres**. On peut présenter au CEO « Petit budget 10 k » qui pointe en réalité un gros budget. | Lecture de `…0010:110` | Le libellé et le montant doivent être **dérivés du sujet** par la base ; seul le propriétaire du sujet (ou son responsable) peut demander. |
| **S10** | Moyenne | **Le CEO contourne toutes les gardes sans trace de décision** : chaque garde commence par `not is_ceo()`. Rien n'apparaît dans le registre des validations. | Lecture | Le CEO passe aussi par une décision enregistrée (même auto-approuvée), pour que le registre soit complet. |
| **S11** | Moyenne | **`dashboard.exec` est un passe-partout** : donné aux responsables Finance, RH et Juridique, il ouvre la lecture de toute la finance, du CRM, de tous les projets, de toutes les unités. | `…0009_holding.sql:491-493` | Permissions de lecture par domaine ; `dashboard.exec` réservé à la Direction. |
| **S12** | Moyenne | **Action serveur à affectation libre** : `updateInvoice(id, patch: Record<string, unknown>)` transmet n'importe quelle colonne (total, numéro, date de paiement). | `finance/actions.ts:73` | Liste blanche de champs, totaux recalculés uniquement par la base, facture verrouillée après envoi. |
| **S13** | Moyenne | **Intégrité financière** : transactions et factures supprimables ; repasser une facture « non payée » supprime le revenu au lieu de passer une écriture d'annulation ; la fusion d'unités réécrit l'historique financier (`unit_id`). | Lecture | Écritures immuables (annulation par contre-passation), clôtures de période, fusion qui conserve l'historique. |
| **S14** | Faible | Tout collaborateur déclenche l'envoi **global** des notifications via « Notification de test » (`parametres/actions.ts:43`). | Lecture | Envoyer seulement la notification de test de l'appelant. |
| **S15** | Faible | Les tables et fonctions créées après la migration 3 reposent sur les privilèges par défaut de Supabase (qui incluent `anon`). Les politiques RLS protègent, mais il n'y a pas de défense en profondeur ; la séquence `legal_contract_seq` n'est même pas accordée explicitement (le test 60 échoue). | Test `60_holding.sql:245` | `revoke … from anon` et `grant` explicites dans chaque migration. |
| **S16** | Faible | Amorçage : « le premier compte créé devient CEO » ; si les inscriptions publiques restent ouvertes après installation, n'importe quelle adresse peut créer un compte employé (le domaine n'est imposé qu'aux invitations). | `handle_new_user` | Refuser en base tout compte hors domaine et toute création hors invitation après l'amorçage. |

### 3.2 Workflows — relier l'interface aux règles de la base

La base de données décrit des circuits que l'interface n'emprunte pas. Résultat : soit l'utilisateur est bloqué, soit le contrôle n'a jamais lieu.

| Circuit | Problème | Correction |
| --- | --- | --- |
| Budget | Créé en `draft`, jamais activé, jamais soumis | Bouton « Soumettre / Activer » ; afficher l'état ; ne compter que les budgets actifs |
| Dépense > seuil | Formulaire sans `approval_id` → échec systématique | Sélecteur « accord du CEO » ou création de la demande depuis le formulaire, puis saisie après accord |
| Contrat de travail | Aucune soumission, aucune signature | Parcours `brouillon → accord CEO → signature → actif`, salaire appliqué à la signature |
| Contrat juridique | Revue juridique facultative, pas d'expiration | Machine à états stricte en base ; tâche planifiée `expired` ; renouvellement tacite qui crée l'avenant |
| Seuil | Non modifiable dans l'interface | Écran CEO dédié, journalisé |
| Projet | Lancement soumis au CEO : réel. Budget de projet : sans écran | Onglet « Finance » du projet (budget, engagé, consommé, factures) |

### 3.3 Architecture

1. **Règles métier dispersées dans des triggers.** Chaque circuit est codé à la main (budgets, contrats, cycles, tâches) avec des variantes. Il faut un **moteur de workflows** unique (§4.1-B) : définitions déclaratives, états, transitions autorisées, gardes, effets.
2. **Migrations qui réécrivent des fonctions existantes** (`tasks_before_write`, `can_manage_project`, `audit_trigger`, `save_document_content` redéfinies plusieurs fois). La version en vigueur n'est lisible qu'en relisant tout l'historique. Adopter un fichier par fonction (schéma déclaratif) ou au minimum un `schema.sql` de référence régénéré.
3. **`install.sql` monolithique + instructions de rattrapage manuelles** dans le README. Passer à la CLI Supabase (`supabase db push`) avec un suivi de version des migrations, et des environnements séparés.
4. **Pas de couche domaine côté application.** Les actions serveur appellent directement les tables ; les mêmes règles (statuts, libellés, droits) sont dupliquées entre `src/lib/auth.ts` (`navAccess`) et le SQL. Générer les types depuis la base (`supabase gen types`) au lieu de `src/lib/types.ts` écrit à la main, et regrouper l'accès aux données par domaine.
5. **Pas de journal d'événements métier.** `audit_log` enregistre des lignes modifiées, pas des faits métier (« contrat signé », « nomination prononcée »). C'est pourtant ce qui permet de relier une opération à son contexte (§4.1-C).
6. **Mono-société.** `company_settings` est une ligne unique (`id boolean check (id)`), la devise est globale, la racine de l'organigramme est unique. L'ajout des filiales touche toutes les tables métier : à faire **avant** d'empiler d'autres modules.
7. **Performance.** Les politiques RLS appellent en cascade des fonctions `security definer` (`document_access` → `folder_access` → `has_perm` → `in_unit`) ligne par ligne ; la fiche projet charge **toutes** les dépendances de tâches visibles (`projets/[id]/page.tsx:43`). Indexer, mettre en cache les droits par requête et paginer avant la montée en charge.

### 3.4 Fiabilité et qualité

| Constat | Action |
| --- | --- |
| 3 scénarios SQL sur 6 en échec (régressions non détectées) | Réparer les tests, les exécuter à chaque commit |
| Aucun test TypeScript / composant / bout en bout | Vitest pour la logique (`sheet-engine`, `converters`, `access-code`), Playwright pour 10 parcours critiques |
| Aucune intégration continue | GitHub Actions : typecheck, lint, build, tests SQL (Postgres en service), tests E2E |
| Erreurs ignorées (bannissement Supabase, envoi de lignes de facture) | Vérifier chaque appel ; transaction ou compensation |
| `next lint` est déprécié | Migrer vers la CLI ESLint |
| Pas d'observabilité | Journalisation structurée, suivi d'erreurs (Sentry ou équivalent), alertes sur les files de notifications |
| Sauvegarde / reprise non testées | Point-in-Time Recovery activé et **restauration testée** chaque trimestre |

### 3.5 Ergonomie

- **Point d'entrée par la tâche, pas par le module** : une boîte « À traiter » unique (validations, vérifications, signatures, congés, rapports) plutôt que des onglets dispersés.
- **Fiche 360°** pour chaque objet (personne, projet, contrat, unité, fournisseur) avec une chronologie de tout ce qui s'y rattache.
- **États explicites** partout (brouillon, en attente de X depuis N jours, bloqué par Y) et **prochaine action** proposée.
- **Messages d'erreur** : certaines erreurs SQL brutes remontent encore (`explain()` ne couvre que quelques codes).
- **Accessibilité** : contrôle des contrastes, navigation au clavier, libellés ARIA sur le Kanban et les éditeurs.
- **Mode hors ligne** partiel (PWA déjà présente) pour la consultation sur réseau mobile instable.

---

## 4. Question 3 — Que faut-il construire ensuite ?

Le principe directeur — **aucune opération isolée de son contexte** — n'est pas une fonctionnalité de plus : c'est une propriété du socle. Il faut donc d'abord construire cinq briques transverses, puis brancher les modules dessus.

### 4.1 Le socle transverse

```
                     ┌──────────────────────────────────────────┐
                     │  A. Graphe d'objets (le « dossier »)     │
                     │  entité · personne · unité · projet ·    │
                     │  contrat · budget · dépense · document · │
                     │  décision · réunion  + liens typés       │
                     └──────────────┬───────────────────────────┘
                                    │
 ┌───────────────────┐   ┌──────────┴──────────┐   ┌──────────────────────┐
 │ B. Moteur de      │──▶│ C. Journal          │──▶│ D. Génération de     │
 │ workflows         │   │ d'événements métier │   │ documents + signature│
 │ (états, gardes,   │   │ (faits immuables,   │   │ + archivage probant  │
 │ seuils, délais)   │   │ abonnements)        │   │                      │
 └───────────────────┘   └─────────────────────┘   └──────────────────────┘
                                    │
                     ┌──────────────┴───────────────────────────┐
                     │  E. Multi-entités : holding + filiales   │
                     │  (entité porte devise, fiscalité, séries,│
                     │  employeur, plan comptable, droits)      │
                     └──────────────────────────────────────────┘
```

**A. Graphe d'objets.** Une table `object_links (source_type, source_id, relation, target_type, target_id, created_by, created_at)` et une vue « contexte » par objet. Toute opération déclare ses liens (une dépense → budget, projet, justificatif, accord). La fiche 360° et la recherche globale s'appuient dessus.

**B. Moteur de workflows.** Définitions versionnées (`workflow_definitions`, `workflow_steps`, `workflow_transitions`) : qui peut faire quoi à quelle étape, à partir de quel montant, avec quel délai et quelle escalade. Instances (`workflow_instances`) attachées à un objet, avec **instantané du contenu validé** (corrige S5). Toutes les validations actuelles (budget, dépense, contrat, cycle, lancement, embauche, congé, tâche) y migrent. La règle « pas de décision sur sa propre demande » est appliquée une fois pour toutes (corrige S4).

**C. Journal d'événements métier.** `domain_events (type, entity_id, subject_type, subject_id, payload, actor_id, occurred_at)` immuable, alimenté par les transitions de workflow. Les automatismes (notifications, documents, mises à jour d'organigramme, écritures comptables) s'abonnent aux événements au lieu d'être codés dans chaque trigger. C'est aussi la chronologie affichée sur chaque fiche.

**D. Documents officiels, signature, archivage.** Modèles (DOCX/HTML) avec champs fusionnés depuis l'objet ; génération PDF ; signature électronique (fournisseur reconnu en Afrique de l'Ouest ou signature avancée interne avec horodatage) ; version signée figée avec empreinte SHA-256 ; durée de rétention par catégorie ; gel juridique ; registre des actes.

**E. Multi-entités.** Table `legal_entities` (holding, filiales : raison sociale, pays, RCCM, IFU, devise, TVA, séries de numérotation, plan comptable) ; `entity_id` sur l'organisation, les contrats, la finance, la RH, les documents ; droits bornés à une entité ou transverses (groupe) ; consolidation au niveau de la holding avec conversion de devises.

### 4.2 Les quatre opérations de référence, de bout en bout

#### Une nomination

| Étape | Aujourd'hui | Cible |
| --- | --- | --- |
| Décision | `appoint_member` immédiat par `org.manage` ou le responsable parent | Workflow : proposition → avis RH → décision du CEO (ou délégataire), selon le niveau du poste |
| Acte | Rien | **Décision de nomination** générée depuis un modèle, signée, classée dans le dossier de la personne et dans le registre des actes |
| Organigramme | Mis à jour, historisé ✅ | Idem, à la date d'effet (nomination future programmée) |
| Droits | Recalculés ✅ | Idem + revue des dérogations devenues sans objet |
| Contrat | Rien | Avenant au contrat de travail (intitulé, rémunération) déclenché si nécessaire |
| Communication | Notification à la personne | Annonce interne optionnelle, ajout aux canaux, passation des dossiers et validations en cours du prédécesseur |

#### Un contrat

| Étape | Aujourd'hui | Cible |
| --- | --- | --- |
| Rédaction | Fiche du registre ; document facultatif | Rédaction depuis un modèle, versions comparables, commentaires |
| Revue | Statut `legal_review` facultatif | Revue juridique **obligatoire**, avis tracé, niveau de risque qui détermine le circuit |
| Validation | Accord CEO sur l'existence du contrat | Accord sur **une version figée** (empreinte) ; toute modification relance le circuit |
| Signature | Changement de statut | Signature électronique des deux parties, PDF signé archivé |
| Exécution | Champ texte « engagements » | Obligations transformées en tâches datées avec responsable ; montants reliés aux factures et dépenses |
| Échéance | Rappel au propriétaire ✅ | Expiration automatique ; renouvellement tacite qui crée l'avenant ; décision « renouveler / renégocier / résilier » soumise à temps |
| Conservation | Document dans le Drive | Archivage probant, rétention légale, gel en cas de litige |

#### Une dépense

| Étape | Aujourd'hui | Cible |
| --- | --- | --- |
| Engagement | Rien avant la saisie | **Demande d'achat** reliée à une ligne budgétaire et à un projet ; contrôle de disponibilité |
| Autorisation | CEO au-delà du seuil, accord réutilisable | Circuit par montant (responsable → finance → CEO), accord consommé au fil des paiements, contrôle anti-fractionnement |
| Fournisseur | Texte libre | Fiche fournisseur (KYC, contrat cadre, coordonnées bancaires vérifiées) |
| Justificatif | Aucun | Facture fournisseur / reçu **obligatoire**, lecture automatique (OCR), rapprochement commande–réception–facture |
| Paiement | Saisie manuelle | Ordre de paiement validé, rapprochement bancaire / mobile money |
| Comptabilité | Ligne dans `transactions` | Écriture SYSCOHADA générée, immuable, période clôturable |
| Suivi | Agrégats par unité | Budget engagé / consommé / disponible en temps réel, par unité, projet et entité |

#### Un projet

| Étape | Aujourd'hui | Cible |
| --- | --- | --- |
| Lancement | Accord CEO ✅ | Dossier de lancement : objectifs, budget, équipe, risques, jalons — validé comme un tout |
| Personnes | Chief Product, équipe, référents ✅ | + charge de chacun, disponibilité (congés), temps passé |
| Planification | Cycles des Opérations ✅, tâches ✅ | Jalons et livrables reliés aux cycles ; tâches reliées aux grandes lignes dans les indicateurs |
| Finances | Budget de projet sans écran | Budget, engagé, dépensé, facturé, marge — sur la fiche projet |
| Documents et contrats | Dossier projet ✅ ; contrats non affichés | Contrats, avenants, PV de réunion, livrables sur la fiche |
| Décisions | Rien | Registre des décisions du projet (réunions, comités), actions converties en tâches |
| Pilotage | Rapports de cycle ✅ | Santé du projet calculée (délais, budget, risques), alertes et escalade automatiques |
| Clôture | Statut `completed` | Bilan, archivage, libération des ressources, leçons apprises |

### 4.3 Nouveaux modules, par ordre de valeur

1. **Gouvernance et registre des décisions** : organes (CA, comité de direction, comités de projet), séances, ordres du jour, PV signés, décisions numérotées, délégations de pouvoir formelles (qui peut engager quoi, jusqu'à quel montant, pour quelle entité) — c'est la source des règles du moteur de workflows.
2. **Achats, fournisseurs, notes de frais** (voir « une dépense »).
3. **Comptabilité et trésorerie multi-entités** : plan SYSCOHADA, journaux, rapprochements bancaires et mobile money, clôtures, états financiers, consolidation.
4. **RH complète** : soldes de congés réels et calendrier des jours fériés par pays, recrutement, dossier salarié, entretiens annuels reliés aux OKR, paie (ou interface avec un logiciel de paie local).
5. **Boîte « À traiter » et fiche 360°** (ergonomie transverse).
6. **Indicateurs calculés** : KPI alimentés automatiquement (finance, projets, RH, plateformes produit via API), OKR reliés aux KPI.
7. **Réunions → décisions → tâches** : compte rendu structuré, décisions et actions extraites.
8. **Actifs et accès** : matériel, licences, comptes SaaS attribués et repris au départ.
9. **Conformité et risques** : registre des risques, contrôles internes, protection des données personnelles (registre des traitements, exercice des droits).
10. **Intégrations** : API publique et webhooks, SSO (Google Workspace / Microsoft 365), calendriers, banques.
11. **Assistant IA interne** (en dernier, sur un socle propre) : recherche dans le graphe d'objets, rédaction de documents depuis les modèles, synthèse des rapports — toujours sous les droits de l'utilisateur.

---

## 5. Feuille de route par phases

Les phases sont ordonnées par dépendance : chacune suppose la précédente terminée.

### Phase 0 — Gouvernance fiable (priorité absolue)

- Corriger S1 à S9 (§3.1) et transformer `docs/audit/poc_gouvernance.sql` en tests de non-régression qui doivent **échouer à contourner**.
- Brancher les circuits existants dans l'interface (§3.2) : budget, dépense au-dessus du seuil, contrat de travail, seuil réglable par le CEO.
- Réparer les 3 scénarios SQL en échec ; ajouter GitHub Actions (typecheck, lint, build, tests SQL).
- Vraie MFA (TOTP ou passkeys) exigée pour les rôles CEO, administration, finance, RH, juridique.
- Corriger les éléments « simulés » trompeurs (§2.3) : libellés, checklist 2FA, journal des connexions.

### Phase 1 — Socle transverse

- Multi-entités (E) : holding + filiales, `entity_id` partout, droits par entité.
- Journal d'événements métier (C) et graphe d'objets (A), fiche 360° générique.
- Moteur de workflows (B) ; migration de toutes les validations existantes ; boîte « À traiter ».
- Génération de documents depuis modèles (D, partie 1) ; registre des actes.
- Types générés depuis la base, schéma de référence, environnements dev / préprod / prod.

### Phase 2 — Les quatre opérations de référence de bout en bout

- Nomination (§4.2) avec décision générée et signée.
- Contrat avec signature électronique, archivage probant, obligations → tâches, renouvellement automatique.
- Dépense : achats, fournisseurs, justificatifs obligatoires, budgets par ligne, contrôle anti-fractionnement.
- Projet : onglet finance, contrats, décisions, santé calculée.
- Tests E2E Playwright sur ces quatre parcours.

### Phase 3 — Profondeur métier

- Comptabilité SYSCOHADA et trésorerie multi-entités, consolidation.
- RH complète (soldes, recrutement, entretiens, paie ou interface paie).
- Gouvernance sociale (organes, séances, PV), délégations de pouvoir.
- Indicateurs calculés et OKR reliés aux données.

### Phase 4 — Ouverture et intelligence

- API publique, webhooks, SSO, intégrations bancaires et plateformes produit.
- Actifs, conformité, risques, protection des données.
- Assistant IA sur le graphe d'objets.

### Critères de sortie de la phase 0

- [ ] Les 6 preuves de contournement échouent (accès refusé) et sont exécutées en CI.
- [ ] Les 6 scénarios SQL existants passent.
- [ ] Un budget au-dessus du seuil créé depuis l'écran ne devient actif qu'après accord du CEO.
- [ ] Une dépense au-dessus du seuil peut être saisie depuis l'écran une fois l'accord obtenu, et une seule fois pour son montant.
- [ ] Un contrat de travail peut être soumis, approuvé et signé depuis l'écran RH.
- [ ] Aucun administrateur ne peut modifier le seuil, le statut du CEO ou s'attribuer une permission réservée.
- [ ] La MFA est exigée pour les rôles sensibles.

---

## 6. Annexes

### A. Résultats des preuves de contournement

Script : [`docs/audit/poc_gouvernance.sql`](audit/poc_gouvernance.sql). Exécution sur PostgreSQL 16 après `00_supabase_stub.sql`, les 10 migrations et `seed.sql` :

```
== P1 : le titulaire contourne la vérification de sa tâche
 P1 statut=done validated_by=∅
== P2 : un administrateur relève le seuil des validations du CEO
 P2 seuil=999999999999.00
== P3 : un administrateur suspend le CEO
 P3 statut CEO=suspended
== P4 : budget approuvé puis gonflé après accord
 P4 budget=900000000.00 statut=active
== P5 : un seul accord de dépense réutilisé plusieurs fois
 P5 dépenses sur un seul accord=3
== P6 : un admin donne approvals.decide / finance.admin à un autre admin
 P6 auto-approbation: demandeur=décideur ? true
```

Reproduire :

```bash
U=postgresql://postgres@localhost:5432
psql $U/postgres -c "drop database if exists poc" -c "create database poc"
for f in supabase/tests/00_supabase_stub.sql supabase/migrations/*.sql supabase/seed.sql; do
  psql $U/poc -q -v ON_ERROR_STOP=1 -f "$f" > /dev/null
done
psql $U/poc -f docs/audit/poc_gouvernance.sql | grep -E "^==|P[0-9]|ERROR"
```

Une fois la phase 0 terminée, chaque ligne `P*` doit être remplacée par une erreur `42501` (accès refusé).

### B. Résultats des tests SQL fournis

```
✔ Migrations appliquées
ERROR (10_permissions_scenario.sql:33)  Dépense au-dessus du seuil : rattachez-la à un accord du CEO…
ERROR (20_insert_returning.sql:11)      Unité introuvable ou archivée
✔ Scénarios Drive & messagerie OK
✔ Scénarios co-édition & notifications OK
✔ Code d'accès : 7 contrôles OK
ERROR (60_holding.sql:245)              permission denied for sequence legal_contract_seq
```

Les deux premiers échecs sont des **régressions** : les scénarios n'ont pas été mis à jour quand la migration 10 a ajouté le seuil de dépense et quand le `seed.sql` a changé les codes d'unités.

### C. Principaux fichiers cités

| Fichier | Rôle |
| --- | --- |
| `supabase/migrations/20260925000001_foundation.sql` | Identité, organisation, droits, audit, `profiles_guard` |
| `supabase/migrations/20260925000003_security.sql` | Politiques RLS (dont `settings`, `grants`, `tâches`) |
| `supabase/migrations/20260929000009_holding.sql` | Holding, référents, fusion, droits Juridique/RH |
| `supabase/migrations/20260930000010_operations_legal.sql` | Validations, budgets/dépenses, cycles, juridique, tâches vérifiées |
| `src/lib/supabase/middleware.ts`, `src/lib/access-code.ts` | Session et verrou par code d'accès |
| `src/app/(app)/admin/actions.ts` | Invitations, suspension, départ, dérogations |
| `src/app/(app)/finance/actions.ts` | Transactions, budgets, factures |
| `src/app/(app)/rh/actions.ts` | Congés, contrats de travail, salaires |
