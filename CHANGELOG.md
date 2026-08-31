# Changelog

## [1.0.1] - 2026-08-30

- Hardened dependency identifiers, install paths, hosted-registry authorization, and invalid token-store handling.
- Made package replacement transactional and restored the previous installation when clone, checkout, revision, or copy operations fail.
- Added crash-safe atomic persistence for manifests, lockfiles, registry metadata, scaffolds, rollback restoration, and private mode-`0600` token stores.
- Corrected benchmark report serialization so generated artifacts are valid, schema-checked JSON.
- Added regression coverage for symlink containment, rollback, atomic persistence, token replacement, and installer cleanup.
- Declared Kujo 1.0.0 as the minimum supported runtime for the required atomic and private-file primitives.
- Repaired release CI by supplying the explicit stable Rust toolchain required by the pinned setup action.

## [1.0.0] - 2026-08-08

- Declared the documented local, source, static-index, and local hosted-registry workflows stable.
- Aligned Kujo and Kennel package metadata with the official 1.0 release.
- Preserved deterministic lockfile, source-policy, trust-policy, and hosted-registry validation gates.
