#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

persistent_modules=(
	"$ROOT_DIR/src/commands_dependency.kujo"
	"$ROOT_DIR/src/commands_shared.kujo"
	"$ROOT_DIR/src/future_resolvers.kujo"
	"$ROOT_DIR/src/hosted_auth.kujo"
	"$ROOT_DIR/src/lockfile.kujo"
	"$ROOT_DIR/src/manifest.kujo"
)

if grep -En 'write_file\(' "${persistent_modules[@]}"; then
	echo "[verify-atomic-persistence] direct write_file call remains on a persistent state path"
	exit 1
fi

required_contracts=(
	"$ROOT_DIR/src/utils.kujo:write_file_atomic(path, to_string(content), true)"
	"$ROOT_DIR/src/manifest.kujo:write_text_atomic(path, raw)"
	"$ROOT_DIR/src/lockfile.kujo:write_text_atomic(path, to_toml(lockfile))"
	"$ROOT_DIR/src/hosted_auth.kujo:io_write_private_file(temp_path, to_string(content), 384)"
	"$ROOT_DIR/src/hosted_auth.kujo:rename_file(temp_path, path_value)"
)

for contract in "${required_contracts[@]}"; do
	contract_file="${contract%%:*}"
	contract_pattern="${contract#*:}"
	if ! grep -Fq -- "$contract_pattern" "$contract_file"; then
		echo "[verify-atomic-persistence] missing persistence contract: ${contract_file#$ROOT_DIR/}:$contract_pattern"
		exit 1
	fi
done

echo "[verify-atomic-persistence] success"
