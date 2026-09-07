# Static first-party registry: audit and implementation contract

Audit base: `b5e0cf290aa2af7a90b637a7c3bdb4324ea4f66d`, 2026-09-06.
Scope excludes `.kennel_tmp/` and `kennel_packages/` except test results.

## Existing implementation

The entrypoint delegates to `src/commands_dependency.kujo` and hosted commands through root compatibility shims. Preserve those shims and legacy CLI messages. `src/dependency_spec.kujo` supports file/path and GitHub sources, pinned selectors and optional ranges. `src/resolver.kujo` resolves Git refs and numeric stable SemVer ranges; reuse its stable comparator and range policy. `src/commands_shared.kujo` routes local static indexes and builds transitive dependency graphs. Existing indexes point to source repositories, not release archives. Remote index URLs are currently skipped. `src/installer.kujo` displaces and restores installations transactionally; preserve this primitive. Lock schema 1 is extensible and sorts packages by name; timestamps are informational.

`src/future_resolvers.kujo` implements local hosted metadata publication, ownership, visibility and APIs. `src/hosted_auth.kujo` stores restrictive local credentials; none of it is a public service or required for anonymous package reads. `src/hosted_trust.kujo` validates metadata shape/equality against configured trust values; this is not cryptographic signature verification. Do not label those string comparisons as signed artifact verification. Existing SBOM workflow attests an SBOM on tag push; retain it and add actual release-archive publishing separately.

Manifest packaging controls already exist: `[kujo].sources`, `includes`, `excludes`. Use these controls instead of introducing `[package].include`. Root manifest currently has no dependencies. Existing security/readiness/backlog documents cover local hosted behavior and explicitly defer public operation; retain their historical scope and document the new static read implementation separately.

## Architecture and acceptance spec

* Client remains Kujo-native: HTTPS transport, bounded gzip/USTAR extraction, graph installation, trust-policy checks, additive lock metadata and content-addressed cache.
* A separate `kujolang/kennel-registry` repository holds generated `registry/` static files. Cloudflare Pages Git integration publishes that directory with no server, database or object storage.
* Release packaging is a central Python standard-library build tool operating on Git objects at an exact release commit; no working-tree files or package hooks execute. Normalize gzip mtime, USTAR timestamps, uid/gid, modes, names and order. Reject links/submodules, unsafe names and collisions. Python is publisher-only, not a client dependency.
* Machine API is `/api/v1/index.json`, `/api/v1/packages/<identity>.json`, `/api/v1/packages/<identity>/<version>.json`. Identities are `name` or `@scope/name`; unscoped names require official organization ownership. Third-party publishing remains unavailable.
* Immutable blobs live at `/packages/<identity>/<version>/{package.tar.gz,manifest.json,checksums.txt,provenance.json}`. The index is discovery only; per-package metadata carries versions. Future APIs/storage may serve the same URLs.
* Default registry is centralized and used only when no explicit registry or local index exists. Explicit registry configuration never silently falls back to the official registry.
* Release manifests bind identity, ownership, digest, size, source commit/tag and provenance digest. Provenance is an authenticated-registry statement checked for consistency, not an independent cryptographic proof of a workflow. Workflow attestations can add independent evidence without changing this contract.
* Add locks exact version, archive URL/digest, source commit and provenance reference/digest. Reinstall verifies cache bytes and provenance before staging extraction and replacement. No mutable latest lock references.
* New releases are built from real GitHub Release events; backfill uses existing release IDs via the same builder. Repository allowlist includes immutable repository IDs. Identical release retries are idempotent; altered version content fails. One Git commit publishes blobs and indexes atomically.

## Required verification

Baseline core passed with `KUJO_BIN=/Users/robertdevore/.local/bin/kujo bash scripts/verify-all.sh core`. An initial invocation lacked Kujo on PATH; a first network-backed retry failed transiently and the rerun passed. Full baseline runs before source changes. Preserve core, full, security and contract gates. Add hostile archive, malformed metadata, immutable publication, digest/cache, version/channel, HTTPS and production install coverage. Do not claim completion before anonymous production installs succeed.

Full baseline reached Stage 3 but terminated with host process exhaustion (`fork: Resource temporarily unavailable`, exit 128). This is an environmental baseline failure, not a passing full-suite receipt. New transport uses released Kujo 1.3.1 (published 2026-09-06), whose HTTP response bound is 8 MiB. The archive cap follows that concrete limit.

GitHub rejected deploy-key creation because deploy keys are disabled for the repository; no keys/secrets were created. Release events use a read-only central package-building workflow. The registry owns the write credential and reconciles actual published Release records every 15 minutes, using the same builder. This keeps cross-repository credentials unnecessary while adding scheduling latency. One registry concurrency group serializes all writes.
