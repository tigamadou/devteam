#!/usr/bin/env bats
# Cohérence du texte du plugin : noms, chemins et marqueurs cités existent.

load ../helpers/communs

markdown() { find "$PLUGIN" -name '*.md' -not -path "$PLUGIN/kit/*"; }

@test "aucun « chantier » sous plugins/" {
  run grep -rniI chantier "$PLUGIN"
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
}

@test "chaque devteam:<role> cité existe dans agents/" {
  local nom mauvais=0
  while IFS= read -r nom; do
    case "$nom" in demarrer | conformite | mise-a-jour) continue ;; esac
    [ -f "$PLUGIN/agents/$nom.md" ] || { echo "agent inconnu : devteam:$nom"; mauvais=1; }
  done < <(markdown | xargs grep -ohE 'devteam:[a-z][a-z-]*[a-z]' | sed 's/^devteam://' | sort -u)
  [ "$mauvais" -eq 0 ]
}

@test "chaque agent a un frontmatter name égal à son nom de fichier" {
  local f mauvais=0
  for f in "$PLUGIN"/agents/*.md; do
    [ -f "$f" ] || continue
    grep -qx "name: $(basename "$f" .md)" "$f" || { echo "name incorrect : $f"; mauvais=1; }
  done
  [ "$mauvais" -eq 0 ]
}

@test "chaque marqueur {{…}} du gabarit superviseur figure dans la table du § 7 de demarrer" {
  local m mauvais=0
  while IFS= read -r m; do
    grep -qF "| \`$m\` |" "$PLUGIN/skills/demarrer/SKILL.md" || { echo "marqueur non documenté : $m"; mauvais=1; }
  done < <(grep -oE '\{\{[a-z_]+\}\}' "$PLUGIN/skills/demarrer/superviseur-template.md" | sort -u)
  [ "$mauvais" -eq 0 ]
}

@test "aucun chemin .claude/skills/ ni .claude/agents/ sous plugins/" {
  run grep -rnE '\.claude/(skills|agents)/' "$PLUGIN"
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
}

@test "chaque fichier cité par \${CLAUDE_PLUGIN_ROOT}/ ou \${CLAUDE_SKILL_DIR}/ existe" {
  local f ref chemin mauvais=0
  while IFS= read -r f; do
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      case "$ref" in
        '${CLAUDE_PLUGIN_ROOT}/'*) chemin="$PLUGIN/${ref#'${CLAUDE_PLUGIN_ROOT}/'}" ;;
        '${CLAUDE_SKILL_DIR}/'*) chemin="$(dirname "$f")/${ref#'${CLAUDE_SKILL_DIR}/'}" ;;
      esac
      chemin="${chemin%.}"
      [ -e "$chemin" ] || { echo "$f : $ref introuvable"; mauvais=1; }
    done < <(grep -oE '\$\{CLAUDE_(PLUGIN_ROOT|SKILL_DIR)\}/[A-Za-z0-9_./-]+' "$f" || true)
  done < <(markdown)
  [ "$mauvais" -eq 0 ]
}

@test "chaque skill a un frontmatter name égal à son dossier et une description" {
  local d mauvais=0
  for d in "$PLUGIN"/skills/*/; do
    d="${d%/}"
    [ "$(basename "$d")" = commun ] && continue
    grep -qx "name: $(basename "$d")" "$d/SKILL.md" || { echo "name incorrect : $d"; mauvais=1; }
    grep -q '^description: ' "$d/SKILL.md" || { echo "description absente : $d"; mauvais=1; }
  done
  [ "$mauvais" -eq 0 ]
}

CONF="$PLUGIN/skills/conformite"

@test "questionnaire.md contient les 25 questions" {
  local n
  for n in $(seq 1 25); do
    grep -qE "^\| $n \| " "$CONF/questionnaire.md" || { echo "question $n absente"; return 1; }
  done
}

@test "devteam-ci.yml : job ci-ok en if: always(), avec needs, et vérification jq des résultats" {
  local f="$CONF/modeles/ci/devteam-ci.yml"
  grep -q '^  ci-ok:$' "$f"
  awk '/^  ci-ok:$/ { dedans = 1; next } dedans && /^  [a-z]/ { dedans = 0 } dedans' "$f" > "$BATS_TEST_TMPDIR/ci-ok"
  grep -q 'if: always()' "$BATS_TEST_TMPDIR/ci-ok"
  grep -q 'needs: \[' "$BATS_TEST_TMPDIR/ci-ok"
  grep -qF '.result == "success" or .result == "skipped"' "$BATS_TEST_TMPDIR/ci-ok"
}

@test "devteam-ci.yml : chaque job hors ci-ok est dans needs de ci-ok" {
  local f="$CONF/modeles/ci/devteam-ci.yml" j needs
  needs="$(awk '/^  ci-ok:$/ { d = 1 } d && /needs:/ { print; exit }' "$f")"
  for j in $(awk '/^jobs:$/ { d = 1; next } d && /^  [a-z][a-z0-9-]*:$/ { gsub(/[ :]/, ""); print }' "$f" | grep -v '^ci-ok$'); do
    case "$needs" in *"$j"*) ;; *) echo "job hors needs : $j"; return 1 ;; esac
  done
}

@test "modeles/standard ne contient aucune ligne de recette active" {
  local f
  for f in "$CONF"/modeles/standard/*.mk; do
    [ -f "$f" ] || { echo "aucun modèle"; return 1; }
    if grep -nE '^[^#[:space:]]' "$f"; then echo "ligne active dans $f"; return 1; fi
  done
}

@test "modeles/settings.json déclare la marketplace et active le plugin" {
  grep -q '"repo": "tigamadou/devteam"' "$CONF/modeles/settings.json"
  grep -q '"devteam@devteam": true' "$CONF/modeles/settings.json"
}

@test "makefile-inclusions.mk inclut devteam-agent.mk seulement si devteam.agent.conf existe" {
  local d="$BATS_TEST_TMPDIR/p"
  mkdir -p "$d/make"
  cp "$CONF/modeles/makefile-inclusions.mk" "$d/Makefile"
  printf 'agent-up:\n\t@echo agent\n' > "$d/make/devteam-agent.mk"
  run make -s -C "$d" agent-up
  [ "$status" -ne 0 ]
  touch "$d/devteam.agent.conf"
  run make -s -C "$d" agent-up
  [ "$status" -eq 0 ]
  [ "$output" = "agent" ]
}
