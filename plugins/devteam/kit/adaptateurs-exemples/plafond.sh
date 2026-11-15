#!/usr/bin/env bash
# Adaptateur d'exemple devteam : plafond fixe d'environnements d'agent simultanés, en plus du budget mémoire.
# Copier dans scripts/devteam-adaptateurs/. Ressource : plafond:<nombre maximal> (ex. plafond:3). Aucune variable écrite.
set -euo pipefail

action="${1:-}" plafond="${3:-}"
EX_PAS_DE_PLACE=75

case "$action" in variables | creer | liberer) ;; *) echo "Usage : $0 variables|creer|liberer <lot> <nombre maximal>" >&2; exit 2 ;; esac
[[ "$plafond" =~ ^[1-9][0-9]*$ ]] || { echo "plafond : nombre invalide « $plafond »" >&2; exit 1; }
[ "$action" = variables ] || exit 0
actifs="$(printf '%s\n' "${DEVTEAM_ENVS_ACTIFS:-}" | grep -c . || true)"
if [ "$actifs" -ge "$plafond" ]; then
  echo "plafond : $actifs environnements actifs sur $plafond" >&2
  exit "$EX_PAS_DE_PLACE"
fi
