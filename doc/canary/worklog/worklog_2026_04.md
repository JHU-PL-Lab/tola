# Canary Work Log — April 2026

## Session 1 (2026-03-30 to 2026-04-01)

### Done

**Framework**
- Failfast mode (`--ff`) for the action runner — hard exit on first
  failure, no summary/diagram tail
- `pm_install_cmd` in `canary_basic_store.ml` — unified install
  command with `sudo` for apt, `--assume-depexts` for opam
- `detect_pm` moved from per-project to `canary_basic_store.ml`
- `source_repo` type — git remote + per-distro locals + version/ref
- `mk_locals` + `distro_base` — factor out per-machine path prefixes
- `source_fetch_cmd` — verify local checkout or clone from remote
- `source_check_post` — reads `source.ok` marker, verifies path exists
- `check_post` override in `script_spec` — per-rule postcondition
- `cmake_configure` — single source of truth for z3 cmake flags
- `CANARY_BUILD_DIR` env var — build cache sharing between canary
  and opam (opam.in uses `${CANARY_BUILD_DIR:-build}`)
- `Makefile` shortcuts: `canary-sqlite`, `canary-z3`

**z3 project end-to-end**
- `fetch_source` → `build_lib` → `build_binding` → `pack_binding`
  → `probe_binding` all passing on WSL
- `z3_source_dev` (fork at arbipher/z3, local at `contrib/z3-all/z3`) and
  `z3_source_stable` (official, 4.15.2/bd3e722) defined
- `z3_project_spec` derives `project_spec` from any `source_repo`
- Removed 5 legacy aliases, unified through `root_of_source`
- `build_lib` targets `ninja libz3` only (not all targets)
- `build_binding` targets `ninja build_z3_ocaml_bindings` only
- `opam.in` template: renamed from `opam`, removed
  `Z3_BUILD_LIBZ3_CORE=OFF` (cmake bug), uses `CANARY_BUILD_DIR`
- `probe_binding` tests both build tree (direct `-I`, no
  `-package z3`) and opam-installed (`-package z3`, no `-I`)
- `pack_binding` uses tola's template path (not z3 source tree),
  passes `OPAMVAR_Z3_PREFIX`, `--keep-build-dir`

**sqlite project**
- Uses `pm_install_cmd` instead of raw strings
- End-to-end passing on WSL (after `sudo apt install sqlite3
  libsqlite3-dev pkg-config`)

**Documentation**
- Store model section in `doc/canary/design.md`
- Cross-machine handoff doc (`doc/cross_machine_handoff.md`)
- Handoff workflow inlined in CLAUDE.md with save/load prompts
- z3 bug notes updated (`doc/z3_bug_api.md`)
- Purged mac's stale Claude memory, synced gotchas to local memory

### Gotchas discovered

- `opam config subst` expects `.in` suffix, path relative to cwd
- z3 git submodule `.git` file causes cmake "could not find
  commondir" — convert to standalone repo
- Build tree vs opam-installed binding: never mix `-package z3`
  with `-I build/api/ml` (inconsistent interface assumptions)
- opam sandbox empty on WSL by default; active on GH CI — env
  var build cache sharing won't work in CI sandbox
- z3 cmake `Z3_BUILD_LIBZ3_CORE=OFF` ignores `Z3_ROOT` and
  `Z3_BUILD_OCAML_BINDINGS` — always build from source in opam

---

## Plan: LLVM project (TODO #6)

Prebuilt only (no source building). OCaml + Python bindings.

### Action mapping (no framework changes needed)

| Action          | Command                                      | Notes                     |
| --------------- | -------------------------------------------- | ------------------------- |
| `fetch_lib`     | `apt install llvm-dev` / `brew install llvm` | System LLVM               |
| `fetch_binding` | `opam install llvm -y`                       | OCaml bindings            |
| `fetch_app`     | `pip install llvmlite`                       | Python (bundles own LLVM) |
| `probe_lib`     | `llvm-config --version`                      | Sanity check              |
| `probe_binding` | Compile+run OCaml example                    | `ocamlfind -package llvm` |
| `probe_app`     | `python3 -c "import llvmlite..."`            | Import test               |

No `fetch_source`, `build_*`, or `pack_*`.

### Design notes

- **App tier for Python**: `fetch_app`/`probe_app` map naturally to
  pip install + Python test. Mild semantic stretch of "app" but fits
  existing `script_spec` slots without framework changes.
- **No `Pip` in `package_manager`**: handle via raw shell in
  `script_spec`. z3 already uses `(Python, Unsupported)`. Add `Pip`
  PM later if more projects need it.
- **llvmlite independence**: bundles its own LLVM, so `fetch_app`
  doesn't truly depend on `fetch_lib`. The dep graph adds one anyway
  (harmless — `deps_of_rule` for `Probe App` adds a lib dep).
- **LLVM version pinning**: opam `llvm` requires matching system
  LLVM. Version mismatch is the exact kind of bug canary catches.
- **macOS brew LLVM**: not on PATH by default. May need
  `export PATH=$(brew --prefix llvm)/bin:$PATH` before
  `opam install llvm`.

### Files to create/modify

| File                                   | Action                                 |
| -------------------------------------- | -------------------------------------- |
| `src/bin/canary_project_llvm.ml`       | New — follow sqlite pattern            |
| `canary/examples/llvm/llvm_example.ml` | New — minimal OCaml LLVM example       |
| `src/bin/canary_main.ml`               | Add `"llvm"` case in action dispatch   |
| `src/bin/canary_run.ml`                | Add to `project_configs` list          |
| `src/bin/dune`                         | Add `canary_project_llvm.ml` if needed |
| `Makefile`                             | Add `make canary-llvm`                 |

### Minimal OCaml example

```ocaml
let () =
  let ctx = Llvm.global_context () in
  let m = Llvm.create_module ctx "test" in
  let i32 = Llvm.i32_type ctx in
  let ft = Llvm.function_type i32 [| i32 |] in
  let f = Llvm.declare_function "identity" ft m in
  let bb = Llvm.append_block ctx "entry" f in
  let builder = Llvm.builder ctx in
  Llvm.position_at_end bb builder;
  let param = Llvm.param f 0 in
  ignore (Llvm.build_ret param builder);
  Llvm.dump_module m;
  Llvm.dispose_module m;
  print_endline "llvm ok"
```

### Decision points (before implementation)

1. LLVM version: pin to a specific version (e.g., 18) or use
   distro default?
2. Python: include llvmlite from day one, or add later?
3. macOS: handle brew PATH issue in `fetch_lib` or defer?

---

## Session 2 (2026-04-05 to 2026-04-06)

### Done

**#1 Fix z3 `fetch_binding`** — `--assume-depexts` added via
`pm_install_cmd` in `canary_basic_store.ml`.

**#2 Fix z3 `build_lib` check_post** — `check_post` override added to
`script_spec`; `source_check_post` reads `source.ok` and verifies
the path still exists.

**#3 `check_post` per artifact** — marker file system for all rule
categories (see design.md "Default postcondition markers" table).
z3 `Build_lib` and `Build_binding` also check real artifact existence
(`libz3.so`, `z3ml.cmxa`) to catch stale-marker/deleted-build cache
misses. New module `canary_artifact_check.ml`: existence checks
(`exists_native_lib_or_dylib`, `exists_ocaml_archive`), nm symbol
inspection (`check_symbols`, `native_lib_probe_cmd`), opam package
inspection (`opam_pkg_inspect_cmd`, `opam_pkg_symbol_check_cmd`),
`cmxa_stub_archive` (ocamlmklib convention: `lib<name>.a`).

**#4 Store indirection** — `pm_install_cmd`, `source_repo`, `mk_locals`,
`distro_base`. Remaining: factor pack commands into store templates.

**#6 LLVM project** — `canary_project_llvm.ml` wired up with prebuilt
system + opam binding + llvmlite python. Symbol compat check via opam
package inspection (`ocamlfind query` → `lib*.a` → nm). ELF versioned
symbol regex fix in `assert_binary_symbols.py`. Source build spec added
with `llvm_source_dev` (arbipher fork), cmake configure, but not yet
tested end-to-end.

**#8 cmake configure as a separate action** — new `Configure` rule
variant between `Fetch Source` and `Build_lib`. Marker `conf.ok`.
`Build_lib` depends on `Configure` if present. z3 and llvm both use it.
`build_lib` no longer bundles cmake configure.

**#13 Dump project spec** — `run_info.json` dumped at start of each
action run with project, version, ref, source, distro, system PM,
opam switch, OCaml version, timestamp, actions, project-specific extras.

**Unified example files** — all under `canary/examples/<project>/`:
`z3/z3_example.ml` (new minimal probe), `llvm/llvm_example.ml`
(renamed from `llvm_canary.ml`), `sqlite3/sqlite3_example.ml` (unchanged).

**Source build capabilities** — `source_repo` now has `has_build_lib`
and `has_build_binding` flags. Three source tiers: contributor dev
(both true), official latest (both true), official stable (lib=false,
binding=true). `mk_script_spec` conditionally includes configure/
build_lib/build_binding based on these flags.

**Contrib path reorganization** — z3 moved to `contrib/z3-all/z3{,-stable}`,
opam repos to `contrib/opam-all/`. All references updated across code,
templates, docs, scripts.

### Gotchas discovered

- ELF symbol versioning: `nm -D` outputs `LLVMAddAlias2@@LLVM_19.1`;
  regex must allow `@@VER` suffix (fixed in `assert_binary_symbols.py`)
- `find_llvm_config_cmd` is multi-line if/elif — can't nest in `$()`
  as sub-arg; always assign to variable first
- `ocamlmklib` naming: `<name>.cmxa` → C stubs in `lib<name>.a`, not
  `<name>.a`
- CMakeCache.txt bakes in absolute source path — moving source dir
  requires deleting CMakeCache.txt + CMakeFiles/

---

## Session 3 (2026-04-06 to 2026-04-07)

### Done

**#8 cmake configure as separate action** — new `Configure` rule variant
between `Fetch Source` and `Build_lib`. Marker `conf.ok`. `build_lib`
no longer bundles cmake configure. z3 and llvm both use it.

**#7 z3 stable source (completed)** — three version specs (dev/latest/stable)
for z3 and llvm. `source_repo` has `has_build_lib` and `has_build_binding`
flags. Probes decouple from hardcoded build-tree paths: `lib_cmd_of_source`
resolves to build tree or `pkg-config` at runtime. `native_lib_probe_cmd`
uses double-quoted `"$LIB_Z3"` for shell variable expansion.

**#12 Multiple probes per artifact kind** — `probe_binding` is now
`(location * cmd) list`. `location` (from `canary_store`) determines
tag and deps: `Build_tree` → `probe_binding_build`, `Lang_pm` →
`probe_binding_pkg`. z3 uses both; llvm/sqlite use single entry.

**#15 PM primitive testing** — `canary pm-test` command generates and
runs tests from `canary_pm_{apt,brew,opam,pip}` modules. Each PM module
has uniform ops and a `properties : pm_properties` record. 19 tests
passing. `canary_pm_types.ml` breaks the dependency cycle between
`canary_store` and PM modules.

**#21 Source build capabilities** — `has_build_lib` / `has_build_binding`
flags on `source_repo`. `mk_script_spec` conditionally includes
configure/build_lib/build_binding. Three tiers: dev (both true),
latest (both true), stable (lib=false, binding=true).

**Module renames** — `canary_basic_store` → `canary_store`,
`canary_basic_ocaml` → `canary_ocaml`, `canary_basic_{apt,brew,opam}` →
`canary_pm_{apt,brew,opam}`. New: `canary_pm_pip`, `canary_pm_types`.

**Project file separation** — `canary_project_{z3,llvm,sqlite}.ml` and
`canary_run.ml` moved to `src/canary/projects/` with own library
(`canary_projects`). Framework (`canary_lib`) and consumers cleanly split.

**check_post compositors** — `check_build_lib`, `check_build_binding`,
`check_markers` thin functions in `canary_artifact_check.ml`. z3 and
llvm use these instead of inline logic.

**LLVM source spec** — `llvm_source_dev` (arbipher fork),
`cmake_configure_cmd`, `mk_source_script_spec`. Build dir as sibling
(`llvm-all/build`). Not yet tested end-to-end.

### Gotchas discovered

- `opam list --installed-roots` misses transitive deps; use `--installed`
- opam `eval $(opam env)` prefix hardcodes default switch; needs
  `--switch=<name>` for per-switch targeting

---

## Session 4 (2026-04-14 to 2026-04-16)

### Done

**#23 LLVM source build end-to-end** — `canary action llvm` now runs all
11 action steps (fetch_source → configure → build_lib → fetch_lib →
build_binding → fetch_binding → pack_binding → probe_lib →
probe_binding_build → probe_binding_pkg → probe_app). First fully
end-to-end source-build path for LLVM, passing on WSL.

**`pack_binding` for LLVM** — registers local opam repo, installs
`conf-llvm-shared.dev` (writes build-tree `llvm-config` path via
`CANARY_LLVM_BUILD`), then installs `llvm.dev-shared` (copies archives,
strips `directory` from META, appends `linkopts` for rpath). Writes
`pack.ok` marker. `Publish Binding` case added to `check_post`.

**Multi-version mismatch probe (llvm/19)** — two sequential
`action_steps` invocations sharing one opam switch:

| Sub-run | Lib | Binding | Example | Expected |
|---------|-----|---------|---------|----------|
| `llvm` | dev source build | `llvm.dev-shared` (packed) | `llvm_example_dev.ml` | pass |
| `llvm/19` | `llvm-19-dev` (apt) | `llvm.19-shared` (opam) | `llvm_example_dev.ml` | **fail** |

`llvm_example_dev.ml` uses `Opcode.UncondBr` (introduced in LLVM 21,
March 2026, commit #186176 — `Opcode.Br` split into `UncondBr` +
`CondBr`). Against `llvm.19-shared` it fails to compile — clean
OCaml-level API mismatch, no expect-failure infrastructure needed.
Same sequential pattern applied to z3 + z3/stable.

**`has_build_binding = false` for stable sources** — skips
configure/build_binding/pack_binding; only fetch_lib + fetch_binding +
probe steps run. Applied to `llvm_source_stable` and `z3_source_stable`.

**`llvm_source_stable` uses local WSL path** — `fetch_source` emits
`test -d <path>` (instant existence check, no clone). Source at
`/home/red/code/contrib/llvm-all/llvm-project`.

**New opam packages** under `canary/templates/opam-local-repo/`:
- `conf-llvm-shared.dev` — writes config from `$CANARY_LLVM_BUILD`
- `llvm.dev-shared` — build-tree artifacts + patched META
- `llvm.19-shared` / `conf-llvm-shared.19` — system LLVM 19 bindings

**New example files**:
- `llvm_example_dev.ml` — uses `Opcode.UncondBr`; fails against LLVM 19
- `llvm_example_19.ml` — uses `Opcode.Br`; fails against dev binding
- `llvm_example_15.ml` — uses `global_context ()`; fails against LLVM 16+

**`run_info` exposed per-project** — `canary action llvm/z3` calls
`run_info` for each sub-run; `~source_repo` optional arg for header.

**`run_z3` / `run_llvm` in `canary_main.ml`** — each runs dev then
stable/19 sub-run sequentially (sequential execution avoids opam switch
state conflicts).

**New documentation**:
- `doc/canary/install_target_survey.md` — Z3 vs LLVM cmake install
  patterns; 3 canonical patterns; failure modes. Informs TODO #25.
- `doc/canary/llvm_build_note.md` — full LLVM source build steps,
  smoke test, opam install notes.
- `doc/canary/backlog.md` — lower-priority TODOs (#5, #9–#11,
  #13b, #14, #16–#18, #22).

### Gotchas discovered

- **`build_z3_ocaml_bindings` is PHONY**: cmake `add_custom_target` →
  ninja never considers it up-to-date → always reruns. Deleting canary
  `_out/` cache re-runs cmake, touching `CMakeFiles/` timestamps →
  cascades into full z3 rebuild (~863 steps). LLVM's `LLVM` target
  builds concrete `libLLVM.so` → ninja skips correctly.
- **`$CAMLORIGIN/../..` breaks in flat opam layout**: LLVM's `llvm.cmxa`
  embeds a relative rpath that resolves correctly in the build tree
  (`build/lib/ocaml/llvm/ → build/lib/`) but not after `ocamlfind install`.
  Fix: append `linkopts = "-cclib -L<BUILD>/lib -cclib -Wl,-rpath,<BUILD>/lib"`
  to META in `llvm.dev-shared/opam`.
- **`mktemp /tmp/...` blocked in opam sandbox** (CI-relevant): bwrap
  doesn't mount `/tmp`. Use `./META` (opam build dir) instead.
- **z3/stable resolved to `z3.dev`**: Local opam repo (rank 1) shadowed
  upstream — `opam install z3` picked the local dev version. Fixed by
  pinning to `opam install z3.4.15.2` in `fetch_binding` for the stable
  path. Root cause: unversioned `opam install <pkg>` lets the solver
  prefer rank-1 repo entries regardless of version name.
- **OCaml optional arg semantics**: `?(label : T)` means caller passes
  `T`; OCaml wraps it in `Some`. Pass `~source_repo:llvm_source_stable`,
  not `~source_repo:(Some llvm_source_stable)`.
- **`Publish Binding` not `Pack Binding`**: The `rule` type constructor
  is `Publish of artifact_kind`; `Pack` does not exist.

### Open TODOs after this session

| # | Summary |
|---|---------|
| #19 | LLVM cross-version C symbol check (OCaml API mismatch demonstrated; C level pending) |
| #20 | `assert_binary_symbols.py` `--provided-lib-old/new` mode |
| #24 | Unified project spec — local repo naming, env vars, build dir layout, z3/stable shadowing |
| #25 | Model `cmake --install` as canary action slot (`install_lib` / `install_binding`) |
| #26 | Idempotent step execution — artifact pre-checks for cmake/ninja/opam |

---

## Session 5 (2026-04-16)

### Done

**#24 Unified canary project spec** — all naming and path inconsistencies
resolved:

- **`build_path` in `local_path`** — new field is the source of truth for
  the build directory associated with a local checkout. `mk_locals` computes
  it from a `build_dir` relative path (default `"../build"`, sibling layout).
  `mk_script_spec` in both z3 and llvm now reads `local.build_path` directly;
  no project-specific derivation functions remain.

- **Build dir layout unified** — both z3 and llvm use sibling `../build`
  convention. z3's old in-tree `<source>/build` abandoned; new build path
  is `/home/red/code/contrib/z3-all/build`.

- **`CANARY_BUILD_DIR` unified** — `CANARY_LLVM_BUILD` renamed everywhere
  (ml scripts + opam templates `conf-llvm-shared.dev`, `llvm.dev-shared`).
  z3's `opam.in` already used `CANARY_BUILD_DIR`; now consistent across all.

- **`"canary-local"` unified** — all three projects (z3, llvm, sqlite) use
  the same local opam repo name, matching the single
  `canary/templates/opam-local-repo/` directory that hosts all packages.

- **z3/stable shadowing fixed** — `fetch_binding` for z3/stable now installs
  `z3.4.15.2` (pinned), not `z3` (unversioned). Unversioned install let
  opam's solver prefer `z3.dev` from rank-1 `canary-local` over the upstream
  stable release. LLVM's stable path was already correct (`llvm.19-shared`
  is an explicit name only in `canary-local`; no upstream collision possible).

### Open TODOs after this session

| # | Summary |
|---|---------|
| #19 | LLVM cross-version C symbol check (C level pending) |
| #20 | `assert_binary_symbols.py` `--provided-lib-old/new` mode |
| #25 | Model `cmake --install` as canary action slot |
| #26 | Idempotent step execution — artifact pre-checks for cmake/ninja/opam |

---

## Session 6 (2026-04-17)

### Done

**#26 — Action state detection (complete)**

`check_post` now covers all action slots with external-state probes,
so canary skips steps whose results are already satisfied — even when
`_out/` markers are absent.

- **`Configure`** — added to both z3 and llvm `check_post`:
  `check_markers ["configure.ok"] || Sys.file_exists "<build>/CMakeCache.txt"`.
  Prevents cmake re-runs (which update timestamps → trigger PHONY ninja
  rebuild of `build_z3_ocaml_bindings`) when the build dir is already
  configured and `_out/` was cleared.

- **`Build_lib` / `Build_binding`** — already covered (prior session):
  `check_build_lib` / `check_build_binding` check artifact existence
  (`libz3.so`, `z3ml.cmxa`, `libLLVM.so`, `llvm.cmxa`).

- **`Fetch Binding` / `Publish Binding`** — already covered (prior session):
  `|| Canary_pm_opam.is_installed ~pkg` so opam steps are skipped when
  the package is already installed.

**z3 `pack_binding` opam sandbox fixes**

Root cause: opam's bwrap sandbox mounts the entire filesystem read-only
except `$PWD` (opam build dir). External `CANARY_BUILD_DIR` is readable
but not writable.

- **`CANARY_SRC_DIR`** — new env var passed alongside `CANARY_BUILD_DIR`
  in z3's `pack_binding`. The z3.dev opam template uses
  `cmake -S $S -B $B` (was `-B $B` only), matching the existing cmake cache
  source path and avoiding "source mismatch" errors.

- **Build guard in z3.dev opam template** — cmake+ninja are now wrapped:
  `if [ -f "$B/src/api/ml/z3ml.cmxa" ]; then echo skip; else cmake ... && ninja ...; fi`.
  When artifacts exist (canary already ran `build_binding`), cmake is skipped
  entirely — no writes to the read-only external path needed.
  On CI (`$B=build`, local to sandbox), cmake runs normally in a writable dir.

**`dev_<hash>` cache paths**

`version_cache_tag distro repo` added to `canary_store.ml`: for `ref_="HEAD"`
repos, shells `git rev-parse --short=6 HEAD` in the local checkout and returns
`"dev_abc123"`. Stable refs return `repo.version` unchanged.

`canary_main.ml` and `canary_run.ml` updated: dev sub-runs use
`"llvm/dev_<hash>"` / `"z3/dev_<hash>"` as project names, producing
`_local/llvm/dev_ab43cb8/` layout. Sibling stable runs (`llvm/19`, `z3/stable`)
are unaffected.

**Opam sandbox correctness**

`wrap-build-commands` is active globally (includes `sandbox.sh` + bwrap on
Linux) — the switch-level `[]` is an "inherit global" marker, not a disable.
bwrap mounts all of `/` read-only except `$PWD` (rw), `/tmp` (rw bind),
ccache/dune-cache dirs (rw). `TMPDIR` is redirected to `/opam-tmp` (tmpfs).
Two CLAUDE.md gotchas corrected.

**Backlog additions**

- **#27** — opam template taxonomy: distinguish "build from source" vs
  "install pre-built" templates by convention.
- **#28** — lift shared `pack_binding` preamble into `Canary_ocaml.opam_pack_cmd`.

### Open TODOs after this session

| # | Summary |
|---|---------|
| #19 | LLVM cross-version C symbol check (C level pending) |
| #20 | `assert_binary_symbols.py` `--provided-lib-old/new` mode |
| #25 | Model `cmake --install` as canary action slot |