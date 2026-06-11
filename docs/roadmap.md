# Kennel Roadmap

## Product Direction

Kennel is the Kujo package manager for deterministic source-based dependency workflows and hosted-registry package operations.

The roadmap now focuses on reliability, scale, and maintainability.

## Current Execution Focus (2026-05-20)

1. Keep release-gate scripts green in each change batch.
2. Maintain trust and permission regression coverage in hosted workflows.
3. Track a repeatable local timing baseline for resolver/install/metadata operations.
4. Continue reducing overlap across verification scripts while preserving coverage.

## Theme 1: Dependency Resolution Depth

Primary goals:

1. Add transitive dependency graph solving.
2. Introduce conflict detection with actionable remediation output.
3. Add semver range resolution that remains deterministic under lockfile writes.

Success criteria:

- resolver output is deterministic across repeated runs and dependency declaration order
- lockfile output is stable and replayable in CI
- user-facing conflicts identify exact package/version constraints causing failure

## Theme 2: Registry and Metadata Hardening

Primary goals:

1. Strengthen registry schema compatibility and migration safety.
2. Improve hosted metadata consistency checks for publish/yank/visibility mutations.
3. Expand policy controls for package provenance and ownership delegation.

Success criteria:

- metadata contracts remain backward compatible across planned releases
- mutation failures are explicit, consistent, and safely recoverable
- owner and team permission boundaries are enforced for all write operations

## Theme 3: Security and Trust Maturity

Primary goals:

1. Improve token lifecycle controls (rotation UX, revocation patterns, and audit trails).
2. Expand trust-policy validation and error diagnostics for signature mismatch cases.
3. Define stronger provenance and integrity guidance for hosted package consumption.

Success criteria:

- sensitive operations reject invalid auth and emit auditable reasons
- trust verification failures are deterministic and actionable
- default security posture is safe for CI and multi-maintainer teams

## Theme 4: Performance and Scale

Primary goals:

1. Reduce resolver and install overhead for larger dependency sets.
2. Improve hosted metadata query performance for search and package lookups.
3. Minimize lockfile and registry write churn for no-op operations.

Success criteria:

- improved runtime on representative dependency workloads
- no regression in deterministic outputs
- clear performance baselines tracked in CI or repeatable local benchmarks

## Theme 5: Developer Experience and Operations

Primary goals:

1. Keep CLI diagnostics concise, explicit, and fix-oriented.
2. Simplify validation and release gates with a single authoritative command map.
3. Reduce script duplication and improve maintenance ergonomics.

Success criteria:

- lower setup overhead for first-time contributors
- fewer duplicated shell workflows across scripts
- clear ownership for test, release, and reliability checks

## Reference Documents

- docs/current-status-and-usage.md
- docs/testing-and-delivery-roadmap.md
- docs/full-delivery-checklist.md
- docs/production-hardening-backlog.md
