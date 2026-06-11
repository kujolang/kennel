#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$ROOT_DIR/scripts/verify-profiles.sh"

assert_contains() {
	local haystack="$1"
	local needle="$2"
	if ! grep -F "$needle" >/dev/null <<<"$haystack"; then
		echo "[verify-profile-runner] missing expected text: $needle"
		exit 1
	fi
}

assert_profile() {
	local profile="$1"
	local expected="$2"
	output="$(RUNNER_DRY_RUN=1 bash "$RUNNER" "$profile")"
	assert_contains "$output" "$expected"
	assert_contains "$output" "[verify-profiles] success (${profile})"
}

assert_profile "core" "scripts/verify-all.sh core"
assert_profile "stage2" "scripts/verify-stage-2-deterministic-lockfile.sh"
assert_profile "stage3" "scripts/verify-stage-3-login-workflow.sh"
assert_profile "security" "scripts/verify-atomicity.sh"
assert_profile "full" "scripts/verify-all.sh all"

if RUNNER_DRY_RUN=1 bash "$RUNNER" "bad-profile" >/dev/null 2>&1; then
	echo "[verify-profile-runner] expected bad-profile to fail"
	exit 1
fi

echo "[verify-profile-runner] success"
