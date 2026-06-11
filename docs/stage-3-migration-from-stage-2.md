# Stage 3 Migration Path From Stage 2 Static Index

This document defines the planned migration path from Stage 2 static index metadata to Stage 3 hosted registry APIs.

## Migration Goals

1. Preserve install reproducibility for existing Stage 2 users.
2. Avoid breaking existing lockfile-based workflows.
3. Allow gradual cutover from static JSON hosting to hosted API endpoints.

## Baseline Assumptions

Stage 2 baseline artifacts:

- `index.json`
- `packages/<name>.json`
- contract files in `docs/contracts/`

Stage 3 baseline capabilities (planned):

- authenticated API endpoints
- publish/yank/ownership workflows
- server-side policy enforcement

## Migration Phases

### Phase 1: Dual-Read Metadata Compatibility

- Keep Stage 2 static index artifacts published.
- Introduce Stage 3 API read endpoints that mirror equivalent metadata fields.
- Validate parity between static index and API metadata responses.

### Phase 2: CLI Read-Path Preference Shift

- Add configuration to prefer Stage 3 API metadata reads.
- Keep fallback to Stage 2 static index during transition.
- Emit clear diagnostics indicating data source used.

### Phase 3: Mutation Workflows on Stage 3

- Route publish/yank/ownership flows exclusively through Stage 3 APIs.
- Continue static index generation from Stage 3 as a compatibility surface while needed.

### Phase 4: Static Index Sunset

- Announce deprecation timeline for static index hosting.
- Maintain read-only static artifacts for a defined sunset window.
- Remove static-index dependency from default CLI behavior after migration window ends.

## Lockfile Compatibility Rules

1. Existing `kennel.lock` entries remain source-of-truth for locked installs.
2. Migration must not rewrite lockfiles unless explicitly requested.
3. Stage 3 metadata reads should resolve to equivalent source/ref data for compatibility.

## Operational Safeguards

1. Provide migration health checks comparing static and API metadata parity.
2. Monitor migration error rates and fallback frequency.
3. Maintain rollback path to static-index-first reads during incidents.

## User Communication Requirements

1. Publish migration notices with clear timelines.
2. Document required CLI version updates.
3. Provide explicit fallback instructions for affected users.
