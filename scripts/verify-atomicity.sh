#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-atomicity"
PROJECT_DIR="$TMP_DIR/project"
LOCAL_DEP_DIR="$TMP_DIR/local-fixture"
REGISTRY_DIR="$TMP_DIR/hosted-registry"
TOKEN_STORE="$TMP_DIR/tokens.json"
PAIR_PROJECT_DIR="$TMP_DIR/pair-project"
PAIR_REGISTRY_DIR="$TMP_DIR/pair-registry"
PAIR_CHECK_SCRIPT="$ROOT_DIR/.pair-rollback-check.kujo"

rm -rf "$TMP_DIR"
mkdir -p "$PROJECT_DIR" "$LOCAL_DEP_DIR" "$REGISTRY_DIR/packages"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name atomicity-demo --project-dir "$PROJECT_DIR" >/dev/null

cp "$PROJECT_DIR/kennel.toml" "$TMP_DIR/manifest-before-add.toml"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add github:kujolang/this-should-not-exist-atomicity@main --project-dir "$PROJECT_DIR" >"$TMP_DIR/add-fail.out" 2>&1; then
	echo "[verify-atomicity] expected add failure for missing repository"
	exit 1
fi

cmp -s "$PROJECT_DIR/kennel.toml" "$TMP_DIR/manifest-before-add.toml"
if [[ -f "$PROJECT_DIR/kennel.lock" ]]; then
	echo "[verify-atomicity] kennel.lock should not be created when add fails"
	exit 1
fi

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name local-fixture --project-dir "$LOCAL_DEP_DIR" >/dev/null
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add "$LOCAL_DEP_DIR" --alias local-fixture --project-dir "$PROJECT_DIR" >/dev/null

cp "$PROJECT_DIR/kennel.toml" "$TMP_DIR/manifest-before-hosted.toml"
cp "$PROJECT_DIR/kennel.lock" "$TMP_DIR/lock-before-hosted.lock"

cmp -s "$PROJECT_DIR/kennel.toml" "$TMP_DIR/manifest-before-hosted.toml"
cmp -s "$PROJECT_DIR/kennel.lock" "$TMP_DIR/lock-before-hosted.lock"

cat > "$REGISTRY_DIR/index.json" <<EOF
{
  "schema_version": 1,
  "generated_at": "2026-05-20T00:00:00Z",
  "packages": [
    {
      "name": "brokenpkg",
      "latest": "0.1.0",
      "metadata_path": "packages/brokenpkg.json",
      "versions": [
        {
          "version": "0.1.0",
          "source": "file:$TMP_DIR/does-not-exist",
          "ref": "0.1.0"
        }
      ]
    }
  ]
}
EOF

cat > "$REGISTRY_DIR/packages/brokenpkg.json" <<EOF
{
  "name": "brokenpkg",
  "latest": "0.1.0",
  "visibility": "public",
  "access": {"owners": [{"user": "alice", "role": "owner"}], "teams": []},
  "versions": [
    {
      "version": "0.1.0",
      "source": "file:$TMP_DIR/does-not-exist",
      "ref": "0.1.0"
    }
  ]
}
EOF

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- login --token atomicity-token --registry hosted --user alice --store-path "$TOKEN_STORE" --project-dir "$PROJECT_DIR" >/dev/null

if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- install-hosted brokenpkg --registry hosted --user alice --store-path "$TOKEN_STORE" --registry-dir "$REGISTRY_DIR" --project-dir "$PROJECT_DIR" >"$TMP_DIR/install-hosted-fail.out" 2>&1; then
	echo "[verify-atomicity] expected install-hosted failure for invalid source"
	exit 1
fi

cmp -s "$PROJECT_DIR/kennel.toml" "$TMP_DIR/manifest-before-hosted.toml"
cmp -s "$PROJECT_DIR/kennel.lock" "$TMP_DIR/lock-before-hosted.lock"

cat > "$PAIR_CHECK_SCRIPT" <<EOF
from future_resolvers import publish_package
from manifest import default_manifest

func main() {
  project_dir := "$PAIR_PROJECT_DIR"
  registry_dir := "$PAIR_REGISTRY_DIR"
  execute_status("rm -rf '" + project_dir + "'")
  execute_status("rm -rf '" + registry_dir + "'")
  execute_status("mkdir -p '" + project_dir + "'")

  initial_manifest := default_manifest("pair-atomicity-demo")
  initial_publish := publish_package(project_dir, {
    "manifest": initial_manifest,
    "registry": "hosted-registry",
    "user": "alice",
    "token": "pair-token-123",
    "registry_dir": registry_dir,
    "visibility": "public"
  })
  if initial_publish["ok"] == false {
    print("PAIR_ATOMICITY_FAIL initial publish")
    exit(1)
  }

  index_path := registry_dir + "/index.json"
  metadata_path := registry_dir + "/packages/pair-atomicity-demo.json"
  index_before := read_file(index_path)
  metadata_before := read_file(metadata_path)

  next_manifest := default_manifest("pair-atomicity-demo")
  next_package := next_manifest["package"]
  next_package["version"] := "0.1.1"
  next_manifest["package"] := next_package

  failing_publish := publish_package(project_dir, {
    "manifest": next_manifest,
    "registry": "hosted-registry",
    "user": "alice",
    "token": "pair-token-123",
    "registry_dir": registry_dir,
    "visibility": "public",
    "test_fail_after_first_write": true
  })
  if failing_publish["ok"] == true {
    print("PAIR_ATOMICITY_FAIL expected failure")
    exit(1)
  }
  if index_of(to_string(failing_publish["error"]), "Failed to persist paired registry state") < 0 {
    print("PAIR_ATOMICITY_FAIL missing rollback error")
    exit(1)
  }
  if read_file(index_path) != index_before {
    print("PAIR_ATOMICITY_FAIL index drifted")
    exit(1)
  }
  if read_file(metadata_path) != metadata_before {
    print("PAIR_ATOMICITY_FAIL metadata drifted")
    exit(1)
  }

  print("PAIR_ATOMICITY_OK")
}

main()
EOF

if ! "$KUJO_BIN" run "$PAIR_CHECK_SCRIPT" --interpreter >"$TMP_DIR/pair-rollback.out" 2>&1; then
  echo "[verify-atomicity] paired rollback scenario failed"
  cat "$TMP_DIR/pair-rollback.out"
  rm -f "$PAIR_CHECK_SCRIPT"
  exit 1
fi

if ! grep -q "PAIR_ATOMICITY_OK" "$TMP_DIR/pair-rollback.out"; then
  echo "[verify-atomicity] paired rollback confirmation missing"
  cat "$TMP_DIR/pair-rollback.out"
  rm -f "$PAIR_CHECK_SCRIPT"
  exit 1
fi

rm -f "$PAIR_CHECK_SCRIPT"

echo "[verify-atomicity] success"
