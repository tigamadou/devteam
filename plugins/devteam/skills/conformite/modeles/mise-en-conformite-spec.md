# {{projet}} : mise en conformité avec le contrat devteam

> Rédigée par `/devteam:conformite` le {{date}} ; à valider par le développeur avant exécution. Elle s'exécute de
> façon **séquentielle** (le contrat n'étant pas rempli, une mission parallèle est impossible), par exemple avec
> `superpowers:subagent-driven-development`, à partir du plan joint ({{plan}}).

## 1. Diagnostic de départ

{{tableau_du_diagnostic}}

## 2. Ce qui reste à construire, et pourquoi

Une sous-section par point non rempli après la génération directe (typiquement 2, 3 et 7, et tout préalable de
structure) : ce que dit le contrat, ce que le projet a aujourd'hui, ce qui manque.

### Structure (si bloquante)

{{decision_du_bloc_0}} (monorepo, mission limitée à un dépôt, ou greffe sur une refonte en cours) : étapes,
historique git à conserver, CI à unifier, risques.

### Point 2 : environnement d'agent

- Moteur : celui du kit devteam (`scripts/devteam/agent-env/`, `make/devteam-agent.mk`, `devteam.agent.conf`) ou
  l'environnement propre au projet ; raison du choix.
- Profils : {{profils}} et les services Compose de chacun.
- `compose.agent.yml` : services applicatifs de l'agent sur le réseau d'infrastructure de la stack principale, sans
  port fixe (ou port de l'adaptateur `port`), noms de conteneurs non figés.

### Point 3 : isolation des données

| Ressource | Isolation par lot | Adaptateur |
| --- | --- | --- |
| {{ressource}} | {{isolation}} | {{adaptateur}} |

Garde-fou : {{fichier_du_garde_fou}} refuse de lancer les tests si la base n'est pas la base de test de l'agent
(nom attendu, dérivé de `AGENT_LOT`).

### Point 7 : budget machine

Méthode de mesure : chaque profil lancé seul, en régime établi, puis pendant ses commandes les plus lourdes (tests,
typecheck, e2e) ; valeur retenue = pic observé arrondi. Les chiffres vont dans `devteam.agent.conf` (ou le document
des profils), jamais ailleurs.

## 3. Hors périmètre

Ce que la mise en conformité ne touche pas (code applicatif, déploiement, production).

## 4. Critère de fin

`bash <plugin>/outils/diagnostic.sh <projet>` sort en 0 (neuf points `rempli`, structure `ok`), et
`/devteam:conformite` ne propose plus rien à écrire.
