# Worklog — 2026-07 (Task 1.5 — scenario remodel continuation)

This worklog absorbs the chronicle of the July 2026 scenario-remodel
work that previously bloated SSOT §9.3. The SSOT keeps only the
forward-looking "Next up" pointers and cites this file for the arc.

Backdrop: Task 1 landed a unified `Canary_scenario.scenario` shape
with `perturbation option` (commit `1111ad6` + `13df74e` + `bfc075c`,
late June). Task 1.5 is everything between "the shape exists" and
"the shape is validated by a principled generator and displayed as
one enumeration": drift-catchers on the strings, Good scenarios as
first-class code entries, and a derive-vs-hardcoded coverage view.

## Arc of Task 1.5

Chronological, one paragraph per landing.

### Sc.N registry + start-up validators (2026-07-05, `ab567c9`)

Manifest strings were the first drift risk to close. Bs entries carry
`Definite "Sc.1"` etc., but nothing linked those strings to the SSOT
§4 Good scenarios. Added a per-language `known_ids` list in
`Canary_scenario` (initially `Sc.1..Sc.6`), a `validate_scenario`
routine that walks each Bs's `perturbation.manifest` and asserts the
referenced ids are in `known_ids`, and made `canary_tiny_scenario.ml`
run it at module load via `let () = List.iter … validate_scenario`.
Same routine also asserts `perturbation.target ∈ related_artifacts`
— cheap invariant, previously unenforced. Byproduct: a typo caught
during the next commit's language split fired before the CLI
started.

### Tiny–SSOT integration Phase 1+2A (2026-07-05, `cd92893`)

Threaded a `belongs_to : string list` field onto `scenario` and
populated it for the 13 Bs + 2 Pc via `belongs_to_of_id` — the
`Bs.N` / `Pc.N` prefix carries which Good scenario each perturbation
attributes to, so the mk helpers didn't need per-call updates.
`tiny_good_scenarios` appeared as concrete `scenario` values for
Sc.1..Sc.6, mirroring SSOT §4. `all_scenarios = tiny_good_scenarios
@ (map entries)` gave the united catalogue that later drives `list`.

### `tiny-scenarios list` — show-list-but-no-run (2026-07-06, `9fa470a` + `0f022fc`)

New CLI command surfacing the enumeration. First cut printed the 21
entries flat; second cut nested Bs and Pc under their Good scenario
via `belongs_to`. Format:

```
Sc.1  build_native_lib
  related: A1(source), A2(lib)
  perturbations (7):
    Bs.1 symbol_missing  A1  [c1]
    ...
  verified by (N): ...
```

Language-as-outer-loop grouping (Shared / OCaml / Python) came from
user feedback: mechanism-specific perturbations read cleaner grouped
by language than interleaved.

### Language split — Sc.1 shared, Sc.N.OCaml, Sc.N.Python (2026-07-06, `4651a81`)

Sc.2..Sc.6 turned out to be language-instances of one abstract
scenario each (e.g. `build_binding` fires once for OCaml, once for
Python — different mechanisms, different cells). Renamed
`known_ids` → per-language lists, split `good_scenarios` into 8
entries: `Sc.1` (shared, native lib is language-agnostic under
SCAB), `Sc.2..Sc.6.OCaml`, `Sc.2/Sc.4.Python` (Python has fewer
stages under SCAB — no separate binding-build variant). The validator
caught 13 pre-existing `Definite "Sc.4"` typos immediately (should
have been `"Sc.4.OCaml"`).

### Mechanism + absence-vs-sharing notes (2026-07-06, `7c726f5`)

User pointed out that SCAB (static C API binding) is one of two
Python mechanisms — DFFI (dynamic FFI via `ctypes`) is the other,
and it doesn't have a build_binding stage at all. Rather than model
mechanism as a first-class axis today, hardcoded SCAB and added a
note that mechanism-→-scenarios is future work. "Absent" (a
mechanism has no Sc.N) and "shared" (Sc.1 covers all mechanisms)
are distinct semantics; noted for later.

### `derive_scenarios` experiment (2026-07-07, `9bb16bc`)

Added `Canary_scenario.derive_scenarios : scenario list -> scenario
list`. For each Good scenario, for each related artifact, for each
applicable perturbation kind (`On_artifact <same>` always;
`On_behavior` only for `Source`), emit a derived-cell scenario with
`manifest = Unknown_gap` and `detector = Detector_gap`. Ran against
tiny's 8 goods: 20 cells. Diffed against the 13 Bs via
`matches_derived_cell` (same belongs_to + same target + same kind):
5 filled, 15 empty, 0 extras. New `tiny-scenarios derive` CLI
printed the coverage report.

### Fold coverage into `list` (2026-07-07, `e0c1399`)

User read the `derive` output and asked what its purpose was
relative to `list`. Framed as two views of one enumeration: `list`
was the concrete inventory, `derive` was the principled space. User
picked Option 1: merge coverage into `list`. Refactored `print_list`
to iterate `derived_scenarios` (filtered per Good) instead of
entries directly; each cell now shows filling Bs entries or `—
empty`. Dropped the `derive` command. Header line now reports both
axes: `Scenarios (23 total: 8 good + 13 bad + 2 positive; 20
derived cells, 5 filled, 15 empty)`.

### SSOT §9.3 flush (2026-07-07, `b90368e` → this file)

Purged the four "Confirmed next" checklist entries (all done via
the commits above); replaced with a "Task 1.5 done" summary block
and a "Next up" block for Task 1.6. Then split the arc off into
this worklog file to keep SSOT lean.

## Final state (end of Task 1.5)

- `Canary_scenario` gained: 8-entry `good_scenarios`, per-language
  `known_ids`, `validate_scenario` (Sc.N-in-manifest + target-in-
  related-artifacts), `applicable_perturbations`, `derive_scenarios`,
  `string_of_perturbation_kind`.
- `Canary_tiny_scenario` gained: `tiny_good_scenarios` (mirror of
  SSOT §4), `belongs_to_of_id` (mk-helper glue), `all_scenarios`,
  `derived_scenarios` (20 cells), `matches_derived_cell`,
  `print_list` refactored to iterate cells with coverage tags.
- CLI: `tiny-scenarios list` merges inventory + coverage view;
  `tiny-scenarios derive` no longer exists (info folded in).
- Drift risks closed: manifest `Sc.N` typos, `perturbation.target`
  outside `related_artifacts`.
- Enumeration principle validated against tiny: every hand-listed Bs
  fits a derived cell (0 extras) — the generator admits everything
  hand-declared, so we can trust it going forward.

## Coverage snapshot for Task 1.6 planning

`tiny-scenarios list` output (2026-07-07) reveals:

| Good scenario | Cells | Filled | Empty | Notes |
|---|---|---|---|---|
| Sc.1 | 3 | 3 | 0 | Fully covered by Bs.1–Bs.7 |
| Sc.2.OCaml | 2 | 1 | 1 | A1 (lib) cell empty |
| Sc.3.OCaml | 2 | 0 | 2 | Zero Bs — Pc.1 verifies only |
| Sc.4.OCaml | 3 | 0 | 3 | Zero Bs — Pc.1 verifies only |
| Sc.5.OCaml | 2 | 0 | 2 | Zero Bs — Pc.2 verifies only |
| Sc.6.OCaml | 3 | 0 | 3 | Zero Bs — Pc.2 verifies only |
| Sc.2.Python | 2 | 1 | 1 | A1 (lib) cell empty |
| Sc.4.Python | 3 | 0 | 3 | Zero Bs — no Pc either |

Sc.3–Sc.6 zero-Bs coverage matches SSOT §5.1 observation 2. The
Sc.N/A1 (lib) empty cells at Sc.2.OCaml, Sc.2.Python, Sc.4.Python
are the closest candidates for "extend Task 1.5's enumeration with
concrete Bs" — they represent lib perturbations manifesting only via
that language's binding, distinct from Bs.4 (abi_soname_bump,
attributed to Sc.1).

## Task 1.6 — A2-with-factory (2026-07-07 → 08)

Retires the multi-variant `run_tiny` in favour of a factory
that turns each `entry` into a self-contained project spec.
Every tiny scenario now runs via
`canary action tiny-scenario/<name>` (or the run-all
`canary action tiny-scenario`). See
[`tiny.md`](../design/tiny.md) for the shipped
factory shape.

### Arc

- **`a1ee985` MVP factory (2026-07-07)** — new module
  `canary_tiny_scenario_project.ml`, `script_spec_of_entry`
  dispatches on scenario name for symbol_missing only, calls
  `make_lib_broken_script_spec`. CLI dispatch
  `tiny-scenario/<name>` runs one scenario via `run_project`
  (not multi). Semantic parity with `tiny/lib_broken`.
- **`61af683` Y direction — c1 structural derivation** —
  `expectation_of_entry` computes the expectation from
  `recipe.violates` (c1 only) instead of dispatching by name.
- **`744a137` — language scoping via `belongs_to`** —
  `langs_of_scenario` reads Sc.N.OCaml / Sc.N.Python /
  Sc.N suffixes. Discovered `symbol_orphan` bug: firing c1 at
  both langs was wrong; scoped to OCaml only. Design captured
  in [`design/tiny.md`](../design/tiny.md).
- **`c885108` — c2 derivation** — `compat_inputs_of_contract`
  refactor. Now scenarios pick their inputs by folding over
  `recipe.violates`. api_complete + api_complete_python
  work. 4 derived, 11 to go.
- **`63b1a5a` R1 — fill dispatch table for all 15** —
  user chose "R1 first" (coverage-first) over "R2 only"
  (derivation-only). Named dispatches for the 11 non-derivable
  entries; 15/15 runnable via factory. Sets baseline for
  measurable progress in subsequent commits.
- **`dd32db8` B — run-all + factory route in list** — new
  bare-project dispatch `canary action tiny-scenario` runs
  all 15 in `tiny-scenarios list` order with `[i/N] <id>
  <name>` progress. `list` output annotates each entry with
  `[derived]` / `[dispatched]` / `[base]` via a mutable
  `annotate_ref` on Canary_tiny_scenario (keeps the
  scenario module free of factory dependencies).
- **`b97dfa3` C.1 — c3 + c7 (Expect_failure shape)** —
  second expectation shape lands. `is_expect_failure_contract`
  covers c3 (behaviour) and c7 (repack). Manifest gate on
  `route_of_entry`: `Unknown_gap` → base, so
  `api_repack_stub_orphan` (c7 static-only) stays base while
  `api_repack` moves to derived. 4 more scenarios switch to
  derived (behavior_silent, type_wrong, api_repack,
  api_repack_python) → 8 derived / 3 dispatched / 4 base.
- **`c85f631` D.a — auto-init prepare workspace** —
  `run_tiny_scenario` checks `_cache/<name>/workspace/` and
  auto-runs baseline + prepare if missing. Single-command
  experience: `canary action tiny-scenario/<name>` now
  works from a clean checkout.
- **`9152192` C.2/C.3/C.4 — c4 + c5 + c6 derivation** —
  extends `compat_inputs_of_contract` with the three
  remaining compat contracts. c4/c5 are Python-only in tiny's
  store convention (cached cext, fresh OCaml binding);
  c6 is OCaml-only (fresh binding rebuilds against
  perturbed header). c6 uniquely fires at `Build_binding`
  in addition to `Probe`. `stores_of_entry` derives
  `lib_filename` override from `Soname_bump { to_so }`.
  Dispatch table empty. 11 derived / 0 dispatched / 4 base.
- **`6f0cd9b` A — retire run_tiny** — removes `run_tiny`
  from canary_main.ml and 10 `make_*_broken_script_spec`
  helpers from canary_project_tiny.ml (334 lines gone,
  18 added — net −316 in the tiny plumbing).
  `canary action tiny/<name>` still works, routes to
  factory. Factory is the only path.

### Final state (Task 1.6 complete)

- CLI:
  - `canary action tiny-scenario/<name>` — one scenario
  - `canary action tiny-scenario` — all 15 in `list` order
  - `canary action tiny/<name>` — back-compat alias
- Factory (`canary_tiny_scenario_project.ml`):
  - `route_of_entry` — 3-way classification
  - `expectation_of_entry` — derives from
    `recipe.violates × langs × rule-site`
  - `compat_inputs_of_contract` — per-contract per-lang
    input paths (c1, c2, c4, c5, c6)
  - `is_expect_failure_contract` — c3, c7
  - `stores_of_entry` — perturbation-driven store
    adjustment (soname bump)
  - `route_of_entry` published for `tiny-scenarios list`
    annotation
- Auto-init: workspace materialised on first run.

Coverage:

| Route | 15 entries | Notes |
|---|---|---|
| `Derived | 11 | All Bs with probe manifestation |
| `Base | 4 | api_faithful (c8 dormant), api_repack_stub_orphan (c7 static-only), Pc.1, Pc.2 |
| `Dispatched | 0 | Empty — dispatch removed 2026-07-08 |

### Design references saved for the next task

- [`design/tiny.md`](../design/tiny.md) — what
  shipped (factory shape). Slimmed from an in-progress note
  to a landing reference after retirement.
- [`design/bad_scenario_flavors.md`](../design/bad_scenario_flavors.md)
  — the flavor-1 (artifact-local defect) vs flavor-2
  (cross-artifact mismatch) split; catalogue completeness as
  next research task; tiny as bug-categorisation foundation.

### Forward look

Immediate follow-ups (not in this task):

1. **Fill the 15 empty derived cells** in `tiny-scenarios list`
   with concrete flavor-1 perturbations. Mechanical once
   `tiny_recipe` synthesis lands (SSOT §9.3 backlog item 2).
2. **Grow the flavor-2 catalogue** — cull real-world bugs
   for failure kinds not covered by c1..c8; propose new
   contracts. Foundation is now stable; see
   [`bad_scenario_flavors.md`](../design/bad_scenario_flavors.md).

## R2 arc — route tiny through `tool/` (2026-07-09)

**Status: complete.** Both sub-gaps of `design/tiny.md §7.7`
shipped this session; that section now points here for the
completion detail and keeps only the macOS-verification
open item.

Motivation (from `tiny.md §7.7` pre-flush): tiny's
baseline/prepare pair inlined raw compiler + inspector shell
commands instead of routing through `src/canary/tool/`.
Two hazards: (a) hidden flag surface (portability fixes
can't be applied in one place); (b) drift risk between tiny
and other projects that already use the tool builders.

### Sub-gap 1 — direct-compile family (`2930a35`)

**Problem.** `canary_build_cmd.ml` covered cmake/ninja/dune
only; no primitive for gcc / ocamlfind / ar. Tiny's
`build_c_lib` / `build_ocaml_binding` / `build_python_cext`
Printf.sprintf'd 7 raw compile commands.

**Solution.** New file `src/canary/tool/canary_cc.ml`
(~110 LOC). Six primitives:
`cc_compile_obj`, `cc_link_shared` (with optional soname /
version-script / rpath / include_dirs / library_dirs /
libs), `ocaml_compile_unit`, `ocaml_archive_cmxa`,
`ar_archive`, `symlink`. `canary_tiny_workspace.ml`'s three
build fns refactored to call them.

**Byte-stability.** After refactor, `tiny prepare-all`
(15 scenarios × 7 inspectors) + `tiny baseline` (7 inspectors)
produced 110 inspect JSONs byte-identical to the
pre-refactor snapshot. `tiny run` 15/15 PASS.

### Sub-gap 1½ — JSON schema tests (`8bf910b`)

**Problem.** The `_cache/*/inspect/*.json` schema is
project-standard (7+ producers, 8+ consumers all shell out
to the same 4 `inspect_*.py` scripts). Sub-gap 2 would
refactor callers; nothing pinned the schema at the script
level.

**Solution.** Per-script schema tests in
`canary_artifact_test.ml`: one `_schema_cmd` helper per
kind (`native`, `ocaml`, `ocaml_mli`, `c_stub`, `python`),
wired into the existing four shell-test groups. Each check
asserts the `kind` literal, required top-level keys, and
type-checks values where the shape is fixed. `78/78`
artifact-test after.

### Sub-gap 2 — inspector pipe primitives (`d0fb81e`)

**Problem.** Tool builders in `Canary_artifact_native` and
`Canary_artifact_lang` emitted "write JSON to
`<output_dir>/<marker>`" commands (runner path); tiny
wanted capture-JSON-to-stdout for reference cache assembly.
Impedance mismatch — the pipe was the same, only the
redirect differed.

**Solution.** Added `_pipe_cmd` variants of each tool
builder (native `inspect_pipe_cmd`; lang
`inspect_pipe_cmd` for ocamlobjinfo, `mli_inspect_pipe_cmd`
path-based, `stub_inspect_pipe_cmd` path-based,
`python_inspect_pipe_cmd` with optional `env` prefix). The
existing `_cmd` builders now compose the pipe with
`" > <out>"`. Five of the six tiny inspectors refactored
to the pipe primitives.

**Incidental bug fix.** The old `inspect_bo6` called
`python3 inspect_ocaml.py --path <cmxa>` **without piping
`ocamlobjinfo <cmxa>`** into it. `inspect_ocaml.py` reads
ocamlobjinfo output from stdin, so it saw an empty stream
and always emitted
`{"counts": {"imports": 0, "modules": 0}, "modules": []}`.
The tool-builder pipe primitive correctly pipes; bo6 now
reports `{"modules": ["Tiny_raw", "Tiny"], "imports": 7}`.
Downstream `surface_delta` still emits `bo6: (no delta)`
for spot-checked scenarios (their mutations don't add or
remove modules).

### Sub-gap 2 follow-up — retire the last hand-rolled inspector (`3445276`)

`inspect_bpe3` (cext `.so` → filter tiny_ prefix → c_stub
JSON) was hand-rolled: `nm -u | awk | sort -u | python3 -c
"..."`. Turns out `inspect_binding.py --kind stub` already
detects `.cpython-*.so` and uses `nm -D` natively. Routed
through `stub_inspect_pipe_cmd`. Byte-drift on `bpe3.json`:
gains `versioned_req`, `watchlist`, `elf` fields the
hand-rolled version omitted; `requires` set identical; no
new deltas fire on spot-checked scenarios (cext is
snapshot-copied from baseline per scenario, so its
NEEDED/soname don't drift).

**Result.** Zero hand-rolled inspect commands remain in
`canary_tiny_workspace.ml`; all six inspectors go through
tool-builder pipe primitives. Portability dividend real:
tiny's inspectors inherit `Canary_artifact_native.nm_cmd`'s
`nm -g` on macOS choice. Verification on macOS is the one
remaining open item — separate SSH-Mac session (see
CLAUDE.md Known-Gap on macOS).

### Doc pass (`2132a36`)

`tiny.md §7.7` rewritten from a two-sub-gap plan to a
completion note pointing at the four commits + the macOS
open item.


## Task 2 prereq — baseline non-tiny projects (2026-07-17)

Before starting Cluster B (Task 2 — recipe/mutation
integration), ran the three non-tiny projects to capture
current behavior:

- `canary action sqlite` — 7/7 steps done. Fetch-only path
  (stdlib sqlite3 + apt libsqlite3-dev); no build_lib /
  build_binding. Positive-only, no Expect_compat_failure.
- `canary action z3` — dev variant 22/22 + stable 7/7.
  Stable variant fires
  `Expect_compat_failure { inputs = Python_attrs [...] }`
  at `Probe_binding Python`; log confirms:
    "expected failure confirmed (derived): z3-solver pip
     wheel predates z3.parser_context, added in Z3 4.15+
     Python source (not yet exported in pip wheel)".
- `canary action llvm` — dev variant 27/27 + stable /19
  14/14. Compat-failure prediction machinery hand-coded at
  [`canary_project_llvm.ml:495-512`](../../src/canary/projects/canary_project_llvm.ml#L495-L512)
  with `Ocaml_mli` inputs + version_info naming
  `Opcode.UncondBr`. Investigated apparent shape drift
  (only 3 of 14 steps logged today vs full log on
  2026-05-06): confirmed as
  [`canary_local_runner.ml:302-305`](../../src/canary/backend/canary_local_runner.ml#L302-L305)
  fast-skip pre-seed. `run_graph` seeds `status = Step_done`
  for any step whose postcondition already passes,
  without emitting a log line; the loop only runs steps
  NOT in the status table. Today's run trusted the
  2026-05-06 artifacts for probe_binding_ocaml + probe_lib
  + others — check_post said "done from before" and
  they were seeded silent. Not a Phase G bug. Force-verify
  by wiping `_out/canary/projects/llvm` before running.

**Fixed en route** (`1af76e8`): `probe_rule_of_kind` in
`canary_diagram.ml` was a Phase G leftover — it
`Stdlib.failwith`'d on Headers/Source kinds. z3's diagram
iterates `present_kinds` (a wider set than probe_kinds)
which surfaced the bug. Changed to return `rule option`;
guards Source/Headers as `None`.

**All three projects run clean**; Task 2 Phase 1 can start.
Hand-coded Expect_compat_failure predicates in
llvm (:495-512, ~18 LOC) and z3 (:541-551, ~10 LOC) are
the retirement targets for Phase 3 and Phase 4.

**Session-split decision** (per user 2026-07-17 —
hesitant to touch llvm/z3 in the same session as new
recipe code): Phase 1 lands alone (~50 LOC of type defs,
nothing wired in) as a small session; Phase 2 (tiny
refactor to use the new types) in the next session;
Phases 3/4/5 (per-project refactors) as later, independent
follow-ups. Small blast radius per session; easy bail-out
mid-phase.

### Rescope: Task 2 postponed → §7.2 picked up (2026-07-20)

Reviewing Task 2 scope: extracting a project-hookable
recipe interface for z3/llvm/sqlite ran ~230 LOC of
plumbing for ~28 LOC of hand-coded predicates. Concluded
ROI marginal until (a) more projects use the pattern
(PyTorch, cvc5, …), (b) tiny's recipe machinery is
concrete enough to lift, (c) expectation/contract model
settles. sqlite/z3/llvm are "second-tier" per the
**ssot-tiny-canary sync line** — flush from the
tiny+SSOT+code trio once it stabilises; don't touch them
until then.

Operating principle laid down: work code-first, doc-synced
— each wish-list phase commit carries the SSOT/tiny.md
sync bits it opens up. Modeling questions (Sf/Ar alignment,
c8 wiring, expectation shape, …) get resolved as side
effects of code decisions, not as prerequisite doc rounds.

Task 2 parked at `design/tiny.md §7.8`. Picked §7.2
(`tiny_recipe` synthesis from an abstract cell) as the
next active item.

**Parked plan (moved from `design/tiny.md §7.8` on 2026-07-20 as
part of the finish-flush pass; kept here so the design intent
survives when we come back to it):**

Sequel to Phase G. Phase G (2026-07-09) unified
`Canary_scenario.scenario` — `.origin` replaced `.mutation`;
nullary `Version_mismatch` and `Packaging` reserved. That
was the *scenario*-side integration. The *recipe*-side gap
remains:

- Tiny defines `tiny_recipe` in
  `canary_tiny_scenario.ml:60`:
  `{ mutates; mutation; expected; violates }`. Factory
  functions (`stores_of_entry`, `expectation_of_entry`,
  `project_spec_of_entry`) derive the runnable `project_spec`
  from it. `expectation_of_entry` reads `violates + language`,
  delegates to `compat_inputs_of_contract ~lang c` for JSON
  paths, wraps in `Expect_compat_failure { inputs;
  version_info }`.
- z3 / llvm / sqlite have **no parallel**. Their variants
  hand-code `Expect_compat_failure` inline in the project
  spec — llvm's stable variant spells out the predicted
  substring by name (`canary_project_llvm.ml:495-512`, 18
  lines: `Opcode.UncondBr` version_info); z3 stable Python
  variant same shape (`canary_project_z3.ml:541-551`, 10
  lines: `parser_context`). Structurally identical to
  tiny's derivation, just typed out inline.

Goal: lift tiny's recipe/factory pattern into a
project-hookable interface so z3 / llvm / sqlite can supply
their own recipes and inherit the uniform derivation.

Phased plan (~230 LOC total; non-breaking per phase):

| Phase | Scope | LOC |
|---|---|---|
| **1. Generic recipe shape** | New module `Canary_recipe` (or extend `Canary_scenario`) with project-agnostic fields: `type recipe = { violates; expected; mutates }`. `tiny_recipe` becomes `{ generic : recipe; concrete_pert : mutation option }` (concrete tiny extras stay tiny-specific). No behavior change. | ~50 |
| **2. Project hooks + generic expectation deriver** | Extract `expectation_of_scenario ~hooks ~scenario`, where `hooks : { compat_inputs_of_contract; version_info_of_origin }` is project-supplied. Tiny becomes the reference implementation. Behavior byte-identical to today. | ~80 |
| **3. llvm refactor** | Add `llvm_recipe` (or use generic directly) + `llvm_hooks` with opam-path-flavored `compat_inputs_of_contract`. Replace the hand-coded `Expect_compat_failure` with recipe-driven derivation. `Version_mismatch` origin becomes the natural fit. | ~40 |
| **4. z3 refactor** | Same shape as llvm. Python variant (`Probe_binding Python`). | ~40 |
| **5. sqlite refactor** | Smallest — positive-only, so just plug in hooks; no expectation change. Sanity that the interface fits both compat-failure and positive-only projects. | ~20 |

Verification per phase: (1&2) `canary artifact-test` +
`canary tiny run` (behavior-preserving); (3) `canary action
llvm` — stable must still produce `Opcode.UncondBr` prediction;
(4) `canary action z3` — `parser_context` prediction unchanged;
(5) `canary action sqlite` — plain success.

Prerequisite when this is picked up: run all three non-tiny
projects locally to capture current behavior (catches
bit-rot in the specs since R2 / Phase G).

Out of scope for Task 2 itself: `scenario.actions` runtime
sync (best as Task 2 follow-up), `Package` origin variant
activation (needs a project that wants it — PyTorch tier-1).

Note: §7.2 shipped 2026-07-20 with the current recipe
shape. Task 2 will change the shape, so its plan may need
re-baselining once picked up.

### §7.2 Phases 1-4 shipped (2026-07-20)

Four-phase remodel of tiny's mutation vocabulary + derived
cells. Goal: make derived cells (from
`Canary_scenario.derive_scenarios`) *runnable* rather than
name-only, so §7.1 (fill empty cells) becomes data-driven
instead of hand-authoring per Bs.

**Phase 1 — per-artifact mutation modules
(`canary_artifact_mutation.ml` rewrite, ~230 LOC + 200
test LOC)**. Replaced the flat `mutation` type with
`module Source | Native | Binding` — each artifact-flavor
owns its own variants, `apply_cmds`, and constructor
naming. Top-level union
`Of_source | Of_native | Of_binding | Patch`.  Four
parametric variants land today: `Rename_c_symbol`,
`Rename_version_tag`, `Soname_bump`, `Drop_ocaml_val`.
`Drop_c_symbol` + `Drop_python_attr` deferred as
*missing but visible* — return `None` from synthesis
rather than fake an implementation; the design principle
"missing-ness visible" carries through. Byte-identical
parity to existing tiny patches verified via `diff -r`
regression tests
(`canary_artifact_test.ml:mutation_regression_tests`).
Bug caught mid-flight: `patch` command couldn't find
patch file after `cd`; fixed by absolutizing via
`readlink -f` and wrapping in a subshell so the `cd`
didn't leak. User feedback along the way: *"mutation is
just our perspective; from a more artifact-centric
perspective, it's just another artifact"* — motivated the
per-artifact submodule layout.

**Phase 2 — workspace dispatch
(`canary_tiny_workspace.ml`, ~30 LOC net)**. `run_prepare`
now dispatches through per-artifact `apply_cmds`: source /
binding mutations pre-build, native mutations post-build.
Retired the ad-hoc `apply_soname_bump` local wrapper.
Bs.4's recipe migrated to full-name SONAMEs
(`libtiny.so.1.0 → libtiny.so.2.0`).  Bs.4 stays 13/13.
`Of_source` / `Of_binding` dispatch is dead-code today
until Phase 3 emits recipes that use them.

**Phase 3 — recipe synthesis
(`recipe_of_derived_cell` in `canary_tiny_scenario.ml`,
~150 LOC)**. Enumerated `(target, kind) → mutation` table:
Source × On_artifact Source → `rename_c_symbol
tiny_sum→tiny_total`; Lib × On_artifact Lib →
`soname_bump 1.0→2.0`; Binding OCaml × On_artifact Binding
OCaml → `drop_ocaml_val sum`. Other cells return `None`
until their primitive lands (Binding Python needs
`Drop_python_attr`; App has no primitive; Headers /
On_behavior stay `Patch`-flavored).
`derived_scenario_specs` enumerates all 20 cells and
returns the ones that synthesize. Default target
(`tiny_sum` for source, `sum` for mli) hardcoded per the
2026-07-09 decision; heuristic picking from
`api_source.stable_symbols` is future work.

**Phase 4 — fold derived cells into `all_scenario_specs`
(~50 LOC + three bug-fix rounds)**. Concatenates hand +
derived, deduplicating derived against hand via
`matches_derived_cell`.  Bugs hit and fixed in flight:

1. **Name collision** — `derive_scenario` was using
   `good.name` to build derived-cell names, but
   `good.name` isn't unique across Sc.N × language (both
   Sc.2.OCaml and Sc.2.Python name their step
   `build_binding`). Fix: use `good.id`. Now
   `mutate_<kind>_at_<good.id>` naming convention.
2. **Manifest inheritance** — derived cells inherited
   `manifest = Unknown_gap` from the base `scenario`
   record, so `has_probe_manifestation` returned false →
   the factory fell through to `Expect_success` → probe
   actually failed → unexpected_failure across the board.
   Fix: `scenario_spec_of_derived_cell` rebuilds the cell's
   origin with `manifest = Possible cell.belongs_to;
   detector = Wired first_violated_contract`.
3. **OCaml Lib cells failing** —
   `compat_inputs_of_contract ~lang:OCaml C4` returns
   `None` (tiny convention; c4 not wired for OCaml). Fix:
   guard `(Lib, On_artifact Lib)` synthesis on Python
   being in the cell's langs, so Sc.2/4/6.OCaml Lib cells
   return None until c4 wires for OCaml.

Final counts: 9 cells synthesize, 3 dedup against
Bs.1/4/8-13 → **6 net new derived cells**.
`all_scenario_specs = 15 hand + 6 derived = 21`. Coverage
in `tiny list`: **11/20 filled** (up from 5/20), 9 empty
awaiting `Drop_c_symbol` / `Drop_python_attr` / App
primitives plus OCaml-c4 wiring. Startup assertions guard
the counts (`expected_some=9`, `expected_none=11`,
`expected_derived_after_dedup=6`) so silent drift is
caught at module load.

`tiny run` reports **20/21 PASS**. The one fail is
`type_wrong` (c6 flake in hand-authored Bs.5, unrelated
to Phase 4).  `artifact-test` stays 98/98.

**Doc-sync riders landed with each phase**:
- Phase 1 → SSOT §5.3 "Mutation shapes (parametric
  vocabulary)"
- Phase 2 → tiny.md §3.4 "Mutation dispatch in workspace
  prep"
- Phase 3 → SSOT §5.2 synthesis-path pointer
- Phase 4 → tiny.md §6 coverage recount (11/20 filled)

### §7.1 first primitive: Drop_python_attr shipped (2026-07-21)

Cheapest of the three §7.1 blockers to land. Added
`Binding.Drop_python_attr { file; name }` to
`canary_artifact_mutation.ml` — a sed-range primitive that
deletes from `^def <name>(` through the next blank line.
Byte-parity with `api_complete_python.patch` (its
python_cext hunk) verified in `mutation_regression_tests`
via the same `diff -r` anchor pattern used for the other
parametric primitives.

Wired `(Binding Python, On_artifact (Binding Python))` →
`drop_python_attr ~file:"python_cext/tiny_cext/__init__.py"
~name:"sum"` into `recipe_of_derived_cell`. Two new
synthesized cells: one on Sc.2.Python.A2 (dedup vs Bs.12
api_complete_python) and one on Sc.4.Python.A1 (new
coverage — the `mutate_python_binding_at_Sc.4.Python`
cell).

Startup counts:
- `expected_some`: 9 → 11
- `expected_none`: 11 → 9
- `expected_derived_after_dedup`: 6 → 7

Test surface: `artifact-test` 98 → 101 (+3: pure
constructor, shell apply, regression parity). `tiny run`
21/22 PASS (the one fail is still `type_wrong` c6 flake
in Bs.5, unrelated).

**Coverage**: `all_scenario_specs` = 15 hand + 7 derived
= 22; `tiny list` shows 12/20 cells filled (up from
11/20). Remaining 8 empty cells: 3 OCaml `lib` (blocked
on c4 wiring for OCaml) + 5 `app` cells across
Sc.3/4/5/6 OCaml + Sc.4.Python (blocked on App-level
primitive).

**Design decision**: sed-based rather than ast-based. The
CLAUDE.md gotcha "sed cannot distinguish match-case scope"
applies to sed on OCaml; on Python it's fine as long as
we accept the limitation (blank-line-separated defs; no
decorator support). Documented as such in the module
docblock; upgrade to ast-based when a project needs the
richer vocabulary.

**Doc-sync riders**:
- `derived_vs_hardcoded.md` §1 counts + §4 primitive list
  refresh + §5 blocker recount
- `ssot.md` §5.2 coverage + §5.3 "Missing on purpose" →
  "Recently added"
- `tiny.md` §6 coverage recount + §7.1 blocker table
  (removed Drop_python_attr row, added shipped marker) +
  picking-order status

### §7.1 pause — structural expectation rewrite (2026-07-21)

Motivation: two remaining §7.1 blockers (c4-OCaml wiring, App
primitive) both push against the same seam in
`expectation_of_entry` — an ad-hoc switch table that hardcodes
`if c6 then Build_binding else Probe_binding`. Adding either
blocker as-is would accumulate 2-3 more `match rule with`
branches in the OCaml code (same accretion pressure that
Task 2 also blocks on per its "expectation/contract model
settles" prerequisite). User asked (2026-07-21) whether §7.1
remainder should ride the special-case path or wait on
unification; chose unification with placeholder tolerance.

**Two-category framing** (per user, 2026-07-21): contracts
source their observations from *both* the artifact face
(static: symbols, mli, headers checked at build/inspect
time) and the runtime/behavior (probe execution outcome).
Today `Expect_compat_failure` is already a hybrid — its
SOURCE is artifact-static (read cached JSONs, diff), its
CHECK is behavior-dynamic (grep). Make the seam explicit.

**Step 1 — behavior-preserving lowering (byte-parity)**:

New vocabulary in `canary_scenario.ml` (project-agnostic):

- `firing_site` — where a contract's failure observation
  surfaces: `At_build_binding lang | At_probe_binding lang |
  At_build_app lang | At_probe_app lang`. Companion
  `firing_site_of_rule : rule → firing_site option` projects
  a concrete runtime rule down for lookup.
- `expectation_source` — how the observation is derived:
  `From_artifact { inputs }` (read cached inspect JSONs;
  contract's predict closure emits substrings) |
  `From_behavior_grep { contains_any }` (assert log contains
  substring) | `Placeholder { reason : string }` (shape
  committed, content TBD; emits Expect_success at runtime).
- `contract_binding` — a per-(contract, lang) declaration of
  `firings : (firing_site * expectation_source) list`. One
  contract can fire at multiple sites (c6 fires at both
  Build_binding and Probe_binding).

Data half in `canary_tiny_scenario.ml`: `tiny_contract_bindings :
contract_binding list` populated with all currently-wired
tiny contracts (c1/c2/c3/c4/c5/c6/c7). c4-OCaml and c8-OCaml
enter as `Placeholder` bindings with the reason string
documenting the SSOT-level question that's still open. Both
were previously either silently-guarded-out (c4-OCaml)
or Unknown_gap-based (c8) — the placeholder makes them
visible.

Rewrite of `expectation_of_entry` (~40 LOC → ~40 LOC):

- Delete `compat_inputs_of_contract ~lang c` (subsumed by
  the binding table).
- Delete `is_expect_failure_contract` (subsumed).
- New body iterates `violates × scenario_langs`, looks up
  each pair in `tiny_contract_bindings`, filters `firings`
  by `firing_site_of_rule rule`, picks the highest-priority
  source (Artifact > BehaviorGrep > Placeholder-skip).
- Falls through to `Expect_success` in the same cases as
  before.

**Behavior preserved byte-identically**: `tiny run` 21/22
PASS (same one `type_wrong` c6 flake), `artifact-test`
101/101 (unchanged). No new tests needed — the switch table
is now data but produces the same step_expectation output
for every (scenario, rule, lang) triple as the old ad-hoc
branches did.

**Step 2 — synthesis guard reads the binding table**:

`recipe_of_derived_cell`'s `Lib × On_artifact Lib` guard
used to hand-check `List.mem langs Python` — mirroring the
fact that `compat_inputs_of_contract ~lang:OCaml C4`
returned None. Now consults `Canary_scenario.binding_has_live_firing
tiny_contract_bindings C4 lang`: skips synthesis when the
lang has no live firing for c4 (Placeholder counts as
non-live). Same output (OCaml Lib cells stay empty), but
the *reason* is now data — when c4-OCaml gets wired later,
the guard automatically lets the cells synthesize without
code change. This is the payoff of the placeholder pattern:
the guard collapses from "hand-coded Python-in-langs check"
to "consult binding status".

**Startup validator** added: any scenario claiming
`manifest = Possible _` (expects to fire) must have at
least one live firing across its `violates × langs`. Catches
"you wired a Bs entry expecting failure detection, but every
contract you listed is a Placeholder" — a design gap that
would otherwise emit silent Expect_success.  Currently zero
offenders; validator loads clean.

**Code net**:
- `canary_scenario.ml`: +80 LOC (types + `firing_site_of_rule` +
  `binding_has_live_firing`)
- `canary_tiny_scenario.ml`: +140 LOC (`tiny_contract_bindings`
  data) - 60 LOC (deleted `compat_inputs_of_contract` +
  `is_expect_failure_contract`) + 15 LOC net for the rewritten
  `expectation_of_entry` + guard change + validator.
- Net: ~+175 LOC. Larger than the 2-3 special-case branches would
  have cost, but the accretion pressure is now data-shaped, not
  code-shaped. Adding a contract binding for a new (contract,
  lang) is one row. Wiring a Placeholder is a source-variant swap.

**Doc-sync riders**:
- `ssot.md` §5.4 (new) "Contract bindings" — types +
  Placeholder principle
- `tiny.md` §7.1 refresh (blockers now framed as Placeholder
  wirings, not "hand-coded guard removals")
- `derived_vs_hardcoded.md` §1/§2 update + note the parallel
  between mutation Placeholders (§5.3) and contract binding
  Placeholders (§5.4)

**Follow-ups opened**:
1. When c4-OCaml is wired (Placeholder → `From_artifact { inputs
   = ... }`), the guard in `recipe_of_derived_cell` automatically
   synthesizes Sc.2/4/6.OCaml Lib cells. No code change.
2. When App primitive lands, need `At_build_app lang` or
   `At_probe_app lang` bindings for whichever contracts the App
   primitive can trigger.
3. z3/llvm/sqlite still hand-code `Expect_compat_failure` inline
   (their variants don't go through tiny's lowering). Task 2's
   project-hookable factory would let them supply their own
   `<project>_contract_bindings` table; the shape is now proven.

### Task 2 Phase A shipped — lowering lifted (2026-07-21)

Post-structural-rewrite re-scope: the parked Task 2 plan's
Phase 2 ("project hooks + generic expectation deriver") is
materially done — the binding table IS the hook shape. Remaining
Task 2 work re-planned into 6 smaller phases (A-F, ~145 LOC vs
the original ~230):

- **A** — Lift binding-lookup lowering into project-agnostic
  `Canary_scenario.lower_expectation`. Tiny becomes a thin
  wrapper.  ✅ shipped 2026-07-21.
- **B** — Loc-awareness (bindings filter by Pm location; llvm's
  Python probe is Expect_success while OCaml probe fails).
  ✅ shipped 2026-07-21 (B1: per-firing `loc_filter`).
- **C** — `version_info` in bindings (extend `From_artifact` or
  add per-binding field). ✅ shipped 2026-07-21 (C1: per-source
  `version_info` on both `From_artifact` and `From_behavior_grep`).
- **D** — llvm migration (declare `llvm_stable_contract_bindings`,
  replace inline `Expect_compat_failure`).
- **E** — z3 migration (same shape, Python variant).
- **F** — sqlite migration (empty bindings; sanity that the
  interface fits positive-only).

**Phase A code**: `Canary_scenario.lower_expectation
~bindings ~violates ~langs ~has_manifest : rule → loc →
step_expectation` extracted from tiny's `expectation_of_entry`.
Byte-preserving: same source ordering (Artifact > Grep >
Placeholder-skip), same fallthrough to `Expect_success`, same
handling of `has_manifest = false`. Tiny's `expectation_of_entry`
shrinks from ~40 lines to 6 (thin wrapper that pulls fields
out of a `scenario_spec` and passes them + `tiny_contract_bindings`).

Verified: tiny run 21/22 PASS unchanged, artifact-test 101/101.
`canary_scenario.ml` gains a `Canary_step_model` dependency
(same layer, no dune change needed).

### Task 2 Phases B + C shipped — loc_filter + version_info (2026-07-21)

Two small ADT extensions landed together (same touch surface):

**B1 (loc-awareness)**. Added `loc_filter` variant:

```ocaml
type loc_filter =
  | Any                                (* current default; tiny uses this *)
  | At_pm_lang of Canary_lang.lang     (* fires only at that lang's PM *)
  | Not_pm_lang of Canary_lang.lang    (* fires everywhere except *)
  | Only_if of (loc option -> bool)    (* escape hatch *)
```

Firings changed from `(firing_site * expectation_source)` tuple to
a record `{ site; loc_filter; source }` (record shape leaves room
for future fields — enable flag, per-firing note — without a
breaking change). The lowering evaluates `loc_filter_passes` after
matching on `site`; a firing whose filter rejects the step's `loc`
is skipped. This lets llvm's inline `Probe_binding (_), Some (Pm
(Lang_pm { lang = Python }))` → `Expect_success` special case
become `{ site = At_probe_binding OCaml; loc_filter = Not_pm_lang
Python; source = From_artifact { ... } }` — one binding row
instead of a nested match.

**C1 (version_info threading)**. Extended both live source
variants to carry the human-readable version bundle:

```ocaml
type expectation_source =
  | From_artifact of { inputs; version_info : version_info option }
  | From_behavior_grep of { contains_any; version_info : ... option }
  | Placeholder of { reason }
```

Lowering threads `version_info` through to the emitted
`Expect_compat_failure` / `Expect_failure`. Tiny sets it to `None`
throughout (no version drift to report); llvm/z3 can populate
their `provider_version = "llvm 19"; consumer_requires =
"Opcode.UncondBr"; ...` strings when they migrate (Phase D/E).

**Tiny bindings updated to record shape** — every firing now
carries `loc_filter = Any` and `version_info = None` explicitly.
No behavioural change; still 21/22 PASS + 101/101.

Docs: SSOT §5.4 refreshed with the new type shapes + a note
that `loc_filter` and `version_info` are what let per-project
bindings replace the ad-hoc nested `match rule with (_, loc)`
that z3/llvm use today.

**Next**: Phases D/E/F — per-project migration
(llvm → z3 → sqlite). Design surface is now settled; each phase
is a per-project data addition + inline `expectation` replacement.
Paused for user confirmation before proceeding.

### Task 2 Phases F + E + D shipped — sqlite / z3 / llvm migrated (2026-07-21)

**Baseline** (from `_out/canary/projects/{sqlite,z3,llvm}/-run/`
pre-migration, captured after user OK):
- sqlite: 7/7 done, positive-only (no compat-failure).
- z3: 29/29 done, 2 `expected failure confirmed` events fire
  (both Python probes, dev + stable, `parser_context` prediction).
- llvm: 40/40 done, 1 `expected failure confirmed` (stable OCaml
  `Opcode.UncondBr` prediction).

**Phase F — sqlite (no-op)**. sqlite's `project_spec` uses
`empty_project_spec` with no `expectation` field. Empty bindings
(implicit) already produce Expect_success everywhere — the
positive-only case fits the pattern without code changes.
Verified by re-inspection of `canary_project_sqlite.ml:60`.

**Phase E — z3 (one binding)**. New `z3_contract_bindings` at
module scope declares one binding:
  { contract = C2; lang = Python;
    firings = [{
      site = At_probe_binding Python;
      loc_filter = At_pm_lang Python;
      source = From_artifact {
        inputs = [Python_attrs …];
        version_info = Some { provider_version = "z3-solver pip wheel";
          consumer_requires = "z3.parser_context"; … };
      }}]}

The inline expectation (~20 LOC nested match on (rule, loc))
collapses to a 5-line `Canary_scenario.lower_expectation` call
with ~violates:[C2] ~langs:[Python] ~has_manifest:true. Shared
across dev/latest/stable variants because Python probe always
runs against the pip wheel (independent of native z3 lib build
mode).

Re-verified: 29/29 done, both Python compat-failures fire
identically. `diff -u` on done-lines (timestamps stripped)
returns empty — byte-parity with baseline.

**Phase D — llvm (one binding)**. New
`llvm_stable_contract_bindings` at module scope declares one
binding (C2 for OCaml at At_probe_binding OCaml, loc_filter Any).
Inputs bag intentionally merges C_stub + Native_lib + Ocaml_mli
even though the binding is keyed on C2 — the runner's
`predicted_contains_any_v2` iterates ALL contracts over the
merged input pool, so multi-contract predictions work same as
the old inline. version_info populated with the LLVM 19 →
Opcode.UncondBr context.

The inline expectation had three branches (Python override →
Expect_success; stable non-Python → Expect_compat_failure;
fallthrough → Expect_success). All three collapse into the
binding-based lookup:
- Python probe: no (C2, Python) binding → fallthrough → Expect_success.
- Stable OCaml probe: (C2, OCaml) binding matches → Expect_compat_failure.
- Dev variant: has_manifest = not source.has_build_binding = false
  → whole lookup short-circuits to Expect_success.

No `loc_filter` needed for the Python override (as the plan
speculated); the absence of a (C2, Python) binding does the
same job naturally. `~has_manifest:(not source.has_build_binding)`
handles the dev/stable split cleanly.

Re-verified: 40/40 done, one `expected failure confirmed`
(same as baseline), diff on done-lines empty — byte-parity.

**Summary**. Three project migrations, ~85 LOC net (z3 -18 +30 =
+12; llvm -30 +55 = +25; sqlite unchanged). Every hand-coded
`Expect_compat_failure` in z3/llvm's `project_spec` now flows
through `Canary_scenario.lower_expectation` over a
per-project binding table. Task 2's original 5-phase plan
(~230 LOC) landed as ~85 LOC after the structural rewrite
absorbed the switch table.

**Task 2 status**: parked plan closed. The binding-based pattern
is now the uniform way to declare per-project failure
predictions. Follow-ups (not part of Task 2):
1. When a new project appears (PyTorch, cvc5, ...) or a scenario
   needs multi-contract violations at one probe, revisit whether
   `lower_expectation`'s single-source pick should become a merge
   over all matching From_artifact firings.
2. The higher-level `project`/`project_definition` type (naming
   pressure noted in the "rename project_spec" discussion) is
   now a natural next step — the per-project contract_bindings +
   scenario_specs + workspace materializer + shell chassis form
   the components of a `project`, distinct from the runner-facing
   `Canary_step_builder.project_spec`. Deferred until a real
   consumer needs it.

### Task 2 follow-up: `Canary_project.project` type introduced (2026-07-21)

User raised the `project` vs `project_spec` naming confusion after
D/E/F landed. SSOT §6.1 taxonomy was missing `project` at the top;
`Canary_step_builder.project_spec` sits at the bottom (runner-facing
handoff) but its name suggests it's the top.

**Design decision — project owns scenarios** (Model A of the
options discussed): a project's `scenarios : 'a list` field holds
the concrete instances. Sharing scenarios across projects isn't a
real use case (patterns are shared via `Canary_scenario.good_scenarios`;
instances are owned). Ownership avoids the sync problems of a
bidirectional reference.

**New type** in `src/canary/action/canary_project.ml`:

```ocaml
type 'scenario_spec project = {
  name : string;
  scenarios : 'scenario_spec list;
  contract_bindings : Canary_scenario.contract_binding list;
}
```

Parametric on `'scenario_spec` because each project has its own
concrete recipe representation (tiny_recipe for tiny; z3/llvm will
introduce their own once variants are recast as scenarios).

`api_source` intentionally NOT a field — `source_repo` lives in the
`tool/` layer and would create a downward dependency from `action/`.
Callers who need it look it up per-project. Revisit if a real
generic consumer appears.

**Populated** `tiny_project : scenario_spec Canary_project.project`
at the bottom of `canary_tiny_scenario.ml`:

```ocaml
let tiny_project = {
  name = "tiny";
  scenarios = all_scenario_specs;
  contract_bindings = tiny_contract_bindings;
}
```

Nothing else changes yet — `canary_main.ml` still walks
`all_scenario_specs` directly. The bundle exists so (a) the
`project` type has at least one concrete inhabitant, and (b)
subsequent renames of `Canary_step_builder.project_spec` can
proceed without ambiguity about which "project" means what.

**z3 / llvm / sqlite project bundles** — deferred until the
variants-vs-scenarios question is answered (per user 2026-07-21:
"start with Step 1 project type + tiny only"). When picked up,
each project would either (a) recast variants as scenarios with
`origin = Some (Version_mismatch { ... })`, or (b) keep a separate
`variants` field on the project. Decide when a real consumer forces
the choice.

**Task 3** (deferred): rename
`Canary_step_builder.project_spec` → `runner_spec` (or
`variant_spec`) now that `Canary_project.project` occupies the
higher-level name. Cross-file sweep; wait until we have a stable
plumbing story.

**Verified**: build clean, tiny run 21/22 PASS unchanged,
artifact-test 101/101 unchanged.

SSOT §6.1 taxonomy updated: `project` added as top row; naming
distinction between `project` and `project_spec` documented
explicitly.

### Task 2 Step 1 refinement — concrete monomorphic project (2026-07-21)

User feedback after the polymorphic
`('scenario_spec, 'info) project` shape landed: prefers
concrete types over polymorphism; the variant-vs-scenario framing
was already unified (they occupy the same taxonomy slot), so no
need to parametrize on `'scenario_spec`. Also flagged a
chicken-and-egg risk in the shape (project owns scenarios ↔
scenarios computed from project data), noting the sub-field
pattern used for `stores` in the old project_spec as the
resolution.

**Taxonomy confirmed** (user 2026-07-21):
- `project` = aggregation bundle.
- `scenario ≡ variant` = middle-level runnable configuration.
  Tiny's factory generates one runner_spec per scenario; z3/llvm
  generate one per variant. `run_project_multi` consumes both
  under the same `variants` list.
- No separate "meta-project" concept — scenario is the label at
  that level. The "meta-project" feeling comes from the current
  name `project_spec` (Task 3 rename → `runner_spec`).

**Type refined** to concrete monomorphic (drops `'a` polymorphism
and `scenarios` field):

```ocaml
type project = {
  name : string;
  contract_bindings : contract_binding list;
}
```

Rationale: `scenarios` field would need either polymorphism
(rejected), a variant enum (needs concrete scenario_spec types
visible → module must move to `projects/`), or an opaque wrapper
(overkill). Deferred until it earns its keep — likely alongside
the variant case added for adapting to old `project_spec` when
Task 3 rename lands.

Each project's own module keeps ownership of its scenarios
(tiny: `all_scenario_specs`; z3/llvm: `mk_project_spec ~source`
produces variants). Semantic ownership (Model A) preserved; the
storage decision is separated from the ownership decision.

`api_source` still deliberately absent (would create a downward
layer dependency from `action/` to `tool/`).

**tiny_project simplified**:

```ocaml
let tiny_project : Canary_project.project = {
  name = "tiny";
  contract_bindings = tiny_contract_bindings;
}
```

**Chicken-and-egg** neutralized by this shape: no `scenarios`
field means no derived-from-project-info circularity. When a
project needs project-specific scenario derivation, the sub-field
pattern applies at the per-project module level (each project's
module can carry both raw info sub-fields and derived scenario
lists, decoupled by its own local functions).

Verified: build clean, tiny run 21/22 PASS unchanged,
artifact-test 101/101 unchanged.

SSOT §6.1 augmented: naming-distinction paragraph now explains
the concrete-monomorphic rationale + notes scenario ≡ variant.
