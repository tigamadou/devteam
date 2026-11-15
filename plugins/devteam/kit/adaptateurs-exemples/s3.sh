#!/usr/bin/env bash
# Adaptateur d'exemple devteam : un bucket S3 (MinIO, RustFS…) par lot, créé par un conteneur aws-cli sur le réseau de
# la stack principale. Copier dans scripts/devteam-adaptateurs/ et ajuster. Ressource : s3:<bucket> (ex. s3:monprojet-{lot}).
# Variables lues : DEVTEAM_RESEAU_INFRA, DEVTEAM_S3_ENDPOINT (ex. http://minio:9000), DEVTEAM_S3_ACCESS_KEY,
# DEVTEAM_S3_SECRET_KEY (identifiants de développement de la stack locale), DEVTEAM_S3_IMAGE (défaut amazon/aws-cli:2.22.0).
set -euo pipefail

action="${1:-}" lot="${2:-}" bucket="${3:-}"
IMAGE="${DEVTEAM_S3_IMAGE:-amazon/aws-cli:2.22.0}"

case "$action" in variables | creer | liberer) ;; *) echo "Usage : $0 variables|creer|liberer <lot> <bucket>" >&2; exit 2 ;; esac
[[ "$bucket" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]] || { echo "s3 : nom de bucket invalide « $bucket »" >&2; exit 1; }

if [ "$action" != variables ]; then
  [ -n "${DEVTEAM_RESEAU_INFRA:-}" ] && [ -n "${DEVTEAM_S3_ENDPOINT:-}" ] ||
    { echo "s3 : DEVTEAM_RESEAU_INFRA et DEVTEAM_S3_ENDPOINT requis dans devteam.agent.conf" >&2; exit 1; }
fi

aws() {
  docker run --rm --network "$DEVTEAM_RESEAU_INFRA" \
    -e AWS_ACCESS_KEY_ID="${DEVTEAM_S3_ACCESS_KEY:-}" -e AWS_SECRET_ACCESS_KEY="${DEVTEAM_S3_SECRET_KEY:-}" \
    -e AWS_DEFAULT_REGION=us-east-1 "$IMAGE" --endpoint-url "$DEVTEAM_S3_ENDPOINT" "$@"
}

case "$action" in
  variables) echo "export S3_BUCKET=$bucket" ;;
  creer)
    if aws s3api head-bucket --bucket "$bucket" >/dev/null 2>&1; then
      echo "s3 : bucket $bucket déjà présent (réutilisé)"
    else
      aws s3 mb "s3://$bucket" >/dev/null
      echo "s3 : bucket $bucket créé (lot $lot)"
    fi
    ;;
  liberer) ;; # le bucket est conservé jusqu'au nettoyage final
esac
