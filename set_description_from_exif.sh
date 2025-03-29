#!/bin/bash

shopt -s nullglob

# === Defaults ===
LOGFILE="set_description_log.csv"
NUM_JOBS=4
DRY_RUN=false
SKIP_TAGGED=false
SHOW_STATS=false

# === Usage ===
usage() {
  echo "Usage: $0 [options] <image-file(s)> or glob pattern"
  echo "Options:"
  echo "  -n                Dry-run mode (don’t write EXIF tags)"
  echo "  --skip-tagged     Skip images that already have a description"
  echo "  --logfile <file>  Specify output CSV log filename (default: $LOGFILE)"
  echo "  --stats           Show summary counts at the end"
  exit 1
}

# === Parse CLI options ===
while [[ "$1" =~ ^- ]]; do
  case "$1" in
    -n ) DRY_RUN=true; shift ;;
    --skip-tagged ) SKIP_TAGGED=true; shift ;;
    --stats ) SHOW_STATS=true; shift ;;
    --logfile )
      shift
      [ -z "$1" ] && usage
      LOGFILE="$1"
      shift ;;
    -* ) usage ;;
    -- ) shift; break ;;
  esac
done

# === Check for input files ===
if [ "$#" -lt 1 ]; then
  usage
fi

# === Logging & Timer ===
START_TIME=$(date +%s)
TOTAL_FILES=0

echo "Processing started at $(date)"
echo "Logging to $LOGFILE..."
echo "File,OriginalDescription,NewDescription,MissingFields,Status" > "$LOGFILE"

# === Counters for stats ===
UPDATED=0
SKIPPED=0
NOT_A_FILE=0
DRY_RUNS=0

# === Function to process a single file ===
process_file() {
  local FILE="$1"

  if [ ! -f "$FILE" ]; then
    echo "$FILE,,,,Not a file" >> "$LOGFILE"
    ((NOT_A_FILE++))
    return
  fi

  local ORIGINAL_DESC
  ORIGINAL_DESC=$(exiftool -s3 -ImageDescription "$FILE")

  if [ "$SKIP_TAGGED" = true ] && [ -n "$ORIGINAL_DESC" ]; then
    echo "\"$FILE\",\"${ORIGINAL_DESC//\"/\"\"}\",,,Skipped - already tagged" >> "$LOGFILE"
    ((SKIPPED++))
    return
  fi

  local CAMERA LENS FOCAL SHUTTER APERTURE
  CAMERA=$(exiftool -s3 -Model "$FILE")
  LENS=$(exiftool -s3 -Lens "$FILE")
  FOCAL=$(exiftool -s3 -FocalLength "$FILE")
  SHUTTER=$(exiftool -s3 -ShutterSpeedValue "$FILE")
  APERTURE=$(exiftool -s3 -ApertureValue "$FILE")

  local MISSING=()
  [ -z "$CAMERA" ] && MISSING+=("Camera Model")
  [ -z "$LENS" ] && MISSING+=("Lens")
  [ -z "$FOCAL" ] && MISSING+=("Focal Length")
  [ -z "$SHUTTER" ] && MISSING+=("Shutter Speed")
  [ -z "$APERTURE" ] && MISSING+=("Aperture")

  local DESCRIPTION="${CAMERA:-[Missing]} - ${LENS:-[Missing]} - ${FOCAL:-[Missing]} - ${SHUTTER:-[Missing]} - ${APERTURE:-[Missing]}"
  local MISSING_STR="${MISSING[*]}"
  local STATUS

  if [ "$DRY_RUN" = true ]; then
    STATUS="Dry run"
    ((DRY_RUNS++))
  else
    exiftool -overwrite_original -ImageDescription="$DESCRIPTION" "$FILE" > /dev/null
    STATUS="Updated"
    ((UPDATED++))
  fi

  ORIGINAL_DESC=${ORIGINAL_DESC//\"/\"\"}
  DESCRIPTION=${DESCRIPTION//\"/\"\"}
  MISSING_STR=${MISSING_STR//\"/\"\"}

  echo "\"$FILE\",\"$ORIGINAL_DESC\",\"$DESCRIPTION\",\"$MISSING_STR\",\"$STATUS\"" >> "$LOGFILE"
}

export -f process_file
export DRY_RUN LOGFILE SKIP_TAGGED UPDATED SKIPPED NOT_A_FILE DRY_RUNS

# === Gather files and count ===
FILE_LIST=("$@")
TOTAL_FILES=${#FILE_LIST[@]}

# === Process in parallel ===
printf "%s\n" "${FILE_LIST[@]}" | xargs -n 1 -P "$NUM_JOBS" -I{} bash -c 'process_file "$@"' _ {}

# === Timing & Stats ===
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
# Avoid division by zero
if [ "$ELAPSED" -gt 0 ]; then
  FPS=$(awk "BEGIN { printf \"%.2f\", $TOTAL_FILES / $ELAPSED }")
else
  FPS="$TOTAL_FILES.00"
fi

# === Final Log ===
echo "Done. Processed $TOTAL_FILES files in ${ELAPSED}s (${FPS} files/sec)."
echo "CSV log saved to $LOGFILE"

# === Optional stats ===
if [ "$SHOW_STATS" = true ]; then
  echo
  echo "Summary:"
  echo "  Total Files:     $TOTAL_FILES"
  echo "  Updated:         $UPDATED"
  echo "  Dry-run:         $DRY_RUNS"
  echo "  Skipped Tagged:  $SKIPPED"
  echo "  Not a File:      $NOT_A_FILE"
fi
