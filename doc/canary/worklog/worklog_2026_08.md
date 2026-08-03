# Worklog — 2026-08

## The tiny-full arc (2026-08-01 → 2026-08-03)

Turned tiny-full into a real, mutation-agnostic project driven by a
project-agnostic runner. Principle now in [ssot §4.2.5](../design/ssot.md);
this is the phase-by-phase build history (moved out of `status.md` §1a on
2026-08-03 when the arc completed).

**Core principle.** The tiny-full runner knows *nothing* about mutations. A
bad artifact is a build at a **bad-quality version** (its badness is identity,
not a type the runner dispatches on). tiny-full **declares** vendored artifact
resources; **canary computes** detection, expectation, and the fail-fast
collapse. The factory (tiny1) stays the ground-truth **oracle** for the
cross-check.

| concern | owner | knows the mutation? |
|---|---|---|
| enumeration (assign versions to artifacts) | `canary_enumerate` | no |
| runner (materialize → run) | `run_project_run` + `project_run` | **no** |
| materializer (tag → concrete artifact) | `canary_tiny_workspace` | yes (hidden) |
| oracle (tag → expected verdict) | factory (tiny1) | yes (cross-check) |

### Phases (all shipped)

- **P0 — naming + `action tiny-full` as a project** (`b6ca255`, `4b003f3`).
  Named tiny-factory / tiny1 (`tiny run`) / tiny-full (`action tiny-full`);
  moved tiny-full off the `tiny` subcommand family onto the general `action`
  dispatch (peer of sqlite/z3/llvm).
- **P1 — agnostic driver over variant tags** (`3e1bc83`). The runner loop
  references only an opaque tag; all mutation/name knowledge confined to the
  materializer.
- **P2a — tag folded into the typed version identity** (`b943b1a`, grain (i)
  full unification). `canary_enumerate.placement.version` became `build_id =
  { channel; quality }`, `quality = Good | Bad of tag`. The Phase-1
  `variant_tag` side channel deleted; a bad artifact is `dev#Bs.1`.
- **P2b — contract-derived (agnostic) expectation** (spike `5bcce8e`,
  complete `c96eb1f`). `lower_expectation_agnostic` derives the expectation
  from the bindings table + (action, loc) alone — no per-scenario
  `violates`/`has_manifest` — unioning every contract's `From_artifact` inputs
  and letting `predicted_contains_any_v2` discover the break. The
  empty-prediction question resolved with an **additive** `Expect_compat_derived`
  variant: prediction empty ⇒ expect success, non-empty ⇒ expect the failure.
  z3/llvm keep `Expect_compat_failure` (zero risk). tiny-full now runs with no
  oracle.
- **P3 — vendored resources + combinations.**
  - Correction: reverted an `earliest_bad_of` collapse-key — tiny-full does
    *not* predict the collapse; canary computes it by running. `placement`
    became `Vendored`.
  - Materializer **emit → assemble → run** (`94fa841`, `dd912a7`, `7ac0cea`).
    Emit = *extract* each built artifact variant from the per-scenario
    workspaces `prepare-all` already builds (`resources/<id>/<tag>/`); assemble
    = overlay chosen variants onto the unmutated-witness base (no rebuild);
    run = the normal path over the assembled tree. Finding: vendored resources
    are the **built** artifacts (lib / ocaml-cstubs / cext); **source folds
    into lib**. `action tiny-full` full single-bad sweep: **20/20** via
    assembly. Deploy mismatch (binding built vs good lib, overlaid on bad lib)
    comes for free and canary catches it (c4).
  - Combinations (`d627890`). `tiny assemble-combo <TAG>...` assembles several
    bad artifacts — the scenarios *beyond* tiny1 — and runs with the agnostic
    expectation; canary computes the fail-fast collapse. Validated pairs +
    3-way.

### Convergence

- **Step 1 — `canary_project_tiny.ml`** (`ab4bcd4`). The tiny-full PROJECT
  module (peer of `canary_project_z3.ml`): `project` bundle + declarative
  surface + `run`, distinct from the factory that makes the ingredients. Pins
  the `project_run` interface (`{name; artifacts; enumerate; materialize;
  runner_spec}`).
- **Step 2 — the generic runner** (`a620b15`). `run_project_run` is
  project-agnostic: enumerate → materialize → runner_spec → run → report, same
  loop for any project; all specifics in the `project_run` closures.
  `Canary_project_tiny.tiny_full_run` is tiny-full's value (materialize =
  assemble; soname-aware stores via `detect_lib_filename`; agnostic
  expectation). `action tiny-full` routes through it: 20/20. **Additive** —
  z3/llvm keep their raw-script `run_project_multi` untouched.

### Agreed strategy for the rest

New runner drives tiny-full now + simple projects (sqlite) next; heavy
projects (z3/llvm) stay raw-script, migrated last by copy-modify only if ever.

### Superseded exploration (kept for archaeology)

The positive-space count churned during design before the vendored model
settled: raw per-artifact cartesian **2048** → whole-scenario version **64** →
app→binding dependency in `assignment_ok` **58** → then "presence is not a
choice, a project ships its whole declared set" made presence-enumeration a
dead end. The **per-edge version** model (build vs run version = the deploy
mismatch; ssot §4.2.4) and the finding that the instance graph **already
exists** (`artifact_node` + `make_action_graph`) remain live *deferred* design
— see [`enumeration_graph.md`](../design/enumeration_graph.md) and
[`versioning.md`](../design/versioning.md), tracked in `status.md` §1c.
