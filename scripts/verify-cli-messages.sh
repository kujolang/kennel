#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
KENNEL_SCRIPT="$ROOT_DIR/kennel.kujo"
TMP_DIR="$ROOT_DIR/.kennel_tmp/verify-cli-messages"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- init --name cli-check --project-dir "$TMP_DIR" >/dev/null 2>&1

help_output="$TMP_DIR/help.out"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- help >"$help_output" 2>&1

expected_help="$TMP_DIR/help.expected"
cat >"$expected_help" <<'EOF'
Kennel
Production package manager for Kujo with deterministic lockfiles and hosted-registry workflows

Usage:
  kennel init [--name NAME] [--force] [--project-dir PATH]
  kennel new <project-name> [--force] [--project-dir PATH]
  kennel add <source-or-name> [--alias NAME] [--allow-mutable-ref] [--project-dir PATH]
  kennel install [--allow-mutable-ref] [--project-dir PATH]
  kennel update [name] [--allow-mutable-ref] [--project-dir PATH]
  kennel remove <name> [--project-dir PATH]
  kennel list [--project-dir PATH]
  kennel search <query> [--project-dir PATH]
  kennel info <name-or-source> [--project-dir PATH]
  kennel login (--token TOKEN | --token-file PATH) [--registry NAME] [--user NAME] [--store-path PATH] [--project-dir PATH]
  kennel publish [--registry NAME] [--user NAME] [--store-path PATH] [--registry-dir PATH] [--private|--public] [--project-dir PATH]
  kennel yank <version> [--package NAME] [--registry NAME] [--user NAME] [--store-path PATH] [--registry-dir PATH] [--undo] [--project-dir PATH]
  kennel access <owner-add|owner-remove|team-add|team-remove|list> <package> [target] [--role ROLE] [--permission NAME] [--registry NAME] [--user NAME] [--store-path PATH] [--registry-dir PATH] [--project-dir PATH]
  kennel visibility <package> <public|private> [--registry NAME] [--user NAME] [--store-path PATH] [--registry-dir PATH] [--project-dir PATH]
  kennel api-search <query> [--registry NAME] [--user NAME] [--store-path PATH] [--registry-dir PATH] [--project-dir PATH]
  kennel api-metadata <package> [--registry NAME] [--user NAME] [--store-path PATH] [--registry-dir PATH] [--project-dir PATH]
  kennel install-hosted <package> [--registry NAME] [--user NAME] [--store-path PATH] [--registry-dir PATH] [--allow-mutable-ref] [--project-dir PATH]
  kennel validate [--project-dir PATH]

Supported sources:
  github:owner/repo@ref
  github:owner/repo
  https://github.com/owner/repo.git#ref
  file:../local-package or ../local-package

Examples:
  kennel init --name demo
  kennel new demo-app
  kennel add github:robertdevore/pypractice@main --alias pypractice
  kennel install
  kennel login --token-file ~/.kennel/token.txt --registry hosted-registry --user alice
  kennel publish --registry hosted-registry --user alice --store-path ~/.kennel/tokens.json --registry-dir ./hosted-registry

Recovery guidance:
  Missing kennel.toml: run `kennel init` in the project root or pass --project-dir PATH.
  Duplicate dependency alias: run `kennel update <alias>` or `kennel remove <alias>` first.
  Hosted auth failures: run `kennel login` again and verify --store-path, --registry, and --user values.

Security hints:
  Prefer --token-file over --token so secrets are not echoed in shell history.
  Keep token store paths outside repositories and use restrictive file permissions.
  Prefer explicit refs and commit pins for reproducible installs.

Tip: prefer explicit refs and commit pins for reproducible installs.
EOF

diff -u "$expected_help" "$help_output"
grep -q '^Examples:' "$help_output"
grep -q '^Recovery guidance:' "$help_output"
grep -q '^Security hints:' "$help_output"
grep -q 'Prefer --token-file over --token so secrets are not echoed in shell history.' "$help_output"

invalid_add_output="$TMP_DIR/invalid-add.log"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add ssh://example.com/repo.git --project-dir "$TMP_DIR" >"$invalid_add_output" 2>&1; then
	echo "[verify-cli-messages] expected add with unsupported source to fail"
	exit 1
fi

grep -q "Unsupported source format:" "$invalid_add_output"
grep -q "Supported sources:" "$invalid_add_output"

unknown_command_output="$TMP_DIR/unknown-command.log"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- frobnicate --project-dir "$TMP_DIR" >"$unknown_command_output" 2>&1; then
	echo "[verify-cli-messages] expected unknown command to fail"
	exit 1
fi

grep -q 'Unknown command: frobnicate. Run `kennel help` for supported commands.' "$unknown_command_output"

missing_dep_output="$TMP_DIR/missing-dep.log"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- update does-not-exist --project-dir "$TMP_DIR" >"$missing_dep_output" 2>&1; then
	echo "[verify-cli-messages] expected update for missing dependency to fail"
	exit 1
fi

grep -q 'Dependency `does-not-exist` not found in kennel.toml' "$missing_dep_output"

duplicate_dep_output="$TMP_DIR/duplicate-dep.log"
"$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add github:robertdevore/pypractice@main --alias duplicate-check --project-dir "$TMP_DIR" >/dev/null 2>&1
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- add github:robertdevore/pypractice@main --alias duplicate-check --project-dir "$TMP_DIR" >"$duplicate_dep_output" 2>&1; then
	echo "[verify-cli-messages] expected duplicate dependency add to fail"
	exit 1
fi

grep -q 'Dependency `duplicate-check` is already declared. Use `kennel update duplicate-check` or remove it first.' "$duplicate_dep_output"

missing_remove_output="$TMP_DIR/missing-remove.log"
if "$KUJO_BIN" run "$KENNEL_SCRIPT" --interpreter -- remove does-not-exist --project-dir "$TMP_DIR" >"$missing_remove_output" 2>&1; then
	echo "[verify-cli-messages] expected remove for missing dependency to fail"
	exit 1
fi

grep -q 'Dependency `does-not-exist` is not declared in kennel.toml. Run `kennel list` to inspect installed dependencies.' "$missing_remove_output"

echo "[verify-cli-messages] success"
