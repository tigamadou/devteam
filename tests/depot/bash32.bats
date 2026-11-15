#!/usr/bin/env bats
# Les scripts tournent sous le bash 3.2 de macOS alors que les tests tournent sous bash 5.

load ../helpers/communs

scripts() { fichiers_depot | grep -E '\.(sh|bash)$' || true; }

@test "aucun script n'utilise une construction absente de bash 3.2" {
  local trouve=0 f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if grep -nE 'declare -A|mapfile|readarray|\$\{[a-zA-Z_]+(,,|\^\^)\}|&>>|coproc' "$DEPOT/$f"; then
      echo "dans $f"
      trouve=1
    fi
  done < <(scripts)
  [ "$trouve" -eq 0 ]
}

@test "tout script commence par le shebang et set -euo pipefail" {
  local mauvais=0 f
  while IFS= read -r f; do
    case "$f" in "" | *.bash) continue ;; esac
    if [ "$(head -1 "$DEPOT/$f")" != "#!/usr/bin/env bash" ] || ! grep -qx 'set -euo pipefail' "$DEPOT/$f"; then
      echo "en-tête manquant : $f"
      mauvais=1
    fi
  done < <(scripts)
  [ "$mauvais" -eq 0 ]
}

@test "aucun script livré ne coupe un tube par grep -q ou head (SIGPIPE fatal sous pipefail)" {
  local trouve=0 f
  while IFS= read -r f; do
    case "$f" in plugins/devteam/*.sh) ;; *) continue ;; esac
    if grep -nE '\|[[:space:]]*(grep[[:space:]]+-[a-zA-Z]*q|head)\b' "$DEPOT/$f"; then echo "dans $f"; trouve=1; fi
  done < <(scripts)
  [ "$trouve" -eq 0 ]
}
