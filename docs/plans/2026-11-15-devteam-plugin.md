# Plugin `devteam` v1 : plan d'implémentation

> **Pour les agents :** sous-skill requis : `superpowers:subagent-driven-development` (recommandé) ou
> `superpowers:executing-plans`, tâche par tâche. Les étapes utilisent des cases (`- [ ]`) pour le suivi.

**But :** livrer le plugin Claude Code `devteam` (trois skills, sept agents, kit copié dans les projets, moteur
d'environnement d'agent), installable depuis le dépôt public `tigamadou/devteam`.

**Architecture :** un dépôt qui est à la fois marketplace et plugin (`plugins/devteam/`). Le Markdown (skills,
agents, gabarits) porte la méthode ; deux outils bash déterministes (`outils/kit.sh`, `outils/diagnostic.sh`),
appelés depuis les skills par `${CLAUDE_PLUGIN_ROOT}`, font tout ce qui se vérifie mécaniquement ; `kit/` contient les
fichiers copiés dans les projets, décrits par un `MANIFEST`.

**Pile :** bash compatible 3.2, bats (en conteneur `alpine:3.20`), GNU make, GitHub Actions (modèles), Markdown.

**Spec :** [`docs/specs/2026-11-15-devteam-plugin-design.md`](../specs/2026-11-15-devteam-plugin-design.md).

## Progression

| Tâche | Statut | Date | Notes |
| --- | --- | --- | --- |
| 1. Squelette du dépôt | [x] | 2026-11-15 |  |
| 2. Scripts de base du kit | [x] | 2026-11-15 |  |
| 3. `outils/kit.sh` | [x] | 2026-11-15 |  |
| 4. Contrat, fichier projet, `outils/diagnostic.sh` | [x] | 2026-11-15 |  |
| 5. Skill `demarrer` et gabarits | [x] | 2026-11-15 |  |
| 6. Sept agents | [x] | 2026-11-15 |  |
| 7. Moteur d'environnement d'agent | [x] | 2026-11-15 |  |
| 8. Adaptateurs d'exemple et `devteam-agent.mk` | [x] | 2026-11-15 |  |
| 9. Skill `conformite` | [x] | 2026-11-15 |  |
| 10. Skill `mise-a-jour` | [x] | 2026-11-15 |  |
| 11. Projets de démonstration | [x] | 2026-11-15 | recette manuelle Claude Code à jouer par l'utilisateur |
| 12. Publication locale et vérification finale | [x] | 2026-11-15 | chargement vérifié en non interactif ; installation locale et push en attente d'accord |

## Contraintes globales

- **Sources** : le kit source et les deux environnements d'agent de référence sont sur la machine de l'utilisateur ;
  leurs chemins sont dans `.sources.local` à la racine du dépôt (non versionné, créé par la tâche 1). Ne jamais
  recopier un chemin, un nom de projet, de service, de domaine ni une valeur mesurée de ces sources dans le dépôt :
  les exemples sont génériques (`monprojet`, `api`, `web`, `worker`).
- Renommages à appliquer en reprenant le kit source : « chantier » → « mission » (texte), skill → `demarrer`,
  agents `chantier-<role>` → `devteam:<role>` (fichier `agents/<role>.md`, `name: <role>`), `.claude/chantier.projet.md`
  → `.claude/devteam.projet.md`, `make/chantier.mk` → `make/devteam.mk`, cibles `chantier-*` → `devteam-*`,
  `scripts/chantier/` → `scripts/devteam/`, label `chantier:<slug>` → `devteam:<slug>`, tâche planifiée `<slug>` →
  `devteam-<slug>`. Inchangés : « lot », « superviseur », labels `lot:`, `role:`, `type:`, `etat:`, `revue:`, dossier
  d'état `.superpowers/sdd/<slug>/`.
- Le mot « chantier » n'apparaît nulle part sous `plugins/`.
- Texte en français avec accents ; identifiants, fichiers, branches, labels en ASCII.
- Scripts : `#!/usr/bin/env bash`, `set -euo pipefail`, **bash 3.2** (interdits : `declare -A`, `mapfile`,
  `readarray`, `${v,,}`, `${v^^}`, `&>>`, `coproc`), chemins toujours entre guillemets.
- Codes de sortie des outils : 0 succès, 1 échec du contrôle, 2 usage ; `agent-env` : **75 pas de place** ;
  `kit.sh appliquer` : 3 mission en cours, 4 fichier modifié localement.
- En-tête des fichiers copiés (ligne 1, ou ligne 2 après un shebang) :
  `# devteam {{version}} : fichier du kit, ne pas modifier ici` ; `{{version}}` est remplacé à la copie.
- Version du plugin : `plugins/devteam/.claude-plugin/plugin.json`, clé `version`, valeur initiale `1.0.0` ; pas de
  `version` dans `marketplace.json`.
- Travail sur la branche `feat/plugin-v1` du dépôt `devteam`. **Aucun commit sans demande explicite de
  l'utilisateur** ; les étapes « Commit » proposent le commit et attendent. Messages : une ligne, Conventional Commits
  en français, **sans mention d'IA, sans trailer, sans co-auteur**.
- Hors du dépôt `devteam` (configuration Claude Code, autre dépôt) et pour tout push : accord explicite avant.
- Tests : `make test` (tous les bats en conteneur). Un test qui touche `gh` ou `docker` utilise un faux binaire en tête
  du `PATH`, jamais le vrai.

## Points de vigilance (non couverts par la spec, à tester)

1. **Bash 3.2 sur macOS** alors que les tests tournent sous bash 5 : un script peut passer en CI et casser chez
   l'utilisateur. Test `bash32.bats` (tâche 1) qui refuse les constructions interdites dans tout `*.sh` du dépôt.
2. **Chemin de projet avec espaces et accents** (par exemple sous `Application Support`) : `kit.sh` et `diagnostic.sh`
   doivent fonctionner. Tests dédiés (tâches 3 et 4).
3. **Fichier copié supprimé ou édité à la main par l'utilisateur** : `etat` le dit (`absent`, `modifie-localement`),
   `appliquer` recopie un absent et refuse d'écraser un modifié. Tests (tâche 3).
4. **Version avec suffixe** (`1.1.0-rc.1`) : lue et comparée comme une chaîne exacte. Test (tâche 3).
5. **`.agent.env` corrompu ou lot injecté** (`LOT='a;rm -rf x'`) : refus avant tout appel docker ou adaptateur.
   Tests (tâche 7).

---

### Task 1: Squelette du dépôt

**Fichiers :**
- Créer : `.claude-plugin/marketplace.json`, `plugins/devteam/.claude-plugin/plugin.json`, `Makefile`, `.gitignore`,
  `plugins/devteam/CHANGELOG.md` (dans le plugin : seul ce dossier est installé), `README.md` (remplace l'actuel), `.sources.local` (non versionné), `tests/depot/bash32.bats`,
  `tests/helpers/communs.bash`

**Interfaces :**
- Produit : `make test` (lance `bats -r tests plugins/devteam/kit` dans `alpine:3.20` avec `bash git bats make`,
  dépôt monté sur `/repo`) ; `make validate` (`claude plugin validate plugins/devteam` puis
  `claude plugin validate .`) ; `tests/helpers/communs.bash` avec `fake_bin <nom> <script>` (écrit un faux binaire
  dans `$BATS_TEST_TMPDIR/bin`, en tête du `PATH`, qui journalise `"<nom> $*"` dans `$CALLS_LOG`) et
  `assert_call <regex>` / `refute_call <regex>`.

- [ ] **Étape 1 : créer la branche** `git switch -c feat/plugin-v1` dans le dépôt `devteam`.
- [ ] **Étape 2 : écrire `.sources.local`** avec les trois chemins absolus donnés par la session qui lance le plan
  (kit source, environnement de référence A, environnement de référence B), et `.gitignore` contenant
  `.sources.local`, `.interdits.local`, `.superpowers/`.
- [ ] **Étape 3 : écrire le test qui échoue** `tests/depot/bash32.bats` :
  - `@test "aucun script n'utilise une construction absente de bash 3.2"` : pour chaque `*.sh` et `*.bash` suivi par
    git, `grep -nE 'declare -A|mapfile|readarray|\$\{[a-zA-Z_]+(,,|\^\^)\}|&>>|coproc'` ne trouve rien.
  - `@test "tout script commence par le shebang et set -euo pipefail"` (sauf `*.bash` de helpers et `*.bats`).
- [ ] **Étape 4 : lancer** `make test` ; attendu : échec, car `Makefile` absent (« No rule to make target »).
- [ ] **Étape 5 : écrire** `Makefile` (cibles `help`, `test`, `validate`, `verifier-public` laissée pour la
  tâche 12), `marketplace.json` (`name: devteam`, propriétaire `tigamadou`, une entrée
  `{"name": "devteam", "source": "./plugins/devteam", "description": …}`), `plugin.json` (`name: devteam`,
  `version: 1.0.0`, description en français), `plugins/devteam/CHANGELOG.md` (section `## 1.0.0 (à venir)`), `README.md` (but,
  installation `claude plugin marketplace add tigamadou/devteam` puis `claude plugin install devteam@devteam`, les
  trois skills).
- [ ] **Étape 6 : lancer** `make test` puis `make validate` ; attendu : `ok` sur les deux tests, validation sans
  erreur.
- [ ] **Étape 7 : proposer le commit** `chore: squelette du plugin devteam` (exécuté seulement sur demande).

### Task 2: Scripts de base du kit

**Fichiers :**
- Créer (repris du kit source, renommés) : `plugins/devteam/kit/scripts/devteam/check-perimetre.sh`,
  `plugins/devteam/kit/scripts/devteam/labels.sh`, `plugins/devteam/kit/scripts/devteam/tests/helpers.bash`,
  `…/tests/check-perimetre.bats`, `…/tests/labels.bats`, `plugins/devteam/kit/make/devteam.mk`,
  `plugins/devteam/kit/MANIFEST`
- Test : `tests/kit/manifest.bats`

**Interfaces :**
- Produit : `MANIFEST`, une ligne par fichier : `<ensemble> <chemin relatif à kit/>` où `<ensemble>` vaut `base` ou
  `agent` ; le chemin de destination dans le projet est identique au chemin relatif. Lignes `base` de cette tâche :
  les six fichiers ci-dessus (sauf `MANIFEST`). `labels.sh <slug> [lot…]` crée `devteam:<slug>` (couleur `ededed`,
  description `Mission <slug>`), les 13 labels fixes inchangés, `lot:<id>` (description `Lot <id> de la mission`).
  `devteam.mk` : cibles `devteam-labels SLUG= [LOTS=]`, `devteam-perimetre LOT= PLAN= BASE=`, `devteam-test`
  (même conteneur que la source, `bats -r scripts/devteam` pour inclure les tests du moteur quand il est copié).

- [ ] **Étape 1 : copier** les scripts, helpers et tests du kit source (chemin dans `.sources.local`) vers `kit/`, et
  ajouter l'en-tête de version à chacun.
- [ ] **Étape 2 : adapter les tests** de labels : `@test "crée les 13 labels fixes plus devteam:<slug>"` vérifie
  `^label create devteam:ma-mission ` et 14 créations ; les autres tests gardent leurs assertions.
- [ ] **Étape 3 : lancer** `make test` ; attendu : le test de labels échoue (`chantier:` encore créé).
- [ ] **Étape 4 : renommer** dans `labels.sh`, `check-perimetre.sh` et `devteam.mk` selon les contraintes globales.
- [ ] **Étape 5 : écrire** `tests/kit/manifest.bats` :
  - `@test "chaque ligne du MANIFEST désigne un fichier existant de kit/"` ;
  - `@test "chaque fichier de kit/ est dans le MANIFEST"` (sauf `MANIFEST`, `*.exemple` et `adaptateurs-exemples/`) ;
  - `@test "chaque fichier du MANIFEST porte l'en-tête devteam {{version}}"` (ligne 1, ou 2 après un shebang).
- [ ] **Étape 6 : lancer** `make test` ; attendu : les 34 tests repris et les 3 tests du manifeste passent.
- [ ] **Étape 7 : proposer le commit** `feat(kit): scripts de périmètre et de labels`.

### Task 3: `outils/kit.sh`

**Fichiers :**
- Créer : `plugins/devteam/outils/kit.sh`
- Test : `tests/outils/kit.bats`

**Interfaces :**
- Consomme : `MANIFEST` (tâche 2), `plugin.json` (tâche 1).
- Produit, `kit.sh <sous-commande> …` (`<plugin>` = racine du plugin, `<projet>` = racine du projet) :
  - `version <plugin>` : écrit la valeur de `version` de `plugin.json` (lecture par `sed`, sans `jq`).
  - `etat <plugin> <projet>` : première ligne `version-projet <v|aucune> version-plugin <v>`, puis une ligne
    `<statut> <chemin>` par fichier applicable, `<statut>` ∈ `absent`, `a-jour`, `a-mettre-a-jour`,
    `modifie-localement`. Les lignes `agent` ne s'appliquent que si `<projet>/devteam.agent.conf` existe.
  - `appliquer <plugin> <projet> [chemin…]` : copie les fichiers demandés (tous les `absent` et `a-mettre-a-jour` si
    aucun chemin), remplace `{{version}}`, rend exécutables les `*.sh`, réécrit `scripts/devteam/VERSION`. Sort en 3
    si `mission-en-cours` est vrai, en 4 si un chemin demandé est `modifie-localement` (rien n'est écrit dans ces deux
    cas).
  - `mission-en-cours <projet>` : 0 et les slugs sur la sortie si un `.superpowers/sdd/*/state.md` n'a pas de ligne
    `DONE` ; 1 sinon.
  - `figer <plugin> <projet> <slug>` : copie `skills/demarrer/SKILL.md` en `methode.md` et `skills/commun/contrat.md`
    dans `<projet>/.superpowers/sdd/<slug>/kit/`, crée `state.md` s'il manque, remplace ou ajoute la ligne
    `Version devteam: <v>`.
- Format de `scripts/devteam/VERSION` : ligne 1 `version <v>`, puis `<sha256> <chemin>` par fichier copié
  (`sha256sum` ou, à défaut, `shasum -a 256`). Statuts : `absent` (pas de fichier) ; `modifie-localement` (somme
  différente de celle de `VERSION`, ou fichier sans entrée) ; `a-jour` (somme conforme et contenu égal à la source
  après remplacement) ; `a-mettre-a-jour` (somme conforme, contenu différent de la source).

- [ ] **Étape 1 : écrire les tests qui échouent** dans `tests/outils/kit.bats`, sur un faux plugin
  (`plugin.json` en `1.0.0`, un `MANIFEST` avec une ligne `base` et une ligne `agent`) et un projet temporaire :
  - `version` : écrit `1.0.0` ; avec `1.1.0-rc.1` écrit `1.1.0-rc.1` ;
  - `etat` sur projet vide : `version-projet aucune version-plugin 1.0.0` puis `absent <base>`, sans ligne `agent` ;
    avec `devteam.agent.conf` : la ligne `agent` apparaît ;
  - `appliquer` puis `etat` : tout `a-jour`, en-tête contenant `devteam 1.0.0`, `*.sh` exécutable ;
  - `appliquer` deux fois : même résultat, code 0 ;
  - fichier copié supprimé : `absent`, puis recopié par `appliquer` ;
  - fichier copié modifié : `modifie-localement` ; `appliquer <ce chemin>` sort en 4 et ne touche à rien ;
  - plugin passé en `1.1.0` avec une source modifiée : `a-mettre-a-jour`, puis `a-jour` après `appliquer` ;
  - mission en cours (`state.md` sans `DONE`) : `appliquer` sort en 3 ; avec `DONE` : passe ;
  - `figer` : `methode.md` et `contrat.md` copiés, `Version devteam: 1.0.0` présent une seule fois après deux appels ;
  - projet dans un dossier `Mon projet/Application Support é` : `etat`, `appliquer`, `figer` passent ;
  - sous-commande inconnue ou argument manquant : code 2.
- [ ] **Étape 2 : lancer** `make test` ; attendu : échec, `kit.sh` absent.
- [ ] **Étape 3 : implémenter** `plugins/devteam/outils/kit.sh` selon les interfaces.
- [ ] **Étape 4 : lancer** `make test` ; attendu : tout passe.
- [ ] **Étape 5 : proposer le commit** `feat(outils): copie versionnée du kit dans un projet`.

### Task 4: Contrat, fichier projet, `outils/diagnostic.sh`

**Fichiers :**
- Créer : `plugins/devteam/skills/commun/contrat.md` (repris, renommé), `plugins/devteam/skills/conformite/modeles/devteam.projet.md`,
  `plugins/devteam/outils/diagnostic.sh`
- Test : `tests/outils/diagnostic.bats`

**Interfaces :**
- Produit : le **format du fichier projet**, une section `## <clé>` par clé du contrat (`docker`, `agent_env`,
  `isolation`, `cibles`, `branches`, `ci`, `budget`, `generes_migrations`, `taches_planifiees`, puis
  `stack_principale`, `notification`, `cahier_tests` optionnelle, `plans`). Lignes lues mécaniquement :
  - `isolation` : `- Garde-fou : \`<chemin>\`` ;
  - `cibles` : `- <cible> : sans objet (<raison>)` pour une cible déclarée sans objet ;
  - `branches` : `- Intégration : \`<branche>\`` ;
  - `ci` : `- Check requis : \`<nom>\`` ;
  - `budget` : `- Document : \`<chemin>\`` et `- Jeton e2e : <n>` ;
  - `generes_migrations` : `- Générés : \`<chemin>\`, \`<chemin>\`` ou `- Générés : sans objet`.
- Produit : `diagnostic.sh <projet>` écrit une ligne `structure<TAB><ok|bloquant><TAB><détail>` (bloquant si un
  sous-dossier non ignoré contient un `.git` ou si `.gitmodules` existe ou si un dossier ignoré par `.gitignore`
  contient un `.git`), puis une ligne `<n><TAB><clé><TAB><rempli|partiel|absent><TAB><détail>` par point 1 à 9 ;
  `rempli` = vérification mécanique du contrat réussie **et** section présente et non vide ; `partiel` = l'une des
  deux ; `absent` = aucune. Sortie 0 si tout est `rempli` et la structure `ok`, 1 sinon. Les vérifications sont celles
  du contrat (`make -n` sur les cibles avec variables factices, `gh auth status`, `docker info`, `git branch -a`,
  existence des chemins cités). Le point 9 ne vérifie que `docker info` : la présence de l'outil de tâches planifiées
  est vérifiée par le skill.
- `contrat.md` : les vérifications citent ces lignes exactes, et le point 7 accepte comme document un Markdown ou
  `devteam.agent.conf`.

- [ ] **Étape 1 : reprendre** `contrat.md` depuis le kit source, renommer, aligner chaque « Vérification » sur les
  lignes ci-dessus. Écrire le modèle `devteam.projet.md` (chaque section avec ses lignes, valeurs entre `<…>`).
- [ ] **Étape 2 : écrire les tests qui échouent** dans `tests/outils/diagnostic.bats` (faux `gh` et `docker` qui
  réussissent ou échouent selon `FAKE_GH_RC`, `FAKE_DOCKER_RC`) :
  - projet vide (un `Makefile` sans cible) : 9 lignes `absent` ou `partiel`, code 1 ;
  - projet complet construit dans le test (les 9 cibles, `agent-up/down/status`, fichier projet rempli selon le
    modèle, chemins cités présents) : 9 `rempli`, structure `ok`, code 0 ;
  - cible déclarée `sans objet` dans `cibles` et absente du `Makefile` : point 4 `rempli` ;
  - `gh auth status` en échec : point 6 `partiel` ;
  - dossier `apps/api/.git` ignoré par `.gitignore` : structure `bloquant` ;
  - branche d'intégration nommée mais absente, ou dépôt sans `origin` : point 5 `partiel`, pas d'erreur bash ;
  - garde-fou cité mais inexistant : point 3 `partiel` ;
  - projet sous un chemin avec espaces et accents : mêmes résultats.
- [ ] **Étape 3 : lancer** `make test` ; attendu : échec, `diagnostic.sh` absent.
- [ ] **Étape 4 : implémenter** `diagnostic.sh`.
- [ ] **Étape 5 : lancer** `make test` ; attendu : tout passe.
- [ ] **Étape 6 : proposer le commit** `feat(outils): diagnostic mécanique du contrat`.

### Task 5: Skill `demarrer` et gabarits

**Fichiers :**
- Créer (repris, renommés) : `plugins/devteam/skills/demarrer/SKILL.md`, `…/demarrer/plan-template.md`,
  `…/demarrer/superviseur-template.md`
- Test : `tests/plugin/coherence.bats`

**Interfaces :**
- Consomme : `kit.sh version|etat|figer` (tâche 3), `diagnostic.sh` (tâche 4), `contrat.md`.
- Produit : frontmatter `name: demarrer`, description reprise et renommée. Les chemins du plugin s'écrivent
  `${CLAUDE_PLUGIN_ROOT}/…` (outils, gabarits) ou `${CLAUDE_SKILL_DIR}/…` (fichiers du skill).
- Changements par rapport à la source :
  - **§ 0 Contrat** : lance `bash "${CLAUDE_PLUGIN_ROOT}/outils/diagnostic.sh" "<projet>"` ; si la sortie n'est pas
    0, écrit « Mission impossible : le point <n> du contrat (<intitulé>) n'est pas rempli : <détail>. Lance
    `/devteam:conformite`. » et s'arrête ; vérifie aussi que l'outil `create_scheduled_task` est présent. Puis
    `kit.sh etat` : si `version-projet` diffère de `version-plugin`, refuse et renvoie vers `/devteam:mise-a-jour`.
  - **§ 7 Tâche planifiée** : avant de créer la tâche, `kit.sh figer <plugin> <projet> <slug>` ; nom de tâche
    `devteam-<slug>` ; le gabarit ne cite que `.superpowers/sdd/<slug>/kit/methode.md` et `…/kit/contrat.md`.
  - **§ 8 Rôles** : noms `devteam:<role>`.
- Gabarit du superviseur : § Contexte lit `.claude/devteam.projet.md`, `CLAUDE.md`, `.superpowers/sdd/{{slug}}/kit/methode.md`
  (cycle des labels § 9), la spec, les plans ; § 2 Préalables lit `…/kit/contrat.md` ; **nouveau § 2 bis Version** :
  le rapport du surveillant commence par `Version devteam: <v>` ; si `<v>` diffère de la ligne `Version devteam:` de
  `state.md`, aucun agent n'est lancé après le surveillant, une ligne `VERSION <ancienne> -> <nouvelle> : passage
  suspendu` est ajoutée, notification, sortie avec libération du verrou (§ 1). Agents appelés `devteam:surveillant`,
  `devteam:lead-dev`, `devteam:lead-qa`, `devteam:relecteur`, `devteam:developpeur`, `devteam:testeur`,
  `devteam:planificateur`.

- [ ] **Étape 1 : écrire les tests qui échouent** dans `tests/plugin/coherence.bats` :
  - `@test "aucun « chantier » sous plugins/"` (insensible à la casse) ;
  - `@test "chaque devteam:<role> cité existe dans agents/"` (hors `devteam:<slug>` et `devteam:demarrer|conformite|mise-a-jour`) ;
  - `@test "chaque marqueur {{…}} du gabarit superviseur figure dans la table du § 7 de demarrer"` ;
  - `@test "aucun chemin .claude/skills/ ni .claude/agents/ sous plugins/"` ;
  - `@test "chaque fichier cité par \${CLAUDE_PLUGIN_ROOT}/ ou \${CLAUDE_SKILL_DIR}/ existe"`.
- [ ] **Étape 2 : lancer** `make test` ; attendu : échec (skill absent).
- [ ] **Étape 3 : reprendre et adapter** les trois fichiers selon les interfaces.
- [ ] **Étape 4 : lancer** `make test` ; attendu : échec limité au test des agents (tâche 6), le reste passe.
- [ ] **Étape 5 : proposer le commit** `feat(demarrer): lancement d'une mission et superviseur versionné`, après la
  tâche 6 si l'utilisateur préfère un état vert.

### Task 6: Sept agents

**Fichiers :**
- Créer (repris, renommés) : `plugins/devteam/agents/{surveillant,lead-dev,lead-qa,planificateur,developpeur,testeur,relecteur}.md`

**Interfaces :**
- Consomme : les noms et chemins de la tâche 5.
- Produit : frontmatter `name: <role>` (sans préfixe : le plugin l'ajoute), `description`, `tools` et `model` repris.
  Références : `.claude/devteam.projet.md` ; méthode `.superpowers/sdd/<slug>/kit/methode.md` (le slug est donné dans
  le brief du superviseur) ; cibles `devteam-*` ; label `devteam:<slug>`. **Surveillant** : sa première action lit
  `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` et la première ligne de son rapport est
  `Version devteam: <version>`.

- [ ] **Étape 1 : reprendre** les sept agents du kit source et appliquer les renommages.
- [ ] **Étape 2 : lancer** `make test` ; attendu : `coherence.bats` passe en entier.
- [ ] **Étape 3 : lancer** `make validate` ; attendu : sans erreur.
- [ ] **Étape 4 : proposer le commit** `feat(agents): sept agents devteam`.

### Task 7: Moteur d'environnement d'agent

**Fichiers :**
- Créer : `plugins/devteam/kit/scripts/devteam/agent-env/agent-env.sh`,
  `plugins/devteam/kit/scripts/devteam/agent-env/tests/agent-env.bats`,
  `plugins/devteam/kit/scripts/devteam/agent-env/tests/helpers.bash`,
  `plugins/devteam/kit/scripts/devteam/agent-env/tests/fakes/docker`, `plugins/devteam/kit/devteam.agent.conf.exemple`
- Modifier : `plugins/devteam/kit/MANIFEST` (lignes `agent` pour ces fichiers ; `devteam.agent.conf.exemple` n'y est
  pas : la mission de mise en conformité le copie une fois en `devteam.agent.conf`, qui appartient ensuite au projet)

**Interfaces :**
- Lit `devteam.agent.conf` (racine du dépôt principal, sourcé en bash) :

  ```bash
  DEVTEAM_PROJET=monprojet                 # préfixe des worktrees et projets Compose
  DEVTEAM_PROFILS="web api complet"
  DEVTEAM_COUT_MO_web=0                    # coût mesuré, Mo, un par profil
  DEVTEAM_SERVICES_web="web"               # services Compose lancés, un par profil
  DEVTEAM_STACK_MO=0                       # mémoire de la stack principale en régime établi
  DEVTEAM_MARGE_MO=1500
  DEVTEAM_COMPOSE_FICHIERS="compose.yml compose.agent.yml"
  DEVTEAM_PROJET_PRINCIPAL=monprojet       # projet Compose de la stack principale
  DEVTEAM_SERVICES_INFRA="postgres"        # services qui doivent tourner dans la stack principale
  DEVTEAM_RESSOURCES="postgres:monprojet_{lot} s3:monprojet-{lot}"   # <type>:<paramètre>, {lot} remplacé
  DEVTEAM_LOT_MAX=40
  ```
- Adaptateur : `scripts/devteam-adaptateurs/<type>.sh <action> <lot> <paramètre>` (exécutable du projet), actions :
  - `variables` : appelé **sous verrou** ; écrit des lignes `export K=V` à ajouter au `.agent.env` ; reçoit dans
    `DEVTEAM_ENVS_ACTIFS` les chemins des `.agent.env` des autres lots réservés ; sort en 75 si la ressource est
    épuisée ;
  - `creer` : après le verrou, idempotent ;
  - `liberer` : à `down`, sous verrou ; ne supprime jamais de données durables (bases, buckets).
  Le nettoyage final reste manuel (message affiché par `down`).
- `agent-env.sh up <lot> <profil> <base>` | `down <lot>` | `status` | `budget`, comportements repris de
  l'environnement de référence A (`.sources.local`), généralisés : validation du lot (regex
  `^[a-z0-9]+(-[a-z0-9]+)*$`, longueur ≤ `DEVTEAM_LOT_MAX`, réservés `test` et `e2e`) et du profil (dans
  `DEVTEAM_PROFILS`) avant tout appel docker ; préambule (docker répond, services d'infrastructure présents, base
  existante, chaque fichier Compose présent dans la base) ; worktree `../<DEVTEAM_PROJET>-wt-<lot>` sur
  `<base>-<lot>` (création, reprise sur la bonne branche, refus sinon) ; verrou `mkdir` dans le `git-common-dir`
  (`AGENT_LOCK_TIMEOUT`, `AGENT_LOCK_SLEEP`) ; budget = mémoire Docker − `DEVTEAM_STACK_MO` − `DEVTEAM_MARGE_MO`,
  utilisé = somme des coûts des lots `AGENT_ACTIF=1` ; dépassement → 75 ; ressources réservées dans l'ordre de
  `DEVTEAM_RESSOURCES`, premier 75 → 75 et rien n'est créé ; `.agent.env` (`AGENT_LOT`, `AGENT_PROFIL`,
  `AGENT_ACTIF`, puis les variables des adaptateurs) ; `creer` de chaque ressource ; `docker compose -p
  <DEVTEAM_PROJET>-ag-<lot> -f … up -d --wait <services du profil>` ; message de reprise (`HINT`) en cas d'échec ;
  rien n'est jamais supprimé automatiquement. `down` : refuse si `.agent.env` est absent ou si `AGENT_LOT` ne
  correspond pas ; `docker compose … down -v --remove-orphans` ; `liberer` de chaque ressource sous verrou ; passe
  `AGENT_ACTIF=0` ; affiche le nettoyage manuel. `status` : une ligne par lot actif ou réservé, puis la ligne de
  `budget` (`budget_mo=<n> utilise_mo=<n> libre_mo=<n>`).

- [ ] **Étape 1 : écrire les tests qui échouent** en généralisant la suite de l'environnement de référence A
  (identifiants A1 à B4 de la source) avec un faux `docker` et un vrai git, et des adaptateurs factices écrits par le
  test. À couvrir au minimum :
  - usage et sous-commande inconnue → 2 ; lot invalide (dont `a;rm -rf x`, `../x`, `A`) ou réservé → 1 sans aucun
    appel `docker` journalisé ; lot de `DEVTEAM_LOT_MAX` caractères accepté ;
  - profil hors `DEVTEAM_PROFILS` → 1 ; base inexistante, base sans fichier Compose → 1, rien créé ;
  - service d'infrastructure absent → 1 nommant le service ;
  - premier lot : worktree créé, `.agent.env` contient `AGENT_ACTIF=1` et les variables de l'adaptateur ;
  - budget dépassé → 75, aucun worktree ni appel `creer` ; adaptateur qui sort en 75 → 75, aucun worktree ;
  - reprise d'un lot arrêté sur sa branche → réutilise le worktree ; dossier sur une autre branche → 1 ;
  - verrou tenu au-delà du délai → 1, verrou d'autrui conservé ;
  - `down` avec `.agent.env` corrompu (`AGENT_LOT` différent) → 1, aucun `liberer` ni `compose down` ;
  - `down` normal → `liberer` appelé, `AGENT_ACTIF=0`, aucun appel destructif (`worktree remove`, `branch -D`,
    `dropdb`, `DROP DATABASE`, `FLUSHALL`) ;
  - `status` sans environnement → `Aucun environnement d'agent.` puis la ligne de budget.
- [ ] **Étape 2 : lancer** `make test` ; attendu : échec, `agent-env.sh` absent.
- [ ] **Étape 3 : implémenter** `agent-env.sh` et l'exemple de conf (valeurs à `0` et commentaire « mesurer : voir
  la mission de mise en conformité »).
- [ ] **Étape 4 : lancer** `make test` ; attendu : tout passe, y compris `manifest.bats` et `bash32.bats`.
- [ ] **Étape 5 : proposer le commit** `feat(kit): moteur commun d'environnement d'agent`.

### Task 8: Adaptateurs d'exemple et `devteam-agent.mk`

**Fichiers :**
- Créer : `plugins/devteam/kit/adaptateurs-exemples/{postgres,mysql,redis,s3,port,plafond}.sh`,
  `plugins/devteam/kit/make/devteam-agent.mk`
- Modifier : `plugins/devteam/kit/MANIFEST` (ligne `agent make/devteam-agent.mk` ; les exemples **n'y sont pas** :
  ils sont copiés et ajustés par la mission de mise en conformité, puis appartiennent au projet)
- Test : `tests/kit/adaptateurs.bats`

**Interfaces :**
- Consomme : contrat d'adaptateur de la tâche 7.
- Produit :
  - `postgres.sh` / `mysql.sh` : `creer` crée la base `<paramètre>` dans le conteneur du service de la stack
    principale (`docker exec`), idempotent ; `variables` écrit `export DB_NAME=<paramètre>` ; `liberer` ne fait rien.
  - `s3.sh` : `creer` crée le bucket `<paramètre>` par un conteneur `amazon/aws-cli` sur le réseau d'infrastructure
    (`DEVTEAM_RESEAU_INFRA`, `DEVTEAM_S3_ENDPOINT`), idempotent ; `variables` écrit `export S3_BUCKET=<paramètre>`.
  - `redis.sh` : paramètre = nombre de numéros par lot ; `variables` prend les premiers numéros libres dans `2..15`
    d'après `DEVTEAM_ENVS_ACTIFS`, écrit `export REDIS_DB_1=…` (… `_N`), sort en 75 s'il n'y en a plus ; `liberer`
    fait `FLUSHDB` sur ses numéros, refuse un numéro hors `2..15`.
  - `port.sh` : paramètre `<min>-<max>` ; premier port libre d'après `DEVTEAM_ENVS_ACTIFS`, `export AGENT_PORT=…`,
    75 si la plage est pleine.
  - `plafond.sh` : paramètre = nombre maximal d'environnements simultanés ; 75 si atteint ; aucune variable.
  - Les noms de conteneurs, d'identifiants et de mots de passe viennent de variables `DEVTEAM_*` du conf, avec des
    valeurs par défaut génériques ; aucune valeur d'un projet réel.
  - `devteam-agent.mk` : `agent-up LOT= PROFIL= BASE=`, `agent-down LOT=`, `agent-status`, messages d'usage et code 2
    si une variable manque ; inclus par `-include make/devteam-agent.mk` seulement si `devteam.agent.conf` existe
    (la ligne d'inclusion conditionnelle est fournie dans les modèles de la tâche 9).
- [ ] **Étape 1 : écrire les tests qui échouent** `tests/kit/adaptateurs.bats` (faux `docker`) :
  - `redis.sh variables` sans autre lot → `REDIS_DB_1=2` ; avec deux lots qui tiennent 2 et 3 → `4` ; tous pris → 75 ;
  - `redis.sh liberer` avec un `.agent.env` contenant `REDIS_DB_1=0` → refus, aucun `FLUSHDB` ;
  - `port.sh variables 4100-4101` avec un lot sur 4100 → `4101` ; plage pleine → 75 ;
  - `plafond.sh variables 2` avec deux lots actifs → 75 ;
  - `postgres.sh creer` → un `docker exec` contenant `CREATE DATABASE` ; deuxième appel quand la base existe → aucune
    création ;
  - `make -n agent-up LOT=x PROFIL=web BASE=y` avec `devteam-agent.mk` inclus → pas de « No rule » ; sans `LOT` → 2.
- [ ] **Étape 2 : lancer** `make test` ; attendu : échec.
- [ ] **Étape 3 : implémenter** les six adaptateurs et `devteam-agent.mk`.
- [ ] **Étape 4 : lancer** `make test` ; attendu : tout passe.
- [ ] **Étape 5 : proposer le commit** `feat(kit): adaptateurs d'exemple et cibles d'environnement`.

### Task 9: Skill `conformite`

**Fichiers :**
- Créer : `plugins/devteam/skills/conformite/SKILL.md`, `…/conformite/questionnaire.md`,
  `…/conformite/modeles/standard/{django,laravel,node,prisma}.mk`, `…/conformite/modeles/ci/devteam-ci.yml`,
  `…/conformite/modeles/settings.json`, `…/conformite/modeles/makefile-inclusions.mk`,
  `…/conformite/modeles/mise-en-conformite-spec.md`
- Modifier : `tests/plugin/coherence.bats`

**Interfaces :**
- Consomme : `diagnostic.sh`, `kit.sh etat|appliquer`, modèle `devteam.projet.md` (tâche 4), `plan-template.md`
  (tâche 5), adaptateurs d'exemple (tâche 8).
- Produit :
  - `SKILL.md` (`name: conformite`) : les cinq étapes de la spec § 5.4, dans l'ordre, avec ces règles écrites
    explicitement : une écriture = un fichier montré (contenu ou diff) puis accord ; aucune commande inventée (chaque
    cible cite la commande trouvée et son origine, ou la réponse du développeur) ; une réponse bloquante du bloc 0
    arrête le questionnaire ; réponses consignées dans `.claude/devteam.projet.md` ; la protection de branche via
    `gh api` n'est exécutée qu'avec accord ; à l'étape 4, le skill écrit spec et plan à partir de
    `mise-en-conformite-spec.md` et `plan-template.md`, propose de copier les adaptateurs d'exemple utiles, ne lance
    rien et s'arrête ; étape 5 relance `diagnostic.sh` et affiche le tableau.
  - `questionnaire.md` : l'annexe A de la spec, telle quelle (25 questions, blocs, « déduit de »).
  - `modeles/standard/*.mk` : pour chaque stack, les neuf cibles du point 4 en commentaires d'exemple (`# exemple :`),
    jamais une recette prête ; en tête, « référence seulement : chaque commande doit venir du projet ».
  - `modeles/ci/devteam-ci.yml` : `on: pull_request` et `push` sur la branche d'intégration `<integration>`, un job
    par famille de cibles (`lint`, `typecheck`, `test`, `check-generated`, `migrations-check`, `e2e`), chacun
    `make <cible>`, et `ci-ok` avec `if: always()`, `needs` sur tous les jobs, étape
    `echo "$NEEDS" | jq -e 'all(.[]; .result == "success" or .result == "skipped")'`.
  - `modeles/settings.json` : `extraKnownMarketplaces.devteam.source = {"source": "github", "repo": "tigamadou/devteam"}`
    et `enabledPlugins["devteam@devteam"] = true` ; le skill fusionne avec un `settings.json` existant.
  - `modeles/makefile-inclusions.mk` : `-include make/devteam.mk`, `-include make/standard.mk`, et
    `ifneq ($(wildcard devteam.agent.conf),)` + `-include make/devteam-agent.mk` + `endif`.
- [ ] **Étape 1 : étendre** `coherence.bats` : `@test "questionnaire.md contient les 25 questions"` (lignes `| <n> |`
  pour 1 à 25) ; `@test "devteam-ci.yml est un YAML valide avec un job ci-ok en if: always()"` (`python3 -c 'import
  yaml'` n'est pas dans le conteneur : vérifier par `grep` la présence de `ci-ok:` et de `if: always()` sous lui) ;
  `@test "modeles/standard ne contient aucune ligne de recette active"` (toute ligne commençant par une tabulation
  est commentée).
- [ ] **Étape 2 : lancer** `make test` ; attendu : échec.
- [ ] **Étape 3 : écrire** le skill, le questionnaire et les modèles.
- [ ] **Étape 4 : lancer** `make test` et `make validate` ; attendu : tout passe.
- [ ] **Étape 5 : proposer le commit** `feat(conformite): diagnostic, questionnaire et mise en conformité`.

### Task 10: Skill `mise-a-jour`

**Fichiers :**
- Créer : `plugins/devteam/skills/mise-a-jour/SKILL.md`

**Interfaces :**
- Consomme : `kit.sh etat|appliquer|mission-en-cours|figer`.
- Produit (`name: mise-a-jour`) : deux usages.
  - **Mettre à jour le kit** : `kit.sh etat` ; montre les fichiers `a-mettre-a-jour` (diff entre la copie du projet
    et la source) et l'extrait de `${CLAUDE_PLUGIN_ROOT}/CHANGELOG.md` entre les deux versions ; signale les
    `modifie-localement` sans y toucher ; avec accord, `kit.sh appliquer` ; sur code 3, explique qu'une mission est en
    cours et propose l'usage suivant ; sur code 4, liste les fichiers modifiés.
  - **Accepter une nouvelle version pour une mission en cours** : sur demande explicite, pour un slug donné,
    `kit.sh figer <plugin> <projet> <slug>` ; rappelle que le superviseur reprendra au prochain passage.
- [ ] **Étape 1 : écrire** le skill.
- [ ] **Étape 2 : lancer** `make test` et `make validate` ; attendu : `coherence.bats` passe (chemins cités
  existants, aucun « chantier »).
- [ ] **Étape 3 : proposer le commit** `feat(mise-a-jour): synchronisation du kit et changement de version`.

### Task 11: Projets de démonstration

**Fichiers :**
- Créer : `tests/projets/{vide,multi-depot,conforme,version-en-retard}/` (fichiers générés par
  `tests/projets/construire.sh <nom> <dossier>`, pas de dépôts git imbriqués commités), `tests/projets/construire.sh`,
  `tests/projets/README.md`
- Test : `tests/projets/projets.bats`

**Interfaces :**
- Consomme : `diagnostic.sh`, `kit.sh`.
- Produit : `construire.sh <nom> <dossier>` crée le projet dans `<dossier>` (dépôt git initialisé, branche
  `development`, commits) :
  - `vide` : `compose.yml` avec un service `api` (image `alpine`), un `Makefile` avec `up` et `down` ;
  - `multi-depot` : `vide` plus `apps/api/` et `apps/web/` comme dépôts git ignorés par `.gitignore` ;
  - `conforme` : les 9 cibles (recettes `@true`), `agent-up/down/status` par `devteam-agent.mk` et un
    `devteam.agent.conf` rempli, fichier projet complet, garde-fou et document de budget présents, kit appliqué ;
  - `version-en-retard` : `conforme` dont `scripts/devteam/VERSION` et les en-têtes indiquent `0.9.0`.
- [ ] **Étape 1 : écrire les tests qui échouent** `tests/projets/projets.bats` (faux `gh` et `docker` qui
  réussissent) :
  - `vide` : `diagnostic.sh` code 1, points 2, 3, 4, 6, 7 non `rempli`, structure `ok` ;
  - `multi-depot` : structure `bloquant` ;
  - `conforme` : code 0, 9 `rempli` ; `kit.sh etat` : tout `a-jour` ;
  - `version-en-retard` : `kit.sh etat` → `version-projet 0.9.0`, fichiers `a-mettre-a-jour` ; après `appliquer` :
    `version-projet 1.0.0`, tout `a-jour` ; `make devteam-test` dans le projet passe.
- [ ] **Étape 2 : lancer** `make test` ; attendu : échec.
- [ ] **Étape 3 : implémenter** `construire.sh`.
- [ ] **Étape 4 : lancer** `make test` ; attendu : tout passe.
- [ ] **Étape 5 : écrire** `tests/projets/README.md` : la recette manuelle avec Claude Code, par projet construit
  dans un dossier temporaire, plugin chargé par `claude --plugin-dir plugins/devteam` :
  - `vide` : `/devteam:conformite` pose les questions des blocs dans l'ordre, propose chaque fichier un par un, écrit
    seulement après accord, produit spec et plan pour les points 2, 3, 7, puis affiche le nouveau tableau ;
  - `multi-depot` : s'arrête au bloc 0 et ne propose que la mission structurelle ;
  - `conforme` : 9/9, rien à écrire ;
  - `version-en-retard` : `/devteam:demarrer` refuse et renvoie vers `/devteam:mise-a-jour`, qui montre le diff et
    met à jour.
- [ ] **Étape 6 : proposer le commit** `test: projets de démonstration`.

### Task 12: Publication locale et vérification finale

**Fichiers :**
- Modifier : `Makefile` (cible `verifier-public`), `plugins/devteam/CHANGELOG.md`, `README.md`
- Créer : `tests/depot/public.bats`, `tests/depot/motifs-publics.txt`

**Interfaces :**
- Produit : `make verifier-public` : recherche (`git grep -nE`) dans les fichiers suivis chaque expression de
  `tests/depot/motifs-publics.txt` (dossiers personnels macOS et Linux, adresses Gmail, en-tête de clé privée, jetons
  GitHub `ghp_` et clés AWS `AKIA`) et de `.interdits.local` (non versionné, une expression par ligne, rempli par
  l'utilisateur avec ses noms de projets) ; `motifs-publics.txt` lui-même est exclu de la recherche ; sort en 1 en
  listant les correspondances.
- [ ] **Étape 1 : écrire le test qui échoue** `tests/depot/public.bats`, sur une copie temporaire du dépôt : un
  fichier suivi contenant un dossier personnel macOS (chaîne construite à l'exécution, pour ne pas l'écrire dans le
  test) → `make verifier-public` sort en 1 ; un motif de `.interdits.local` trouvé → 1 ; dépôt propre → 0.
- [ ] **Étape 2 : implémenter** la cible ; lancer `make test` ; attendu : tout passe.
- [ ] **Étape 3 : demander à l'utilisateur** de remplir `.interdits.local` (noms de ses projets et services), puis
  lancer `make verifier-public` ; attendu : code 0.
- [ ] **Étape 4 : compléter** `plugins/devteam/CHANGELOG.md` (`## 1.0.0`, contenu livré) et `README.md` (installation par projet via
  `.claude/settings.json`, commande `claude plugin install devteam@devteam --scope project` à lancer par clone,
  développement avec `--plugin-dir`).
- [ ] **Étape 5 : lancer** `make test`, `make validate`, `make verifier-public` ; attendu : les trois réussissent.
- [ ] **Étape 6 : jouer la recette manuelle** de `tests/projets/README.md` avec `claude --plugin-dir plugins/devteam`
  et consigner le résultat de chaque projet dans la Progression.
- [ ] **Étape 7 : avec l'accord de l'utilisateur** (écriture dans sa configuration Claude Code), installer depuis la
  marketplace locale (`claude plugin marketplace add <dépôt>` puis `claude plugin install devteam@devteam`) et
  vérifier que `/devteam:demarrer`, `/devteam:conformite`, `/devteam:mise-a-jour` et les sept agents `devteam:*` sont
  listés.
- [ ] **Étape 8 : proposer** le commit final, puis, sur demande explicite seulement, le push de `feat/plugin-v1` et la
  PR vers `main`. L'acceptation 2 de la spec (installation depuis GitHub sur une seconde machine) se fait après la
  fusion, par l'utilisateur.
