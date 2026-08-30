#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-all}"

run_script() {
	local script_path="$1"
	echo "[verify-all] running ${script_path#$ROOT_DIR/}"
	bash "$script_path"
}

if [[ "$MODE" == "core" ]]; then
	run_script "$ROOT_DIR/scripts/verify-atomic-persistence.sh"
	run_script "$ROOT_DIR/scripts/verify-cli-messages.sh"
	run_script "$ROOT_DIR/scripts/verify-git-diagnostics.sh"
	run_script "$ROOT_DIR/scripts/verify-pinned-refs.sh"
	run_script "$ROOT_DIR/scripts/verify-stale-lockfile.sh"
	run_script "$ROOT_DIR/scripts/verify-deterministic-lockfile.sh"
	run_script "$ROOT_DIR/scripts/verify-transitive-resolution.sh"
	run_script "$ROOT_DIR/scripts/verify-semver-range-resolution.sh"
	run_script "$ROOT_DIR/scripts/verify-multi-registry-fallback.sh"
	run_script "$ROOT_DIR/scripts/verify-enterprise-docs.sh"
	run_script "$ROOT_DIR/scripts/verify-architecture-flow-maps.sh"
	run_script "$ROOT_DIR/scripts/verify-ci-quality-report-workflow.sh"
	run_script "$ROOT_DIR/scripts/verify-kujo-native-direction.sh"
	run_script "$ROOT_DIR/scripts/verify-benchmark-harness.sh"
	run_script "$ROOT_DIR/scripts/verify-release-sbom-attestation-workflow.sh"
	echo "[verify-all] success (core)"
	exit 0
fi

if [[ "$MODE" != "all" ]]; then
	echo "Usage: ./scripts/verify-all.sh [all|core]"
	exit 1
fi

while IFS= read -r script_path; do
	if [[ "$script_path" == "$ROOT_DIR/scripts/verify-all.sh" ]]; then
		continue
	fi
	run_script "$script_path"
done < <(find "$ROOT_DIR/scripts" -maxdepth 1 -type f -name 'verify-*.sh' | sort)

echo "[verify-all] success (all)"
