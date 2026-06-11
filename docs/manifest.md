# Kennel Manifest (`kennel.toml`)

Kennel uses `kennel.toml` as the package manifest for Kujo projects.

## Goals

- Keep Stage 1 practical and explicit
- Support direct GitHub/Git installs today
- Leave room for registry index and hosted registry features

## Example

```toml
[package]
name = "example-package"
version = "0.1.0"
description = "A short description of what this Kujo package does."
license = "MIT"
authors = ["Your Name <you@example.com>"]
homepage = ""
repository = "https://github.com/owner/example-package"
documentation = ""
keywords = ["kujo", "tooling"]
categories = ["developer-tools"]
readme = "README.md"

[package.status]
stage = "experimental"
stability = "early"
public_api = false
notes = "This package is early-stage and may change before 1.0."

[kujo]
minimum_version = "0.1.0"
entry = "main.kujo"
sources = ["."]
includes = ["README.md"]
excludes = [".git", "kennel_packages", "dist", "build", "node_modules"]

[build]
command = ""
output = "dist"
artifacts = []

[dependencies]
ai-sdk = { source = "github:kujolang/ai-sdk", ref = "main" }
mcp = { git = "https://github.com/kujolang/mcp.git", tag = "v0.1.0" }
dispatch = { source = "github:kujolang/dispatch", version = "v0.1.0" }
local-tool = { path = "../my-local-kujo-tool" }

[dev-dependencies]

[scripts]

[package.exports]

[package.metadata]

[registry]
index = ""
publish = ""

[trust]
checksum = ""
signature = ""
signing_key = ""
```
