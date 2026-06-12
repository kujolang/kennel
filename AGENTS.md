# Agent and Contributor Guide

Use this guide before broad readability, docs, example, or output-surface sweeps.

## Canonical Copyable Examples

- `README.md` Quick Start is the primary onboarding path.
- `examples/basic-project/` is the minimal runnable package fixture and copyable example.
- `docs/contracts/index.example.json` is a schema fixture, not a style example for hand-authored docs.
- `tests/` and `scripts/verify-*.sh` are contract and validation fixtures; keep explicit output when it improves failure triage.

## Search Hygiene

Exclude generated/bulk paths from the main sweep unless the task explicitly targets them; document the search exclusions you used.

Recommended default exclusions:

```bash
rg "pattern" --glob '!.kennel_tmp/**' --glob '!kennel_packages/**'
```

Add focused exclusions such as `docs/contracts/**` or `tests/**` only when the sweep is about copyable examples rather than fixtures.

## Cleanup Bias

- Preserve CLI output byte-for-byte unless the change is explicitly about user-facing wording.
- Add or update output checks before refactoring repeated CLI/report formatting.
- Prefer small local helpers such as `print_lines(lines)` for banners, menus, and static prose blocks.
- Do not hide the command, API, or language feature being demonstrated behind helper code.
- Label legacy, generated, stale, or expected-fail examples where they remain useful.
