#!/usr/bin/env bats
# Le MANIFEST décrit exactement les fichiers de kit/ copiés dans les projets.

load ../helpers/communs

KIT="$PLUGIN/kit"

entrees() { grep -vE '^[[:space:]]*(#|$)' "$KIT/MANIFEST"; }

@test "chaque ligne du MANIFEST a un ensemble valide et désigne un fichier existant de kit/" {
  local ensemble chemin reste mauvais=0
  while read -r ensemble chemin reste; do
    case "$ensemble" in base | agent) ;; *) echo "ensemble invalide : $ensemble"; mauvais=1 ;; esac
    [ -z "$reste" ] || { echo "colonne en trop : $ensemble $chemin $reste"; mauvais=1; }
    [ -f "$KIT/$chemin" ] || { echo "absent : $chemin"; mauvais=1; }
  done < <(entrees)
  [ "$mauvais" -eq 0 ]
}

@test "chaque fichier de kit/ est dans le MANIFEST" {
  local f mauvais=0
  while IFS= read -r f; do
    f="${f#"$KIT"/}"
    case "$f" in MANIFEST | *.exemple | adaptateurs-exemples/*) continue ;; esac
    entrees | awk '{print $2}' | grep -qxF "$f" || { echo "hors MANIFEST : $f"; mauvais=1; }
  done < <(find "$KIT" -type f)
  [ "$mauvais" -eq 0 ]
}

@test "chaque fichier du MANIFEST porte l'en-tête devteam {{version}}" {
  local ensemble chemin entete mauvais=0
  entete='# devteam {{version}} : fichier du kit, ne pas modifier ici'
  while read -r ensemble chemin; do
    if [ "$(head -1 "$KIT/$chemin" | cut -c1-2)" = "#!" ]; then
      [ "$(sed -n 2p "$KIT/$chemin")" = "$entete" ] || { echo "en-tête absent (ligne 2) : $chemin"; mauvais=1; }
    else
      [ "$(head -1 "$KIT/$chemin")" = "$entete" ] || { echo "en-tête absent (ligne 1) : $chemin"; mauvais=1; }
    fi
  done < <(entrees)
  [ "$mauvais" -eq 0 ]
}
