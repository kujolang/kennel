#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW_FILE="$ROOT_DIR/.github/workflows/release-sbom-attestation.yml"

if [ ! -f "$WORKFLOW_FILE" ]; then
	echo "[verify-release-sbom-attestation-workflow] missing workflow file: $WORKFLOW_FILE"
	exit 1
fi

required_patterns=(
	"name: release-sbom-attestation"
	"workflow_dispatch:"
	"tags:"
	"- 'v*'"
	"permissions:"
	"contents: read"
	"id-token: write"
	"attestations: write"
	"runs-on: ubuntu-latest"
	"actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5"
	"anchore/sbom-action@e22c389904149dbc22b58101806040fa8d37a610"
	"bash ./scripts/generate-integrity-manifest.sh artifacts/security"
	"actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02"
	"actions/attest-build-provenance@e8998f949152b193b063cb0ec769d69d929409be"
	"subject-path: artifacts/security/sbom.spdx.json"
)

disallowed_patterns=(
	"actions/checkout@v4"
	"anchore/sbom-action@v"
	"actions/upload-artifact@v4"
	"actions/attest-build-provenance@v"
)

for pattern in "${required_patterns[@]}"; do
	if ! grep -Fq -- "$pattern" "$WORKFLOW_FILE"; then
		echo "[verify-release-sbom-attestation-workflow] missing required workflow entry: $pattern"
		exit 1
	fi
done

for pattern in "${disallowed_patterns[@]}"; do
	if grep -Fq -- "$pattern" "$WORKFLOW_FILE"; then
		echo "[verify-release-sbom-attestation-workflow] found mutable action reference: $pattern"
		exit 1
	fi
done

echo "[verify-release-sbom-attestation-workflow] success"
