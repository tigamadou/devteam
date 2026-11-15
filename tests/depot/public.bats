#!/usr/bin/env bats
# make verifier-public : aucun détail personnel ni secret dans les fichiers du dépôt public.

load ../helpers/communs

setup() {
  COPIE="$BATS_TEST_TMPDIR/depot"
  cp -R "$DEPOT" "$COPIE"
  rm -f "$COPIE/.interdits.local" "$COPIE/.sources.local"
  V="$COPIE/tests/depot/verifier-public.sh"
}

@test "dépôt propre : code 0" {
  run "$V" "$COPIE"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "dossier personnel macOS dans un fichier : code 1, fichier listé" {
  printf 'chemin %s\n' "/Us""ers/quelquun/projet" > "$COPIE/docs/fuite.md"
  run "$V" "$COPIE"
  [ "$status" -eq 1 ]
  assert_contient "docs/fuite.md"
}

@test "jeton GitHub dans un fichier : code 1" {
  printf 'jeton %s\n' "ghp""_abcdefghijklmnopqrstuvwxyz0123" > "$COPIE/docs/fuite.md"
  run "$V" "$COPIE"
  [ "$status" -eq 1 ]
}

@test "motif de .interdits.local trouvé : code 1" {
  echo "projetsecret" > "$COPIE/.interdits.local"
  echo "on parle de projetsecret ici" > "$COPIE/docs/fuite.md"
  run "$V" "$COPIE"
  [ "$status" -eq 1 ]
  assert_contient "docs/fuite.md"
}

@test "les fichiers ignorés par git ne sont pas examinés" {
  mkdir -p "$COPIE/.superpowers"
  printf '%s\n' "/Us""ers/x" > "$COPIE/.superpowers/note.md"
  run "$V" "$COPIE"
  [ "$status" -eq 0 ]
}
