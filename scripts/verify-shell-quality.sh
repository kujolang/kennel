#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERIFY_SHELLCHECK_REQUIRED="${VERIFY_SHELLCHECK_REQUIRED:-0}"
SHELLCHECK_BIN="${SHELLCHECK_BIN:-shellcheck}"
SHELLCHECK_SEVERITY="${SHELLCHECK_SEVERITY:-warning}"

scripts=(
	"$ROOT_DIR/scripts/verify-*.sh"
	"$ROOT_DIR/scripts/verify-stage-1-ci-workflow.sh"
	"$ROOT_DIR/scripts/verify-change-type-policy.sh"
	"$ROOT_DIR/scripts/benchmark-harness.sh"
	"$ROOT_DIR/scripts/generate-integrity-manifest.sh"
	"$ROOT_DIR/scripts/cleanup-local-artifacts.sh"
)

# Expand globs once while preserving explicit script paths.
expanded=()
for pattern in "${scripts[@]}"; do
	for file in $pattern; do
		expanded+=("$file")
	done
done

for script in "${expanded[@]}"; do
	if [[ ! -f "$script" ]]; then
		echo "[verify-shell-quality] missing script: $script"
		exit 1
	fi
	if ! head -n 1 "$script" | grep -Fq "#!/usr/bin/env bash"; then
		echo "[verify-shell-quality] missing bash shebang: ${script#$ROOT_DIR/}"
		exit 1
	fi
	if ! grep -Fq "set -euo pipefail" "$script"; then
		echo "[verify-shell-quality] missing strict shell options: ${script#$ROOT_DIR/}"
		exit 1
	fi
	bash -n "$script"
done

if command -v "$SHELLCHECK_BIN" >/dev/null 2>&1; then
	echo "[verify-shell-quality] running shellcheck (${SHELLCHECK_SEVERITY})"
	"$SHELLCHECK_BIN" -S "$SHELLCHECK_SEVERITY" "${expanded[@]}"
else
	if [ "$VERIFY_SHELLCHECK_REQUIRED" = "1" ]; then
		echo "[verify-shell-quality] shellcheck is required but not available"
		exit 1
	fi
	echo "[verify-shell-quality] shellcheck not found; skipping lint (set VERIFY_SHELLCHECK_REQUIRED=1 to enforce)"
fi

echo "[verify-shell-quality] success"
