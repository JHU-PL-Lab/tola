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
| `src/canary/canary.ml` | Core types, action rules, 14-pattern table, diagram generation |
| `src/canary/canary_action.ml` | `script_spec`, `derive_steps`, runner, text log, shared templates |
| `src/bin/canary_main.ml` | CLI entry point (`canary_main.exe`) |
| `src/canary/canary_basic.ml` | `artifact_kind`, `kind_order`, `project_spec` |
| `src/canary/canary_basic_store.ml` | `location`, `package_manager`, `source_repo`, `distro` types |
| `src/canary/canary_project_sqlite.ml` | sqlite3 project spec + `script_spec` |
| `src/canary/canary_project_z3.ml` | z3 project spec + `script_spec` |
| `src/canary/canary_project_llvm.ml` | LLVM project spec + `script_spec` (prebuilt only) |
| `src/canary/canary_basic_apt.ml` | apt install/verify/query commands |
| `src/canary/canary_basic_brew.ml` | brew install/verify/query commands |
| `src/canary/canary_basic_opam.ml` | opam install/verify/query/switch commands |
| `doc/canary/design.md` | Design doc: pattern table, store config, execution model |
| `doc/canary/conf_package_analysis.md` | conf-* package complexity analysis (94% eliminable) |
| `doc/canary/worklog_2026_03.md` | Session-by-session work log + TODO list |
| `canary/scripts/test_pm_primitives.sh` | Test apt/brew/opam primitive commands |
| `canary/scripts/test_llvm_versions.sh` | LLVM version resolution: diagnose, switch, test-seams |

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

1. ~~**Fix z3 `fetch_binding`**~~ — done: `--assume-depexts` added via
   `pm_install_cmd` in `canary_basic_store.ml`.

2. ~~**Fix z3 `build_lib` check_post**~~ — done: `check_post` override
   added to `script_spec`; `source_check_post` reads `source.ok` and
   verifies the path still exists.

3. ~~**`check_post` per artifact**~~ — done: marker file system in place
   for all rule categories (see design.md "Default postcondition markers"
   table). z3 `Build_lib` and `Build_binding` now also check real artifact
   existence (`libz3.so`, `z3ml.cmxa`) to catch stale-marker/deleted-build
   cache misses. Remaining: sqlite/llvm have no build steps so no further
   real artifact checks needed.

4. ~~**Store indirection**~~ — largely done: `pm_install_cmd` handles
   system PMs; `source_repo` type models git sources with per-distro
   locals and clone-on-demand; `mk_locals` + `distro_base` factor out
   paths. Remaining: factor pack commands into store templates.

5. **CI mode for opam depexts** — use `--confirm-level=unsafe-yes` to let
   opam auto-install system deps in Docker/CI. Currently local dev uses
   `--assume-depexts` (requires pre-installing system deps manually).

6. ~~**LLVM**~~ — done: `canary_project_llvm.ml` wired up with prebuilt
   system + opam binding + llvmlite python. Torch remains if needed.

7. **z3 stable source** — `z3_source_stable` (4.15.2, bd3e722) is defined
   and `action_steps` accepts `~source`, but no CLI flag to select it yet.
   Wire up e.g. `action z3-stable` or `--source stable`.

8. **cmake configure as a separate action** — currently `build_lib`
   bundles cmake configure + ninja build. Should be its own action step
   with pre (source exists), cmd (`cmake -B build ...`), post
   (`build/build.ninja` exists). `build_lib` and `build_binding` would
   depend on it instead of re-running configure each time.

9. **Binding build dependencies** — z3's OCaml binding requires `zarith`
   at build time. Currently not tracked in `ocaml_binding` or
   `script_spec`. Need to model per-binding opam deps so `build_binding`
   can ensure they're installed (or fail clearly). If canary gets
   first-class language-binding support, this becomes a dependency edge
   in the action graph; otherwise, add a `binding_deps` field to
   `ocaml_tool_config`.

10. **Unified build cache schema** — currently two independent caches:
    canary's `_out/canary/_local/` (filesystem check_post) and opam's
    `~/.opam/.../build/` (opam-managed). For version combination testing,
    both layers need a shared cache key scheme (project × version × ref).
    Explore specifying opam build dir and reusing canary's build artifacts
    to avoid rebuilding libz3 twice.

11. **tqdm-style progress display** — redirect verbose build output
   (cmake/ninja) to a log file, show a `\r`-overwriting single-line
   status on tty. Canary's `run_cmd_logged` already has the logging
   layer; split tty output from file output.

12. **Multiple probes per artifact kind** — `probe_binding` needs two
    variants: one against the build tree (`-I api_path`, no `-package z3`)
    and one against the opam-installed package (`-package z3`, no `-I`).
    Currently hacked as a two-command sequence in one step. The framework
    should support multiple probes per kind, each with different deps
    (build_binding vs pack_binding). Probes are derived from artifacts,
    not enumerated — this is a design question for the pattern table.

13. ~~**Dump project spec / canary config**~~ — done: `run_info.json`
    dumped at start of each action run with project, version, ref,
    source, distro, system PM, opam switch, OCaml version, timestamp,
    actions, and project-specific extras.

13b. **Driver mode: read `run_info.json` to configure a run** — allow
    `canary action --from run_info.json` to replay or reconfigure a
    run from a previously dumped spec. This enables: (a) reproducing
    a specific test configuration on another machine, (b) editing the
    JSON to test a different version/source without changing code,
    (c) CI generating the JSON and canary executing it.

14. **z3 cmake `Z3_BUILD_LIBZ3_CORE=OFF` bug** — when set, cmake ignores
    `Z3_ROOT`, `Z3_BUILD_OCAML_BINDINGS`, and other flags. The
    "use external libz3" code path doesn't wire up binding options.
    Workaround: always build libz3 from source in the opam template.
    See `doc/z3_bug_api.md`.

15. **PM primitive testing** — `canary_basic_apt.ml`, `canary_basic_brew.ml`,
    `canary_basic_opam.ml` now have query/verify/check_available commands
    (version query, availability check, depext listing). Next: wire these
    into canary actions so PM readiness can be tested independently before
    project-level actions (e.g., "is llvm-19-dev available and installed?
    is the opam switch ready?"). Currently the commands are hardcoded
    strings — they are version-dependent on the PM tools themselves
    (dpkg, opam, brew CLI may change). Track this as a known fragility.

16. **Mismatch prediction system** *(Opus suggested)* — given two versions
    of artifacts in a dependency chain, predict what breaks and how.
    Currently `Expect_failure` and `Expect_symbols` are hand-written per
    test case. A prediction system would derive expected failures from
    version metadata: e.g., "z3 4.15 binding linked against z3 4.13 lib →
    missing symbols X, Y, Z" should be computable from API diffs.
    This is the core canary research contribution — testing the seams
    between versions across the resolution chain.

17. **Module interfaces (.mli)** — add `.mli` files to define contracts
    for PM modules and project modules. PM modules (`canary_basic_apt`,
    `canary_basic_brew`, `canary_basic_opam`) should all implement:
    `install_cmd`, `verify_installed_cmd`, `query_version_cmd`,
    `check_available_cmd`. Project modules (`canary_project_*.ml`)
    should all provide: `script_spec`, `action_steps`, `run_info`,
    `config`. This makes it clear what a new PM or project needs to
    implement and prevents accidental use of internal functions.

## Other Work: Yelu

Yelu is a programmable config/shell language that compiles to cmake
(and future targets). The cmake tutorial steps serve as test cases.

### Key source files

| File | Purpose |
|------|---------|
| `src/langs/cmake/lang_cmake.ml` | CMake AST |
| `src/langs/cmake/lang_cmake_pp.ml` | CMake pretty printer |
| `src/langs/cmake/lang_cmake_utils.ml` | CMake AST utilities |
| `src/langs/yelu/lang_yelu.ml` | Yelu AST |
| `src/langs/yelu/lang_yelu_compile.ml` | Yelu → CMake compiler |
| `src/langs/yelu/lang_yelu_utils.ml` | Yelu AST utilities |
| `src/bin/yelu/` | Step files (step1.ml–step12.ml) |
| `doc/yelu/design_chat_2026_03_26.md` | Design notes: namespace-as-type, program equivalence |

### Build commands

```sh
dune build src/langs/ src/bin/cmake/   # cmake only
dune build src/langs/ src/bin/yelu/    # yelu only
```

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
  on WSL. On GH CI (Ubuntu), sandbox is active — `CANARY_BUILD_DIR`
  pointing outside the sandbox will be blocked. CI should use the
  default `build` fallback (no env var).

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
