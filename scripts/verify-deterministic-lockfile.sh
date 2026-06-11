#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-deterministic-lockfile"
LOCAL_SOURCE_A="${LOCAL_SOURCE_A:-$ROOT_DIR/examples/basic-project}"

create_local_package() {
	local package_dir="$1"
	local package_name="$2"
	mkdir -p "$package_dir"
	cat >"$package_dir/kennel.toml" <<EOF
[package]
name = "$package_name"
version = "0.1.0"

[kujo]
entry = "main.kujo"
sources = ["."]
EOF
	echo "print(\"$package_name\")" >"$package_dir/main.kujo"
}

if [ ! -d "$LOCAL_SOURCE_A" ]; then
	echo "[verify-deterministic-lockfile] missing LOCAL_SOURCE_A: $LOCAL_SOURCE_A"
	exit 1
fi

LOCAL_SOURCE_A="$(cd "$LOCAL_SOURCE_A" && pwd)"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

if [ -z "${LOCAL_SOURCE_B:-}" ] || [ ! -d "${LOCAL_SOURCE_B:-}" ]; then
	LOCAL_SOURCE_B="$TMP_DIR/local-source-b"
	create_local_package "$LOCAL_SOURCE_B" "kujo-ai-sdk"
fi

LOCAL_SOURCE_B="$(cd "$LOCAL_SOURCE_B" && pwd)"
mkdir -p "$TMP_DIR/order-a" "$TMP_DIR/order-b"

bootstrap_project() {
	project_dir="$1"
	first_source="$2"
	first_alias="$3"
	second_source="$4"
	second_alias="$5"

	"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name deterministic-check --project-dir "$project_dir" >/dev/null 2>&1
	"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add "$first_source" --alias "$first_alias" --project-dir "$project_dir" >/dev/null 2>&1
	"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add "$second_source" --alias "$second_alias" --project-dir "$project_dir" >/dev/null 2>&1
}

bootstrap_project "$TMP_DIR/order-a" "$LOCAL_SOURCE_B" "b-dep" "$LOCAL_SOURCE_A" "a-dep"
bootstrap_project "$TMP_DIR/order-b" "$LOCAL_SOURCE_A" "a-dep" "$LOCAL_SOURCE_B" "b-dep"

grep -v '^generated_at = ' "$TMP_DIR/order-a/kennel.lock" > "$TMP_DIR/order-a/kennel.lock.normalized"
grep -v '^generated_at = ' "$TMP_DIR/order-b/kennel.lock" > "$TMP_DIR/order-b/kennel.lock.normalized"

diff -u "$TMP_DIR/order-a/kennel.lock.normalized" "$TMP_DIR/order-b/kennel.lock.normalized" >/dev/null

echo "[verify-deterministic-lockfile] success"
