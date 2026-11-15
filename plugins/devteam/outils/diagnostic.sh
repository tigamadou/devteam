#!/usr/bin/env bash
# Diagnostic mécanique du contrat devteam pour un projet.
#
#   diagnostic.sh <projet>
#
# Écrit « structure<TAB>ok|bloquant<TAB>détail », puis une ligne « <n><TAB><clé><TAB>rempli|partiel|absent<TAB>détail »
# par point du contrat. rempli = vérification réussie et section du fichier projet présente ; partiel = l'une des deux ;
# absent = aucune. Sorties : 0 tout rempli et structure ok, 1 sinon, 2 usage.
set -euo pipefail

[ $# -eq 1 ] && [ -d "$1" ] || { echo "Usage : $0 <projet>" >&2; exit 2; }
PROJET="$(cd "$1" && pwd)"
FICHIER="$PROJET/.claude/devteam.projet.md"
CIBLES="test-cible coverage-diff lint typecheck generate check-generated migrations-check e2e-fixtures e2e"
TAB="$(printf '\t')"

# Corps de la section « ## <clé> » du fichier projet, commentaires HTML retirés
section() {
  [ -f "$FICHIER" ] || return 0
  awk -v cle="$1" '
    /^## / { dedans = ($0 == "## " cle); next }
    dedans' "$FICHIER" | awk '
    /<!--/ { cache = 1 }
    !cache { print }
    /-->/ { cache = 0 }'
}

# grep sans -q : il lit toute l'entrée (avec -q, la sortie anticipée provoque un SIGPIPE en amont, fatal sous pipefail)
section_presente() { section "$1" | grep '[^[:space:]]' >/dev/null; }

# Valeur d'une ligne « - <libellé> : <valeur> » de la section
ligne() { section "$1" | sed -n "s/^- $2 : //p" | awk 'NR == 1'; }

# Chemins entre accents graves d'une valeur, un par ligne
chemins() { printf '%s\n' "$1" | grep -o '`[^`]*`' | tr -d '`' || true; }

cible_existe() { make -C "$PROJET" -n "$1" LOT=x PROFIL=p BASE=y T=x >/dev/null 2>&1; }

STATUT_GLOBAL=0
rapport() { # <n> <clé> <vérification 0|1> <détail>
  local etat
  if [ "$3" = 0 ] && section_presente "$2"; then
    etat=rempli
  elif [ "$3" = 0 ] || section_presente "$2"; then
    etat=partiel
  else
    etat=absent
  fi
  [ "$etat" = rempli ] || STATUT_GLOBAL=1
  section_presente "$2" || set -- "$1" "$2" "$3" "$4${4:+ ; }section « $2 » absente ou vide"
  echo "$1$TAB$2$TAB$etat$TAB${4:-ok}"
}

# --- Structure ---------------------------------------------------------------------------------------------------
imbriques="$(find "$PROJET" -mindepth 2 -name .git -not -path "$PROJET/.git/*" -prune 2>/dev/null | sed "s|^$PROJET/||; s|/\.git\$||" | sort | tr '\n' ' ' || true)"
if [ -f "$PROJET/.gitmodules" ]; then
  echo "structure${TAB}bloquant${TAB}sous-modules git déclarés (.gitmodules) : le code n'est pas dans un seul dépôt"
  STATUT_GLOBAL=1
elif [ -n "$imbriques" ]; then
  echo "structure${TAB}bloquant${TAB}dépôts git imbriqués : ${imbriques% }"
  STATUT_GLOBAL=1
else
  echo "structure${TAB}ok${TAB}un seul dépôt"
fi

# --- 1. Docker uniquement ---------------------------------------------------------------------------------------
if cible_existe help; then v=0; d=""; else v=1; d="pas de cible make help"; fi
rapport 1 docker "$v" "$d"

# --- 2. Environnement d'agent -----------------------------------------------------------------------------------
manque=""
for c in agent-up agent-down agent-status; do cible_existe "$c" || manque="$manque $c"; done
if [ -z "$manque" ]; then v=0; d=""; else v=1; d="cibles absentes :$manque"; fi
rapport 2 agent_env "$v" "$d"

# --- 3. Isolation -----------------------------------------------------------------------------------------------
garde="$(chemins "$(ligne isolation Garde-fou)" | awk 'NR == 1')"
if [ -z "$garde" ]; then
  v=1; d="ligne « - Garde-fou : \`<chemin>\` » absente"
elif [ -e "$PROJET/$garde" ]; then
  v=0; d=""
else
  v=1; d="garde-fou introuvable : $garde"
fi
rapport 3 isolation "$v" "$d"

# --- 4. Cibles standard -----------------------------------------------------------------------------------------
manque=""
for c in $CIBLES; do
  cible_existe "$c" && continue
  section cibles | grep "^- $c : sans objet" >/dev/null && continue
  manque="$manque $c"
done
if [ -z "$manque" ]; then v=0; d=""; else v=1; d="cibles absentes :$manque"; fi
rapport 4 cibles "$v" "$d"

# --- 5. Branches ------------------------------------------------------------------------------------------------
integ="$(chemins "$(ligne branches Intégration)" | awk 'NR == 1')"
if [ -z "$integ" ]; then
  v=1; d="ligne « - Intégration : \`<branche>\` » absente"
elif git -C "$PROJET" for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null |
  grep -E "^([^/]+/)?${integ}\$" >/dev/null; then
  v=0; d=""
else
  v=1; d="branche d'intégration « $integ » introuvable"
fi
rapport 5 branches "$v" "$d"

# --- 6. CI et GitHub --------------------------------------------------------------------------------------------
check="$(chemins "$(ligne ci 'Check requis')" | awk 'NR == 1')"
d=""
gh auth status >/dev/null 2>&1 || d="gh non authentifié"
if [ -z "$check" ]; then
  d="$d${d:+ ; }ligne « - Check requis : \`<nom>\` » absente"
else
  job=0
  for w in "$PROJET"/.github/workflows/*.yml "$PROJET"/.github/workflows/*.yaml; do
    [ -f "$w" ] || continue
    if grep -E "^[[:space:]]+${check}:[[:space:]]*\$" "$w" >/dev/null; then job=1; fi
  done
  [ "$job" = 1 ] || d="$d${d:+ ; }aucun workflow de .github/workflows ne définit le job « $check »"
fi
if [ -z "$d" ]; then v=0; else v=1; fi
rapport 6 ci "$v" "$d"

# --- 7. Budget --------------------------------------------------------------------------------------------------
doc="$(chemins "$(ligne budget Document)" | awk 'NR == 1')"
jeton="$(ligne budget 'Jeton e2e')"
d=""
if [ -z "$doc" ]; then
  d="ligne « - Document : \`<chemin>\` » absente"
elif [ ! -e "$PROJET/$doc" ]; then
  d="document de budget introuvable : $doc"
fi
printf '%s' "$jeton" | grep -E '^[0-9]+' >/dev/null || d="$d${d:+ ; }ligne « - Jeton e2e : <n> » absente"
if [ -z "$d" ]; then v=0; else v=1; fi
rapport 7 budget "$v" "$d"

# --- 8. Fichiers générés et migrations --------------------------------------------------------------------------
generes="$(ligne generes_migrations 'Générés')"
d=""
case "$generes" in
  "") d="ligne « - Générés : … » absente" ;;
  "sans objet"*) ;;
  *)
    liste="$(chemins "$generes")"
    if [ -z "$liste" ]; then
      d="aucun chemin entre accents graves dans « - Générés : »"
    else
      while IFS= read -r g; do
        [ -e "$PROJET/$g" ] || d="$d${d:+ ; }fichier généré introuvable : $g"
      done <<< "$liste"
    fi
    ;;
esac
if [ -z "$d" ]; then v=0; else v=1; fi
rapport 8 generes_migrations "$v" "$d"

# --- 9. Tâches planifiées ---------------------------------------------------------------------------------------
if docker info >/dev/null 2>&1; then v=0; d=""; else v=1; d="docker ne répond pas"; fi
rapport 9 taches_planifiees "$v" "$d"

exit "$STATUT_GLOBAL"
