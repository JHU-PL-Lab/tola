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

## Forward look — Task 1.6 (queued in SSOT §9.3)

1. **Coverage-tag `prepare-all`.** After a `prepare-all` run,
   report which derived cells the 13 Bs recipes covered. Cheap;
   reuses `derived_scenarios` + `matches_derived_cell`. Purpose:
   connect a real test run to the abstract coverage view.
2. **`tiny_recipe` synthesis from an abstract cell.** Today derived
   cells are name-only. To *run* a derived cell we'd need to
   generate a `tiny_recipe` (patch files + expected step outcomes)
   from (Good × target × kind). Would unblock filling the 15 empty
   cells with concrete instances rather than hand-listing them.
