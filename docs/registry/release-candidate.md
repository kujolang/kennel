# Kennel 1.1.0 native release candidate

Status: unpublished, for review. No tag or release is created by this migration. The previous installer PRs were merged; this follow-up replaces their Python implementation with native Kujo scripts before release.

## What changed

- `scripts/install.kujo` and `src/bootstrap.kujo`: per-user source/public bootstrap, profiles, verified immutable releases and atomic client activation.
- `scripts/tool_manager.kujo` and `src/global_tools.kujo`: global install/update/list/remove/run through the existing resolver, cache, provenance and lockfile implementation.
- `scripts/registry/*.kujo`: deterministic package building, approved release reconciliation, static site generation, deployment verification and production acceptance.
- `scripts/bundle_installer.kujo`: generates the standalone public installer from reviewed native modules. The small POSIX entrypoint runs Kujo for its download and checksum verification.
- Runtime mechanisms: POSIX advisory locks, atomic symlink selection, user-ownership inspection and process replacement with exact argv/inherited terminal streams.

No consumer Python requirement remains. Git is required for source-review installation and publisher Git-object reads, not official registry consumption. Bash/Python package entries remain supported when the released package itself requires that interpreter. Python survives only in independent adversarial archive test fixtures and their native test bridge; it is not shipped as an invoked bootstrap, tool manager or publisher.

## Compatibility and release order

The published Kujo 1.3.1 lacks the required source capabilities. Use a build with `--isolated-imports`, `file_lock`, `file_unlock`, `exec_process`, `symlink_atomic` and `path_owned`. Release that compatible Kujo runtime before Kennel 1.1.0. Choose/synchronize Kujo’s version and release-state documents only when approving its complete Unreleased scope.

Installer protocol 2 denotes the native bootstrap. This does not change registry protocol v1 or lockfile schema 1. Existing client symlink, launcher, global state and generation layouts are preserved; existing protocol-1 source installations can be replaced through an explicit native source install. Public bootstrap rejects historical releases without the native marker. Never replace an immutable old archive.

The native archive builder retains normalized USTAR/gzip and the same manifest/provenance schemas. Its builder identity is `kennel-kujo-ustar-gzip-v1`. Compression/canonical serialization can differ from the retired Python builder, so old releases are verified and skipped rather than rebuilt. Attempting to publish different bytes at an existing version fails closed.

Review/merge runtime, client, then registry delivery. A registry merge deploys the generated site; it retains the preview notice until a native-installable stable release exists. Scheduled reconciliation still runs every 15 minutes and processes actual published GitHub Releases. No accounts or service infrastructure are added.

## Review commands

```sh
export KUJO_BIN=/absolute/compatible/kujo
export KUJO_MODULE_PATH="$PWD"
"$KUJO_BIN" run scripts/install.kujo --interpreter --isolated-imports -- --source . --home /absolute/review-home --no-modify-path
/absolute/review-home/bin/kennel --version
/absolute/review-home/bin/kennel tool install shipcheck
/absolute/review-home/bin/shipcheck --help
bash scripts/verify-global-tools.sh
bash scripts/verify-registry-packages.sh
bash scripts/verify-profiles.sh full
"$KUJO_BIN" run scripts/registry/production_e2e.kujo --interpreter --isolated-imports
"$KUJO_BIN" run scripts/registry/global_tools_production_e2e.kujo --interpreter --isolated-imports
```

Current verification receipts belong in the review PRs and handoff; a local partial run is never a substitute for clean full CI. The native test suites cover profile preservation, exact arguments/cwd, conflicting caller modules, lifecycle, ownership, obsolete shim removal, failed activation rollback, deterministic archives, immutable publication and integrity failures. The original registry regression suite now calls the native builder while generating independent hostile archives.

After actual releases, verify the public installer from a fresh home, version output, project/global installs, updates, cached installs, Pages metadata/artifacts and removal of the preview notice. These publication-dependent checks remain future release gates.

## Boundaries

Kennel’s bootstrap/global OS integration remains macOS/Linux POSIX. Unsupported native Windows use fails explicitly; no Windows installer is claimed. Old generations remain for running processes/recovery; automatic pruning is deferred. Import isolation is not a sandbox. Provenance validates trusted-registry consistency, not an independent signature. Publisher GitHub access and filesystem mutation remain bounded, explicit trusted automation.
