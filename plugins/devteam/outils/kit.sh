#!/usr/bin/env bash
# Copie versionnée du kit devteam dans un projet.
#
#   kit.sh version <plugin>                       version du plugin
#   kit.sh etat <plugin> <projet>                 statut de chaque fichier du kit dans le projet
#   kit.sh appliquer <plugin> <projet> [chemin…]  copie les fichiers absents ou à mettre à jour (ou ceux nommés)
#   kit.sh mission-en-cours <projet>              0 et les slugs si une mission tourne, 1 sinon
#   kit.sh figer <plugin> <projet> <slug>         fige la méthode et la version pour une mission
#
# Statuts : absent, a-jour, a-mettre-a-jour, modifie-localement.
# Sorties : 0 succès, 1 erreur, 2 usage, 3 mission en cours, 4 fichier modifié localement.
set -euo pipefail

usage() {
  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}
erreur() { echo "kit.sh : $*" >&2; exit 1; }

FICHIER_VERSION="scripts/devteam/VERSION"

version_plugin() { # <plugin>
  local v
  [ -f "$1/.claude-plugin/plugin.json" ] || erreur "plugin.json introuvable dans $1/.claude-plugin"
  v="$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1/.claude-plugin/plugin.json" | awk 'NR == 1')"
  [ -n "$v" ] || erreur "clé version absente de $1/.claude-plugin/plugin.json"
  echo "$v"
}

# Lignes « <ensemble> <chemin> » applicables au projet (agent seulement si devteam.agent.conf existe)
entrees() { # <plugin> <projet>
  local ensemble chemin
  [ -f "$1/kit/MANIFEST" ] || erreur "MANIFEST introuvable dans $1/kit"
  while read -r ensemble chemin; do
    case "$ensemble" in
      "" | \#*) continue ;;
      base) ;;
      agent) [ -f "$2/devteam.agent.conf" ] || continue ;;
      *) erreur "ensemble inconnu « $ensemble » dans le MANIFEST" ;;
    esac
    echo "$chemin"
  done < "$1/kit/MANIFEST"
}

somme() { # <fichier>
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

rendre() { # <plugin> <chemin> <version> : contenu de la source, version substituée
  sed "s|{{version}}|$3|g" "$1/kit/$2"
}

version_projet() { # <projet>
  local v=""
  [ -f "$1/$FICHIER_VERSION" ] && v="$(sed -n 's/^version //p' "$1/$FICHIER_VERSION" | awk 'NR == 1')"
  echo "${v:-aucune}"
}

somme_enregistree() { # <projet> <chemin>
  [ -f "$1/$FICHIER_VERSION" ] || return 0
  awk -v c="$2" 'NR > 1 && $2 == c { print $1; exit }' "$1/$FICHIER_VERSION"
}

statut() { # <plugin> <projet> <chemin> <version>
  local dest="$2/$3" enregistree
  [ -f "$dest" ] || { echo absent; return 0; }
  enregistree="$(somme_enregistree "$2" "$3")"
  if [ -z "$enregistree" ] || [ "$enregistree" != "$(somme "$dest")" ]; then
    echo modifie-localement
  elif rendre "$1" "$3" "$4" | cmp -s - "$dest"; then
    echo a-jour
  else
    echo a-mettre-a-jour
  fi
}

missions_en_cours() { # <projet> : slugs des missions sans ligne DONE
  local f
  for f in "$1"/.superpowers/sdd/*/state.md; do
    [ -f "$f" ] || continue
    grep -qx 'DONE' "$f" || basename "$(dirname "$f")"
  done
}

cmd_etat() {
  [ $# -eq 2 ] || usage
  local plugin="$1" projet="$2" v c
  [ -d "$projet" ] || erreur "projet introuvable : $projet"
  v="$(version_plugin "$plugin")"
  echo "version-projet $(version_projet "$projet") version-plugin $v"
  entrees "$plugin" "$projet" | while IFS= read -r c; do
    echo "$(statut "$plugin" "$projet" "$c" "$v") $c"
  done
}

cmd_appliquer() {
  [ $# -ge 2 ] || usage
  local plugin="$1" projet="$2" v c s en_cours tous cibles=() demandes=()
  shift 2
  [ -d "$projet" ] || erreur "projet introuvable : $projet"
  v="$(version_plugin "$plugin")"
  en_cours="$(missions_en_cours "$projet")"
  if [ -n "$en_cours" ]; then
    echo "kit.sh : mission en cours ($(echo $en_cours)) : rien n'est copié pendant une mission" >&2
    exit 3
  fi
  tous="$(entrees "$plugin" "$projet")"
  if [ $# -gt 0 ]; then
    demandes=("$@")
    for c in "${demandes[@]}"; do
      printf '%s\n' "$tous" | grep -xF -- "$c" >/dev/null || { echo "kit.sh : « $c » n'est pas un fichier du kit pour ce projet" >&2; exit 2; }
      s="$(statut "$plugin" "$projet" "$c" "$v")"
      if [ "$s" = modifie-localement ]; then
        echo "kit.sh : $c a été modifié localement : rien n'est copié" >&2
        exit 4
      fi
      cibles+=("$c")
    done
  else
    while IFS= read -r c; do
      [ -n "$c" ] || continue
      case "$(statut "$plugin" "$projet" "$c" "$v")" in absent | a-mettre-a-jour) cibles+=("$c") ;; esac
    done <<< "$tous"
  fi

  if [ "${#cibles[@]}" -gt 0 ]; then
    for c in "${cibles[@]}"; do
      mkdir -p "$(dirname "$projet/$c")"
      rendre "$plugin" "$c" "$v" > "$projet/$c"
      if [ -x "$plugin/kit/$c" ]; then chmod +x "$projet/$c"; fi
      echo "copié : $c"
    done
  fi
  ecrire_version "$plugin" "$projet" "$v" "$tous" ${cibles[@]+"${cibles[@]}"}
}

# Réécrit VERSION : somme des fichiers écrits, somme conservée pour les autres ; la version n'est celle du plugin que
# si tous les fichiers applicables sont à jour (sinon l'ancienne est gardée : la mise à jour est partielle).
ecrire_version() { # <plugin> <projet> <version> <applicables> [écrits…]
  local plugin="$1" projet="$2" v="$3" tous="$4" c ancienne complet=1 tmp
  shift 4
  local ecrits=" "
  for c in "$@"; do ecrits="$ecrits$c "; done
  tmp="$(mktemp)"
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    case "$ecrits" in
      *" $c "*) echo "$(somme "$projet/$c") $c" >> "$tmp" ;;
      *)
        ancienne="$(somme_enregistree "$projet" "$c")"
        [ -z "$ancienne" ] || echo "$ancienne $c" >> "$tmp"
        ;;
    esac
  done <<< "$tous"
  mkdir -p "$(dirname "$projet/$FICHIER_VERSION")"
  # La version se calcule sur le nouveau VERSION : on l'installe d'abord avec l'ancienne version
  { echo "version $(version_projet "$projet")"; cat "$tmp"; } > "$tmp.v"
  mv "$tmp.v" "$projet/$FICHIER_VERSION"
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    [ "$(statut "$plugin" "$projet" "$c" "$v")" = a-jour ] || complet=0
  done <<< "$tous"
  if [ "$complet" = 1 ]; then
    { echo "version $v"; cat "$tmp"; } > "$projet/$FICHIER_VERSION"
  elif [ "$(version_projet "$projet")" = aucune ]; then
    { echo "version partielle"; cat "$tmp"; } > "$projet/$FICHIER_VERSION"
  fi
  rm -f "$tmp"
}

cmd_mission_en_cours() {
  [ $# -eq 1 ] || usage
  local en_cours
  en_cours="$(missions_en_cours "$1")"
  [ -n "$en_cours" ] || return 1
  echo "$en_cours"
}

cmd_figer() {
  [ $# -eq 3 ] || usage
  local plugin="$1" projet="$2" slug="$3" v dossier etat
  [[ "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { echo "kit.sh : slug invalide « $slug »" >&2; exit 2; }
  v="$(version_plugin "$plugin")"
  dossier="$projet/.superpowers/sdd/$slug"
  mkdir -p "$dossier/kit"
  cp "$plugin/skills/demarrer/SKILL.md" "$dossier/kit/methode.md"
  cp "$plugin/skills/commun/contrat.md" "$dossier/kit/contrat.md"
  etat="$dossier/state.md"
  if [ -f "$etat" ] && grep -q '^Version devteam:' "$etat"; then
    awk -v v="$v" '/^Version devteam:/ { print "Version devteam: " v; next } { print }' "$etat" > "$etat.tmp"
    mv "$etat.tmp" "$etat"
  else
    echo "Version devteam: $v" >> "$etat"
  fi
  echo "mission $slug figée en devteam $v"
}

[ $# -ge 1 ] || usage
sous_commande="$1"
shift
case "$sous_commande" in
  version) [ $# -eq 1 ] || usage; version_plugin "$1" ;;
  etat) cmd_etat "$@" ;;
  appliquer) cmd_appliquer "$@" ;;
  mission-en-cours) cmd_mission_en_cours "$@" ;;
  figer) cmd_figer "$@" ;;
  *) usage ;;
esac
