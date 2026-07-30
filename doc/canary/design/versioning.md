# Versioning unification — design + tracker

> **Status: design / tracking doc.** Versioning is bigger than a single
> enumeration axis: it needs a global design, its own test cases, and
> uniform usage across the enumeration, the store, and the cache. Tracked
> here rather than inline in [`../status.md`](../status.md).

Model reference: [`ssot.md` §4.2.2](ssot.md) (the version axis).

## 1. The model — version as artifact identity

A concrete artifact's **version** is its identity: the release **channel**
(`Dev | Stable`) plus an **id** — a commit hash for `Dev`, a tag / release
name for `Stable`. Typed as `Canary_basic.version = { channel; id : string }`.

Pre-condition (ssot §4.2.2): *same version ⇒ identical artifact* (for
binaries, given the same tooling) — so version is a sufficient identity key.

The version should flow as **one** identity through:

- **enumeration** — read + print which version each artifact is at.
- **store / source_repo** — the concrete version of a fetched/built artifact.
- **cache key / provision** — a version identifies the artifact *resource*
  (a re-fetch at a different version is a different resource, so it must
  key the cache).

## 2. Where version lives today (as strings)

| location | form | note |
|---|---|---|
| `source_repo.version` / `ref_` (`tool/canary_artifact_source.ml`) | strings | concrete version; **~91 interpolation sites** across z3/llvm (`%{source.version}_%{source.ref_}` in build/cache dirs + opam pkg names) — the bulk of the migration cost |
| `system_package_spec.version_tag` (`base/canary_store.ml`) | `string option` | PM pin |
| cache key (`backend/canary_local_runner.ml`) | `"<project>:<step_tag>"` | version **not** in the key — it rides the `output_dir` path |
| enumeration `placement.version` (`action/canary_enumerate.ml`) | `channel` only | concrete id not yet connected |

## 3. The three pieces

- **A. `source_repo` → typed version.** *Small* if additive (add a
  `version : Canary_basic.version` field, keep the strings); *medium-large*
  to migrate the ~91 string interpolations to accessors.
- **B. enumeration carries the concrete version.** `placement` / `config` /
  `run_config` range over `Canary_basic.version` (a project supplies its
  `{channel; id}` list) instead of the bare channel; render + tests follow.
- **C. cache key / provision include the version id.** *Small* code
  (`"<project>:<id>:<step_tag>"`); needs care on cache invalidation
  (output_dir already carries the version, so it's partly there).

## 4. Incremental strategy — simple projects first (decision 2026-07-30)

**The enumeration's version is decoupled from z3/llvm's string machinery.**
The ~91 interpolation sites are about *build paths / package names* — a
separate concern from the enumeration *axis*. So we don't have to move them
together:

1. **Do piece B for the simple projects first** — tiny, sqlite, and the
   Pattern-A projects (ssl / cairo / zarith). Their versions are simple
   (sqlite = one system version; ssl = 0.6.0 / 0.7.0). Give the enumeration
   a typed `version` there, with test cases — validating the design on
   easy cases.
2. **Leave z3/llvm on the legacy path** — their `source_repo` strings and
   their `--engine` render stay channel-based (or a thin `{channel; id}`
   wrap of their existing `version`/`ref_`) until the big migration. **No
   touching the 91 sites.**
3. **Then** piece A (migrate `source_repo` strings) and C (cache key), and
   fold z3/llvm in.

This pays the design cost on simple cases before the z3/llvm migration cost.

## 5. Test cases (to write)

- enumeration prints the concrete version per artifact (`channel@id`).
- cross-artifact version *mismatch* representable + source-primary prunes
  (extends the existing `enumerate.version_axis` layer test).
- (later) cache key distinguishes two versions of the same artifact.
- (later) `source_repo` round-trips through the typed `version`.

## 6. Open design questions

- Does `channel` stay a **separate axis** (`Dev | Stable`, what the
  enumeration ranges over) with the concrete id resolved per project, or
  does the enumeration range over full `{channel; id}` versions directly?
- `version_tag` (PM pin) vs artifact version — reconcile (**package
  version ≠ artifact version**, ssot §4.2.2).
- Where does a project **declare its concrete version list** for the
  enumeration to range over — `source_repo`, or a dedicated field on the
  project spec?
