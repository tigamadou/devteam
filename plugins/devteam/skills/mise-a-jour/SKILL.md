---
name: mise-a-jour
description: "Synchronise les fichiers du kit devteam copiés dans un projet (make/devteam.mk, scripts/devteam/…) avec la version du plugin installée, et permet d'accepter une nouvelle version de devteam pour une mission en cours. À utiliser après une mise à jour du plugin, ou quand /devteam:demarrer ou le superviseur signalent un écart de version."
---

# Mise à jour du kit devteam dans un projet

Outil : `${CLAUDE_PLUGIN_ROOT}/outils/kit.sh`. Notes de version : `${CLAUDE_PLUGIN_ROOT}/CHANGELOG.md`. Rien n'est
écrit sans accord explicite ; jamais de commit ni de push.

## Usage 1 : mettre à jour le kit copié

1. `bash "${CLAUDE_PLUGIN_ROOT}/outils/kit.sh" etat "${CLAUDE_PLUGIN_ROOT}" "<racine du projet>"`. La première ligne
   donne `version-projet` et `version-plugin` ; les suivantes, le statut de chaque fichier.
2. Présente :
   - les fichiers `a-mettre-a-jour` et `absent`, avec pour chacun le diff entre la copie du projet et la source du
     plugin (`${CLAUDE_PLUGIN_ROOT}/kit/<chemin>`, où `{{version}}` sera remplacé par la version du plugin) ;
   - l'extrait du `CHANGELOG.md` entre les deux versions ;
   - les fichiers `modifie-localement` : ils ne seront **pas** touchés. Propose au développeur de reporter ses
     modifications ailleurs (une cible de `make/standard.mk`, un fichier du projet) puis de supprimer le fichier pour
     qu'il soit recopié, ou de le garder tel quel en connaissant l'écart.
3. Avec accord, `bash "${CLAUDE_PLUGIN_ROOT}/outils/kit.sh" appliquer "${CLAUDE_PLUGIN_ROOT}" "<racine du projet>"`.
   - **Code 3** (mission en cours) : rien n'est copié. Explique qu'on ne change pas le kit sous une mission qui
     tourne : attendre sa fin (`DONE` dans `.superpowers/sdd/<slug>/state.md`), ou, si c'est le superviseur qui a
     signalé l'écart, passer à l'usage 2.
   - **Code 4** (fichier modifié localement demandé explicitement) : liste les fichiers en cause, rien n'est copié.
4. Relance `kit.sh etat` et montre le résultat ; si `version-projet` est restée l'ancienne (mise à jour partielle à
   cause de fichiers modifiés localement), dis-le : `/devteam:demarrer` refusera tant que l'écart demeure.

## Usage 2 : accepter une nouvelle version pour une mission en cours

Le superviseur suspend ses passages quand le plugin chargé n'est plus dans la version figée pour la mission (ligne
`VERSION <ancienne> -> <nouvelle> : passage suspendu` dans `state.md`). Sur **demande explicite** du développeur, pour
un slug donné :

1. Montre l'extrait du `CHANGELOG.md` entre la version figée (ligne `Version devteam:` de
   `.superpowers/sdd/<slug>/state.md`) et la version du plugin, et ce qui change pour la mission (méthode, agents).
2. Avec accord, `bash "${CLAUDE_PLUGIN_ROOT}/outils/kit.sh" figer "${CLAUDE_PLUGIN_ROOT}" "<racine du projet>" "<slug>"` :
   la méthode et le contrat de la mission sont recopiés et la ligne de version mise à jour.
3. Rappelle que le superviseur reprendra au prochain passage (toutes les 15 minutes), et que les fichiers du kit
   copiés dans le projet ne sont mis à jour qu'après la fin de la mission (usage 1).

Revenir à l'ancienne version à la place : réinstaller le plugin dans la version figée
(`claude plugin install devteam@devteam` après avoir ramené la marketplace sur l'ancienne version), sans toucher à
`state.md`.
