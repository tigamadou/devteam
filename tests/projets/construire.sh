#!/usr/bin/env bash
# Construit un projet de démonstration générique pour les tests d'acceptation du plugin devteam.
#
#   construire.sh <vide|multi-depot|conforme|version-en-retard> <dossier>
#
# Le dossier ne doit pas exister. Aucun code tiré d'un projet réel : un service « api » sur une image alpine.
set -euo pipefail

usage() { echo "Usage : $0 <vide|multi-depot|conforme|version-en-retard> <dossier>" >&2; exit 2; }
[ $# -eq 2 ] || usage
nom="$1"
dossier="$2"
case "$nom" in vide | multi-depot | conforme | version-en-retard) ;; *) usage ;; esac
[ ! -e "$dossier" ] || { echo "construire.sh : $dossier existe déjà" >&2; exit 2; }

PLUGIN="$(cd "$(dirname "$0")/../../plugins/devteam" && pwd)"
KIT_SH="$PLUGIN/outils/kit.sh"
CIBLES="test-cible coverage-diff lint typecheck generate check-generated migrations-check e2e-fixtures e2e"

commit() { git -C "$dossier" add -A && git -C "$dossier" -c user.email=demo@example.com -c user.name=Demo commit -q -m "$1"; }

base() {
  mkdir -p "$dossier"
  git -C "$dossier" init -q -b development
  cat > "$dossier/compose.yml" <<'EOF'
services:
  api:
    image: alpine:3.20
    command: sleep infinity
EOF
  printf 'up:\n\tdocker compose up -d\n\ndown:\n\tdocker compose down\n' > "$dossier/Makefile"
  commit "init"
}

conforme() {
  base
  {
    printf '\nhelp: ## Aide\n\t@grep -hE "^[a-z-]+:.*## " $(MAKEFILE_LIST)\n'
    printf -- '-include make/devteam.mk\n-include make/standard.mk\n'
    printf 'ifneq ($(wildcard devteam.agent.conf),)\n-include make/devteam-agent.mk\nendif\n'
  } >> "$dossier/Makefile"
  mkdir -p "$dossier/make" "$dossier/.claude" "$dossier/tests"
  {
    echo "# Cibles standard du projet de démonstration (recettes factices)."
    for c in $CIBLES; do printf '%s:\n\t@true\n' "$c"; done
  } > "$dossier/make/standard.mk"
  echo 'services: {}' > "$dossier/compose.agent.yml"
  sed -e 's/=0 /=500 /' -e 's/^DEVTEAM_STACK_MO=0/DEVTEAM_STACK_MO=500/' -e 's/^DEVTEAM_RESSOURCES=.*/DEVTEAM_RESSOURCES=""/' \
    "$PLUGIN/kit/devteam.agent.conf.exemple" > "$dossier/devteam.agent.conf"
  printf '#!/usr/bin/env bash\nset -euo pipefail\n[ "${DB_NAME:-}" = "test_${AGENT_LOT:-}" ] || { echo "base de test de l agent attendue" >&2; exit 1; }\n' \
    > "$dossier/tests/garde-fou.sh"
  cat > "$dossier/.claude/devteam.projet.md" <<'EOF'
# Valeurs du projet pour devteam

## docker

Toutes les commandes passent par des cibles make qui lancent des conteneurs.

## agent_env

- Moteur devteam : `make agent-up`, `make agent-down`, `make agent-status`.
- « Pas de place » de `agent-up` : ligne `agent-env : pas de place : …`.

## isolation

- Ressources isolées par lot : base de test.
- Garde-fou : `tests/garde-fou.sh`

## cibles

Les neuf cibles du contrat, dans `make/standard.mk`.

## branches

- Intégration : `development`
- Commits : Conventional Commits.

## ci

- Check requis : `ci-ok`

## budget

- Document : `devteam.agent.conf`
- Jeton e2e : 1

## generes_migrations

- Générés : sans objet
- Migrations : un seul lot actif par modèle.

## taches_planifiees

Application de bureau ouverte, machine éveillée, Docker lancé.
EOF
  mkdir -p "$dossier/.github/workflows"
  sed 's/<integration>/development/' "$PLUGIN/skills/conformite/modeles/ci/devteam-ci.yml" > "$dossier/.github/workflows/devteam-ci.yml"
  cp "$PLUGIN/skills/conformite/modeles/settings.json" "$dossier/.claude/settings.json"
  "$KIT_SH" appliquer "$PLUGIN" "$dossier" >/dev/null
  commit "devteam"
}

case "$nom" in
  vide) base ;;
  multi-depot)
    base
    echo 'apps/' > "$dossier/.gitignore"
    mkdir -p "$dossier/apps/api" "$dossier/apps/web"
    git -C "$dossier/apps/api" init -q
    git -C "$dossier/apps/web" init -q
    commit "apps ignorées"
    ;;
  conforme) conforme ;;
  version-en-retard)
    # Kit appliqué depuis une copie du plugin en version 0.9.0
    ancien="$(mktemp -d)"
    cp -R "$PLUGIN/." "$ancien/"
    sed -i.bak 's/"version": *"[^"]*"/"version": "0.9.0"/' "$ancien/.claude-plugin/plugin.json"
    rm -f "$ancien/.claude-plugin/plugin.json.bak"
    PLUGIN="$ancien" KIT_SH="$ancien/outils/kit.sh" conforme
    rm -rf "$ancien"
    ;;
esac
echo "projet $nom construit dans $dossier"
