#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
runtime="${KUJO_BIN:-kujo}"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/kennel-git-commit.XXXXXXXX")"
trap 'rm -rf "$scratch"' EXIT
source="$scratch/source"
consumer="$scratch/consumer"
git init --quiet --initial-branch=main "$source"
git -C "$source" config user.name 'Kennel fixture'
git -C "$source" config user.email 'fixture@example.invalid'
git -C "$source" config commit.gpgsign false
git -C "$source" config tag.gpgsign false

cat > "$source/kennel.toml" <<'TOML'
[package]
name = "fixture"
version = "1.0.0"
TOML
git -C "$source" add kennel.toml
git -C "$source" commit --quiet -m 'First fixture version'
git -C "$source" tag v1.0.0
first_commit="$(git -C "$source" rev-parse HEAD)"
printf 'second fixture version\n' > "$source/version.txt"
cat > "$source/kennel.toml" <<'TOML'
[package]
name = "fixture"
version = "1.1.0"
TOML
git -C "$source" add version.txt kennel.toml
git -C "$source" commit --quiet -m 'Second fixture version'
git -C "$source" tag -a v1.1.0 -m 'Annotated release'
expected="$(git -C "$source" rev-parse HEAD)"
tag_object="$(git -C "$source" rev-parse refs/tags/v1.1.0)"
test "$expected" != "$tag_object"

export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="url.file://$source.insteadOf"
export GIT_CONFIG_VALUE_0='https://github.com/kennel-fixtures/annotated.git'

mkdir "$consumer"
cat > "$consumer/kennel.toml" <<'TOML'
[package]
name = "consumer"
version = "0.1.0"

[policy.resolution]
semver_ranges = true

[dependencies]
annotated = { source = "github:kennel-fixtures/annotated", tag = "v1.1.0" }
explicit = { source = "github:kennel-fixtures/annotated", ref = "refs/tags/v1.1.0" }
lightweight = { source = "github:kennel-fixtures/annotated", tag = "v1.0.0" }
branch = { source = "github:kennel-fixtures/annotated", ref = "main" }
range = { source = "github:kennel-fixtures/annotated", range = "^1.0.0" }
TOML

kennel() {
    "$runtime" run "$root/kennel.kujo" --interpreter -- "$@" --project-dir "$consumer"
}
kennel install
python3 - "$consumer/kennel.lock" "$expected" "$first_commit" <<'PY'
import pathlib
import re
import sys

lock, expected, first = sys.argv[1:]
packages = {}
for section in pathlib.Path(lock).read_text().split("[[package]]")[1:]:
    fields = dict(re.findall(r'^([a-z_]+) = "([^"]*)"$', section, re.M))
    packages[fields["name"]] = fields
for name in ("annotated", "explicit", "branch", "range"):
    actual = packages[name]["resolved_commit"]
    assert actual == expected, f"{name} locked {actual} instead of {expected}"
assert packages["lightweight"]["resolved_commit"] == first
assert packages["range"]["resolved_ref"] == "v1.1.0"
PY
test "$(cat "$consumer/kennel_packages/annotated/version.txt")" = 'second fixture version'

# A range must identify the commit before installation, while the remote result
# still identifies the selected source. The lock check alone misses this.
cat > "$scratch/resolve-range.kujo" <<'KUJO'
from src.dependency_spec import parse_source_reference
from src.resolver import resolve_dependency_with_policy

spec := parse_source_reference("github:kennel-fixtures/annotated@^1.0.0")
resolution := resolve_dependency_with_policy("fixture", spec, {"semver_ranges": true})
if resolution["ok"] == false {
    throw(resolution["error"])
}
print(resolution["resolved"]["resolved_commit"])
KUJO
test "$(cd "$root" && "$runtime" run "$scratch/resolve-range.kujo" --interpreter)" = "$expected"

kennel install
kennel validate

# Older locks may store the exact annotated tag object. Keep those replayable.
cp "$consumer/kennel.lock" "$scratch/current.lock"
python3 - "$consumer/kennel.lock" "$expected" "$tag_object" <<'PY'
import pathlib
import sys

lock, current, legacy = sys.argv[1:]
path = pathlib.Path(lock)
text = path.read_text()
path.write_text(text.replace(f'resolved_commit = "{current}"',
                             f'resolved_commit = "{legacy}"', 1))
PY
kennel install
test "$(cat "$consumer/kennel_packages/annotated/version.txt")" = 'second fixture version'

# A retired tag still has a reachable pinned commit. Locked replay can fall
# back from the shallow tag clone to a direct fetch of that commit.
cp "$scratch/current.lock" "$consumer/kennel.lock"
git -C "$source" tag -d v1.1.0 >/dev/null
kennel install
test "$(cat "$consumer/kennel_packages/range/version.txt")" = 'second fixture version'

# An immutable revision can be installed without downloading its history.
consumer="$scratch/pinned-consumer"
mkdir "$consumer"
kennel init --name pinned-consumer
export GIT_TRACE2_EVENT="$scratch/exact-fetch.jsonl"
kennel add "github:kennel-fixtures/annotated@$first_commit" --alias fixed
unset GIT_TRACE2_EVENT
python3 - "$scratch/exact-fetch.jsonl" "$first_commit" <<'PY'
import json
import pathlib
import sys

trace, commit = sys.argv[1:]
commands = [record.get("argv", []) for record in map(json.loads, pathlib.Path(trace).read_text().splitlines())
            if record["event"] == "start"]
assert any("fetch" in command and "--depth" in command and commit in command for command in commands), commands
assert not any("clone" in command for command in commands), commands
PY
test -f "$consumer/kennel_packages/fixed/kennel.toml"
test ! -e "$consumer/kennel_packages/fixed/version.txt"
cp "$consumer/kennel.lock" "$scratch/fixed.lock"

# A host that refuses the direct object request can still serve the
# reachable revision through the advertised history.
export KENNEL_FIXTURE_GIT="$(command -v git)"
mkdir "$scratch/ref-only"
cat >"$scratch/ref-only/git" <<'SH'
#!/usr/bin/env bash
if [[ "${1:-}" == -C && "${3:-}" == fetch ]]; then
    echo 'fixture: direct object fetch unavailable' >&2
    exit 1
fi
exec "$KENNEL_FIXTURE_GIT" "$@"
SH
chmod +x "$scratch/ref-only/git"
PATH="$scratch/ref-only:$PATH" kennel install
cmp "$consumer/kennel.lock" "$scratch/fixed.lock"
test ! -e "$consumer/kennel_packages/fixed/version.txt"
echo '[verify-git-commit-resolution] success'
