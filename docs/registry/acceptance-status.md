# Static registry production acceptance

2026-09-08: **the static registry is live at https://kennel.kujolang.ai and real package installation passes.** Consumers provide package names, not GitHub source URLs. Acceptance used the updated Kennel client on main and Kujo 1.3.1. Historical Kennel releases retain their original behavior; no test release or replacement artifact was created.

## Architecture and Kennel changes

GitHub remains the development and Release authority. The separate public [kennel-registry repository](https://github.com/kujolang/kennel-registry) contains generated static distribution files. Cloudflare Pages serves `registry/` directly, with no build command, application server, database, Worker or R2.

Kennel provides a centralized official HTTPS default, anonymous search/info/resolution/install, shared stable SemVer selection and existing opt-in ranges, exact-version URLs, bounded downloads, digest/provenance consistency checks, a verified content-addressed cache, strict archive staging, and deterministic schema-1 lock replay. Existing local/source/custom-index and local hosted auth/trust commands remain.

## Protocol, site and package format

[Protocol](protocol.md) and [JSON schemas](../contracts/registry-v1-version.schema.json) define discovery at `/api/v1/index.json`, per-package metadata at `/api/v1/packages/<name>.json`, and exact release metadata at `/api/v1/packages/<name>/<version>.json`. Immutable artifacts live at `/packages/<name>/<version>/`: package.tar.gz, manifest.json, checksums.txt and provenance.json. Human package/version pages and Markdown are generated from those records; the CLI never scrapes HTML.

The builder reads exact tracked Git blobs at the released tag commit, applies explicit source/include/exclude controls and mandatory exclusions, sorts paths, and normalizes USTAR uid/gid/timestamps/permissions and gzip metadata. [Publishing details](publishing.md). No expanded source-tree deployment, proprietary format or fabricated SBOM.

## Release automation and backfill

Small `release.published` callers use the central builder. Registry-owned scheduled reconciliation independently consumes actual Release API records, verifies approved repository names and immutable IDs, builds through the same path, and writes one atomic commit using its own GITHUB_TOKEN. GitHub disables deploy keys; none were created and no personal token is used. Publishing is nominally every 15 minutes, subject to scheduling delays.

[Run 34250625389](https://github.com/kujolang/kennel-registry/actions/runs/34250625389) passed the complete reconciliation and production archive-verification workflow. Callers pin central workflow `161d5e5`; publisher tooling is pinned to `aa0e552`. New client archive performance fixes do not change published package bytes.

Only these real releases are enrolled/backfilled:

| Package | Version | GitHub Release ID | Compressed bytes | Files |
| --- | --- | --- | --- | --- |
| changebucket | 1.0.0 | 367136441 | 21,265 | 17 |
| kennel | 1.0.0 | 367138335 | 126,287 | 165 |
| kennel | 1.0.1 | 379486187 | 135,012 | 168 |

Original backfill commit: `kennel-registry@8c52c19`. Changebucket v1.0.0 still used the ChangeBudget name; its commit-specific policy generates only a distribution manifest and records the adaptation in provenance. Released code is unchanged and its missing license is not invented. [Wider enrollment review](enrollment-review.md) identifies candidates; no additional repositories were automatically enrolled.

## Cloudflare

Pages project `kennel-registry` (ID `618df53e-08cf-41d2-9424-ba213e19eb21`) is Git-connected to `kujolang/kennel-registry`, production branch `main`, no build command, output `registry`. Settings are recorded in that repository's `cloudflare-pages.json`.

`kennel.kujolang.ai` is an active proxied CNAME to `kennel-registry.pages.dev`. Cloudflare reports domain verification and certificate validation active. HTTPS requests verify normally without disabling certificate checks. Initial deployment `49484b03-a103-43a3-9177-95351c6707fb` succeeded. A subsequent Git push at registry commit `674a92b` automatically deployed successfully as `57893195-711c-4fee-a7c3-e8741908a3cb`. Production homepage, Changebucket package/version pages and a 390px mobile layout were checked in-browser. Live JSON and every archive digest pass the deployment verifier.

## Security and provenance

[Threat model](threat-model.md) records trust boundaries and mitigations. SHA-256 failures stop installation, including corrupted cache reads. USTAR accepts bounded regular files, safe portable paths and normalized permissions; links, traversal, duplicate/case-colliding paths, malformed headers and excessive padding fail. Headers validate before staging and existing installation displacement. A production performance defect in repeated archive-byte indexing was fixed by reading one 512-byte header at a time; hostile-archive fixtures still pass.

Provenance binds package/version, archive hash, exact source commit/tag, repository/Release IDs and publishing workflow identity through a trusted HTTPS registry statement. It is **not independent cryptographic workflow proof**. Signed archive attestations remain an additive future capability. Explicit ownership and scoped identity schemas allow future accounts/authenticated publishing to replace the write implementation without changing consumer URLs or lock semantics.

## Tests and production E2E

Commands use Kujo 1.3.1, `/Users/robertdevore/2026/Kujolang/kujo-repos/kujo/target/release/kujo`.

- Baseline core passed. Baseline full was interrupted by host process exhaustion; not claimed passing.
- The first post-production full-profile rerun stopped on a Git process spawn with `Resource temporarily unavailable (os error 35)`; the unchanged full-profile retry passed with exit 0 (`/tmp/kennel-full-production-retry.log`).
- Existing implementation verification: core and full profiles passed; security profile passed; split contracts 29/29 core, 7/7 registry index, 18/18 hosted; aggregate contracts 34/34. Earlier failed attempts are retained in the temporary logs described in Git history.
- `bash scripts/verify-registry-packages.sh` after the extraction performance fix: 5/5 Kujo tests and 9/9 Python tests, exit 0. Includes deterministic packaging, immutable rejection, archive attacks/padding, provenance tampering, cache corruption and locked replay.
- ShipCheck gate: 16/16, no errors/warnings. JSON Schema validation: six index/package/version documents and three provenance statements passed.
- `python3 scripts/registry/verify_deployment.py ../kennel-registry/registry`: exit 0, production index and every immutable archive digest verified.
- `KUJO_BIN=/path/to/kujo-1.3.1 python3 scripts/registry/production_e2e.py`: exit 0. Default, exact, cached and clean installs pass for **changebucket 1.0.0 and kennel 1.0.1**, with checksum/provenance verification, extraction and locked replay. No consumer GitHub source URL.
- Live CLI `search changebucket` and `info changebucket`: exit 0, official registry results. The portable `bin/kennel` launcher also passed literal `kennel init` and `kennel add changebucket` production checks; `sh -n bin/kennel` passed.

Measured end-to-end wall-clock seconds, one production sample per operation:

| Package | Default uncached | Exact | Cached lock replay | Clean cache/project |
| --- | --- | --- | --- | --- |
| changebucket | 2.435 | 1.639 | 0.501 | 2.169 |
| kennel | 3.810 | 3.694 | 1.923 | 8.106 |

Global index: 909 bytes; package discovery: 619 bytes Changebucket / 857 bytes Kennel. Native Changebucket resolution measured 1.320485s; lock writing 22.933ms for 1,778 bytes. Rewriting the same resolved lock produced identical bytes. Timings are local samples, not latency guarantees. Logs: `/tmp/kennel-production-e2e-final.log`, `/tmp/kennel-deployment-final.log`, `/tmp/kennel-protocol-benchmark.log`, `/tmp/kennel-registry-final-20260908.log`.

## Remaining limitations

The new client is on main; existing immutable Kennel releases predate remote support and require an updated client plus Kujo 1.3.1. Normal release management can distribute that client later. ETag metadata caching and independent signed archive attestations are not implemented. Accounts, third-party publishing, private packages and moderation are intentionally absent. Wider enrollment requires release/package review. No production deployment or installation blocker remains.
