# Change-Type Validation Policy

This policy defines minimum validation requirements for every change family.

## Required Profiles

- security changes: `security` + `core`
- architecture/refactor changes: `stage2` + `core`
- feature changes (hosted/API/user-facing): `stage3` + `core`
- docs-only changes: `core`
- release-candidate cut: `full`

Profile entrypoint:

```bash
bash ./scripts/verify-profiles.sh <core|stage2|stage3|security|full>
```

## Enforcement

- Policy is documented here and in docs/maintainer-runbook.md.
- CI enforces policy presence via scripts/verify-change-type-policy.sh.
- Policy verification is executed in .github/workflows/stage1-verification.yml.

## Notes

- Minimum profiles may be extended by maintainers when risk increases.
- Security-affecting changes should also run trust and atomicity verification scripts.
