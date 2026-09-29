#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-git-diagnostics"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR/bin"

# Exercise Git's two distinct failure contracts without depending on GitHub
# authentication, a personal repository, or network availability.
cat >"$TMP_DIR/bin/git" <<'GIT'
#!/usr/bin/env bash
case "$*" in
  "ls-remote https://github.com/fixture/missing.git main")
    echo 'remote: Repository not found.' >&2
    exit 128 ;;
  "ls-remote https://github.com/fixture/existing.git ref-that-does-not-exist")
    exit 0 ;;
  *) echo 'unexpected git command in diagnostics fixture' >&2; exit 99 ;;
esac
GIT
chmod +x "$TMP_DIR/bin/git"
export PATH="$TMP_DIR/bin:$PATH"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name git-diagnostics --project-dir "$TMP_DIR" >/dev/null 2>&1

missing_repo_output="$TMP_DIR/missing-repo.log"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add github:fixture/missing@main --alias missing-repo --project-dir "$TMP_DIR" >"$missing_repo_output" 2>&1; then
	echo "[verify-git-diagnostics] expected missing repository add to fail"
	exit 1
fi

grep -q "Repository not found" "$missing_repo_output"
grep -q "Verify owner/repo and repository visibility" "$missing_repo_output"

missing_ref_output="$TMP_DIR/missing-ref.log"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add github:fixture/existing@ref-that-does-not-exist --alias missing-ref --project-dir "$TMP_DIR" >"$missing_ref_output" 2>&1; then
	echo "[verify-git-diagnostics] expected missing ref add to fail"
	exit 1
fi

grep -q "No commit found for ref \`ref-that-does-not-exist\`" "$missing_ref_output"
grep -q "Verify that the ref exists and is pushed" "$missing_ref_output"

echo "[verify-git-diagnostics] success"
