#!/usr/bin/env bash
# Adaptateur d'exemple devteam : une base MySQL ou MariaDB par lot dans le service de la stack principale.
# Copier dans scripts/devteam-adaptateurs/ et ajuster. Ressource : mysql:<nom de base> (ex. mysql:monprojet_{lot}).
# Variables lues : DEVTEAM_PROJET_PRINCIPAL, DEVTEAM_MYSQL_SERVICE (défaut mysql). Le mot de passe root est celui du
# conteneur (variable MYSQL_ROOT_PASSWORD de son environnement), jamais écrit ici.
set -euo pipefail

action="${1:-}" lot="${2:-}" nom="${3:-}"
SERVICE="${DEVTEAM_MYSQL_SERVICE:-mysql}"

case "$action" in variables | creer | liberer) ;; *) echo "Usage : $0 variables|creer|liberer <lot> <nom de base>" >&2; exit 2 ;; esac
[[ "$nom" =~ ^[a-z0-9_]{1,64}$ ]] || { echo "mysql : nom de base invalide « $nom » (a-z, 0-9, _ ; 64 caractères au plus)" >&2; exit 1; }

conteneur() {
  local c
  c="$(docker ps --filter "label=com.docker.compose.project=$DEVTEAM_PROJET_PRINCIPAL" \
    --filter "label=com.docker.compose.service=$SERVICE" --filter status=running --format '{{.Names}}' | awk 'NR == 1')"
  [ -n "$c" ] || { echo "mysql : service $SERVICE absent de la stack principale" >&2; exit 1; }
  echo "$c"
}

case "$action" in
  variables) echo "export DB_NAME=$nom" ;;
  creer)
    c="$(conteneur)"
    docker exec "$c" sh -c "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" -e 'CREATE DATABASE IF NOT EXISTS \`$nom\`'"
    echo "mysql : base $nom prête (lot $lot)"
    ;;
  liberer) ;; # la base est conservée jusqu'au nettoyage final
esac
