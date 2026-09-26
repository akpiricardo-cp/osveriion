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
| **Identité & sécurité** | Connexion unique `prenom.nom@veriion.com`, double authentification TOTP obligatoire (configurable), mot de passe oublié, invitation par e-mail, sessions (déconnexion des autres appareils), suspension et départ d'un collaborateur |
| **Organisation** | Organigramme interactif Entreprise → Département → Sous-département → Équipe, nomination datée des responsables et adjoints **avec historique**, page dédiée par unité (effectif, budget, objectifs, projets, canal, réunions) |
| **Droits automatiques** | Nommer quelqu'un responsable modifie **automatiquement** ses droits (règles configurables), dérogations manuelles temporaires et motivées |
| **Communication** | Messagerie temps réel : conversations directes, canaux de groupe (publics/privés), canal par département et par projet, **fils de discussion**, **mentions @** avec autocomplétion et notification, **pièces jointes** (glisser-déposer, coller une capture, aperçu des images), **réactions**, **messages épinglés**, **recherche**, **appel vidéo en un clic** depuis la conversation, indicateur « est en train d'écrire », modification/suppression, non-lus, annonces de la direction |
| **Projets & tâches** | Kanban glisser-déposer (souris et tactile), vue liste, sous-tâches, dépendances bloquantes, **circuit de validation**, commentaires, notifications, collaboration temps réel, « Mes tâches » par échéance |
| **CRM & partenariats** | Prospects/clients/partenaires, contacts, pipeline glisser-déposer, historique des interactions. **Une opportunité gagnée crée automatiquement le projet de livraison et la facture brouillon** |
| **Finance** | Revenus, dépenses, trésorerie, factures (lignes, TVA, impression PDF), budgets par unité avec consommation, analyses par produit/pays/catégorie. **Une facture encaissée génère le revenu comptable** |
| **RH** | Congés (solde, demande, validation par le responsable, notifications), contrats, salaires confidentiels, masse salariale, parcours d'intégration et de départ |
| **Documents (Drive)** | **Dossiers et sous-dossiers illimités** dans 4 types d'espaces : *Mon espace* (privé), *Département/équipe*, *Projet*, *Entreprise*. Droits selon les rôles + partage à une personne ou une unité (Lecteur / Éditeur / Gestionnaire, avec expiration), « Partagés avec moi », Récents, Favoris, corbeille (30 jours), déplacement par glisser-déposer, 3 niveaux de confidentialité, recherche plein texte **dans le contenu** |
| **Éditeurs intégrés** | **Documents texte** (type Word : titres, listes, tableaux, images, couleurs, liens, cases à cocher), **tableurs** (type Excel : formules en français ou en anglais `SOMME`, `SI`, `RECHERCHEV`, `NB.SI`…, plusieurs feuilles, formats monétaire FCFA / % / date, somme automatique), **présentations** (type PowerPoint : dispositions, thèmes, images, notes de l'orateur, mode présentation plein écran). **Co-édition en temps réel** : plusieurs personnes écrivent dans le même document au même moment, avec le curseur et le nom de chacun (fusion Yjs pour le texte, cellule par cellule pour le tableur, diapositive par diapositive pour les présentations — on voit qui est sur quelle cellule ou quelle diapositive). Enregistrement automatique, **historique des versions avec restauration**. Import Word/Excel/CSV, export **.docx / .xlsx / .pptx / CSV / PDF**. Visionneuse PDF, images, vidéo, audio pour les fichiers déposés |
| **Objectifs & KPI** | OKR entreprise → département → individuel, résultats clés mesurables, progression calculée, référentiel unique des indicateurs |
| **Notifications** | Dans l'application (cloche + alerte en direct), **sur téléphone et ordinateur** (notifications push, application installable sur l'écran d'accueil), **par e-mail** (regroupé quelques minutes après une notification non lue, ou **résumé quotidien** à l'heure choisie). Préférences par personne et par type (messages, tâches, validations, réunions, documents, RH, annonces), plage « ne pas déranger ». **Rappels automatiques** : échéances du jour, tâches en retard, validations et congés en attente (chaque matin), réunion qui commence dans 15 minutes |
| **Réunions** | Planification, invitations, réponses, salle de visioconférence (Jitsi), comptes rendus |
| **Dashboard de direction** | Utilisateurs actifs, revenus, dépenses, trésorerie, pipeline, projets, tâches en retard, performance par département, incidents, objectifs |
| **Administration** | Comptes, droits effectifs, règles automatiques, **journal d'activité immuable**, paramètres de l'entreprise |

Recherche globale `Ctrl/⌘ + K`, thème clair/sombre, interface responsive (mobile, tablette, desktop), 100 % en français.

---

## 2. Architecture

```
Navigateur (Next.js — React 19)
        │  HTTPS, session en cookies httpOnly (@supabase/ssr)
        ▼
Next.js 15 (App Router) ── Server Components (lecture) ── Server Actions (écriture)
        │                         middleware : rafraîchit la session, protège les routes
        ▼
Supabase
 ├── Auth ............ identités, MFA TOTP, invitations
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
   Ce fichier regroupe, dans l'ordre, les 7 migrations et la structure de l'organisation (celle de votre organigramme : Direction Générale, Opérations, Technologie, Marketing, Business, Finance et leurs sous-unités).
2. *(Optionnel)* Pour voir des tableaux de bord remplis pendant vos essais, exécutez **`supabase/demo.sql`** (données fictives : revenus, dépenses, CRM, métriques). Un bloc de nettoyage est fourni en bas du fichier.

> **Vous aviez déjà exécuté une version précédente de `install.sql` ?** N'exécutez pas tout à nouveau : lancez seulement les migrations manquantes, dans l'ordre — depuis la version à 4 migrations : `20260926000005_drive.sql`, `20260926000006_messaging.sql` puis `20260927000007_collab_notifications.sql` ; depuis la version à 6 migrations : uniquement `20260927000007_collab_notifications.sql`. Vos documents existants sont rangés automatiquement dans l'espace *Documents de l'entreprise* ou dans celui de leur département / projet.

> Vous préférez la CLI Supabase ? `supabase link --project-ref <ref>` puis `supabase db push` applique `supabase/migrations/` ; exécutez ensuite `supabase/seed.sql`.

Si le message `pg_cron non disponible` apparaît : activez **Database > Extensions > pg_cron**, puis relancez uniquement le bloc « Tâches planifiées » de `20260925000004_api.sql` et celui de purge de la corbeille à la fin de `20260926000005_drive.sql`.

Les buckets de stockage (`documents`, `doc-assets`, `chat`, `avatars`) et leurs politiques d'accès sont créés par le SQL : rien à configurer à la main dans *Storage*.

### Étape 3 — Configurer l'authentification

**Authentication > URL Configuration**
- *Site URL* : l'URL de l'application (ex. `https://os.veriion.com`, ou `http://localhost:3000` en local)
- *Redirect URLs* : ajoutez `https://os.veriion.com/**` et `http://localhost:3000/**`

**Authentication > Sign In / Providers > Email**
- Activez *Email*. Après avoir créé le compte du CEO (étape 4), **désactivez « Allow new users to sign up »** : les comptes ne seront plus créés que par invitation.

**Authentication > Multi-Factor** : laissez *TOTP* activé.

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
| `REQUIRE_MFA` | — | `true` : chaque employé doit activer la double authentification |
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
2. Connectez-vous sur `/connexion`, activez la double authentification.
3. **Désactivez les inscriptions publiques** (étape 3).
4. Dans **Organisation**, ouvrez *Direction Générale* → *Nommer le responsable* → vous-même, intitulé « CEO ».
5. Dans **Administration > Comptes**, invitez vos directeurs en choisissant leur département et le rôle **Responsable** : leurs droits sont attribués automatiquement.

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
| RH | Membre / Adjoint | Consulter / administrer les RH |
| Opérations | Responsable | Accès à tous les projets |
| Technologie | Responsable | Métriques produit et incidents |

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
- [ ] `REQUIRE_MFA=true`
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

Ils vérifient notamment : droits automatiques à la nomination, cloisonnement finance, impossibilité d'escalader son rôle, transfert de responsabilité avec historique, validation et dépendances des tâches, opportunité gagnée → projet + facture, facture payée → revenu, départ d'un employé, le bon fonctionnement de toutes les écritures sous RLS, et pour le Drive et la messagerie : espaces et droits par rôle, espace personnel inaccessible au CEO, lecteur/contributeur, conflit de révision, partage + notification, corbeille et restauration, blocage des déplacements hors périmètre, mentions, fils, épingles, réactions, conversations directes et recherche ; et pour la co-édition et les notifications : enregistrement et invalidation de l'état de co-édition, protection en écriture, préférences et appareils privés, files d'envoi réservées au serveur et sans doublon, résumé une fois par jour, rappels d'échéance, de retard et de réunion.

```bash
npm run typecheck    # TypeScript strict
npm run lint
npm run build
```

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
  notifications_schedule.sql     activation de l'envoi planifié (pg_cron + pg_net)
  seed.sql                       organigramme VERIION + référentiel KPI
  demo.sql                       données de démonstration (optionnel)
  tests/                         scénarios de test SQL
src/
  middleware.ts                  session & protection des routes
  app/
    (auth)/                      connexion, mot de passe, double authentification
    (app)/                       application (layout avec navigation)
      page.tsx                   accueil
      direction/  organisation/  annuaire/  messages/  reunions/
      projets/    taches/        objectifs/ documents/
      crm/        finance/       rh/        admin/     parametres/
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
