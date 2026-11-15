# Questionnaire de mise en conformité

Lu par `/devteam:conformite`, étape 2. Les blocs se posent **dans l'ordre**, une question à la fois, et **seulement si
le projet n'y répond pas** : ce qui se déduit (colonne « déduit de ») est proposé au développeur pour qu'il le
corrige. Une réponse **bloquante** du bloc 0 arrête le questionnaire et ouvre la mission de mise en conformité
structurelle. Chaque réponse est consignée dans `.claude/devteam.projet.md` (ou dans la spec de mise en conformité
pour ce qui reste à construire) et n'est jamais reposée.

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
