#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW_FILE="$ROOT_DIR/.github/workflows/stage1-verification.yml"

if [ ! -f "$WORKFLOW_FILE" ]; then
	echo "[verify-stage-1-ci-workflow] missing workflow file: $WORKFLOW_FILE"
	exit 1
fi

required_patterns=(
	"name: stage1-verification"
	"permissions:"
	"contents: read"
	"build-kujo-runtime"
	"actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5"
	"dtolnay/rust-toolchain@3c5f7ea28cd621ae0bf5283f0e981fb97b8a7af9"
	"toolchain: stable"
	"actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02"
	"actions/download-artifact@v4"
	"name: kujo-runtime-linux"
	"needs: build-kujo-runtime"
	"static-script-quality"
	"macos-smoke"
	"runs-on: macos-latest"
	"bash ./scripts/verify-macos-smoke.sh"
	"Install shellcheck"
	"sudo apt-get install -y shellcheck"
	"VERIFY_SHELLCHECK_REQUIRED: '1'"
	"SHELLCHECK_SEVERITY: warning"
	"bash ./scripts/verify-shell-quality.sh"
	"bash ./scripts/verify-contract-suites.sh"
	"bash ./scripts/verify-stage-1.sh"
	"bash ./scripts/verify-stage-1-source-matrix.sh"
	"bash ./scripts/verify-cli-messages.sh"
	"bash ./scripts/verify-git-diagnostics.sh"
	"bash ./scripts/verify-pinned-refs.sh"
	"bash ./scripts/verify-stale-lockfile.sh"
	"bash ./scripts/verify-deterministic-lockfile.sh"
	"bash ./scripts/verify-kujo-native-direction.sh"
	"bash ./scripts/verify-change-type-policy.sh"
	"Verify benchmark harness dry-run contract"
	"BENCH_DRY_RUN: '1'"
	"bash ./scripts/verify-benchmark-harness.sh"
	"- security"
	"set -euo pipefail"
)

disallowed_patterns=(
	"actions/checkout@v4"
	"dtolnay/rust-toolchain@stable"
)

for pattern in "${required_patterns[@]}"; do
	if ! grep -Fq -- "$pattern" "$WORKFLOW_FILE"; then
		echo "[verify-stage-1-ci-workflow] missing required workflow entry: $pattern"
		exit 1
	fi
done

for pattern in "${disallowed_patterns[@]}"; do
	if grep -Fq -- "$pattern" "$WORKFLOW_FILE"; then
		echo "[verify-stage-1-ci-workflow] found mutable action reference: $pattern"
		exit 1
	fi
done

build_count="$(grep -Fc 'run: cargo build --release --bin kujo' "$WORKFLOW_FILE")"
if [ "$build_count" -ne 2 ]; then
	echo "[verify-stage-1-ci-workflow] expected exactly 2 Kujo build steps (shared Linux + macOS), found: $build_count"
	exit 1
fi

toolchain_count="$(grep -Fc 'toolchain: stable' "$WORKFLOW_FILE")"
if [[ "$toolchain_count" -ne 2 ]]; then
	echo "[verify-stage-1-ci-workflow] expected exactly 2 explicit stable Rust toolchain inputs, found: $toolchain_count"
	exit 1
fi

echo "[verify-stage-1-ci-workflow] success"
