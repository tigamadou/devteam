---
name: conformite
description: "Diagnostique un projet par rapport au contrat devteam, pose au développeur les questions que le projet ne règle pas, puis le met en conformité : génère avec son accord, fichier par fichier, les cibles make, la CI à check unique, le fichier projet et le kit ; rédige la spec et le plan de ce qui demande de l'ingénierie (environnement d'agent, isolation, budget). À utiliser pour installer devteam dans un projet, ou quand /devteam:demarrer refuse de démarrer."
---

# Mise en conformité d'un projet avec devteam

But : amener le projet à remplir les neuf points du [contrat](${CLAUDE_PLUGIN_ROOT}/skills/commun/contrat.md), sans
rien écrire sans accord et sans rien inventer.

## Règles, en tout point du déroulé

- **Une écriture = un fichier**, montré au développeur (contenu complet pour un nouveau fichier, diff pour un fichier
  existant), écrit **seulement après son accord explicite** sur ce fichier. Un refus n'arrête pas le reste : le point
  concerné reste ouvert dans le tableau final.
- **Aucune commande inventée.** Chaque cible `make` renvoie à une commande **trouvée dans le projet** (Makefile, CI,
  scripts, README, `package.json`, `composer.json`, `pyproject.toml`…) dont tu cites l'origine, ou **donnée par le
  développeur**. Les modèles de `${CLAUDE_SKILL_DIR}/modeles/standard/` ne sont que des références.
- Tout s'exécute en conteneur : une commande qui ne tourne que sur l'hôte (gestionnaire de paquets, interpréteur) est
  enveloppée dans une cible `make` qui lance un conteneur, ou signalée comme bloquante pour le point 1.
- **Hors du projet** (protection de branche GitHub, configuration de l'utilisateur) : rien sans accord explicite.
- Jamais de commit ni de push : le développeur committe quand il le décide. Aucune mention d'IA dans ce que tu
  écris pour un commit, une PR ou un fichier.
- Le skill est **relançable** : chaque passage repart du diagnostic et ne repose aucune question déjà consignée.

## 1. Diagnostic, sans écriture

1. `bash "${CLAUDE_PLUGIN_ROOT}/outils/diagnostic.sh" "<racine du projet>"`.
2. Lis le projet : `Makefile`, fichiers Compose, `.github/workflows/`, branches (`git branch -a`), gestionnaires de
   paquets, outils de test et de migration, `CLAUDE.md`, specs et notes existantes.
3. Vérifie ce que le script ne juge pas : commandes hôte citées dans le fichier projet (point 1), présence de l'outil
   `create_scheduled_task` dans la session (point 9).
4. Présente un tableau : point, état (`rempli`, `partiel`, `absent`), ce qui manque, traitement prévu (**direct** :
   étape 3 ; **mission de mise en conformité** : étape 4). En tête, la ligne `structure`.

## 2. Questionnaire

Suis [questionnaire.md](${CLAUDE_SKILL_DIR}/questionnaire.md) : blocs dans l'ordre, **une question à la fois**,
seulement si le projet n'y répond pas ; ce que tu déduis, tu le proposes pour correction. Consigne chaque réponse
dans `.claude/devteam.projet.md` (une fois le fichier accepté à l'étape 3) ou, pour ce qui reste à construire, dans
la spec de l'étape 4.

**Bloc 0 bloquant** (structure `bloquant`, code non conteneurisable, refonte d'infrastructure en cours) : arrête le
questionnaire et va directement à l'étape 4, qui ne porte alors que sur ce préalable structurel ; le reste dépend de
la nouvelle forme du projet.

## 3. Génération directe

Dans cet ordre, un fichier à la fois (règles ci-dessus) :

1. **Fichier projet** `.claude/devteam.projet.md`, à partir de
   [modeles/devteam.projet.md](${CLAUDE_SKILL_DIR}/modeles/devteam.projet.md) : garder les libellés exacts des
   lignes lues par le diagnostic ; une cible sans objet = une ligne `- <cible> : sans objet (<raison>)` ; aucun
   chiffre de budget.
2. **Kit** : `bash "${CLAUDE_PLUGIN_ROOT}/outils/kit.sh" etat "${CLAUDE_PLUGIN_ROOT}" "<projet>"`, montre la liste,
   puis, avec accord, `kit.sh appliquer "${CLAUDE_PLUGIN_ROOT}" "<projet>"`.
3. **Cibles** `make/standard.mk` : les neuf cibles du point 4, chacune avec un commentaire d'origine
   (`# d'après : <fichier ou réponse du développeur>`), et `help` si le projet n'en a pas.
4. **Makefile racine** : ajoute à la fin les lignes de
   [modeles/makefile-inclusions.mk](${CLAUDE_SKILL_DIR}/modeles/makefile-inclusions.mk) qui manquent (diff montré).
5. **CI** : `.github/workflows/devteam-ci.yml` à partir de
   [modeles/ci/devteam-ci.yml](${CLAUDE_SKILL_DIR}/modeles/ci/devteam-ci.yml), branche d'intégration remplacée, jobs
   des cibles sans objet retirés de `jobs` et de `needs` ; ou, au choix du développeur, intégration d'un job agrégateur
   `ci-ok` au workflow existant. Puis propose la protection de branche (check requis `ci-ok`) : commande
   `gh api -X PUT repos/<propriétaire>/<dépôt>/branches/<branche>/protection …` montrée, exécutée seulement avec
   accord, sinon laissée au développeur.
6. **`.claude/settings.json`** : fusion de [modeles/settings.json](${CLAUDE_SKILL_DIR}/modeles/settings.json) avec le
   fichier existant (diff montré), pour que les autres clones connaissent le plugin ; rappelle que chaque clone lance
   une fois `claude plugin install devteam@devteam --scope project`.

## 4. Mission de mise en conformité

Pour ce qui ne se génère pas (typiquement les points 2, 3 et 7, et tout préalable de structure) :

1. Rédige la spec à partir de
   [modeles/mise-en-conformite-spec.md](${CLAUDE_SKILL_DIR}/modeles/mise-en-conformite-spec.md), dans l'emplacement
   des specs du projet (section `plans` du fichier projet, sinon demande), avec les réponses du questionnaire.
2. Rédige le plan au format du
   [gabarit de plan](${CLAUDE_PLUGIN_ROOT}/skills/demarrer/plan-template.md), un plan séquentiel.
3. Si le projet adopte le moteur devteam : le plan copie
   `${CLAUDE_PLUGIN_ROOT}/kit/devteam.agent.conf.exemple` en `devteam.agent.conf`, les adaptateurs utiles de
   `${CLAUDE_PLUGIN_ROOT}/kit/adaptateurs-exemples/` dans `scripts/devteam-adaptateurs/` (ils appartiennent ensuite
   au projet), puis relance `kit.sh appliquer` pour les fichiers de l'ensemble `agent`.
4. Montre spec et plan, écris-les avec accord, indique comment les exécuter (séquentiellement), puis **arrête-toi** :
   tu ne les exécutes pas toi-même.

## 5. Nouveau diagnostic

Relance `diagnostic.sh`, affiche le nouveau tableau et dis ce qui reste et par quel plan. Quand tout est `rempli` et
la structure `ok`, le projet est prêt pour `/devteam:demarrer`.
