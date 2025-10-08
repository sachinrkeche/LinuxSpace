#!/bin/bash
# ============================================================
# Generic Multi-File Downloader (per-file target mapping + parallel + force)
#
# Usage:
#   ./download_mapped_files.sh <mapping_file> [--parallel] [--force]
#
# mapping_file example (URL + target directory separated by space or tab):
#   https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-api/2.25.1/log4j-api-2.25.1.jar /data/temp/libs/api/
#   https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-core/2.25.1/log4j-core-2.25.1.jar /data/temp/libs/core/
#
# ============================================================

set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 <mapping_file> [--parallel] [--force]"
  exit 1
fi

MAPPING_FILE="$1"
shift 1

# Optional flags
PARALLEL_MODE=false
FORCE_MODE=false

for arg in "$@"; do
  case $arg in
    --parallel) PARALLEL_MODE=true ;;
    --force) FORCE_MODE=true ;;
    *) echo "⚠️  Unknown option: $arg" ;;
  esac
done

# Validate mapping file
if [ ! -f "$MAPPING_FILE" ]; then
  echo "❌ Mapping file not found: $MAPPING_FILE"
  exit 1
fi

# Prepare log file
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="./download_log_$TIMESTAMP.txt"

log_action() {
  echo "$1" | tee -a "$LOG_FILE"
}

# Detect download tool
if command -v curl >/dev/null 2>&1; then
  DOWNLOADER="curl"
elif command -v wget >/dev/null 2>&1; then
  DOWNLOADER="wget"
else
  log_action "❌ Neither curl nor wget found. Please install one."
  exit 1
fi

log_action "🚀 Starting mapped downloads..."
log_action "Using: $DOWNLOADER"
$PARALLEL_MODE && log_action "⚡ Parallel mode enabled"
$FORCE_MODE && log_action "🔁 Force mode enabled (will overwrite existing files)"

# ---- FUNCTION: Download one file ----
download_mapped_file() {
  local FILE_URL="$1"
  local TARGET_DIR="$2"
  local FILE_NAME=$(basename "$FILE_URL")
  local TARGET_PATH="$TARGET_DIR/$FILE_NAME"

  mkdir -p "$TARGET_DIR"

  if [ -f "$TARGET_PATH" ] && [ "$FORCE_MODE" = false ]; then
    echo "⏩ Skipped (exists): $TARGET_PATH" >>"$LOG_FILE"
    return
  fi

  echo "⬇️  Downloading: $FILE_URL → $TARGET_DIR" >>"$LOG_FILE"

  if [ "$DOWNLOADER" = "curl" ]; then
    curl -s -L -o "$TARGET_PATH" "$FILE_URL" >>"$LOG_FILE" 2>&1
  else
    wget -q -O "$TARGET_PATH" "$FILE_URL" >>"$LOG_FILE" 2>&1
  fi

  if [ -f "$TARGET_PATH" ]; then
    echo "✅ Success: $TARGET_PATH" >>"$LOG_FILE"
  else
    echo "❌ Failed: $FILE_URL" >>"$LOG_FILE"
  fi
}

# ---- MAIN LOGIC ----
if $PARALLEL_MODE; then
  log_action "⚙️  Running parallel downloads (max 5 at once)..."
  export -f download_mapped_file
  export LOG_FILE DOWNLOADER FORCE_MODE

  # Read mapping file, skip blank/comment lines, handle spaces/tabs
  awk '!/^#/ && NF>=2 {print $1,$2}' "$MAPPING_FILE" | \
  xargs -n 2 -P 5 bash -c 'download_mapped_file "$0" "$1"' 
else
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    FILE_URL=$(echo "$line" | awk '{print $1}')
    TARGET_DIR=$(echo "$line" | awk '{print $2}')
    [ -z "$FILE_URL" ] || [ -z "$TARGET_DIR" ] && continue
    download_mapped_file "$FILE_URL" "$TARGET_DIR"
  done < "$MAPPING_FILE"
fi

log_action "🎯 All downloads complete. Log saved at: $LOG_FILE"
