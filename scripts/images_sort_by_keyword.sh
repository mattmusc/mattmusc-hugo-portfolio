#!/usr/bin/env bash

set -euo pipefail

SRC="./content/export"     # dove LR esporta
DEST_ROOT="./content"      # root del tuo sito

if [ ! -d "$SRC" ]; then
  echo "La cartella $SRC non esiste."
  exit 1
fi

# Controllo exiftool
if ! command -v exiftool >/dev/null 2>&1; then
  echo "Errore: 'exiftool' non trovato. Installa con 'brew install exiftool'."
  exit 1
fi

echo "📁 Scannerizzo file JPG in $SRC ..."
echo

shopt -s nullglob
for file in "$SRC"/*.jpg "$SRC"/*.jpeg; do
  [ -e "$file" ] || continue

  # Legge TUTTE le keyword
  all_keywords=$(exiftool -s -s -s -Keywords "$file" || true)

  # Prende la prima keyword che inizia con 'portfolio-'
  portfolio_keyword=$(echo "$all_keywords" | grep -E '^portfolio-' | head -n 1 || true)

  if [ -z "$portfolio_keyword" ]; then
    echo "⚠️ Nessuna keyword 'portfolio-*' per: $(basename "$file"), salto."
    continue
  fi

  # Rimuove il prefisso 'portfolio-'
  category="${portfolio_keyword#portfolio-}"

  # Normalizza (minuscolo, spazi -> underscore)
  category_clean=$(echo "$category" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' )

  dest_dir="$DEST_ROOT/$category_clean"
  mkdir -p "$dest_dir"

  echo "➜ $(basename "$file")  [$portfolio_keyword → $category_clean] → $dest_dir/"
  mv "$file" "$dest_dir/"
done
shopt -u nullglob

# Rimuove la cartella export se è vuota
if [ -d "$SRC" ] && [ -z "$(ls -A "$SRC")" ]; then
  echo "🧹 Rimuovo cartella vuota: $SRC"
  rmdir "$SRC"
fi

echo
echo "✅ Ordinamento completato usando keyword 'portfolio-*' (nessun rename, solo spostamento)."
