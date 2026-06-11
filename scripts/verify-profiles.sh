#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE="${1:-core}"
RUNNER_DRY_RUN="${RUNNER_DRY_RUN:-0}"

run_script() {
	local script_path="$1"
	if [ "$RUNNER_DRY_RUN" = "1" ]; then
		echo "[verify-profiles] (dry-run) ${script_path#$ROOT_DIR/}"
		return 0
	fi
	echo "[verify-profiles] running ${script_path#$ROOT_DIR/}"
	bash "$script_path"
}

run_core_profile() {
	if [ "$RUNNER_DRY_RUN" = "1" ]; then
		echo "[verify-profiles] (dry-run) scripts/verify-all.sh core"
		return 0
	fi
	echo "[verify-profiles] running scripts/verify-all.sh core"
	bash "$ROOT_DIR/scripts/verify-all.sh" core
}

run_stage2_profile() {
	while IFS= read -r script_path; do
		run_script "$script_path"
	done < <(find "$ROOT_DIR/scripts" -maxdepth 1 -type f -name 'verify-stage-2-*.sh' | sort)
}

run_stage3_profile() {
	while IFS= read -r script_path; do
		run_script "$script_path"
	done < <(find "$ROOT_DIR/scripts" -maxdepth 1 -type f -name 'verify-stage-3-*.sh' | sort)
}

run_security_profile() {
	run_script "$ROOT_DIR/scripts/verify-atomicity.sh"
	run_script "$ROOT_DIR/scripts/verify-pinned-refs.sh"
	run_script "$ROOT_DIR/scripts/verify-stage-3-private-package-workflow.sh"
	run_script "$ROOT_DIR/scripts/verify-stage-3-server-permission-workflow.sh"
	run_script "$ROOT_DIR/scripts/verify-stage-3-trust-signature-workflow.sh"
}

run_full_profile() {
	if [ "$RUNNER_DRY_RUN" = "1" ]; then
		echo "[verify-profiles] (dry-run) scripts/verify-all.sh all"
		return 0
	fi
	echo "[verify-profiles] running scripts/verify-all.sh all"
	bash "$ROOT_DIR/scripts/verify-all.sh" all
}

case "$PROFILE" in
	core)
		run_core_profile
		;;
	stage2)
		run_stage2_profile
		;;
	stage3)
		run_stage3_profile
		;;
	security)
		run_security_profile
		;;
	full)
		run_full_profile
		;;
	*)
		echo "Usage: ./scripts/verify-profiles.sh [core|stage2|stage3|security|full]"
		exit 1
		;;
esac

echo "[verify-profiles] success (${PROFILE})"
