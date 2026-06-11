#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-semver-range-resolution"
RANGE_SOURCE="github:pallets/itsdangerous@^2.1.0"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

ENABLED_DIR="$TMP_DIR/enabled"
mkdir -p "$ENABLED_DIR"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name semver-enabled --project-dir "$ENABLED_DIR" >/dev/null

python3 - "$ENABLED_DIR/kennel.toml" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
raw = path.read_text(encoding="utf-8")
updated = raw.replace("semver_ranges = false", "semver_ranges = true", 1)
if updated == raw:
    raise SystemExit("failed to enable [policy.resolution].semver_ranges")
path.write_text(updated, encoding="utf-8")
PY

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add "$RANGE_SOURCE" --alias semver_dep --project-dir "$ENABLED_DIR" >/dev/null

grep -q 'name = "semver_dep"' "$ENABLED_DIR/kennel.lock"
grep -q 'requested_kind = "range"' "$ENABLED_DIR/kennel.lock"
grep -Eq 'resolved_ref = "2\.' "$ENABLED_DIR/kennel.lock"

update_log="$ENABLED_DIR/update.log"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- update semver_dep --project-dir "$ENABLED_DIR" >"$update_log" 2>&1
grep -q 'Updated semver_dep to commit' "$update_log"

DISABLED_DIR="$TMP_DIR/disabled"
mkdir -p "$DISABLED_DIR"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name semver-disabled --project-dir "$DISABLED_DIR" >/dev/null

disabled_log="$DISABLED_DIR/add.log"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add "$RANGE_SOURCE" --alias semver_dep --project-dir "$DISABLED_DIR" >"$disabled_log" 2>&1; then
	echo "[verify-semver-range-resolution] expected add with semver range to fail when semver range mode is disabled"
	exit 1
fi

grep -q 'No commit found for ref `\^2.1.0`' "$disabled_log"

echo "[verify-semver-range-resolution] success"