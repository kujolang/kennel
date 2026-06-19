# Kennel

Kennel is the official package and project manager for [Kujo](https://github.com/kujolang/kujo/). The current launch-safe scope focuses on deterministic local, source-based, static-index, and local hosted-registry package/project workflows.

Public package discovery, an operated hosted registry service, package directory browsing, hosted moderation, malware scanning, and public trust scoring are intentionally deferred until the security, trust, and moderation model is mature.

## Why Teams Use Kennel

- Deterministic installs and lockfiles for stable release pipelines
- Local and source-based package/project workflows that run reproducibly in the Kujo interpreter
- Trust-policy enforcement for checksum, signature, and signing key fields
- Scripted verification profiles for fast baseline checks and deeper stage/security gates

## Verified Behaviors

Current verified behaviors in this repository:

- `--flag=value` parsing preserves complete values, including token-like values containing additional `=` characters
- Lockfile output is deterministic and order-stable
- Direct and transitive dependencies are installed and locked deterministically
- Unsafe dependency install paths are rejected before local copy or git clone work starts
- Pinned refs are protected during update operations
- Token-store handling uses safer defaults and restrictive file permissions

These behaviors are validated through contract suites and verify scripts in `scripts/`.

## Supported Environments

Validated in current project automation:

- CI: Ubuntu (`ubuntu-latest`) via GitHub Actions
- Local development: macOS and Linux shells with Kujo installed

Toolchain assumptions:

- Kujo binary available as `kujo` or overridden with `KUJO_BIN`
- Bash available for verification scripts

> Note: the current CLI surface includes `help`; a dedicated `version` flag is not implemented yet.

## Security Posture Summary

- Use `--token-file` when possible to avoid shell-history token exposure
- Keep token stores outside repositories when practical
- Prefer least-privilege local and source-based workflows for reproducibility
- Prefer explicit refs and commit pins for reproducibility
- Configure trust policy values in `kennel.toml` for sensitive environments

Detailed security behavior and command mappings are in `docs/stage-3-security-model.md`.

## Capability Overview

| Capability Area | Status | Notes |
| --- | --- | --- |
| Core dependency lifecycle | Available | `init`, `new`, `add`, `install`, `update`, `remove`, `list`, `info`, `validate` |
| Deterministic lockfiles | Available | `kennel.lock` generation and reinstall parity |
| Local/source package workflows | Available | `file:` and local-path dependency installation |
| Trust policy checks | Available | `checksum`, `signature`, `signing_key` validations for local/source workflows |
| Full transitive solver | Available | Deterministic graph install with conflict diagnostics for incompatible transitive specs |
| Semver range solver | Available (optional) | Enable with `[policy.resolution].semver_ranges = true` for deterministic tag-based range selection |
| Local hosted registry lifecycle | Available | Auth, publish, access, visibility, search/metadata APIs, and hosted install against local registry artifacts |
| Multi-registry static index routing | Available | Configure `[registry].index` + `[registry].mirrors` for deterministic name-resolution fallback in `add`, `info`, and `search` |
| Operated public registry service | Deferred | Public discovery, hosted moderation, malware scanning, trust scoring, and registry operations at internet scale |

## Production Readiness Boundary

Kennel is production-oriented for its current launch-safe scope: deterministic lockfiles, explicit source handling, local/static registry workflows, local hosted-registry artifacts, trust-policy checks, source-policy gates, and broad scripted validation.

It should not yet be presented as a universal enterprise package ecosystem. The remaining enterprise-exemplar work is mostly around scale and operated-service readiness: bounded parallel install performance, stronger provenance around release artifacts and hosted downloads, migration/offline cache ergonomics, richer registry audit/export tooling, and clearer adoption funnels for new Kujo users. See `docs/KENNEL_ENTERPRISE_READINESS_REVIEW_2026_06_19.md` for the current review and next-session backlog.

## Quick Start

```bash
cd /path/to/kujolang/kennel
kujo run kennel.kujo --interpreter -- help

kujo run kennel.kujo --interpreter -- init --name kennel-demo
kujo run kennel.kujo --interpreter -- add file:../some-local-package --alias some-local-package
kujo run kennel.kujo --interpreter -- install
kujo run kennel.kujo --interpreter -- validate
```

## Trust Policy Configuration

```toml
[trust]
checksum = "sha256:..."
signature = "sig-..."
signing_key = "key-..."
```

When declared, trust policy is enforced during add/install/update workflows.

## Source Policy Configuration

```toml
[policy.source]
strict_mutable_refs = true
allow_mutable_refs = false
```

When strict mode is enabled, mutable refs (for example, branch refs or implicit HEAD) are blocked for non-path dependencies during add/install/update. Operators can explicitly override once per command with `--allow-mutable-ref`.

## Resolution Policy Configuration

```toml
[policy.resolution]
semver_ranges = true
```

When semver range mode is enabled, range selectors (for example `^2.1.0`, `~1.4.2`, or `>=1.2.0 <2.0.0`) are resolved against repository tags deterministically by selecting the highest compatible semver tag.

## Static Index Routing Configuration

```toml
[registry]
index = "./registry/index.primary.json"
mirrors = ["./registry/index.secondary.json", "./registry/index.tertiary.json"]
```

Name-based package operations (`add <name>`, `info <name>`, and `search <query>`) evaluate static indexes in configured order (`index` first, then `mirrors`) and stop on the first successful match. Missing files and unsupported remote URLs are skipped with diagnostics so failover remains deterministic.

## Deferred Roadmap

The following areas are intentionally out of launch-safe scope for now:

- public package discovery
- hosted registry workflows
- package publishing
- package directory browsing
- accounts/auth for hosted mutation flows
- moderation and malware scanning
- trust scoring
- package signing

## Validation and Release Gates

Primary validation entrypoints:

- `scripts/verify-all.sh`
- `scripts/verify-profiles.sh`
- `scripts/verify-shell-quality.sh`
- `scripts/verify-macos-smoke.sh`
- `scripts/verify-contract-suites.sh`
- `scripts/verify-security-regression-suite.sh`
- `scripts/verify-command-failure-matrix.sh`
- `scripts/verify-nightly-full-regression-workflow.sh`
- `scripts/cleanup-local-artifacts.sh`
- `scripts/benchmark-harness.sh`

CI release-confidence coverage:

- Pull request and push gates run stage and security profiles.
- Static script quality gates enforce ShellCheck diagnostics in CI.
- A nightly scheduled workflow runs `verify-profiles.sh full` and publishes artifacts for triage.
- Nightly CI exports `nightly-ci-quality-report` with pass/fail trend, duration, and warning summaries.

Script input convention:

- `KUJO_BIN` is the shared Kujo binary override for verify scripts
- Verify scripts default `KUJO_BIN` to `kujo` if not provided
- If `kujo` is not on PATH locally, run with `KUJO_BIN=/path/to/kujo bash ./scripts/verify-all.sh core`

Run core baseline gate:

```bash
bash ./scripts/verify-all.sh core
```

Run profile-based gates:

```bash
bash ./scripts/verify-profiles.sh core
bash ./scripts/verify-profiles.sh stage2
bash ./scripts/verify-profiles.sh stage3
bash ./scripts/verify-profiles.sh security
bash ./scripts/verify-profiles.sh full
```

Run split contract suites:

```bash
bash ./scripts/verify-contract-suites.sh
```

Run deterministic benchmark harness:

```bash
bash ./scripts/benchmark-harness.sh
BENCH_DRY_RUN=1 bash ./scripts/benchmark-harness.sh
```

Clean local validation artifacts:

```bash
bash ./scripts/cleanup-local-artifacts.sh
```

## Enterprise Rollout Path

Suggested adoption order:

1. Start with `core` profile in pull requests.
2. Add `stage2` or `stage3` gates based on change surface.
3. Require `security` profile for security-sensitive and release-candidate changes.
4. Run `full` profile before release tagging.

## Repository Layout

Top-level runtime artifacts:

- `kennel.toml`: manifest
- `kennel.lock`: deterministic dependency snapshot
- `kennel_packages/`: installed source trees
- `AGENTS.md`: agent and contributor guidance for canonical examples, fixture boundaries, and search hygiene

Implementation layout:

- Core implementation modules live under `src/`
- Root-level module files are intentional compatibility shims re-exporting `src` modules; keep them until downstream imports no longer rely on root module names
- Shared utility logic is implemented in `src/utils.kujo`; root `utils.kujo` is a compatibility shim
- Entrypoint remains `kennel.kujo`
- Shim consistency is enforced by `scripts/verify-kujo-native-direction.sh`
