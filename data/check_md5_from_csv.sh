#!/bin/bash

# Usage: ./check_md5_from_csv.sh checksums.csv /path/to/search
# Checksums obtained via Google Drive v3 API - see https://stackoverflow.com/a/49043352
# This script reads a CSV file with expected MD5 checksums and original filenames,
# searches for files in a specified directory, computes their MD5 checksums,
# and compares them against the expected values.
# It can handle filenames with optional '-XXX' suffixes before the extension, which 
# is common when downloading directories from Google Drive.

CSV_FILE="$1"
SEARCH_DIR="$2"

if [[ ! -f "$CSV_FILE" || ! -d "$SEARCH_DIR" ]]; then
  echo "Usage: $0 checksums.csv /path/to/search"
  exit 1
fi

# Remove quotes from CSV (if any), skip header
tail -n +2 "$CSV_FILE" | sed 's/"//g' | while IFS=, read -r expected_md5 original_filename; do
  # Build search pattern: original_filename plus optional '-XXX' before the extension
  base_name="${original_filename%.*}"  # e.g., imagenet_ai_0508_adm
  extension="${original_filename##*.}" # e.g., z01

  # Use glob pattern for find (literal * to match optional '-XXX')
  search_pattern="${base_name}-*.$extension ${base_name}.$extension"

  # Find files matching the pattern
  matched_file=$(find "$SEARCH_DIR" -type f \( -name "${base_name}-*.$extension" -o -name "${base_name}.$extension" \) | head -n 1)

  if [[ -z "$matched_file" ]]; then
    echo "❌ File not found: $original_filename"
    continue
  fi

  # Compute the md5sum
  computed_md5=$(md5sum "$matched_file" | awk '{print $1}')

  # Compare checksums
  if [[ "$expected_md5" == "$computed_md5" ]]; then
    # Check if filename differs
    actual_filename=$(basename "$matched_file")
    if [[ "$actual_filename" != "$original_filename" ]]; then
      echo "✅ OK (but filename differs):"
      echo "    Expected: $original_filename"
      echo "    Found:    $actual_filename"
    else
      echo "✅ OK: $original_filename"
    fi
  else
    echo "❗ MISMATCH: $original_filename"
    echo "    Expected MD5: $expected_md5"
    echo "    Found MD5:    $computed_md5"
    echo "    Actual file:  $(basename "$matched_file")"
  fi
done
