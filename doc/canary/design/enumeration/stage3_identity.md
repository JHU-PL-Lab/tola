# Stage 3 — scenario identity, exclusive resources, and run order

**Kind: rationale.** Standalone. Stage 2 hands over a list of
assignments; this stage answers three questions before anything runs:
which of them are the **same** scenario, which of them **cannot coexist**,
and in what **order** they go. The map is [`README.md`](README.md).

> Created 2026-08-24 (user: *"the general principle should be expressed
> in the spec or the later stage doc on how to run on an exclusive
> scenario e.g. opam-switch or any global mutated singleton resource"*).
> §2 is that principle, generalized out of
> [`store_switching.md`](store_switching.md), which stays as the opam
> instance. §3 moved here from that doc's §6.

## 1. Identity — which assignments are one scenario

`scenario_dir_of` computes a per-scenario directory that is
simultaneously the **output path** and the **dedup key**. Two assignments
with the same key are one run.

What is in the key: each artifact's provision, and its version **when the
version is identity-bearing**. That qualifier is the whole rule, and it
is declared upstream — see [`stage1_project_spec.md`
§5](stage1_project_spec.md):

- `id = ""` — **version-ambient**. The provider picks (a PM resolves
  whatever it resolves), so the declared version is not part of identity
  and two `Fetched@v` assignments differing only in declared version
  collapse to one run.
- `id` non-empty — **identity-bearing**. The version reaches the key, so
  `ssl@0.6.0` and `ssl@0.7.0` are two scenarios, and z3 at `latest` vs
  `arbipher` are two chains.

The directory is **born-safe**: `:` never appears (ids use `-`), because
these paths reach `PYTHONPATH` and `LD_LIBRARY_PATH`.

A consequence worth stating plainly: **identity is a claim, not a
guarantee.** The key says which world the row is about. Whether the
machine was in that world when the step ran is §2's problem.

## 2. Exclusive resources — the general principle

Some placements do not merely *name* a resource; they require it to be in
a particular state, and the machine has exactly **one** of it. Satisfying
such a placement means **mutating a singleton**. Two scenarios that need
different states of the same singleton are **mutually exclusive**: they
can both exist in the enumeration, but not at the same moment.

This is not an opam quirk. It has shown up four times, in four different
resources, and each time the fix was invented locally before the pattern
was named:

| singleton | who needs it | what went wrong without isolation |
| --- | --- | --- |
| **an opam switch** | any pinned lang-PM package | opam holds ONE version of a package per switch (a solver invariant). Scenario N's fetch re-pins; N+1 silently inherits it |
| **an install prefix** | every `Installed` placement | z3's worlds shared `z3-all/install`, so the fork's staged package could answer the pre-10549 world's staged probe — and *silence a regression xfail*. Now `install-<ref>` per world; pin `z3.install_prefix_isolated` |
| **a build tree** | every `Built` placement | one `build/` shared across refs. Now `build-<ref>`. Related: a shared tree also goes STALE — ninja would not relink `dllz3ml.so` after the lib's SONAME bumped |
| **a findlib namespace** | two packages exporting one module path | `zarith` and `zarith-no-conf` both install findlib `zarith`; only one can own the name |

### The two ways out, and how to choose

**Partition** — give each world its own copy of the resource, so nothing
is shared and order stops mattering. This is right when the resource is a
*place*: a build directory, an install prefix, a workspace. It is cheap,
it needs no verification, and it makes the exclusivity disappear rather
than manage it. Both directory instances above took this route.

**Serialize and verify** — keep one resource, mutate it to the state the
scenario needs, and *check that you hold it* before using it. This is
right when the resource cannot be cheaply duplicated, or when duplicating
it would change what is being tested. Opam's one-version-per-switch rule
is not a directory you can copy; a per-version switch is possible
(~5 s — see [`store_switching.md`](store_switching.md) §2) but pays a
dependency reinstall per switch and changes the world under test.

The findlib case shows the choice is not always about cost: two distinct
findlib names would have let both packages coexist, but then the probe
would compile against a name no real consumer uses. **Same name plus
serialization was chosen because realism beats coexistence.**

Rule of thumb: **partition a place, serialize a state.**

### What serialization requires

Three things, and all three have bitten when missing:

1. **Verify-or-set, not set-once.** The step that establishes the state
   must re-establish it whenever it is not held. This is also the only
   sound warm-cache rule here: for a store-mutating step, the
   cache-skippable fact is not "this ran before" but **"the resource is
   provably in the required state"**. A marker saying the install
   succeeded once is not that — another scenario may have moved the store
   since. (`pin_check_post` over `Canary_pm_opam.holds_pin_cmd` is the
   opam realization.)
2. **A backstop assertion on the consumer.** The step that *uses* the
   state asserts it, before running, and aborts. It must be a pre-check:
   by the time a post-check runs, the wrong version has already been
   linked against. This is redundant in principle — canary performed the
   mutation, so the result is known at dispatch — and it earns its place
   against two things dispatch cannot see: a bug in canary's own
   dispatch, and mutation from **outside** canary. The latter happened:
   an interrupted batch left the switch on `sqlite3.5.1.0` (2026-08-20).
3. **No two worlds may share a write location.** The install-prefix bug
   is the specimen, and note how it failed: the two prefixes were
   *spelled* differently (`…/z3/../build/../install` vs
   `…/z3-pre-10549/../build-pre-10549/../install`) while naming ONE
   directory. So the invariant is about resolved paths, not strings — the
   pin normalizes `..` segments before comparing, because a string
   comparison would have called them isolated and been decorative.

### What is general in the code, and what is not

The **model** is general. `Canary_store.store_behavior_of_pm` classifies
a store rather than special-casing a PM:

```ocaml
Apt | Brew -> Stateful_global          (* one system, mutated in place *)
Opam       -> Isolated_store "switch"  (* isolated from the system, single-valued inside *)
Pip        -> Isolated_store "venv"
Unsupported -> Stateless
```

`Canary_project_run.store_state_key` is likewise general: it derives the
(artifact, pinned version) pairs an assignment locks, from whichever
providers declare pins.

The **mechanisms** are not. `Canary_world.Opam_pin` is an opam-shaped
constructor; `holds_pin_cmd` is an opam command; the no-shared-write
invariant is one project's hand-written pin rather than a check derived
from the install rows. Generalizing those is open work, and the honest
statement is that we have a general vocabulary with opam-specific
realizations hanging off it. Tracked in `../../project/status_project.md`.

## 3. Run order — group by the state required (LANDED 2026-08-21)

Once exclusivity is handled correctly, order stops mattering for
**correctness** — verify-or-set means a scenario cannot inherit a
neighbour's state. What is left is **cost**, and it was large.

The enumerated list IS the run order, and stage 2's product ranges over
the lib axis outermost. So the binding pin alternated on every row:

```
sqlite, before:  5.1.0  5.4.1  5.1.0  5.4.1  …   → 9 real swaps in 10 rows
```

`scenarios_in_run_order` is `scenarios_of` put through a
`List.stable_sort` on `store_state_key`, and the runner iterates that.
Stable, so the enumeration's order (baseline world first) survives inside
each group; `scenarios_of` itself is untouched, so `spec` and every pure
test still see enumeration order.

| | pin operations | of which REAL swaps |
| --- | --- | --- |
| before | 10 | 9 — alternating every row |
| after | 10 | **2** — one per group boundary |

The command still runs per scenario; eight of them became `already
installed` no-ops. Wall clock moved only 57.4 s → 53.6 s on sqlite,
because reinstalling `sqlite3` is cheap — **the saving is proportional to
the install cost**. Which is why z3 motivated it: six of its sixteen rows
place the binding `Fetched@4.16.0`, the opam `z3` package is
`Package_builds_lib` (it compiles libz3 from source), and
`fetch_binding_ocaml` accumulated **344 s** in one sampled window against
~2 s for an entire zlib scenario. Grouping pays that build once.

Three properties worth keeping straight:

- It is an **ordering, not a new axis**. The scenario set is unchanged, so
  this stays out of the enumeration's semantics — it is a sort key
  derived from each assignment.
- Reordering was **already safe** before the sort existed. The
  correctness never depended on order (§2 point 1), which is what made
  this a pure optimization rather than a fix.
- It **composes with pin cost**: a cheap pin gets cheaper by exactly this
  factor, and an expensive one does not become acceptable — it just gets
  performed once instead of six times.

Pinned by `run_order.groups_by_store_state` over every catalogued
project, muted ones included, asserting both halves — the ordering is a
permutation of the enumeration (a sort, not a policy), and each distinct
key occupies one contiguous run. Falsified by dropping the sort and by
making it drop a scenario.

## Pins guarding this stage

| pin | asserts |
| --- | --- |
| `run_order.groups_by_store_state` | the run order is a permutation of the enumeration, and each store state occupies one contiguous run |
| `matrix.registry_shape` | per-project scenario counts — so a change in identity or dedup cannot pass silently |
| `z3.install_prefix_isolated` | two worlds' staging prefixes resolve to different directories (`..` collapsed) |
| `z3.env_guard_paths` | no asserted path carries a `..` segment — the spelling-vs-directory trap again |
| `world.one_vocabulary` | both kinds of world assertion travel together, so a partial consumer cannot honour one and drop the other in silence |
