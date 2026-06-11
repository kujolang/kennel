# Architecture Flow Maps

This document adds contributor-facing system flow maps aligned with current `src/` module boundaries and verification entrypoints.

## 1) Command Routing Map

```mermaid
flowchart TD
	A[kennel.kujo] --> B[parse_cli and safety checks]
	B --> C{dispatch_command}
	C --> D[src/commands_dependency.kujo]
	C --> E[src/commands_hosted.kujo]
	D --> F[src/commands_shared.kujo]
	E --> F
	F --> G[src/dependency_spec.kujo]
	F --> H[src/resolver.kujo]
	F --> I[src/installer.kujo]
	F --> J[src/manifest.kujo]
	H --> K[src/utils.kujo]
	D --> L[src/validator.kujo]
```

Notes:

- Root-level module files (for example `commands_shared.kujo`) are compatibility shims that re-export from `src/`.
- Command-family boundaries are documented in `docs/architecture-command-boundaries.md`.

## 2) Hosted Registry Mutation Flow

```mermaid
flowchart TD
	A[CLI hosted command] --> B[src/commands_hosted.kujo]
	B --> C[resolve_registry_request_context]
	C --> D[auth_token_store get]
	B --> E[future_resolvers hosted APIs]
	E --> F{mutation intent}
	F --> G[publish]
	F --> H[yank]
	F --> I[access/visibility]
	G --> J[registry index + metadata write]
	H --> J
	I --> J
	J --> K[contract and stage-3 workflow verifiers]
```

Verification alignment:

- `scripts/verify-stage-3-publish-workflow.sh`
- `scripts/verify-stage-3-yank-workflow.sh`
- `scripts/verify-stage-3-ownership-workflow.sh`
- `scripts/verify-stage-3-server-permission-workflow.sh`
- `scripts/verify-stage-3-hosted-api-workflow.sh`

## 3) Lockfile Lifecycle Map

```mermaid
flowchart TD
	A[add/install/update/install-hosted] --> B[src/commands_shared.kujo]
	B --> C[resolve_manifest_dependency_graph]
	C --> D[resolve_dependency_with_policy]
	D --> E[install_resolved or install_locked_package]
	E --> F[lock_entry_from_install]
	F --> G[rebuild_lockfile_from_manifest]
	G --> H[save_lockfile]
	H --> I[kennel.lock]
	I --> J[deterministic reinstall + validation]
```

Verification alignment:

- `scripts/verify-deterministic-lockfile.sh`
- `scripts/verify-stale-lockfile.sh`
- `scripts/verify-pinned-refs.sh`
- `scripts/verify-transitive-resolution.sh`
- `scripts/verify-semver-range-resolution.sh`
- `scripts/verify-multi-registry-fallback.sh`

## Maintenance Rules

1. Keep diagrams in this file version-controlled with each routing or lifecycle change.
2. Update module references when command/shared/resolver boundaries shift.
3. Update verification alignment lists when adding or retiring gate scripts.
