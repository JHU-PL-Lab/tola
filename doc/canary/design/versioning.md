# Versioning unification — what landed, what is left

**Kind: rationale + one open item.** Rewritten 2026-08-23: the 2026-07-30
tracker this replaces described pieces A and B as pending, but both had
landed by 2026-08-12 and the doc had not noticed. That is the failure
mode the design/ audit was about — a proposal with no way to tell it
came true. What survives here is the model, the evidence that it is
built, and the one piece that genuinely is not.

Model reference: [`ssot.md` §4.2.2](ssot.md) (the version axis).

## 1. The model — version as artifact identity

A concrete artifact's **version** is its identity: the release **channel**
(`Dev | Stable`) plus an **id** — a commit hash for `Dev`, a tag / release
name for `Stable`.

Pre-condition (ssot §4.2.2): *same version ⇒ identical artifact* (for
binaries, given the same tooling) — so version is a sufficient identity key.

## 2. Where it lives, verified 2026-08-23

| piece | shape in the code | status |
| --- | --- | --- |
| the type | `Canary_basic.version = { channel; id : string }` | **landed** |
| the enumeration's placement | `Canary_artifact.placement = { provision; version : Canary_basic.build_id }`, where `build_id = { channel; id; quality }` | **landed** (2026-08-12, the store-pin work) |
| a project's concrete version list | the provider declares it — `Lang_pkg.versions : opam_pin list` (`pin_version`), projected into the axes by `versions_of_provider` | **landed** |
| the source repo | `source_repo.version : Canary_basic.version` (additive, as piece A proposed — the `ref_` strings stayed) | **landed** |
| the cache key | `"<project>:<step_tag>"` plus a **spec fingerprint** over the realized cmd + expectation (`step_fingerprint`, `backend/canary_local_runner.ml`) | **superseded** — see §3 |

The old §6 open questions are answered by that table. `channel` did NOT
stay a separate axis: `build_id` carries channel *and* id together, an
unpinned artifact keeps `id = ""` and stays version-ambient, and a pinned
one is identity-bearing (it reaches `scenario_dir_of`, `ambient_key` and
assignment dedup). A project declares its versions on the **provider**,
not on `source_repo` or a dedicated spec field.

## 3. The one piece that is left

Piece C was "put the version id in the cache key". It was not done as
proposed and does not need to be: the version already rides `output_dir`,
which IS the scenario dir, and the 2026-08-17 warm-mask fix added a spec
fingerprint that catches a changed command or expectation.

What is still missing is a different thing, and it has its own note:
**the cache does not key on the identity of a step's INPUT artifacts.**
Two independent caches can each be correct by their own rule while the
artifact is wrong — measured twice (ninja + canary's step marker, on a
stale `dllz3ml.so`, 2026-08-20). Tracked in
[`artifact_cache.md`](artifact_cache.md) §5 and
[`run_model_revisit.md`](run_model_revisit.md); not here.

**`version_tag` vs artifact version** stays worth reconciling —
`system_package_spec.version_tag` is a PM pin and a package version is
not an artifact version (ssot §4.2.2). Small, unscheduled, and the only
item this doc still owns.
