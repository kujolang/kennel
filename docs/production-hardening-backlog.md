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

1. Add atomic write safety for manifest and lockfile updates.

- Evidence:
	- Command-level rollback now restores paired manifest/lockfile state after a handled write failure.
	- `save_manifest` and `save_lockfile` still overwrite their target files directly, so process or machine termination during a write can leave a partial file.
- Outcome:
	- Temp-file write, flush, and atomic rename on supported platforms.
	- Preserve the existing command-level rollback behavior for handled failures.

2. Remove shell-based destructive file operations from installer paths.

- Evidence:
	- Installer replacement uses guarded shell `mv`, `rm`, and `cp` operations.
	- Failed replacements now restore the displaced package, and successful replacements delete temporary trash, but safe native filesystem operations would reduce shell dependence further.
- Outcome:
	- Replace with safe Kujo-native file operations or strict guardrails.
	- Explicit path safety checks for install targets.

3. Add crash-safe token-store persistence.

- Evidence:
	- Token-store writes apply restrictive permissions and fail closed on malformed state.
	- The store file is still overwritten directly rather than replaced atomically.
- Outcome:
	- Atomic replace without any interval in which a partially written credential store can be observed.
	- Preserve mode `0600` across create and replacement flows.

## Recently Completed Safeguards

- Central identifier validation rejects unsafe package, registry, user, and alias values before filesystem or registry operations.
- Trust validation enforces canonical checksum algorithms/digest lengths, base64 signature shape, safe signing-key shape, and distinct malformed/missing/mismatch diagnostics.
- Installer replacement restores the previous package after a failed copy/clone/checkout and removes temporary displaced-package data after success.

## P1: DRY and Modular Architecture

1. Extract shared auth context resolution used by hosted-registry commands.

- Evidence:
	- Repeated token/registry/user/store-path setup and token lookup in:
		- `command_publish`
		- `command_yank`
		- `command_access`
		- `command_visibility`
		- `command_api_search`
		- `command_api_metadata`
		- `command_install_hosted`
	- All in `kennel.kujo`.
- Outcome:
	- Single helper for auth context and registry-dir resolution.
	- Lower regression risk when auth behavior changes.

2. Split command orchestration from command implementation.

- Evidence:
	- `kennel.kujo` contains parsing, workflow orchestration, and command internals in one file.
- Outcome:
	- Move hosted-registry command logic into dedicated module.
	- Move dependency lifecycle command logic into dedicated module.
	- Keep `kennel.kujo` as thin routing layer.

3. Break large resolver/registry module into focused units.

- Evidence:
	- `future_resolvers.kujo` currently owns static index lookup, auth token store, publish/yank/access/visibility, hosted API behavior, and trust verification.
- Outcome:
	- Extract token-store, registry-metadata mutation, hosted-read APIs, and trust-verification concerns into separate modules.

## P1: Performance

1. Stop full lock rebuild for single-dependency add/remove operations.

- Evidence:
	- `rebuild_lockfile_from_manifest` resolves and reinstalls every dependency in sequence.
	- Called after add/remove and fallback install paths in `kennel.kujo`.
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

2. Add explicit failure atomicity tests.

- Outcome:
	- Verify manifest and lockfile remain consistent when install/resolve/publish steps fail mid-flight.

3. Add unified verification runner.

- Evidence:
	- 24 scripts under `scripts/` with overlapping setup patterns.
- Outcome:
	- One orchestrator script to run targeted capability groups.
	- Keep individual scripts as leaf checks.

## P2: Cleanup and Naming Consistency

1. Remove legacy maturity wording from runtime defaults and help text.

- Evidence:
	- `manifest.kujo` default package status uses legacy maturity strings.
	- `cli.kujo` and `kennel.kujo` help/warning output still includes legacy maturity phrasing.
	- Test naming and language across `tests/contracts/*.kujo` can still be tightened for production terminology consistency.
- Outcome:
	- Production-forward default metadata and help output.
	- Terminology aligned across code, tests, and docs.

2. Rename legacy verification script naming.

- Evidence:
	- Many scripts still use legacy milestone naming in `scripts/`.
- Outcome:
	- Capability-based names (auth, publish, trust, api, permissions, lockfile, diagnostics).
	- Cleaner entry points for CI and contributor workflows.

3. Revisit ignore rules and tracked docs expectations.

- Evidence:
	- `.gitignore` includes `docs/full-delivery-checklist.md`.
- Outcome:
	- Align ignore rules with actual tracked documentation policy.

## Suggested Execution Order

1. P0 reliability and security items.
2. Shared-helper extraction and command/module split.
3. Lockfile/install performance work and cache strategy.
4. Test suite refactor and runner consolidation.
5. Naming and cleanup pass.

## Definition Of Done For This Backlog

- All P0 items complete and tested.
- No data-loss risk from partial command failure.
- Auth and trust behavior enforced through shared code paths.
- Verification and test workflows are modular and easy to run.
- Runtime messaging, defaults, tests, and docs use consistent production terminology.
