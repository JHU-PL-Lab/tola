# Vocabulary — scenario naming & classification

**Kind: reference.** Not a pass: the words every pass reuses. Four senses
of "scenario", the canonical name structure, the fault tags, the c1..c8
catalogue. The pipeline map is [`README.md`](README.md).

> 2026-08-10. Replaces `scenario_terms.md` (retired). Canonical naming scheme,
> shared expected-outcome reference, and contract catalogue.

## The four senses

| Sense                              | Term             | Definition                                                                | Example                                       |
| ---------------------------------- | ---------------- | ------------------------------------------------------------------------- | --------------------------------------------- |
| 1. Concrete runnable configuration | **scenario**     | An action chain + version coordinates, produced by the enumeration engine | `fetch_lib → probe_lib` with `{lib@F@Stable}` |
| 2. Abstract action shape           | **pattern**      | A named collection of actions (Sc.N id), stable manuscript identifier     | `Sc.2.OCaml` = "build OCaml binding"          |
| 3. Lifecycle stage                 | **stage**        | A single action in the coverage matrix                                    | `build_lib`, `fetch_binding`                  |
| 4. Structural path                 | **path pattern** | Universal action chain from the path table (`canary paths`)               | `fetch_source → build_lib → build_binding`    |

**Sense 1** is the primary one — `Canary_project_run.run_project_spec` produces scenarios.
**Sense 2** lives in `canary_scenario.ml` — the `good_scenarios` catalogue.
**Sense 3** is displayed by `canary stages`. **Sense 4** is the `canary paths` command
(18 universal chains from the action catalogue).

## Canonical scenario naming

> Tentative scheme. `canary tiny scenario` prints the current table.
> Functions: `canonical_name_of`, `canonical_names_disambiguated` in `canary_tiny_scenario.ml`.

### Name structure

```
Good:  Sc.<primary-stage>.<terminal-action>_on_<dep-artifacts>
Bad:   Sc.<primary-stage>.<terminal-action>_on_<dep-artifacts>.<fault>_on_<artifact>
```

| Component         | Meaning                                                   | Example                                |
| ----------------- | --------------------------------------------------------- | -------------------------------------- |
| `primary-stage`   | First `belongs_to` entry — the pattern's entry point      | `Sc.1`, `Sc.2.OCaml`                   |
| `terminal-action` | Last action in the chain                                  | `build_lib`, `probe_app`               |
| `dep-artifacts`   | Artifacts the terminal action depends on, with provisions | `lib_local`, `lib_local_binding_local` |
| `fault`           | Concise tag for the violated contract                     | `sym_missing`, `api_drop`              |
| `artifact`        | Which artifact the fault targets (short name)             | `src`, `lib`, `binding`                |

### Dep ordering

- **build actions** (build_lib, build_binding, build_app): direct dependency first,
  transitive later. E.g., `build_app` → `binding_local_lib_local` (binding is the
  direct compile dep, lib is transitive through binding).
- **probe actions** (probe_app): runtime dependency first. E.g., `probe_app` →
  `lib_local_binding_local` (lib is the runtime dep, binding is link-time).

### Short names

| Full name                         | Short     | Why                          |
| --------------------------------- | --------- | ---------------------------- |
| `source`                          | `src`     | Clear from context           |
| `lib`                             | `lib`     | Already short                |
| `ocaml_binding`, `python_binding` | `binding` | Language implicit from stage |
| Vendored                          | `local`   | Uniform term                 |
| Fetched (PM)                      | `sys-pm`  | System package manager       |
| Built                             | `built`   | Compiled by canary           |

### Fault tags (contract ↔ fault)

| Contract | Fault tag     | What it detects                                  |
| -------- | ------------- | ------------------------------------------------ |
| c1       | `sym_missing` | Symbol present in binding, absent from lib       |
| c2       | `api_drop`    | API surface entry dropped (mli val, Python attr) |
| c3       | `behavior`    | Probe output mismatch (runtime behavior)         |
| c4       | `abi_soname`  | SONAME bump breaks dynamic link                  |
| c5       | `sym_version` | Versioned symbol floor mismatch                  |
| c6       | `type_arity`  | Header type/arity mismatch                       |
| c7       | `api_repack`  | Repackaging breaks API (intra-binding)           |
| c8       | `api_add`     | API addition not propagated to binding (dormant) |

### Example names

```
Sc.1.build_lib_on_src_local                          (good: build native lib)
Sc.1.build_lib_on_src_local.sym_missing_on_src       (bad:  symbol missing)
Sc.2.OCaml.build_binding_on_lib_local                 (good: build OCaml binding)
Sc.2.OCaml.build_binding_on_lib_local.api_drop_on_binding  (bad: API completeness)
Sc.3.OCaml.probe_app_on_lib_local_binding_local       (good: OCaml app probe)
```

### Commands

```
canary tiny scenario       # canonical name table (all 22, tentative)
canary tiny expected-all   # expected outcomes with canary step tags
canary action tiny1/<name> # run one scenario through general pipeline
```

## Shared expected-outcome reference

`Canary_tiny_scenario.canary_expected_of` maps a scenario spec to
`{ ce_must_xfail : string list; ce_must_pass : string list }` — canary step
tags that must confirm failure (xfail) or succeed. Both the oracle
(`expectation_of_entry`) and the agnostic post-run comparison consume this.

The mapping from tiny1 recipe step names to canary step tags is the
`canary_tag_of_recipe_step` table in `canary_tiny_scenario.ml`.

## Scenario classification

### By provision (action chain shape)

A scenario's chain is determined by which provisions fire:

| Pattern                   | Provisions                              | Chain                                 |
| ------------------------- | --------------------------------------- | ------------------------------------- |
| Fetch chain               | All Fetched                             | `Fetch S → Fetch L → Fetch B → Probe` |
| Build chain (follows)     | Source Fetched, Lib+Bind Built          | `Fetch S → Build L → Build B → Probe` |
| Build chain (independent) | Lib Built, Bind Fetched                 | `Build L → Fetch B → Probe`           |
| Mixed provision           | Lib Fetched, Bind Built                 | `Fetch L → Build B → Probe`           |
| No-source build           | Lib Built, no source declared           | `Build L → Fetch B → Probe`           |
| Deploy mismatch           | Bind Fetched over different-version Lib | Same chain, lib@Dev vs binding@Stable |

The `scenario_pattern` type in `canary_enumerate.ml` encodes these.

### By outcome (good vs bad)

- **Good** — all artifacts have `quality = Good`. Positive test, expected behavior.
- **Bad** — at least one artifact has `quality = Bad tag`. Injected fault.

Bad scenarios come in two flavors:

|                | Flavor 1: defect IN one artifact       | Flavor 2: mismatch BETWEEN artifacts        |
| -------------- | -------------------------------------- | ------------------------------------------- |
| Locus          | Single artifact missing/adding a field | Two well-formed artifacts that don't fit    |
| Engine         | Mutation axis (quality = Bad tag)      | Deploy-mismatch (run-lib ≠ build-lib)       |
| Implementation | tiny1's 20 bad scenarios               | Machinery built, not yet wired to live run  |
| Canonical name | `<good-name>.<fault>_on_<artifact>`    | `<good-name>.deploy_mismatch_on_<consumer>` |

## Contract catalogue (c1..c8)

| Contract | Fault tag     | What it checks                                       |
| -------- | ------------- | ---------------------------------------------------- |
| c1       | `sym_missing` | C symbols exported by lib vs expected by binding     |
| c2       | `api_drop`    | API surface entries (mli vals, Python attrs) present |
| c3       | `behavior`    | Probe output matches expected                        |
| c4       | `abi_soname`  | Shared library version name matches                  |
| c5       | `sym_version` | `@@GLIBC_2.31` annotations                           |
| c6       | `type_arity`  | C type compatibility                                 |
| c7       | `api_repack`  | Repackaging preserves API                            |
| c8       | `api_add`     | Repackaging is complete (dormant, blocked on c6+c7)  |

## Stage coverage (`canary stages`)

Lifecycle stages from the action catalogue. Per-project marks:

- **Covered** (✓) — at least one scenario instantiates this stage
- **Unspecified** (-) — no scenario covers it
- **Disabled** (⊘) — config overrides

Currently driven by `canary_scenario_coverage.ml`. To be replumbed through
the enumeration engine (F5).

## Term ↔ code

*Moved here 2026-08-27 from the retired `design/ssot.md` §6.1, which
the source cites in eight places. It is the vocabulary map, so it
belongs with the rest of the vocabulary.*

Canonical name-to-code map. If a term isn't in this table, add a
row before using it in code or writeup. Term names are shared with
the writeup — no need for a separate alignment section.

| Level        | Term                       | Meaning                                                                                                                                                         | Code                                                                                                                                                                             |
| ------------ | -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Top**      | **project**                | System under test + coverage config bundle. Owns scenarios + contract bindings.                                                                                 | `Canary_project_run.project_run` (`projects/`) — A6 2026-08-05: the never-read `Canary_project.project` bundle was deleted; z3/llvm's identity stays their variant list until A5 |
| Middle       | **scenario** ≡ **variant** | One runnable configuration. Named collection of actions + interested artifacts. `Sc.N` (pattern) / `Bs.N` (mutation instance) / dev, stable (llvm/z3 variants). | `Canary_scenario.scenario`                                                                                                                                                       |
| Below-middle | **runner_spec**            | Runner-facing handoff for one scenario/variant: `expectation` closure + build/probe/inspect commands. One per scenario.                                         | `Canary_step_builder.runner_spec`                                                                                                                                                |
| Below-middle | **action_graph**           | Actions-plus-pools schema (declared actions + the artifact-node pools produced by applying them).                                                               | `Canary_action.action_graph`                                                                                                                                                     |
| Low          | **step**                   | Concrete instantiation of an action: cmdline + env + expectation. Runtime unit consumed by the four backends.                                                   | `Canary_step_model.step`                                                                                                                                                         |
| Low (legacy) | **step_body**              | Shell-command record used by the retired YAML backend + `canary_toolchain`'s `verify_*_step` helpers (zero live consumers). Kept as placeholder.                | `Canary_basic.step_body`                                                                                                                                                         |
| Action verb  | **action**                 | Operational verb (`Build_lib`, `Probe_binding L`, …). See §6.5 for the catalogue.                                                                               | `Canary_basic.action`                                                                                                                                                            |

...
| Attribute of action   | **stage**                  | Pipeline phase (Upstream / Binding-creation / Downstream-use). Matches writeup "Stage for …" headings.                                                          | (doc-only)                           |
| Attribute of artifact | **artifact_status**        | Lifecycle state (`Built \| Installed_state \| Packed \| Fetched`). Complement to `location`. (Dormant; its `Installed` was renamed `Installed_state` 2026-08-18 to free the name for the *provision*, which is the live axis.) | `Canary_store.artifact_status`       |
| Theory                | **rule**                   | *What an action is for* — operational semantics / invariants. Doc-only concept; no code counterpart.                                                            | —                                    |

**Same-word-different-level pitfalls.**

- **project** (top) vs the historical **project_spec** (renamed to
  **runner_spec** 2026-07-21). One `project` produces many
  `runner_spec`s — one per scenario/variant.
- **scenario** ≡ **variant** ≡ **world** — same taxonomy position; tiny calls
  them scenarios (22 concrete), z3/llvm historically called them variants (2-3
  each), and the 2026-08-05 enumeration printing briefly said "world" (one
  enumerated flat assignment). **Unified 2026-08-05: the display term is
  `scenario`, everywhere** (`spec`/`status`/`action` output). "variant"
  survives only in code identifiers (`variant_id`/`variant_key`/
  `variant_file` — a scenario's cache/filename key) and `print_spec_variants`
  internals; renaming those is a queued mechanical sweep (status §E), not a
  display concern.
  `Canary_run_info.run_project_multi` consumes both under the same
  `variants` list.
- **action** (verb, code) vs **rule** (theory, doc-only) — freed by
  the 2026-07-21 rename. Pre-rename, `rule` was overloaded.
- **stage** (pipeline phase, doc-only) vs **artifact_status**
  (lifecycle state, code) — pre-rename, `stage` was overloaded.
- **step** (runtime, `Canary_step_model`) vs **step_body** (legacy
  shell carrier, `Canary_basic`) — kept apart post-rename.

**Ownership.** Project owns scenarios semantically (each is tied to
what it exercises), and no project bundle holds a `scenarios` field —
each project's module keeps concrete ownership. (The
`Canary_project.project` bundle this used to cite was never read by
anything and was deleted 2026-08-05, A6;
[`Canary_project_run.project_run`](../../../../src/canary/project/canary_project_run.ml)
is the project identity now.)

**Pattern vs instance.** `Sc.1..Sc.6` patterns live project-agnostic
in `Canary_scenario.good_scenarios`. Concrete scenarios (`Bs.N`,
project variants) live under their owning project's module.

Rename chronicle 2026-07-21 (`project_spec → runner_spec`,
`rule → action`, `action_rule → action_graph`, `action_step → step`,
`step → step_body`, `stage → artifact_status`) captured in
[`worklog_2026_07.md`](../../worklog/worklog_2026_07.md).

