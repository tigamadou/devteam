#!/usr/bin/env bats
# Projets de démonstration génériques, construits à chaque test par tests/projets/construire.sh.

load ../helpers/communs

setup() {
  CONSTRUIRE="$DEPOT/tests/projets/construire.sh"
  DIAG="$PLUGIN/outils/diagnostic.sh"
  KIT_SH="$PLUGIN/outils/kit.sh"
  P="$BATS_TEST_TMPDIR/projet"
  fake_bin gh 'exit 0'
  fake_bin docker 'exit 0'
}

etat() { printf '%s\n' "$output" | awk -F '\t' -v n="$1" '$1 == n { print $3 }'; }
structure() { printf '%s\n' "$output" | awk -F '\t' '$1 == "structure" { print $2 }'; }

@test "vide : diagnostic en échec, points 2 3 4 6 7 non remplis, structure ok" {
  "$CONSTRUIRE" vide "$P"
  run "$DIAG" "$P"
  [ "$status" -eq 1 ]
  [ "$(structure)" = "ok" ]
  local n
  for n in 2 3 4 6 7; do [ "$(etat "$n")" != "rempli" ] || { echo "point $n rempli"; return 1; }; done
}

@test "multi-depot : structure bloquante" {
  "$CONSTRUIRE" multi-depot "$P"
  run "$DIAG" "$P"
  [ "$(structure)" = "bloquant" ]
  assert_contient "apps/api"
  assert_contient "apps/web"
}

@test "conforme : neuf points remplis, kit à jour" {
  "$CONSTRUIRE" conforme "$P"
  run "$DIAG" "$P"
  echo "$output"
  [ "$status" -eq 0 ]
  run "$KIT_SH" etat "$PLUGIN" "$P"
  [ "${lines[0]}" = "version-projet $("$KIT_SH" version "$PLUGIN") version-plugin $("$KIT_SH" version "$PLUGIN")" ]
  refute_contient "absent"
  refute_contient "a-mettre-a-jour"
  refute_contient "modifie-localement"
}

@test "conforme : les tests du kit copié passent dans le projet" {
  "$CONSTRUIRE" conforme "$P"
  run bats -r "$P/scripts/devteam"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "version-en-retard : fichiers à mettre à jour, puis à jour après appliquer" {
  "$CONSTRUIRE" version-en-retard "$P"
  run "$KIT_SH" etat "$PLUGIN" "$P"
  assert_contient "version-projet 0.9.0"
  assert_contient "a-mettre-a-jour make/devteam.mk"
  run "$KIT_SH" appliquer "$PLUGIN" "$P"
  [ "$status" -eq 0 ]
  run "$KIT_SH" etat "$PLUGIN" "$P"
  assert_contient "version-projet $("$KIT_SH" version "$PLUGIN")"
  refute_contient "a-mettre-a-jour"
}

@test "nom de projet inconnu ou dossier déjà existant : code 2" {
  run "$CONSTRUIRE" inconnu "$P"
  [ "$status" -eq 2 ]
  mkdir -p "$P"
  run "$CONSTRUIRE" vide "$P"
  [ "$status" -eq 2 ]
}
