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

#### New features

5. **CI mode for opam depexts** — use `--confirm-level=unsafe-yes` to let
   opam auto-install system deps in Docker/CI. Currently local dev uses
   `--assume-depexts` (requires pre-installing system deps manually).

11. **tqdm-style progress display** — redirect verbose build output
    (cmake/ninja) to a log file, show a `\r`-overwriting single-line
    status on tty. Canary's `run_cmd_logged` already has the logging
    layer; split tty output from file output.

13b. **Driver mode: read `run_info.json` to configure a run** — allow
    `canary action --from run_info.json` to replay or reconfigure a
    run from a previously dumped spec. Enables reproducibility across
    machines and CI-generated test configurations.

#### Framework

9. **Binding build dependencies** — z3's OCaml binding requires `zarith`
   at build time. Model per-binding opam deps so `build_binding` can
   ensure they're installed. Add `binding_deps` to `ocaml_tool_config`.

10. **Unified build cache schema** — canary's `_out/canary/_local/` and
    opam's `~/.opam/.../build/` need a shared cache key scheme
    (project × version × ref) for version combination testing.

14. **z3 cmake `Z3_BUILD_LIBZ3_CORE=OFF` bug** — cmake ignores
    `Z3_ROOT` and binding flags. Workaround: always build libz3 from
    source in opam template. See `doc/z3_bug_api.md`.

17. **Module interfaces (.mli)** — define contracts for PM modules
    (`canary_pm_{apt,brew,opam,pip}`: `install_cmd`, `verify_installed_cmd`,
    etc.) and project modules (`canary_project_*.ml`: `script_spec`,
    `action_steps`, `run_info`).

18. **ocamlmklib stub archive convention** — `cmxa_stub_archive` derives
    `lib<name>.a` based on `ocamlmklib` naming. Factor into OCaml
    toolchain layer so each binding declares its stub archive path.

22. **Bundle check_post with action slots** — refactor `script_spec`
    action slots from `cmd option` to `{ cmd; check } option` so each
    action carries its own check_post instead of a separate dispatch.

#### Core research extension

16. **Mismatch prediction system** *(Opus)* — derive expected failures
    from version metadata. "z3 4.15 binding against z3 4.13 lib →
    missing symbols X, Y, Z" should be computable from API diffs.
    TODO #20 is the nm-based foundation.

19. **LLVM cross-version symbol check** — probe_binding has symbol
    compat check for dynamic case. Remaining: test with a mismatched
    version pair to confirm breakage detection.

20. **Symbol diff between lib versions** — extend `assert_binary_symbols.py`
    with `--provided-lib-old / --provided-lib-new` mode. Computes
    `added = v_new − v_old`, `breaking = required ∩ added`. Purely
    nm-based, no API metadata needed. Foundation for #16.

### Done

Done: #1, #2, #3, #4, #6, #7, #8, #12, #13, #15, #21. Details in
`doc/canary/worklog_2026_04.md`.

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
