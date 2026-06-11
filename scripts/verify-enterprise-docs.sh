#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOC_GUIDE="$ROOT_DIR/docs/enterprise-adoption-guide.md"
DOC_POLICY="$ROOT_DIR/docs/change-type-validation-policy.md"
DOC_RUNBOOK="$ROOT_DIR/docs/maintainer-runbook.md"

required_docs=(
	"$DOC_GUIDE"
	"$DOC_POLICY"
	"$DOC_RUNBOOK"
)

for doc_path in "${required_docs[@]}"; do
	if [ ! -f "$doc_path" ]; then
		echo "[verify-enterprise-docs] missing required doc: $doc_path"
		exit 1
	fi
done

required_commands=(
	"bash ./scripts/verify-profiles.sh core"
	"bash ./scripts/verify-profiles.sh security"
	"bash ./scripts/verify-profiles.sh full"
	"bash ./scripts/verify-contract-suites.sh"
	"bash ./scripts/verify-multi-registry-fallback.sh"
)

for command_text in "${required_commands[@]}"; do
	if ! grep -Fq -- "$command_text" "$DOC_GUIDE"; then
		echo "[verify-enterprise-docs] missing required command in enterprise guide: $command_text"
		exit 1
	fi
done

tmp_refs="$ROOT_DIR/.kennel_tmp/verify-enterprise-docs-script-paths.txt"
mkdir -p "$(dirname "$tmp_refs")"

grep -RhoE -- 'scripts/[A-Za-z0-9._/-]+\.sh' "$ROOT_DIR/docs" "$ROOT_DIR/README.md" | sort -u > "$tmp_refs"

while IFS= read -r script_ref; do
	[ -z "$script_ref" ] && continue
	if [ ! -f "$ROOT_DIR/$script_ref" ]; then
		echo "[verify-enterprise-docs] missing referenced script path: $script_ref"
		exit 1
	fi
done < "$tmp_refs"

echo "[verify-enterprise-docs] success"
