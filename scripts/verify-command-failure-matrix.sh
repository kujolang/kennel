#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-command-failure-matrix"
PROJECT_DIR="$TMP_DIR/project"

rm -rf "$TMP_DIR"
mkdir -p "$PROJECT_DIR"

missing_manifest_out="$TMP_DIR/missing-manifest.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add github:robertdevore/pypractice@main --project-dir "$PROJECT_DIR" >"$missing_manifest_out" 2>&1; then
	echo "[verify-command-failure-matrix] expected add to fail when kennel.toml is missing"
	exit 1
fi
if ! grep -Fq "kennel.toml" "$missing_manifest_out"; then
	echo "[verify-command-failure-matrix] missing manifest diagnostic did not mention kennel.toml"
	exit 1
fi

invalid_project_dir_out="$TMP_DIR/invalid-project-dir.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- list --project-dir "$TMP_DIR/does-not-exist" >"$invalid_project_dir_out" 2>&1; then
	echo "[verify-command-failure-matrix] expected list to fail for invalid --project-dir"
	exit 1
fi
if ! grep -Fq "Project directory does not exist" "$invalid_project_dir_out" && ! grep -Fq "Cannot get absolute path" "$invalid_project_dir_out"; then
	echo "[verify-command-failure-matrix] invalid project-dir diagnostic missing"
	exit 1
fi

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name failure-matrix --project-dir "$PROJECT_DIR" >/dev/null

if grep -Eq '^index\s*=' "$PROJECT_DIR/kennel.toml"; then
	perl -0pi -e 's/index\s*=\s*"[^"]*"/index = "index-invalid.json"/g' "$PROJECT_DIR/kennel.toml"
else
	cat >>"$PROJECT_DIR/kennel.toml" <<'EOF'

[registry]
index = "index-invalid.json"
EOF
fi
printf '{invalid-json' >"$PROJECT_DIR/index-invalid.json"

malformed_index_out="$TMP_DIR/malformed-index.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- search broken --project-dir "$PROJECT_DIR" >"$malformed_index_out" 2>&1; then
	echo "[verify-command-failure-matrix] expected search to fail for malformed index JSON"
	exit 1
fi
if ! grep -Fq "Invalid static index JSON" "$malformed_index_out"; then
	echo "[verify-command-failure-matrix] malformed index diagnostic missing"
	exit 1
fi

mkdir -p "$PROJECT_DIR/packages"
cat >"$PROJECT_DIR/index-valid.json" <<'EOF'
{
  "packages": [
    {
      "name": "brokenpkg",
      "latest": "0.1.0",
      "metadata_path": "packages/brokenpkg.json",
      "versions": [
        {
          "version": "0.1.0",
          "source": "github:robertdevore/pypractice",
          "ref": "main"
        }
      ]
    }
  ]
}
EOF
printf '{invalid-metadata' >"$PROJECT_DIR/packages/brokenpkg.json"
perl -0pi -e 's/index = "index-invalid\.json"/index = "index-valid.json"/' "$PROJECT_DIR/kennel.toml"

malformed_metadata_out="$TMP_DIR/malformed-metadata.out"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- info brokenpkg --project-dir "$PROJECT_DIR" >"$malformed_metadata_out" 2>&1; then
	echo "[verify-command-failure-matrix] expected info to fail for malformed metadata JSON"
	exit 1
fi
if ! grep -Fq "Invalid package metadata JSON" "$malformed_metadata_out"; then
	echo "[verify-command-failure-matrix] malformed metadata diagnostic missing"
	exit 1
fi

echo "[verify-command-failure-matrix] success"
