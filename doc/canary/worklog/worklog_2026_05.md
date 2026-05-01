# Canary Work Log — May 2026

## Session 7 (2026-05-01)

### Done

**#25 — `install` as a distinct canary action slot**

`Install_lib` rule added to `store_rules` (between `Build_lib` and
`Fetch Lib`). `probe_lib` generalised from `cmd option` to
`(location * cmd) list`, following the same per-location pattern as
`probe_binding`. Three location entries per source-build project:

| Entry | Location | Depends on |
|-------|----------|-----------|
| build-tree probe | `Build_tree` | `build_lib` |
| installed probe | `Staged` | `install_lib` |
| system PM probe | `Pm (Sys_pm { pm })` | `fetch_lib` |

New helpers in `canary_action.ml`:
- `tag_of_probe_lib_location` — canonical tag per location (single entry
  keeps `"probe_lib"`; multiple disambiguate to `probe_lib_staged`, `probe_lib_apt`, etc.)
- `deps_of_probe_lib_entry` — location → dependency tag

`no_source` strips `Build_tree` and `Staged` entries from `probe_lib`
(and clears `install_lib`) for source-less specs.

Fake install scripts (placeholder for TODO #40):
- z3: `cp build/libz3.so* $build/../install/lib/`
- llvm: `cp build/lib/libLLVM*.so $PREFIX/lib/`

Both projects now have `probe_lib` with all three location entries.

`Install_binding` was initially added but removed: lang binding install is
PM's job — `probe_binding Pm` already covers it. `Staged` remains as a
location type for future lang install slots (e.g. `ocamlfind install`).

**#28 — lift shared `pack_binding` preamble**

`opam_pack_cmd` added to `canary_toolchain.ml`. Shared sequence:
`eval $(opam env)` → optional preamble → repo add/set-url → update →
optional pre-install → remove old → env opam install → echo ok.

Parameters:
- `~preamble` (default `""`): z3 uses this for mkdir+cp+opam-config-subst
  (template-based packaging)
- `~pre_install` (default `""`): llvm uses this for `conf-llvm-shared.dev`
  install before the main package
- `~env_prefix`: space-terminated env-var assignments before `opam install`
  (z3: CANARY_BUILD_DIR + CANARY_SRC_DIR + prefix vars; llvm: CANARY_BUILD_DIR)

Both `canary_project_z3.ml` and `canary_project_llvm.ml` now call the
helper. Inline boilerplate removed.

**Tension 3 deferred → TODO #39**

The three ad-hoc follow-up patterns in `derive_steps` (`scan_source`,
`_summary`, `probe_binding` multi-probe) are stable as-is. The broader
need for conditional / triggered step dispatch is tracked as **TODO #39**
(dynamic scheduling / action dispatch). Not urgent while the step list
stays small; revisit when TODO #40 or CI conditional execution is needed.

**TODO #40 added** — replace fake `install_lib` (cp) with real
`cmake --install --prefix $PREFIX` in z3 and llvm. See
`doc/canary/backlog.md` and `doc/canary/ops/install_targets.md`.

### Open TODOs after this session

| # | Summary |
|---|---------|
| #19 | LLVM cross-version C symbol check (C level pending) |
| #20 | `assert_binary_symbols.py` `--provided-lib-old/new` mode |
| #35 | Split `binding_api.deps` into provenance and runtime contract |
| #39 | Dynamic scheduling / action dispatch (deferred) |
| #40 | Replace fake `install_lib` with real `cmake --install` |
