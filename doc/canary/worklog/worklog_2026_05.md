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

## Session 8 (2026-05-19, 2026-05-28, 2026-05-29) — Phase 4 alignment + Step 3b/4 scaffolding

Three days condensed: vocabulary alignment, tiny harness's prepare /
confirm_ill flow, and the initial-implementation pass of the
surface-theory comparators + inspectors. The Phase-4 detail lives in
[`phase4_2026_05.md`](phase4_2026_05.md); this entry records the
implementation milestones that fed Phase 14/15's wiring in June.

### Done — Phase 3 tiny harness (2026-05-28)

`scenarios.py prepare` / `confirm_ill` flow: each scenario's
`violates` claim is now a machine-checkable assertion. `prepare`
computes the surface delta vs cached baseline JSONs and writes
`_cache/<name>/confirm_ill.json`. Phase 3b adds artifact + source
snapshots for cached replay (`make scenarios-cached`, ~1.6× faster
than `make scenarios` on tiny). `tiny.md` "Phase 3a" / "Phase 3b"
subsections document the flow; Makefile + scenarios.py expose the
commands.

### Done — Seed fixtures + runner for compat/inspect tests (2026-05-29)

In-memory OCaml fixtures in `test/canary_artifact_test.ml`:
- `cmp_symbol_pure_tests` (5 cases): Compatible / Missing one / etc.
- Lays the framework that #15b's per-contract case lists later
  attached to (c4/c5/c6/c7/c8 sections added through Phase 14/15).

### Done — Step 4 comparator + inspector scaffolding (2026-05-29)

Initial function shapes for the c4..c8 comparators and the new
n3 / bo1 inspectors. Each landed with unit-test coverage; pipeline
wiring (Expect_compat_failure prediction routes) was a follow-up
that landed during Phase 14/15.

- **c4 `cmp_abi`** (commit `2426099`). Function
  `check_abi ~provider_soname ~consumer_needed` in
  `surface/canary_compat.ml`; dedicated `abi_result` type
  (`Abi_compatible` / `Abi_mismatch` / `Abi_unknown`). 5 unit
  tests in `cmp_abi_pure_tests`. Pipeline wiring landed in Phase 14e.

- **c5 `cmp_sym_version`**. Function
  `check_sym_version ~provider_versioned_exports
  ~consumer_required_versions`; dedicated `sym_version_result`
  type. 6 unit tests in `cmp_sym_version_pure_tests` (exact-match,
  subset-match, glibc/musl drift, missing-multiple, both Unknown
  branches). Today's check is exact-match; floor-comparison is a
  future refinement. Pipeline wiring landed in Phase 15.4.

- **Inspector for `bo1`**. `^external` parse added to
  `inspect_binding.py`; emits a new `externals` field alongside
  `vals` so a single `--kind mli` run on either a stub-facing or
  user-facing `.mli` cleanly separates the two surfaces. Watchlist
  resolves against both. 3 fixture-driven tests
  (`bo1_external_inspect_pure_tests`).

- **Inspector for `n3`**. New `canary/scripts/inspect_header.py` —
  regex-based C header parser. Emits `{kind: c_header, functions:
  [{name, return_type, arg_types}], extern_vars: [{name, type}]}`.
  Scoped to tiny.h-shape headers. Real-world z3.h / llvm-c/*.h need
  libclang or tree-sitter — follow-up. 4 fixture-driven tests
  (`n3_header_inspect_pure_tests`). [Note: superseded by Phase 15.3's
  `inspect_tiny_typed.py` which subsumes the header layer.]

- **`bo1` enhanced**. `inspect_binding.py --kind mli` now emits an
  `externals_detail` field per external: `{name, sig, c_symbol,
  arity}`. Arity = count of `->`.

- **c6 `cmp_type` (OCaml first)**. Function
  `check_type ~header_functions ~binding_externals ~name_mapping`;
  dedicated `type_result` type. MVP arity-only after applying a
  project-declared name mapping. 7 unit tests in
  `cmp_type_pure_tests`. Pipeline wiring landed in Phase 15.5b.
  (Correction logged then: the earlier plan claimed e3 type_wrong
  flips ✗ → ✓ when c6 lands; that's wrong — e3 patches `c/src/tiny.c`
  body so header + stub stay aligned. e3 is c3 Behavior's territory.
  A new tiny scenario `header_arity_bump` was added in Phase 15.5b
  to give c6 a live demo where the regression shape actually fits.)

- **c7 `cmp_api_repack` (OCaml first)**. Function
  `check_api_repack ~stub_externals ~user_vals ~renames`;
  dedicated `repack_result` type (`Repack_compatible` /
  `Repack_stub_orphan` / `Repack_user_phantom` / `Repack_unknown`).
  Renames declared by project specs. 6 unit tests. **Regression
  scenario**: new tiny scenario **e14 `api_repack_stub_orphan`** —
  static stub-orphan case. (Reframed in Phase 15.6 to
  `api_sound_repack` Contract, since the static-only side of c7 is
  ad-hoc and the runtime side reuses c3's mechanism with different
  attribution.)

- **c8 `cmp_api_faithfulness`**. Function
  `check_api_faithfulness ~type_verdict ~symbol_verdict
  ~repack_verdict`; dedicated `faithfulness_result` type. Pure
  composition of the three constituent verdicts. 7 unit tests.
  (Reframed in Phase 15.6: c8 disabled at the registry level —
  each binding is independent; cross-binding consistency isn't a
  canary-side agreement.)

### Done — `canary_project_tiny.ml` Phase 4 milestone (2026-05-28 / 05-29)

`canary action tiny` runs the full 12-step pipeline (6 main + 6
inspect) using the aligned vocabulary. JSON shapes byte-equivalent
to `make scenarios-cached`. Phase 4 milestone check passed — see
[`phase4_2026_05.md`](phase4_2026_05.md). The 13-variant matrix
landed on top of this foundation in June (Phase 14a–15.7) — see
[`worklog_2026_06.md`](worklog_2026_06.md).

### Done — single source of truth + retired docs (2026-05-19)

Theory, witness, plan in three aligned docs; entry point at
`research/README.md`; legacy `api_surface.md` retired (its
implementation pointers folded into `surface_theory.md` §2.7,
glibc/musl case into §4.2, packaging kept as §3 of the same doc).
