# Contrat de prérequis de devteam

Une mission **ne démarre pas** s'il manque un seul de ces neuf points, et le skill **dit lequel**. Pour chaque point,
la vérification décrite ici est appliquée, puis la réponse du projet est lue dans **`.claude/devteam.projet.md`**
(une section `## <clé>` par point). Une section absente, vide ou contredite par la vérification = point manquant.

La partie mécanique de ces vérifications est faite par `outils/diagnostic.sh <projet>` (une ligne par point :
`rempli`, `partiel` ou `absent`) ; le skill complète par ce qu'un script ne peut pas juger (commande hôte citée dans
le fichier projet, présence de l'outil de tâches planifiées). Le diagnostic vérifie aussi un préalable de
**structure** : tout le code qu'une mission modifie est dans un seul dépôt git (pas de dépôt imbriqué ni de
sous-module) ; sinon il est `bloquant`.

Les noms de cibles `make` ci-dessous sont ceux du contrat ; le fichier projet dit comment le projet les remplit. Les
lignes entre accents graves (par exemple `` - Intégration : `<branche>` ``) sont lues telles quelles : le modèle
`skills/conformite/modeles/devteam.projet.md` les donne toutes.

### 1. Docker uniquement

- **Énoncé** : toutes les commandes de build, test, lint et génération passent par des cibles `make` qui lancent des
  conteneurs. L'hôte n'exécute que `docker`, `make`, `git` et `gh`.
- **Vérification** : `make -n help` réussit ; le fichier projet ne cite aucune commande hôte (gestionnaire de
  paquets, interpréteur, lanceur de tests) hors `docker`, `make`, `git`, `gh` (jugé par le skill).
- **Clé** : `docker`

### 2. Environnement d'agent

- **Énoncé** : `make agent-up LOT=<lot> PROFIL=<profil> BASE=<branche>`, `make agent-down LOT=<lot>` et
  `make agent-status`. Un environnement = un worktree `../<projet>-wt-<lot>` sur la branche du lot + ses conteneurs
  applicatifs ; les services d'infrastructure sont partagés (une base, un bucket, un espace de cache par agent,
  jamais un service dupliqué). Chaque profil déclare son coût mémoire mesuré. `agent-up` signale **« pas de place »**
  (budget ou ressource épuisée) distinctement des erreurs, de façon lisible à travers `make` (qui renvoie toujours 2
  quand une recette échoue) : avec le moteur devteam, code 75 du script et ligne `agent-env : pas de place : …` ; le
  signal est déclaré dans le fichier projet.
- **Vérification** : `make -n agent-up LOT=x PROFIL=p BASE=y`, `make -n agent-down LOT=x` et `make -n agent-status`
  ne répondent pas « No rule to make target ».
- **Clé** : `agent_env`

### 3. Isolation des données

- **Énoncé** : chaque agent a ses propres données (base, base de test, cache, files de tâches, stockage, emails) et un
  **garde-fou** refuse de lancer les tests sur une base qui n'est pas une base de test de l'agent.
- **Vérification** : la section nomme les ressources isolées et porte la ligne `` - Garde-fou : `<chemin>` `` ; ce
  chemin existe.
- **Clé** : `isolation`

### 4. Cibles standard

- **Énoncé** : toutes lancées depuis le worktree de l'agent : `make test-cible T=<chemins>`,
  `make coverage-diff BASE=<branche>`, `make lint`, `make typecheck`, `make generate`, `make check-generated`,
  `make migrations-check`, `make e2e-fixtures`, `make e2e`.
- **Vérification** : pour chacune, `make -n <cible>` (variables factices) ne répond pas « No rule to make target »,
  ou la section la déclare par une ligne `- <cible> : sans objet (<raison>)`. Attendu : neuf cibles couvertes.
- **Clé** : `cibles`

### 5. Modèle de branches

- **Énoncé** : une branche principale d'intégration, des branches protégées et une convention de nommage couvrant
  `feature/<slug>`, `feature/<slug>-<lot>` et `fix/<slug>-<sujet>`, et une convention de commit.
- **Vérification** : la section porte `` - Intégration : `<branche>` `` et cette branche figure dans `git branch -a`.
- **Clé** : `branches`

### 6. CI et GitHub

- **Énoncé** : une CI avec un **check requis unique**, déclenchée sur toutes les PR ; `gh` authentifié.
- **Vérification** : `gh auth status` réussit ; la section porte `` - Check requis : `<nom>` `` et un workflow de
  `.github/workflows/` définit un job de ce nom.
- **Clé** : `ci`

### 7. Budget machine

- **Énoncé** : mémoire Docker allouable aux agents, coût de chaque profil, nombre maximal d'e2e complets
  simultanés (jeton e2e, 1 par défaut).
- **Vérification** : la section porte `` - Document : `<chemin>` `` (un document Markdown de profils et de budget, ou
  `devteam.agent.conf` pour un projet qui utilise le moteur devteam) et ce chemin existe, et `- Jeton e2e : <n>`. Les
  chiffres vivent dans ce document, jamais recopiés ailleurs.
- **Clé** : `budget`

### 8. Fichiers générés et migrations

- **Énoncé** : la liste des fichiers **jamais fusionnés à la main** (générés), la façon de résoudre un conflit sur
  eux, et la règle des migrations (un seul lot actif par modèle ou schéma).
- **Vérification** : la section porte `` - Générés : `<chemin>`, `<chemin>` `` (chaque chemin existe) ou
  `- Générés : sans objet`.
- **Clé** : `generes_migrations`

### 9. Tâches planifiées

- **Énoncé** : l'outil de tâches planifiées de la session est disponible, et l'environnement qui le fait tourner
  l'est aussi (application de bureau ouverte, machine éveillée, Docker lancé).
- **Vérification** : `docker info` répond ; l'outil `create_scheduled_task` est présent dans la session (jugé par le
  skill).
- **Clé** : `taches_planifiees`

## Valeurs complémentaires lues dans le fichier projet

- **`stack_principale`** : commande de démarrage et de vérification de la stack principale (le superviseur la lance
  en préalable de chaque passage).
- **`notification`** : moyen de notifier l'utilisateur (l'outil `PushNotification` s'il est disponible dans la
  session, sinon une ligne `NOTIF …` dans `state.md`).
- **`plans`** : emplacement des specs et des plans de mission, convention de commit, labels.
- **`cahier_tests`** (optionnelle) : fichier du cahier de tests et forme des identifiants de scénarios ; lue par le
  testeur et le lead QA. Absente : pas de cahier, aucun identifiant exigé.
- Commandes du kit : labels `make devteam-labels SLUG=<slug> [LOTS="a b"]`, périmètre
  `make devteam-perimetre LOT=<lot> PLAN=<plan> BASE=<branche>`.
