# Kennel 1.1.0 release candidate

Status: pre-release candidate for review. Current CI conclusions and acceptance receipts are linked from the three PRs below; do not treat historical failures in this record as current CI status. **No tag, GitHub Release or registry package for 1.1.0 has been published.** Review this candidate before approving a release.

## Review scope

- `bin/kennel`: stable terminal launcher, no-argument help, `--version`, global tool commands and self-update.
- `scripts/install.py`: per-user macOS/Linux bootstrap, explicit source-review mode, runtime prerequisite checks, HTTPS/hash/provenance verification, bounded safe extraction, collision protection and atomic client selection.
- `scripts/tool_manager.py`: global install/update/list/remove/run, isolated generation projects, the existing native resolver/installer/cache/lockfile pipeline, executable mapping, deterministic activation records, command ownership and rollback.
- `[bin]`: declared `.kujo` commands or supported executable sh/Bash/Python 3 scripts; historical `[kujo].entry` fallback. Spec's real published Bash entry is supported.
- `scripts/registry/onboarding.py`: inspectable installer delivery and getting-started page. The preview notice remains until an installer-enabled stable archive exists.
- Kujo runtime companion change: `run --isolated-imports`, propagated to child Kujo processes, removes caller-directory/module/lockfile lookup while preserving filesystem cwd. Exact argv, including zero arguments and separator characters, is preserved in this mode. Default runtime behavior is unchanged.

The POSIX layer uses Python's standard library for file locking, process replacement, shell-profile handling and bootstrap. Package resolution, trust checks and tool installation stay in the existing Kujo client. Source dependency and legacy hosted commands remain available. No accounts, database, server, new publishing API or package mirroring was added.

## Required release order

The published Kujo 1.3.1 runtime does **not** have the isolation flag. Build the updated Kujo checkout for review. The installer and tool manager reject an incompatible runtime instead of silently running with unsafe module lookup. A compatible Kujo runtime release must precede Kennel 1.1.0 public installation. No Kujo release was created during this work.

After review, publish the chosen compatible Kujo runtime release, then Kennel 1.1.0 as an actual GitHub Release. The registry's existing scheduled reconciliation packages that exact release and Pages deploys it. The marker in the latest stable archive enables public onboarding automatically. A final fresh public bootstrap after those releases is a release gate, not something simulated by overwriting historical artifacts.

## Merge and release decision checklist

Merging these PRs does not publish a Kujo or Kennel version. Merge after review in this order: Kujo PR 7, Kennel PR 1, then registry PR 1. The registry merge does deploy its generated onboarding through Pages; it retains the preview notice until an installer-enabled stable Kennel archive is available. Reusable workflows and runtime checkouts use immutable commit pins, so a merge does not silently substitute another implementation.

Before approving release:

1. Require successful current PR checks, including Kennel's full-profile matrix job. The manual nightly workflow can also run on the candidate branch without a release.
2. Review the manual Kujo `release-binaries` workflow artifacts. Branch dispatch builds candidate artifacts; both GitHub-release and npm publication jobs are tag-only and must remain skipped. Manual artifacts still carry the checkout's Cargo version and are not a new public version.
3. Review `CHANGELOG.md` and the complete Kujo Unreleased scope. This companion PR does not represent all changes already merged since Kujo 1.3.1. At release approval, select the next Kujo version and synchronize Cargo/npm manifests and release-state documents using the existing release checks. Kennel's proposed version is 1.1.0.
4. Reproduce live global-command acceptance with `KUJO_BIN=/absolute/compatible/kujo python3 scripts/registry/global_tools_production_e2e.py`. It uses a temporary home, keeps user shell profiles unchanged, installs four real released tools, checks exact-version updates and failed-client-update rollback, then removes its temporary state.
5. Reproduce project-package acceptance with `KUJO_BIN=/absolute/compatible/kujo python3 scripts/registry/production_e2e.py`.

Only after the release decision: publish the compatible Kujo runtime, then publish the actual Kennel GitHub Release. Pushing a Kujo `v*` tag activates its release-publishing workflow, so do not create that tag during review. Kennel's official Release publication (not a tag alone) activates package distribution. Registry reconciliation runs every 15 minutes; maintainers can dispatch its existing workflow for a selected package/release ID if needed.

After publication, verify the public installer in a fresh home, `kennel --version`, a global command and `kennel add changebucket`, and confirm Pages serves the new immutable manifest/archive and removes the preview notice. Those checks depend on actual published releases and cannot be completed honestly during pre-release review.

## Review locally

Build the updated Kujo checkout with `cargo build --release --bin kujo`, then:

```sh
export KUJO_BIN=/absolute/path/to/kujo/target/release/kujo
python3 scripts/install.py --source . --home /absolute/review-home --no-modify-path
/absolute/review-home/bin/kennel --version
/absolute/review-home/bin/kennel tool install shipcheck
/absolute/review-home/bin/shipcheck --help
/absolute/review-home/bin/kennel tool update shipcheck
/absolute/review-home/bin/kennel tool remove shipcheck
```

If an unrelated `shipcheck` already exists on PATH, installation deliberately refuses it; use `--allow-shadow` only for an intentional separate shim. No existing executable is replaced.

## Historical implementation verification record

Verified on macOS with the optimized Kujo isolation candidate:

- `KUJO_BIN=/absolute/path/to/kujo/target/release/kujo bash scripts/verify-all.sh core`: passed as part of the full-profile run.
- `scripts/verify-contract-suites.sh`: 29 CLI/core + 7 registry-index + 18 hosted-registry tests passed (54 total).
- `scripts/verify-global-tools.sh`: 17 Python tests, offline installer/PATH/tool lifecycle E2E, and deterministic release-path bootstrap/corrupt-update rollback passed.
- Registry package suite: 5 Kujo tests and 12 Python tests passed.
- `node scripts/registry/verify_site.cjs http://127.0.0.1:8769`: passed generated-site desktop/mobile, clipboard, keyboard, no-JS and overflow checks.
- Live-registry review: a temporary custom `KENNEL_HOME` installed ShipCheck 1.0.0, Spec 1.0.1, Changebucket 1.0.0 and RunLedger 1.1.0 from `kennel.kujolang.ai`, then invoked their global commands from a separate directory containing a conflicting module fixture. All four passed. Exact ShipCheck pin/update, content-cache location, and failed self-update to historical Kennel 1.0.1 preserving the active client also passed. The candidate client was bootstrapped from reviewed source; this is not a claim that public 1.1.0 bootstrap is live.
- ShipCheck `scan` and `gate --dir /absolute/path/to/kennel --format json`: exit 0, 16/16 passed, zero warning/error findings, gate passed. Existing runtime type-check warnings were printed separately.
- Kujo `cargo build --release --bin kujo`: passed. `(cd /absolute/path/to/kujo/scripts && bash verify-installed-tool-imports.sh)`: 2 Rust integration tests passed, exercising both VM and interpreter. `cargo fmt --check`: passed. After rebasing the unchanged isolation patch onto current main, `cargo check --bin kujo -j1`: passed. The optimized binary predates that rebase; the check covers the rebased source. A second full `cargo test --release` build was cancelled rather than counted as a pass; the actual integration test source was compiled/run by the provided verification script.
- Full-profile attempts: `bash scripts/verify-all.sh all` and `bash scripts/verify-profiles.sh full` returned nonzero during existing Git/network-dependent checks. One lookup stalled; another run encountered host process exhaustion. Core and contract suites passed, and the affected SemVer test passed on retry. The remaining stage scripts all passed in segmented runs (one stage-1 compatibility retry was needed after an explicit process-spawn error). `bash scripts/verify-profiles.sh security` passed with exit 0. Together the runs cover every full-profile script, but an uninterrupted full-profile pass is still required before release. GitHub verification was queued at handoff.

Earlier full-profile attempts encountered host process exhaustion (`os error 35`) and a stalled GitHub-dependent SemVer lookup. The SemVer retry passed with per-process Git low-speed limits. No assertions were weakened.

Local evidence: `/tmp/kennel-global-full-bounded.log`, `/tmp/kennel-global-complete.log`, `/tmp/kennel-global-production-final.log`, `/tmp/kennel-global-site-final.log`, `/tmp/kennel-global-shipcheck-gate.json`, `/tmp/kujo-global-import-script.log`, `/tmp/kujo-global-rebased-check.log`, `/tmp/kennel-global-full-remainder.log`, `/tmp/kennel-global-final-stages.log`.

## Review links

- Kennel client: https://github.com/kujolang/kennel/pull/1
- Required Kujo runtime: https://github.com/kujolang/kujo/pull/7
- Registry onboarding: https://github.com/kujolang/kennel-registry/pull/1

All three are draft review PRs. No main-branch deployment or release is required to inspect the candidate.

## Security and compatibility review

Downloads stay on official HTTPS; redirects are not followed. The bootstrap binds the exact Kennel repository ID, package/version/source/workflow identity and digests, verifies compressed size and file count, caps compressed and expanded sizes, and rejects links, special files, traversal and canonical path collisions. Provenance is trusted-registry consistency, not an independent signature.

Global mutations use an OS file lock and a single atomically replaced state file. Failed install/update leaves the previous generation active. Unmanaged executable files and commands owned by other tools are protected. Tool entry declarations cannot traverse directories or select an arbitrary interpreter. Kujo's opt-in import isolation prevents caller-workspace modules from replacing installed modules. It is not a sandbox: tools retain normal user permissions.

Immutable registry archives/version metadata remain unchanged. Project dependencies still use `kennel add` and `kennel install`; global commands are opt-in via `kennel tool install`. Existing exact pins stay pinned through tool updates. `KENNEL_HOME` keeps custom installation state and artifact cache together.

## Deliberate limits

- macOS/Linux POSIX integration; no native Windows installer.
- Bash/Zsh/POSIX shell profiles are handled automatically; Fish can use `fish_add_path` with `--no-modify-path`.
- Old generations are retained for running processes and manual recovery; automatic pruning is deferred.
- Installed tool capabilities are those of their actual released source. No historical tool is rewritten to add a different CLI.
- Existing catalog exclusions, including Dispatch's unreleased dependency, remain documented in the registry enrollment inventory.
