#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="./content"

# Controlla che la cartella esista
if [ ! -d "$ROOT_DIR" ]; then
  echo "La cartella $ROOT_DIR non esiste."
  exit 1
fi

# File temporaneo per salvare coppie "size<tab>path"
TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

echo "Scannerizzo immagini JPG/JPEG in $ROOT_DIR ..."

# Trova tutte le immagini e salva: "<size>\t<path>" nel file temporaneo
find "$ROOT_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) -print0 | while IFS= read -r -d '' file; do
  size=$(stat -f %z "$file")  # macOS: usa stat -f %z
  printf "%s\t%s\n" "$size" "$file" >> "$TMP_FILE"
done

# Se non ci sono file, esci
if [ ! -s "$TMP_FILE" ]; then
  echo "Nessuna immagine JPG/JPEG trovata in $ROOT_DIR"
  exit 0
fi

# Calcola totale e numero di file
total_bytes=$(awk '{sum+=$1} END {print sum+0}' "$TMP_FILE")
file_count=$(wc -l < "$TMP_FILE" | tr -d '[:space:]')

# Calcola media
avg_bytes=$(awk '{sum+=$1} END {if (NR>0) print int(sum/NR); else print 0}' "$TMP_FILE")

# Funzione per formattare i byte in B / KB / MB / GB / TB
human_readable() {
  echo "$1" | awk '{
    split("B KB MB GB TB", u);
    size=$1;
    i=1;
    while (size >= 1024 && i < 5) {
      size = size / 1024;
      i++;
    }
    printf "%.2f %s\n", size, u[i];
  }'
}

echo
echo "📊 Statistiche immagini in $ROOT_DIR"
echo "-------------------------------------"
echo "Numero di file:       $file_count"
echo "Dimensione totale:    $(human_readable "$total_bytes")"
echo "Dimensione media:     $(human_readable "$avg_bytes")"

echo
echo "🏆 Top 10 file per dimensione:"
echo "-------------------------------------"

# Ordina per dimensione decrescente e mostra i primi 10
sort -nrk1,1 "$TMP_FILE" | head -n 10 | awk '{
  size=$1; $1="";
  sub(/^[ \t]+/, "", $0);
  fname=$0;
  # conversione human-readable per ogni riga
  split("B KB MB GB TB", u);
  hsize=size; i=1;
  while (hsize >= 1024 && i < 5) {
    hsize = hsize / 1024;
    i++;
  }
  printf " - %.2f %s\t%s\n", hsize, u[i], fname;
}'
