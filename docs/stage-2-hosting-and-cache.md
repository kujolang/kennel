# Stage 2 Hosting and Cache Behavior

This document defines recommended hosting and cache behavior for Stage 2 static index resolution.

## Hosted Artifacts

Stage 2 static registry artifacts:

- `index.json`
- `packages/<name>.json` metadata documents

Recommended hosting requirements:

1. Serve artifacts over HTTPS only.
2. Support immutable historical metadata URLs when practical.
3. Provide consistent content types (`application/json`).

## Cache Policy

Suggested cache controls:

- `index.json`: short TTL (for example 60-300 seconds) for freshness.
- `packages/<name>.json`: moderate TTL (for example 300-1800 seconds).
- version-specific metadata can be cached longer when immutable.

HTTP behavior guidance:

1. Provide `ETag` and/or `Last-Modified` headers.
2. Support conditional requests (`If-None-Match`, `If-Modified-Since`).
3. Return `304 Not Modified` when content is unchanged.

## Client Cache Strategy

Expected Stage 2 client behavior:

1. Read cached index metadata when fresh.
2. Revalidate with conditional requests when stale.
3. Fallback to cached data during transient network failures with clear warnings.
4. Invalidate cached package metadata when index version markers change.

## Determinism and Cache Safety

1. Resolved install artifacts should remain lockfile-driven for reproducibility.
2. Cache freshness affects discovery of new versions, not reproducibility of locked installs.
3. Index cache misses should not mutate existing lockfile-backed installs unexpectedly.

## Failure Semantics

When index host is unavailable:

- `kennel add <name>` should fail with actionable diagnostics if no cached index is available.
- If a valid cache exists, CLI may proceed with warning that cached metadata was used.

When package metadata is malformed:

- fail resolution for the specific package
- return actionable field-level error context

## Operational Guidance

1. Publish index updates atomically (or via versioned snapshots) to avoid partial-read windows.
2. Roll back by restoring prior known-good index and metadata snapshot.
3. Monitor fetch latency/error rates and cache hit ratio for hosted artifacts.

## Stage Scope Note

This document defines hosting/cache behavior for Stage 2 design and does not imply `kennel add/search/info` by name are fully implemented yet.
