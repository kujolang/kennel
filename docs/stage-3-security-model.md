# Stage 3 Security Model: Tokens, Trust, and Hosted Permission Boundaries

This document defines the current Stage 3 security behavior for Kennel hosted-registry workflows.

## Security Goals

1. Keep credentials out of manifests, lockfiles, and command output.
2. Enforce hosted mutation boundaries so only package owners can mutate package state.
3. Enforce trust policy fields (checksum/signature/signing_key) during dependency operations.
4. Provide command-oriented guidance that maps directly to tested scripts.

## Token Handling

Preferred login forms:

```bash
# preferred: token file avoids shell-history leakage
kujo run kennel.kujo --interpreter -- login \
	--token-file ~/.kennel/token.txt \
	--registry hosted-registry \
	--user alice

# supported: direct token value (use with caution)
kujo run kennel.kujo --interpreter -- login \
	--token YOUR_TOKEN \
	--registry hosted-registry \
	--user alice
```

Storage behavior:

- Default token store path is `~/.kennel/tokens.json` unless `--store-path` is provided.
- Token-store writes are hardened with restrictive file permissions.
- Login output confirms storage path but does not print raw token values.
- Token material must never be committed to source control.

## Trust Policy Usage

Trust policy is declared in `kennel.toml`:

```toml
[trust]
checksum = "sha256:..."
signature = "base64-signature"
signing_key = "key.id"
```

Operational rules:

- `checksum` must be syntactically valid and must match package metadata.
- `signature` and `signing_key` are enforced when declared.
- Malformed policy values fail fast with explicit diagnostics.
- Malformed package trust metadata is reported distinctly from policy mismatch errors.

## Private Package Workflows

Use private visibility for restricted packages:

```bash
kujo run kennel.kujo --interpreter -- publish \
	--private \
	--registry hosted-registry \
	--user alice \
	--store-path ~/.kennel/tokens.json \
	--registry-dir .kennel_registry
```

Visibility transitions:

```bash
kujo run kennel.kujo --interpreter -- visibility <package> private --registry hosted-registry --user alice --store-path ~/.kennel/tokens.json --registry-dir .kennel_registry
kujo run kennel.kujo --interpreter -- visibility <package> public  --registry hosted-registry --user alice --store-path ~/.kennel/tokens.json --registry-dir .kennel_registry
```

## Permission Boundaries

Hosted mutation boundaries:

- Only owners can publish new versions for an existing package.
- Only owners can yank/unyank package versions.
- Only owners can manage access (`owner-add`, `owner-remove`, `team-add`, `team-remove`).
- Only owners can change package visibility.
- Private package metadata/API responses require owner context.

These boundaries are intentionally strict and should not be bypassed in automation.

## Validation Mapping

Security guidance in this document is cross-checked by existing stage-3 and trust scripts:

```bash
bash ./scripts/verify-stage-3-login-workflow.sh
bash ./scripts/verify-stage-3-private-package-workflow.sh
bash ./scripts/verify-stage-3-server-permission-workflow.sh
bash ./scripts/verify-stage-3-trust-signature-workflow.sh
bash ./scripts/verify-contract-suites.sh
```
