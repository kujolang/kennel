#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-stage-3-authenticated-publish-install-workflow"
PUBLISHER_DIR="$TMP_DIR/publisher"
CONSUMER_DIR="$TMP_DIR/consumer"
ALICE_STORE="$TMP_DIR/alice-tokens.json"
BOB_STORE="$TMP_DIR/bob-tokens.json"
REGISTRY_DIR="$TMP_DIR/hosted-registry"

rm -rf "$TMP_DIR"
mkdir -p "$PUBLISHER_DIR" "$CONSUMER_DIR"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name secure-lib --project-dir "$PUBLISHER_DIR" >/dev/null 2>&1

publish_no_auth_output="$TMP_DIR/publish-no-auth.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- publish --private --registry hosted-registry --user alice --store-path "$ALICE_STORE" --registry-dir "$REGISTRY_DIR" --project-dir "$PUBLISHER_DIR" >"$publish_no_auth_output" 2>&1; then
	echo "[verify-stage-3-authenticated-publish-install-workflow] expected publish to fail without login"
	exit 1
fi

grep -q 'No auth token is configured' "$publish_no_auth_output"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- login --token stage3-auth-alice --registry hosted-registry --user alice --store-path "$ALICE_STORE" --project-dir "$PUBLISHER_DIR" >/dev/null
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- publish --private --registry hosted-registry --user alice --store-path "$ALICE_STORE" --registry-dir "$REGISTRY_DIR" --project-dir "$PUBLISHER_DIR" >/dev/null

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name secure-consumer --project-dir "$CONSUMER_DIR" >/dev/null 2>&1

install_no_auth_output="$TMP_DIR/install-no-auth.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- install-hosted secure-lib --registry hosted-registry --user alice --store-path "$ALICE_STORE.missing" --registry-dir "$REGISTRY_DIR" --project-dir "$CONSUMER_DIR" >"$install_no_auth_output" 2>&1; then
	echo "[verify-stage-3-authenticated-publish-install-workflow] expected install-hosted to fail without login"
	exit 1
fi

grep -q 'No auth token is configured' "$install_no_auth_output"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- login --token stage3-auth-bob --registry hosted-registry --user bob --store-path "$BOB_STORE" --project-dir "$CONSUMER_DIR" >/dev/null

install_non_owner_output="$TMP_DIR/install-non-owner.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- install-hosted secure-lib --registry hosted-registry --user bob --store-path "$BOB_STORE" --registry-dir "$REGISTRY_DIR" --project-dir "$CONSUMER_DIR" >"$install_non_owner_output" 2>&1; then
	echo "[verify-stage-3-authenticated-publish-install-workflow] expected non-owner private hosted install to fail"
	exit 1
fi

grep -q 'requires owner access' "$install_non_owner_output"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- install-hosted secure-lib --registry hosted-registry --user alice --store-path "$ALICE_STORE" --registry-dir "$REGISTRY_DIR" --project-dir "$CONSUMER_DIR" >/dev/null

grep -q '\[dependencies.secure-lib\]' "$CONSUMER_DIR/kennel.toml"
grep -q '\[\[package\]\]' "$CONSUMER_DIR/kennel.lock"
grep -q 'name = "secure-lib"' "$CONSUMER_DIR/kennel.lock"

echo "[verify-stage-3-authenticated-publish-install-workflow] success"
