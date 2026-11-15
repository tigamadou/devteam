# Projets de démonstration

`construire.sh <nom> <dossier>` génère un projet générique dans un dossier qui n'existe pas encore :

| Projet | Contenu | Attendu |
| --- | --- | --- |
| `vide` | un dépôt git (`development`), un `compose.yml` avec un service `api`, un `Makefile` `up`/`down` | diagnostic en échec, structure `ok` |
| `multi-depot` | `vide` plus `apps/api` et `apps/web`, dépôts git ignorés par `.gitignore` | structure `bloquant` |
| `conforme` | les neuf cibles (recettes factices), moteur d'agent, fichier projet complet, kit appliqué | neuf points `rempli` |
| `version-en-retard` | `conforme`, kit appliqué depuis une copie du plugin en `0.9.0` | fichiers `a-mettre-a-jour` |

La partie automatisée est `projets.bats` (lancée par `make test`). Ce qui demande Claude Code se joue à la main.

## Recette manuelle

Pour chaque projet : le construire dans un dossier temporaire, puis y lancer Claude Code avec le plugin du dépôt.

```bash
tests/projets/construire.sh vide /tmp/devteam-demo-vide
cd /tmp/devteam-demo-vide && claude --plugin-dir <chemin du dépôt devteam>/plugins/devteam
```

- **vide** : `/devteam:conformite` affiche le tableau du diagnostic, pose les questions du questionnaire bloc par
  bloc et une à la fois, propose chaque fichier un par un (fichier projet, kit, `make/standard.mk`, inclusions du
  `Makefile`, CI, `.claude/settings.json`) et n'écrit qu'après accord, ne cite que des commandes trouvées dans le
  projet ou données en réponse, rédige spec et plan de mise en conformité pour les points 2, 3 et 7 sans les exécuter,
  puis affiche le nouveau tableau.
- **multi-depot** : `/devteam:conformite` s'arrête au bloc 0 et ne propose que la mission de mise en conformité
  structurelle (monorepo, mission limitée à un dépôt, ou refus), sans autre écriture.
- **conforme** : `/devteam:conformite` donne neuf points remplis et ne propose rien à écrire (le point 9 dépend de la
  présence de `create_scheduled_task` dans la session).
- **version-en-retard** : `/devteam:demarrer` refuse et renvoie vers `/devteam:mise-a-jour` ; celui-ci montre le
  diff des fichiers et l'extrait des notes de version, puis met à jour avec accord.

Consigner le résultat de chaque projet dans la Progression du plan.
