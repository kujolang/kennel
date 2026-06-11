# Kennel Testing and Delivery Roadmap

This document defines the quality gates required for release readiness and ongoing production reliability.

## Release Objective

Each release must be reproducible, secure by default, and validated by deterministic test artifacts.

## Mandatory Release Gates

All gates must pass before merge or release tagging:

1. End-to-end command flow is stable: init, add, install, update, remove, list, info, validate.
2. Lockfile generation and reinstall behavior are deterministic.
3. GitHub and local path dependency workflows both pass integration tests.
4. Pinned refs are not changed by update operations.
5. Hosted-registry auth, publish, yank, access, visibility, api-search, api-metadata, and install-hosted flows are green.
6. Trust-policy checks reject invalid checksum/signature/signing_key data.
7. CLI diagnostics remain specific and actionable.
8. Documentation aligns with shipped behavior.

## Canonical Test Matrix

Run and keep green:

1. Contract coverage:

```bash
cd /path/to/kujolang/kennel
bash ./scripts/verify-contract-suites.sh
```

2. Core dependency and lockfile validation:

```bash
cd /path/to/kujolang/kennel
./scripts/verify-pinned-refs.sh
./scripts/verify-stale-lockfile.sh
./scripts/verify-deterministic-lockfile.sh
```

3. CLI quality and diagnostics:

```bash
cd /path/to/kujolang/kennel
./scripts/verify-cli-messages.sh
./scripts/verify-git-diagnostics.sh
./scripts/verify-atomicity.sh
```

4. Unified verification runner:

```bash
cd /path/to/kujolang/kennel
./scripts/verify-all.sh core
```

5. Full integration script matrix:

```bash
cd /path/to/kujolang/kennel
for script in ./scripts/verify-*.sh; do
	bash "$script"
done
```

## CI Expectations

1. Fail fast with strict shell options.
2. Keep deterministic checks on every change set that can affect resolver, installer, lockfile, auth, or registry behavior.
3. Keep Kujo-native implementation guardrails active.
4. Ensure new behavior includes contract or integration coverage before merge.

## Ongoing Hardening Priorities

1. Expand failure-path coverage for resolver edge cases and malformed registry metadata.
2. Add performance baselines for larger dependency sets and hosted metadata queries.
3. Reduce overlap across verification scripts to keep maintenance cost low.
4. Strengthen security regression coverage for token handling and permission boundaries.

## Latest Baseline Snapshot (2026-05-20)

The current baseline run used the existing script matrix and contract suite.

Pass status:

1. `scripts/verify-stage-1.sh`
2. `scripts/verify-deterministic-lockfile.sh`
3. `scripts/verify-pinned-refs.sh`
4. `scripts/verify-stage-2-name-workflow-stability.sh`
5. `scripts/verify-cli-messages.sh`
6. `scripts/verify-kujo-native-direction.sh`
7. `scripts/verify-stage-3-trust-signature-workflow.sh`
8. `scripts/verify-stage-3-server-permission-workflow.sh`
9. `scripts/verify-stage-3-private-package-workflow.sh`
10. `scripts/verify-stage-3-hosted-api-workflow.sh`
11. `scripts/verify-stale-lockfile.sh`
12. `scripts/verify-atomicity.sh`
13. `scripts/verify-contract-suites.sh` (31 passed across split suites)

Timing baseline (seconds):

- `verify-stage-2-name-workflow-stability.sh`: 4
- `verify-stage-3-server-permission-workflow.sh`: 3
- `verify-stage-3-hosted-api-workflow.sh`: 3
- `verify-deterministic-lockfile.sh`: 3
- `verify-atomicity.sh`: 3
- `verify-stage-3-private-package-workflow.sh`: 2
- `verify-stage-3-trust-signature-workflow.sh`: 1
- `verify-stale-lockfile.sh`: 1
- `verify-contract-suites.sh`: 1
- `verify-kujo-native-direction.sh`: 0
