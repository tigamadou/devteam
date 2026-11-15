# Notes de version

## 1.0.0

Première version.

- Skills `/devteam:demarrer` (mission parallèle à partir d'une spec validée), `/devteam:conformite` (diagnostic,
  questionnaire, mise en conformité) et `/devteam:mise-a-jour` (synchronisation du kit, changement de version d'une
  mission en cours).
- Sept agents `devteam:surveillant`, `devteam:lead-dev`, `devteam:lead-qa`, `devteam:planificateur`,
  `devteam:developpeur`, `devteam:testeur`, `devteam:relecteur`.
- Outils `outils/diagnostic.sh` (contrat vérifié mécaniquement, structure du dépôt) et `outils/kit.sh` (copie
  versionnée du kit, état des fichiers, missions en cours, figeage de la version d'une mission).
- Kit copié dans les projets : `make/devteam.mk` (labels, périmètre, tests), scripts de périmètre et de labels ; pour
  les projets qui l'adoptent, moteur d'environnement d'agent (`agent-up`, `agent-down`, `agent-status`, budget
  mémoire, code 75 « pas de place ») et adaptateurs d'exemple (PostgreSQL, MySQL, Redis, S3, port, plafond).
