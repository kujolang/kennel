#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
POLICY_FILE="$ROOT_DIR/docs/change-type-validation-policy.md"
RUNBOOK_FILE="$ROOT_DIR/docs/maintainer-runbook.md"
WORKFLOW_FILE="$ROOT_DIR/.github/workflows/stage1-verification.yml"

if [ ! -f "$POLICY_FILE" ]; then
	echo "[verify-change-type-policy] missing policy file: $POLICY_FILE"
	exit 1
fi

if [ ! -f "$RUNBOOK_FILE" ]; then
	echo "[verify-change-type-policy] missing runbook file: $RUNBOOK_FILE"
	exit 1
fi

if [ ! -f "$WORKFLOW_FILE" ]; then
	echo "[verify-change-type-policy] missing workflow file: $WORKFLOW_FILE"
	exit 1
fi

required_policy_patterns=(
	'security changes: `security` + `core`'
	'architecture/refactor changes: `stage2` + `core`'
	'feature changes (hosted/API/user-facing): `stage3` + `core`'
	'docs-only changes: `core`'
	'release-candidate cut: `full`'
)

for pattern in "${required_policy_patterns[@]}"; do
	if ! grep -Fq "$pattern" "$POLICY_FILE"; then
		echo "[verify-change-type-policy] missing policy entry: $pattern"
		exit 1
	fi
done

if ! grep -Fq "## Validation Policy By Change Type" "$RUNBOOK_FILE"; then
	echo "[verify-change-type-policy] runbook is missing validation policy section"
	exit 1
fi

if ! grep -Fq "bash ./scripts/verify-change-type-policy.sh" "$WORKFLOW_FILE"; then
	echo "[verify-change-type-policy] workflow is missing policy verification step"
	exit 1
fi

echo "[verify-change-type-policy] success"
