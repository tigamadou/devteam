# devteam

Plugin [Claude Code](https://code.claude.com) pour mener une **mission** de développement non triviale avec une
équipe d'agents : découpage en lots à fichiers exclusifs, plans rédigés en parallèle, puis une tâche planifiée qui
orchestre l'exécution (un environnement par lot, revues, fusions, PR finale, jamais fusionnée par un agent).

## Installation

Pour soi, sur n'importe quelle machine :

```bash
claude plugin marketplace add tigamadou/devteam
claude plugin install devteam@devteam
```

Pour un projet : `/devteam:conformite` propose d'ajouter au `.claude/settings.json` du projet la déclaration de la
marketplace et du plugin. Chaque clone lance ensuite une fois :

```bash
claude plugin install devteam@devteam --scope project
```

## Utilisation

1. `/devteam:conformite` : diagnostique le projet par rapport au contrat de la méthode (neuf points : Docker
   uniquement, environnement d'agent, isolation des données, cibles standard, branches, CI à check unique, budget
   machine, fichiers générés et migrations, tâches planifiées), pose les questions nécessaires, génère avec votre
   accord ce qui se déduit du projet et rédige la spec et le plan du reste.
2. `/devteam:demarrer` : à partir d'une spec validée, découpe la mission en lots, fait rédiger les plans, puis crée
   la tâche planifiée qui la supervise.
3. `/devteam:mise-a-jour` : après une mise à jour du plugin, synchronise les fichiers du kit copiés dans le projet.

Le plugin ne commite ni ne pousse rien sans demande, et n'écrit aucun fichier du projet sans accord.

## Développement

```bash
make test             # tous les tests bats, en conteneur
make validate         # claude plugin validate
make verifier-public  # aucun détail personnel ni secret dans le dépôt
claude --plugin-dir plugins/devteam   # essayer le plugin sans l'installer
```

Spec et plan : [`docs/specs/`](docs/specs/), [`docs/plans/`](docs/plans/).
