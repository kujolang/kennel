# Static registry threat model

Scope: released source → GitHub Actions → generated registry Git commit → Pages HTTPS → Kennel cache/staging/lock. Reviewed 2026-09-07. Production deployment remains subject to the acceptance record; this document does not certify a live service.

## Assets and trust boundaries

Protect package identity, exact release contents, existing installations, local filesystem integrity, immutable version history, and reproducible locks. Publisher policy and the official HTTPS registry are trusted authorities. Package bytes, archive headers, remote JSON, local cache bytes, and release source are parsed as untrusted input. GitHub organization administrators, approved workflow changes, DNS and Cloudflare administrators can affect the trusted registry.

## Threats and implemented controls

| Threat | Control and evidence |
| --- | --- |
| Unauthorized publication, rename/transfer, squatting | Explicit enabled package policy binds official unscoped name to public kujolang repository and immutable repository ID. Actual published Release API record and exact tag commit required. `scripts/registry/sync_releases.kujo`, `build_package.kujo`. |
| Working tree leakage/secrets | Read committed Git blobs only; explicit sources/include/exclude controls and mandatory secret/cache/build exclusions. Reject symlinks/submodules. No archive of the working directory. Arbitrary secrets deliberately committed inside allowed source cannot be identified perfectly. |
| Version overwrite/partial publication | Existing version with different archive or release identity rejected. Retry preserves first provenance. Generate and validate everything before one registry commit; index written after version files. Git/Pages deployment is the publication unit. |
| Dependency confusion/namespace ambiguity | Reserved official unscoped ownership, explicit scoped parser and registry override. No automatic search across arbitrary registries. Lock exact registry/version/artifact identity. |
| Network downgrade/oversize | HTTPS only, credential-free authority, no redirects, 30-second timeout, 1 MiB metadata and 8 MiB compressed artifact caps. `src/registry_transport.kujo`. |
| Metadata tampering/fake provenance | Strict identity/owner/type/schema/URL/digest consistency; provenance hash and source/release/workflow fields verified. HTTPS registry is the trust root. A fully compromised registry can fabricate a consistent statement; independent signed attestations are not implemented. |
| Cache corruption/race | Content-addressed cache; read bytes once and hash that same buffer before reuse. Reject symlink cache directories. Same-user malicious filesystem mutation is outside the isolation guarantee. |
| Archive traversal/symlink escape/bombs | Regular-file-only USTAR, portable relative names, no links/devices/extensions, case-collision detection, fixed permissions, header checksums, complete termination, 64 MiB expansion/10k file limits. `src/registry_archive.kujo`. |
| Malformed manifest/failed install | Require exact lowercase kennel.toml and strict TOML package identity/version/dependencies. Random UUID staging, cleanup only staging owned by this attempt, validate before existing displacement/restore transaction. `src/installer.kujo`. |
| Mutable resolution/lock drift | Highest stable shared SemVer selection; exact version metadata and digests retained in schema-1 lock. Embedded manifest encoded as JSON to preserve nulls through TOML round trips. |

## Review and validation

Independent architecture review identified authority parsing, permissive manifest fallback, staging collision/cleanup, cache reread, Release pagination, and prerelease numeric ordering weaknesses. These were corrected before final verification. `tests/registry_protocol_tests.kujo` and `tests/test_registry_packages.py` exercise identity/URL validation, deterministic builds, immutable rejection, hostile archives, digest cache replay/corruption, metadata/provenance tampering, and stable/prerelease precedence. Existing local/Git and hosted trust regression suites remain separate compatibility gates.

The read protocol contains ownership and scopes but supplies no accounts, private publishing, user authentication, moderation, or public namespace registration. Future authenticated writes must enforce those authorities without changing these read and lock contracts.
