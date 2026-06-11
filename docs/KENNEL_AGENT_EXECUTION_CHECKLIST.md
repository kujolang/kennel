# Kennel Agent Execution Checklist

This document is the operational backlog for incremental, agent-driven improvements to Kennel.

## Goal

Raise Kennel from production-capable to production-hardened by improving:
- security posture
- architectural maintainability
- repository ergonomics
- test depth and reliability
- contributor documentation and release confidence

## How Agents Must Work This Checklist

1. Read this file first, then read README.md.
2. Only pick unchecked actionable items.
3. Pick the first unchecked actionable item in top-to-bottom order.
4. Complete exactly one actionable item per loop unless blocked.
5. If blocked, leave the item unchecked and add a blocker note directly under the item.
6. Blocker format:
   Blocker (YYYY-MM-DD): <reason>. Evidence: <command output, failing test, or file proof>.
7. Mark completion only after code, tests, and docs are updated.
8. Mark completion by changing the checkbox from [ ] to [x].
9. Add a Work Log entry for every completed item.
10. Keep changes tightly scoped to the selected item.
11. Update README.md when behavior, commands, file layout, or guarantees change.

## Status Legend

- [ ] Not started
- [~] In progress
- [x] Completed

## Current Findings Snapshot

1. Command orchestration and workflow logic are heavily centralized in kennel.kujo, making regression surface large for each command change.
2. Hosted registry behavior, trust policy checks, token storage, and metadata mutation are concentrated in future_resolvers.kujo, with several responsibilities mixed in one file.
3. parent_dir_path is duplicated across kennel.kujo and installer.kujo.
4. Token storage defaults to .kennel_tokens.json in the current working directory, which can cause accidental token placement in tracked project paths.
5. Token store writes are plain JSON without explicit permission hardening.
6. Metadata path handling trusts registry/index metadata paths and should be constrained to safe boundaries.
7. Registry index and metadata updates are multi-file writes without explicit transactional/atomic guarantees.
8. Command update performs per-dependency resolution and then rebuilds lockfile from manifest, causing redundant resolution/install work.
9. Verification coverage is broad but distributed across many shell scripts, which raises maintenance overhead.
10. Contract tests are concentrated in one file, reducing modularity and targeted failure triage speed.
11. README is technically accurate but still reads like an internal engineering reference and does not present enterprise-facing positioning, support boundaries, or release guarantees.
12. Documentation still contains stale references to `tests/kennel_contract_tests.kujo` after suite-split rollout, which can mislead operators.
13. .gitignore currently excludes only `kennel_packages/` and `.kennel_tmp/`, leaving local registry/token/test artifact patterns under-specified.
14. CI currently covers stage-1 plus stage2/stage3 profiles but does not run the security profile as a first-class required gate.
15. CI does not include dedicated static workflow checks (shell script linting/format validation) that catch script regressions before runtime.
16. CI workflows still use floating GitHub Action references and do not define explicit minimum token permissions, leaving avoidable supply-chain and token-scope risk.
17. CI validates stage-critical profiles on Ubuntu only; there is no macOS smoke gate despite documented local macOS support.
18. There is no scheduled/nightly full-profile CI run, which limits early detection of long-tail regressions that may not be exercised in every PR.
19. Static shell quality currently verifies shebang/strict-mode/bash syntax only; ShellCheck-level diagnostics are not enforced in CI.
20. Local validation logs accumulate heavily under `.kennel_tmp/` and there is no first-class cleanup script to keep developer environments tidy.

## Actionable Backlog

## Tier 0: Security and Integrity

### SEC-001 Token Store Permissions Hardening
- [x] Enforce restrictive file permissions for auth token store writes and fail closed when safe permissions cannot be applied.

Implementation expectations:
- Ensure auth token writes use least-privilege file modes.
- Add explicit error messaging when permission hardening fails.

Acceptance criteria:
- Token store file is not world-readable by default.
- Existing login flows still pass.

Validation/testing expectations:
- Add contract test coverage for token-store permission behavior.
- Run tests/kennel_contract_tests.kujo and affected verify-stage-3 login scripts.

### SEC-002 Token Store Location Safety
- [x] Replace cwd-based token-store default with a safer deterministic location and document migration behavior.

Implementation expectations:
- Avoid silently dropping token files into arbitrary invocation directories.
- Keep explicit --store-path behavior unchanged.

Acceptance criteria:
- Default location is stable and documented.
- No token leakage in command output.

Validation/testing expectations:
- Add tests for default path resolution and backward compatibility.
- Run verify-stage-3-login-workflow.sh.

### SEC-003 Registry Metadata Path Guardrails
- [x] Validate metadata_path values from index data to prevent directory traversal and out-of-bound reads/writes.

Implementation expectations:
- Reject absolute paths and traversal segments when operating in hosted registry mode.
- Add strict normalization checks for metadata path use.

Acceptance criteria:
- Malicious metadata_path cannot escape registry root.
- Error messages are explicit and actionable.

Validation/testing expectations:
- Add regression tests for traversal attempts on search/metadata/access/visibility/yank paths.
- Run hosted API and server-permission workflow scripts.

### SEC-004 Manifest/Lockfile and Index/Metadata Atomicity
- [x] Introduce stronger atomic write semantics for paired file updates (manifest+lock, index+metadata) with rollback guarantees.

Implementation expectations:
- Prevent partial state when one of paired writes fails.
- Preserve successful command behavior and messages.

Acceptance criteria:
- Injected write failure does not leave mixed old/new state.

Validation/testing expectations:
- Extend verify-atomicity.sh with index/metadata partial-write scenarios.
- Add contract-level failure-path tests.

### SEC-005 Trust Policy Verification Depth
- [x] Extend trust verification beyond literal field equality with stronger semantic checks and clearer diagnostics.

Implementation expectations:
- Keep checksum format validation strict.
- Improve mismatch diagnostics for checksum/signature/signing_key.

Acceptance criteria:
- Validation errors distinguish malformed metadata from policy mismatches.

Validation/testing expectations:
- Add tests for malformed package metadata trust fields.
- Run verify-stage-3-trust-signature-workflow.sh.

## Tier 1: Architecture and DRY Refactors

### ARC-001 Extract Shared Path Helpers
- [x] Remove duplicated parent_dir_path and centralize path helper utilities.

Implementation expectations:
- Keep behavior identical.
- Minimize call-site churn.

Acceptance criteria:
- No duplicate helper remains.
- Existing installer and info flows remain green.

Validation/testing expectations:
- Run contract tests and deterministic-lockfile scripts.

### ARC-002 Split Hosted Registry Domain Module
- [x] Break future_resolvers.kujo into focused modules (token store, index IO, metadata mutation, hosted API read paths, trust verification).

Implementation expectations:
- Preserve exported behavior.
- Keep command UX backward compatible.

Acceptance criteria:
- Smaller modules with clear ownership and boundaries.
- No behavior regressions in hosted workflows.

Validation/testing expectations:
- Run all verify-stage-3-*.sh scripts.
- Run tests/kennel_contract_tests.kujo.

### ARC-003 Split Command Router From Command Implementations
- [x] Refactor kennel.kujo into a thin command dispatcher and command-focused modules.

Implementation expectations:
- Keep CLI surface unchanged.
- Keep --project-dir behavior unchanged.

Acceptance criteria:
- kennel.kujo primarily routes and delegates.
- Dependency lifecycle and hosted commands live in separate modules.

Validation/testing expectations:
- Run verify-all.sh core and contract tests.

### ARC-004 Reduce Rebuild Redundancy in Update Flow
- [x] Avoid redundant resolve/install cycles during update by removing unnecessary full rebuild passes when safe.

Implementation expectations:
- Preserve deterministic lockfile behavior.
- Keep pinned ref protections.

Acceptance criteria:
- Update performs no duplicate install work for already-updated dependencies.
- Lockfile output remains deterministic.

Validation/testing expectations:
- Run verify-pinned-refs.sh, verify-deterministic-lockfile.sh, verify-stage-2-deterministic-lockfile.sh.

### ARC-005 Introduce Internal Error Shape Consistency
- [x] Standardize error object schema and mapping to CLI output for command handlers.

Implementation expectations:
- Unify keys like ok/error/context across modules.
- Improve diagnostics while preserving existing success output.

Acceptance criteria:
- Fewer ad-hoc error shapes.
- Better testability of failure paths.

Validation/testing expectations:
- Add targeted tests for standardized error contracts.

## Tier 2: Repository and Developer Experience

### DX-001 Clean Root Module Layout
- [x] Move core Kujo modules from repository root into a structured src tree and preserve executable entrypoint compatibility.

Implementation expectations:
- Keep kennel.kujo entry command working.
- Update imports and docs consistently.

Acceptance criteria:
- Root directory is cleaner and easier to scan.
- Developer onboarding still works with documented commands.

Validation/testing expectations:
- Run verify-kujo-native-direction.sh (or updated equivalent).
- Run verify-all.sh core.

### DX-002 Add Unified Test/Profile Runner
- [x] Add a single script entrypoint for grouped validation profiles (core, stage2, stage3, security, full).

Implementation expectations:
- Preserve existing leaf scripts.
- Provide clear profile selection and failure summaries.

Acceptance criteria:
- One command can run targeted suites by profile.

Validation/testing expectations:
- Add tests for profile routing logic.

### DX-003 Standardize Script Configuration Inputs
- [x] Normalize environment variable and path conventions across verify scripts.

Implementation expectations:
- Reduce hardcoded path assumptions.
- Keep local dev ergonomics straightforward.

Acceptance criteria:
- Consistent variable names and defaults across scripts.

Validation/testing expectations:
- Smoke-run core scripts with explicit env overrides.

### DX-004 Add Command-Level Help Expansion
- [x] Expand help output with command examples, common failure recovery guidance, and security best-practice hints.

Implementation expectations:
- Keep help concise but practical.
- Avoid leaking sensitive details.

Acceptance criteria:
- New users can complete init/add/install/login/publish flow from help.

Validation/testing expectations:
- Add output assertions to verify-cli-messages.sh.

## Tier 3: Test Coverage Expansion

### TEST-001 Split Monolithic Contract Test File
- [x] Break tests/kennel_contract_tests.kujo into domain-focused suites with a single orchestration runner.

Implementation expectations:
- Keep equivalent or better coverage.
- Maintain clear naming and suite boundaries.

Acceptance criteria:
- Faster triage from failing suite.
- Existing CI still runs expected tests.

Validation/testing expectations:
- Run all resulting suites plus verify-all.sh core.

### TEST-002 Add CLI Parser Unit Coverage
- [x] Add dedicated tests for parse_cli, has_flag, flag_value, positional edge cases.

Implementation expectations:
- Cover --flag value, --flag=value, boolean flags, unknown tokens, and mixed positionals.

Acceptance criteria:
- Parser edge behavior is explicitly locked by tests.

Validation/testing expectations:
- Run targeted parser tests and contract suite.

### TEST-003 Add Command Handler Failure Matrix
- [x] Add tests for command-level failure scenarios not currently covered by scripts.

Implementation expectations:
- Cover missing manifests, invalid project-dir, malformed index JSON, malformed metadata JSON.

Acceptance criteria:
- Command failure pathways have stable diagnostics.

Validation/testing expectations:
- Run added tests plus verify-cli-messages.sh.

### TEST-004 Add Path and Registry Security Regression Suite
- [x] Add security regression tests for path traversal, unsafe metadata path, and token store misuse cases.

Implementation expectations:
- Focus on hosted registry read/write operations and install-hosted flows.

Acceptance criteria:
- Regressions fail loudly and deterministically.

Validation/testing expectations:
- Add new tests and run stage-3 hosted/security scripts.

### TEST-005 Add Atomicity Fault-Injection Tests
- [x] Add deterministic fault injection tests around write_file/save routines for paired state updates.

Implementation expectations:
- Simulate mid-flow failure after one write succeeds.

Acceptance criteria:
- Rollback/restore behavior is verified.

Validation/testing expectations:
- Extend verify-atomicity.sh and add contract coverage.

## Tier 4: Documentation and Operations

### DOC-001 Update README for New Architecture and Layout
- [x] Keep README aligned with module locations, command examples, and verification entrypoints.

Implementation expectations:
- Reflect any src/ layout changes and test runner profiles.

Acceptance criteria:
- README command examples execute as documented.

Validation/testing expectations:
- Run referenced core examples.

### DOC-002 Add Maintainer Runbook
- [x] Create a concise runbook for release checks, emergency rollback, and incident response actions.

Implementation expectations:
- Include minimum required verification profiles per change type.

Acceptance criteria:
- Maintainers can execute release flow from runbook alone.

Validation/testing expectations:
- Dry-run runbook commands in a clean environment.

### DOC-003 Tighten Security Documentation
- [x] Expand security guidance for token handling, trust policy usage, private package workflows, and permission boundaries.

Implementation expectations:
- Keep guidance concrete and command-oriented.

Acceptance criteria:
- Security docs match runtime behavior and test coverage.

Validation/testing expectations:
- Cross-check against stage-3 scripts and trust tests.

### OPS-001 Expand CI Coverage Beyond Stage 1
- [x] Add CI jobs or matrix profiles for stage-2 and stage-3 critical gates.

Implementation expectations:
- Keep runtime/cost balanced with confidence needs.

Acceptance criteria:
- CI catches regressions in hosted workflows and schema compatibility.

Validation/testing expectations:
- Verify workflow contracts similarly to verify-stage-1-ci-workflow.sh.

### OPS-002 Add Change-Type Validation Policy
- [x] Define required validation profiles by change family (security, architecture, feature, docs-only) and enforce in CI/docs.

Implementation expectations:
- Keep policy simple and repeatable.

Acceptance criteria:
- Every PR type has clear minimum validation requirements.

Validation/testing expectations:
- Add policy docs and workflow checks where appropriate.

## Tier 5: Enterprise Release Readiness (2026-05-22 Audit)

### DOC-004 Reposition README for Enterprise Consumers
- [x] Rewrite README into a forward-facing enterprise product document with explicit guarantees, supported environments, security posture summary, and clear adoption path.

Implementation expectations:
- Lead with value proposition, release confidence signals, and production constraints.
- Separate quickstart from production rollout guidance.

Acceptance criteria:
- README presents Kennel as a professional enterprise-grade tool, not only an internal dev utility.
- Security, support boundaries, and validation expectations are easy to find.

Validation/testing expectations:
- Dry-run README commands in a clean environment.
- Cross-check enterprise claims against existing scripts/docs.

### DOC-005 Remove Stale Contract-Test References Across Docs
- [x] Replace legacy references to `tests/kennel_contract_tests.kujo` with the split-suite runner and suite paths where appropriate.

Implementation expectations:
- Update security model, runbook, and status docs to use `scripts/verify-contract-suites.sh`.
- Preserve historical references only when explicitly marked as archival.

Acceptance criteria:
- Operator-facing docs no longer instruct monolithic contract suite execution as the primary path.

Validation/testing expectations:
- Grep scan for stale contract-suite references in `docs/`.

### DX-005 Harden Ignore Rules for Local Runtime Artifacts
- [x] Expand `.gitignore` to cover local registry, token stores, transient validation outputs, and common local environment artifacts.

Implementation expectations:
- Keep ignore scope minimal-but-safe (do not hide source artifacts that should be tracked).
- Include patterns for local auth/registry files generated by verification workflows.

Acceptance criteria:
- Running stage and security scripts does not produce noisy untracked sensitive/transient files.

Validation/testing expectations:
- Run targeted verify scripts and confirm `git status --short` stays clean.

### OPS-003 Add Security Profile as Required CI Gate
- [x] Extend GitHub Actions to run `verify-profiles.sh security` as a required gate alongside stage2/stage3 profiles.

Implementation expectations:
- Reuse existing Kujo build setup and keep workflow runtime acceptable.
- Keep profile matrix extensible for future release-candidate gates.

Acceptance criteria:
- CI fails on security profile regressions before merge.

Validation/testing expectations:
- Update and run workflow contract checks.

### OPS-004 Add CI Static Script Quality Gate
- [x] Add a GitHub Actions job for shell script static checks (e.g., shellcheck) and basic script consistency validation.

Implementation expectations:
- Focus on `scripts/verify-*.sh` plus workflow helper scripts.
- Fail fast on shell syntax/quoting regressions.

Acceptance criteria:
- Script-level regressions are caught before runtime profile execution.

Validation/testing expectations:
- Ensure static-check job is wired into PR and push workflows.

## Tier 6: Additional Production Hardening (2026-05-22 Follow-up Audit)

### OPS-005 Pin CI Actions and Restrict Workflow Permissions
- [x] Pin third-party GitHub Actions to immutable commit SHAs and define explicit least-privilege workflow permissions.

Implementation expectations:
- Replace floating action references (`@v4`, `@stable`) with pinned commit SHAs.
- Add explicit top-level/job-level `permissions` blocks using minimum required scopes.

Acceptance criteria:
- CI no longer depends on mutable action tags.
- Workflow token permissions are explicit and least privilege.

Validation/testing expectations:
- Update workflow contract checks to assert pinned actions and permissions policy.
- Run stage-1 CI workflow contract verification.

### OPS-006 Add Nightly Full-Profile Regression Workflow
- [x] Add a scheduled GitHub Actions workflow that runs `verify-profiles.sh full` and preserves logs/artifacts for triage.

Implementation expectations:
- Trigger nightly and support manual dispatch.
- Keep runtime failure diagnostics accessible via uploaded artifacts.

Acceptance criteria:
- Full-profile regressions are detected without waiting for feature PRs.
- Maintainers can inspect artifacts from failed nightly runs.

Validation/testing expectations:
- Add and run workflow contract verification for the nightly pipeline.

### OPS-007 Add macOS Smoke CI Gate
- [x] Add a lightweight macOS CI gate for command/help/core smoke validation.

Implementation expectations:
- Keep scope minimal to control runtime cost.
- Reuse existing profile/scripts where practical.

Acceptance criteria:
- At least one required CI job validates Kennel behavior on `macos-latest`.

Validation/testing expectations:
- Verify workflow definitions and run script contract checks.

### OPS-008 Expand Static Script Checks with ShellCheck
- [x] Extend static shell quality validation to run ShellCheck on verification scripts.

Implementation expectations:
- Integrate ShellCheck into CI static script gate.
- Keep existing shebang/strict-mode/bash-syntax checks.

Acceptance criteria:
- Shell lint warnings/errors fail CI.
- Script quality gate catches quoting/subshell/pipeline pitfalls earlier.

Validation/testing expectations:
- Run updated shell-quality script locally and in CI contract validation.

### DX-006 Add Local Artifact Cleanup Entrypoint
- [x] Add a dedicated cleanup script for transient local validation artifacts under `.kennel_tmp/`.

Implementation expectations:
- Provide a safe, documented cleanup command.
- Preserve tracked files and avoid destructive behavior outside known temp paths.

Acceptance criteria:
- Developers can reset local artifact clutter with one command.
- Repository working tree remains easier to inspect during long validation cycles.

Validation/testing expectations:
- Run cleanup script and verify expected temp logs are removed without deleting source files.

## Item Completion Template

Use this exact format in the Work Log when an item is completed:

- Date: YYYY-MM-DD
- Item: <ITEM_ID>
- Summary: <what changed>
- Files changed: <comma-separated list>
- Tests/validation run: <commands>
- Result: <pass/fail + short evidence>
- README/docs updated: <yes/no + file list>
- Follow-ups: <none or short list>

## Work Log

Append new entries at the top.

- Date: 2026-05-22
- Item: DX-006
- Summary: Added a safe local cleanup entrypoint for `.kennel_tmp` artifacts, documented it in maintainer/user docs, and wired the script into static shell quality checks.
- Files changed: scripts/cleanup-local-artifacts.sh, scripts/verify-shell-quality.sh, README.md, docs/maintainer-runbook.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: chmod +x scripts/cleanup-local-artifacts.sh && mkdir -p .kennel_tmp/dx006-test && echo temporary > .kennel_tmp/dx006-test/sample.log && bash ./scripts/cleanup-local-artifacts.sh && test ! -e .kennel_tmp/dx006-test/sample.log && test -f README.md; export KUJO_BIN=/path/to/kujo/target/debug/kujo && bash ./scripts/verify-shell-quality.sh; export KUJO_BIN=/path/to/kujo/target/debug/kujo && bash ./scripts/verify-profiles.sh core
- Result: pass
- README/docs updated: yes (README.md, docs/maintainer-runbook.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: OPS-008
- Summary: Extended static shell quality checks to include ShellCheck linting, added CI installation/enforcement settings, and updated workflow contract checks for ShellCheck policy entries.
- Files changed: scripts/verify-shell-quality.sh, .github/workflows/stage1-verification.yml, scripts/verify-stage-1-ci-workflow.sh, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: export KUJO_BIN=/path/to/kujo/target/debug/kujo && bash ./scripts/verify-shell-quality.sh; export KUJO_BIN=/path/to/kujo/target/debug/kujo && bash ./scripts/verify-stage-1-ci-workflow.sh; export KUJO_BIN=/path/to/kujo/target/debug/kujo && bash ./scripts/verify-change-type-policy.sh
- Result: pass (local run skipped ShellCheck because binary is unavailable; CI job now installs and enforces it)
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: OPS-007
- Summary: Added a required macOS CI smoke job and a lightweight smoke script covering help/init/validate/list flows, with workflow contract enforcement.
- Files changed: .github/workflows/stage1-verification.yml, scripts/verify-macos-smoke.sh, scripts/verify-stage-1-ci-workflow.sh, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: export KUJO_BIN=/path/to/kujo/target/debug/kujo && bash ./scripts/verify-macos-smoke.sh; export KUJO_BIN=/path/to/kujo/target/debug/kujo && bash ./scripts/verify-stage-1-ci-workflow.sh; export KUJO_BIN=/path/to/kujo/target/debug/kujo && bash ./scripts/verify-change-type-policy.sh; export KUJO_BIN=/path/to/kujo/target/debug/kujo && bash ./scripts/verify-shell-quality.sh
- Result: pass
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: OPS-006
- Summary: Added a nightly full-profile regression workflow with manual dispatch support and artifact upload, plus a dedicated workflow contract checker.
- Files changed: .github/workflows/nightly-full-regression.yml, scripts/verify-nightly-full-regression-workflow.sh, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: export KUJO_BIN=/path/to/kujo/target/debug/kujo && bash ./scripts/verify-nightly-full-regression-workflow.sh; export KUJO_BIN=/path/to/kujo/target/debug/kujo && bash ./scripts/verify-stage-1-ci-workflow.sh; export KUJO_BIN=/path/to/kujo/target/debug/kujo && bash ./scripts/verify-change-type-policy.sh; export KUJO_BIN=/path/to/kujo/target/debug/kujo && bash ./scripts/verify-shell-quality.sh
- Result: pass
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: OPS-005
- Summary: Pinned workflow actions to immutable SHAs, added explicit least-privilege workflow permissions, and hardened CI contract checks to reject mutable action tags.
- Files changed: .github/workflows/stage1-verification.yml, scripts/verify-stage-1-ci-workflow.sh, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: export KUJO_BIN=/path/to/kujo/target/debug/kujo && bash ./scripts/verify-stage-1-ci-workflow.sh; export KUJO_BIN=/path/to/kujo/target/debug/kujo && bash ./scripts/verify-change-type-policy.sh; export KUJO_BIN=/path/to/kujo/target/debug/kujo && bash ./scripts/verify-shell-quality.sh
- Result: pass
- README/docs updated: yes (docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: OPS-004
- Summary: Added a dedicated static shell quality gate script (shebang/strict-mode checks plus `bash -n`) and wired it into GitHub Actions as a required job with workflow-contract enforcement.
- Files changed: scripts/verify-shell-quality.sh, .github/workflows/stage1-verification.yml, scripts/verify-stage-1-ci-workflow.sh, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: bash ./scripts/verify-shell-quality.sh; bash ./scripts/verify-stage-1-ci-workflow.sh
- Result: pass
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: OPS-003
- Summary: Extended CI stage-critical profile matrix to include `security` and strengthened workflow contract verification to enforce this required gate.
- Files changed: .github/workflows/stage1-verification.yml, scripts/verify-stage-1-ci-workflow.sh, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: bash ./scripts/verify-stage-1-ci-workflow.sh; bash ./scripts/verify-change-type-policy.sh
- Result: pass
- README/docs updated: yes (docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: DX-005
- Summary: Expanded ignore coverage for local registry/token artifacts, transient atomicity helper output, and common local environment noise while keeping source-tracked paths unaffected.
- Files changed: .gitignore, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: KUJO_BIN=/path/to/kujo/target/debug/kujo bash ./scripts/verify-command-failure-matrix.sh; KUJO_BIN=/path/to/kujo/target/debug/kujo bash ./scripts/verify-security-regression-suite.sh; git status --short
- Result: pass (post-validation status clean except intended tracked edits)
- README/docs updated: yes (docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: DOC-004
- Summary: Rewrote README into an enterprise-facing product document with explicit production guarantees, supported environments, security posture summary, profile-based rollout guidance, and cleaner validation entrypoints.
- Files changed: README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: /path/to/kujo/target/debug/kujo run kennel.kujo --interpreter -- help; KUJO_BIN=/path/to/kujo/target/debug/kujo bash ./scripts/verify-contract-suites.sh; KUJO_BIN=/path/to/kujo/target/debug/kujo bash ./scripts/verify-profiles.sh core
- Result: pass
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: DOC-005
- Summary: Updated operator-facing documentation to use the split contract-suite runner and suite model instead of the legacy monolithic contract test path.
- Files changed: docs/current-status-and-usage.md, docs/stage-3-security-model.md, docs/maintainer-runbook.md, docs/testing-and-delivery-roadmap.md, docs/stage-1-support-matrix.md, docs/production-hardening-backlog.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: grep -R -n "tests/kennel_contract_tests\.kujo" docs --exclude='KENNEL_AGENT_EXECUTION_CHECKLIST.md'
- Result: pass (no matches)
- README/docs updated: yes (docs/current-status-and-usage.md, docs/stage-3-security-model.md, docs/maintainer-runbook.md, docs/testing-and-delivery-roadmap.md, docs/stage-1-support-matrix.md, docs/production-hardening-backlog.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: TEST-004
- Summary: Added a dedicated hosted security regression suite covering metadata path traversal/absolute-path rejection in read and write flows plus install-hosted token-store misuse diagnostics.
- Files changed: scripts/verify-security-regression-suite.sh, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: bash ./scripts/verify-security-regression-suite.sh; bash ./scripts/verify-stage-3-hosted-api-workflow.sh; bash ./scripts/verify-stage-3-private-package-workflow.sh; bash ./scripts/verify-stage-3-server-permission-workflow.sh; bash ./scripts/verify-stage-3-trust-signature-workflow.sh
- Result: pass
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: TEST-003
- Summary: Added a dedicated command failure matrix verification script covering missing manifest, invalid project-dir, malformed static index JSON, and malformed package metadata JSON diagnostics.
- Files changed: scripts/verify-command-failure-matrix.sh, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: bash ./scripts/verify-command-failure-matrix.sh; bash ./scripts/verify-cli-messages.sh
- Result: pass
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: TEST-001
- Summary: Split contract coverage into domain-focused suites (CLI/core, registry index, hosted registry) and added a single orchestration runner script; updated CI contract step and docs to use the runner.
- Files changed: tests/contracts/cli-and-core-contract_tests.kujo, tests/contracts/registry-index-contract_tests.kujo, tests/contracts/hosted-registry-contract_tests.kujo, scripts/verify-contract-suites.sh, .github/workflows/stage1-verification.yml, scripts/verify-stage-1-ci-workflow.sh, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: bash ./scripts/verify-contract-suites.sh; bash ./scripts/verify-all.sh core
- Result: pass
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: DX-003
- Summary: Standardized verify-script Kujo binary configuration by removing hardcoded release-path defaults and normalizing `KUJO_BIN` defaults to `kujo` with explicit override support; documented the shared convention in README.
- Files changed: scripts/verify-atomicity.sh, scripts/verify-cli-messages.sh, scripts/verify-deterministic-lockfile.sh, scripts/verify-git-diagnostics.sh, scripts/verify-pinned-refs.sh, scripts/verify-stage-1-source-matrix.sh, scripts/verify-stage-1.sh, scripts/verify-stage-3-authenticated-publish-install-workflow.sh, scripts/verify-stage-3-hosted-api-workflow.sh, scripts/verify-stage-3-login-workflow.sh, scripts/verify-stage-3-ownership-workflow.sh, scripts/verify-stage-3-private-package-workflow.sh, scripts/verify-stage-3-publish-workflow.sh, scripts/verify-stage-3-server-permission-workflow.sh, scripts/verify-stage-3-trust-signature-workflow.sh, scripts/verify-stage-3-yank-workflow.sh, scripts/verify-stale-lockfile.sh, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: KUJO_BIN=/path/to/kujo/target/debug/kujo bash ./scripts/verify-all.sh core
- Result: pass
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: DX-001
- Summary: Moved core module implementations into `src/` and converted root Kujo modules to compatibility shims that re-export `src.*` symbols to preserve existing imports and executable entrypoint behavior.
- Files changed: src/cli.kujo, src/manifest.kujo, src/lockfile.kujo, src/dependency_spec.kujo, src/path_helpers.kujo, src/resolver.kujo, src/installer.kujo, src/validator.kujo, src/future_resolvers.kujo, src/hosted_auth.kujo, src/hosted_trust.kujo, src/commands_shared.kujo, src/commands_dependency.kujo, src/commands_hosted.kujo, src/error_shape.kujo, cli.kujo, manifest.kujo, lockfile.kujo, dependency_spec.kujo, path_helpers.kujo, resolver.kujo, installer.kujo, validator.kujo, future_resolvers.kujo, hosted_auth.kujo, hosted_trust.kujo, commands_shared.kujo, commands_dependency.kujo, commands_hosted.kujo, error_shape.kujo, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: bash ./scripts/verify-kujo-native-direction.sh; bash ./scripts/verify-all.sh core
- Result: pass
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: ARC-005
- Summary: Added a shared `error_result` helper and normalized shared command-helper failure paths to return `{ok,error,context}` with operation/stage metadata; added contract tests that lock the error-context shape.
- Files changed: error_shape.kujo, commands_shared.kujo, tests/kennel_contract_tests.kujo, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: /path/to/kujo/target/debug/kujo test-run tests/kennel_contract_tests.kujo; bash ./scripts/verify-all.sh core
- Result: pass
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: ARC-003
- Summary: Split command handling into dependency and hosted command modules with shared helper utilities, leaving kennel.kujo as a thin parse/project-dir/dispatch entrypoint.
- Files changed: kennel.kujo, commands_shared.kujo, commands_dependency.kujo, commands_hosted.kujo, docs/architecture-command-boundaries.md, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: /path/to/kujo/target/debug/kujo test-run tests/kennel_contract_tests.kujo; bash ./scripts/verify-all.sh core
- Result: pass
- README/docs updated: yes (README.md, docs/architecture-command-boundaries.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: OPS-002
- Summary: Added formal change-type validation policy documentation and CI enforcement via policy verification script wired into workflow and CI-contract checks.
- Files changed: docs/change-type-validation-policy.md, .github/workflows/stage1-verification.yml, scripts/verify-change-type-policy.sh, scripts/verify-stage-1-ci-workflow.sh, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: bash ./scripts/verify-change-type-policy.sh; bash ./scripts/verify-stage-1-ci-workflow.sh; bash ./scripts/verify-all.sh core
- Result: pass
- README/docs updated: yes (docs/change-type-validation-policy.md, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: OPS-001
- Summary: Added CI stage-critical matrix coverage for `stage2` and `stage3` profiles in GitHub Actions, reusing Kujo build setup and profile runner entrypoint.
- Files changed: .github/workflows/stage1-verification.yml, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: bash ./scripts/verify-stage-1-ci-workflow.sh; bash ./scripts/verify-all.sh core
- Result: pass
- README/docs updated: yes (docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-22
- Item: DOC-003
- Summary: Rewrote stage-3 security guidance with command-oriented token handling, trust-policy enforcement, private-package workflow, and owner-boundary documentation aligned to runtime behavior.
- Files changed: docs/stage-3-security-model.md, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: bash ./scripts/verify-stage-3-login-workflow.sh; bash ./scripts/verify-stage-3-private-package-workflow.sh; bash ./scripts/verify-stage-3-server-permission-workflow.sh; bash ./scripts/verify-stage-3-trust-signature-workflow.sh; /path/to/kujo/target/debug/kujo test-run tests/kennel_contract_tests.kujo
- Result: pass
- README/docs updated: yes (docs/stage-3-security-model.md, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-21
- Item: DOC-002
- Summary: Added maintainer runbook covering release checks, rollback steps, incident response workflow, and minimum validation profiles by change type.
- Files changed: docs/maintainer-runbook.md, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: RUNNER_DRY_RUN=1 bash ./scripts/verify-profiles.sh core; RUNNER_DRY_RUN=1 bash ./scripts/verify-profiles.sh security; RUNNER_DRY_RUN=1 bash ./scripts/verify-profiles.sh full
- Result: pass
- README/docs updated: yes (docs/maintainer-runbook.md, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-21
- Item: DOC-001
- Summary: Refreshed README layout and validation sections with explicit current module-location note and profile intent mapping for core/stage2/stage3/security/full entrypoints.
- Files changed: README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: /path/to/kujo/target/debug/kujo run kennel.kujo --interpreter -- help; bash ./scripts/verify-profiles.sh core
- Result: pass
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-21
- Item: TEST-005
- Summary: Verified existing deterministic paired-write fault-injection coverage from SEC-004 satisfies atomicity regression requirements (script + contract coverage).
- Files changed: docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: bash ./scripts/verify-atomicity.sh; /path/to/kujo/target/debug/kujo test-run tests/kennel_contract_tests.kujo
- Result: pass
- README/docs updated: yes (docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-21
- Item: TEST-002
- Summary: Added dedicated parser coverage for `--flag value`, `--flag=value`, boolean flags, unknown command token handling, mixed positional parsing, and accessor fallback behavior.
- Files changed: tests/kennel_contract_tests.kujo, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: /path/to/kujo/target/debug/kujo test-run tests/kennel_contract_tests.kujo; bash ./scripts/verify-cli-messages.sh
- Result: pass
- README/docs updated: yes (docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-21
- Item: DX-004
- Summary: Expanded `kennel help` with practical command examples, recovery guidance for common failures, and security handling hints; added help-output assertions to CLI verification.
- Files changed: cli.kujo, scripts/verify-cli-messages.sh, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: bash ./scripts/verify-cli-messages.sh; /path/to/kujo/target/debug/kujo test-run tests/kennel_contract_tests.kujo; bash ./scripts/verify-all.sh core
- Result: pass
- README/docs updated: yes (docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-21
- Item: DX-002
- Summary: Added a unified profile runner for core/stage2/stage3/security/full suites plus routing validation coverage.
- Files changed: scripts/verify-profiles.sh, scripts/verify-profile-runner.sh, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: bash ./scripts/verify-profile-runner.sh; bash ./scripts/verify-profiles.sh core; /path/to/kujo/target/debug/kujo test-run tests/kennel_contract_tests.kujo; bash ./scripts/verify-all.sh core
- Result: pass
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-21
- Item: ARC-004
- Summary: Added update/install cache-aware lock rebuilds so command_update reuses freshly resolved installs and avoids duplicate install work for already-updated dependencies.
- Files changed: kennel.kujo, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: /path/to/kujo/target/debug/kujo test-run tests/kennel_contract_tests.kujo; bash ./scripts/verify-pinned-refs.sh; bash ./scripts/verify-deterministic-lockfile.sh; bash ./scripts/verify-stage-2-deterministic-lockfile.sh
- Result: pass
- README/docs updated: yes (docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-21
- Item: ARC-002
- Summary: Split hosted auth token store and trust verification logic into dedicated hosted_auth and hosted_trust modules while preserving future_resolvers API compatibility.
- Files changed: hosted_auth.kujo, hosted_trust.kujo, future_resolvers.kujo, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: /path/to/kujo/target/debug/kujo test-run tests/kennel_contract_tests.kujo; for script in ./scripts/verify-stage-3-*.sh; do bash "$script"; done
- Result: pass
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-21
- Item: ARC-001
- Summary: Removed duplicated parent_dir_path implementations by introducing a shared path_helpers module and updating installer/registry metadata callers.
- Files changed: path_helpers.kujo, installer.kujo, kennel.kujo, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: /path/to/kujo/target/debug/kujo test-run tests/kennel_contract_tests.kujo; bash ./scripts/verify-deterministic-lockfile.sh
- Result: pass
- README/docs updated: yes (docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-21
- Item: SEC-005
- Summary: Strengthened trust-policy semantics and added explicit malformed-vs-mismatch diagnostics via error_kind/field classification in signature verification.
- Files changed: future_resolvers.kujo, tests/kennel_contract_tests.kujo, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: /path/to/kujo/target/debug/kujo test-run tests/kennel_contract_tests.kujo; bash ./scripts/verify-stage-3-trust-signature-workflow.sh; bash ./scripts/verify-all.sh core
- Result: pass
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-21
- Item: SEC-004
- Summary: Added paired index/metadata atomic persistence with rollback restore on write failure and deterministic fault-injection coverage.
- Files changed: future_resolvers.kujo, tests/kennel_contract_tests.kujo, scripts/verify-atomicity.sh, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: /path/to/kujo/target/debug/kujo test-run tests/kennel_contract_tests.kujo; bash ./scripts/verify-atomicity.sh; bash ./scripts/verify-all.sh core
- Result: pass
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-21
- Item: SEC-003
- Summary: Added hosted registry metadata_path guardrails to block absolute/traversal paths and enforce registry-root boundaries across hosted operations.
- Files changed: future_resolvers.kujo, tests/kennel_contract_tests.kujo, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: /path/to/kujo/target/debug/kujo test-run tests/kennel_contract_tests.kujo; bash ./scripts/verify-stage-3-hosted-api-workflow.sh; bash ./scripts/verify-stage-3-server-permission-workflow.sh; bash ./scripts/verify-all.sh core
- Result: pass
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-21
- Item: SEC-002
- Summary: Moved default auth token store from invocation cwd to a stable home-based path and added coverage for default-path behavior.
- Files changed: future_resolvers.kujo, tests/kennel_contract_tests.kujo, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: /path/to/kujo/target/debug/kujo test-run tests/kennel_contract_tests.kujo; bash ./scripts/verify-stage-3-login-workflow.sh; bash ./scripts/verify-all.sh core
- Result: pass
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: 2026-05-21
- Item: SEC-001
- Summary: Added fail-closed token-store write hardening with restrictive file permissions and contract test coverage.
- Files changed: future_resolvers.kujo, tests/kennel_contract_tests.kujo, README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md
- Tests/validation run: kujo test-run tests/kennel_contract_tests.kujo; bash ./scripts/verify-stage-3-login-workflow.sh; bash ./scripts/verify-all.sh core
- Result: pass
- README/docs updated: yes (README.md, docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md)
- Follow-ups: none

- Date: YYYY-MM-DD
- Item: 
- Summary: 
- Files changed: 
- Tests/validation run: 
- Result: 
- README/docs updated: 
- Follow-ups: 
