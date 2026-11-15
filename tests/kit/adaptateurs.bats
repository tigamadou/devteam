#!/usr/bin/env bats
# Adaptateurs d'exemple du moteur (kit/adaptateurs-exemples) et cibles make/devteam-agent.mk.

load ../helpers/communs

AD="$PLUGIN/kit/adaptateurs-exemples"

setup() {
  E="$BATS_TEST_TMPDIR/envs"
  mkdir -p "$E"
  # Faux docker : ps renvoie un conteneur ; exec psql répond FAKE_PG_EXISTE à la requête d'existence
  fake_bin docker '
case "$1" in
  ps) echo "conteneur-1" ;;
  exec) case "$*" in *"SELECT 1 FROM pg_database"*) echo "${FAKE_PG_EXISTE:-}" ;; esac ;;
  run) case "$*" in *head-bucket*) exit "${FAKE_BUCKET_ABSENT:-0}" ;; esac ;;
esac
exit 0'
  export DEVTEAM_PROJET_PRINCIPAL=mp DEVTEAM_ENVS_ACTIFS="" DEVTEAM_ENV_LOT=""
}

# env_lot <nom> <lignes…> : écrit un .agent.env et renvoie son chemin
env_lot() {
  local f="$E/$1.env"
  shift
  printf '%s\n' "$@" > "$f"
  echo "$f"
}

@test "redis variables sans autre lot : premier numéro 2" {
  run "$AD/redis.sh" variables l1 1
  [ "$status" -eq 0 ]
  [ "$output" = "export REDIS_DB_1=2" ]
}

@test "redis variables : numéros pris par les autres lots évités, deux numéros demandés" {
  DEVTEAM_ENVS_ACTIFS="$(env_lot a 'export REDIS_DB_1=2')
$(env_lot b 'export REDIS_DB_1=3')"
  run "$AD/redis.sh" variables l1 2
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "export REDIS_DB_1=4" ]
  [ "${lines[1]}" = "export REDIS_DB_2=5" ]
}

@test "redis variables : reprise d'un lot, ses numéros gardés s'ils sont libres" {
  DEVTEAM_ENV_LOT="$(env_lot moi 'export REDIS_DB_1=9')"
  run "$AD/redis.sh" variables l1 1
  [ "$output" = "export REDIS_DB_1=9" ]
}

@test "redis variables : tous les numéros pris, code 75" {
  local i l=""
  for i in 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do l="$l$(env_lot "n$i" "export REDIS_DB_1=$i")
"; done
  DEVTEAM_ENVS_ACTIFS="$l"
  run "$AD/redis.sh" variables l1 1
  [ "$status" -eq 75 ]
}

@test "redis liberer : FLUSHDB sur ses numéros" {
  DEVTEAM_ENV_LOT="$(env_lot moi 'export REDIS_DB_1=4' 'export REDIS_DB_2=5')"
  run "$AD/redis.sh" liberer l1 2
  [ "$status" -eq 0 ]
  assert_call 'docker exec conteneur-1 redis-cli -n 4 FLUSHDB'
  assert_call 'docker exec conteneur-1 redis-cli -n 5 FLUSHDB'
}

@test "redis liberer : numéro hors 2..15 refusé, aucun FLUSHDB" {
  DEVTEAM_ENV_LOT="$(env_lot moi 'export REDIS_DB_1=0')"
  run "$AD/redis.sh" liberer l1 1
  [ "$status" -eq 1 ]
  refute_call 'FLUSHDB'
}

@test "port variables : premier port libre de la plage" {
  DEVTEAM_ENVS_ACTIFS="$(env_lot a 'export AGENT_PORT=4100')"
  run "$AD/port.sh" variables l1 4100-4101
  [ "$status" -eq 0 ]
  [ "$output" = "export AGENT_PORT=4101" ]
}

@test "port variables : plage pleine, code 75" {
  DEVTEAM_ENVS_ACTIFS="$(env_lot a 'export AGENT_PORT=4100')
$(env_lot b 'export AGENT_PORT=4101')"
  run "$AD/port.sh" variables l1 4100-4101
  [ "$status" -eq 75 ]
}

@test "port variables : plage invalide, code 1" {
  run "$AD/port.sh" variables l1 abc
  [ "$status" -eq 1 ]
}

@test "plafond variables : plafond atteint, code 75 ; sous le plafond, aucune variable" {
  DEVTEAM_ENVS_ACTIFS="$(env_lot a 'export AGENT_LOT=a')
$(env_lot b 'export AGENT_LOT=b')"
  run "$AD/plafond.sh" variables l1 2
  [ "$status" -eq 75 ]
  run "$AD/plafond.sh" variables l1 3
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "postgres creer : CREATE DATABASE si la base est absente" {
  run "$AD/postgres.sh" creer l1 mp_l1
  [ "$status" -eq 0 ]
  assert_call 'docker exec conteneur-1 psql .*CREATE DATABASE "mp_l1"'
}

@test "postgres creer : base présente, aucune création" {
  FAKE_PG_EXISTE=1 run "$AD/postgres.sh" creer l1 mp_l1
  [ "$status" -eq 0 ]
  refute_call 'CREATE DATABASE'
}

@test "postgres : nom de base invalide refusé avant tout appel docker" {
  run "$AD/postgres.sh" creer l1 'x"; DROP DATABASE y; --'
  [ "$status" -eq 1 ]
  refute_call '^docker '
}

@test "postgres variables : DB_NAME" {
  run "$AD/postgres.sh" variables l1 mp_l1
  [ "$output" = "export DB_NAME=mp_l1" ]
}

@test "mysql creer : CREATE DATABASE IF NOT EXISTS" {
  run "$AD/mysql.sh" creer l1 mp_l1
  [ "$status" -eq 0 ]
  assert_call 'docker exec conteneur-1 sh -c .*CREATE DATABASE IF NOT EXISTS'
}

@test "s3 creer : bucket absent créé, bucket présent réutilisé" {
  export DEVTEAM_RESEAU_INFRA=mp-infra DEVTEAM_S3_ENDPOINT=http://s3:9000
  FAKE_BUCKET_ABSENT=1 run "$AD/s3.sh" creer l1 mp-l1
  [ "$status" -eq 0 ]
  assert_call 'docker run .* s3 mb s3://mp-l1'
  : > "$CALLS_LOG"
  run "$AD/s3.sh" creer l1 mp-l1
  refute_call ' mb '
}

@test "s3 : réseau ou point d'accès absent, erreur explicite" {
  run "$AD/s3.sh" creer l1 mp-l1
  [ "$status" -eq 1 ]
  assert_contient "DEVTEAM_RESEAU_INFRA"
}

@test "action inconnue : code 2 pour chaque adaptateur" {
  local a
  for a in postgres mysql redis s3 port plafond; do
    run "$AD/$a.sh" inconnue l1 x
    [ "$status" -eq 2 ] || { echo "$a : $status"; return 1; }
  done
}

@test "devteam-agent.mk : cibles trouvées par make -n, usage sans variable" {
  local mk="$PLUGIN/kit/make/devteam-agent.mk"
  run make -n -f "$mk" agent-up LOT=x PROFIL=web BASE=y
  [ "$status" -eq 0 ]
  run make -n -f "$mk" agent-down LOT=x
  [ "$status" -eq 0 ]
  run make -n -f "$mk" agent-status
  [ "$status" -eq 0 ]
  run make -s -f "$mk" agent-up
  [ "$status" -ne 0 ]
  assert_contient "Usage : make agent-up"
}

@test "redis liberer : numéro tenu par un autre lot actif, refus sans aucun FLUSHDB" {
  DEVTEAM_ENV_LOT="$(env_lot moi 'export REDIS_DB_1=4')"
  DEVTEAM_ENVS_ACTIFS="$(env_lot autre 'export REDIS_DB_1=4')"
  run "$AD/redis.sh" liberer l1 1
  [ "$status" -eq 1 ]
  refute_call 'FLUSHDB'
}
