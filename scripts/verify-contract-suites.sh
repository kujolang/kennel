#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"

SUITES=(
	"$ROOT_DIR/tests/contracts/cli-and-core-contract_tests.kujo"
	"$ROOT_DIR/tests/contracts/registry-index-contract_tests.kujo"
	"$ROOT_DIR/tests/contracts/hosted-registry-contract_tests.kujo"
)

for suite in "${SUITES[@]}"; do
	echo "[verify-contract-suites] running ${suite#$ROOT_DIR/}"
	"$KUJO_BIN" test-run "$suite"
done

echo "[verify-contract-suites] success"
