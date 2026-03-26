# Movitation and Status

Working towards a principled derivation for all possible actions.
- Used a concrete job-step diagram, e.g. 4 for z3 [_out/canary/graph/z3_reference.mmd]
- It goes very large if we want to show combination of versions, that losing the point to use a diagram.

Now we have a single-source three-representation (diagram, table, runner). The diagram shows the action patterns but hide the versioned artifacts.

1. [_out/canary/graph/action_rule.mmd] shows actions
   - A unified aspect for artifact (source, lib, binding, app) that can be versioned, and a unified source to fetch and pack artifacts.
   - It shows core compination actions `build_lib`, `build_binding`, `build_app`, and their `packing` actions
   - We hide the combinations (after enough rounds of experiments).
2. [doc/canary/design.md] shows a job enumeration. The possible job (rather than 4 handcrafted). The maximum possible jobs can be generated and listed before the concrete project. Many one-step action is commom actions. Many two-step actions is common testing.
   - I was rooted by a idea that I shall design an optimized handcrafted jobs to cover the canary matrix. However, if any step e.g. building-from-source can be cached, I can just run all the job combinations and let the cache work. Now the question gets down to every action should have deterministic result.
3. runner, see logs [_out/canary/_local/sqlite] (from [canary_project_sqlite.ml] `action_steps`)
  - [X] working on a workflow function that given a project spec and the pre-generated action table, generate the job/actions add run it. Time-consuming building-from-the-source is configurable to bypass and cachable to only run once. 
  - [ ] Will try on LLVM and Torch immediately after sqlite and z3's example is finished.

Aside:
Enumerating possbible actions, or enumerating possible paths, or finding minimal-count paths to cover the graph are quite theoretical problems. When modeling the actions as a tree, e.g. `Build_app(Build_binding(Source, Fetch_lib), Fetch_lib)` where the first lib is for building binding, and the second lib is for building the app, term enumeration is very straightforward. When considering there are duplication is providing libs, tree enumeration beceoms DAG enumeration, `Build_app(Build_binding(Source, Lib*), Lib*)`, the problem immediately becomes tricky, as if compilation optimization. See [expression_sharing_note.md]

# Canary Work Log — March 2026

## Current Status (2026-03-19)

The canary system now has three aligned representations of the
action model, plus a working local runner:

1. **Pattern table** (14 structural patterns) — universal
   enumeration of all action paths, generated from `store_rules`
   by `pattern_rows_of_paths`. Sorted by artifact kind
   (lib → binding → app), then depth.

2. **Mermaid diagram** — generated from the same `store_rules`
   by `mermaid_of_action_rule_schema`. Shows 4 artifact pools
   (source, lib, binding, app), 4 stores, build/pack/probe
   action nodes, and fetch/publish transport edges.

3. **Action runner** — executes action steps with filesystem
   caching and plain-text logging. Steps are real shell commands.
   Steps are derived from `script_spec` + `store_rules` (not
   hand-written). SQLite and z3 projects both wired up.

### Key files

- `canary.ml` — core types, action rules, pattern table,
  diagram generation
- `canary_action.ml` — script_spec, derive_steps, runner,
  logging
- `canary_main.ml` — standalone CLI (`canary paths`, `canary
  graph`, `canary action`)
- `canary_project_sqlite.ml` — sqlite project: legacy config +
  new `action_steps`
- `canary_basic.ml` — `artifact_kind = Source | Lib | Binding |
  App`, `kind_order`, `project_spec`
- `canary_basic_store.ml` — `location`, `package_manager`
- `doc/canary/design.md` — design document with pattern table,
  execution model, store config design

### What works

- `canary paths` / `canary paths-md` — print 14-row pattern table
- `canary graph` — generate action_rule.mmd diagram
- `canary action sqlite` — run sqlite project locally with
  caching and logging
- `canary run` — legacy YAML/shell backend generation

### Done (this session)

- [x] `script_spec` type + `derive_steps` — action list derived
  from pattern table, no longer hand-written
- [x] sqlite project uses `script_spec` → working end-to-end
- [x] z3 project `script_spec` defined, wired to CLI
- [x] Removed SQLite DB — cache is purely `check_post` based
- [x] `canary_main.ml` CLI: `canary action [sqlite|z3]`

### TODO

Near-term (framework):

1. **`check_post` per artifact** — verify actual artifact
   existence (e.g., `libz3.dylib`, `z3.cma`), not just
   output_dir non-empty. Similar to `produces` in legacy
   `step_phase`. Can carry `expect_success` / `expect_failure`.
2. **z3 build scripts** — fix cmake in-tree builds to write
   markers to output_dir so caching works. Alternatively,
   `check_post` checks in-tree artifacts directly.
3. **Store indirection** — factor fetch/pack scripts into
   store templates parameterized by `pkg_name`. Project only
   provides build/probe scripts + store entries. See design.md
   "Store Config" section.

Near-term (projects):

1. **z3 end-to-end** — fix `opam install z3` (needs
   `--assume-depexts` or pre-install system deps). Test all
   8 derived steps.
2. **LLVM / Torch** — new projects using same `script_spec`
   pattern. Validates the framework generalizes.

Later:

1. **GH CI backend** — generate YAML with `needs:` deps and
   `upload/download-artifact` from the same action graph.
2. **Version combinations** — instantiate patterns with
   concrete versions (dev, stable) at the select step.
3. **`run_app` action** — add to diagram (noted in motivation).

---

## Editing History

### Session 1 (prior to 2026-03-18)

Work on design doc and core enumeration code. Established:

- `action_rule` model: `rule list` processed left-to-right,
  building artifact pools via `make_action_rule`
- `job_path` type with `node_depth`, `annotate_path`
- `job_paths_of_action_rule` — enumerate all artifact paths
- `pp_job_path_table` — display as table
- `mermaid_of_action_rule_schema` with hand-written
  `schema_of_rule` types
- Initial design.md sections: action rule → job derivation gap,
  store abstraction gap

### Session 2 (2026-03-18 to 2026-03-19)

Major refactoring and new implementation. Changes in order:

**Table redesign**
- Merged separate Artifacts/Probes tables into one unified table
- Added `action_path` column showing full action chain
- Made probes implicit (every artifact can be probed at d+1)
- Collapsed version instances into `versions` column →
  14 structural patterns instead of 56+ rows
- Sorted by artifact kind (lib → binding → app), then depth
- Added `canary_paths_md` CLI command for markdown output

**Diagram redesign**
- Deleted `schema_of_rule` and associated types (`rule_schema`,
  `pool_input`, `source_role`)
- Diagram now derives directly from `rule` type, same as
  `make_action_rule`
- `Fetch` made a uniform action (matching table's `fetch_*`)
- Fetch later changed to dotted edge labels (visually quiet)

**Source as artifact**
- Added `Source` to `artifact_kind`
- Added `source_store`, `fetch_source` to diagram and model
- `fetch_source` appears explicitly in all build chain
  action_paths (e.g., `fetch_source → build_lib`)
- Depths adjusted (+1 for leaf build nodes)

**Publish → Pack rename**
- `Publish` rule added to model
- Renamed action to `pack_<kind>` (the interesting work)
- `publish` becomes an edge label in the diagram (transport)
- Pack action nodes shown in diagram alongside build/probe

**Type cleanup**
- Removed `Executable`, `Dir`, `File` from `artifact_kind`
  (unused)
- Moved `kind_order` to `canary_basic.ml` next to type def
- Removed all wildcard match fallbacks (type now exhaustive)
- Unified naming: `<artifact>_store`, `<artifact>_node`,
  `<artifact>_pool` (derived from `string_of_artifact_kind`)
- Removed subgraph wrappers from diagram (single node per pool)
- Used `@{ shape: docs }` for multi-version artifact nodes

**Design doc updates**
- Execution model: graph-based with cached sharing, not
  independent job matrix
- Store config design (Option C): package format as
  instantiation dimension, not structural
- Action step protocol: check_pre, run (shell cmd), check_post
- Three-layer separation: store templates (fetch/pack) vs
  project commands (build/probe) vs project spec (capabilities)

**Action runner implementation**
- `canary_action.ml` — new module:
  - `action_step` type with `cmd` (shell command generator)
  - SQLite `action_run` table for caching
  - Plain-text `actions.log` (append-only)
  - `run_step` with pre/postcondition logging
  - `run_graph` — dependency-ordered execution
  - Convenience: `mk_step`, `has_file`, `run_project`
- `canary_main.ml` — standalone CLI with cmdliner subcommands
- `canary_project_sqlite.ml` — `action_steps` function with
  real shell commands (`brew install`, `opam install`,
  `ocamlfind ocamlopt`)
- Output at `_out/canary/_local/<project>/`
- Deploy excludes `_local` via rsync
- SQLite project passes end-to-end: fetch_lib, fetch_binding,
  probe_binding (compile + run example)
