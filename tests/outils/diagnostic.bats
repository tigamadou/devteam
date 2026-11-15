#!/usr/bin/env bats
# outils/diagnostic.sh : vérification mécanique des neuf points du contrat.

load ../helpers/communs

CIBLES="test-cible coverage-diff lint typecheck generate check-generated migrations-check e2e-fixtures e2e"

setup() {
  DIAG="$PLUGIN/outils/diagnostic.sh"
  PROJ="$BATS_TEST_TMPDIR/projet"
  mkdir -p "$PROJ"
  fake_bin gh 'exit "${FAKE_GH_RC:-0}"'
  fake_bin docker 'exit "${FAKE_DOCKER_RC:-0}"'
}

depot() { # crée le dépôt git du projet sur la branche development
  git -C "$PROJ" init -q -b development
  git -C "$PROJ" commit -q --allow-empty -m init
}

makefile_complet() {
  {
    echo 'help: ; @true'
    for c in $CIBLES agent-up agent-down agent-status; do echo "$c: ; @true"; done
  } > "$PROJ/Makefile"
}

fichier_projet() { # écrit un fichier projet complet ; les arguments « clé=ligne » remplacent une ligne lue
  mkdir -p "$PROJ/.claude" "$PROJ/tests" "$PROJ/docs"
  touch "$PROJ/tests/garde-fou.py" "$PROJ/docs/agents.md" "$PROJ/openapi.yaml"
  mkdir -p "$PROJ/.github/workflows"
  printf 'name: CI\non: pull_request\njobs:\n  ci-ok:\n    runs-on: ubuntu-latest\n' > "$PROJ/.github/workflows/ci.yml"
  cat > "$PROJ/.claude/devteam.projet.md" <<'EOF'
# Valeurs du projet

## docker

Tout passe par make.

## agent_env

- `make agent-up`, `make agent-down`, `make agent-status`.

## isolation

- Ressources isolées par lot : base, cache.
- Garde-fou : `tests/garde-fou.py`

## cibles

Les neuf cibles.

## branches

- Intégration : `development`

## ci

- Check requis : `ci-ok`

## budget

- Document : `docs/agents.md`
- Jeton e2e : 1

## generes_migrations

- Générés : `openapi.yaml`

## taches_planifiees

Application ouverte.
EOF
}

etat() { printf '%s\n' "$output" | awk -F '\t' -v n="$1" '$1 == n { print $3 }'; }
structure() { printf '%s\n' "$output" | awk -F '\t' '$1 == "structure" { print $2 }'; }

@test "projet vide : aucun point rempli, code 1" {
  depot
  echo 'up: ; @true' > "$PROJ/Makefile"
  run "$DIAG" "$PROJ"
  [ "$status" -eq 1 ]
  [ "$(structure)" = "ok" ]
  local n
  for n in 1 2 3 4 5 6 7 8 9; do
    [ "$(etat "$n")" != "rempli" ] || { echo "point $n rempli"; return 1; }
  done
  [ "$(printf '%s\n' "$output" | grep -c '^[1-9]	')" -eq 9 ]
}

@test "projet complet : neuf points remplis, structure ok, code 0" {
  depot
  makefile_complet
  fichier_projet
  run "$DIAG" "$PROJ"
  echo "$output"
  [ "$status" -eq 0 ]
  [ "$(structure)" = "ok" ]
  local n
  for n in 1 2 3 4 5 6 7 8 9; do
    [ "$(etat "$n")" = "rempli" ] || { echo "point $n : $(etat "$n")"; echo "$output"; return 1; }
  done
}

@test "cible déclarée sans objet et absente du Makefile : point 4 rempli" {
  depot
  makefile_complet
  fichier_projet
  sed -i '/^generate:/d' "$PROJ/Makefile"
  run "$DIAG" "$PROJ"
  [ "$(etat 4)" = "partiel" ]
  sed -i 's/^Les neuf cibles.$/- generate : sans objet (aucun fichier généré)/' "$PROJ/.claude/devteam.projet.md"
  run "$DIAG" "$PROJ"
  [ "$(etat 4)" = "rempli" ]
}

@test "gh non authentifié : point 6 partiel" {
  depot
  makefile_complet
  fichier_projet
  FAKE_GH_RC=1 run "$DIAG" "$PROJ"
  [ "$(etat 6)" = "partiel" ]
  [ "$status" -eq 1 ]
}

@test "docker muet : point 9 partiel" {
  depot
  makefile_complet
  fichier_projet
  FAKE_DOCKER_RC=1 run "$DIAG" "$PROJ"
  [ "$(etat 9)" = "partiel" ]
}

@test "dépôt git imbriqué ignoré par .gitignore : structure bloquante" {
  depot
  makefile_complet
  fichier_projet
  echo 'apps/' > "$PROJ/.gitignore"
  mkdir -p "$PROJ/apps/api"
  git -C "$PROJ/apps/api" init -q
  run "$DIAG" "$PROJ"
  [ "$(structure)" = "bloquant" ]
  [ "$status" -eq 1 ]
  assert_contient "apps/api"
}

@test "sous-modules déclarés : structure bloquante" {
  depot
  touch "$PROJ/.gitmodules"
  run "$DIAG" "$PROJ"
  [ "$(structure)" = "bloquant" ]
}

@test "branche d'intégration absente : point 5 partiel, sans erreur bash" {
  depot
  makefile_complet
  fichier_projet
  sed -i 's/`development`/`integration`/' "$PROJ/.claude/devteam.projet.md"
  run "$DIAG" "$PROJ"
  [ "$(etat 5)" = "partiel" ]
  refute_contient "unbound variable"
}

@test "branche d'intégration présente seulement sur origin : point 5 rempli" {
  depot
  makefile_complet
  fichier_projet
  git -C "$PROJ" update-ref refs/remotes/origin/integration HEAD
  sed -i 's/`development`/`integration`/' "$PROJ/.claude/devteam.projet.md"
  run "$DIAG" "$PROJ"
  [ "$(etat 5)" = "rempli" ]
}

@test "dossier qui n'est pas un dépôt git : point 5 partiel, pas de plantage" {
  makefile_complet
  fichier_projet
  run "$DIAG" "$PROJ"
  [ "$(etat 5)" = "partiel" ]
  [ "$(printf '%s\n' "$output" | grep -c '^[1-9]	')" -eq 9 ]
}

@test "garde-fou cité mais inexistant : point 3 partiel" {
  depot
  makefile_complet
  fichier_projet
  rm "$PROJ/tests/garde-fou.py"
  run "$DIAG" "$PROJ"
  [ "$(etat 3)" = "partiel" ]
}

@test "fichier généré cité mais absent : point 8 partiel ; « sans objet » : rempli" {
  depot
  makefile_complet
  fichier_projet
  rm "$PROJ/openapi.yaml"
  run "$DIAG" "$PROJ"
  [ "$(etat 8)" = "partiel" ]
  sed -i 's/^- Générés : .*/- Générés : sans objet/' "$PROJ/.claude/devteam.projet.md"
  run "$DIAG" "$PROJ"
  [ "$(etat 8)" = "rempli" ]
}

@test "jeton e2e absent : point 7 partiel" {
  depot
  makefile_complet
  fichier_projet
  sed -i '/^- Jeton e2e/d' "$PROJ/.claude/devteam.projet.md"
  run "$DIAG" "$PROJ"
  [ "$(etat 7)" = "partiel" ]
}

@test "projet sous un chemin avec espaces et accents : mêmes résultats" {
  PROJ="$BATS_TEST_TMPDIR/Mon projet/Application Support é"
  mkdir -p "$PROJ"
  depot
  makefile_complet
  fichier_projet
  run "$DIAG" "$PROJ"
  [ "$status" -eq 0 ]
}

@test "argument manquant ou dossier inexistant : code 2" {
  run "$DIAG"
  [ "$status" -eq 2 ]
  run "$DIAG" "$BATS_TEST_TMPDIR/absent"
  [ "$status" -eq 2 ]
}

@test "section très longue : lue entièrement, sans faux négatif dû à un SIGPIPE" {
  depot
  makefile_complet
  fichier_projet
  awk '{ print } /^- Garde-fou/ { for (i = 0; i < 20000; i++) print "- ligne de remplissage " i }' \
    "$PROJ/.claude/devteam.projet.md" > "$PROJ/p.md"
  mv "$PROJ/p.md" "$PROJ/.claude/devteam.projet.md"
  sed -i 's/^Les neuf cibles.$/Les neuf cibles.\n- generate : sans objet (aucun)/' "$PROJ/.claude/devteam.projet.md"
  awk '{ print } /^- generate : sans objet/ { for (i = 0; i < 20000; i++) print "- autre ligne " i }' \
    "$PROJ/.claude/devteam.projet.md" > "$PROJ/p.md"
  mv "$PROJ/p.md" "$PROJ/.claude/devteam.projet.md"
  sed -i '/^generate:/d' "$PROJ/Makefile"
  run "$DIAG" "$PROJ"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "aucun workflow ne définit le job du check requis : point 6 partiel ; avec le job : rempli" {
  depot
  makefile_complet
  fichier_projet
  rm -rf "$PROJ/.github"
  run "$DIAG" "$PROJ"
  [ "$(etat 6)" = "partiel" ]
  assert_contient "ci-ok"
  mkdir -p "$PROJ/.github/workflows"
  printf 'name: CI\non: pull_request\njobs:\n  lint:\n    runs-on: ubuntu-latest\n' > "$PROJ/.github/workflows/ci.yaml"
  run "$DIAG" "$PROJ"
  [ "$(etat 6)" = "partiel" ]
  printf '  ci-ok:\n    runs-on: ubuntu-latest\n' >> "$PROJ/.github/workflows/ci.yaml"
  run "$DIAG" "$PROJ"
  [ "$(etat 6)" = "rempli" ]
}
