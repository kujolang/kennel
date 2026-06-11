#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

entry_module="kennel"
shim_modules=(
	"cli"
	"commands_dependency"
	"commands_hosted"
	"commands_shared"
	"dependency_spec"
	"error_shape"
	"future_resolvers"
	"hosted_auth"
	"hosted_trust"
	"installer"
	"lockfile"
	"manifest"
	"path_helpers"
	"resolver"
	"utils"
	"validator"
)

if [ ! -f "$ROOT_DIR/${entry_module}.kujo" ]; then
	echo "[verify-kujo-native-direction] missing Kujo entry module: ${entry_module}.kujo"
	exit 1
fi

for ext in py js ts go rs; do
	if [ -f "$ROOT_DIR/${entry_module}.${ext}" ]; then
		echo "[verify-kujo-native-direction] unexpected non-Kujo entry implementation file detected: ${entry_module}.${ext}"
		exit 1
	fi
done

for module in "${shim_modules[@]}"; do
	root_module="$ROOT_DIR/${module}.kujo"
	src_module="$ROOT_DIR/src/${module}.kujo"

	if [ ! -f "$root_module" ]; then
		echo "[verify-kujo-native-direction] missing root compatibility shim: ${module}.kujo"
		exit 1
	fi

	if [ ! -f "$src_module" ]; then
		echo "[verify-kujo-native-direction] missing src implementation module: src/${module}.kujo"
		exit 1
	fi

	if ! head -n 1 "$root_module" | grep -Fq "from src.${module} import"; then
		echo "[verify-kujo-native-direction] root shim does not import src implementation: ${module}.kujo"
		exit 1
	fi

	if grep -q '^func ' "$root_module"; then
		echo "[verify-kujo-native-direction] root shim unexpectedly defines functions: ${module}.kujo"
		exit 1
	fi

	if ! grep -q '^export ' "$root_module"; then
		echo "[verify-kujo-native-direction] root shim is missing exports: ${module}.kujo"
		exit 1
	fi

	for ext in py js ts go rs; do
		if [ -f "$ROOT_DIR/${module}.${ext}" ]; then
			echo "[verify-kujo-native-direction] unexpected non-Kujo core implementation file detected: ${module}.${ext}"
			exit 1
		fi
	done
done

echo "[verify-kujo-native-direction] success"
