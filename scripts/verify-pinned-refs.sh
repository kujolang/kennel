#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-pinned-refs"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

PINNED_COMMIT="$(git ls-remote https://github.com/robertdevore/pypractice.git main | awk 'NR==1 {print $1}')"
if [ -z "$PINNED_COMMIT" ]; then
	echo "[verify-pinned-refs] failed to resolve commit for robertdevore/pypractice@main"
	exit 1
fi

cat >"$TMP_DIR/kennel.toml" <<EOF
[package]
name = "pinned-refs"
version = "0.1.0"

[kujo]
entry = "main.kujo"
sources = ["."]

[dependencies]
commit-pin = { source = "github:robertdevore/pypractice", commit = "$PINNED_COMMIT" }
tag-pin = { source = "github:robertdevore/pypractice", tag = "main" }
version-pin = { source = "github:robertdevore/pypractice", version = "main" }
EOF

echo "[verify-pinned-refs] install"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- install --project-dir "$TMP_DIR"

cp "$TMP_DIR/kennel.lock" "$TMP_DIR/kennel.lock.before"

update_output="$TMP_DIR/update.log"
echo "[verify-pinned-refs] update"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- update --project-dir "$TMP_DIR" >"$update_output" 2>&1

grep -q "Skipped commit-pin because it is pinned to commit" "$update_output"
grep -q "Skipped tag-pin because it is pinned to tag" "$update_output"
grep -q "Skipped version-pin because it is pinned to version" "$update_output"

grep -v '^generated_at = ' "$TMP_DIR/kennel.lock.before" >"$TMP_DIR/kennel.lock.before.normalized"
grep -v '^generated_at = ' "$TMP_DIR/kennel.lock" >"$TMP_DIR/kennel.lock.normalized"
diff -u "$TMP_DIR/kennel.lock.before.normalized" "$TMP_DIR/kennel.lock.normalized" >/dev/null

echo "[verify-pinned-refs] success"
