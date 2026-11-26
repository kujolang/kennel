# Kennel Git commit resolution

The packaged Howl v1.2.0 smoke test found that Kennel wrote the annotated tag object `4428a7f` to `resolved_commit` even though the checked-out source was commit `769af88`. The semver resolver also dropped the selected Git object before starting a separate clone. Baseline `7c76eae`.

Kennel now asks Git for both tag rows in a single lookup and locks the selected checkout commit. Semver installations still try a shallow clone of the selected tag. The checkout must match the resolved commit. Full clone and pinned checkout remain available for replay when the tag cannot be shallow-cloned or no longer points to the locked commit. Existing object-pinned locks remain replayable with the corresponding tag object available.

The new offline fixture checks annotated and lightweight tags, an explicit tag ref, a branch, semver before installation, regular locked replay, replay of a legacy annotated-object lock, and replay after a tag is retired while its commit remains reachable. It fails against the baseline and is wired into the core and hosted stage 1 gates. Real GitHub lookups for the Howl tag and range both returned `769af8827ab7f32e3b5f009d50f7643a45144fea`.
