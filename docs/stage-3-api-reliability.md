# Stage 3 Registry API Reliability and Failure Semantics

This document defines reliability expectations and failure semantics for the hosted Kennel registry API.

## Reliability Objectives

Service-level targets (initial baseline):

- Metadata read endpoints (`search`, package metadata): 99.9% monthly availability.
- Authenticated mutation endpoints (`publish`, `yank`, ownership changes): 99.5% monthly availability.

Latency targets (server-side processing, excluding client network):

- p95 metadata read responses under 300ms.
- p95 mutation responses under 800ms.

## Failure Semantics

### Read Endpoints

1. Prefer graceful degradation where feasible (for example, cached metadata responses with freshness markers).
2. Return deterministic error envelopes when data is unavailable or malformed.

### Mutation Endpoints

1. Mutation operations must be idempotent or expose idempotency-key support.
2. On partial internal failure, endpoint must return failure and avoid reporting a successful mutation state.
3. Clients should be able to safely retry transient failures.

## Error Envelope Contract

Error response shape:

- code: machine-readable failure class
- message: actionable user-facing text
- retryable: boolean hint for caller retry behavior
- request_id: correlation ID for support/investigation
- details: optional structured context

Required failure classes:

- auth_required
- auth_scope_denied
- rate_limited
- not_found
- validation_failed
- conflict
- upstream_unavailable
- internal_error

## Retry and Backoff Guidance

1. Retry only when `retryable` is true or status class indicates transient failure.
2. Use bounded exponential backoff with jitter.
3. Respect `Retry-After` when present.

## Consistency and Read-After-Write

1. Publish/yank responses should include enough version state to confirm resulting visibility.
2. Search/metadata endpoints should converge quickly after mutation; document expected propagation window.
3. During propagation windows, responses should include staleness indicators where possible.

## Operational Observability

Minimum operational telemetry:

- request rate/error rate by endpoint
- latency distributions (p50/p95/p99)
- retry volume and rate-limit counts
- publish/yank mutation success/failure counts

All logs and traces should include request correlation identifiers.

## Client Expectations

`kennel` CLI should:

1. Distinguish retryable vs non-retryable failures in diagnostics.
2. Surface request IDs for support troubleshooting.
3. Provide actionable remediation guidance for auth, scope, validation, and rate-limit failures.
