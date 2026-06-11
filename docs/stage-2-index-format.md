# Stage 2 Index Format and Package Metadata Fields

This document is the human-readable reference for Stage 2 static index contracts.

Machine-readable contracts:

- `docs/contracts/index.schema.json`
- `docs/contracts/package-metadata.schema.json`

Fixtures:

- `docs/contracts/index.example.json`
- `docs/contracts/packages/ai-sdk.json`
- `docs/contracts/packages/mcp.json`

## Index Document (`index.json`)

Required top-level fields:

- schema_version: integer contract version for the index document.
- generated_at: timestamp string indicating when index content was generated.
- packages: array of package summary entries.

Package summary entry fields:

- name: package identifier used by future name-based commands.
- latest: latest recommended release identifier.
- metadata_path: relative path to package metadata document (`packages/<name>.json`).
- versions: quick lookup list of available versions.

Version summary fields in index entries:

- version: package release label.
- source: canonical source reference (for example, `github:owner/repo`).
- ref: tag/ref/selector associated with the release.
- checksum: optional integrity metadata.
- yanked: optional boolean availability status.

## Package Metadata Document (`packages/<name>.json`)

Required fields:

- name
- latest
- repository
- versions

Optional descriptive fields:

- description
- homepage

Version entry fields:

- version (required)
- source (required)
- ref (required)
- checksum (optional)
- published_at (optional)
- yanked (optional)
- deprecation (optional)

## Consistency Requirements

1. `index.json` package `name` must match the corresponding metadata `name`.
2. `index.json` package `latest` must match metadata `latest`.
3. `metadata_path` must resolve to an existing `packages/<name>.json` document.
4. Every metadata `versions` array must be non-empty and include required fields.

## Validation Commands

Run schema and fixture checks:

```bash
cd /path/to/kujolang/kennel
bash ./scripts/verify-stage-2-index-schema.sh
bash ./scripts/verify-stage-2-package-metadata-schema.sh
```

## Stage Scope Note

These contracts document Stage 2 data shape and do not imply Stage 2 CLI command implementation is complete.
