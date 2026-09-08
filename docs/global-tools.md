# Global tools and the Kennel installer

Status: 1.1.0 release candidate, not published. The latest historical release remains immutable. macOS and Linux are supported; Windows users need a Linux environment such as WSL. Kujo 1.3.1+, Python 3.9+ and curl are prerequisites. Python handles POSIX installation, command activation and bootstrap; the existing Kujo client remains responsible for tool resolution, checksums, provenance, extraction, caching and lockfiles. There is no second package resolver or package execution hook.

## Review before release

From this checkout:

```sh
python3 scripts/install.py --source .
. "$HOME/.kennel/env"
kennel --version
kennel tool install shipcheck
shipcheck --help
```

`--source` is explicitly a review build: it copies tracked files from the current working tree, including reviewed edits, into a separate client generation. It excludes caches and untracked files. It does not create a release, tag or registry package.

For a disposable review, use `--home /absolute/review-directory --no-modify-path`. Invoke `/absolute/review-directory/bin/kennel`; set `KUJO_BIN=/absolute/path/to/kujo` if the appropriate runtime is not already on PATH. The installer never silently installs Kujo or alters the system runtime.

## Public installation after release

```sh
curl -fsSLO https://kennel.kujolang.ai/install.sh
sh install.sh
. "$HOME/.kennel/env"
kennel --version
```

Both installer files are inspectable. The shell entry point pins the Python installer digest. The Python bootstrap permits only official registry HTTPS URLs, rejects redirects by not following them, bounds downloads and expansion, verifies archive/provenance hashes and release/workflow identity, and rejects unsafe tar entries. This is HTTPS registry trust and provenance consistency, not an independent signature.

The installer creates `~/.kennel/bin/kennel` and atomically selects `~/.kennel/client`. It adds a marked, idempotent PATH block to `.profile`, `.bash_profile`, `.bashrc` and `.zshrc`, preserving other text. It cannot modify the parent terminal's environment; source `~/.kennel/env` or open a new terminal. Symlinked profiles require `--no-modify-path`. Fish users use `fish_add_path ~/.kennel/bin` and `--no-modify-path`.

Use `--version X.Y.Z` to pin an actual release. Until an installer-enabled release is published, normal installation rejects historical releases and explains the source review option. No fallback to mutable main is allowed.

## Tool lifecycle

```sh
kennel tool install shipcheck
shipcheck --help
kennel tool install shipcheck@1.0.0
kennel tool list
kennel tool update shipcheck
kennel tool update
kennel tool remove shipcheck
```

An unversioned install resolves the latest stable package; an exact request remains exact on update. Use `tool install NAME@VERSION` again to change a pin. Each global package gets a separate project and deterministic lockfile under `~/.kennel/tools/generation-*`. The original package manager installs its dependencies there. Global operations never modify the caller's project manifest or lockfile.

Command shims live in `~/.kennel/bin`. They look up one atomically replaced `tools.json` record and run the verified package entry with Kujo. Arguments, exit status and the caller's working directory are preserved. Locked dependency roots are passed to the runtime. Existing `KUJO_MODULE_PATH` is not inherited by global tools, avoiding accidental environment-level dependency substitution. Tools run with the user's normal permissions, not in a sandbox.

`[bin]` explicitly declares commands:

```toml
[bin]
my-tool = "main.kujo"
my-other-command = "cli/other.kujo"
```

The publisher validates that each entry is a packaged `.kujo` file. Global activation rejects unsafe names, missing entries, traversal, symlinks and reserved runtime/shell names. For historical packages with no `[bin]`, an explicit `tool install` uses `[kujo].entry` and the package name. This does not make libraries globally executable when installed with `kennel add`. Packages with no executable entry fail with guidance to use project dependencies.

`--command NAME` renames a single-entry tool. Commands belonging to another globally installed package cannot be overwritten. Unmanaged files in the Kennel bin directory are never overwritten. A command already elsewhere on PATH requires `--allow-shadow`; this only permits a new Kennel shim and does not edit the other executable.

An OS file lock serializes mutations. Install/update prepares a new generation, validates all commands, writes owned shims, then atomically replaces global state. A failed install leaves the prior installation active. Removed/obsolete shims are deleted only if they still contain Kennel's exact managed wrapper. Old generations are retained to avoid deleting files used by running tools; automatic pruning is not implemented.

## Update or remove the client

```sh
kennel self update
kennel self update --version X.Y.Z
```

Updates download an actual official release and preserve global tool state. Failed verification or an incompatible historical release leaves the active client untouched. Old client generations remain available for manual rollback by restoring the `client` symlink to a reviewed generation in `clients/`.

To uninstall, remove tools with `kennel tool remove NAME`, remove the marked Kennel PATH blocks from the four shell profiles, and remove the dedicated `~/.kennel` directory only after confirming its caches/generations are no longer needed. Custom installation homes use the same layout. Do not remove unrelated commands elsewhere on PATH.

## Maintainer release checklist

- Review 1.1.0 changes and exact test results in `docs/registry/release-candidate.md`.
- Keep the manifest version, intended tag and changelog aligned.
- Ensure `bin/`, `scripts/bootstrap.json`, `scripts/install.py`, `scripts/tool_manager.py` and `scripts/tool_metadata.kujo` are included in the release package.
- Publish an actual GitHub Release only after approval. A tag push alone does not publish a registry package.
- Registry reconciliation packages the exact release and Pages deploys it. The onboarding page detects the installer marker in the latest stable archive and automatically removes the preview notice.
- Verify a fresh public installer, `kennel --version`, a global tool invocation and project installation after the real release. No release is fabricated to satisfy this pre-release review.
