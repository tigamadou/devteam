#!/usr/bin/env bats
# outils/kit.sh : copie versionnée du kit dans un projet.

load ../helpers/communs

ENTETE='# devteam {{version}} : fichier du kit, ne pas modifier ici'

setup() {
  KIT_SH="$PLUGIN/outils/kit.sh"
  PLUG="$BATS_TEST_TMPDIR/plugin"
  PROJ="$BATS_TEST_TMPDIR/projet"
  mkdir -p "$PLUG/.claude-plugin" "$PLUG/kit/make" "$PLUG/kit/scripts/devteam" \
    "$PLUG/skills/demarrer" "$PLUG/skills/commun" "$PROJ"
  version_plugin 1.0.0
  printf '# commentaire\nbase make/x.mk\nagent scripts/devteam/a.sh\n' > "$PLUG/kit/MANIFEST"
  printf '%s\nx: ; @true\n' "$ENTETE" > "$PLUG/kit/make/x.mk"
  printf '#!/usr/bin/env bash\n%s\nset -euo pipefail\necho a\n' "$ENTETE" > "$PLUG/kit/scripts/devteam/a.sh"
  chmod +x "$PLUG/kit/scripts/devteam/a.sh"
  echo "# Méthode" > "$PLUG/skills/demarrer/SKILL.md"
  echo "# Contrat" > "$PLUG/skills/commun/contrat.md"
}

version_plugin() {
  printf '{\n  "name": "devteam",\n  "version": "%s",\n  "description": "x"\n}\n' "$1" > "$PLUG/.claude-plugin/plugin.json"
}

statut() { printf '%s\n' "$output" | awk -v c="$1" '$2 == c { print $1 }'; }

@test "version : lit la version de plugin.json" {
  run "$KIT_SH" version "$PLUG"
  [ "$status" -eq 0 ]
  [ "$output" = "1.0.0" ]
}

@test "version : garde un suffixe de pré-version tel quel" {
  version_plugin 1.1.0-rc.1
  run "$KIT_SH" version "$PLUG"
  [ "$output" = "1.1.0-rc.1" ]
}

@test "etat sur projet vide : aucune version, fichiers base absents, pas de ligne agent" {
  run "$KIT_SH" etat "$PLUG" "$PROJ"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "version-projet aucune version-plugin 1.0.0" ]
  [ "$(statut make/x.mk)" = "absent" ]
  refute_contient "scripts/devteam/a.sh"
}

@test "etat : la ligne agent apparaît si devteam.agent.conf existe" {
  touch "$PROJ/devteam.agent.conf"
  run "$KIT_SH" etat "$PLUG" "$PROJ"
  [ "$(statut scripts/devteam/a.sh)" = "absent" ]
}

@test "appliquer puis etat : tout à jour, version substituée, script exécutable" {
  touch "$PROJ/devteam.agent.conf"
  run "$KIT_SH" appliquer "$PLUG" "$PROJ"
  [ "$status" -eq 0 ]
  run "$KIT_SH" etat "$PLUG" "$PROJ"
  [ "${lines[0]}" = "version-projet 1.0.0 version-plugin 1.0.0" ]
  [ "$(statut make/x.mk)" = "a-jour" ]
  [ "$(statut scripts/devteam/a.sh)" = "a-jour" ]
  grep -qx '# devteam 1.0.0 : fichier du kit, ne pas modifier ici' "$PROJ/make/x.mk"
  [ -x "$PROJ/scripts/devteam/a.sh" ]
  grep -q '^version 1.0.0$' "$PROJ/scripts/devteam/VERSION"
}

@test "appliquer deux fois : même résultat, code 0" {
  "$KIT_SH" appliquer "$PLUG" "$PROJ"
  cp "$PROJ/scripts/devteam/VERSION" "$BATS_TEST_TMPDIR/v1"
  run "$KIT_SH" appliquer "$PLUG" "$PROJ"
  [ "$status" -eq 0 ]
  diff "$BATS_TEST_TMPDIR/v1" "$PROJ/scripts/devteam/VERSION"
}

@test "fichier copié supprimé : absent, puis recopié par appliquer" {
  "$KIT_SH" appliquer "$PLUG" "$PROJ"
  rm "$PROJ/make/x.mk"
  run "$KIT_SH" etat "$PLUG" "$PROJ"
  [ "$(statut make/x.mk)" = "absent" ]
  "$KIT_SH" appliquer "$PLUG" "$PROJ"
  [ -f "$PROJ/make/x.mk" ]
}

@test "fichier copié modifié : modifie-localement, appliquer sur ce chemin sort en 4 sans rien écrire" {
  "$KIT_SH" appliquer "$PLUG" "$PROJ"
  echo "# ajout local" >> "$PROJ/make/x.mk"
  cp "$PROJ/make/x.mk" "$BATS_TEST_TMPDIR/local"
  run "$KIT_SH" etat "$PLUG" "$PROJ"
  [ "$(statut make/x.mk)" = "modifie-localement" ]
  run "$KIT_SH" appliquer "$PLUG" "$PROJ" make/x.mk
  [ "$status" -eq 4 ]
  diff "$BATS_TEST_TMPDIR/local" "$PROJ/make/x.mk"
}

@test "appliquer sans chemin ne touche pas un fichier modifié localement" {
  "$KIT_SH" appliquer "$PLUG" "$PROJ"
  echo "# ajout local" >> "$PROJ/make/x.mk"
  cp "$PROJ/make/x.mk" "$BATS_TEST_TMPDIR/local"
  version_plugin 1.1.0
  run "$KIT_SH" appliquer "$PLUG" "$PROJ"
  [ "$status" -eq 0 ]
  diff "$BATS_TEST_TMPDIR/local" "$PROJ/make/x.mk"
}

@test "nouvelle version du plugin : a-mettre-a-jour, puis a-jour après appliquer" {
  "$KIT_SH" appliquer "$PLUG" "$PROJ"
  version_plugin 1.1.0
  echo "y: ; @true" >> "$PLUG/kit/make/x.mk"
  run "$KIT_SH" etat "$PLUG" "$PROJ"
  [ "${lines[0]}" = "version-projet 1.0.0 version-plugin 1.1.0" ]
  [ "$(statut make/x.mk)" = "a-mettre-a-jour" ]
  "$KIT_SH" appliquer "$PLUG" "$PROJ"
  run "$KIT_SH" etat "$PLUG" "$PROJ"
  [ "${lines[0]}" = "version-projet 1.1.0 version-plugin 1.1.0" ]
  [ "$(statut make/x.mk)" = "a-jour" ]
  grep -q '^y:' "$PROJ/make/x.mk"
}

@test "mission en cours : appliquer sort en 3 ; mission terminée : appliquer passe" {
  mkdir -p "$PROJ/.superpowers/sdd/m1"
  printf 'Phase: lots\n' > "$PROJ/.superpowers/sdd/m1/state.md"
  run "$KIT_SH" appliquer "$PLUG" "$PROJ"
  [ "$status" -eq 3 ]
  [ ! -f "$PROJ/make/x.mk" ]
  echo DONE >> "$PROJ/.superpowers/sdd/m1/state.md"
  run "$KIT_SH" appliquer "$PLUG" "$PROJ"
  [ "$status" -eq 0 ]
}

@test "mission-en-cours : 0 et le slug si une mission tourne, 1 sinon" {
  run "$KIT_SH" mission-en-cours "$PROJ"
  [ "$status" -eq 1 ]
  mkdir -p "$PROJ/.superpowers/sdd/m2"
  echo "Phase: lots" > "$PROJ/.superpowers/sdd/m2/state.md"
  run "$KIT_SH" mission-en-cours "$PROJ"
  [ "$status" -eq 0 ]
  [ "$output" = "m2" ]
}

@test "figer : copie méthode et contrat, une seule ligne de version après deux appels" {
  "$KIT_SH" figer "$PLUG" "$PROJ" m3
  version_plugin 1.2.0
  run "$KIT_SH" figer "$PLUG" "$PROJ" m3
  [ "$status" -eq 0 ]
  [ "$(cat "$PROJ/.superpowers/sdd/m3/kit/methode.md")" = "# Méthode" ]
  [ "$(cat "$PROJ/.superpowers/sdd/m3/kit/contrat.md")" = "# Contrat" ]
  [ "$(grep -c '^Version devteam:' "$PROJ/.superpowers/sdd/m3/state.md")" -eq 1 ]
  grep -qx 'Version devteam: 1.2.0' "$PROJ/.superpowers/sdd/m3/state.md"
}

@test "figer garde le reste de state.md" {
  mkdir -p "$PROJ/.superpowers/sdd/m4"
  printf 'Phase: lots\nrelances 12 1/2\n' > "$PROJ/.superpowers/sdd/m4/state.md"
  "$KIT_SH" figer "$PLUG" "$PROJ" m4
  grep -qx 'relances 12 1/2' "$PROJ/.superpowers/sdd/m4/state.md"
  grep -qx 'Phase: lots' "$PROJ/.superpowers/sdd/m4/state.md"
}

@test "projet sous un chemin avec espaces et accents" {
  PROJ="$BATS_TEST_TMPDIR/Mon projet/Application Support é"
  mkdir -p "$PROJ"
  run "$KIT_SH" appliquer "$PLUG" "$PROJ"
  [ "$status" -eq 0 ]
  run "$KIT_SH" etat "$PLUG" "$PROJ"
  [ "$(statut make/x.mk)" = "a-jour" ]
  run "$KIT_SH" figer "$PLUG" "$PROJ" m5
  [ "$status" -eq 0 ]
}

@test "sous-commande inconnue ou argument manquant : code 2" {
  run "$KIT_SH" inconnue
  [ "$status" -eq 2 ]
  run "$KIT_SH" etat "$PLUG"
  [ "$status" -eq 2 ]
  run "$KIT_SH" figer "$PLUG" "$PROJ"
  [ "$status" -eq 2 ]
  run "$KIT_SH"
  [ "$status" -eq 2 ]
}

@test "appliquer garde le bit exécutable de la source, même sans extension .sh" {
  printf '#!/usr/bin/env bash\n%s\necho faux\n' "$ENTETE" > "$PLUG/kit/scripts/devteam/outil"
  chmod +x "$PLUG/kit/scripts/devteam/outil"
  printf 'base scripts/devteam/outil\nbase make/x.mk\n' > "$PLUG/kit/MANIFEST"
  "$KIT_SH" appliquer "$PLUG" "$PROJ"
  [ -x "$PROJ/scripts/devteam/outil" ]
  [ ! -x "$PROJ/make/x.mk" ]
}
