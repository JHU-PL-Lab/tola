# Claude Code — Project Guide

## Build & Run

```sh
dune build                          # build everything
dune exec src/bin/canary_main.exe -- paths      # print 14-row action pattern table
dune exec src/bin/canary_main.exe -- paths-md   # same, markdown output
dune exec src/bin/canary_main.exe -- graph       # write _out/canary/action_rule.mmd
dune exec src/bin/canary_main.exe -- action sqlite
dune exec src/bin/canary_main.exe -- action z3
make canary       # run canary via Makefile shorthand
```

Output lives under `_out/canary/_local/<project>/` (gitignored via `_*`).
Do NOT copy `_local/` to the z3 repo for GH CI.

## Active Work: Canary

Canary is a dependency-testing framework that enumerates all possible
build/probe actions for a C/OCaml project and runs them locally (with
plans for GH CI).

### Key source files

| File | Purpose |
|------|---------|
| `src/bin/canary.ml` | Core types, action rules, 14-pattern table, diagram generation |
| `src/bin/canary_action.ml` | `script_spec`, `derive_steps`, runner, text log |
| `src/bin/canary_main.ml` | CLI entry point (`canary_main.exe`) |
| `src/bin/canary_basic.ml` | `artifact_kind`, `kind_order`, `project_spec` |
| `src/bin/canary_basic_store.ml` | `location`, `package_manager` types |
| `src/bin/canary_project_sqlite.ml` | sqlite3 project spec + `script_spec` |
| `src/bin/canary_project_z3.ml` | z3 project spec + `script_spec` |
| `doc/canary/design.md` | Design doc: pattern table, store config, execution model |
| `doc/canary/worklog_2026_03.md` | Session-by-session work log + TODO list |

### Architecture in one paragraph

`store_rules` in `canary.ml` defines the universal action graph (fetch,
build, probe, pack for each artifact kind: Source → Lib → Binding → App).
`pattern_rows_of_paths` enumerates 14 structural patterns with `action_path`
strings like `fetch_source → build_lib → build_binding`. A project provides
a `script_spec` (hardcoded shell commands per action). `derive_steps` filters
the 14 patterns by project capabilities and instantiates them with the
project's scripts. `run_graph` executes the steps in dependency order with
`check_pre`/`check_post` filesystem checks and appends to `actions.log`.
`mermaid_of_action_rule_schema` generates both reference and result diagrams;
the result diagram colors edges via `linkStyle N stroke:...` by action status.

### Current TODO (pick one to start)

1. **Fix z3 `fetch_binding`** — `opam install z3` exits 10 (interactive
   prompt for system deps). Fix: add `--assume-depexts` to the opam command
   in `canary_project_z3.ml`.

2. **Fix z3 `build_lib` check_post** — cmake builds in-tree at
   `/Users/ex/code/repos/z3/build/`, not in `output_dir`. Current workaround
   is an empty-dir marker. Proper fix: check `libz3.dylib` exists in the z3
   source tree directly.

3. **`check_post` per artifact** — replace empty-dir checks with real artifact
   existence checks (`.dylib`, `.cma`, etc.) keyed per action kind.

4. **Store indirection** — factor fetch/pack shell commands into store
   templates parameterized by `pkg_name`, so project specs only need to
   name the store + package, not write the full command. Design sketched in
   `doc/canary/design.md` "Store Config" section.

5. **LLVM / Torch** — next projects to wire up using the same `script_spec`
   pattern, validating the framework generalizes.

## Conventions

- `cc` = Claude Code (user shorthand)
- Allowed bash: `make *` and `dune *` only
- OCaml LSP shows stale cross-module errors until `dune build` — ignore
  during multi-file edits, verify at the end
