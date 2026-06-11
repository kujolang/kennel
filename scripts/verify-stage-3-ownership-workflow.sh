#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-stage-3-ownership-workflow"
STORE_PATH="$TMP_DIR/token-store.json"
REGISTRY_DIR="$TMP_DIR/hosted-registry"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name ownership-demo --project-dir "$TMP_DIR" >/dev/null 2>&1
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- login --token ownership-token-123 --registry hosted-registry --user alice --store-path "$STORE_PATH" --project-dir "$TMP_DIR" >/dev/null
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- publish --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$TMP_DIR" >/dev/null

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- access owner-add ownership-demo bob --role maintainer --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$TMP_DIR" >/dev/null
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- access team-add ownership-demo core-team --permission publish --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$TMP_DIR" >/dev/null

list_output="$TMP_DIR/access-list.out"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- access list ownership-demo --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$TMP_DIR" >"$list_output"

grep -q '"package":"ownership-demo"' "$list_output"
grep -q '"user":"alice"' "$list_output"
grep -q '"user":"bob"' "$list_output"
grep -q '"team":"core-team"' "$list_output"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- access owner-remove ownership-demo bob --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$TMP_DIR" >/dev/null
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- access team-remove ownership-demo core-team --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$TMP_DIR" >/dev/null

last_owner_remove_output="$TMP_DIR/last-owner-remove.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- access owner-remove ownership-demo alice --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$TMP_DIR" >"$last_owner_remove_output" 2>&1; then
	echo "[verify-stage-3-ownership-workflow] expected removing the last owner to fail"
	exit 1
fi

grep -q 'Cannot remove the last owner' "$last_owner_remove_output"

echo "[verify-stage-3-ownership-workflow] success"
