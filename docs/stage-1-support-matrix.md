# Stage 1 Support Matrix and Exit Criteria

This document defines the final Stage 1 support matrix and the required Stage 1 exit criteria for Kennel.

## Stage 1 Support Matrix

| Area | Capability | Stage 1 Status | Notes |
| --- | --- | --- | --- |
| CLI | `kennel init` | Supported | Initializes `kennel.toml` with Stage 1 defaults. |
| CLI | `kennel add <source>` | Supported | Accepts GitHub shorthand, GitHub HTTPS, and local path sources. |
| CLI | `kennel install` | Supported | Uses `kennel.lock` when present, otherwise resolves from manifest. |
| CLI | `kennel update [name]` | Supported | Updates floating refs; skips pinned `commit`, `tag`, and `version`. |
| CLI | `kennel remove <name>` | Supported | Removes dependency from manifest, install tree, and lockfile. |
| CLI | `kennel list` | Supported | Lists installed lockfile entries. |
| CLI | `kennel info <name-or-source>` | Supported | Supports installed-package lookup and direct source inspection. |
| CLI | `kennel validate` | Supported | Validates manifest shape and dependency declarations. |
| Sources | `github:owner/repo@ref` | Supported | Ref is resolved to a commit and written to lockfile. |
| Sources | `github:owner/repo` | Supported | Defaults to `HEAD` for selector resolution. |
| Sources | `https://github.com/owner/repo.git#ref` | Supported | Supported for GitHub-hosted HTTPS repositories. |
| Sources | `file:../local-package` and `../local-package` | Supported | Intended for local multi-repo Kujo development. |
| Sources | Non-GitHub git remotes (SSH or arbitrary hosts) | Not supported | Stage 1 parser accepts GitHub shorthand and GitHub HTTPS only. |
| Locking | Deterministic `kennel.lock` | Supported | Lockfile package ordering is deterministic by package name. |
| Install layout | `kennel_packages/<name>/` | Supported | Install target for resolved dependencies. |
| Solver | Semver ranges | Not supported | Deferred to future stages. |
| Solver | Full transitive graph/conflict resolution | Not supported | Stage 1 handles direct dependencies only. |
| Registry | Name-based install (`kennel add ai-sdk`) | Not supported | Planned for Stage 2 index workflows. |
| Publish/Auth | Login, publish, yank, ownership | Not supported | Planned for Stage 3 hosted registry workflows. |
| Security | Checksum/signature enforcement | Not supported | Placeholder fields exist, enforcement is deferred. |

## Stage 1 Exit Criteria

Stage 1 is complete only when every criterion below is verified and green:

1. End-to-end command flow succeeds: `init`, `add`, `install`, `update`, `remove`, `list`, `info`, `validate`.
2. Deterministic lockfile generation and reinstall behavior are verified.
3. Integration coverage verifies local path and GitHub source installs.
4. Pinned refs (`commit`, `tag`, `version`) are not unexpectedly updated.
5. User-facing errors are specific and actionable.
6. CI executes Stage 1 verification and fails on regressions.
7. Documentation accurately reflects supported and unsupported behavior.

## Verification Sources

- `docs/full-delivery-checklist.md`
- `docs/testing-and-delivery-roadmap.md`
- `scripts/verify-stage-1.sh`
- `scripts/verify-stage-1-source-matrix.sh`
- `scripts/verify-contract-suites.sh`