# Dépôt du plugin devteam. `make help` pour la liste des cibles.
.DEFAULT_GOAL := help
.PHONY: help test validate verifier-public image-tests

IMAGE_TESTS := devteam-tests
SUITES := tests $(wildcard plugins/devteam/kit)

help: ## Affiche cette aide
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

image-tests:
	@docker build -q -t $(IMAGE_TESTS) tests >/dev/null

test: image-tests ## Lance tous les tests bats en conteneur
	docker run --rm -v "$(CURDIR)":/repo -w /repo $(IMAGE_TESTS) bats -r $(SUITES)

validate: ## Valide le plugin et la marketplace (claude plugin validate)
	claude plugin validate plugins/devteam
	claude plugin validate .

verifier-public: ## Vérifie qu'aucun détail personnel ni secret n'est dans les fichiers du dépôt
	@tests/depot/verifier-public.sh
