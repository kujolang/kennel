# Kennel Maintainer Runbook

This runbook is the operational checklist for release checks, emergency rollback, and incident response.

## Release Preconditions

- Work from a clean branch with no uncommitted changes.
- Confirm current checklist status in docs/KENNEL_AGENT_EXECUTION_CHECKLIST.md.
- Export the intended Kujo binary for deterministic local runs:

```bash
export KUJO_BIN=/path/to/kujo/target/debug/kujo
```

## Validation Policy By Change Type

Minimum required profile coverage:

- security changes: `security` + `core`
- architecture/refactor changes: `stage2` + `core`
- feature changes (hosted/API/user-facing): `stage3` + `core`
- docs-only changes: `core` (dry-run allowed for local docs edits)
- release-candidate cut: `full`

Command form:

```bash
bash ./scripts/verify-profiles.sh <core|stage2|stage3|security|full>
```

## Release Flow

1. Sync and verify branch state.
2. Execute profile requirements based on change family.
3. Run contract suite.
4. Tag and publish only after all required checks pass.

```bash
git status --short
bash ./scripts/verify-profiles.sh core
bash ./scripts/verify-contract-suites.sh
```

Release-candidate gate:

```bash
bash ./scripts/verify-profiles.sh full
```

Optional local cleanup after heavy validation runs:

```bash
bash ./scripts/cleanup-local-artifacts.sh
```

## Emergency Rollback

Use when a release introduces a production regression.

1. Stop further release activity.
2. Identify last known good commit or tag.
3. Revert the bad change set in a new commit.
4. Re-run minimum `security` + `core` profiles.
5. Communicate rollback scope and customer impact.

Non-destructive rollback preparation commands:

```bash
git log --oneline -n 20
git show --stat <candidate-rollback-commit>
```

## Incident Response

Use for auth leakage, trust failures, hosted-registry corruption, or install integrity incidents.

1. Triage severity and affected command path.
2. Capture evidence (failing command, output, and relevant registry/project files).
3. Reproduce in isolated temp project.
4. Contain impact:
   - rotate compromised registry tokens
   - suspend publish/yank/access mutations if registry integrity is uncertain
5. Patch, validate with required profiles, and document postmortem actions.

Suggested first-response checks:

```bash
bash ./scripts/verify-profiles.sh security
bash ./scripts/verify-atomicity.sh
```

## Dry-Run Mode

For planning and CI wiring checks, use dry-run routing output without executing suites:

```bash
RUNNER_DRY_RUN=1 bash ./scripts/verify-profiles.sh core
RUNNER_DRY_RUN=1 bash ./scripts/verify-profiles.sh security
RUNNER_DRY_RUN=1 bash ./scripts/verify-profiles.sh full
```
