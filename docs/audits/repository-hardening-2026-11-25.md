# Kennel ecosystem hardening

## Repository

- Repository `kujolang/kennel`, branch `main`
- Starting commit `8e128969f1bfa9914b9f6567b9efa56159d6ae13`
- Verified implementation `aa1a9758f86eb6a5ee2c735416bab33b84da1790`
- Kennel resolves and installs local, Git and official registry packages. It preserves manifest and lockfile contracts for direct and transitive dependencies and supplies the official registry's static generator. The [prior audit](repository-hardening.md) covers atomic persistence, source and installer boundaries, and the benchmark artifact contract.

## Findings

| ID | Priority | Area | Evidence and action | Status |
| --- | --- | --- | --- | --- |
| KNL-01 | P0 | Static metadata reads | The local metadata path checked a lexical prefix, then used an ordinary file read. Use the runtime's `read_file_beneath` from the configured index directory to enforce the boundary during the open. | Fixed |
| KNL-02 | P1 | Lockfile ordering | Each inserted package rebuilt the sorted prefix. Group packages by their case-folded name, use native key sort and preserve source order within ties. | Fixed |
| KNL-03 | P1 | Search fallback | Search aborted at the first unreadable index and never searched later configured mirrors. Continue through available indexes and return the first existing diagnostic if all cannot be read. | Fixed |
| KNL-04 | P2 | Installation failure | An installation rename failure returned from the inner catch before cleaning the verified archive staging directory. Clean the incomplete stage after rolling back the destination. | Fixed |
| KNL-05 | P2 | Registry onboarding | The landing page and onboarding independently labeled Kujo 1.8.2 as current. Point both routes to the runtime installation guide and retain the Kennel minimum. | Fixed in the generator |

## Compatibility and trust

Package ordering remains case-insensitive and stable for equivalent names. Manifests, lockfiles, output fields and version formats retain their existing schemas. Local metadata accepts normal relative paths and preserves the runtime's 8 MiB file limit. Symlink metadata paths now fail. The rooted reader is present at the declared Kujo 1.4.0 minimum. Search retains index order, first result per package name, and successful empty output for a readable index. Release downloads, pinned metadata, provenance and archive trust still use their existing fail-closed paths.

## Measurements

The [fixture](evidence/lockfile-sort-2026-11-25.kujo) runs in isolated import mode from each corresponding worktree using the existing Kujo 1.10.0 interpreter on Intel macOS. One warm-up preceded three alternating measured pairs. `performance_now()` brackets package ordering, with output digests checked outside the measured interval. Both revisions emitted matching digests. These are focused operation times, with whole install latency and memory outside the measurement.

| Packages | Baseline median ms | Candidate median ms |
| ---: | ---: | ---: |
| 80 | 230.07 | 24.38 |
| 320 | 3,407.18 | 81.84 |

[Raw paired samples](evidence/lockfile-sort-2026-11-25.jsonl).

## Audit coverage

| Phases | Evidence |
| --- | --- |
| 0–2 | Read the agent guide, native CLI entrypoint and adapter, manifest, lockfile, installer, resolver, verification scripts and recent audit. Traced fallback from command parsing through index and registry transport. |
| 3–4 | Measured ordering work and reviewed source replacement, bounded cache reads, cache integrity, temporary archive ownership and error cleanup. |
| 5–6, 15 | Checked JSON output, merged search order and bounded registry requests. Kennel does not register model tools or dispatch prompts, replay, or agent handoffs. |
| 7–9 | Reviewed local read boundaries, explicit registry authority, download policies, immutable archive digests and replacement recovery. No change to the global source and registry trust policy. |
| 10–11 | Preserved CLI names and normal outputs, version metadata, tracked compatibility re-exports and dependency requirements. Two fields support rooted reads in the successful path-resolution result. |
| 12–13 | Extended the core contract and mirror fixture. Existing comprehensive gates run them without a machine-dependent timing threshold. |
| 14–16 | Updated the changelog and registry guidance. Kept checkout compatibility shims, immutable historical artifacts and release evidence. Excluded generated `.kennel_tmp` and `kennel_packages` from source inspection. |
| 17–18 | See the verification receipt. |

## Verification

- `KUJO_BIN=/path/to/kujo bash scripts/verify-all.sh` passed on the original and final source using Kujo 1.10.0. This covered the core and hosted contracts, lockfile determinism, transitive and semver resolution, source policy, global tools, registry packaging, security regressions and the macOS smoke.
- `kujo test-run tests/contracts/cli-and-core-contract_tests.kujo` passed in the final gate. The new regressions exercise local path normalization, rooted link rejection and stable case-insensitive ties. `bash scripts/verify-multi-registry-fallback.sh` passed with a corrupt primary, a readable mirror with zero matches and all indexes invalid.
- `kujo run lockfile-sort-2026-11-25.kujo --interpreter --isolated-imports -- 320` passed in both worktrees with `KUJO_MODULE_PATH` pointed at the respective checkout. A direct rooted-read smoke passed under the available Kujo 1.5.0 interpreter.
- `kujo run scripts/registry/generate_registry.kujo --interpreter -- "$fixture"` generated the landing and onboarding pages with the canonical install guide. `bash scripts/verify-enterprise-docs.sh` and `git diff --check` passed. The full packaging gate covers verified archive handling. An injected OS-level final rename failure was outside this pass.

## Cross-repository follow-up

Promote the registry generator revision in `kujolang/kennel-registry` to update the live landing and getting-started pages.
