#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-stage-1"
AI_SDK_DIR="${AI_SDK_DIR:-$ROOT_DIR/examples/basic-project}"
MCP_DIR="${MCP_DIR:-$TMP_DIR/kujo-mcp}"

create_local_package() {
	local package_dir="$1"
	local package_name="$2"
	mkdir -p "$package_dir"
	cat >"$package_dir/kennel.toml" <<EOF
[package]
name = "$package_name"
version = "0.1.0"
description = "Local Stage 1 verification fixture"

[kujo]
entry = "main.kujo"
sources = ["."]

[dependencies]
EOF
	echo "print(\"$package_name\")" >"$package_dir/main.kujo"
}

if [ ! -d "$AI_SDK_DIR" ]; then
	echo "[verify] missing AI_SDK_DIR: $AI_SDK_DIR"
	exit 1
fi

AI_SDK_DIR="$(cd "$AI_SDK_DIR" && pwd)"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
cd "$ROOT_DIR"

if [ ! -d "$MCP_DIR" ]; then
	create_local_package "$MCP_DIR" "mcp"
fi
MCP_DIR="$(cd "$MCP_DIR" && pwd)"

echo "[verify] init"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name kennel-demo --project-dir "$TMP_DIR"

echo "[verify] add local ai-sdk"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add "$AI_SDK_DIR" --alias ai-sdk --project-dir "$TMP_DIR"

echo "[verify] add local mcp"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add "$MCP_DIR" --alias mcp --project-dir "$TMP_DIR"

echo "[verify] install"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- install --project-dir "$TMP_DIR"

echo "[verify] list"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- list --project-dir "$TMP_DIR"

echo "[verify] validate"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- validate --project-dir "$TMP_DIR"

echo "[verify] lockfile path: $TMP_DIR/kennel.lock"
echo "[verify] success"
