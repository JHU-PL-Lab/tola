# Claude Code — Project Guide

## Build & Run

```sh
dune build                          # build everything
dune exec src/bin/canary_main.exe -- paths      # print 14-row action pattern table
dune exec src/bin/canary_main.exe -- paths-md   # same, markdown output
dune exec src/bin/canary_main.exe -- graph       # write _out/canary/action_rule.mmd
dune exec src/bin/canary_main.exe -- action sqlite
dune exec src/bin/canary_main.exe -- action z3       # runs z3 (dev) + z3/stable
dune exec src/bin/canary_main.exe -- action llvm     # runs llvm (dev) + llvm/19
make canary       # run canary via Makefile shorthand
```

Output lives under `_out/canary/_local/<project>/` (gitignored via `_*`).
`action llvm` writes to `_local/llvm/` (dev) and `_local/llvm/19/` (stable mismatch).
`action z3` writes to `_local/z3/` (dev) and `_local/z3/stable/` (stable mismatch).
Do NOT copy `_local/` to the z3 repo for GH CI.

## Active Work: Canary

Canary is a dependency-testing framework that enumerates all possible
build/probe actions for a C/OCaml project and runs them locally (with
plans for GH CI).

### Key source files

| File                                   | Purpose                                                           |
| -------------------------------------- | ----------------------------------------------------------------- |
| `src/canary/canary.ml`                 | Core types, action rules, 14-pattern table, diagram generation    |
| `src/canary/canary_action.ml`          | `script_spec`, `derive_steps`, runner, text log, shared templates |
| `src/bin/canary_main.ml`               | CLI entry point; `run_llvm` runs llvm+llvm/19, `run_z3` runs z3+z3/stable |
| `src/canary/canary_basic.ml`           | `artifact_kind`, `kind_order`, `project_spec`                     |
| `src/canary/canary_store.ml`           | `location`, `package_manager`, `source_repo`, `distro` types      |
| `src/canary/canary_ocaml.ml`           | OCaml toolchain types, opam packaging, probe generation           |
| `src/canary/canary_artifact_check.ml`  | Artifact existence checks, nm symbol inspection, check_post       |
| `src/canary/projects/canary_project_sqlite.ml` | sqlite3 project spec + `script_spec`                       |
| `src/canary/projects/canary_project_z3.ml`     | z3 project spec + `script_spec`; `z3_source_stable` has `has_build_binding=false` |
| `src/canary/projects/canary_project_llvm.ml`   | LLVM project spec + `script_spec`; `llvm_source_stable` has local path + `has_build_binding=false` |
| `src/canary/projects/canary_run.ml`            | Project orchestrator; runs llvm+llvm/19 and z3+z3/stable |
| `canary/examples/llvm/llvm_example.ml`         | LLVM 16+ example (create_context)                          |
| `canary/examples/llvm/llvm_example_dev.ml`     | LLVM 21+ example (Opcode.UncondBr); fails against llvm.19-shared |
| `canary/examples/llvm/llvm_example_19.ml`      | LLVM ≤20 example (Opcode.Br); fails against dev binding    |
| `canary/examples/llvm/llvm_example_15.ml`      | LLVM ≤15 example (global_context); fails against LLVM 16+  |
| `canary/templates/opam-local-repo/`            | Local opam packages: z3.dev, llvm.dev-shared, llvm.19-shared, llvm.19-static, conf-llvm-shared.dev/19 |
| `canary/scripts/assert_binary_symbols.py`      | nm-based symbol compat check                               |
| `doc/canary/design.md`                 | Design doc: pattern table, store config, execution model          |
| `doc/canary/install_target_survey.md`  | Z3 vs LLVM cmake install patterns; informs TODO #25               |
| `doc/canary/llvm_build_note.md`        | LLVM source build steps, smoke test, opam install notes           |
| `doc/canary/backlog.md`                | Lower-priority TODOs (#5, #9–#11, #13b, #14, #16–#18, #22)       |

### Architecture in one paragraph

`store_rules` in `canary.ml` defines the universal action graph (fetch,
build, probe, pack for each artifact kind: Source → Lib → Binding → App).
`pattern_rows_of_paths` enumerates 14 structural patterns with `action_path`
strings like `fetch_source → build_lib → build_binding`. A project provides
a `script_spec` (hardcoded shell commands per action). `derive_steps` filters
the 14 patterns by project capabilities and instantiates them with the
project's scripts. `run_graph` executes the steps in dependency order with
`check_pre`/`check_post` filesystem checks and appends to `actions.log`.
Each project runs two variants: dev (source build + pack_binding) and
stable (fetch_lib + fetch_binding only, no build) — the stable variant
probes with the dev example to demonstrate version mismatch detection.

### Multi-version probe design

`canary action llvm` runs two sequential sub-runs sharing one opam switch:

| Sub-run | Source | Lib | Binding | Example | Expected |
|---------|--------|-----|---------|---------|----------|
| `llvm` | dev (ninja) | dev libLLVM.so | `llvm.dev-shared` (packed) | `llvm_example_dev.ml` | pass |
| `llvm/19` | local path (no build) | `llvm-19-dev` (apt) | `llvm.19-shared` (opam) | `llvm_example_dev.ml` | **fail — Opcode.UncondBr unbound** |

`llvm_example_dev.ml` uses `Opcode.UncondBr` (added in LLVM 21, March 2026
commit #186176 — `br` split into `uncondbr+condbr`). Against `llvm.19-shared`
it fails to compile, demonstrating API mismatch. Sequential execution avoids
opam switch conflicts.

### Current TODO (numbers are stable like GH issues — never renumbered)

19. **LLVM cross-version symbol check** — probe_binding has symbol compat
    check. `llvm/19` probe_binding_pkg now demonstrates OCaml API mismatch
    (compile error). Remaining: also verify at the C symbol level with a
    mismatched libLLVM.so version pair.

20. **Symbol diff between lib versions** — extend `assert_binary_symbols.py`
    with `--provided-lib-old / --provided-lib-new` mode. Foundation for #16.

24. **Unified canary project spec** — naming and paths are scattered and
    inconsistent across projects. Everything should live in the project spec:
    - Local opam repo: `"local-z3-dev"` (z3) vs `"local-llvm"` (llvm) → `"local-canary"`
    - Env vars: `CANARY_BUILD_DIR` (z3) vs `CANARY_LLVM_BUILD` (llvm) → single convention
    - Build dir layout: z3 uses `<source>/build` (in-tree) vs llvm uses sibling `../build`
    - All configurable paths (source root, build dir, local repo path) should be
      derivable from the spec so `mk_script_spec` has no hardcoded locations.
    - `z3/stable` fetch_binding resolves to `z3.dev` (local repo rank 1 shadows
      upstream); need a real stable z3 opam version or deregister local repo
      for the stable probe to be meaningful.

25. **Model `cmake --install` as canary action slot** — `install_lib` /
    `install_binding` between `build_*` and `pack_binding`. See
    `doc/canary/install_target_survey.md` for Z3 vs LLVM patterns.

26. **Idempotent step execution** — canary cache (`_out/`) and external state
    (build tree, opam switch) are independent stores; deleting `_out/` causes
    all steps to re-run even when artifacts already exist. Fix: each step should
    check for existing artifacts before executing. Examples:
    - `configure`: `test -f <build>/CMakeCache.txt || cmake ...` (re-running cmake
      updates timestamps → ninja considers generated targets stale → partial rebuild)
    - `build_lib/binding`: `test -f <artifact> || ninja ...`
    - `fetch_binding/pack_binding`: `opam list pkg.version | grep -q installed || opam install ...`
    Same pkg+version = same content in opam, so pre-check is always safe.

Backlog (lower priority): #5, #9, #10, #11, #13b, #14, #16, #17, #18, #22.
Details in `doc/canary/backlog.md`.

### Done

Done: #1, #2, #3, #4, #6, #7, #8, #12, #13, #15, #21, #23. Details in
`doc/canary/worklog_2026_04.md`.

- **#23** — LLVM source build end-to-end via canary: `canary action llvm`
  runs all 11 steps (fetch_source, configure, build_lib, fetch_lib,
  build_binding, fetch_binding, pack_binding, probe_lib, probe_binding_build,
  probe_binding_pkg, probe_app). `llvm/19` sub-run demonstrates mismatch.

## Other Work: Yelu

Yelu lives under `yelu/` and has its own project guide. If you are working
on yelu or the cmake language layer, read `yelu/CLAUDE.md` and ignore the
rest of this file.

## Gotchas

- **OCaml LSP stale diagnostics**: Cross-module edits show false errors
  until dune rebuilds. ocamllsp reads compiled `.cmi` files; no
  in-memory cross-module resolution. Ignore during multi-file refactors,
  verify with `dune build` at the end.
- **`open Base` shadows stdlib**: `result`, `prefix`, `id`, `append`
  are shadowed — rename in pattern matches.
- **Mermaid v11+**: User's renderer supports `@{ shape: docs }` syntax.
  Safe to use modern Mermaid features in `.mmd` files.
- **`opam config subst`**: expects `foo.in` → `foo`. The template must
  be named `.in`; the command is relative to cwd, not absolute.
- **z3 git submodule leftover**: if z3 source has a `.git` file (not
  dir) pointing to `../../.git/modules/z3`, cmake fails with "could
  not find commondir". Fix: convert to standalone repo (`rm .git`,
  `git clone --bare ... .git`, `git config core.bare false`).
- **Build tree vs opam-installed binding conflict**: `-package z3 -I
  build/src/api/ml` causes "inconsistent assumptions" because
  ocamlfind loads the opam version while `-I` adds build tree `.cmi`
  files. For build tree probes, use `-package zarith` (dep only) +
  explicit `z3ml.cmxa`, not `-package z3`.
- **opam sandbox on WSL**: `wrap-build-commands` is empty by default
  on WSL (`opam option wrap-build-commands` = `[]`). On GH CI (Ubuntu),
  sandbox is active — `CANARY_BUILD_DIR` pointing outside the sandbox
  will be blocked. CI should use the default `build` fallback (no env var).
- **ELF symbol versioning in nm output**: Linux shared libs (e.g., LLVM)
  use versioned symbols — `nm -D` outputs `LLVMAddAlias2@@LLVM_19.1`
  not `LLVMAddAlias2`. `assert_binary_symbols.py` regex must allow
  `(?:@@?\S+)?$` suffix; a bare `\w+$` anchor silently matches nothing.
  Fix is in `parse_defined_symbols` in `canary/scripts/assert_binary_symbols.py`.
- **`find_llvm_config_cmd` composability**: it's a multi-line `if/elif/fi`
  shell expression. Cannot be safely nested inside `$()` as a sub-argument
  (e.g., `$(find_llvm_config_cmd --libdir)` is wrong). Always assign to a
  variable first: `LLVM_CONFIG=$(find_llvm_config_cmd)` then use `$LLVM_CONFIG`.
- **`$CAMLORIGIN/../..` breaks in opam flat layout**: LLVM's `llvm.cmxa`
  embeds `-L$CAMLORIGIN/../..` pointing to `libLLVM.so`. In the build tree
  (`build/lib/ocaml/llvm/`) this resolves to `build/lib/` ✓. After
  `ocamlfind install` to `lib/llvm/`, it resolves to the switch root ✗.
  Fix: append `linkopts = "-cclib -L<BUILD>/lib -cclib -Wl,-rpath,<BUILD>/lib"`
  to META. Proper fix (TODO #25): run `cmake --install` which regenerates cmxa.
- **`mktemp /tmp/...` blocked in opam sandbox**: opam's bwrap sandbox does
  not mount `/tmp`. Use `./name` (current dir = opam build dir) directly.
- **`build_z3_ocaml_bindings` is a cmake PHONY target**: `add_custom_target`
  in cmake always generates a PHONY ninja target — ninja never considers it
  up-to-date and always reruns it. Deleting the canary `_out/` cache causes
  canary to re-run `configure` (cmake), which updates `CMakeFiles/` timestamps,
  which triggers a full z3 rebuild (~863 steps). Fix: TODO #26 artifact
  pre-check (`test -f z3ml.cmxa || ninja ...`). LLVM's `LLVM` target builds
  a concrete file (libLLVM.so) so ninja correctly skips it.
- **META.llvm `directory = "llvm"`**: OCaml archives are in a `llvm/`
  subdirectory of the build tree. Set `OCAMLPATH` to the parent
  (`build/lib/ocaml/`), not `build/lib/ocaml/llvm/`. Strip `directory`
  field when doing flat opam install.

## Conventions

- `cc` = Claude Code (user shorthand)
- Allowed bash: `make *` and `dune *` only

## Handoff Workflow

This file is the serialization layer for cross-machine continuity.
Local memory and chat context are ephemeral; CLAUDE.md is the durable
snapshot any fresh session on any machine can reconstruct from.

**Before ending a session**, update this file with current state:

```
Update CLAUDE.md for handoff. Include these sections:
1. Build & Run — commands to build, test, run
2. Key Files — table of important files and their purpose
3. Architecture — one-paragraph summary of how things fit together
4. Current TODO — prioritized next steps
5. Gotchas — behavioral traps, things that wasted time, workarounds
   (include *why* for each)
6. Feedback — corrections or preferences I gave you during our sessions
   that should carry forward
7. Conventions — shorthand, naming patterns, style preferences
Check your memory files for gotchas and feedback material.
Commit the result.
```

**When starting on a new machine**, load context:

```
Read CLAUDE.md and familiarize yourself with the project. Save any
gotchas and feedback items to your local memory so they persist across
conversations on this machine.
```
