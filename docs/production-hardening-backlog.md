# Kennel Production Hardening Backlog

## Purpose

This document is the current engineering review of remaining work needed to harden Kennel for long-term production operation.

It is intentionally implementation-focused and organized by priority.

## Current Snapshot

- Core CLI routing is thin and remains in `kennel.kujo`; command implementation now lives under `src/` with root compatibility shims.
- Hosted auth and hosted trust checks have dedicated modules, while broader hosted registry metadata/API behavior still lives mostly in `src/future_resolvers.kujo`.
- Contract coverage now runs through split suites in `tests/contracts/` via `scripts/verify-contract-suites.sh`.
- Verification coverage is broad and profile-routed, but still distributed across many focused shell scripts in `scripts/`.

## Priority Backlog

## P0: Reliability and Security

No open P0 finding remains in the current launch-safe scope.

## Recently Completed Safeguards

- Central identifier validation rejects unsafe package, registry, user, and alias values before filesystem or registry operations.
- Trust validation enforces canonical checksum algorithms/digest lengths, base64 signature shape, safe signing-key shape, and distinct malformed/missing/mismatch diagnostics.
- Installer replacement restores the previous package after a failed copy/clone/checkout and removes temporary displaced-package data after success.
- Manifest, lockfile, registry metadata, rollback restoration, and generated scaffold files use Kujo's synced same-directory atomic replacement primitive.
- Token-store replacement creates verified mode-`0600` temporary content and atomically renames it into place.
- Installer displacement, restoration, recursive deletion, and empty-directory cleanup use native Kujo filesystem operations; shell execution remains only where Git or recursive copy semantics require an external tool.

## P1: DRY and Modular Architecture

1. Break the remaining large resolver/registry module into focused units.

- Evidence:
	- `future_resolvers.kujo` currently owns static index lookup, auth token store, publish/yank/access/visibility, hosted API behavior, and trust verification.
- Outcome:
	- Extract token-store, registry-metadata mutation, hosted-read APIs, and trust-verification concerns into separate modules.

## P1: Performance

1. Stop full lock rebuild for single-dependency add/remove operations.

- Evidence:
	- `rebuild_lockfile_from_manifest` resolves and reinstalls every dependency in sequence.
	- Called after add/remove and fallback install paths in `src/commands_dependency.kujo`.
- Outcome:
	- Incremental lock updates when safe.
	- Full rebuild only when required.

2. Add optional parallel install pipeline.

- Evidence:
	- Dependency install loops are sequential in rebuild and install flows.
- Outcome:
	- Optional bounded concurrency mode for larger dependency sets.
	- No determinism regressions in lockfile content.

3. Add metadata/index caching strategy for repeated lookup commands.

- Evidence:
	- Search/info flows repeatedly load and parse static metadata files.
- Outcome:
	- In-process cache with explicit invalidation boundaries.
	- Faster repeated command execution.

## P1: Test Suite Hardening

1. Continue hardening split contract suites and orchestration coverage.

- Evidence:
	- Domain suites now exist under `tests/contracts/`, but reliability/performance scenarios can still be expanded.
- Outcome:
	- Faster root-cause isolation.
	- Easier ownership and maintenance of test domains.

2. Continue expanding abrupt-termination and recovery drills beyond the atomic primitive's repository-owned contract coverage.

## P2: Cleanup and Naming Consistency

1. Rename legacy verification script naming.

- Evidence:
	- Many scripts still use legacy milestone naming in `scripts/`.
- Outcome:
	- Capability-based names (auth, publish, trust, api, permissions, lockfile, diagnostics).
	- Cleaner entry points for CI and contributor workflows.

2. Revisit ignore rules and tracked docs expectations.

- Evidence:
	- `.gitignore` includes `docs/full-delivery-checklist.md`.
- Outcome:
	- Align ignore rules with actual tracked documentation policy.

## Suggested Execution Order

1. Evidence-backed lockfile/install performance work and cache strategy.
2. Remaining registry-module split.
3. Test suite refinements.
4. Naming and cleanup pass.

## Definition Of Done For This Backlog

- All P0 items complete and tested.
- No data-loss risk from partial command failure.
- Auth and trust behavior enforced through shared code paths.
- Verification and test workflows are modular and easy to run.
- Runtime messaging, defaults, tests, and docs use consistent production terminology.
