# Terminology to-do: "scenario" is overloaded (scenario vs pattern vs stage)

> Status: **OPEN — analysis recorded, no decision yet** (2026-08-05 discussion).
> The display unification (scenario ≡ variant ≡ "world" → say `scenario`,
> ssot §6.1) is DONE; this file is about the *remaining* overload — the word
> `scenario` also covers two abstract notions. Nothing here is urgent; it
> gates nothing. Revisit when it bothers someone, or when F5 (status §F)
> replumbs the coverage command — the natural moment for the type split.

## History (why the overload exists)

In the tiny1 era the `Sc.N` catalogue WAS the scenario enumeration: a
hand-listed set of good configurations, with bad cases (`Bs.N`) derived from
them via the mutation matrix (`derive_scenarios`; `belongs_to` links each Bs
to its Sc). One record type — `Canary_scenario.scenario`, `id = "Sc.N" or
"Bs.N"` — naturally served both. The enumeration algorithm
(`canary_enumerate`) then superseded the hand-list as the source of concrete
scenarios; the `Sc.N` side drifted into a display/coverage catalogue but kept
the name. The word stayed while one of its referents changed kind.

## The senses today

1. **Concrete runnable configuration** — an enumerated assignment
   (provision × version × quality per artifact), with a dir, a cache key, a
   verdict. `spec`/`action`/`status` displays, `scenario_dir_of`,
   `scenarios.tsv`, tiny1's `Bs.N` cases, z3/llvm per-source configs. This is
   ssot §6.1's middle level — the sense `scenario` should KEEP.
2. **Designed good pattern** — `Sc.N` in `good_scenarios`
   (`action/canary_scenario.ml`): a named *collection of actions*,
   language-parameterized, no placements. Quantifies over worlds; not
   runnable as-is.
3. **Lifecycle stage** — the rows of `canary scenarios` /
   `canary_scenario_coverage.ml`: *single* actions (`fetch_source`,
   `build_lib`, …) marked ✓/-/⊘ per project. The module docstring already
   says "abstract-**stage** catalogue" — the honest word exists, just not in
   the command name.
4. (Adjacent) **structural pattern** — the path-table's 17 `pattern_row`s
   (`canary paths`). Already named "pattern"; conceptually a third
   abstract-shape representation (dynamic_enumeration.md lists all three).

Semantic relationship worth enforcing: a concrete scenario **instantiates**
patterns/stages; coverage = "which stages have at least one instantiating
scenario (or are declared unreachable)". That is exactly what F5 wants to
compute from the enumeration instead of the legacy parallel walk.

## Concrete symptoms

- **CLI contradiction**: `canary spec sqlite` lists 3 scenarios (sense 1);
  `canary scenarios sqlite` says "union of 1 scenario(s)" over stage rows
  (sense 3) — wrong count AND wrong word (legacy impl, predates
  `project_run`; the F5 gap).
- **Type-level awkwardness**: consumers of `scenario` handle two flavors —
  `origin` only meaningful for Bs, `belongs_to` is self for Sc.
- **Prose ambiguity**: "tiny has 22 scenarios" (designed cases), "tiny-full
  enumerates 6 scenarios" (assignments), "Sc.3 scenario" (a pattern) — three
  identity notions under one word.

## Options (tiered)

- **T0 — document**: ssot §6.1 pitfall entry (`scenario` = concrete only;
  `Sc.N` = good-scenario *patterns*; coverage rows = *stages*). Zero risk.
- **T1 — rename the `scenarios` command**. Candidates:
  - `canary coverage` — matches the display, BUT collides with the run
    output's *detection* coverage line ("coverage: N/M bad detected") —
    two coverages (static stage-coverage vs dynamic detection-coverage).
  - `canary stages` — precise, collision-free. Preferred so far.
  Keep the old name as an alias either way. The command's plumbing is
  already condemned (F5), so the rename is cheap now or free later.
- **T2 — split the dual-use type**: `pattern = {id; name; description;
  actions}` (the Sc.N catalogue) vs `scenario` keeping the concrete-case
  extras (`origin`, `belongs_to → pattern id`). Touches the tiny factory,
  `derive_scenarios`, coverage, validation. Best done WITH F5 (don't
  refactor code F5 replaces), and ideally in ONE terminology pass together
  with the queued `variant_*` → `scenario_*` identifier sweep (status §E) so
  cache keys, types, and display change once.

## Constraints

- `Sc.N`/`Bs.N` **ids are SSOT-stable** (like GH issue numbers) and appear
  in the manuscript — re-label the concept, never the ids.
- Manuscript wording changes go through the drafting queue
  (`research/drafting.md`), not ad hoc.

## Open questions (decide before executing T1/T2)

- (a) Command name: `stages` vs `coverage` vs other?
- (b) Is "pattern" the word for `Sc.N`, given `pattern_row` already uses it
  for the 17 structural rows? (Near-synonymy might be correct — both are
  abstract shapes — or might deserve distinct words.)
- (c) Should T2 also rename the `Bs.N` designed bad cases (e.g. `case`) to
  separate them from enumerated scenarios, or are they just scenarios with
  an oracle?
