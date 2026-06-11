#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOC_FILE="$ROOT_DIR/docs/architecture-flow-maps.md"

if [ ! -f "$DOC_FILE" ]; then
	echo "[verify-architecture-flow-maps] missing doc file: $DOC_FILE"
	exit 1
fi

required_doc_tokens=(
	"flowchart TD"
	"src/commands_dependency.kujo"
	"src/commands_hosted.kujo"
	"src/commands_shared.kujo"
	"src/resolver.kujo"
	"src/manifest.kujo"
	"scripts/verify-deterministic-lockfile.sh"
	"scripts/verify-stage-3-hosted-api-workflow.sh"
)

for token in "${required_doc_tokens[@]}"; do
	if ! grep -Fq -- "$token" "$DOC_FILE"; then
		echo "[verify-architecture-flow-maps] missing required mapping token: $token"
		exit 1
	fi
done

tmp_refs="$ROOT_DIR/.kennel_tmp/verify-architecture-flow-maps-paths.txt"
mkdir -p "$(dirname "$tmp_refs")"

grep -oE -- '(src/[A-Za-z0-9._/-]+\.kujo|scripts/[A-Za-z0-9._/-]+\.sh)' "$DOC_FILE" | sort -u > "$tmp_refs"

while IFS= read -r path_ref; do
	[ -z "$path_ref" ] && continue
	if [ ! -f "$ROOT_DIR/$path_ref" ]; then
		echo "[verify-architecture-flow-maps] missing referenced path: $path_ref"
		exit 1
	fi
done < "$tmp_refs"

echo "[verify-architecture-flow-maps] success"
