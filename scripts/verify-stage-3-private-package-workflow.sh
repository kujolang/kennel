#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-stage-3-private-package-workflow"
STORE_PATH="$TMP_DIR/token-store.json"
REGISTRY_DIR="$TMP_DIR/hosted-registry"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name private-demo --project-dir "$TMP_DIR" >/dev/null 2>&1
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- login --token private-token-alice --registry hosted-registry --user alice --store-path "$STORE_PATH" --project-dir "$TMP_DIR" >/dev/null

publish_output="$TMP_DIR/publish-private.out"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- publish --private --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$TMP_DIR" >"$publish_output"

grep -q 'Visibility: private' "$publish_output"
grep -q '"visibility":"private"' "$REGISTRY_DIR/packages/private-demo.json"
grep -q '"private":true' "$REGISTRY_DIR/packages/private-demo.json"
grep -q '"private":true' "$REGISTRY_DIR/index.json"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- login --token private-token-bob --registry hosted-registry --user bob --store-path "$STORE_PATH" --project-dir "$TMP_DIR" >/dev/null

visibility_non_owner_output="$TMP_DIR/visibility-non-owner.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- visibility private-demo public --registry hosted-registry --user bob --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$TMP_DIR" >"$visibility_non_owner_output" 2>&1; then
	echo "[verify-stage-3-private-package-workflow] expected non-owner visibility change to fail"
	exit 1
fi

grep -q 'Only package owners can update visibility' "$visibility_non_owner_output"

publish_non_owner_output="$TMP_DIR/publish-non-owner.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- publish --private --registry hosted-registry --user bob --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$TMP_DIR" >"$publish_non_owner_output" 2>&1; then
	echo "[verify-stage-3-private-package-workflow] expected non-owner publish on private package to fail"
	exit 1
fi

grep -q 'Only package owners can publish new versions' "$publish_non_owner_output"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- visibility private-demo public --registry hosted-registry --user alice --store-path "$STORE_PATH" --registry-dir "$REGISTRY_DIR" --project-dir "$TMP_DIR" >/dev/null

grep -q '"visibility":"public"' "$REGISTRY_DIR/packages/private-demo.json"
grep -q '"private":false' "$REGISTRY_DIR/index.json"

echo "[verify-stage-3-private-package-workflow] success"
