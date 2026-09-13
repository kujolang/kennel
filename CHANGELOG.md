# Changelog

## [1.1.0] - 2026-09-13

- Official HTTPS package distribution, verified immutable archives, provenance consistency checks and content-addressed cache.
- Per-user installer and `kennel` launcher, runtime checks, repeatable PATH setup and `kennel self update`.
- `kennel tool install/update/list/remove`: isolated global packages, explicit `[bin]` commands, legacy `[kujo].entry` fallback, atomic activation and command collision protection.
- Registry website onboarding, Tabler copy controls, mobile navigation and official Kujo typography.

- Kujo-native bootstrap, global command management and deterministic release publishing; no consumer Python dependency.
- Requires published Kujo 1.4.0 or newer.
- Bounded retries recover transient GitHub API read failures while authorization, schema and integrity failures remain fatal.

### Registry foundation

- Native HTTPS registry resolution, verified release archives, safe staging extraction and content-addressed caching.
- Additive schema-1 lock metadata for exact archives and release provenance.
- Central deterministic release builder, reusable GitHub Release publication, static Pages registry and historical-release backfill.
- Installation requires Kujo 1.4.0; existing local/source and hosted command contracts are preserved.

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
