# Kennel Enterprise Excellence Checklist

This document is the next-session backlog for advancing Kennel from production-hardened to enterprise-exemplar quality.

## Goal

Make Kennel a flagship Kujo ecosystem project by improving:
- performance at scale
- security and supply-chain confidence
- feature completeness for broad teams
- presentation and adoption readiness

## How To Use This Checklist

1. Work top-to-bottom on unchecked actionable items.
2. Complete exactly one actionable item per loop unless blocked.
3. If blocked, add a blocker note under the item with evidence.
4. Mark completion only after implementation, validation, and docs updates.
5. Add a Work Log entry for every completed item.

## Status Legend

- [ ] Not started
- [~] In progress
- [x] Completed

## Current Audit Findings (2026-05-22)

1. Root/module layout is now src-first with compatibility shims, but shim drift prevention should stay a first-class guardrail as modules evolve.
2. CI still rebuilds Kujo runtime from source in multiple jobs, increasing latency and cost for routine validation.
3. There is no benchmark harness committed for resolver/install/metadata performance regression tracking.
4. Security coverage is strong for trust and permissions, but there is no signed-release provenance (SBOM/attestation) workflow.
5. Hosted workflows are robust; multi-registry routing is now available, and long-term focus shifts to adoption/diagram clarity for large-team operations.
6. Dependency resolution now includes deterministic transitive solving and optional semver ranges; remaining quality work is primarily reporting/documentation depth.
7. Nightly full-profile checks exist, but trend visibility for pass/fail duration and warning budgets is not yet documented in an operator report.
8. Documentation, architecture diagrams, and CI quality trend exports are now present and source-controlled.

## Actionable Backlog

## Tier A: Performance and Scale

### PERF-001 Add Deterministic Benchmark Harness
- [x] Add repeatable benchmark scripts for install/update/search/metadata paths with machine-readable output.

Implementation expectations:
- Include fixed fixture projects and controlled environment variables.
- Emit JSON summaries suitable for CI artifact comparison.

Acceptance criteria:
- Maintainers can compare benchmark runs across commits.
- Regression thresholds are documented.

Validation/testing expectations:
- Run benchmark harness locally and in CI dry-run mode.

### PERF-002 Reduce CI Runtime Build Duplication
- [x] Reduce repeated Kujo runtime builds across workflow jobs via artifact reuse or cache strategy.

Implementation expectations:
- Preserve reproducibility and pinning guarantees.
- Keep workflow readability high.

Acceptance criteria:
- End-to-end CI runtime decreases without reducing coverage.

Validation/testing expectations:
- Validate all affected workflows and contract scripts.

## Tier B: Security and Compliance

### SEC-006 Add SBOM and Build Attestation Workflow
- [x] Generate and publish SBOM and signed build attestations for release builds.

Implementation expectations:
- Use pinned actions and least-privilege permissions.
- Keep release artifacts traceable to source commit and workflow run.

Acceptance criteria:
- Release pipeline produces auditable provenance artifacts.

Validation/testing expectations:
- Add contract checks for attestation workflow structure.

### SEC-007 Add Policy Checks for Unsafe Source Patterns
- [x] Add configurable policy gates to block disallowed source patterns (for example, mutable branch refs in strict mode).

Implementation expectations:
- Allow policy overrides with explicit operator intent.
- Keep diagnostics actionable.

Acceptance criteria:
- Unsafe dependency source patterns fail with clear remediation guidance.

Validation/testing expectations:
- Add contract tests for allow/deny policy cases.

## Tier C: Functionality and Universal Utility

### FEAT-001 Add Transitive Dependency Resolution
- [x] Implement deterministic transitive dependency resolution with explicit conflict diagnostics.

Implementation expectations:
- Preserve existing lockfile determinism guarantees.
- Keep direct-dependency workflows backward compatible.

Acceptance criteria:
- Transitive trees are installed and locked deterministically.

Validation/testing expectations:
- Add conflict, override, and reproducibility regression tests.

### FEAT-002 Add Semver Range Solver Mode
- [x] Introduce optional semver range resolution mode with deterministic lock output.

Implementation expectations:
- Keep explicit refs/pins fully supported.
- Make solver behavior transparent in lock metadata.

Acceptance criteria:
- Teams can choose semver mode without nondeterministic lockfile churn.

Validation/testing expectations:
- Add tests for range intersections and pin precedence.

### FEAT-003 Add Multi-Registry Routing and Mirror Fallback
- [x] Support multiple registry sources with deterministic priority/fallback behavior.

Implementation expectations:
- Keep security boundaries for hosted private packages.
- Document predictable failover order.

Acceptance criteria:
- Enterprise teams can route dependencies across internal/public registries safely.

Validation/testing expectations:
- Add stage-3 integration tests for primary/secondary registry scenarios.

## Tier D: Presentation and Adoption

### DOC-006 Add Enterprise Adoption Guide
- [x] Create an enterprise adoption guide covering rollout patterns, org policy templates, and migration playbooks.

Implementation expectations:
- Target platform/security leads and large-team maintainers.
- Include examples for CI policy and incident response drills.

Acceptance criteria:
- New enterprise users can adopt Kennel with minimal custom discovery.

Validation/testing expectations:
- Verify all documented commands and script paths.

### DOC-007 Add Architecture Diagrams and Flow Maps
- [x] Add diagrams for command routing, hosted registry mutation flow, and lockfile lifecycle.

Implementation expectations:
- Keep diagrams source-controlled and update-friendly.
- Align with current code/module boundaries.

Acceptance criteria:
- Contributors can understand system boundaries quickly.

Validation/testing expectations:
- Cross-check diagrams against implementation modules and verify scripts.

### OPS-009 Add CI Quality Dashboard Export
- [x] Produce a periodic CI quality report artifact summarizing pass/fail trends, durations, and warning counts.

Implementation expectations:
- Keep report generation lightweight and deterministic.
- Preserve privacy and avoid sensitive log leakage.

Acceptance criteria:
- Maintainers gain trend visibility without manual log mining.

Validation/testing expectations:
- Add contract checks for report generation workflow.

## Item Completion Template

Use this format in Work Log entries:

- Date: YYYY-MM-DD
- Item: <ITEM_ID>
- Summary: <what changed>
- Files changed: <comma-separated list>
- Tests/validation run: <commands>
- Result: <pass/fail + evidence>
- README/docs updated: <yes/no + file list>
- Follow-ups: <none or short list>

## Work Log

Append new entries at the top.

- Date: 2026-05-28
- Item: OPS-009
- Summary: Added nightly CI quality report export (`nightly-ci-quality-report`) with deterministic JSON summary of pass/fail trends, duration metrics, and warning counts, plus workflow contract enforcement.
- Files changed: scripts/generate-ci-quality-report.sh, scripts/verify-ci-quality-report-workflow.sh, scripts/verify-all.sh, .github/workflows/nightly-full-regression.yml, docs/ci-quality-dashboard-export.md, README.md, docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Tests/validation run: bash /path/to/kujo-kennel/scripts/verify-ci-quality-report-workflow.sh; bash /path/to/kujo-kennel/scripts/verify-contract-suites.sh; bash /path/to/kujo-kennel/scripts/verify-profiles.sh core; bash /path/to/kujo-kennel/scripts/verify-stage-3-private-package-workflow.sh; bash /path/to/kujo-kennel/scripts/verify-stage-3-server-permission-workflow.sh; bash /path/to/kujo-kennel/scripts/verify-stage-3-trust-signature-workflow.sh; bash /path/to/kujo-kennel/scripts/verify-stage-3-hosted-api-workflow.sh
- Result: pass; nightly workflow now emits a privacy-safe report artifact with trend/duration/warning summaries and contract checks to prevent workflow drift.
- README/docs updated: yes; README.md, docs/ci-quality-dashboard-export.md, docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Follow-ups: none

- Date: 2026-05-28
- Item: DOC-007
- Summary: Added source-controlled architecture flow maps for command routing, hosted mutation flow, and lockfile lifecycle, plus automated path/alignment verification.
- Files changed: docs/architecture-flow-maps.md, scripts/verify-architecture-flow-maps.sh, scripts/verify-all.sh, README.md, docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Tests/validation run: bash /path/to/kujo-kennel/scripts/verify-architecture-flow-maps.sh; bash /path/to/kujo-kennel/scripts/verify-contract-suites.sh; bash /path/to/kujo-kennel/scripts/verify-profiles.sh core; bash /path/to/kujo-kennel/scripts/verify-stage-3-private-package-workflow.sh; bash /path/to/kujo-kennel/scripts/verify-stage-3-server-permission-workflow.sh; bash /path/to/kujo-kennel/scripts/verify-stage-3-trust-signature-workflow.sh; bash /path/to/kujo-kennel/scripts/verify-stage-3-hosted-api-workflow.sh
- Result: pass; architecture flow maps are now update-friendly, module-aligned, and automatically checked against referenced implementation/verification paths.
- README/docs updated: yes; README.md, docs/architecture-flow-maps.md, docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Follow-ups: OPS-009

- Date: 2026-05-28
- Item: DOC-006
- Summary: Added a dedicated enterprise adoption guide with rollout patterns, policy templates, migration playbooks, CI policy examples, and incident response drills; added deterministic docs command/path verification.
- Files changed: docs/enterprise-adoption-guide.md, scripts/verify-enterprise-docs.sh, scripts/verify-all.sh, README.md, docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Tests/validation run: bash /path/to/kujo-kennel/scripts/verify-enterprise-docs.sh; bash /path/to/kujo-kennel/scripts/verify-contract-suites.sh; bash /path/to/kujo-kennel/scripts/verify-profiles.sh core; bash /path/to/kujo-kennel/scripts/verify-stage-3-private-package-workflow.sh; bash /path/to/kujo-kennel/scripts/verify-stage-3-server-permission-workflow.sh; bash /path/to/kujo-kennel/scripts/verify-stage-3-trust-signature-workflow.sh; bash /path/to/kujo-kennel/scripts/verify-stage-3-hosted-api-workflow.sh
- Result: pass; enterprise adoption guidance is now explicit and command/script references are automatically verified.
- README/docs updated: yes; README.md, docs/enterprise-adoption-guide.md, docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Follow-ups: DOC-007

- Date: 2026-05-28
- Item: FEAT-003
- Summary: Added deterministic multi-registry static index routing (`[registry].index` + `[registry].mirrors`) with ordered fallback for name-based add/info/search flows, including safe handling for missing or unsupported index paths.
- Files changed: src/commands_shared.kujo, commands_shared.kujo, src/commands_dependency.kujo, src/manifest.kujo, scripts/verify-multi-registry-fallback.sh, scripts/verify-all.sh, README.md, docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Tests/validation run: bash /path/to/kujo-kennel/scripts/verify-multi-registry-fallback.sh; bash /path/to/kujo-kennel/scripts/verify-contract-suites.sh; bash /path/to/kujo-kennel/scripts/verify-profiles.sh core; bash /path/to/kujo-kennel/scripts/verify-stage-3-private-package-workflow.sh; bash /path/to/kujo-kennel/scripts/verify-stage-3-server-permission-workflow.sh; bash /path/to/kujo-kennel/scripts/verify-stage-3-trust-signature-workflow.sh; bash /path/to/kujo-kennel/scripts/verify-stage-3-hosted-api-workflow.sh
- Result: pass; primary+mirror routing resolves deterministically, name-based lookup/search traverse configured indexes in stable order, and core/stage-3 verification gates remain green.
- README/docs updated: yes; README.md, docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Follow-ups: DOC-006

- Date: 2026-05-28
- Item: FEAT-002
- Summary: Added optional semver range resolution mode (`[policy.resolution].semver_ranges`) with deterministic highest-compatible tag selection and persisted range metadata for add/update/install flows.
- Files changed: src/utils.kujo, src/dependency_spec.kujo, src/resolver.kujo, resolver.kujo, src/manifest.kujo, src/commands_shared.kujo, commands_shared.kujo, src/commands_dependency.kujo, src/commands_hosted.kujo, scripts/verify-semver-range-resolution.sh, scripts/verify-all.sh, tests/contracts/cli-and-core-contract_tests.kujo, README.md, docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Tests/validation run: bash ./scripts/verify-semver-range-resolution.sh; bash ./scripts/verify-contract-suites.sh; bash ./scripts/verify-profiles.sh core; bash ./scripts/verify-stage-3-private-package-workflow.sh; bash ./scripts/verify-stage-3-server-permission-workflow.sh; bash ./scripts/verify-stage-3-trust-signature-workflow.sh; bash ./scripts/verify-stage-3-hosted-api-workflow.sh
- Result: pass; semver ranges resolve deterministically when enabled and fail safely with clear ref diagnostics when disabled.
- README/docs updated: yes; README.md, docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Follow-ups: FEAT-003

- Date: 2026-05-28
- Item: FEAT-001
- Summary: Added deterministic transitive dependency graph resolution for add/install/update/install-hosted lock rebuilds, including explicit conflict diagnostics for incompatible transitive source specs.
- Files changed: src/installer.kujo, src/commands_shared.kujo, src/commands_dependency.kujo, src/commands_hosted.kujo, scripts/verify-transitive-resolution.sh, scripts/verify-all.sh, README.md, docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Tests/validation run: bash ./scripts/verify-transitive-resolution.sh; bash ./scripts/verify-contract-suites.sh; bash ./scripts/verify-profiles.sh core; bash ./scripts/verify-stage-3-private-package-workflow.sh; bash ./scripts/verify-stage-3-server-permission-workflow.sh; bash ./scripts/verify-stage-3-trust-signature-workflow.sh; bash ./scripts/verify-stage-3-hosted-api-workflow.sh
- Result: pass; transitive trees are installed/locked deterministically and conflicting transitive specs fail with actionable dependency conflict diagnostics.
- README/docs updated: yes; README.md, docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Follow-ups: FEAT-002

- Date: 2026-05-27
- Item: SEC-007
- Summary: Added strict source-policy enforcement for mutable refs across add/install/update/install-hosted workflows, with explicit CLI override support and actionable remediation guidance.
- Files changed: src/commands_shared.kujo, commands_shared.kujo, src/commands_dependency.kujo, src/commands_hosted.kujo, kennel.kujo, src/manifest.kujo, src/cli.kujo, tests/contracts/cli-and-core-contract_tests.kujo, README.md, docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Tests/validation run: bash ./scripts/verify-contract-suites.sh; bash ./scripts/verify-profiles.sh core; bash ./scripts/verify-stage-3-private-package-workflow.sh; bash ./scripts/verify-stage-3-server-permission-workflow.sh; bash ./scripts/verify-stage-3-trust-signature-workflow.sh; bash ./scripts/verify-stage-3-hosted-api-workflow.sh
- Result: pass; strict mutable-ref policy now blocks unsafe refs by default when enabled and allows explicit operator override via --allow-mutable-ref.
- README/docs updated: yes; README.md, docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Follow-ups: FEAT-001

- Date: 2026-05-27
- Item: SEC-006
- Summary: Added release SBOM+attestation workflow with pinned actions, integrity manifest generation, and workflow contract checks enforcing provenance structure.
- Files changed: .github/workflows/release-sbom-attestation.yml, scripts/generate-integrity-manifest.sh, scripts/verify-release-sbom-attestation-workflow.sh, scripts/verify-all.sh, scripts/verify-shell-quality.sh, docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Tests/validation run: bash ./scripts/verify-release-sbom-attestation-workflow.sh; bash ./scripts/verify-contract-suites.sh; bash ./scripts/verify-profiles.sh core; bash ./scripts/verify-stage-3-private-package-workflow.sh; bash ./scripts/verify-stage-3-server-permission-workflow.sh; bash ./scripts/verify-stage-3-trust-signature-workflow.sh; bash ./scripts/verify-stage-3-hosted-api-workflow.sh
- Result: pass; release workflow now emits SBOM artifact and provenance attestation with contract-enforced pinned-action configuration.
- README/docs updated: yes; docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Follow-ups: SEC-007

- Date: 2026-05-27
- Item: PERF-002
- Summary: Added shared Linux Kujo runtime build artifact job in stage1 CI and switched Ubuntu verification/profile jobs to download and reuse that artifact.
- Files changed: .github/workflows/stage1-verification.yml, scripts/verify-stage-1-ci-workflow.sh, docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Tests/validation run: bash ./scripts/verify-stage-1-ci-workflow.sh; bash ./scripts/verify-contract-suites.sh; bash ./scripts/verify-profiles.sh core; bash ./scripts/verify-stage-3-private-package-workflow.sh; bash ./scripts/verify-stage-3-server-permission-workflow.sh; bash ./scripts/verify-stage-3-trust-signature-workflow.sh; bash ./scripts/verify-stage-3-hosted-api-workflow.sh
- Result: pass; workflow contract enforces artifact reuse and bounded Kujo build-step count.
- README/docs updated: yes; docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Follow-ups: SEC-006

- Date: 2026-05-27
- Item: PERF-001
- Summary: Added deterministic benchmark harness for install/update/api-search/api-metadata paths, added CI dry-run contract verification, and documented threshold-based regression review policy.
- Files changed: scripts/benchmark-harness.sh, scripts/verify-benchmark-harness.sh, scripts/verify-all.sh, .github/workflows/stage1-verification.yml, scripts/verify-stage-1-ci-workflow.sh, docs/performance-benchmarking.md, docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, README.md, CHANGELOG.md
- Tests/validation run: bash ./scripts/verify-benchmark-harness.sh; bash ./scripts/benchmark-harness.sh; bash ./scripts/verify-contract-suites.sh; bash ./scripts/verify-profiles.sh core; bash ./scripts/verify-stage-3-private-package-workflow.sh; bash ./scripts/verify-stage-3-server-permission-workflow.sh; bash ./scripts/verify-stage-3-trust-signature-workflow.sh; bash ./scripts/verify-stage-3-hosted-api-workflow.sh
- Result: pass; benchmark harness emits deterministic JSON and CI dry-run contract checks are enforced.
- README/docs updated: yes; README.md, docs/performance-benchmarking.md, docs/KENNEL_ENTERPRISE_EXCELLENCE_CHECKLIST.md, CHANGELOG.md
- Follow-ups: PERF-002
