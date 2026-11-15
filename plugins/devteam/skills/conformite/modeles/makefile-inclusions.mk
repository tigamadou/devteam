# Lignes à ajouter à la fin du Makefile racine du projet.
-include make/devteam.mk
-include make/standard.mk
ifneq ($(wildcard devteam.agent.conf),)
-include make/devteam-agent.mk
endif
