#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${1:-artifacts/security}"
MANIFEST_FILE="$OUTPUT_DIR/integrity-manifest.sha256"

mkdir -p "$OUTPUT_DIR"
: > "$MANIFEST_FILE"

TARGET_FILES=(
	"LICENSE"
	"README.md"
	"CHANGELOG.md"
	"docs/current-status-and-usage.md"
	"docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md"
	"docs/performance-benchmarking.md"
	"scripts/verify-contract-suites.sh"
	"scripts/verify-profiles.sh"
	"scripts/verify-stage-1-ci-workflow.sh"
	"scripts/verify-nightly-full-regression-workflow.sh"
	"scripts/verify-benchmark-harness.sh"
	".github/workflows/stage1-verification.yml"
	".github/workflows/nightly-full-regression.yml"
	".github/workflows/release-sbom-attestation.yml"
	"$OUTPUT_DIR/sbom.spdx.json"
)

for target_file in "${TARGET_FILES[@]}"; do
	if [ -f "$target_file" ]; then
		shasum -a 256 "$target_file" >> "$MANIFEST_FILE"
	fi
done

echo "Wrote integrity manifest: $MANIFEST_FILE"
