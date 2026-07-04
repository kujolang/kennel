# CI Quality Dashboard Export

Kennel publishes a periodic CI quality report artifact from the nightly full regression workflow.

Workflow source:

- `.github/workflows/nightly-full-regression.yml`

Report generator:

- `scripts/generate-ci-quality-report.sh`

Artifact name:

- `nightly-ci-quality-report`

Artifact file:

- `.kennel_tmp/nightly/ci-quality-report.json`

## Report Contents

The exported JSON report includes:

- current run conclusion (`success`/`failure`)
- current run duration in seconds
- warning counts (`KUJORUN001` or type-warning marker lines)
- verify success/failure marker counts
- trend summary from recent workflow runs (pass/fail counts and duration stats)
- privacy metadata confirming no raw logs or secret tokens are included

## Example Local Invocation

```bash
mkdir -p .kennel_tmp/nightly
bash ./scripts/verify-profiles.sh full 2>&1 | tee .kennel_tmp/nightly/nightly-full-profile.log
RUN_DURATION_SECONDS=600 \
RUN_CONCLUSION=success \
bash ./scripts/generate-ci-quality-report.sh
```

## Contract Validation

Use the workflow contract verifier to ensure report generation/export remains configured:

```bash
bash ./scripts/verify-ci-quality-report-workflow.sh
```

## Operational Notes

1. Report generation is lightweight and relies on summary counts from the nightly profile log.
2. Trend data uses the GitHub Actions API when `GITHUB_TOKEN` and `GITHUB_REPOSITORY` are present.
3. If API access is unavailable, the report still emits current-run metrics with trend source set to `none` or `unavailable`.
