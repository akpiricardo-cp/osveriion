# VERIION OS

**Système de gestion et de pilotage interne de VERIION** — une seule identité, un seul organigramme, des droits qui suivent les nominations, et tous les modules métier réunis : communication, projets, CRM, finance, RH, documents, objectifs et dashboard de direction.

> L'écosystème numérique de l'Afrique · usage interne et confidentiel

---

## Sommaire

1. [Ce que contient le projet](#1-ce-que-contient-le-projet)
2. [Architecture](#2-architecture)
3. [Installation pas à pas](#3-installation-pas-à-pas)
4. [Premier démarrage : devenir CEO](#4-premier-démarrage--devenir-ceo)
5. [Modèle de droits](#5-modèle-de-droits)
6. [Déploiement en production](#6-déploiement-en-production)
7. [Tests](#7-tests)
8. [Arborescence](#8-arborescence)
9. [Exploitation & évolutions](#9-exploitation--évolutions)

---

## 1. Ce que contient le projet

| Module | Fonctionnalités |
| --- | --- |
| **Identité & sécurité** | Connexion unique `prenom.nom@veriion.com` (seul ce domaine peut ouvrir un compte), **code d'accès personnel** redemandé à chaque nouvelle session (sans jamais déconnecter), **double authentification (TOTP) imposée aux rôles sensibles** et exigée par la base pour les opérations sensibles, mot de passe oublié, invitation par e-mail, sessions (déconnexion des autres appareils), suspension et départ d'un collaborateur. Le compte du CEO n'est modifiable que par le CEO ; la fonction se **transmet** (*Paramètres › Gouvernance*) |
| **Organisation (holding)** | Deux axes qui se croisent : l'**équipe administrative** (Direction Générale, Opérations, Technologie, Finance, Business, Marketing, Juridique, RH — CEO, COO, CTO, CFO, CBO, CMO…) et les **projets**, chacun dirigé par son **Chief Product**. Chaque département désigne un **référent par projet**, ajouté automatiquement au canal du projet. Organigramme interactif, nomination datée **avec historique**, **fusion de deux unités** (les membres, sous-unités, budgets, canaux et dossiers suivent), création/réduction de départements par le CEO |
| **Intitulés de poste** | Plus aucune saisie libre : l'unité porte les intitulés (responsable, adjoint, membre) et la **nomination attribue le poste**. Diriger un projet donne l'intitulé *Chief Product — <projet>* |
| **Calendrier opérationnel** | Le département des **Opérations** écrit le calendrier de chaque projet (**mensuel**, **hebdomadaire**, **journalier**) sous forme de grandes lignes avec résultat attendu. Le mensuel passe par l'accord du CEO avant publication. Le chef de projet les découpe en tâches, puis **rend compte** à chaque cycle (avancement, blocages, prochaines étapes) ; les Opérations accusent réception |
| **Validations du CEO** | Guichet unique des décisions qui engagent la holding : **budgets et dépenses au-delà d'un seuil** (réglable par le CEO seul), **contrats**, **calendriers mensuels**, **lancement de projet** et **contrats de travail**. L'accord porte sur **un contenu figé** (instantané + empreinte : toute modification le rend caduc), un accord de dépense **se consomme** au fil des paiements, personne ne statue sur **sa propre demande**, et les décisions directes du CEO sont elles aussi inscrites au registre. La base refuse l'opération tant que l'accord valide n'existe pas |
| **Juridique** | Registre des contrats de la holding (NDA, partenariat, client, fournisseur, licence, actes statutaires). Circuit imposé par la base : **rédaction → revue juridique (obligatoire) → accord du CEO → signature**. Un contrat signé ne se modifie plus. **Expiration et renouvellement tacite automatiques**, préavis avec rappel, niveau de risque, engagements à tenir |
| **Droits automatiques** | Nommer quelqu'un responsable modifie **automatiquement** ses droits (règles configurables), dérogations manuelles temporaires et motivées |
| **Communication** | Messagerie temps réel : conversations directes, canaux de groupe (publics/privés), canal par département et par projet, **fils de discussion**, **mentions @** avec autocomplétion et notification, **pièces jointes** (glisser-déposer, coller une capture, aperçu des images), **réactions**, **messages épinglés**, **recherche**, **appel vidéo en un clic** depuis la conversation, indicateur « est en train d'écrire », modification/suppression, non-lus, annonces de la direction |
| **Projets & tâches** | Un projet = un Chief Product, une équipe, des référents. **Répartition hiérarchique** : on ne confie une tâche qu'à soi-même, à son équipe projet ou aux personnes que l'on encadre. Une tâche confiée par quelqu'un d'autre ne se clôt pas seule : son titulaire la **soumet à vérification**, et celui qui l'a confiée **valide ou la renvoie avec un motif**. Kanban glisser-déposer (souris et tactile), vue liste, sous-tâches, dépendances bloquantes, commentaires, temps réel, « Mes tâches » et « À vérifier » |
| **CRM & partenariats** | Prospects/clients/partenaires, contacts, pipeline glisser-déposer, historique des interactions. **Une opportunité gagnée crée automatiquement le projet de livraison et la facture brouillon** |
| **Finance** | Revenus, dépenses, trésorerie, factures (lignes, TVA, impression PDF), budgets par unité **et par projet** (brouillon → activation, accord du CEO au-delà du seuil), analyses par produit/pays/catégorie. **Une facture encaissée génère le revenu comptable.** Intégrité : facture **figée dès son émission**, numérotation **continue par exercice**, aucune opération ne s'efface — on **contre-passe** (écriture inverse motivée) |
| **RH** | Congés (demande, validation par le responsable, notifications), contrats de travail (**brouillon → accord du CEO → signature**, le salaire convenu s'applique à la signature), salaires confidentiels, masse salariale, parcours d'intégration et de départ |
| **Documents (Drive)** | **Dossiers et sous-dossiers illimités** dans 4 types d'espaces : *Mon espace* (privé), *Département/équipe*, *Projet*, *Entreprise*. Droits selon les rôles + partage à une personne ou une unité (Lecteur / Éditeur / Gestionnaire, avec expiration), « Partagés avec moi », Récents, Favoris, corbeille (30 jours), déplacement par glisser-déposer, 3 niveaux de confidentialité, recherche plein texte **dans le contenu** |
| **Éditeurs intégrés** | **Documents texte** (type Word : titres, listes, tableaux, images, couleurs, liens, cases à cocher), **tableurs** (type Excel : formules en français ou en anglais `SOMME`, `SI`, `RECHERCHEV`, `NB.SI`…, plusieurs feuilles, formats monétaire FCFA / % / date, somme automatique), **présentations** (type PowerPoint : dispositions, thèmes, images, notes de l'orateur, mode présentation plein écran). **Co-édition en temps réel** : plusieurs personnes écrivent dans le même document au même moment, avec le curseur et le nom de chacun (fusion Yjs pour le texte, cellule par cellule pour le tableur, diapositive par diapositive pour les présentations — on voit qui est sur quelle cellule ou quelle diapositive). Enregistrement automatique, **historique des versions avec restauration**. Import Word/Excel/CSV, export **.docx / .xlsx / .pptx / CSV / PDF**. Visionneuse PDF, images, vidéo, audio pour les fichiers déposés |
| **Objectifs & KPI** | OKR entreprise → département → individuel, résultats clés mesurables, progression calculée, référentiel unique des indicateurs |
| **Notifications** | Dans l'application (cloche + alerte en direct), **sur téléphone et ordinateur** (notifications push, application installable sur l'écran d'accueil), **par e-mail** (regroupé quelques minutes après une notification non lue, ou **résumé quotidien** à l'heure choisie). Préférences par personne et par type (messages, tâches, validations, réunions, documents, RH, annonces), plage « ne pas déranger ». **Rappels automatiques** : échéances du jour, tâches en retard, validations et congés en attente (chaque matin), réunion qui commence dans 15 minutes |
| **Réunions** | Planification, invitations, réponses, salle de visioconférence (Jitsi), comptes rendus |
| **Dashboard de direction** | Utilisateurs actifs, revenus, dépenses, trésorerie, pipeline, projets, tâches en retard, performance par département, incidents, objectifs |
| **Administration** | Comptes, droits effectifs, règles automatiques, **journal d'activité immuable**, paramètres de l'entreprise |

Recherche globale `Ctrl/⌘ + K`, thème clair/sombre, **100 % en français**.

**Pensé pour le téléphone d'abord** : barre de navigation basse à portée du pouce (Accueil, Tâches, Messages, Projets, et le reste en tiroir), boîtes de dialogue ancrées en bas de l'écran, champs de saisie à 16 px (pas de zoom intempestif sur iOS), zones de sécurité respectées sous l'encoche et la barre d'accueil, application installable sur l'écran d'accueil.

---

## 2. Architecture

```
Navigateur (Next.js — React 19)
        │  HTTPS, session en cookies (@supabase/ssr) + verrou httpOnly du code d'accès
        ▼
Next.js 15 (App Router) ── Server Components (lecture) ── Server Actions (écriture)
        │                         middleware : rafraîchit la session, protège les routes
        ▼
Supabase
 ├── Auth ............ identités, invitations
 ├── PostgreSQL ...... schéma métier + RLS sur 100 % des tables + triggers
 ├── Realtime ........ messages, notifications, tâches, co-édition (broadcast + présence)
 ├── Storage ......... documents, doc-assets (images des documents), chat (pièces jointes) — privés ; avatars (public)
 ├── pg_cron ......... factures en retard, purge de la corbeille, rappels (échéances, réunions)
 └── pg_net .......... déclenche l'envoi des notifications (push immédiat, e-mails chaque minute)

Envoi hors plateforme : /api/notifications/dispatch (Next.js) → SMTP de veriion.com (e-mails)
                                                             → Web Push / VAPID (téléphones, ordinateurs)
```

**Principe central : la base de données est la source de vérité de la sécurité.** L'interface masque ce que vous ne pouvez pas faire, mais c'est PostgreSQL (Row Level Security) qui refuse réellement l'accès, même si quelqu'un appelait l'API directement.

- `has_perm(permission, unité)` : l'utilisateur détient-il la permission, globalement ou sur une unité parente ?
- `in_unit(unité)` : est-il membre de l'unité ou d'une de ses sous-unités ?
- Les triggers portent les règles métier (dépendances de tâches, validation, facture payée → revenu, opportunité gagnée → projet + facture, notifications, audit).

Stack : Next.js 15 · React 19 · TypeScript strict · Tailwind CSS 4 · Radix UI · dnd-kit · Recharts · TipTap (éditeur de texte) · fast-formula-parser (formules) · docx / exceljs / pptxgenjs / mammoth (import-export Office) · Supabase (Postgres 15+).

**Le modèle : une holding et ses projets.** VERIION pilote plusieurs produits ; l'organisation croise deux axes.

```
                         VERIION (holding) — CEO
                                   │
   ┌──────────┬──────────┬─────────┼─────────┬──────────┬──────────┬──────────┐
  DG         OPS        TECH      FIN       BIZ        MKT        LEG        RH
 (CEO)      (COO)      (CTO)     (CFO)     (CBO)      (CMO)   (Juridique)  (CHRO)
   └──────────┴──────────┴─────────┴─────────┴──────────┴──────────┴──────────┘
                    chaque département désigne UN RÉFÉRENT par projet
                                   │
              ┌────────────────────┼────────────────────┐
           Projet A             Projet B             Projet C
      Chief Product +      Chief Product +      Chief Product +
          équipe               équipe               équipe
```

Le travail descend et remonte toujours par le même chemin :

1. les **Opérations** écrivent le calendrier du projet (mensuel, hebdomadaire, journalier) ;
2. le calendrier mensuel reçoit l'**accord du CEO**, puis est publié au projet ;
3. le **Chief Product** découpe chaque grande ligne en **tâches** qu'il répartit dans son équipe, lui compris ;
4. chaque membre **soumet** sa tâche terminée ; celui qui l'a confiée **vérifie** ;
5. le Chief Product **rend compte** aux Opérations à la clôture du cycle.

Les départements ne commandent pas les équipes : ils coordonnent par leur référent, qui est membre du canal du projet et voit son avancement.

**Code d'accès personnel (verrou de session).** Chaque collaborateur choisit un code connu de lui seul, demandé à chaque nouvelle session du navigateur pour rouvrir son espace :

- il remplace la double authentification TOTP, qui obligeait à ressortir son téléphone et cassait la session ;
- **il ne déconnecte jamais** : la session Supabase reste ouverte, l'application est seulement verrouillée. Le code rouvre l'espace là où on l'avait laissé ;
- seul un hachage bcrypt est conservé, dans une table `access_codes` sans aucune policy RLS ni droit de lecture : tout passe par `set_access_code`, `verify_access_code` et `has_access_code` ;
- 5 échecs consécutifs bloquent la saisie 15 minutes ; un administrateur peut effacer un code oublié (*Administration > Comptes*), la personne en choisit alors un nouveau ;
- une fois le code accepté, un cookie `httpOnly` signé (HMAC-SHA256, `ACCESS_CODE_SECRET`) déverrouille l'espace pour la session du navigateur — 12 heures au maximum. Le middleware le vérifie à chaque requête, y compris pour les Server Actions et les fichiers ;
- **limite** : le code d'accès est vérifié par l'application, pas par la base. La session Supabase (cookies lisibles par le navigateur, nécessaires au temps réel) reste utilisable directement contre l'API. C'est pourquoi les opérations sensibles exigent, **en base**, la double authentification.

Les fichiers privés ne sont jamais exposés par URL publique : ils passent par la route `/api/storage/<bucket>/…` qui les lit **avec la session de l'utilisateur**, donc sous les politiques RLS du stockage.

---

## 3. Installation pas à pas

### Prérequis

- Node.js **20.9+** (22 recommandé)
- Un projet Supabase (gratuit pour démarrer) : <https://supabase.com/dashboard>

### Étape 1 — Créer le projet Supabase

Créez le projet, choisissez une région proche (ex. `eu-west` ou `af-south` si disponible), notez le mot de passe de la base.

### Étape 2 — Exécuter le SQL

Dans **Supabase > SQL Editor > New query** :

1. Collez le contenu de **`supabase/install.sql`** et cliquez **Run**.
   Ce fichier regroupe, dans l'ordre, toutes les migrations et la structure de l'organisation (celle de votre organigramme : Direction Générale, Opérations, Technologie, Marketing, Business, Finance et leurs sous-unités).
2. *(Optionnel)* Pour voir des tableaux de bord remplis pendant vos essais, exécutez **`supabase/demo.sql`** (données fictives : revenus, dépenses, CRM, métriques). Un bloc de nettoyage est fourni en bas du fichier.

> **Vous aviez déjà exécuté une version précédente de `install.sql` ?** N'exécutez pas tout à nouveau : lancez seulement les migrations manquantes, dans l'ordre — depuis la version à 4 migrations : `20260926000005_drive.sql`, `20260926000006_messaging.sql` puis `20260927000007_collab_notifications.sql` ; depuis la version à 6 migrations : `20260927000007_collab_notifications.sql` puis `20260928000008_access_code.sql` ; depuis la version à 7 migrations : `20260928000008_access_code.sql`, `20260929000009_holding.sql` puis `20260930000010_operations_legal.sql`. Les deux dernières ajoutent les départements **Juridique** et **Ressources Humaines** s'ils manquent, posent les intitulés des officiers (CEO, COO, CTO, CFO, CBO, CMO) et recalculent les droits de chacun — vos unités et vos nominations existantes sont conservées. **Ces deux migrations sont rejouables** : si une exécution s'interrompt, relancez le fichier entier sans risque (tout y est conditionné par `if not exists`, et les reprises de données ne s'appliquent qu'au premier passage). Vos documents existants sont rangés automatiquement dans l'espace *Documents de l'entreprise* ou dans celui de leur département / projet.
>
> **Depuis la version à 10 migrations (phase 0 de l'audit)** : appliquez `20261012000011_p0_gouvernance.sql` à `20261012000015_p0_vues_interface.sql`, dans l'ordre. Le seuil des validations est repris de vos paramètres ; les budgets, contrats et factures existants restent dans leur état. Après application, chaque responsable sensible devra activer la double authentification à sa prochaine connexion.

> Vous préférez la CLI Supabase ? `supabase link --project-ref <ref>` puis `supabase db push` applique `supabase/migrations/` ; exécutez ensuite `supabase/seed.sql`.

Si le message `pg_cron non disponible` apparaît : activez **Database > Extensions > pg_cron**, puis relancez uniquement le bloc « Tâches planifiées » de `20260925000004_api.sql` et celui de purge de la corbeille à la fin de `20260926000005_drive.sql`.

Les buckets de stockage (`documents`, `doc-assets`, `chat`, `avatars`) et leurs politiques d'accès sont créés par le SQL : rien à configurer à la main dans *Storage*.

### Étape 3 — Configurer l'authentification

**Authentication > URL Configuration**
- *Site URL* : l'URL de l'application (ex. `https://os.veriion.com`, ou `http://localhost:3000` en local)
- *Redirect URLs* : ajoutez `https://os.veriion.com/**` et `http://localhost:3000/**`

**Authentication > Sign In / Providers > Email**
- Activez *Email*. Après avoir créé le compte du CEO (étape 4), **désactivez « Allow new users to sign up »** : les comptes ne seront plus créés que par invitation.

**Authentication > Multi-Factor** : laissez **TOTP activé** (réglage par défaut). La double authentification est imposée aux rôles sensibles (CEO, administration, finance, RH, juridique, délégataires) : la base exige le niveau `aal2` pour les écritures financières, les contrats, les décisions du CEO, les dérogations et la lecture des salaires d'autrui. Le **code d'accès personnel** reste un verrou de confort pour rouvrir son espace ; il ne remplace pas la double authentification.

**Authentication > Emails > Templates** — remplacez le lien des deux modèles suivants :

| Modèle | Lien à utiliser dans le modèle |
| --- | --- |
| **Invite user** | `{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=invite&next=/definir-mot-de-passe` |
| **Reset password** | `{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=recovery&next=/definir-mot-de-passe` |

Exemple de modèle d'invitation :

```html
<h2>Bienvenue chez VERIION</h2>
<p>Votre compte sur VERIION OS a été créé. Cliquez pour définir votre mot de passe :</p>
<p><a href="{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=invite&next=/definir-mot-de-passe">Activer mon compte</a></p>
```

**Authentication > SMTP** : en production, branchez le SMTP de `veriion.com` (Google Workspace, Microsoft 365, Brevo, Postmark…). Le SMTP intégré de Supabase est limité à quelques e-mails par heure.

### Étape 4 — Variables d'environnement

```bash
cp .env.example .env.local
```

| Variable | Où la trouver | Rôle |
| --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Project Settings > API | URL du projet |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Project Settings > API (anon / publishable) | Clé publique (protégée par RLS) |
| `SUPABASE_SERVICE_ROLE_KEY` | Project Settings > API (service_role / secret) | **Serveur uniquement** : invitations et suspension de comptes |
| `NEXT_PUBLIC_SITE_URL` | — | URL publique de l'application |
| `NEXT_PUBLIC_EMAIL_DOMAIN` | — | `veriion.com` : seul domaine accepté pour les invitations |
| `ACCESS_CODE_SECRET` | 32 caractères aléatoires (`openssl rand -hex 16`) | Signe le verrou du code d'accès. Facultative (la clé `service_role` sert de repli) ; la changer redemande le code à tout le monde |
| `NEXT_PUBLIC_MEET_BASE_URL` | — | Préfixe des salles de visioconférence (réunions et appels depuis la messagerie) : `https://meet.jit.si/veriion` ou votre propre serveur Jitsi |
| `NEXT_PUBLIC_TIMEZONE` | — | `Africa/Porto-Novo` : fuseau d'affichage |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM` | Votre messagerie (Google Workspace, Microsoft 365, Brevo…) | Envoi des e-mails de notification (voir § Notifications) |
| `NEXT_PUBLIC_VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` | `npm run vapid` (une seule fois) | Notifications push sur téléphone et ordinateur |
| `CRON_SECRET` | 32 caractères aléatoires (`openssl rand -hex 16`) | Protège les adresses d'envoi appelées par Supabase |

### Étape 5 — Lancer

```bash
npm install
npm run dev          # http://localhost:3000
```

### Étape 6 — Activer les notifications par e-mail et sur téléphone

1. **E-mail** : renseignez les variables `SMTP_*` (pour Google Workspace : `smtp.gmail.com`, port 587, un *mot de passe d'application* du compte `notifications@veriion.com`).
2. **Push** : lancez `npm run vapid`, copiez la clé publique dans `NEXT_PUBLIC_VAPID_PUBLIC_KEY` et la clé privée dans `VAPID_PRIVATE_KEY`, puis redéployez. Ne changez plus ces clés ensuite (les appareils déjà inscrits devraient se réinscrire).
3. **Planification** : dans Supabase, activez les extensions **pg_cron** et **pg_net**, puis exécutez **`supabase/notifications_schedule.sql`** après y avoir mis l'adresse de l'application et la valeur de `CRON_SECRET`.
4. Chaque employé choisit ses préférences dans **Paramètres › Notifications**, active les notifications sur son téléphone (bouton « Activer sur cet appareil ») et peut s'envoyer une notification et un e-mail de test.

> **iPhone** : les notifications push web fonctionnent depuis iOS 16.4, à condition d'avoir **ajouté VERIION OS à l'écran d'accueil** (Safari › Partager › « Sur l'écran d'accueil ») puis d'activer les notifications depuis l'application installée. Android, Windows et macOS fonctionnent directement dans le navigateur.

> Sans pg_cron, vous pouvez appeler les mêmes adresses depuis n'importe quel planificateur (Vercel Cron en plan Pro, cron-job.org…) avec l'en-tête `Authorization: Bearer <CRON_SECRET>` : `/api/notifications/dispatch` chaque minute, `/api/notifications/reminders?type=daily` chaque matin et `/api/notifications/reminders?type=meetings` toutes les 5 minutes.

---

## 4. Premier démarrage : devenir CEO

Le **premier compte créé devient automatiquement CEO** (accès global).

1. Tant que les inscriptions sont ouvertes, créez votre compte depuis **Authentication > Users > Add user** (cochez *Auto Confirm User*) avec votre adresse `prenom.nom@veriion.com`.
2. Connectez-vous sur `/connexion` : l'application vous demande de **créer votre code d'accès personnel** (6 à 32 caractères, redemandé à chaque nouvelle session sans jamais vous déconnecter), puis de **compléter votre profil** (prénom, nom, téléphone, localisation). Ces deux étapes valent pour chaque collaborateur.
3. **Désactivez les inscriptions publiques** (étape 3).
4. Dans **Organisation**, nommez-vous responsable de **VERIION** : l'intitulé « CEO — Directeur Général » vous est attribué automatiquement (les intitulés se règlent sur chaque unité, plus dans la fiche des personnes).
5. Dans **Administration > Comptes**, invitez vos officiers (COO, CTO, CFO, CBO, CMO, Juridique, RH) en choisissant leur département et le rôle **Responsable** : intitulé et droits suivent automatiquement.
6. Créez votre premier **projet** dans *Projets*, désignez son **Chief Product**, puis, dans *Organisation > Projets & référents*, désignez le référent de chaque département pour ce projet.
7. Demandez le **lancement du projet** depuis sa fiche : il passe actif dès votre accord dans *Validations*.

---

## 5. Modèle de droits

### Rôles système
| Rôle | Portée |
| --- | --- |
| **CEO** | Accès global à tout |
| **Administrateur** | Comptes, organisation, dérogations, journal — **pas** d'accès à la finance ni aux salaires |
| **Employé** | Tout le reste dépend de ses affectations |

### Règles automatiques (modifiables par le CEO dans *Administration > Règles automatiques*)

| Domaine de l'unité | Rôle | Permission obtenue |
| --- | --- | --- |
| Toutes | Responsable | Administrer son unité et ses sous-unités, publier des annonces |
| Toutes | Adjoint | Attribuer des tâches dans l'unité |
| Direction | Responsable | Dashboard de direction, objectifs entreprise |
| Finance | Membre | Consulter la finance |
| Finance | Adjoint / Responsable | Administrer la finance (+ dashboard pour le CFO) |
| Business | Membre | Consulter et modifier le CRM |
| Business | Responsable | Administrer le CRM |
| Marketing | Responsable | Consulter le CRM |
| RH | Membre / Adjoint / Responsable | Consulter / administrer les RH (+ dashboard pour le CHRO) |
| Opérations | Responsable / Adjoint | Écrire et publier les calendriers opérationnels (`ops.plan`), accès à tous les projets |
| Opérations | Membre | Suivre les rapports des chefs de projet (`ops.review`) |
| Juridique | Membre | Consulter le registre des contrats (`legal.view`) |
| Juridique | Adjoint / Responsable | Administrer le registre, soumettre les contrats à signature (`legal.admin`) |
| Technologie | Responsable | Métriques produit et incidents |

**Permissions réservées** : `approvals.decide`, `finance.admin`, `finance.view`, `hr.admin`, `docs.confidential`, `grants.manage` et `dashboard.exec` ne s'accordent par dérogation **que par le CEO**. Toute dérogation a une **échéance** (90 jours au plus par défaut, réglable dans *Paramètres › Gouvernance*). Un administrateur ne peut ni modifier le seuil des validations, ni suspendre, rétrograder ou faire partir un CEO.

**Décisions réservées au CEO** (`approvals.decide`, délégable par dérogation du CEO) : budgets et dépenses au-delà du seuil défini dans *Paramètres*, contrats juridiques, calendriers mensuels, lancement de projet et contrats de travail. Ce ne sont pas de simples écrans : la base **refuse** l'écriture tant que l'accord n'est pas enregistré.

**Répartition des tâches** : `can_assign_task` autorise l'auto-assignation, le chef de projet vers les membres de son équipe, et un responsable vers les personnes qu'il encadre — rien d'autre. Une tâche confiée exige une vérification, et seul celui qui l'a confiée peut la clôturer.

- Les droits **globaux** de responsable ne sont accordés qu'au niveau **département** ; un responsable de sous-unité administre son périmètre sans hériter des droits globaux du département.
- Une nomination clôture l'affectation précédente (date de fin) : **l'historique n'est jamais effacé**.
- Toute modification d'une règle recalcule immédiatement les droits de tous.
- Les **dérogations** (ex. intérim) sont nominatives, motivées, datées et journalisées.

### Documents : qui voit et modifie quoi

| Espace | Lecture | Modification (créer, éditer, déposer, ranger) | Gestion (partager, supprimer définitivement) |
| --- | --- | --- | --- |
| **Mon espace** | le propriétaire seul — **même le CEO n'y a pas accès** | le propriétaire | le propriétaire |
| **Département / équipe** | membres de l'unité et de ses sous-unités | membres | responsables (`unit.manage`) |
| **Projet** | membres du projet (`view`) | contributeurs | chef de projet (`manage`) |
| **Entreprise** | tous les collaborateurs | administrateurs de l'organisation | administrateurs de l'organisation |

- Les **partages** (à une personne ou à toute une unité, avec date d'expiration facultative) s'ajoutent à ces droits et s'héritent dans les sous-dossiers.
- Déplacer un élément vers un **autre espace** exige le niveau *Gestion* : un contributeur ne peut pas sortir un document de son département.
- Niveau de **confidentialité** d'un document : *Interne* (tous ceux qui ont accès au dossier), *Restreint* (éditeurs et gestionnaires du dossier uniquement), *Confidentiel* (gestionnaires, auteur, personnes invitées et détenteurs de `docs.confidential`).
- Chaque enregistrement conserve une **version** (au plus une toutes les 10 minutes, plus les versions nommées manuellement).
- **Co-édition** : les modifications simultanées sont fusionnées en direct ; un seul poste (le plus ancien éditeur connecté) enregistre en base, et le suivant prend le relais s'il ferme le document. Restaurer une version recharge le document chez tout le monde. Les lecteurs voient les modifications en direct sans pouvoir modifier.

---

## 6. Déploiement en production

**Vercel (recommandé)**
1. Poussez le dépôt sur GitHub (privé).
2. Importez-le sur <https://vercel.com/new>, framework *Next.js* détecté.
3. Ajoutez les variables d'environnement (étape 4) — `SUPABASE_SERVICE_ROLE_KEY` **sans** préfixe `NEXT_PUBLIC_`.
4. Domaine : `os.veriion.com` (CNAME vers Vercel), puis mettez à jour *Site URL* dans Supabase.

**Autre hébergement** : `npm run build && npm start` derrière un reverse proxy HTTPS (Node 20+).

### Check-list sécurité avant ouverture
- [ ] Inscriptions publiques désactivées
- [ ] `ACCESS_CODE_SECRET` défini (32 caractères aléatoires) et conservé tel quel
- [ ] SMTP professionnel configuré, modèles d'e-mail en français
- [ ] Sauvegardes quotidiennes activées (plan Pro : Point-in-Time Recovery)
- [ ] Clé `service_role` uniquement côté serveur
- [ ] `CRON_SECRET` long et aléatoire, identique dans l'application et dans `private.settings`
- [ ] Revue trimestrielle des droits (*Administration > Droits & dérogations*)

---

## 7. Tests

Le schéma SQL est livré avec des scénarios de test exécutables sur n'importe quel PostgreSQL 15+ local (un émulateur minimal d'Auth/Storage est fourni) :

```bash
PGURL=postgresql://postgres@localhost:5432/postgres ./supabase/tests/run.sh
```

Ils vérifient notamment : droits automatiques à la nomination, cloisonnement finance, impossibilité d'escalader son rôle, transfert de responsabilité avec historique, validation et dépendances des tâches, opportunité gagnée → projet + facture, facture payée → revenu, départ d'un employé, le bon fonctionnement de toutes les écritures sous RLS, et pour le Drive et la messagerie : espaces et droits par rôle, espace personnel inaccessible au CEO, lecteur/contributeur, conflit de révision, partage + notification, corbeille et restauration, blocage des déplacements hors périmètre, mentions, fils, épingles, réactions, conversations directes et recherche ; et pour la co-édition et les notifications : enregistrement et invalidation de l'état de co-édition, protection en écriture, préférences et appareils privés, files d'envoi réservées au serveur et sans doublon, résumé une fois par jour, rappels d'échéance, de retard et de réunion ; pour le code d'accès : codes trop faibles refusés, hachage illisible même par son propriétaire, blocage après 5 échecs (y compris par la porte du changement de code), réinitialisation réservée aux administrateurs et journalisée sans le hachage, code effacé au départ d'un collaborateur ; et pour la holding : intitulé attribué à la nomination, droits automatiques des domaines Opérations et Juridique, référent ajouté au canal du projet, lancement de projet et calendrier mensuel bloqués sans l'accord du CEO (refus non motivé rejeté), dépense au-dessus du seuil refusée sans accord, contrat non signable sans accord, assignation hors périmètre refusée, tâche non clôturable par son titulaire puis renvoyée et validée par son vérificateur, rapport de cycle et accusé de réception, fusion d'unités (sous-unités déplacées, unité absorbée archivée, fusion circulaire refusée).

```bash
npm run typecheck    # TypeScript strict
npm run lint         # ESLint
npm test             # tests unitaires (Vitest)
npm run test:sql     # scénarios SQL (PGURL=…)
npm run build
npm run build:install  # régénère supabase/install.sql après une migration
npm run schema:dump    # régénère supabase/schema/schema.sql (état courant du schéma)
```

La CI GitHub (`.github/workflows/ci.yml`) exécute tout cela à chaque pull request. Le scénario `70_gouvernance.sql` rejoue les contournements relevés par l'audit d'octobre 2026 et vérifie qu'ils sont tous refusés ; `80_finance_circuits.sql` couvre l'intégrité financière et les circuits budget / contrats. Exploitation (environnements, sauvegardes, supervision, secrets) : [`docs/EXPLOITATION.md`](docs/EXPLOITATION.md).

---

## 8. Arborescence

```
supabase/
  install.sql                    ← tout-en-un à coller dans le SQL Editor
  migrations/
    …0001_foundation.sql         identité, organisation, permissions, audit
    …0002_modules.sql            communication, projets, CRM, finance, RH, documents, OKR, réunions
    …0003_security.sql           RLS de toutes les tables
    …0004_api.sql                RPC (dashboard, recherche, messagerie), stockage, temps réel, cron
    …0005_drive.sql              dossiers, espaces, partages, contenus éditables, versions, corbeille, favoris
    …0006_messaging.sql          fils, mentions, réactions, épingles, appels, pièces jointes, recherche
    …0007_collab_notifications.sql  co-édition, préférences, push, e-mails, rappels
    …0008_access_code.sql        code d'accès personnel (verrou de session)
    …0009_holding.sql            départements de la holding, projets, référents, intitulés, fusion, profil obligatoire
    …0010_operations_legal.sql   calendrier opérationnel, rapports, juridique, validations du CEO, tâches vérifiées
    …0011_p0_gouvernance.sql     gouvernance fiable : seuil réservé au CEO, accords figés et consommés, double authentification
    …0012_p0_durcissement.sql    privilèges explicites, inscriptions limitées au domaine
    …0013_p0_integrite_financiere.sql  factures figées, numérotation continue, contre-passations
    …0014_p0_circuits.sql        budgets, contrats de travail, machine à états des contrats juridiques
    …0015_p0_vues_interface.sql  accords caducs, accords disponibles, supervision
  schema/schema.sql              état courant du schéma (référence lisible, généré)
  notifications_schedule.sql     activation de l'envoi planifié (pg_cron + pg_net)
  seed.sql                       organigramme VERIION + référentiel KPI
  demo.sql                       données de démonstration (optionnel)
  tests/                         scénarios de test SQL
src/
  middleware.ts                  session & protection des routes
  app/
    (auth)/                      connexion, mot de passe, code d'accès, complétion du profil
    (app)/                       application (layout avec navigation)
      page.tsx                   accueil
      direction/  organisation/  annuaire/  messages/  reunions/
      projets/    operations/    taches/    objectifs/ documents/
      crm/        finance/       juridique/ validations/
      rh/         admin/         parametres/
    auth/                        callbacks e-mail
      documents/d/[id]/          ouverture d'un document dans son éditeur
    api/storage/                 lecture sécurisée des fichiers privés
    api/notifications/           envoi des e-mails et push, rappels (appelés par Supabase)
    manifest.ts                  application installable (PWA)
public/sw.js                     service worker : réception des notifications push
  components/
    ui/  shell/                  design system et navigation
    drive/                       explorateur : icônes, dialogues (nom, déplacement, partage), envoi de fichiers
    editors/                     éditeurs texte, tableur, présentation, visionneuse, historique
    chat/                        zone de saisie (mentions, pièces jointes) et affichage des messages
  lib/collab/                    co-édition : fournisseur Yjs sur Supabase Realtime, opérations tableur/présentation
  lib/server/                    envoi des e-mails (SMTP), des push (VAPID) et répartition des notifications
  lib/                           clients Supabase, contexte & permissions, moteur de formules,
                                 conversions Office, utilitaires Drive et messagerie
```

---

## 9. Exploitation & évolutions

- **Métriques produit** : la table `product_metrics` peut être alimentée automatiquement par vos plateformes (Oniix, iSkul, Wiix, Eduoo) via l'API REST Supabase avec une clé serveur, ou saisie depuis le dashboard.
- **Nouvelle permission** : ajoutez-la dans `public.permissions`, utilisez `has_perm('…')` dans les politiques RLS et `can(ctx, '…')` dans l'interface.
- **Nouveau domaine d'unité** (ex. Juridique) : `alter type public.unit_domain add value 'legal';` puis ajoutez les règles correspondantes.
- **Audit** : chaque création, modification et suppression sur les tables sensibles est tracée (acteur, date, avant/après ; contenu masqué pour les salaires).

---

© VERIION — Tous droits réservés. Document et code à usage interne.
