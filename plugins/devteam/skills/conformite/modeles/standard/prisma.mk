# Référence seulement : chaque commande de make/standard.mk doit venir du projet (Makefile, CI, README) ou du
# développeur. Ne jamais copier ces lignes telles quelles. Exemple : cibles propres à Prisma, service Compose « web »,
# à combiner avec node.mk.
#
# WEB := docker compose run --rm web
#
# generate: ## Client Prisma
# 	$(WEB) npx prisma generate
# check-generated:
# 	$(MAKE) generate && git diff --exit-code -- node_modules/.prisma prisma/generated
# migrations-check: ## Schéma et migrations alignés
# 	$(WEB) npx prisma migrate diff --from-migrations prisma/migrations --to-schema-datamodel prisma/schema.prisma --exit-code --shadow-database-url "$$SHADOW_DATABASE_URL"
