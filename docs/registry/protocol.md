# Kennel read protocol v1

The registry is an HTTPS authority. Current implementation: static Cloudflare Pages; future read APIs may serve the same files. Public reads are anonymous. No website scraping, Git clones, tokens, or GitHub requests occur during consumer installation.

## Identity and URLs

Unscoped lowercase `name` identifies an official Kujo package. `@scope/name` is the reserved future third-party form. Names/scopes are bounded safe ASCII identifiers; ownership is explicit (`scope`, `owner.type`, `owner.id`, `official`). Client aliases do not change release identity. Third-party registration/publishing is not implemented.

`/api/v1/index.json` contains `schema_version: 1`, registry origin and package summaries (`name`, description, latest stable, ownership, relative metadata_path). It has no full source/file inventory. Search loads it once and filters locally. Resolution goes directly to `/api/v1/packages/<identity>.json`, whose versions list points to `/api/v1/packages/<identity>/<version>.json`. The client selects the highest stable numeric SemVer; exact prereleases are explicit. Existing opt-in full three-part ranges use the shared SemVer solver. Latest is never stored as a lock source.

Exact version JSON and immutable `manifest.json` are identical. Required fields: schema_version, package (leaf name), version, scope, owner, official, description, license, released_at, source_commit, source_tag, archive_url, archive_sha256, archive_size, file_count, provenance_url, provenance_sha256, checksum_url, dependencies, minimum_kujo_version, repository, repository_id, release_id. Optional sbom_url may be added when an actual SBOM exists. Unknown additive fields are forward-compatible; changed field semantics require a new protocol major.

Artifacts use `/packages/<identity>/<version>/package.tar.gz`, `manifest.json`, `checksums.txt`, `provenance.json`. Version directories never mutate. Discovery/human pages may change. Future storage can move behind these domain paths; neither commands nor lockfiles need storage-provider URLs.

## Client guarantees

Kujo 1.3.1 native `http_request` bounds metadata at 1 MiB and archives at 8 MiB, times out at 30 seconds and rejects redirects (including HTTPS redirects). HTTP is not permitted. There is no silent downgrade or stale-index fallback. Explicit registry configuration replaces the default; local indexes retain their existing routing. ETag revalidation is not yet implemented. Digest-keyed immutable archive/provenance caching avoids repeat downloads; every cache read hashes bytes before reuse. A corrupt cache triggers a fresh bounded fetch and digest check.

USTAR extraction accepts regular files only, ASCII portable relative paths, 0644/0755 modes, valid header checksums and complete zero termination. Links, devices, extension headers, duplicate/case-colliding paths, path traversal and absolute paths fail. Expanded bytes are capped at 64 MiB and files at 10,000. All headers validate before staging writes. Validate the extracted manifest before the existing displacement/restore transaction replaces the package.

Lock schema remains 1. New `kind = "registry"` entries carry the exact version JSON source, resolved version/commit, checksum, registry, package_identity, registry_manifest and provenance_status. The embedded manifest freezes URL/digest/dependency identity for locked replay. No latest lookup occurs on reinstall. Existing path/Git entries remain readable. generated_at remains informational; package records/order are deterministic.

## Provenance trust

The trusted HTTPS registry authenticates a publishing statement. Its digest is locked and its package/version/archive/source/repository/release fields must agree with version metadata. It records exact commit/tag, immutable GitHub repository and Release IDs, workflow run URL, publisher ref/SHA and timestamp. This is consistency and integrity verification against a trusted registry, not independent cryptographic proof of a workflow. Existing hosted signature metadata checks remain separate and are not rebranded as cryptographic verification. Optional future attestation bundles and owner-authenticated publishing can strengthen this model without changing artifact identity.
