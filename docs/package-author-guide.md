# Package Author Guide

This guide explains how to make a Kujo project Kennel-compatible in Stage 1.

## 1. Add `kennel.toml`

Start with a minimal package section:

```toml
[package]
name = "my-package"
version = "0.1.0"
description = "What this Kujo package provides."
readme = "README.md"

[package.status]
stage = "experimental"
stability = "early"
public_api = false
notes = "Early package API may change."

[kujo]
minimum_version = "0.1.0"
entry = "main.kujo"
sources = ["."]

[dependencies]
```

## 2. Keep Entrypoints Explicit

If your package is an app, set `kujo.entry`.

If your package is a library, add exports under `[package.exports]` and document import usage in your README.

## 3. Keep Dependencies Explicit

Use explicit refs in Stage 1 when possible:

```toml
[dependencies]
ai-sdk = { source = "github:kujolang/ai-sdk", ref = "main" }
```

For reproducibility, prefer `tag`, `version` (tag-like), or `commit`.

## 4. Exclude Build and Vendor Artifacts

Use `kujo.excludes` for local hygiene.

Recommended:

```toml
excludes = [".git", "kennel_packages", "dist", "build", "node_modules"]
```

## 5. Validate Manifest

Run:

```bash
kujo run kennel.kujo --interpreter -- validate --project-dir /path/to/project
```

## 6. Publish Readiness (Future)

Stage 1 has no publish API.

To prepare for Stage 2/3:

- Keep `name` and `version` stable
- Keep README and repository URL accurate
- Avoid breaking public exports without notes in `package.status.notes`
