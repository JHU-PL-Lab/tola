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

| File                                   | Purpose                                                           |
| -------------------------------------- | ----------------------------------------------------------------- |
| `src/canary/canary.ml`                 | Core types, action rules, 14-pattern table, diagram generation    |
| `src/canary/canary_action.ml`          | `script_spec`, `derive_steps`, runner, text log, shared templates |
| `src/bin/canary_main.ml`               | CLI entry point (`canary_main.exe`)                               |
| `src/canary/canary_basic.ml`           | `artifact_kind`, `kind_order`, `project_spec`                     |
| `src/canary/canary_store.ml`           | `location`, `package_manager`, `source_repo`, `distro` types      |
| `src/canary/canary_ocaml.ml`           | OCaml toolchain types, opam packaging, probe generation           |
| `src/canary/canary_pm_apt.ml`          | apt install/verify/query commands                                 |
| `src/canary/canary_pm_brew.ml`         | brew install/verify/query commands                                |
| `src/canary/canary_pm_opam.ml`         | opam install/verify/query/switch commands                         |
| `src/canary/canary_artifact_check.ml`  | Artifact existence checks, nm symbol inspection, check_post       |
| `src/canary/projects/canary_project_sqlite.ml` | sqlite3 project spec + `script_spec`                       |
| `src/canary/projects/canary_project_z3.ml`     | z3 project spec + `script_spec`                            |
| `src/canary/projects/canary_project_llvm.ml`   | LLVM project spec + `script_spec`                          |
| `src/canary/projects/canary_run.ml`            | Project orchestrator, config list, action runner           |
| `doc/canary/design.md`                 | Design doc: pattern table, store config, execution model          |
| `doc/canary/conf_package_analysis.md`  | conf-* package complexity analysis (94% eliminable)               |
| `doc/canary/worklog_2026_03.md`        | Session-by-session work log + TODO list                           |
| `canary/scripts/test_pm_primitives.sh` | Test apt/brew/opam primitive commands                             |
| `canary/scripts/test_llvm_versions.sh` | LLVM version resolution: diagnose, switch, test-seams             |

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

### Current TODO (numbers are stable like GH issues — never renumbered)

5. **CI mode for opam depexts** — use `--confirm-level=unsafe-yes` to let
   opam auto-install system deps in Docker/CI. Currently local dev uses
   `--assume-depexts` (requires pre-installing system deps manually).

7. ~~**z3 stable source**~~ — done: three version specs (dev/latest/stable)
   defined for z3 and llvm. `source_repo` has `has_build_lib` and
   `has_build_binding` flags. Probes resolve lib path dynamically
   (build tree or pkg-config). CLI flag deferred to #13b.

9. **Binding build dependencies** — z3's OCaml binding requires `zarith`
   at build time. Currently not tracked in `ocaml_binding` or
   `script_spec`. Need to model per-binding opam deps so `build_binding`
   can ensure they're installed (or fail clearly). Add a `binding_deps`
   field to `ocaml_tool_config`.

10. **Unified build cache schema** — currently two independent caches:
    canary's `_out/canary/_local/` (filesystem check_post) and opam's
    `~/.opam/.../build/` (opam-managed). For version combination testing,
    both layers need a shared cache key scheme (project × version × ref).

11. **tqdm-style progress display** — redirect verbose build output
    (cmake/ninja) to a log file, show a `\r`-overwriting single-line
    status on tty. Canary's `run_cmd_logged` already has the logging
    layer; split tty output from file output.

12. ~~**Multiple probes per artifact kind**~~ — done: `probe_binding`
    is now `(location * cmd) list`. Each entry keyed by `location`
    (`Build_tree`, `Lang_pm`, etc.) which determines tag and deps.
    Single entry = one step (`probe_binding`); multiple = expanded
    (`probe_binding_build`, `probe_binding_pkg`). z3 uses both;
    llvm/sqlite use single.

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
    `canary_basic_opam.ml` now have query/verify/check_available commands.
    Next: wire these into canary actions so PM readiness can be tested
    independently before project-level actions. Currently the commands are
    hardcoded strings — version-dependent on the PM tools themselves.

16. **Mismatch prediction system** *(Opus)* — given two versions of
    artifacts in a dependency chain, predict what breaks and how.
    A prediction system would derive expected failures from version
    metadata: e.g., "z3 4.15 binding linked against z3 4.13 lib →
    missing symbols X, Y, Z" should be computable from API diffs.
    This is the core canary research contribution. TODO #20 is the
    nm-based foundation.

17. **Module interfaces (.mli)** — add `.mli` files to define contracts
    for PM modules and project modules. PM modules (`canary_basic_apt`,
    `canary_basic_brew`, `canary_basic_opam`) should all implement:
    `install_cmd`, `verify_installed_cmd`, `query_version_cmd`,
    `check_available_cmd`. Project modules (`canary_project_*.ml`)
    should all provide: `script_spec`, `action_steps`, `run_info`,
    `config`. This makes it clear what a new PM or project needs to
    implement and prevents accidental use of internal functions.

18. **ocamlmklib stub archive convention** — `cmxa_stub_archive` in
    `canary_artifact_check.ml` derives the C stub path as `lib<name>.a`
    based on `ocamlmklib` naming. This is NOT universal — depends on how
    the binding was built. Factor into the OCaml toolchain layer (similar
    to how PM ops live in `canary_basic_opam.ml`): each project or binding
    spec should declare its stub archive path explicitly, with the
    `ocamlmklib` default as a fallback. Affects `probe_binding` symbol compat
    check for any future binding that doesn't follow the `lib<name>.a` pattern.

19. **LLVM cross-version symbol check (extended)** — probe_binding for
    llvm now has symbol compat check for dynamic case. Remaining: test
    with a mismatched version pair to confirm breakage detection.

20. **Symbol diff between lib versions** — `assert_binary_symbols.py`
    currently checks `binding_required ⊆ lib_provided` (matching version,
    expect missing=0). For the cross-version case, the useful query is:
    (a) `added = symbols(lib_v_new) − symbols(lib_v_old)` — API additions
    (b) `breaking = binding_required ∩ added` — what breaks if system has
    v_old but binding was built against v_new.
    Extend the script with `--provided-lib-old / --provided-lib-new` mode.
    Purely nm-based, no API metadata needed. Foundation for TODO #16.

21. **Source build capabilities** — `source_repo` now has `has_build_lib`
    and `has_build_binding` flags. Three source tiers per project:
    contributor dev (both true), official latest (both true), official
    stable (lib=false, binding=true). `mk_script_spec` conditionally
    includes configure/build_lib/build_binding based on these flags.
    Done for z3 and llvm. Remaining: wire CLI `--source dev|stable`,
    add official latest sources.

22. **Bundle check_post with action slots** — currently `script_spec` has
    action cmds (`build_lib`, `build_binding`, ...) and a separate
    `check_post : rule -> ...` dispatch that must be kept in sync. Refactor
    action slots from `cmd option` to `{ cmd; check } option` so each
    action carries its own check_post. Do after #12 (multiple probes)
    since that will also reshape the action slots.

### Done

Done: #1, #2, #3, #4, #6, #7, #8, #12, #13. Details in
`doc/canary/worklog_2026_04.md`.

## Other Work: Yelu

Yelu is a programmable config/shell language that compiles to cmake
(and future targets). The cmake tutorial steps serve as test cases.

### Key source files

| File                                  | Purpose                                              |
| ------------------------------------- | ---------------------------------------------------- |
| `src/langs/cmake/lang_cmake.ml`       | CMake AST                                            |
| `src/langs/cmake/lang_cmake_pp.ml`    | CMake pretty printer                                 |
| `src/langs/cmake/lang_cmake_utils.ml` | CMake AST utilities                                  |
| `src/langs/yelu/lang_yelu.ml`         | Yelu AST                                             |
| `src/langs/yelu/lang_yelu_compile.ml` | Yelu → CMake compiler                                |
| `src/langs/yelu/lang_yelu_utils.ml`   | Yelu AST utilities                                   |
| `src/bin/yelu/`                       | Step files (step1.ml–step12.ml)                      |
| `doc/yelu/design_chat_2026_03_26.md`  | Design notes: namespace-as-type, program equivalence |

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
- **ELF symbol versioning in nm output**: Linux shared libs (e.g., LLVM)
  use versioned symbols — `nm -D` outputs `LLVMAddAlias2@@LLVM_19.1`
  not `LLVMAddAlias2`. `assert_binary_symbols.py` regex must allow
  `(?:@@?\S+)?$` suffix; a bare `\w+$` anchor silently matches nothing.
  Fix is in `parse_defined_symbols` in `canary/scripts/assert_binary_symbols.py`.
- **`find_llvm_config_cmd` composability**: it's a multi-line `if/elif/fi`
  shell expression. Cannot be safely nested inside `$()` as a sub-argument
  (e.g., `$(find_llvm_config_cmd --libdir)` is wrong). Always assign to a
  variable first: `LLVM_CONFIG=$(find_llvm_config_cmd)` then use `$LLVM_CONFIG`.

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
