#!/bin/bash

# Usage: ./clean_jars.sh paths.txt jars.txt /backup/base/dir

if [ $# -ne 3 ]; then
  echo "Usage: $0 <paths_file.txt> <jars_file.txt> <backup_base_directory>"
  exit 1
fi

paths_file="$1"
jars_file="$2"
backup_base_dir="$3"

  echo "Variable: $paths_file"

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
backup_directory="$backup_base_dir/Backup_$timestamp"

mkdir -p "$backup_directory"
log_file="$backup_directory/deletion_log.txt"

log_action() {
  echo "$1" | tee -a "$log_file"
}

# Read jar names into an array
mapfile -t jar_list < "$jars_file"

deleted_count=0

# Clean CRLF if file created on Windows
dos2unix "$paths_file" "$jars_file" >/dev/null 2>&1 || true

while IFS= read -r path; do
  [ -z "$path" ] && continue

  if [ ! -d "$path" ]; then
    log_action "⚠️ Path not found: $path"
    continue
  fi
    log_action "📁 Scanning path: $path"
  for jar_name in "${jar_list[@]}"; do
    log_action "🔍 Searching for: $jar_name in $path"
    while IFS= read -r jar_path; do
      if [ -f "$jar_path" ]; then
        relative_path="${jar_path#$path/}"
        relative_dir=$(dirname "$relative_path")
        backup_path="$backup_directory/$relative_dir"

        mkdir -p "$backup_path"
        cp -p "$jar_path" "$backup_path/"
        log_action "📂 Backed up: $jar_path → $backup_path/$jar_name"

        rm -f "$jar_path"
        log_action "🗑️ Deleted: $jar_path"
        ((deleted_count++))
      fi
    done < <(find "$path" -type f -name "$jar_name" 2>/dev/null)
  done
done < "$paths_file"

if [ $deleted_count -eq 0 ]; then
  log_action "⚠️ No matching JARs found in any provided paths."
else
  log_action "✅ Total deleted after backup: $deleted_count"
fi

log_action "📝 Log file created at: $log_file"
echo "Process completed. Check the log file at: $log_file"