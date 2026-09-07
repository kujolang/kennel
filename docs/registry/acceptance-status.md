# Static registry implementation and acceptance status

As of 2026-09-07: implementation and real-release backfill are committed and pushed. **Production acceptance is blocked, not complete.** GitHub requires interactive verification before the existing Cloudflare app can receive access to the new registry repository.

## Architecture and client

The read side is versioned static JSON plus immutable USTAR/gzip artifacts. GitHub remains the development and Release authority. Separate public repository: https://github.com/kujolang/kennel-registry. Pages will serve its `registry/` directory directly, with no build, server, database, Worker or R2.

Kennel adds centralized official HTTPS default resolution, shared stable SemVer selection, exact versions and existing opt-in ranges, anonymous search/info/read/install, bounded downloads, digest/provenance consistency checks, verified digest cache, strict staged extraction and schema-1 lock replay. Existing local/source/custom-index and local hosted auth/trust commands remain. Runtime requirement: Kujo 1.3.1 for native bounded HTTP/byte/archive primitives. The old installed runtime is insufficient; verification used the local Kujo 1.3.1 release build.

Protocol, schema and package format details: [protocol](protocol.md), [JSON schemas](../contracts/registry-v1-version.schema.json), [publisher](publishing.md). Human pages and Markdown are generated from the same exact metadata. Local browser checks passed for homepage layout, filtering and package navigation. No production browser result is claimed.

## Releases and automation

Only Kennel and Changebucket are enabled. Actual GitHub Actions backfill [34081283600](https://github.com/kujolang/kennel-registry/actions/runs/34081283600) built and committed these real releases in registry commit `8c52c19`:

| Package | Version | Release ID | Compressed bytes | Files |
| --- | --- | --- | --- | --- |
| changebucket | 1.0.0 | 367136441 | 21,265 | 17 |
| kennel | 1.0.0 | 367138335 | 126,287 | 165 |
| kennel | 1.0.1 | 379486187 | 135,012 | 168 |

No release was created for testing. Changebucket's historical ChangeBudget identity is documented in the exact-commit policy and provenance. No missing license or SBOM was fabricated.

Release-published callers build through the central workflow. Registry-owned scheduled reconciliation uses the same builder and its own GITHUB_TOKEN to commit atomically; deploy keys are disabled by GitHub policy and none were provisioned. No personal token is used. Callers are pinned to reviewed workflow commit `3b9c419`; package tooling is pinned to `25319f2`. Workflow provenance records the executing workflow ref/SHA. Scheduled publication is nominally every 15 minutes, subject to GitHub scheduling delays.

The backfill run's final deployment verification failed because the domain is not configured; its successful registry commit does not imply successful production deployment.

## Cloudflare and production acceptance

Existing account/kujolang.ai zone were inspected. At inspection, no Kennel Pages project and no conflicting kennel DNS record existed. The Pages Git setup is open with the kujolang account selected. Its existing app currently exposes only the commerce repository. GitHub API access cannot modify this installation (403); browser administration is gated by GitHub's Confirm access verification. The user was asked to complete verification; no credential was requested or handled.

After verification: grant the existing Cloudflare app access to `kujolang/kennel-registry`, select it in Pages, configure `main`, no build command, output `registry`, then add `kennel.kujolang.ai`. Verify DNS/TLS, deployment, human pages, exact JSON and archives. Run `KUJO_BIN=/path/to/kujo-1.3.1 python3 scripts/registry/production_e2e.py`, then dispatch registry verification again. This acceptance script performs default, exact, cached and clean installs for both official packages in isolated projects/cache and records elapsed install times.

## Security and provenance

[Threat model](threat-model.md) records trust boundaries, review corrections and mitigations. SHA-256 verification fails closed, including cache reads; extraction rejects traversal, links, unsafe modes, malformed headers and oversized contents. Ownership/repository IDs and released tag commits are explicit. Provenance is an integrity-checked statement from the trusted registry, **not independent cryptographic proof**. Optional signed attestations remain future work.

## Verification

Commands use `PATH=/Users/robertdevore/2026/Kujolang/kujo-repos/kujo/target/release:/Library/Frameworks/Python.framework/Versions/3.10/bin:$PATH`.

- Baseline core: passed. Baseline full: interrupted by host process exhaustion; not claimed passing.
- `bash scripts/verify-all.sh core`: exit 0, passed (`/tmp/kennel-core-final.log`).
- `bash scripts/verify-profiles.sh full`: exit 0, passed (`/tmp/kennel-full-final.log`). Includes split contracts: 29/29 core, 7/7 registry index, 18/18 hosted.
- New registry tests in full: 5/5 Kujo and 9/9 Python passed. Deterministic packaging, immutability, archive rejection, provenance tampering, locked replay and cache corruption covered.
- `bash scripts/verify-profiles.sh security`: exit 0, passed (`/tmp/kennel-security-final.log`).
- Final `bash scripts/verify-registry-packages.sh`: 5/5 Kujo, 9/9 Python, exit 0 (`/tmp/kennel-registry-final.log`).
- `kujo test-run -v tests/kennel_contract_tests.kujo`: exit 0, 34/34 passed (`/tmp/kennel-monolithic-verbose.log`). An earlier nonverbose attempt reported 25/34; unchanged verbose rerun passed. Host process exhaustion also affected earlier runs, so the failed attempt is retained rather than erased.
- ShipCheck gate: exit 0; 16/16 checks, zero errors/warnings (`/tmp/kennel-shipcheck-gate.json`).
- JSON Schema validation: all six real index/package/version documents plus three provenance statements passed.
- Native anonymous HTTPS read of committed registry JSON through GitHub raw hosting: passed. This is a transport test, not production Kennel domain acceptance.
- Real Changebucket artifact cached installation and locked replay: passed offline, with exact release bytes. Not a production download.

## Performance and remaining work

Global index: 909 bytes. Changebucket package discovery: 619 bytes; Kennel: 857 bytes. Package sizes are above. Resolution reads per-package metadata instead of the whole index. Archive/provenance caching is digest-addressed. Production latency, uncached/cached installation timing and lock generation timing remain unmeasured until deployment. ETag metadata caching is not implemented; transport caps and artifact caching are implemented.

Concrete remaining acceptance work: Cloudflare app verification/access, Pages Git connection/custom domain, DNS/TLS checks, production installs and timings. Wider enrollment is intentionally deferred pending those results; see [inventory review](enrollment-review.md). Accounts, scoped authenticated publishing and private packages are not implemented. Explicit scope/owner schemas and stable read/artifact URLs allow a future API/object-storage write path without changing CLI or lock identities.
