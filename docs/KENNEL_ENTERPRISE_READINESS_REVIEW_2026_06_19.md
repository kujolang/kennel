# Kennel Enterprise Readiness Review - 2026-06-19

## Review Answer

Kennel is production-oriented and strong for its launch-safe scope, but it should not be described as universally enterprise-grade yet.

The current codebase is a credible flagship Kujo example for deterministic local/source package management, static-index routing, local hosted-registry workflows, trust checks, source-policy gates, and validation automation. To become a universally useful enterprise package ecosystem, the remaining work is less about basic correctness and more about scale, provenance, operated-registry readiness, and adoption polish.

## Search Exclusions Used

Broad review searches excluded generated and bulk runtime paths:

```bash
rg "pattern" --glob '!.kennel_tmp/**' --glob '!kennel_packages/**'
```

Fixture and contract paths were included when reviewing behavior, tests, and output contracts. Copyable-example review treated `README.md` Quick Start and `examples/basic-project/` as the canonical user-facing examples.

## What Changed In This Pass

- Preserved root `.kujo` files as intentional compatibility shims for `src/` modules.
- Fixed `--flag=value` parsing so payloads containing additional `=` characters, such as token-like strings, are preserved.
- Hardened installer path handling so unsafe package install names are rejected before local copy or git clone work starts.
- Added contract coverage for complete equals-preserving flag parsing and unsafe installer path rejection.
- Updated README and status docs to distinguish launch-safe readiness from universal enterprise ecosystem readiness.

## Validation Completed

```bash
KUJO_BIN=/Users/robertdevore/2026/Kujolang/kujo-repos/kujo/target/release/kujo bash scripts/verify-all.sh
KUJO_BIN=/Users/robertdevore/2026/Kujolang/kujo-repos/kujo/target/release/kujo bash scripts/verify-profiles.sh stage3
KUJO_BIN=/Users/robertdevore/2026/Kujolang/kujo-repos/kujo/target/release/kujo bash scripts/verify-security-regression-suite.sh
KUJO_BIN=/Users/robertdevore/2026/Kujolang/kujo-repos/kujo/target/release/kujo bash scripts/verify-contract-suites.sh
/Users/robertdevore/2026/Kujolang/kujo-repos/kujo/target/release/kujo test-run tests/kennel_contract_tests.kujo
```

Results:

- Full verification gate: passed.
- Stage3 profile gate: passed.
- Security regression suite: passed.
- Split contract suites: 43 total, 43 passed.
- Monolithic contract fixture: 34 total, 34 passed.

## Next-Session Backlog

### P0 - Supply-Chain Provenance

- [ ] Enforce provenance metadata for hosted install paths.
  - Current state: trust policy checks checksum/signature fields, but hosted downloads still depend on registry metadata rather than a complete artifact provenance chain.
  - Target: lock entries can record provenance fields such as source commit, registry metadata path, attestation reference, and verification status.
  - Acceptance: hosted install tests fail closed when required provenance metadata is missing or malformed.

- [ ] Add a release artifact verification drill.
  - Current state: SBOM/attestation workflow structure exists, but local verification ergonomics are thin.
  - Target: one documented command verifies release SBOM/attestation artifacts against the current commit.
  - Acceptance: CI contract check and maintainer docs cover the verification path.

### P1 - Performance And Scale

- [ ] Add bounded parallel install planning without changing lockfile determinism.
  - Current state: dependency graph install is sequential and deterministic.
  - Target: optional planning phase can identify independent install batches while preserving deterministic lock output.
  - Acceptance: benchmark harness shows a measurable path for larger graphs and tests prove lock ordering remains stable.

- [ ] Add repeated static-index read caching for `info` and `search`.
  - Current state: each command invocation parses configured index files independently.
  - Target: command-local cache avoids duplicate loads across mirror fallback loops and metadata reads.
  - Acceptance: benchmark fixture records improved repeated lookup time with no stale read behavior inside a single command.

### P1 - Enterprise Operations

- [ ] Add registry audit export for local hosted workflows.
  - Current state: publish/yank/access/visibility update registry artifacts, but operator audit export is limited.
  - Target: deterministic JSON or Markdown report showing package versions, visibility, owners, teams, yanked versions, and metadata integrity warnings.
  - Acceptance: new verify script covers the report shape and README links the operator workflow.

- [ ] Add offline/cache restore guidance.
  - Current state: deterministic lockfiles and local artifacts are documented, but disaster recovery for cache and registry artifact loss can be clearer.
  - Target: maintainer runbook includes restore drills for `kennel.lock`, `kennel_packages/`, and local registry metadata.
  - Acceptance: docs command/path verification covers the new runbook entries.

### P2 - Presentation And Adoption

- [ ] Add a "Why Kennel shows Kujo well" README section.
  - Current state: README explains what Kennel does, but the language funnel from Kennel usefulness into Kujo adoption can be sharper.
  - Target: concise explanation of deterministic workflows, policy-as-code, and readable Kujo implementation as adoption signals.
  - Acceptance: section is product-facing without overstating deferred public-registry features.

- [ ] Add a guided example for static-index plus trust policy.
  - Current state: README includes snippets, and fixtures exist, but the best enterprise path spans multiple docs.
  - Target: one copyable walkthrough that initializes a project, configures an index, adds by name, enables trust policy, installs, and validates.
  - Acceptance: walkthrough commands are verified by a script or dry-run doc checker.

## Root Layout Decision

Do not remove root module shims yet. They are intentionally documented compatibility surfaces and are checked by `scripts/verify-kujo-native-direction.sh`. The implementation is already `src/` first; removal should wait for an explicit downstream-import migration plan.

## Recommended First Action Next Session

Start with P0 supply-chain provenance. It is the highest-leverage enterprise trust gap and pairs naturally with existing trust-policy, hosted registry, SBOM, and attestation work.
