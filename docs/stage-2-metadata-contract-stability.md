# Stage 2 Metadata Contract Stability Baseline

This document finalizes the Stage 2 metadata contract baseline that Stage 3 planning depends on.

## Canonical Contract Files

- `docs/contracts/index.schema.json`
- `docs/contracts/package-metadata.schema.json`

These files are the source of truth for Stage 2 metadata structures.

## Stability Baseline (v1)

Stable required fields for `index.json` entries:

- schema_version
- generated_at
- packages[].name
- packages[].latest
- packages[].metadata_path
- packages[].versions[].version
- packages[].versions[].source
- packages[].versions[].ref

Stable required fields for `packages/<name>.json`:

- name
- latest
- repository
- versions[].version
- versions[].source
- versions[].ref

## Compatibility Rules

1. Additive optional fields are allowed in v1 contracts.
2. Removing or renaming required fields is a breaking change.
3. Breaking changes require a new contract major version and migration guidance.

## Contract Governance

1. Schema changes must include fixture updates.
2. Schema changes must pass validation scripts:
- `scripts/verify-stage-2-index-schema.sh`
- `scripts/verify-stage-2-package-metadata-schema.sh`
3. Changelog entries must call out any contract-level changes.

## Stage 3 Dependency

Stage 3 hosted registry API planning assumes these Stage 2 metadata contracts as the baseline for:

- API response shapes
- publish validation rules
- migration and backward compatibility guidance
