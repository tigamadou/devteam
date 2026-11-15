---
name: demarrer
description: "Lance une mission devteam à partir d'une spec validée : découpage en graphe de lots à fichiers exclusifs, plans rédigés en parallèle par des agents, puis tâche planifiée qui orchestre l'exécution (un environnement par lot, revues, fusions, PR finale). À utiliser dès qu'une feature touche plusieurs zones du code ou demande plus d'une session, dans un projet conforme au contrat devteam."
---

# Mission : de la spec validée à la PR finale, en parallèle

Méthode générique : elle ne contient aucune valeur propre à un projet. Les valeurs (branches, commandes, labels,
budget, règles de test) sont lues dans **`.claude/devteam.projet.md`** ; les règles du projet dans `CLAUDE.md`.

Fichiers du plugin : [contrat](${CLAUDE_PLUGIN_ROOT}/skills/commun/contrat.md),
[gabarit de plan](${CLAUDE_SKILL_DIR}/plan-template.md),
[gabarit du superviseur](${CLAUDE_SKILL_DIR}/superviseur-template.md), les outils
`${CLAUDE_PLUGIN_ROOT}/outils/diagnostic.sh` et `${CLAUDE_PLUGIN_ROOT}/outils/kit.sh`, et les sept agents
`devteam:<role>`.

## 0. Contrat

1. Lance `bash "${CLAUDE_PLUGIN_ROOT}/outils/diagnostic.sh" "<racine du projet>"`. Lis aussi le contrat et juge ce
   que le script ne vérifie pas (aucune commande hôte citée dans le fichier projet ; outil `create_scheduled_task`
   présent dans la session).
2. **S'il manque un point** (code de sortie non nul, structure `bloquant`, ou point jugé manquant), **refuse de
   démarrer** : écris « Mission impossible : le point <n> du contrat (<intitulé>) n'est pas rempli : <détail>. Lance
   `/devteam:conformite`. », puis arrête-toi. Ne contourne pas.
3. Lance `bash "${CLAUDE_PLUGIN_ROOT}/outils/kit.sh" etat "${CLAUDE_PLUGIN_ROOT}" "<racine du projet>"`. Si
   `version-projet` diffère de `version-plugin`, refuse : « Le kit copié dans le projet est en version <v projet>, le
   plugin en <v plugin> : lance `/devteam:mise-a-jour`. », puis arrête-toi.
4. Demande en **une seule question** ce qui manque parmi : slug de la mission (ASCII, minuscules et tirets), titre.

## 1. Spec validée

Une spec validée est requise (nom, contenu, emplacement : voir la section `plans` du fichier projet). Sans spec :
lance `superpowers:brainstorming` d'abord et ne va pas plus loin avant validation.

## 2. Découpage en graphe de lots

- La mission part de la branche d'intégration sur `feature/<slug>`.
- **Règle centrale : un lot = une chaîne de tâches dépendantes** (chaque tâche a besoin de la précédente). **Deux
  tâches indépendantes vont dans deux lots.** Maximise le nombre de lots indépendants.
- Un lot peut **dépendre d'autres lots** : il démarre quand ils sont fusionnés dans la branche de la mission. La
  mission est un graphe ; le **socle** n'est qu'un lot amont dont les autres dépendent, et il reste **petit** pour que
  la file démarre vite.
- Chaque lot a une liste de **fichiers exclusifs** (globs) et une liste **en lecture seule**. **Aucun fichier
  modifiable dans deux lots actifs en même temps.** Un document partagé est découpé en sections attribuées.
- Chaque lot déclare son **profil** d'environnement (le coût mémoire de chaque profil est lu dans le document cité par
  la section `budget` du fichier projet).
- Branches de lot : `feature/<slug>-<lot>`, parties de `feature/<slug>`.
- Règles propres au projet (migrations, fichiers générés) : lues dans le fichier projet (`generes_migrations`).
- **Table de contrôle** dans la spec : une ligne par paire de lots qui partagent un fichier ou une interface
  (producteur / consommateur / verdict). Un fichier partagé non résolu **remonte dans un lot amont**.
- Complète la spec par une section **« Organisation du travail »** : graphe, lots, fichiers, profils, table de
  contrôle.

## 3. Plans en parallèle

Un **planificateur** (`devteam:planificateur`) **par lot**, **tous lancés dans le même message**. Brief
auto-suffisant : spec, section « Organisation du travail », globs du lot, contrats des lots amont, chemin du
[gabarit de plan](${CLAUDE_SKILL_DIR}/plan-template.md), fichier projet. Emplacement des plans et `README.md` de la
mission (graphe, tableau de bord) : voir la section `plans` du fichier projet.

## 4. Relecture croisée

Contrats entre lots (noms, signatures, formats), listes exclusives sans recouvrement, tâches contradictoires, lots à
scinder signalés par les planificateurs. Amende les plans et journalise chaque arbitrage dans la spec.

## 5. Validation utilisateur

Présente : graphe, plans, fichiers par lot, et ce que la tâche planifiée fera seule (commits par tâche sur les
branches de la mission, PR de lot, PR finale ; **jamais** de fusion de la PR finale). Attends un **accord explicite**
avant les étapes 6 et 7.

## 6. Issues et labels

- Labels de la mission : `make devteam-labels SLUG=<slug> LOTS="<lots>"` (`devteam:<slug>`, `lot:<id>` par lot, et
  les labels fixes). Labels fixes : `role:dev`, `role:testeur`, `role:planificateur`, `type:lot`, `type:ci`,
  `type:test`, `type:revue`, `etat:pret`, `etat:en-cours`, `etat:en-revue`, `etat:a-corriger`, `etat:bloque`,
  `revue:ok`.
- Une **issue de lot** par lot : lien du plan, `Dépend de #…`, profil, fichiers exclusifs ; labels `devteam:<slug>`,
  `lot:<id>`, `role:…`, `type:lot`, et `etat:pret` si le lot n'a aucune dépendance.

## 7. Tâche planifiée

1. Fige la méthode et la version pour cette mission :
   `bash "${CLAUDE_PLUGIN_ROOT}/outils/kit.sh" figer "${CLAUDE_PLUGIN_ROOT}" "<racine du projet>" "<slug>"`. Le
   superviseur ne lira que ces copies (`.superpowers/sdd/<slug>/kit/methode.md` et `…/kit/contrat.md`), jamais le
   dossier du plugin, qui change à chaque version.
2. Crée la tâche avec `create_scheduled_task`, nom `devteam-<slug>`, cron `*/15 * * * *`, dont le prompt est le
   [gabarit du superviseur](${CLAUDE_SKILL_DIR}/superviseur-template.md) rempli. Remplace **chaque** marqueur :

| Marqueur | Valeur |
| --- | --- |
| `{{slug}}` | slug de la mission |
| `{{titre}}` | titre de la mission |
| `{{branche}}` | branche de la mission `feature/<slug>` |
| `{{base}}` | branche d'intégration dont elle est partie |
| `{{spec}}` | chemin de la spec |
| `{{plans}}` | chemins des plans de lot |
| `{{lots}}` | liste des lots |
| `{{ordre_graphe}}` | dépendances entre lots (qui attend qui) |
| `{{depot}}` | chemin absolu du dépôt principal |
| `{{exceptions_risque}}` | exceptions aux actions à risque accordées pour cette mission, ou « Aucune exception. » |

Indique à l'utilisateur : le nom de la tâche, l'emplacement de l'état (`.superpowers/sdd/<slug>/state.md`), la
version de devteam figée pour la mission, et qu'elle ne tourne que **application de bureau ouverte, machine
éveillée, Docker lancé**. Si le plugin change de version pendant la mission, le superviseur suspend ses passages et
notifie ; `/devteam:mise-a-jour` permet alors d'accepter la nouvelle version pour la mission.

## 8. Rôles

**Seul le superviseur lance des agents** : un sous-agent ne lance personne. Les chefs d'équipe décident et exécutent
eux-mêmes leurs écritures GitHub (issues, commentaires, labels, fusions) ; le superviseur lance les agents, tient le
verrou, l'état et les compteurs (voir § 9). Issues et PR sont le support durable de la coordination.

| Agent | Rôle | Interdits |
| --- | --- | --- |
| `devteam:surveillant` | Contrôle les agents actifs, arrête les bloqués, demande la relance, donne la version du plugin | Coder, décider du contenu |
| `devteam:lead-dev` | CI, issues de correctif, arbitrages, fusion (`--merge`) des PR de lot et de correctif, PR finale | Coder un correctif, fusionner la PR finale |
| `devteam:lead-qa` | Qualité des tests de chaque PR de lot, issues testeur | Modifier du code |
| `devteam:planificateur` | Rédige le plan d'un lot (préparation ou re-planification), signale un lot à scinder | Toucher au code |
| `devteam:developpeur` | Exécute une issue `role:dev` en TDD, PR de lot, répond aux revues | Sortir de ses fichiers, force push |
| `devteam:testeur` | Tests e2e, scénarios, tests manquants | Modifier le code de production |
| `devteam:relecteur` | Relecture en lecture seule d'une PR (lot, correctif, finale), un fil par constat, `revue:ok` | Modifier le code, approuver |

Le superviseur adapte l'équipe au graphe (un développeur par lot actif, testeurs selon les lots de test, un relecteur
par PR prête).

## 9. Cycle des labels et exécution des décisions

**Qui écrit quoi** : les **leads et agents exécutent eux-mêmes leurs écritures GitHub** (`gh issue create/close/comment/
edit`, labels, `gh pr merge`). Le **superviseur** ne fait que : verrou, état, lancement et arrêt des agents, label
`etat:en-cours` au lancement, compteurs, notifications. Chaque lead écrit en plus un rapport de passage à chemin fixe
`.superpowers/sdd/<slug>/passages/<AAAAMMJJ-HHMM>-<role>.md` (sections `Décisions prises`, `Issues créées / fermées`,
`PR fusionnées`, `Demandes au superviseur`).

**Automate des labels** (une transition, un responsable) :

| Transition | Responsable |
| --- | --- |
| issue créée sans `etat:*` (ou `etat:pret`) et dépendances `Dépend de #…` toutes closes → lancée, `etat:en-cours` | superviseur |
| PR ouverte → `etat:en-revue` (PR et issue), retire `etat:en-cours` | développeur / testeur |
| relecture : fils ouverts → `etat:a-corriger` ; sinon `revue:ok` ; retire `etat:en-revue` | relecteur |
| PR `etat:a-corriger`, ou issue « mettre à jour depuis la branche de la mission » → développeur du lot relancé, `etat:en-cours` | superviseur |
| push après une revue → retire `revue:ok` et `etat:a-corriger`, pose `etat:en-revue` | développeur / testeur |
| fusion d'une PR de lot ou de correctif (exige `revue:ok` **postérieur au dernier commit**) ; fermeture de l'issue de lot ; fermeture de l'issue de correctif quand la CI est verte | lead dev |
| `etat:bloque` (plafonds atteints ou action à risque) ; **jamais relancé automatiquement** | superviseur (sur demande d'un lead ou du surveillant) |

`type:revue` marque les issues `role:dev` de **reprise de revue** (PR de correctif ou finale en `etat:a-corriger`, sans
développeur de lot à relancer). Compteurs (`relances <issue> n/2`, `echec <issue> <signature> n/3`) : tenus par le
superviseur dans `state.md`.

**Correctifs** : le lead écrit dans l'issue de correctif la **branche visée** ; le développeur ou testeur part de cette
branche sur `fix/<slug>-<sujet>`, ouvre une PR vers elle ; le lead dev la fusionne (`--merge`) aux mêmes conditions
qu'un lot (périmètre : fichiers listés dans l'issue). La régénération des fichiers générés et le contrôle des
migrations après fusion passent par une issue `role:dev` sur la branche de la mission, exécutée dans le worktree
d'intégration `../<projet>-wt-integration` sur `feature/<slug>`.

**Branche locale à jour** : le superviseur fait `git fetch` puis `git pull --ff-only` sur la branche de la mission
avant chaque `agent-up`, et utilise `origin/<branche>` comme base de la commande de périmètre
(`make devteam-perimetre LOT=<lot> PLAN=<plan> BASE=origin/<branche>`).
