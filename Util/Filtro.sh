#!/bin/bash

ROMS="/home/willian/.config/retroarch/roms/FBNeo - Arcade Games/"
LPL_DIR="/home/willian/.config/retroarch/playlists/"
DESTINO="/home/willian/.config/retroarch/roms/FBNeo - Arcade Games/BAK/"

mkdir -p "$DESTINO"

# cria lista temporária
TMP_LIST=$(mktemp)

# pega todos os paths dos lpl
for lpl in "$LPL_DIR"/*.lpl; do
    jq -r '.items[].path' "$lpl" >> "$TMP_LIST"
done

# normaliza nomes (só nome do arquivo)
sort -u "$TMP_LIST" | xargs -n1 basename > /tmp/keep.txt

# percorre roms
for rom in "$ROMS"/*; do
    nome=$(basename "$rom")

    if ! grep -qx "$nome" /tmp/keep.txt; then
        mv "$rom" "$DESTINO/"
    fi
done

rm "$TMP_LIST"
