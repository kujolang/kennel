# Kennel Performance Benchmark Harness

This document defines the deterministic benchmark harness for install/update/search/metadata command paths.

## Scope

The harness targets four operations:

- `install`
- `update`
- `api-search`
- `api-metadata`

## Determinism Controls

The harness applies fixed controls on each run:

- Fixed fixture inputs from `examples/basic-project`
- Fixed hosted registry user (`alice`) and token fixture
- Controlled environment variables (`TZ=UTC`, `LC_ALL=C`, `LANG=C`)
- Explicit benchmark iteration and warmup settings
- Isolated run directory under `.kennel_tmp/benchmarks`

## Run Locally

```bash
bash ./scripts/benchmark-harness.sh
```

Custom settings:

```bash
BENCH_ITERATIONS=5 BENCH_WARMUP=1 BENCH_OUTPUT=.kennel_tmp/benchmarks/local-results.json bash ./scripts/benchmark-harness.sh
```

Dry-run mode (used in CI contract checks):

```bash
BENCH_DRY_RUN=1 bash ./scripts/benchmark-harness.sh
```

## Output Format

The harness writes machine-readable JSON including:

- schema and generation metadata
- commit SHA and benchmark settings
- threshold guidance
- per-operation durations (`durations_ms`, `avg_ms`, `min_ms`, `max_ms`)

Default output path:

- `.kennel_tmp/benchmarks/results.json`

## Regression Threshold Policy

Use `avg_ms` for comparison against a prior baseline JSON from the same operation set.

- Default review threshold: `15%` max regression per operation.
- If regression exceeds `15%`, require explicit reviewer rationale before merge.
- If fixture shape or benchmark parameters changed, regenerate and document a new baseline.

## CI Integration

Stage 1 CI runs the benchmark harness in dry-run mode through:

- `scripts/verify-benchmark-harness.sh`

This keeps CI deterministic and low-cost while parsing the generated JSON and validating
its schema-critical fields, operation set, and numeric result types.
