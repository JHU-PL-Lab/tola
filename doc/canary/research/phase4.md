# Phase 4 tracker — canary code-side term alignment

Working tracker for propagating the unified vocabulary
(`s*` / `c*` / `e*` indices, `n*` / `b<lang><mech?>*` artifact
aliases, canonical names) from the research docs + tiny harness
into canary's OCaml code.

Status of the surrounding tracks:

- ✓ Step 1 (unified terms) — docs + tiny aligned (2026-05-20).
- ✓ Phase 3 (tiny prepare / confirm_ill / cached harness) — landed
  2026-05-28 (commit `8804228`).
- **→ Phase 4 (this doc)** — align canary OCaml code to the same scheme.
- ⏳ Step 4 (comparators c4 / c5 / c6 / c7 / c8) — depends on Phase 4
  for clean naming in the new comparator code.

Phase 4 is **no-semantics-change**: only comments, renames,
doc-strings, and a small typed mapping. `canary action {z3,llvm,sqlite}`
and `canary {artifact-test,pm-test}` must stay green throughout.

## Goal

A reader who reads `surface_theory.md` and then opens any
`src/canary/*.ml` file finds the same artifact roles called by the
same names. No mental translation between "binding_summary" (code)
and "bo4 `user_binding_ocaml.mli`" (docs).

The milestone check is `canary_project_tiny.ml` + `canary action
tiny` — once that runs every scenario through the canary pipeline
with the aligned vocabulary, the loop is closed.

## Naming convention (final)

| index family | examples | usage |
|---|---|---|
| `s1..s6` | s1 native_header, s2 native_lib, ... | abstract surface roles (theory layer) |
| `c1..c8` | c1 cmp_symbol, c2 cmp_api_completeness | contracts = comparators (1-to-1) |
| `e1..e13` | e1 symbol_missing, e2 abi_soname_bump | scenarios |
| `n*` | n1 `source_native.c`, n4 `lib_native.so` | native-side artifacts, project-local |
| `bo*` | bo1 `stub_binding_ocaml.mli`, bo7 `compiled_binding_ocaml.stub-a` | ocaml binding artifacts |
| `bpc*` | bpc2 `user_binding_ctypes.py` | python ctypes binding artifacts |
| `bpe*` | bpe3 `compiled_binding_cext.so` | python cext binding artifacts |
| canonical names | `<role>_<side>[_<lang>][_<mech>].<form>` | pan-universal, the prose form in OCaml code |

**Code convention**:

- **Default to canonical names in OCaml code** — `let lib_native = ...`,
  `match user_binding_ocaml_mli with ...`. Self-documenting, no
  lookup table needed.
- **Use IDs in tables / log lines / JSON keys / status displays** —
  compact for column-fits contexts.
- **Cross-reference both when introducing a concept in a comment** —
  `(* bo7 = compiled_binding_ocaml.stub-a *)`.

See `tiny.md` "Artifact inventory" for the full mapping.

## Term inventory (what's misaligned today)

A survey of where the old vocabulary lives in `src/canary/`:

| canary location | term today | direction for Phase 4 |
|---|---|---|
| `canary_basic.ml` | `artifact_kind = Source ∣ Headers ∣ Lib ∣ Binding of lang ∣ App` | **keep** — coarse action-dispatch grouping. Add doc-comment mapping each constructor to its canonical-name group (e.g. `Headers → header_native`; `Binding OCaml → {stub,user,compiled}_binding_ocaml.*`). |
| `canary_basic.ml` | `artifact = { kind; name; location }`, `artifact_node` | leave types alone; add doc-comments tying `name` to canonical-name conventions for each kind. |
| `canary.ml` | `string_of_artifact_kind` produces `"source" \| "headers" \| "lib" \| "<lang>_binding" \| "app"` | **keep** — already role-shaped. |
| `canary.ml` | `compat_inspect_input = C_stub ∣ Native_lib ∣ Ocaml_mli ∣ Python_attrs ∣ Versioned_symbols` | each constructor maps to a canonical artifact role. Add doc-comment per constructor: `Ocaml_mli (* parses bo4 user_binding_ocaml.mli OR bpe2/bpc2 equivalent *)`. Consider renaming `Ocaml_mli → User_binding_mli` and `Python_attrs → User_binding_attrs` (per binding-language-agnostic shape), but that's a wider rename — propose as a follow-up if simpler names suffice. |
| `canary.ml` | `step_expectation`, `Expect_compat_failure` | document that the predicted failure substring comes from a specific surface delta on the named artifact alias. |
| `canary_action.ml` | `binding_summary : (lang * string) list` (e.g. `[(OCaml, "z3")]`) | rename to `binding_user_facing_pkg` or `user_facing_label`. The field actually labels the user-facing package name per language; `binding_summary` was the pre-Phase-2 term. |
| `canary_artifact_api.ml` | `native_api`, `binding_api`, `api_component = Headers ∣ Runtime_lib ∣ Link_lib ∣ Pc_file` | keep types; doc-comment cross-references: `Headers (* → header_native = n3 in tiny *)`, `Runtime_lib (* → lib_native = n4 *)`, etc. |
| `canary_artifact_native.ml` | inspect glue for `inspect_native.py` | doc-comments tying functions to `n4` / `bpe3` (the two artifacts using this script). |
| `canary_artifact_lang.ml` | OCaml + Python summary helpers | per-function docs: which alias each function produces JSON for. |
| `canary_artifact_test.ml` | test fixtures: `fmt_cmxa`, `libsqlite3_so`, `sys_dir`, ... | rename test variable names to canonical form where it improves clarity (e.g. `sys_dir → user_binding_python_sys` if the fixture is symbolic of s4 Python). |
| `canary_compat.ml` | `check_c_compat`, `predicted_contains_any_v2`, `verify_for_project` | already structurally aligned; doc-comments tying inputs to alias pairs (e.g. `check_c_compat n4 bo7` for OCaml, `check_c_compat n4 bpe3` for cext). |
| project specs (`canary_project_{z3,llvm,sqlite}.ml`) | hand-written per-project paths and watchlists | optional follow-up: add an `aliases : (string * string) list` field carrying the per-project artifact inventory. Not strictly needed for Phase 4 but unblocks tooling that wants to print `n4 lib_native.so` instead of raw paths. |
| `canary_project_tiny.ml` | **doesn't exist yet** | new module — the milestone check. Must build cleanly and `canary action tiny` must run all 12 scenarios through the production pipeline using the aligned vocabulary. |

## Task list

Ordered low-risk → higher. Each item should leave canary green
(`make canary` + `dune exec ... -- artifact-test` + `pm-test`).

### Pass 1 — doc-comment annotations (zero rename risk)

- [ ] **`canary.ml` `compat_inspect_input`**: doc-comment each
      constructor with the artifact alias(es) it represents
      (`Ocaml_mli` ↔ bo4 / bpe2 / bpc2; `Native_lib` ↔ n4; etc.).
- [ ] **`canary.ml` `string_of_artifact_kind`**: docstring linking
      each output string to the canonical-name group.
- [ ] **`canary_basic.ml` `artifact_kind`**: docstring per
      constructor + a single comment block mapping the coarse kind
      to the fine `n*/b*` aliases in tiny.
- [ ] **`canary_artifact_api.ml` `api_component`**: doc-comment per
      constructor (Headers / Runtime_lib / Link_lib / Pc_file) tying
      to `s1..s2` and the canonical-name groups.
- [ ] **`canary_compat.ml`**: function-header docstrings for
      `check_c_compat` and `predicted_contains_any_v2` naming the
      alias pair each call site exercises.
- [ ] **`canary_artifact_native.ml` / `_lang.ml` / `_check.ml`**:
      per-function docstrings: which alias's JSON each function
      produces or reads.

Pass 1 deliverable: every type and function dealing with surface
artifacts has a doc-comment naming its canonical role. No code
changes; greps for `s1..s6`, `n4`, `bo1`, etc. find the right
files. Safe to ship in pieces.

### Pass 2 — surgical renames (low-risk)

- [x] **`canary_action.ml`** (2026-05-28): renamed `binding_summary`
      field on `script_spec` to `binding_user_facing_pkg`. Updated
      derive_steps call sites + z3 / llvm project specs + sqlite
      comment mention.
- [x] **`canary_artifact_test.ml`** (2026-05-28): inspected — the
      existing fixture identifiers (`native_lib_fixture`,
      `native_pure_tests`, `ocaml_pure_tests`, `compat_pure_tests`)
      are already aligned with the canonical-name scheme. No
      renames needed.
- [ ] (Optional, propose first) `canary.ml`: rename
      `Ocaml_mli → User_binding_mli` and `Python_attrs →
      User_binding_attrs` to drop language-flavoured names. This is
      a wider rename (touches step expectations, comparator
      dispatch, watchlist parsing); propose before doing.

### Pass 3 — typed alias inventory (additive)

- [ ] **`canary_alias.ml`** (new module): types for the alias scheme
      itself —
      ```ocaml
      type side = Native | Binding of Canary_artifact_api.lang * mechanism option
      and mechanism = Cstubs | Ctypes | Cext  (* OCaml gets Cstubs implicitly *)

      type role =
        | Source | Header | Lib       (* native side *)
        | Stub | User | Compiled      (* binding side, repeated per layer *)
        | Trace                        (* runtime *)

      type canonical = { role: role; side: side; form: string option }
      val canonical_to_string : canonical -> string  (* → "lib_native.so" *)
      val alias_of_canonical : canonical -> string  (* → "n4" within a project *)
      ```
      Project specs can optionally carry a `(canonical, path) list`
      so `canary compat` / `verify` output uses aliases.
- [ ] Wire `canary_basic.ml`'s `artifact_kind` to the new types
      (one-way mapping: `Lib → { role=Lib; side=Native }`, etc.).

### Pass 4 — `canary_project_tiny.ml` (milestone)

- [x] **`src/canary/projects/canary_project_tiny.ml`** (2026-05-28):
      new project spec driving the 5-step canary pipeline over
      tiny's in-tree source. Configure / Build_lib / Build_binding
      OCaml / Probe / Probe-inspect all green. Module docstring +
      command-level comments use the aligned vocabulary throughout
      (n4 [lib_native.so], bo6/bo7 [compiled_binding_ocaml.{cmxa,stub-a}],
      bo4 [user_binding_ocaml.mli], etc.).
- [x] **Wired into `canary_main.ml`** — added `run_tiny` and the
      `"tiny"` dispatch case alongside sqlite / zarith / ssl / z3 /
      llvm. `dune exec src/bin/canary_main.exe -- action tiny` runs
      end-to-end.
- [ ] (Stretch) Add Python (cext + ctypes) sub-arms — currently
      only OCaml binding is driven via canary. The tiny harness
      ([scenarios/scenarios.py], [_harness/run_cached.py]) covers
      Python today; folding them into the canary spec needs uv /
      pip command handling that isn't load-bearing for the Phase 4
      alignment milestone.
- [ ] (Follow-up) `canary compat tiny` / `canary verify tiny` —
      the prediction commands work on summary JSONs; tiny's
      api_source flow isn't wired so these aren't directly
      applicable until tiny gets an [api_source] field (parallel to
      z3's). Not blocking for Phase 4.

### Pass 5 — docs sync after each pass

- [ ] After Pass 1 (doc-comments): update `surface_theory.md` §2.7
      "Implementation pointers" table — file-level pointers are now
      navigable by canonical name.
- [ ] After Pass 2 (renames): update CLAUDE.md "Key source files"
      table.
- [ ] After Pass 3 (alias module): document the canonical /
      alias types in `surface_theory.md` and link from this tracker.
- [ ] After Pass 4 (`canary_project_tiny.ml`): update `tiny.md`
      "Not yet wired" section to remove the canary_project_tiny.ml
      gap; close §6 step 4's final bullet in `plan.md`.

## Open questions

- **Wider rename of `Ocaml_mli` / `Python_attrs`** — the variant
  tags work fine as-is. Renaming costs touches across step
  expectations, project specs, and comparator dispatch. Worth it
  for consistency, or leave as a "language-flavoured constructor
  name pointing at a language-agnostic concept" with just a doc?
  Lean toward leaving as-is + doc-comment for Phase 4; flag for a
  later cleanup pass.
- ✓ **`binding_summary` rename** — resolved 2026-05-28: chose
  `binding_user_facing_pkg`. Doc-comment carries a "renamed from"
  note for searchability.
- **Project spec alias inventory** — Phase 4 adds a type for it
  but doesn't require every project to fill it in. For Phase 4 the
  inventory only needs to exist for tiny (driving `canary action
  tiny`); z3/llvm/sqlite can add theirs lazily.

## Notes on code reorganization — deferred

A separate question from the rename pass: should we group core
definitions in one place, and should the modules holding them keep
the `canary_` prefix when the concepts (surface theory, artifact
records, contracts) are broader than canary testing?

**Decision (2026-05-28): keep `canary_` prefix during Phase 4.**
Treat regrouping as a general refactor question for a later pass.
Rationale:

- YAGNI — no second consumer of the surface-theory model exists
  today. Drawing a library boundary against speculative reuse risks
  the wrong line.
- The naming pass tells you the line. After Pass 1 (doc-comments)
  and Pass 2 (renames), files that turn out to use only
  `Canary_action` / `Canary_pm_*` / project specs are clearly
  canary glue; files that touch only artifact/contract/surface
  types are clearly the generic core. The split, when we do it,
  draws itself.

When we revisit (separate refactor, post-Phase-4), three options on
the table:

| | what | structural signal | churn |
|---|---|---|---|
| **A** | Keep `canary_` prefix; doc-comment "generic, extractable" | none | minimal |
| **B** | Drop prefix in module names; keep in canary's dune library | name-level | small renames (+ likely `(wrapped false)` headache) |
| **C** | Split into a sibling dune library `src/surface/`; canary depends on it | library-level | moderate (dune file + every import) |

Option B has a wrinkle: OCaml's default namespace-wrap exports as
`Canary__Surface`. Cleanly un-prefixing pulls in `(wrapped false)`
on the canary library or basically collapses B into C. So when we
revisit, **B vs C is really one decision** — keep the wrap and
accept the prefix, or split the library outright. A stays as the
zero-effort path if the model continues to have only one consumer.

A natural grouping after that future split:

- `surface.ml` (or `canary_surface.ml`): the `s*` types (role /
  side / form / canonical / alias) — the theory vocabulary.
- `artifact.ml` (or `canary_artifact.ml`): the `n*` / `b*`
  artifact-instance vocabulary (kind, location, project-binding
  aliases).
- `contract.ml` (or `canary_contract.ml`): `c1..c8` typed
  enumeration, comparator dispatch.

These names go into Phase 4 with the `canary_` prefix; the future
refactor revisits the question.

## Done criteria for Phase 4

- All passes 1–4 complete.
- `make canary` clean.
- `dune exec src/bin/canary_main.exe -- artifact-test` 28/28 (Linux),
  matches macOS pm-test count from `1b078a2`.
- `dune exec src/bin/canary_main.exe -- pm-test` green.
- `canary action tiny` runs and produces a sensible
  `run_state.json`.
- Pass 5 doc updates landed.

Then Phase 4 closes and §6 step 4 (comparators) picks up with the
aligned vocabulary already in place.
