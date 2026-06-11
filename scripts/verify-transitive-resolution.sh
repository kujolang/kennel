#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-transitive-resolution"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

create_package() {
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

LEAF_DIR="$TMP_DIR/leaf_pkg"
MIDDLE_DIR="$TMP_DIR/middle_pkg"
create_package "$LEAF_DIR" "leaf"
create_package "$MIDDLE_DIR" "middle"

cat >>"$MIDDLE_DIR/kennel.toml" <<EOF

[dependencies]
leaf = { path = "$LEAF_DIR" }
EOF

APP_DIR="$TMP_DIR/app"
mkdir -p "$APP_DIR"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name transitive-app --project-dir "$APP_DIR" >/dev/null
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add "$MIDDLE_DIR" --alias middle --project-dir "$APP_DIR" >/dev/null

grep -q 'name = "middle"' "$APP_DIR/kennel.lock"
grep -q 'name = "leaf"' "$APP_DIR/kennel.lock"

if [ ! -d "$APP_DIR/kennel_packages/middle" ]; then
	echo "[verify-transitive-resolution] expected middle package install"
	exit 1
fi
if [ ! -d "$APP_DIR/kennel_packages/leaf" ]; then
	echo "[verify-transitive-resolution] expected transitive leaf package install"
	exit 1
fi

cp "$APP_DIR/kennel.lock" "$APP_DIR/kennel.lock.before"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- install --project-dir "$APP_DIR" >/dev/null

grep -v '^generated_at = ' "$APP_DIR/kennel.lock.before" >"$APP_DIR/kennel.lock.before.normalized"
grep -v '^generated_at = ' "$APP_DIR/kennel.lock" >"$APP_DIR/kennel.lock.normalized"
diff -u "$APP_DIR/kennel.lock.before.normalized" "$APP_DIR/kennel.lock.normalized" >/dev/null

SHARED_A_DIR="$TMP_DIR/shared_a"
SHARED_B_DIR="$TMP_DIR/shared_b"
PKG_A_DIR="$TMP_DIR/pkg_a"
PKG_B_DIR="$TMP_DIR/pkg_b"

create_package "$SHARED_A_DIR" "shared"
create_package "$SHARED_B_DIR" "shared"
create_package "$PKG_A_DIR" "pkg_a"
create_package "$PKG_B_DIR" "pkg_b"

cat >>"$PKG_A_DIR/kennel.toml" <<EOF

[dependencies]
shared = { path = "$SHARED_A_DIR" }
EOF

cat >>"$PKG_B_DIR/kennel.toml" <<EOF

[dependencies]
shared = { path = "$SHARED_B_DIR" }
EOF

CONFLICT_DIR="$TMP_DIR/conflict-app"
mkdir -p "$CONFLICT_DIR"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name transitive-conflict --project-dir "$CONFLICT_DIR" >/dev/null
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add "$PKG_A_DIR" --alias pkg_a --project-dir "$CONFLICT_DIR" >/dev/null

conflict_log="$CONFLICT_DIR/conflict.log"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add "$PKG_B_DIR" --alias pkg_b --project-dir "$CONFLICT_DIR" >"$conflict_log" 2>&1; then
	echo "[verify-transitive-resolution] expected conflicting transitive dependency add to fail"
	exit 1
fi

grep -q 'Dependency conflict for `shared`' "$conflict_log"

echo "[verify-transitive-resolution] success"