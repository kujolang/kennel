# Stage 1 GitHub Installs

Stage 1 is focused on direct installs from GitHub shorthand and GitHub HTTPS URLs.

## Supported Source Forms

- `github:owner/repo@ref`
- `github:owner/repo`
- `https://github.com/owner/repo.git#ref`
- `https://github.com/owner/repo#ref`

Also supported for local development:

- `file:../local-package`
- `../local-package`

Not supported in Stage 1:

- arbitrary non-GitHub git remotes
- SSH git URLs

## Resolution Behavior

For each dependency, Kennel resolves:

- Package name (alias or repo name)
- Source URL
- Requested selector (`version`, `tag`, `ref`, or `commit`)
- Resolved commit hash when available
- Install path under `kennel_packages/<name>`

Rules:

- `version`: treated as tag-like selector in Stage 1
- `tag`: treated as Git tag selector
- `ref`: branch/tag/named ref selector
- `commit`: pinned commit; no floating update

## Install Behavior

Install target:

- `kennel_packages/<package-name>/`

After clone/copy, Kennel removes common non-runtime directories when present:

- `.git/`
- `node_modules/`
- `dist/`
- `build/`
- `kennel_packages/`
- `.kennel_tmp/`

## Lockfile Contract

`kennel.lock` stores deterministic package entries with:

- `name`
- `source`
- `requested`
- `requested_kind`
- `resolved_ref`
- `resolved_commit`
- `install_path`
- `repository`
- `kind`
- `checksum` placeholder

## Deterministic Installs

`kennel install` behavior:

- If `kennel.lock` exists: install from lockfile
- If lockfile is missing: resolve from manifest and create lockfile

This supports reproducible installs in CI and team development.

## Trust Guidance

Stage 1 installs remote code directly from Git sources.

Use explicit refs where possible and install only from repositories you trust.
