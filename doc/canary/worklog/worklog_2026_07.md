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
