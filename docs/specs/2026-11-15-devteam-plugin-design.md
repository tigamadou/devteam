# Plugin `devteam` : des missions de développement parallèles, installable dans n'importe quel projet

> Statut : **soumis à validation** (2026-11-15).

## 1. Intention

`devteam` organise une **mission** de développement non triviale à partir d'une spec validée : découpage en graphe de
**lots** à fichiers exclusifs, plans rédigés en parallèle par des agents, puis une tâche planifiée qui orchestre
l'exécution (un environnement par lot, revues, fusions, PR finale). La méthode exige que le projet remplisse un
**contrat** de neuf points (Docker uniquement, environnement d'agent, isolation des données, cibles standard,
branches, CI à check unique, budget machine, fichiers générés et migrations, tâches planifiées).

On veut :

1. un kit **versionné**, installable dans **n'importe quel projet, sur n'importe quelle machine** ;
2. qu'à son initialisation dans un projet, il **diagnostique** le contrat, **interroge** le développeur sur ce qu'il ne
   peut pas déduire, puis **met le projet en conformité** : directement pour ce qui se déduit des commandes existantes,
   par une spec et un plan pour ce qui demande de l'ingénierie.

## 2. Objectifs, non-objectifs, anti-objectifs

**Objectifs**
- Plugin Claude Code `devteam`, dans le dépôt GitHub **public** `tigamadou/devteam` qui sert aussi de marketplace.
- Trois skills : `/devteam:demarrer` (lancer une mission), `/devteam:conformite` (diagnostic, questionnaire, mise en
  conformité), `/devteam:mise-a-jour` (synchroniser les fichiers copiés dans le projet avec la version du plugin).
- Sept agents `devteam:<role>`.
- Un **moteur commun d'environnement d'agent** (worktree, projet Compose, verrou, budget, code « pas de place »,
  statut), que chaque projet complète par ses adaptateurs de ressources.

**Non-objectifs**
- Installer le plugin dans un projet existant ou le mettre en conformité : ce travail ne livre que le plugin.
- Imposer le moteur commun à un projet qui a déjà son propre environnement d'agent conforme.
- Supporter une autre forge que GitHub (le contrat exige `gh`) ou une autre CI que GitHub Actions.
- Faire la promotion du plugin ou le publier dans une marketplace tierce : le dépôt est public, mais destiné d'abord à
  son auteur.

**Anti-objectifs** (échec même si « ça marche »)
- Le skill modifie un fichier du projet **sans accord explicite** sur ce fichier.
- Le skill **invente** une commande (test, lint, migration…) au lieu de la trouver dans le projet ou de la demander.
- Le skill déclare un point du contrat rempli alors que sa vérification échoue.
- Un projet conforme dépend de la machine du développeur : un `Makefile` ou une CI qui pointe vers le cache du plugin.
- Une mission en cours est cassée par une mise à jour du plugin.
- Le dépôt public expose un détail interne d'un projet de l'auteur : nom de projet ou de client, domaine, chemin
  absolu, adresse, secret, valeur mesurée ou nom de service propre à un projet. Les exemples (modèles par stack,
  adaptateurs, tests) sont génériques (`monprojet`, `api`, `web`).

## 3. Contraintes

- Toute écriture hors du dépôt `devteam` (configuration Claude Code de l'utilisateur, autre dépôt) et toute
  publication sur GitHub (push, release) **demandent l'accord explicite de l'utilisateur avant**.
- Aucun commit sans demande explicite ; jamais de mention d'IA, de trailer ni de co-auteur dans les commits.
- **Source** : le kit est construit à partir d'un kit existant fourni localement par l'utilisateur (skill, contrat,
  gabarits, sept agents, deux scripts, un fichier `make`, 34 tests bats), repris et adapté aux noms de ce document,
  pas réécrit. Deux environnements d'agent écrits à la main dans d'autres projets servent de références de lecture
  pour le moteur commun ; rien de propre à ces projets n'entre dans le dépôt.
- Contenu du kit en français avec accents ; identifiants, noms de fichiers, branches et labels en ASCII.
- Scripts : bash compatible 3.2 (macOS), testés en conteneur (bats).
- Mécanique des plugins (documentation Claude Code, vérifiée le 2026-11-15) :
  - éléments préfixés par le nom du plugin : skills `/devteam:<skill>`, agents `devteam:<agent>` ;
  - `${CLAUDE_SKILL_DIR}` et `${CLAUDE_PLUGIN_ROOT}` sont substitués dans le Markdown des skills et des agents, **pas**
    dans l'environnement du Bash ; le dossier d'installation change à chaque version ;
  - un projet peut déclarer marketplace et plugin dans son `.claude/settings.json` commité (`extraKnownMarketplaces`,
    `enabledPlugins`), mais chaque clone lance une fois `claude plugin install devteam@devteam --scope project` ;
  - dépôt public : aucune authentification pour installer ni pour la mise à jour automatique (à activer par
    marketplace, désactivée par défaut) ;
  - `version` explicite dans `plugin.json` : les autres machines ne reçoivent une version qu'à son changement ;
  - développement : marketplace locale pointant vers le dépôt, chargée sur place, `/reload-plugins` après modification.

## 4. Approches envisagées

**Portée de l'adaptation**
- A. Tout générer, y compris l'environnement d'agent et l'isolation, à partir de modèles par stack : les modèles collent
  mal (les environnements d'agent existants diffèrent déjà : bases, cache, plafond par budget mémoire ou par nombre
  fixe, ports ; certains projets sont répartis sur plusieurs dépôts), et le résultat serait du code d'infrastructure
  non relu.
- **B. Générer le simple, planifier le lourd (retenu).** Génération directe, validée fichier par fichier, de ce qui se
  déduit des commandes existantes ; spec et plan de mise en conformité pour l'environnement d'agent, l'isolation et le
  budget, allégés par un moteur commun fourni par le kit.
- C. Audit seul : n'aide pas à remplir le contrat, ce qui est le besoin.

**Distribution**
- Copie manuelle dans `~/.claude/` : ni version ni portabilité.
- Dépôt git et liens symboliques dans `~/.claude/` : versionné, mais à recréer à la main sur chaque machine.
- **Plugin dans un dépôt servant de marketplace (retenu)** : installable sur toute machine, versionné, déclarable
  par projet. Inconvénient accepté : préfixes `devteam:` dans les noms. Dépôt **public** (validé) : installation sans
  identifiants ; en contrepartie, rien d'interne aux projets de l'auteur n'y entre (voir anti-objectifs).

**Scripts exécutés par le projet**
- **Copiés dans le projet avec une version (retenu)** : le projet reste autonome (CI, autre machine, historique).
- Appelés depuis le plugin : impossible proprement (chemin d'installation variable) et contraire aux anti-objectifs.

**Nom** : `devteam` partout (plus court comme préfixe que `dev-agents-team`, qui se confondait en outre avec la
fonction « Agent Teams » de Claude Code).

## 5. Ce qui a été décidé

### 5.1 Dépôt `tigamadou/devteam` (public, branche `main`)

```
.claude-plugin/marketplace.json          marketplace « devteam », une entrée : ./plugins/devteam
plugins/devteam/
  .claude-plugin/plugin.json             name: devteam, version: 1.0.0
  skills/
    demarrer/    SKILL.md, plan-template.md, superviseur-template.md
    conformite/  SKILL.md, questionnaire.md, modeles/ (voir 5.4)
    mise-a-jour/ SKILL.md
    commun/      contrat.md (lu par les trois skills)
  agents/        developpeur.md lead-dev.md lead-qa.md planificateur.md relecteur.md surveillant.md testeur.md
  kit/           fichiers copiés dans les projets (voir 5.5)
docs/            specs et plans (notes de version : plugins/devteam/CHANGELOG.md)
tests/projets/   projets de démonstration génériques (voir 6)
Makefile         test (bats en conteneur), validate (claude plugin validate), dev (marketplace locale)
```

### 5.2 Noms

| Élément | Nom |
| --- | --- |
| Skills | `/devteam:demarrer`, `/devteam:conformite`, `/devteam:mise-a-jour` |
| Agents | `devteam:surveillant`, `devteam:lead-dev`, `devteam:lead-qa`, `devteam:planificateur`, `devteam:developpeur`, `devteam:testeur`, `devteam:relecteur` |
| Fichier projet | `.claude/devteam.projet.md` (une section par clé du contrat) |
| Fichiers copiés | `make/devteam.mk`, `scripts/devteam/` |
| Cibles du kit | `devteam-labels SLUG= [LOTS=]`, `devteam-perimetre LOT= PLAN= BASE=`, `devteam-test` |
| Label de mission | `devteam:<slug>` ; labels fixes `lot:<id>`, `role:`, `type:`, `etat:`, `revue:` |
| Tâche planifiée | `devteam-<slug>` |
| Dossier d'état | `.superpowers/sdd/<slug>/` (convention superpowers) |

Vocabulaire : **mission** (l'ensemble du travail, une spec, une PR finale), **lot** (une chaîne de tâches dépendantes
à fichiers exclusifs), **superviseur** (la tâche planifiée).

### 5.3 Le contrat

Les neuf points et leurs vérifications sont ceux du kit source. Le contrat est le seul fichier lu par les trois
skills : `demarrer` refuse s'il manque un point et renvoie vers `/devteam:conformite`.

### 5.4 `/devteam:conformite`

Déroulé, dans l'ordre :

1. **Diagnostic sans écriture** : vérification des neuf points, lecture du projet (`Makefile`, Compose, workflows,
   branches, gestionnaires de paquets, outils de test et de migration). Sortie : un tableau point / état
   (rempli, partiel, absent) / ce qui manque / traitement (direct ou mission de mise en conformité).
2. **Questionnaire** ([`questionnaire.md`](#annexe-a--questionnaire)) : par blocs, dans l'ordre, une question
   seulement si le projet n'y répond pas ; ce qui se déduit est proposé pour correction. Une réponse **bloquante** du
   bloc 0 (par exemple « passer en monorepo ») arrête le questionnaire et ouvre directement l'étape 4. Les réponses
   sont écrites dans `.claude/devteam.projet.md` (ou dans la spec de l'étape 4 pour ce qui reste à construire) pour
   ne jamais être reposées.
3. **Génération directe**, un fichier à la fois, contenu ou diff montré, écriture seulement après accord :
   - `make/standard.mk` : les cibles du point 4, chacune renvoyant à une commande **trouvée dans le projet ou donnée
     par le développeur** ; une cible sans objet sort en 0 avec un message et est déclarée sans objet (avec la raison)
     dans le fichier projet. `modeles/` contient des exemples commentés par stack (Django/pytest, Laravel/PHPUnit,
     Node/Vitest-Playwright, Prisma), servant de référence, jamais copiés tels quels.
   - workflow GitHub Actions `.github/workflows/devteam-ci.yml` (ou intégration au workflow existant, au choix du
     développeur) : jobs appelant les cibles `make`, et job agrégateur `ci-ok` (`if: always()`, `needs: [...]`,
     tous `success` ou `skipped`). La protection de branche est proposée via `gh`, exécutée seulement avec accord.
   - `.claude/devteam.projet.md` rempli, sans aucune valeur chiffrée de budget (elles vivent dans le document des
     profils).
   - `.claude/settings.json` : déclaration de la marketplace et du plugin, pour les autres clones.
   - copie du kit (5.5).
4. **Mission de mise en conformité** pour les points qui ne se génèrent pas (typiquement 2, 3 et 7, et tout préalable
   structurel) : le skill rédige une spec (ce que le projet doit isoler, comment, quels profils, où le garde-fou) et un
   plan au format de `plan-template.md`, dans les emplacements du projet. Il ne l'exécute pas lui-même : il indique la
   méthode (exécution séquentielle, le contrat n'étant pas rempli) et s'arrête.
5. **Re-diagnostic** : nouveau tableau ; le skill dit ce qui reste et par quel plan.

Le skill est relançable : chaque passage repart du diagnostic et ne repose aucune question déjà répondue.

### 5.5 Fichiers copiés dans le projet (`kit/`)

- `make/devteam.mk`, `scripts/devteam/check-perimetre.sh`, `scripts/devteam/labels.sh`, leurs tests bats ;
- le **moteur d'environnement d'agent** (5.6), **seulement pour un projet qui l'adopte** : copié par la mission de
  mise en conformité, avec ses tests, dans `scripts/devteam/agent-env/` et un fichier `make/devteam-agent.mk`
  (cibles `agent-up`, `agent-down`, `agent-status`) inclus seulement si `devteam.agent.conf` existe.
  `make/devteam.mk` ne définit jamais ces cibles : un projet qui a son propre environnement conforme les garde, et
  `mise-a-jour` ne lui copie pas le moteur ;
- `scripts/devteam/VERSION` : version du kit copiée.

Chaque fichier copié porte un en-tête `devteam <version> : fichier du kit, ne pas modifier ici`. Le `Makefile` du
projet les inclut (`-include make/devteam.mk`, `-include make/standard.mk`).

### 5.6 Moteur commun d'environnement d'agent

Extrait des deux environnements d'agent de référence (l'un plafonné par un budget mémoire mesuré, l'autre par un
nombre fixe d'environnements et une plage de ports) :

- **Commun (dans le kit)** : sous-commandes `up <lot> <profil> <base>`, `down <lot>`, `status`, `budget` ; validation
  du lot et du profil ; worktree `../<projet>-wt-<lot>` sur `<base>-<lot>` ; projet Compose `<projet>-ag-<lot>` ;
  écriture de `.agent.env` dans le worktree ; verrou ; calcul du budget (mémoire Docker − stack principale − marge,
  somme des profils actifs) ; codes de sortie 0 / 1 erreur / 2 usage / **75 pas de place** ; messages de reprise après
  échec ; `status` avec mémoire mesurée.
- **Propre au projet** : un fichier de valeurs `devteam.agent.conf` (nom du projet, profils et leur coût mesuré,
  mémoire de la stack principale, marge, réseau d'infrastructure, liste des ressources). Pour un projet qui adopte le
  moteur, ce fichier **est** le document des profils cité par la clé `budget` (commentaires autorisés pour la méthode
  de mesure) ; la vérification du point 7 accepte un document Markdown ou ce fichier. Les chiffres n'existent donc
  qu'à un endroit. Et un **adaptateur par type de ressource** dans `scripts/devteam-adaptateurs/` (`variables`,
  `creer`, `liberer` à `down`). Le kit fournit des adaptateurs d'exemple (base Postgres, base
  MySQL, numéro Redis, bucket S3, port dans une plage) que la mission de mise en conformité copie et ajuste.
- Un plafond fixe d'environnements simultanés est exprimable comme une ressource épuisable (code 75).

### 5.7 Stabilité d'une mission en cours

Les agents, le gabarit du superviseur, le contrat et la méthode sont servis par le plugin, dont le dossier change à
chaque version. Donc :

- au démarrage d'une mission, `/devteam:demarrer` copie dans `.superpowers/sdd/<slug>/kit/` ce que le superviseur
  relit à chaque passage (méthode de `demarrer`, `contrat.md`) et écrit `Version devteam: <x.y.z>` dans `state.md` ;
  le prompt de la tâche planifiée ne cite que ces copies, jamais le dossier du plugin ;
- à chaque passage, le superviseur compare la version du plugin chargé à celle de `state.md` ; si elle diffère, il
  n'envoie aucun agent, écrit une ligne dans `state.md`, notifie et sort (verrou libéré). L'utilisateur relance après
  avoir accepté la nouvelle version (une commande de `mise-a-jour` met à jour la ligne et les copies) ou revient à
  l'ancienne ;
- `demarrer` refuse de démarrer si `scripts/devteam/VERSION` diffère de la version du plugin, et renvoie vers
  `/devteam:mise-a-jour`.

### 5.8 `/devteam:mise-a-jour`

Compare `scripts/devteam/VERSION` à la version du plugin, montre le diff des fichiers copiés et le `CHANGELOG.md`
entre les deux, applique avec accord. Refuse si une mission est en cours (`.superpowers/sdd/*/state.md` sans `DONE`,
sauf la commande d'acceptation de version de 5.7) ou si un fichier copié a été modifié localement (il le signale).

## 6. Critères d'acceptation

1. `claude plugin validate` passe ; `make test` du dépôt (bats en conteneur) passe, y compris les tests repris du kit
   source et ceux du moteur.
2. Sur une seconde installation (autre machine ou utilisateur de test) : `claude plugin marketplace add
   tigamadou/devteam` puis `claude plugin install devteam@devteam` rendent les trois skills et les sept agents
   disponibles.
3. Projets de démonstration génériques dans `tests/projets/`, chacun exercé dans une copie temporaire :
   - **vide** (une application Compose sans cibles ni CI) : `/devteam:conformite` produit les cibles, la CI `ci-ok`
     et le fichier projet avec accord fichier par fichier, puis la spec et le plan de mise en conformité pour les
     points 2, 3 et 7 ;
   - **multi-dépôt** (applications dans des dépôts git imbriqués) : le diagnostic s'arrête au bloc 0 et ouvre la
     mission de mise en conformité structurelle, sans autre écriture ;
   - **conforme** : `/devteam:conformite` donne 9/9 sans rien proposer d'écrire ;
   - **version en retard** (kit copié d'une version antérieure) : `/devteam:mise-a-jour` montre le diff et met à jour ;
     `demarrer` refusait avant.
4. Aucun nom, chemin ni détail d'un projet de l'auteur dans le dépôt (vérification par recherche avant chaque push).

## 7. Laissé au constructeur

- Le texte exact des skills et des agents (en reprenant le kit source), l'organisation interne de `modeles/` et des
  adaptateurs d'exemple.
- La forme des projets de démonstration, et ce qui en est automatisé (bats) ou joué à la main avec Claude Code.
- Le découpage du moteur en fonctions et ses tests.
- L'ordre des étapes d'implémentation (le moteur est la partie la plus grosse et peut venir après le reste).

## Annexe A : questionnaire

Chaque question porte le point du contrat concerné. Le skill tente d'abord de déduire la réponse (colonne « déduit
de ») et ne pose la question que s'il n'y parvient pas, ou pour faire confirmer sa déduction.

| # | Bloc | Question | Déduit de |
| --- | --- | --- | --- |
| 1 | 0 · structure (bloquant) | Un seul dépôt contient-il tout le code qu'une mission modifiera ? Sinon : monorepo, mission limitée à un dépôt, ou refus | `.gitignore`, sous-dossiers `.git`, sous-modules |
| 2 | 0 · structure (1) | Tout s'exécute-t-il en conteneur ? Quelles commandes tournent encore sur l'hôte ? | `Makefile`, README, scripts |
| 3 | 0 · structure | Une refonte d'infrastructure est-elle en cours (Kubernetes, monorepo) ? Si oui, la mise en conformité s'y greffe | notes, branches, specs du projet |
| 4 | 0 · structure | Quelles applications entrent dans les missions (le mobile peut être exclu) ? | arborescence |
| 5 | 4 · cibles | Par application : commandes de tests, tests ciblés (passage des chemins), couverture, lint, types | `Makefile`, `package.json`, `composer.json`, `pyproject` |
| 6 | 8 · générés | Fichiers générés (OpenAPI, client typé, schémas) : commande, fichiers versionnés ? | dépôt |
| 7 | 8 · migrations | Outil de migrations, détection d'une migration manquante | framework |
| 8 | 4 · e2e | Tests de bout en bout : outil, données de départ | `playwright.config`, `cypress` |
| 9 | stack | Commande de démarrage de la stack principale et de vérification de sa santé | `Makefile`, Compose |
| 10 | 2–3 · infra | Services d'infrastructure à partager entre agents ; ceux qui n'existent qu'en production | Compose |
| 11 | 3 · isolation | Pour chacun : comment isoler par lot (base, numéro Redis, préfixe, bucket, boîte mails) | type de service |
| 12 | 2 · profils | Profils d'agent pertinents (front, API, complet) et conteneurs de chacun | Compose |
| 13 | 3 · garde-fou | Où placer le garde-fou « base de test de l'agent seulement » | outil de test |
| 14 | 2 · cohabitation | Ports publiés, noms de conteneurs ou volumes figés en dur ? | Compose |
| 15 | 5 · branches | Branche d'intégration, branches protégées | `git branch -a`, `gh api` |
| 16 | 5 · commits | Convention de commit (langue, Conventional Commits, scopes) | `git log`, CONTRIBUTING |
| 17 | 5 · nommage | `feature/<slug>`, `feature/<slug>-<lot>`, `fix/<slug>-<sujet>` acceptés, ou équivalent ? | branches existantes |
| 18 | 6 · CI | CI existante ? Nom du check requis (défaut `ci-ok`) | `.github/workflows` |
| 19 | 6 · protection | Protection de branche activée par le skill (avec accord) ou par le développeur ? | `gh api` |
| 20 | 6 · coûts | Contraintes de minutes CI ou runners auto-hébergés ? | workflows |
| 21 | 7 · budget | Mémoire allouée à Docker, marge à laisser à la machine | `docker info` |
| 22 | 7 · e2e | Nombre d'e2e complets simultanés (défaut 1) | — |
| 23 | divers | Cahier de tests et forme des identifiants de scénarios | dépôt |
| 24 | divers | Moyen de notification | outils de la session |
| 25 | divers | Emplacement des specs et des plans | `docs/` |

(1) Une commande hôte non remplaçable par une cible `make` est bloquante pour le point 1.
