# Official package enrollment review

2026-09-07 public kujolang repository inventory, obtained from the GitHub organization API. Only `kennel` and `changebucket` are enrolled. Wider enrollment must wait for successful production acceptance and per-release packaging/dependency/license review.

Likely developer-tool candidates: concord, howl, scout, casefile, muzzle, scent, lens, packwrite, shipcheck, patchbrief, runledger, fence, dispatch, eval, spec, redact. Likely library candidates: agents-sdk, ai-sdk, mcp, ability and the provider packages. These are candidates, not approved publication policy.

Require additional application/runtime review: watchdog, ssg, rag, cms, intake, workcell, relay, commerce, site-kit, and the WebOps/editorial tools. Do not assume a repository containing an application is an installable package.

Exclude from automatic enrollment: kujolang.ai, docs.kujolang.ai, agents.kujolang.ai (websites); kennel-registry (distribution infrastructure); kujo (language/toolchain binary distribution); kujo-skills, kujo-agents, kujo-workflows (contracts/workflow collections); ai-chat, crud-api, cms-example, cms-contact-form, cms-field-notes-theme, sitekit-docs-template, workcell-studio (showcases/templates/apps requiring a separate packaging decision).

No new releases or versions were created. Historical Changebucket v1.0.0 was still named ChangeBudget: its exact commit-specific policy generates only a distribution manifest, preserves released source, records the adaptation in provenance, and does not invent a missing license.
