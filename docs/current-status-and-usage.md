# Kennel Current Status and Usage

## Launch-Safe Status

Kennel is Kujo’s official package and project manager.

The current launch-safe scope focuses on local and source-based package and project workflows:

- deterministic install and lock workflows
- local path and `file:` dependency sources
- owner-enforced permissions for local workflow state
- trust-policy enforcement on dependency consumption
- repeatable validation gates for local/source package management

Public package discovery, hosted registry features, package publishing, package directory browsing, accounts/auth, moderation, malware scanning, trust scoring, and package signing are intentionally deferred.

## Capability Matrix

| Capability Area | Status | Notes |
| --- | --- | --- |
| Core package management | Available | `init`, `new`, `add`, `install`, `update`, `remove`, `list`, `info`, `validate` |
| Deterministic locking | Available | `kennel.lock` generation and reinstall parity |
| Local/source workflows | Available | `file:` and local-path dependency sources |
| Static registry index workflows | Available | name-based add/search/info with configured local/static registry indexes |
| Hosted registry lifecycle | Available for local registry workflows | login, publish, yank, access, visibility, api-search, api-metadata, install-hosted |
| Access control enforcement | Available for local hosted workflows | owner checks for hosted mutation workflows |
| Trust policy enforcement | Available | checksum, signature, signing_key checks during add/install/update |
| Transitive resolution | Available | deterministic graph install with conflict diagnostics |
| Semver range resolution | Available (optional) | enable with `[policy.resolution].semver_ranges = true` |

## Recommended Usage Pattern

1. Use explicit refs, local paths, or `file:` sources for reproducibility.
2. Keep `kennel.lock` committed in source control.
3. Use least-privilege local workflows for validation and release prep.
4. Enable trust policy values in `kennel.toml` for sensitive environments.

## Current Constraints

- No generic non-GitHub git or SSH source support yet.
- Hosted downloads rely on metadata and trust-policy checks rather than binary provenance attestation.
- Public package discovery, hosted publishing infrastructure, moderation, malware scanning, and trust scoring remain outside the launch-safe scope.
- Semver range resolution is opt-in with `[policy.resolution].semver_ranges = true`.
- No dedicated `version` flag yet; use `help` for CLI discovery.

## Canonical Validation Commands

```bash
bash ./scripts/verify-contract-suites.sh
for script in ./scripts/verify-*.sh; do
	bash "$script"
done
```

## Validation Snapshot (2026-05-20)

Validated in-repo release and reliability gates:

- `scripts/verify-stage-1.sh` (core flow)
- `scripts/verify-deterministic-lockfile.sh` (deterministic lock behavior)
- `scripts/verify-pinned-refs.sh` (pinned-ref protections)
- `scripts/verify-stage-2-name-workflow-stability.sh` (reordered/repeated static-index operations)
- `scripts/verify-cli-messages.sh` (CLI diagnostics)
- `scripts/verify-kujo-native-direction.sh` (Kujo-native guardrails)
- `scripts/verify-stage-3-trust-signature-workflow.sh` (trust mismatch rejection)
- `scripts/verify-stage-3-server-permission-workflow.sh` (permission boundaries)
- `scripts/verify-stage-3-private-package-workflow.sh` and `scripts/verify-stage-3-hosted-api-workflow.sh` (hosted visibility and metadata query behavior)
- `scripts/verify-stale-lockfile.sh` and `scripts/verify-atomicity.sh` (write-churn and rollback/reliability checks)
- `scripts/verify-contract-suites.sh` (contract suites)

Recorded timing baseline from this run (seconds):

- verify-kujo-native-direction: 0
- verify-stage-3-trust-signature-workflow: 1
- verify-stage-3-server-permission-workflow: 3
- verify-stage-3-private-package-workflow: 2
- verify-stage-2-package-metadata-schema: 0
- verify-stage-3-hosted-api-workflow: 3
- verify-stale-lockfile: 1
- verify-deterministic-lockfile: 3
- verify-stage-2-name-workflow-stability: 4
- verify-atomicity: 3
- contract suite: 1
