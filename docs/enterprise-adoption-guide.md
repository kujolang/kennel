# Enterprise Adoption Guide

This guide targets platform teams, security leads, and large-team maintainers adopting Kennel across multiple services.

## Audience And Outcomes

Primary audiences:

- platform engineering teams owning CI/CD standards
- security engineering teams defining dependency and registry policies
- repository maintainers onboarding multiple development squads

Expected outcomes:

- consistent policy baselines for source, trust, and resolution behavior
- repeatable rollout playbooks that minimize migration risk
- incident drills with concrete command runbooks

## Rollout Patterns

### Pattern A: Pilot Then Expand

Use this pattern for orgs introducing Kennel to mixed legacy repos.

1. Select 1-3 pilot repositories and enable `core` verification profile in pull requests.
2. Require committed `kennel.lock` updates for dependency changes.
3. Enable source/trust policy defaults in pilot manifests.
4. Expand to additional repositories in waves after two clean release cycles.

Commands:

```bash
bash ./scripts/verify-profiles.sh core
bash ./scripts/verify-contract-suites.sh
```

### Pattern B: Policy-First Enforcement

Use this pattern for security-sensitive orgs requiring guardrails before broad rollout.

1. Introduce org policy templates (below) via reusable manifest snippets.
2. Enforce `security` plus `core` profiles for dependency-related changes.
3. Gate production release branches on `full` profile.

Commands:

```bash
bash ./scripts/verify-profiles.sh security
bash ./scripts/verify-profiles.sh full
```

### Pattern C: Registry Transition Wave

Use this pattern when moving from single static index to primary plus mirrors.

1. Set `[registry].index` to the current primary source.
2. Add mirror indexes under `[registry].mirrors` in deterministic priority order.
3. Verify fallback behavior before switching default ownership.

Commands:

```bash
bash ./scripts/verify-multi-registry-fallback.sh
kujo run kennel.kujo --interpreter -- search example-package
kujo run kennel.kujo --interpreter -- info example-package
```

## Organization Policy Templates

### Baseline Manifest Policy Template

```toml
[policy.source]
strict_mutable_refs = true
allow_mutable_refs = false

[policy.resolution]
semver_ranges = true

[trust]
checksum = ""
signature = ""
signing_key = ""
```

### Multi-Registry Template

```toml
[registry]
index = "./registry/index.primary.json"
mirrors = [
	"./registry/index.secondary.json",
	"./registry/index.tertiary.json"
]
```

### CI Policy Template

```yaml
name: kennel-policy-gates
on:
  pull_request:
  push:
    branches: [main]

jobs:
  kennel-core:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
      - run: bash ./scripts/verify-profiles.sh core

  kennel-security:
    if: contains(github.event.pull_request.title, '[security]')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
      - run: bash ./scripts/verify-profiles.sh security
```

## Migration Playbooks

### Playbook 1: Legacy Repo To Kennel Lock Discipline

1. Initialize manifest and baseline metadata.
2. Add dependencies with explicit refs or semver ranges (when policy-enabled).
3. Commit `kennel.toml` and `kennel.lock` together.
4. Enforce pull-request checks with `core` profile.

Commands:

```bash
kujo run kennel.kujo --interpreter -- init --name my-service
kujo run kennel.kujo --interpreter -- add github:kujolang/ai-sdk@main
kujo run kennel.kujo --interpreter -- install
bash ./scripts/verify-profiles.sh core
```

### Playbook 2: Stage 2 Static Index To Hosted Plus Mirrors

1. Keep Stage 2 index in `[registry].index` as current source of truth.
2. Add hosted-generated mirror indexes in `[registry].mirrors`.
3. Validate deterministic lookup/fallback behavior.
4. Enable hosted mutations once search/info parity is confirmed.

Commands:

```bash
bash ./scripts/verify-multi-registry-fallback.sh
bash ./scripts/verify-stage-3-hosted-api-workflow.sh
bash ./scripts/verify-stage-3-private-package-workflow.sh
```

### Playbook 3: Monorepo Progressive Enforcement

1. Start with docs-only dry-run policy checks.
2. Enable `core` profile for all dependency-touching pull requests.
3. Require `stage3` profile for hosted-registry integration changes.
4. Require `full` profile for release-candidate tags.

Commands:

```bash
RUNNER_DRY_RUN=1 bash ./scripts/verify-profiles.sh core
bash ./scripts/verify-profiles.sh stage3
bash ./scripts/verify-profiles.sh full
```

## Incident Response Drills

### Drill A: Compromised Registry Token

Objective: rotate credentials, block mutation access, and prove recovery path.

1. Revoke token and generate replacement credentials.
2. Validate login and publish flow with least-privilege actor.
3. Record timeline and remediation notes in incident log.

Commands:

```bash
bash ./scripts/verify-stage-3-login-workflow.sh
bash ./scripts/verify-stage-3-server-permission-workflow.sh
bash ./scripts/verify-stage-3-publish-workflow.sh
```

### Drill B: Trust Metadata Mismatch

Objective: ensure malformed checksum/signature inputs fail closed.

1. Run trust-signature verification workflow.
2. Confirm command failures are explicit and actionable.
3. Validate no lockfile drift during failed installs.

Commands:

```bash
bash ./scripts/verify-stage-3-trust-signature-workflow.sh
bash ./scripts/verify-deterministic-lockfile.sh
```

### Drill C: Registry Outage And Fallback

Objective: confirm fallback ordering across primary/mirror static indexes.

1. Simulate unavailable primary index.
2. Validate successful fallback to mirror metadata.
3. Confirm search/info output declares effective source index.

Commands:

```bash
bash ./scripts/verify-multi-registry-fallback.sh
kujo run kennel.kujo --interpreter -- search mirror
kujo run kennel.kujo --interpreter -- info mirror-demo
```

## Adoption Checklist

- publish org-standard `kennel.toml` policy templates
- enforce profile routing via `docs/change-type-validation-policy.md`
- verify docs command/path validity with `scripts/verify-enterprise-docs.sh`
- standardize release gating with `bash ./scripts/verify-profiles.sh full`
