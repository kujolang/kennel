# Kennel 1.1.0 production acceptance — September 13, 2026

Kennel 1.1.0 is released and installable anonymously from https://kennel.kujolang.ai with published Kujo 1.4.0. Supported bootstrap platforms are macOS and Linux. Python and Git are not consumer requirements for official packages.

## Release identity

- [GitHub Release](https://github.com/kujolang/kennel/releases/tag/v1.1.0): ID `388030178`.
- Exact tagged source: `093d44dddcebebd99bd8987e3efcb7e044dc45a7`.
- Archive: `https://kennel.kujolang.ai/packages/kennel/1.1.0/package.tar.gz`.
- SHA-256: `d20d585c4b1edc00718726f8f286712a64413f3c5d952a4be05976de318a3299`.
- Archive size: 862,997 bytes; 244 files; minimum Kujo 1.4.0.
- [Independent release build](https://github.com/kujolang/kennel/actions/runs/34781810429) and [registry publication](https://github.com/kujolang/kennel-registry/actions/runs/34781836330) produced identical archive bytes.
- [SBOM attestation](https://github.com/kujolang/kennel/actions/runs/34781809585) passed; security artifacts and canonical registry artifacts are attached to the GitHub Release.

## Verification

| Gate | Result |
| --- | --- |
| `bash scripts/verify-all.sh core` using published Kujo 1.4.0 | PASS |
| `bash scripts/verify-profiles.sh full` before publication | PASS; includes every `verify-*.sh`, security regression, Stage 3, local/source compatibility and contract suites |
| [Release commit CI](https://github.com/kujolang/kennel/actions/runs/34781215266) | PASS: all eight jobs, including macOS, full, security, Stage 2 and Stage 3 |
| `bash scripts/verify-global-tools.sh` and `bash scripts/verify-registry-packages.sh` | PASS, including independent hostile archive fixtures |
| ShipCheck `scan` and `gate --format json` against the release worktree | Exit 0; 16/16 checks; zero report warnings/errors; informational highest report severity |
| `bash scripts/verify-profiles.sh full` after delivery corrections | PASS |
| [Delivery correction CI](https://github.com/kujolang/kennel/actions/runs/34782270571) | PASS: all eight jobs |
| [Public bootstrap acceptance](https://github.com/kujolang/kennel/actions/runs/34782478651) | PASS: GitHub-hosted macOS and Linux, released Kujo 1.4.0 and publicly installed Kennel 1.1.0 |
| [Final acceptance-harness CI](https://github.com/kujolang/kennel/actions/runs/34782441437) | PASS: all eight jobs |
| Same public acceptance on local Intel macOS | PASS |
| All-package pre-publication candidate check | 36/36 fresh downloads and 36/36 cached lock replays with Git disabled; see `catalog-before-publication.jsonl` |
| Historical immutability | All 190 pre-existing immutable files retained their SHA-256 values |
| [Full official-release reconciliation after launch](https://github.com/kujolang/kennel-registry/actions/runs/34782729863) | PASS; all enrolled repositories reviewed and live deployment verified |

The public acceptance receipts beside this file cover PATH/profile setup, repeat bootstrap, Changebucket 1.0.0 and Kennel 1.1.0 default/exact/clean/cached installs, byte-identical lock replay within each project, ShipCheck global invocation, tool/client updates, rejected historical-client update with rollback, and tool removal. Executable guards reject any Git/Python invocation. Timing fields are single-run observations in milliseconds, not performance guarantees.

ShipCheck's older released scanner emitted two nonfatal type-check diagnostics while its report returned 16/16 passing. ShipCheck does not replace the actual regression or production tests.

## Delivery findings resolved during acceptance

The first public test found the shell downloader passing response bytes to `write_file`; it now uses `io_write_bytes`. A subsequent test found flattened installer modules changing variable resolution during archive extraction. The generated installer now materializes its reviewed modules in a private temporary directory, runs them with isolated imports, and cleans them up. Deterministic bundle/source-install tests and the exact downloader template's byte/checksum regression tests cover the corrections.

These fixes affect mutable registry delivery, not the released client archive. Registry publishing is pinned through workflow `88b4e17433e09fa2bf6b16b12cd4b13815660f2c` to publisher `0e026bad87609405d8b4a1135bbffa25777cd5da`. The release tag and archive were never moved or overwritten. The public test harness is independently versioned; it installs the client from the public registry rather than running its checkout as the client.

## Operating boundaries

Public reads use static protocol v1; lock schema 1 is retained. Provenance verifies consistency with the trusted HTTPS registry, not an independent signature. Unscoped names remain first-party reserved. Accounts, third-party publishing, Windows bootstrap, metadata ETag caching, independent archive signatures and automatic old-generation pruning are outside this release.

Existing enrolled repositories publish through actual GitHub Releases. Reconciliation is scheduled every 15 minutes, subject to GitHub scheduling delays; maintainers can dispatch it manually. New repositories still require explicit enrollment and valid release manifests. No accounts, server, database, Worker or object store was added to the registry.

## Discovery surfaces

- [Main website deployment](https://github.com/kujolang/kujolang.ai/actions/runs/34782757006): PASS. The live Kennel page advertises 1.1.0 and the native installer. The complete 242-page build and site contracts passed.
- [Final docs CI](https://github.com/kujolang/docs.kujolang.ai/actions/runs/34783847625) and [Pages deployment](https://github.com/kujolang/docs.kujolang.ai/actions/runs/34783848414): PASS. All 103 HTML pages passed validation. The live homepage shows Kujo Docs 1.4.0, updated September 13, 2026; package guides use the released client.
- [MCP validation](https://github.com/kujolang/kujolang-mcp/actions/runs/34782798184): PASS. Production parity compared all 230 records and six installation profiles. The Kennel record uses 1.1.0 and the public installer; catalog revision is `d327a84019c0c8a9357e00757ddd71fa8790d164f031da82b12fa279baff8526`.

All modified repositories were committed, pushed and verified clean. The existing user's Kujo executable and unrelated work were preserved; consumer testing used an independently verified published Kujo 1.4.0 binary in isolated homes.
