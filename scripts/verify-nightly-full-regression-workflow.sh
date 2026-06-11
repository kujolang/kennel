#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW_FILE="$ROOT_DIR/.github/workflows/nightly-full-regression.yml"

if [ ! -f "$WORKFLOW_FILE" ]; then
	echo "[verify-nightly-full-regression-workflow] missing workflow file: $WORKFLOW_FILE"
	exit 1
fi

required_patterns=(
	"name: nightly-full-regression"
	"schedule:"
	"workflow_dispatch:"
	"permissions:"
	"contents: read"
	"runs-on: ubuntu-latest"
	"bash ./scripts/verify-profiles.sh full"
	"actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5"
	"dtolnay/rust-toolchain@3c5f7ea28cd621ae0bf5283f0e981fb97b8a7af9"
	"actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02"
	"if: always()"
	"nightly-full-regression-artifacts"
)

disallowed_patterns=(
	"actions/checkout@v4"
	"dtolnay/rust-toolchain@stable"
	"actions/upload-artifact@v4"
)

for pattern in "${required_patterns[@]}"; do
	if ! grep -Fq -- "$pattern" "$WORKFLOW_FILE"; then
		echo "[verify-nightly-full-regression-workflow] missing required workflow entry: $pattern"
		exit 1
	fi
done

for pattern in "${disallowed_patterns[@]}"; do
	if grep -Fq -- "$pattern" "$WORKFLOW_FILE"; then
		echo "[verify-nightly-full-regression-workflow] found mutable action reference: $pattern"
		exit 1
	fi
done

echo "[verify-nightly-full-regression-workflow] success"
