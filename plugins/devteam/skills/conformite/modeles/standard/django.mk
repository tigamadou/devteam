# Référence seulement : chaque commande de make/standard.mk doit venir du projet (Makefile, CI, README) ou du
# développeur. Ne jamais copier ces lignes telles quelles. Exemple : Django + pytest, service Compose « api ».
#
# API := docker compose run --rm --no-deps api
#
# test-cible: ## Tests ciblés : make test-cible T="chemins"
# 	$(API) pytest $(T)
# coverage-diff: ## Couverture du code modifié par rapport à BASE
# 	$(API) sh -c 'pytest --cov --cov-report=xml && diff-cover coverage.xml --compare-branch=$(BASE) --fail-under=100'
# lint:
# 	$(API) ruff check .
# typecheck:
# 	$(API) mypy .
# generate: ## Schéma OpenAPI
# 	$(API) python manage.py spectacular --file openapi.yaml
# check-generated:
# 	$(MAKE) generate && git diff --exit-code -- openapi.yaml
# migrations-check:
# 	$(API) python manage.py makemigrations --check --dry-run
# e2e-fixtures:
# 	$(API) python manage.py loaddata e2e
# e2e:
# 	docker compose -f compose.yml -f compose.e2e.yml run --rm playwright
