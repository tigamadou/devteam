#!/usr/bin/env bash
# Cherche dans les fichiers du dépôt (suivis ou non encore commités, hors fichiers ignorés) les motifs interdits dans un
# dépôt public : ceux de tests/depot/motifs-publics.txt et ceux de .interdits.local (non versionné, une expression
# étendue par ligne). Usage : verifier-public.sh [dépôt]. Sorties : 0 rien trouvé, 1 correspondances listées.
set -euo pipefail

depot="$(cd "${1:-$(dirname "$0")/../..}" && pwd)"
motifs="$(mktemp)"
trap 'rm -f "$motifs"' EXIT
grep -vE '^[[:space:]]*(#|$)' "$depot/tests/depot/motifs-publics.txt" > "$motifs"
[ ! -f "$depot/.interdits.local" ] || grep -vE '^[[:space:]]*(#|$)' "$depot/.interdits.local" >> "$motifs" || true

trouve=0
while IFS= read -r f; do
  case "$f" in tests/depot/motifs-publics.txt) continue ;; esac
  [ -f "$depot/$f" ] || continue
  if grep -nIE -f "$motifs" "$depot/$f" > /dev/null; then
    grep -nIE -f "$motifs" "$depot/$f" | sed "s|^|$f:|"
    trouve=1
  fi
done < <(git -C "$depot" ls-files --cached --others --exclude-standard)
if [ "$trouve" = 1 ]; then
  echo "verifier-public : motifs interdits trouvés (ci-dessus)" >&2
  exit 1
fi
echo "verifier-public : rien à signaler"
