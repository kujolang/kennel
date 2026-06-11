#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-stale-lockfile"
LOCAL_SOURCE_DIR="${LOCAL_SOURCE_DIR:-$ROOT_DIR/examples/basic-project}"

if [ ! -d "$LOCAL_SOURCE_DIR" ]; then
	echo "[verify-stale-lockfile] missing LOCAL_SOURCE_DIR: $LOCAL_SOURCE_DIR"
	exit 1
fi

LOCAL_SOURCE_DIR="$(cd "$LOCAL_SOURCE_DIR" && pwd)"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

echo "[verify-stale-lockfile] init"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name stale-lock --project-dir "$TMP_DIR"

echo "[verify-stale-lockfile] add local dependency"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add "$LOCAL_SOURCE_DIR" --alias local-fixture --project-dir "$TMP_DIR"

cp "$TMP_DIR/kennel.lock" "$TMP_DIR/kennel.lock.before"

echo "[verify-stale-lockfile] inject manifest drift"
echo 'drifted = { source = "github:robertdevore/pypractice", ref = "main" }' >>"$TMP_DIR/kennel.toml"

echo "[verify-stale-lockfile] install from lockfile"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- install --project-dir "$TMP_DIR"

diff -u "$TMP_DIR/kennel.lock.before" "$TMP_DIR/kennel.lock" >/dev/null

if [ -d "$TMP_DIR/kennel_packages/drifted" ]; then
	echo "[verify-stale-lockfile] unexpected drifted package install detected"
	exit 1
fi

list_output="$TMP_DIR/list.log"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- list --project-dir "$TMP_DIR" >"$list_output" 2>&1

if grep -q "drifted" "$list_output"; then
	echo "[verify-stale-lockfile] stale lockfile regression: drifted dependency appeared in lock-backed list output"
	exit 1
fi

echo "[verify-stale-lockfile] success"
