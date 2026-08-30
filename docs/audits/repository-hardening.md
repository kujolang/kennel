# Repository Hardening Audit

## Repository

- Repository: `kennel`
- Branch: `main`
- Starting SHA: `012c0a251dafc4984899fe320c0407cdb492fc05`
- Ending implementation SHA: `71324478d8957c3bd5a543e1871b3b8079a5e48f`
- Purpose: deterministic Kujo package/project management for local, source, static-index, and local hosted-registry workflows
- Important integrations: Kujo runtime/interpreter, Git, Bash verification scripts, Python 3 benchmark validation, GitHub Actions, static registry JSON artifacts

The implementation SHA identifies the audited code state before this report-only commit. The final repository SHA is recorded in the engineering receipt produced with this audit.

The source sweep excluded generated/bulk `.kennel_tmp/**` and `kennel_packages/**` except when measuring installer artifacts. Contract fixtures under `tests/**` and `docs/contracts/**` were inspected as contract surfaces rather than copy style.

## Baseline

At the starting SHA:

- `bash scripts/verify-all.sh core`: passed.
- `bash scripts/benchmark-harness.sh`: exited successfully but emitted invalid JSON. `python3 -m json.tool .kennel_tmp/benchmarks/baseline-results.json` failed at line 19 because operation records contained literal `\t` escapes outside JSON strings.
- Baseline benchmark averages (three measured iterations, one warmup): install 1,295 ms; update 1,538 ms; API search 916 ms; API metadata 887 ms.
- Repeated source-matrix installs retained 28 MiB in one `.kennel_installer_trash` directory. Additional verification fixtures retained smaller copies.
- The initial working tree contained an untracked, valid root `kennel.lock`; it was preserved and added as a reproducible build input.

The full script inventory, split contract suites, CI workflows, manifests, root compatibility shims, installer/resolver/lockfile paths, hosted auth/trust boundaries, static index handling, and release/benchmark tooling were inspected. There are no third-party runtime package dependencies declared in `kennel.toml` or `kujo.toml`.

## Findings

| ID | Priority | Area | Finding | Evidence | Action | Status |
| -- | -------- | ---- | ------- | -------- | ------ | ------ |
| KH-001 | P0 | Correctness / state | A vanished or unreadable local source could make the shell `tar` pipeline report success because only the final pipeline process determined status, leaving an empty installed package. | A regression test reproduced a successful empty replacement for a missing source. | Replaced the pipeline fallback with a status-preserving `cp -R` command chain and added failed-replacement rollback coverage. | Fixed |
| KH-002 | P1 | Resource efficiency | Every reinstall displaced the previous package into `.kennel_installer_trash` without deleting it. | The baseline source-matrix fixture retained 28 MiB; several other fixtures retained additional directories. | Added explicit displacement finalization, empty-trash-root cleanup, and restoration on clone/copy/checkout failure. | Fixed |
| KH-003 | P1 | Security / filesystem | Lexical install-path checks allowed `kennel_packages` itself to be a symlink, permitting writes outside the project tree. | The boundary check only searched for `/kennel_packages/`. | Reject symlinked package roots with Kujo's native `path_is_symlink`; added an escape regression test. | Fixed |
| KH-004 | P1 | Benchmark / agent output | The benchmark claimed machine-readable JSON but emitted invalid JSON; its CI check used substring matching and could not detect the defect. | Python JSON parsing failed while the existing verifier passed. | Emit real indentation and parse/assert schema-critical fields in CI. | Fixed |
| KH-005 | P2 | Documentation | README deferred local hosted workflows that the same README and implementation mark available; the hardening backlog cited already-replaced code paths. | Capability, deferred-roadmap, and backlog sections contradicted current source. | Aligned operated-service boundaries and refreshed backlog evidence/completed safeguards. | Fixed |
| KH-006 | P1 | Crash consistency | Manifest, lockfile, and token-store writes directly overwrote targets; command-level rollback did not protect against process or machine termination mid-write. | `save_manifest`, `save_lockfile`, and token-store persistence called `write_file` on final paths. | Adopt Kujo's synced same-directory atomic writer for normal state and a verified private-temp-plus-rename flow for token stores; add behavioral tests and a source ratchet. | Fixed |
| KH-007 | Needs more evidence | Performance / scale | Install and full-lock rebuild paths remain sequential and metadata is reparsed across separate CLI invocations. | The existing benchmark has no representative large dependency graph and separate CLI processes cannot share a command-local cache. | Close as unproven optimization work; require a representative workload before reopening. | Closed — no action |

## Changes Implemented

### Follow-up: crash-safe persistence

- Manifest, lockfile, registry metadata, rollback restoration, and generated scaffold writes now use `write_file_atomic`, which writes, flushes, syncs, and atomically renames a same-directory temporary file.
- Hosted token stores now write content to a verified mode-`0600` private temporary path and atomically rename it over the destination, preserving restrictive permissions during replacement.
- Installer displacement/restoration and recursive destructive cleanup now use native Kujo filesystem operations. Git operations and compatibility-preserving recursive directory copy remain guarded external commands.
- `scripts/verify-atomic-persistence.sh` prevents direct `write_file` calls from returning to persistent state modules and checks the private/atomic primitives remain wired.
- Contract coverage verifies repeated complete manifest/lock replacement, token replacement content, final permissions, and temporary-file cleanup.

### Transactional package replacement

- Problem/root cause: old installations were moved aside but never finalized or restored; the copy pipeline also masked first-stage failures.
- Implementation: package replacement now has explicit displace, restore, finalize, and guarded-delete stages. Failed clone, checkout, revision lookup, or copy restores the prior package. Successful replacement deletes displaced content and removes the empty trash root. Local fallback copying uses an `&&`-chained recursive copy so source failure propagates.
- Files: `src/installer.kujo`, `tests/contracts/cli-and-core-contract_tests.kujo`.
- Tests: successful replacement, trash cleanup, failed replacement rollback, and symlinked package-root rejection.
- Compatibility: command names, normal output, lockfile format, and install layout are unchanged. Failed replacement is stricter: a source disappearance now correctly fails instead of accepting an empty package.

### Valid benchmark artifact contract

- Problem/root cause: operation strings used backslash escapes that were printed literally, while the verifier checked only substrings.
- Implementation: interpret controlled indentation escapes when assembling the report and parse the generated file with Python's JSON parser; assert schema version, dry-run marker, threshold, operation set, and numeric result types.
- Files: `scripts/benchmark-harness.sh`, `scripts/verify-benchmark-harness.sh`, `docs/performance-benchmarking.md`.
- Compatibility: field names and schema version remain `1.0`; consumers now receive the valid JSON the documented contract promised.

### Documentation and reproducibility

- Corrected the public/local-hosted versus operated-public-service boundary.
- Updated hardening backlog evidence to current modules and remaining crash-safety work.
- Tracked the existing root `kennel.lock`; it contains no packages and changes no dependency surface.

## Performance & Efficiency

| Measurement | Before | After | Interpretation |
| --- | ---: | ---: | --- |
| Source-matrix retained installer trash | 28 MiB in one observed trash root | 0 directories / 0 bytes | Directly attributable; successful replacements now finalize displaced content. |
| Benchmark JSON parse | Failed | Passed | Machine-readable output contract restored. |
| Install average | 1,295 ms | 585 ms | No regression; raw run only. Host load differed, so no causal speedup claim is made. |
| Update average | 1,538 ms | 665 ms | No regression; raw run only. Host load differed, so no causal speedup claim is made. |
| API search average | 916 ms | 349 ms | No code-path optimization; difference demonstrates host/run variance. |
| API metadata average | 887 ms | 342 ms | No code-path optimization; difference demonstrates host/run variance. |

Both benchmark runs used three iterations, one warmup, UTC, C locale, the same fixture set, and the same Kujo binary name. Runtime results remained under the documented 15% regression threshold, but only the resource-retention and JSON-validity changes are claimed as measured improvements.

The persistence follow-up used adjacent five-iteration runs against a detached `6f9f81f` worktree and the updated tree on the same host: install 1,048 → 1,167 ms (+11.4%), update 1,195 → 1,087 ms (-9.0%), API search 715 → 656 ms (-8.3%), and API metadata 756 → 699 ms (-7.5%). Every operation remained inside the 15% review threshold; the result supports absence of a material regression rather than a speedup claim.

No token/context optimization was justified: Kennel does not invoke models or expose MCP/tool schemas, and its agent guidance is already scoped with progressive file/search instructions. No dependency-size measurement applies because the manifests declare no runtime or development packages.

## Security

Reviewed boundaries included CLI flags/identifiers, local and Git dependency sources, install paths, shell quoting, package-root containment, symlinks, static index metadata paths, hosted registry mutation/read authorization, token-store parsing and permissions, trust metadata shape, mutable-ref policy, and Git subprocess diagnostics.

Fixed the symlinked package-root escape and crash-consistency gap, with deterministic regression coverage and a source-level persistence ratchet. Existing traversal, identifier, static metadata-path, auth fail-closed, signature/checksum shape, and mutable-ref controls remain enabled.

## Compatibility

- Public APIs: unchanged.
- CLI commands, normal output, and exit behavior: unchanged except the corrected missing-source failure.
- Lockfile and manifest formats: unchanged.
- Registry JSON schemas: unchanged.
- Benchmark schema: unchanged at `1.0`; serialization corrected to valid JSON.
- Configuration and environment variables: unchanged.
- Minimum runtime declaration: raised from Kujo 0.1.0 to 1.0.0 because the atomic and private-file primitives used here are stable in Kujo 1.0.0.
- External consumers: no migration required. Consumers that had worked around malformed benchmark output should remove that workaround.

## Cross-Repository Follow-Ups

- None. The audited Kujo 1.0 standard-library surface already provides the atomic, private-file, permission, rename, and deletion primitives needed to close KH-006 inside Kennel.

## Remaining Work

- **P0:** none demonstrated in the audited scope.
- **P1:** none with sufficient evidence for safe implementation in this pass.
- **P2:** no unresolved issue; remaining Git and recursive-copy commands are compatibility-preserving external integrations without a native equivalent contract.
- **P3:** no cosmetic churn recommended.
- **Needs more evidence:** bounded parallel install, cross-invocation metadata caching, and large-graph performance budgets are hypotheses rather than validated issues.
- **Not worth changing:** compatibility shims, explicit failure-triage output in verification fixtures, and split contract suites remain intentional contract surfaces.

## Verification Receipt

Baseline and targeted commands:

| Command | Exit | Classification |
| --- | ---: | --- |
| `bash scripts/verify-all.sh core` | 0 | Blocking baseline; passed. |
| `bash scripts/benchmark-harness.sh` | 0 | Measurement; artifact was invalid JSON before the fix. |
| `python3 -m json.tool .kennel_tmp/benchmarks/baseline-results.json` | 1 | Diagnostic baseline; exposed KH-004. |
| `kujo test-run -v tests/contracts/cli-and-core-contract_tests.kujo` | 0 | Blocking targeted regression suite; 29/29 passed after changes. |
| `kujo test-run -v tests/contracts/hosted-registry-contract_tests.kujo` | 0 | Blocking targeted registry suite; 18/18 passed after changes. |
| `kujo test-run tests/kennel_contract_tests.kujo` | 0 | Blocking aggregate contract suite; 34/34 passed after changes. |
| `bash scripts/verify-contract-suites.sh` | 0 | Blocking; all split contracts passed. |
| `bash scripts/verify-security-regression-suite.sh` | 0 | Blocking security gate; passed. |
| `bash scripts/verify-atomicity.sh` | 0 | Blocking state gate; passed. |
| `bash scripts/verify-stage-1-source-matrix.sh` | 0 | Blocking integration gate; passed with zero retained trash directories. |
| `bash scripts/verify-benchmark-harness.sh` | 0 | Blocking artifact contract; valid JSON parsed and checked. |
| `bash scripts/benchmark-harness.sh` | 0 | Post-change measurement; valid output at `.kennel_tmp/benchmarks/post-results.json`. |
| `bash scripts/verify-shell-quality.sh` | 0 | Blocking syntax gate; Bash syntax passed; local ShellCheck unavailable and was explicitly skipped by the repository script. |
| `bash scripts/verify-atomic-persistence.sh` | 0 | Blocking persistence ratchet; atomic/private primitives are wired and direct persistent `write_file` calls are absent. |
| `bash scripts/verify-profiles.sh stage3` | 0 | Blocking hosted-registry profile; passed. |
| `bash scripts/verify-all.sh all` | 0 | Blocking full repository verification; passed. |
| Adjacent five-iteration benchmark, `6f9f81f` vs updated tree | 0 / 0 | Performance comparison; all operations remained within the 15% review threshold. |

Push, clean-tree, and exact final-SHA results are recorded in the final engineering receipt because they occur after this report is committed.
