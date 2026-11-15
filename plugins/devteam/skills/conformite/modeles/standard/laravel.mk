# Référence seulement : chaque commande de make/standard.mk doit venir du projet (Makefile, CI, README) ou du
# développeur. Ne jamais copier ces lignes telles quelles. Exemple : Laravel + PHPUnit/Pest, service Compose « app ».
#
# APP := docker compose run --rm app
#
# test-cible:
# 	$(APP) php artisan test $(T)
# coverage-diff:
# 	$(APP) sh -c 'XDEBUG_MODE=coverage php artisan test --coverage-clover=coverage.xml && <outil de couverture du diff> --base=$(BASE)'
# lint:
# 	$(APP) vendor/bin/pint --test
# typecheck:
# 	$(APP) vendor/bin/phpstan analyse
# generate:
# 	@echo "sans objet si aucun fichier généré : le déclarer dans .claude/devteam.projet.md"
# check-generated:
# 	@echo "sans objet si aucun fichier généré"
# migrations-check:
# 	$(APP) php artisan migrate --pretend
# e2e-fixtures:
# 	$(APP) php artisan db:seed --class=E2eSeeder
# e2e:
# 	docker compose -f compose.yml -f compose.e2e.yml run --rm playwright
