#!/usr/bin/env bash

# Erik Martin-Dorel, 2022
#
# script conçu pour extraire tous les "$dm.ml" d'un volume learn-ocaml
# en les copiant vers le chemin "$dest/prénom NOM_${nick}_-_${token}/$dm.ml"
# (compatible avec le "nommage Moodle" accepté / autograde-ocaml.bash)
#
# où $nick est extrait de save.json (avec jq -r .nickname)
#
# et où prénom, NOM sont extraits du fichier $dm.ml
# let nom = "NOM" and prenom = "Prénom"

# srcdir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )
srcdir=~/Desktop/ilu_tpn_2023/sync
dest=~/Desktop/ilu_tpn_2023/tograde

dm=ilu-tpn

find "$srcdir" -type f -name "$dm.ml" -exec \
     bash -c 'fil=$1; dm=$2; dest=$3; srcdir="${4%/}/"
     dir=$(dirname "$fil")
     token=${dir/$srcdir/}
     token=${token//\//-}
     save="$dir/save.json"
     nick=$(jq -r ".nickname" "$save")
     nom_input=$(grep -e " \+nom *=" "$fil")
     nom=$(sed -e "s/^.* \+nom *= *\"\([^\"]\+\).*$/\1/" <<<"$nom_input")
     nom=$(tr "[:lower:]" "[:upper:]" <<<"$nom")
     prenom_input=$(grep -e "prenom *=" "$fil")
     prenom=$(sed -e "s/^.*prenom *= *\"\([^\"]\+\).*$/\1/" <<<"$prenom_input")
     prenom=$(tr "[:upper:]" "[:lower:]" <<<"$prenom") # XXX lazy to capitalize
     target="$dest/${prenom} ${nom}_${nick}_-_${token}"
     set -x
     mkdir -p "$target"
     cp -i "$fil" "$target/$dm.ml"
     ' bash '{}' "$dm" "$dest" "$srcdir" \;
