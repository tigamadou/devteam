# Valeurs du projet pour devteam

Réponses de ce projet au contrat de devteam : une section par clé. Les lignes de la forme `- Libellé : …` sont lues
par le diagnostic : garder leur libellé exact. Les chiffres de budget ne sont **jamais recopiés ici** : ils vivent
dans le document cité par `budget`.

## docker

Toutes les commandes de build, test, lint et génération passent par des cibles `make` qui lancent des conteneurs.
Sur l'hôte : `docker`, `make`, `git`, `gh` seulement.

## agent_env

- `make agent-up LOT=<lot> PROFIL=<profils> BASE=<branche>`, `make agent-down LOT=<lot>`, `make agent-status`.
- Worktree `../<projet>-wt-<lot>` ; projet Compose `<projet>-ag-<lot>`.
- Worktree d'intégration `../<projet>-wt-integration` sur `feature/<slug>`.
- « Pas de place » de `agent-up` : ligne `agent-env : pas de place : …` (code 75 du script, réessayer plus tard) ;
  autres échecs = erreur.
- La stack principale se lance toujours depuis le dépôt principal.

## isolation

- Ressources isolées par lot : <base, base de test, cache, stockage, emails…>.
- Garde-fou : `<chemin du fichier qui refuse les tests hors de la base de test de l'agent>`

## cibles

Toutes lancées depuis le worktree : `make test-cible T=<chemins>`, `make coverage-diff BASE=<branche>`, `make lint`,
`make typecheck`, `make generate`, `make check-generated`, `make migrations-check`, `make e2e-fixtures`, `make e2e`.

<!-- Une cible sans objet : une ligne « - <cible> : sans objet (<raison>) », par exemple :
- generate : sans objet (aucun fichier généré)
-->

## branches

- Intégration : `<branche>`
- Protégées : `<branches>`.
- Nommage : `feature/<slug>`, `feature/<slug>-<lot>`, `fix/<slug>-<sujet>`.
- PR de lot vers `feature/<slug>`, fusionnée en merge commit par le lead dev ; PR finale vers la branche
  d'intégration, **jamais fusionnée par un agent**.
- Commits : <convention> ; aucune mention d'IA, aucun trailer.

## ci

- Check requis : `ci-ok`
- Déclenché sur toute PR. `gh` authentifié (`gh auth status`).

## budget

- Document : `<chemin du document des profils et du budget, ou devteam.agent.conf>`
- Jeton e2e : 1

## generes_migrations

- Générés : `<chemin>`, `<chemin>`
- En conflit sur un fichier généré : prendre un côté, `make generate`, puis `make check-generated`.
- Migrations : les modèles et migrations d'une app appartiennent à **un seul lot actif** ; un modèle partagé remonte
  dans un lot amont. `make migrations-check` à chaque fusion.

## taches_planifiees

Application de bureau Claude ouverte, machine éveillée, Docker lancé.

## stack_principale

Démarrage : `<commande>` ; vérification : `<commande>` (tous les services sains).

## notification

Outil `PushNotification` s'il est disponible dans la session, sinon une ligne `NOTIF …` dans
`.superpowers/sdd/<slug>/state.md`.

## plans

- Specs : `<dossier>` ; plans : `<dossier>/<slug>/<n>-<lot>.md` + `README.md` de la mission.
- Labels : `devteam:<slug>`, `lot:<id>`, `role:dev`, `role:testeur`, `role:planificateur`, `type:lot`, `type:ci`,
  `type:test`, `type:revue`, `etat:pret`, `etat:en-cours`, `etat:en-revue`, `etat:a-corriger`, `etat:bloque`,
  `revue:ok`.
