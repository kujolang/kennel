# Stage 3 API Contract Versioning Strategy

This document defines the versioning strategy for the future hosted Kennel registry API.

## Objectives

1. Preserve stable client behavior across minor server updates.
2. Make breaking changes explicit, infrequent, and easy to migrate.
3. Keep CLI and API negotiation straightforward for Kujo-native tooling.

## Versioning Model

Kennel registry API versions use semantic major versions in the path:

- `/api/v1/...` for the first stable contract.
- `/api/v2/...` only for breaking changes.

Non-breaking changes are allowed within a major version:

- additive fields in responses
- additive optional query parameters
- additive endpoints

Breaking changes require a new major version:

- removing or renaming fields
- changing required field semantics
- changing authentication behavior incompatibly

## Contract Negotiation

Client requests include:

- explicit base path version (`/api/v1`)
- optional `Accept-Version` header for future compatibility hints

Server responses include:

- `X-Kennel-Api-Version` with concrete served contract version
- deprecation headers when endpoint behavior is scheduled to change

## Deprecation Policy

1. Deprecate endpoint/field behavior in `v1` with warnings first.
2. Maintain deprecated behavior for at least one minor release cycle.
3. Document migration guidance before removing behavior in a major version.

## Error Contract Stability

Error payload envelope should remain stable within a major version:

- `code`: machine-readable identifier
- `message`: human-readable guidance
- `details`: optional structured context

Error codes may be added, but existing codes should not be repurposed with different meanings.

## CLI Compatibility Rules

1. `kennel` should default to the latest supported stable API major version.
2. If server only supports newer major versions, CLI must return actionable upgrade guidance.
3. If server supports older major versions only, CLI should attempt compatible fallback if configured.

## Migration Guidance Requirements

Before shipping `v2`:

1. Publish migration notes mapping `v1` to `v2` endpoint/field changes.
2. Provide compatibility test fixtures for `v1` and `v2` responses.
3. Keep `v1` available for a defined transition window.
