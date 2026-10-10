# Official package enrollment review

This document preserves the initial September 7 review. Current enrollment is defined by [official-packages.json](https://github.com/kujolang/kennel-registry/blob/main/official-packages.json) and the registry's [enrollment guide](https://github.com/kujolang/kennel-registry/blob/main/ENROLLMENT.md).

2026-09-07 public kujolang repository inventory, obtained from the GitHub organization API. Only `kennel` and `changebucket` are enrolled. Wider enrollment must wait for successful production acceptance and per-release packaging/dependency/license review.

Likely developer-tool candidates: concord, howl, scout, casefile, muzzle, scent, lens, packwrite, shipcheck, patchbrief, runledger, fence, dispatch, eval, spec, redact. Likely library candidates: agents-sdk, ai-sdk, mcp, ability and the provider packages. These are candidates, not approved publication policy.

Require additional application/runtime review: watchdog, ssg, rag, cms, intake, workcell, relay, commerce, site-kit, and the WebOps/editorial tools. Do not assume a repository containing an application is an installable package.

Exclude from automatic enrollment: kujolang.ai, docs.kujolang.ai, agents.kujolang.ai (websites); kennel-registry (distribution infrastructure); kujo (language/toolchain binary distribution); kujo-skills, kujo-agents, kujo-workflows (contracts/workflow collections); ai-chat, crud-api, cms-example, cms-contact-form, cms-field-notes-theme, sitekit-docs-template, workcell-studio (showcases/templates/apps requiring a separate packaging decision).

No new releases or versions were created. Historical Changebucket v1.0.0 was still named ChangeBudget: its exact commit-specific policy generates only a distribution manifest, preserves released source, records the adaptation in provenance, and does not invent a missing license.

## Commerce release review — October 10, 2026

[Commerce 0.5.0](https://github.com/kujolang/commerce/releases/tag/v0.5.0) is a JavaScript/npm package, not a native Kujo package. Its PostgreSQL and Square modules do not change that boundary. Keep it outside Kennel enrollment; do not create a synthetic `kennel.toml` or suggest `kennel add commerce`.

Install the verified GitHub release tarball with npm while registry publication is pending:

```bash
npm install https://github.com/kujolang/commerce/releases/download/v0.5.0/kujolang-commerce-0.5.0.tgz
```

See the [Commerce docs](https://docs.kujolang.ai/tools/commerce/) for upgrades and the registry's [release audit](https://github.com/kujolang/kennel-registry/blob/main/release-audit.json) for release identity.
