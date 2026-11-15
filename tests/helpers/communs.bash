# Aides communes des tests bats du dépôt devteam.

DEPOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN="$DEPOT/plugins/devteam"

# Fichiers du dépôt hors fichiers ignorés (suivis ou non encore commités).
fichiers_depot() {
  git -C "$DEPOT" ls-files --cached --others --exclude-standard
}

# fake_bin <nom> <corps> : faux binaire en tête du PATH, qui journalise « <nom> <args> » dans $CALLS_LOG puis exécute <corps>.
fake_bin() {
  local nom="$1" corps="${2:-exit 0}"
  FAKE_BIN="${FAKE_BIN:-$BATS_TEST_TMPDIR/bin}"
  CALLS_LOG="${CALLS_LOG:-$BATS_TEST_TMPDIR/calls.log}"
  mkdir -p "$FAKE_BIN"
  touch "$CALLS_LOG"
  {
    echo '#!/usr/bin/env bash'
    echo "echo \"$nom \$*\" >> \"$CALLS_LOG\""
    echo "$corps"
  } > "$FAKE_BIN/$nom"
  chmod +x "$FAKE_BIN/$nom"
  case ":$PATH:" in *":$FAKE_BIN:"*) ;; *) export PATH="$FAKE_BIN:$PATH" ;; esac
  export CALLS_LOG
}

assert_call() { grep -qE -- "$1" "$CALLS_LOG" || { echo "appel attendu absent : $1"; cat "$CALLS_LOG"; return 1; }; }
refute_call() { if grep -qE -- "$1" "$CALLS_LOG"; then echo "appel interdit présent : $1"; cat "$CALLS_LOG"; return 1; fi; }
assert_contient() { case "$output" in *"$1"*) ;; *) echo "sortie sans « $1 » :"; echo "$output"; return 1 ;; esac; }
refute_contient() { case "$output" in *"$1"*) echo "sortie avec « $1 » :"; echo "$output"; return 1 ;; *) ;; esac; }
