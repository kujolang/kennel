# Kennel Delivery Checklist

This document is the single operational checklist for shipping and maintaining Kennel as a production package manager.

Status legend:

- Not started: `[ ]`
- In progress: `[~]`
- Done: `[x]`

## How To Use This Checklist

1. Scope each change to one primary objective.
2. Run relevant verification scripts and contract tests.
3. Update README, roadmap, and status docs when user-visible behavior changes.
4. Add changelog entries for behavior, testing, and docs updates.
5. Commit and push with a clear message.

## Definition Of Done For Any Item

1. The implementation is complete and reviewed.
2. Existing relevant tests pass.
3. New tests are added for behavior changes.
4. Documentation reflects current behavior.
5. Changelog entries are present and accurate.

## Release Operations Checklist

- [x] Verify core command flow in a clean temp project.
- [x] Verify deterministic lockfile behavior.
- [x] Verify pinned-ref update protections.
- [x] Verify static index name-based add/search/info workflows.
- [x] Verify hosted-registry login/publish/yank/access/visibility workflows.
- [x] Verify hosted api-search/api-metadata/install-hosted workflows.
- [x] Verify trust-policy checksum/signature/signing_key enforcement.
- [x] Verify CLI diagnostics remain actionable and regression-safe.
- [x] Verify Kujo-native implementation guardrails.

## Security and Governance Checklist

- [x] Enforce owner checks on all hosted metadata mutations.
- [x] Confirm token handling does not leak credentials in CLI output.
- [x] Confirm trust-policy mismatches fail hard with explicit errors.
- [x] Review permission and visibility changes for least-privilege defaults.
- [x] Confirm audit and reliability docs remain aligned with behavior.

## Performance and Reliability Checklist

- [x] Benchmark resolver and install runtimes on representative projects.
- [x] Track metadata lookup and hosted query performance.
- [x] Reduce no-op lockfile and metadata write churn.
- [x] Keep deterministic behavior under repeated and reordered operations.

## Documentation Checklist

- [x] docs/current-status-and-usage.md is accurate.
- [x] docs/roadmap.md reflects active priorities.
- [x] docs/testing-and-delivery-roadmap.md reflects current gate scripts.
- [x] README command examples match current CLI behavior.
- [x] CHANGELOG.md entries reflect user-visible changes.
