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