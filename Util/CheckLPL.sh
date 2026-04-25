#!/bin/bash

ROMS="/home/willian/.config/retroarch/roms/FBNeo - Arcade Games/"
LPL_DIR="/home/willian/.config/retroarch/playlists/"
DESTINO="/home/willian/BAK/"

mkdir -p "$DESTINO"

TMP=$(mktemp)

# pega lista de ROMs usadas
for lpl in "$LPL_DIR"/*.lpl; do
    jq -r '.items[].path' "$lpl" | xargs -n1 basename >> "$TMP"
done

sort -u "$TMP" -o "$TMP"

echo "Iniciando varredura..."

# varre recursivamente
find "$ROMS" -type f | while read rom; do
    nome=$(basename "$rom")

    if ! grep -qx "$nome" "$TMP"; then
        echo "Movendo: $rom"

        # recria estrutura de pastas no destino
        destino_final="$DESTINO/${rom#$ROMS/}"
        mkdir -p "$(dirname "$destino_final")"

        mv "$rom" "$destino_final"
    fi
done

rm "$TMP"
