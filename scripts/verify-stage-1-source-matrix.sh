#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-source-matrix"
LOCAL_AI_SDK_DIR="${LOCAL_AI_SDK_DIR:-$ROOT_DIR/examples/basic-project}"

if [ ! -d "$LOCAL_AI_SDK_DIR" ]; then
	echo "[verify-source-matrix] missing LOCAL_AI_SDK_DIR: $LOCAL_AI_SDK_DIR"
	exit 1
fi

LOCAL_AI_SDK_DIR="$(cd "$LOCAL_AI_SDK_DIR" && pwd)"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
cd "$ROOT_DIR"

echo "[verify-source-matrix] init"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name source-matrix --project-dir "$TMP_DIR"

echo "[verify-source-matrix] add local source"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add "$LOCAL_AI_SDK_DIR" --alias ai-sdk-local --project-dir "$TMP_DIR"

echo "[verify-source-matrix] add github source"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add github:robertdevore/pypractice@main --alias pypractice-github --project-dir "$TMP_DIR"

echo "[verify-source-matrix] install"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- install --project-dir "$TMP_DIR"

if [ ! -d "$TMP_DIR/kennel_packages/ai-sdk-local" ]; then
	echo "[verify-source-matrix] missing install directory: ai-sdk-local"
	exit 1
fi

if [ ! -d "$TMP_DIR/kennel_packages/pypractice-github" ]; then
	echo "[verify-source-matrix] missing install directory: pypractice-github"
	exit 1
fi

echo "[verify-source-matrix] list"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- list --project-dir "$TMP_DIR"

echo "[verify-source-matrix] validate"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- validate --project-dir "$TMP_DIR"

echo "[verify-source-matrix] update local source"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- update ai-sdk-local --project-dir "$TMP_DIR"

echo "[verify-source-matrix] update github source"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- update pypractice-github --project-dir "$TMP_DIR"

echo "[verify-source-matrix] remove local source"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- remove ai-sdk-local --project-dir "$TMP_DIR"

if [ -d "$TMP_DIR/kennel_packages/ai-sdk-local" ]; then
	echo "[verify-source-matrix] expected ai-sdk-local install directory to be removed"
	exit 1
fi

echo "[verify-source-matrix] remove github source"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- remove pypractice-github --project-dir "$TMP_DIR"

if [ -d "$TMP_DIR/kennel_packages/pypractice-github" ]; then
	echo "[verify-source-matrix] expected pypractice-github install directory to be removed"
	exit 1
fi

echo "[verify-source-matrix] list after removals"
list_output="$TMP_DIR/list-after-removals.log"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- list --project-dir "$TMP_DIR" >"$list_output" 2>&1

grep -q "No dependencies installed." "$list_output"

echo "[verify-source-matrix] success"
