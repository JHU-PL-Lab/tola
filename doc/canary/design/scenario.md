# Scenario naming & classification

**Kind: reference.** The naming scheme. Four senses of "scenario", fixed so the other docs can use them without re-defining.

> 2026-08-10. Replaces `scenario_terms.md` (retired). Canonical naming scheme,
> shared expected-outcome reference, and contract catalogue.

## The four senses

| Sense                              | Term             | Definition                                                                | Example                                                                                    |
| ---------------------------------- | ---------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| 1. Concrete runnable configuration | **scenario**     | An action chain + version coordinates, produced by the enumeration engine | `fetch_lib → probe_lib` with `{lib@F@Stable}`                                              |
| 2. Abstract action shape           | **pattern**      | A named collection of actions (Sc.N id), stable manuscript identifier     | `Sc.2.OCaml` = "build OCaml binding"                                                       |
| 3. Lifecycle stage                 | **stage**        | A single action in the coverage matrix                                    | `build_lib`, `fetch_binding`                                                               |
| 4. Structural path                 | **path pattern** | Universal action chain from the path table (`canary paths`)               | `fetch_source → build_lib → build_binding`                                                 |

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

| Component | Meaning | Example |
|---|---|---|
| `primary-stage` | First `belongs_to` entry — the pattern's entry point | `Sc.1`, `Sc.2.OCaml` |
| `terminal-action` | Last action in the chain | `build_lib`, `probe_app` |
| `dep-artifacts` | Artifacts the terminal action depends on, with provisions | `lib_local`, `lib_local_binding_local` |
| `fault` | Concise tag for the violated contract | `sym_missing`, `api_drop` |
| `artifact` | Which artifact the fault targets (short name) | `src`, `lib`, `binding` |

### Dep ordering

- **build actions** (build_lib, build_binding, build_app): direct dependency first,
  transitive later. E.g., `build_app` → `binding_local_lib_local` (binding is the
  direct compile dep, lib is transitive through binding).
- **probe actions** (probe_app): runtime dependency first. E.g., `probe_app` →
  `lib_local_binding_local` (lib is the runtime dep, binding is link-time).

### Short names

| Full name | Short | Why |
|---|---|---|
| `source` | `src` | Clear from context |
| `lib` | `lib` | Already short |
| `ocaml_binding`, `python_binding` | `binding` | Language implicit from stage |
| Vendored | `local` | Uniform term |
| Fetched (PM) | `sys-pm` | System package manager |
| Built | `built` | Compiled by canary |

### Fault tags (contract ↔ fault)

| Contract | Fault tag | What it detects |
|---|---|---|
| c1 | `sym_missing` | Symbol present in binding, absent from lib |
| c2 | `api_drop` | API surface entry dropped (mli val, Python attr) |
| c3 | `behavior` | Probe output mismatch (runtime behavior) |
| c4 | `abi_soname` | SONAME bump breaks dynamic link |
| c5 | `sym_version` | Versioned symbol floor mismatch |
| c6 | `type_arity` | Header type/arity mismatch |
| c7 | `api_repack` | Repackaging breaks API (intra-binding) |
| c8 | `api_add` | API addition not propagated to binding (dormant) |

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

| Pattern | Provisions | Chain |
|---|---|---|
| Fetch chain | All Fetched | `Fetch S → Fetch L → Fetch B → Probe` |
| Build chain (follows) | Source Fetched, Lib+Bind Built | `Fetch S → Build L → Build B → Probe` |
| Build chain (independent) | Lib Built, Bind Fetched | `Build L → Fetch B → Probe` |
| Mixed provision | Lib Fetched, Bind Built | `Fetch L → Build B → Probe` |
| No-source build | Lib Built, no source declared | `Build L → Fetch B → Probe` |
| Deploy mismatch | Bind Fetched over different-version Lib | Same chain, lib@Dev vs binding@Stable |

The `scenario_pattern` type in `canary_enumerate.ml` encodes these.

### By outcome (good vs bad)

- **Good** — all artifacts have `quality = Good`. Positive test, expected behavior.
- **Bad** — at least one artifact has `quality = Bad tag`. Injected fault.

Bad scenarios come in two flavors:

| | Flavor 1: defect IN one artifact | Flavor 2: mismatch BETWEEN artifacts |
|---|---|---|
| Locus | Single artifact missing/adding a field | Two well-formed artifacts that don't fit |
| Engine | Mutation axis (quality = Bad tag) | Deploy-mismatch (run-lib ≠ build-lib) |
| Implementation | tiny1's 20 bad scenarios | Machinery built, not yet wired to live run |
| Canonical name | `<good-name>.<fault>_on_<artifact>` | `<good-name>.deploy_mismatch_on_<consumer>` |

## Contract catalogue (c1..c8)

| Contract | Fault tag | What it checks |
|---|---|---|
| c1 | `sym_missing` | C symbols exported by lib vs expected by binding |
| c2 | `api_drop` | API surface entries (mli vals, Python attrs) present |
| c3 | `behavior` | Probe output matches expected |
| c4 | `abi_soname` | Shared library version name matches |
| c5 | `sym_version` | `@@GLIBC_2.31` annotations |
| c6 | `type_arity` | C type compatibility |
| c7 | `api_repack` | Repackaging preserves API |
| c8 | `api_add` | Repackaging is complete (dormant, blocked on c6+c7) |

## Stage coverage (`canary stages`)

Lifecycle stages from the action catalogue. Per-project marks:

- **Covered** (✓) — at least one scenario instantiates this stage
- **Unspecified** (-) — no scenario covers it
- **Disabled** (⊘) — config overrides

Currently driven by `canary_scenario_coverage.ml`. To be replumbed through
the enumeration engine (F5).
