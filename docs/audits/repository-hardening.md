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
| KH-006 | Needs more evidence | Crash consistency | Manifest, lockfile, and token-store writes directly overwrite targets; command-level rollback does not protect against process or machine termination mid-write. | `save_manifest`, `save_lockfile`, and token-store persistence call `write_file` on final paths. | Retain as focused follow-up pending a portable durability design and failure-injection proof. | Open |
| KH-007 | Needs more evidence | Performance / scale | Install and full-lock rebuild paths remain sequential and metadata is reparsed across separate CLI invocations. | Control flow is sequential, but no representative large dependency graph or service workload is maintained here. | Do not add concurrency or caching without representative fixtures, invalidation semantics, and measurements. | Deferred |

## Changes Implemented

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

No token/context optimization was justified: Kennel does not invoke models or expose MCP/tool schemas, and its agent guidance is already scoped with progressive file/search instructions. No dependency-size measurement applies because the manifests declare no runtime or development packages.

## Security

Reviewed boundaries included CLI flags/identifiers, local and Git dependency sources, install paths, shell quoting, package-root containment, symlinks, static index metadata paths, hosted registry mutation/read authorization, token-store parsing and permissions, trust metadata shape, mutable-ref policy, and Git subprocess diagnostics.

Fixed the symlinked package-root escape and added deterministic regression coverage. Existing traversal, identifier, static metadata-path, auth fail-closed, signature/checksum shape, and mutable-ref controls remain enabled. Remaining concern KH-006 is crash consistency, not a demonstrated authorization bypass.

## Compatibility

- Public APIs: unchanged.
- CLI commands, normal output, and exit behavior: unchanged except the corrected missing-source failure.
- Lockfile and manifest formats: unchanged.
- Registry JSON schemas: unchanged.
- Benchmark schema: unchanged at `1.0`; serialization corrected to valid JSON.
- Configuration and environment variables: unchanged.
- External consumers: no migration required. Consumers that had worked around malformed benchmark output should remove that workaround.

## Cross-Repository Follow-Ups

- `kujo`: consider a portable native atomic-write/replace primitive with explicit flush and permission semantics. This would let Kennel address KH-006 without shell-specific durability logic. Kennel does not require this change for current supported behavior.

## Remaining Work

- **P0:** none demonstrated in the audited scope.
- **P1:** none with sufficient evidence for safe implementation in this pass.
- **P2:** replace remaining guarded shell filesystem operations with native Kujo operations when equivalent recursive-copy/atomic-replace semantics exist.
- **P3:** no cosmetic churn recommended.
- **Needs more evidence:** crash-safe manifest/lock/token writes; bounded parallel install; cross-invocation metadata caching; large-graph performance budgets.
- **Not worth changing:** compatibility shims, explicit failure-triage output in verification fixtures, and split contract suites remain intentional contract surfaces.

## Verification Receipt

Baseline and targeted commands:

| Command | Exit | Classification |
| --- | ---: | --- |
| `bash scripts/verify-all.sh core` | 0 | Blocking baseline; passed. |
| `bash scripts/benchmark-harness.sh` | 0 | Measurement; artifact was invalid JSON before the fix. |
| `python3 -m json.tool .kennel_tmp/benchmarks/baseline-results.json` | 1 | Diagnostic baseline; exposed KH-004. |
| `kujo test-run -v tests/contracts/cli-and-core-contract_tests.kujo` | 0 | Blocking targeted regression suite; 28/28 passed after changes. |
| `bash scripts/verify-contract-suites.sh` | 0 | Blocking; all split contracts passed. |
| `bash scripts/verify-security-regression-suite.sh` | 0 | Blocking security gate; passed. |
| `bash scripts/verify-atomicity.sh` | 0 | Blocking state gate; passed. |
| `bash scripts/verify-stage-1-source-matrix.sh` | 0 | Blocking integration gate; passed with zero retained trash directories. |
| `bash scripts/verify-benchmark-harness.sh` | 0 | Blocking artifact contract; valid JSON parsed and checked. |
| `bash scripts/benchmark-harness.sh` | 0 | Post-change measurement; valid output at `.kennel_tmp/benchmarks/post-results.json`. |
| `bash scripts/verify-shell-quality.sh` | 0 | Blocking syntax gate; Bash syntax passed; local ShellCheck unavailable and was explicitly skipped by the repository script. |

The final full-profile, push, clean-tree, and exact final-SHA results are recorded in the final engineering receipt because they occur after this report is committed.
