# Ecosystem production acceptance — 2026-09-08

**36 packages and 38 actual released versions are live at https://kennel.kujolang.ai.** The [enrollment inventory](https://github.com/kujolang/kennel-registry/blob/main/ENROLLMENT.md) accounts for all 41 entries on the Kujo primitives and tooling pages, including five explicit coverage boundaries. No private source or invented release was published.

## Verified results

- `KUJO_BIN=/Users/robertdevore/2026/Kujolang/kujo-repos/kujo/target/release/kujo bash scripts/verify-profiles.sh full`: success, including the nested core/security and complete verification suites.
- Registry tests: 5 Kujo tests and 12 Python tests passed, including deterministic manifest projection and the USTAR record-boundary regression.
- `python3 scripts/registry/acceptance_all.py`: 36/36 production packages passed fresh installation and lock/cache replay with Git disabled (72 successful install operations). [Per-package results and timings](enrollment-install-results.json).
- `python3 scripts/registry/verify_deployment.py ../kennel-registry/registry`: production index and all immutable archive digests verified.
- JSON Schema validation: 113 live index, package, version and provenance documents passed.
- Browser: homepage lists 36 packages; search filters SiteKit correctly. Discovery index is 14,078 bytes.

Acceptance uses the updated Kennel client on main and Kujo 1.3.1. Historical Kennel release archives remain immutable and do not acquire new client behavior automatically. Source dependencies are projected only when their exact commit matches a reviewed real release; MCP installs its pinned Ability 1.0.1 entirely through Kennel.

## Publication and boundaries

[GitHub Actions run 34258829008](https://github.com/kujolang/kennel-registry/actions/runs/34258829008) generated and atomically published the real release backfill, then verified production artifacts. The existing registry-owned scheduled workflow handles enrolled repositories; future unsupported manifests fail closed pending review. Provenance provides trusted-registry identity and consistency checks, not an independent cryptographic signature.

Dispatch remains pending approval to bundle its exact unreleased AI SDK dependency; replacing it with a different released commit is not acceptable. Leash and Ward are private. Kujo uses its runtime installer, and Paperclip uses npm/plugin installation. Do not advertise all 41 catalog entries as Kennel-installable.
