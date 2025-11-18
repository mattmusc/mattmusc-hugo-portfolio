#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="./content"

# Soglia in MB (default 2.5 MB, puoi passare un valore come primo argomento es: ./optimize_images.sh 3)
THRESHOLD_MB="${1:-2.5}"

# Converti soglia in byte
THRESHOLD_BYTES=$(awk "BEGIN {printf \"%d\", $THRESHOLD_MB*1024*1024}")

echo "Ottimizzo immagini JPG/JPEG in $ROOT_DIR più grandi di $THRESHOLD_MB MB (~$THRESHOLD_BYTES bytes)"
echo

# Controlla che la cartella esista
if [ ! -d "$ROOT_DIR" ]; then
  echo "La cartella $ROOT_DIR non esiste."
  exit 1
fi

# Check che 'magick' sia disponibile
if ! command -v magick >/dev/null 2>&1; then
  echo "Errore: 'magick' (ImageMagick) non trovato. Installa con 'brew install imagemagick'."
  exit 1
fi

# Trova tutte le immagini
find "$ROOT_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) -print0 | while IFS= read -r -d '' file; do
  size=$(stat -f %z "$file")  # macOS: stat -f %z

  if [ "$size" -gt "$THRESHOLD_BYTES" ]; then
    echo "➜ Ottimizzo: $file ($(printf '%.2f' "$(awk "BEGIN {print $size/1024/1024}")") MB)"

    tmp="${file}.tmp"

    # Ricampiona max 2500px lato lungo, rimuove metadata, qualità 82
    magick "$file" \
      -resize '2500x2500>' \
      -strip \
      -quality 82 \
      "$tmp"

    mv "$tmp" "$file"
  fi
done

echo
echo "✅ Ottimizzazione completata."
