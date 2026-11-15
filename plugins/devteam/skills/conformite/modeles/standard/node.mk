# Référence seulement : chaque commande de make/standard.mk doit venir du projet (Makefile, CI, README) ou du
# développeur. Ne jamais copier ces lignes telles quelles. Exemple : Node (Vitest, ESLint, TypeScript, Playwright),
# service Compose « web ».
#
# WEB := docker compose run --rm --no-deps web
#
# test-cible:
# 	$(WEB) npx vitest run $(T)
# coverage-diff:
# 	$(WEB) sh -c 'npx vitest run --coverage --changed=$(BASE)'
# lint:
# 	$(WEB) npx eslint .
# typecheck:
# 	$(WEB) npx tsc --noEmit
# generate:
# 	$(WEB) npm run generate
# check-generated:
# 	$(MAKE) generate && git diff --exit-code -- src/generated
# migrations-check:
# 	@echo "sans objet si aucune base : le déclarer dans .claude/devteam.projet.md"
# e2e-fixtures:
# 	$(WEB) npm run seed:e2e
# e2e:
# 	docker compose -f compose.yml -f compose.e2e.yml run --rm playwright
