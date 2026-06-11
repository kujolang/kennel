#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$ROOT_DIR/.kennel_tmp"

if [ ! -d "$TMP_DIR" ]; then
	echo "[cleanup-local-artifacts] no temp directory found: $TMP_DIR"
	exit 0
fi

resolved_tmp="$(cd "$TMP_DIR" && pwd)"
expected_tmp="$ROOT_DIR/.kennel_tmp"
if [ "$resolved_tmp" != "$expected_tmp" ]; then
	echo "[cleanup-local-artifacts] refusing cleanup; unexpected temp path: $resolved_tmp"
	exit 1
fi

removed_count=0
while IFS= read -r entry_path; do
	rm -rf "$entry_path"
	removed_count=$((removed_count + 1))
done < <(find "$TMP_DIR" -mindepth 1 -maxdepth 1)

echo "[cleanup-local-artifacts] removed $removed_count item(s) from .kennel_tmp"
