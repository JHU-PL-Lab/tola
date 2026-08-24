# The shared store — what a version pin costs

**Kind: rationale + open decisions.** Shrunk 2026-08-23 from 604 lines,
when `repo_model.md` and `versioning.md` were purged. It could not be
purged with them: three things here have no other home — the opam
measurements (§2), the two open design questions (§4, §5), and the
landed run-order behaviour (§6), which belongs to a stage-3 doc that does
not exist yet.

> What LEFT: how a pin is declared → [`stage1_project_spec.md`
> §5](stage1_project_spec.md). The per-project cost table and the
> template's missing binding axis → `../../project/issues.md` (they were
> duplicated there already). Design A's implementation log (7 items, 6
> landed 2026-08-12) → the worklog; `git show 781f98e` has the original.

## 1. The constraint

opam allows exactly **one version of a package per switch** — a core
solver invariant, no escape hatch in 2.5.x. So a scenario's version pin
is not a preference, it is an **exclusive lock on that store's state**
for the step's duration, and two scenarios pinning the same package
differently cannot run at the same time.

`Canary_store.store_behavior_of_pm` says this in the model: opam is
`Isolated_store "switch"` — isolated from the system, and internally
single-valued. apt and brew are `Stateful_global`; pip is
`Isolated_store "venv"`.

**Design A — sequentialization with pins — is what we run.** Pins are
enumeration data; a pinned fetch's `check_post` verifies the store
actually holds the pin (`SB.pin_check_post` over
`Canary_pm_opam.holds_pin_cmd`), so a warm skip fires only when the
switch provably holds it and otherwise the fetch re-pins. That closed the
hazard on 2026-08-12: no scenario can run on the wrong pin. Probes carry
a `Canary_world.Opam_pin` assertion on top, which is redundant in
principle — canary performed the pin, so the result is known at dispatch
— and earns its place only against dispatch bugs and against mutation
from OUTSIDE canary. Which happened: a stray interrupted batch left the
switch on `sqlite3.5.1.0` (2026-08-20).

Still open from A's plan: the **naive-spec harness** — pure tests that a
Fetched binding on a single-valued store with ≥2 declared versions pins
each of them, that a pinned fetch has a pin-checked `check_post`, and
that a one-version spec is marked as such rather than looking like an
under-declared two-version one. Deferred (user: "no hurry").

## 2. Design B, and why it stays on the table (measured 2026-08-12)

B is one lightweight switch per version — the python-venv analogue. The
old objection was cost, and the measurement killed it: the expensive part
of `opam switch create` is compiling `ocaml-base-compiler`, and
**`ocaml-system`** wires the system OCaml instead.

| step | time |
| --- | --- |
| `opam switch create --empty X` | 0.3 s |
| `opam install ocaml-system` in X | 4.4 s |
| switch footprint before packages | 244 KB |

So per-version isolation costs ~5 s and no compilation. Trade-offs: real
isolation and parallel-safety by construction, against a per-switch
dependency reinstall (no shared build cache) and switch count growing
with scenarios.

Two caveats. **`ocaml-system` needs a distro OCaml** — on this machine
the only `ocaml` is opam's own, so `apt install ocaml` comes first.
And **`opam-0install`** (the experimental per-build solver) is not a
substitute: it relaxes exactly the global consistency our probes need
enforced.

## 3. What the cost measurement changed

A holds only while a pin is **self-contained**, and that is a property of
the dependency graph, not of our design. Measured with
`opam install <pkg>.<v> --show-actions --dry-run`, the four candidate
binding pairs fell into three tiers — one package alone (fine),
collateral rebuilds of other projects' packages (a design question), and
a whole-switch compiler downgrade (out). The table is in
`../../project/issues.md`; the rule it produced belongs to landing:
**before declaring a binding pair, dry-run the older pin and record its
tier.**

## 4. OPEN — A, one canary switch, or B?

Neither of A's stated fallback conditions fired (we did not want scenario
parallelism, and the world assertions are not fragile). A third one did:
A only works for self-contained pins.

1. **A stays right for tier 1.** Two more full 2×2s for one field on the
   template.
2. **Tier 3 needs an isolated switch**, and that is now a requirement
   rather than a preference. Not B's per-version fleet necessarily — ONE
   canary-owned switch is the cheap middle: a destructive pin can be
   destructive where nothing else lives, without paying per-scenario
   switch cost. It does not give parallelism; B still does.
3. **Tier 2 is a design question, not a switch question** — see §5.

Design A's mitigation settles none of this. The world assertion catches
*crossing* (scenario X running under scenario Y's pin). It says nothing
about a switch that is correct for libffi and quietly different for llvm,
or correct for zstd@0.3 and unusable for everything else.

## 5. OPEN — what is a collateral rebuild FOR?

When pinning `ctypes-foreign 0.23.0` makes opam recompile
`llvm.19-shared`, `yaml` and `zstd`, opam is running the experiment
canary exists to run — *does this consumer still build against this
version of its provider?* — on three consumers at once, and throwing the
answer away. We see a longer run; we do not see a result.

What is available there, cheaply:

- **A verdict per rebuild.** Each `↻` either compiles or does not, and a
  failure is a genuine finding. Today it surfaces as "opam install
  failed" attributed to the scenario that triggered it — the wrong
  project gets the blame.
- **A scenario we cannot enumerate.** `llvm.19-shared` × `ctypes 0.23.0`
  crosses two projects: llvm's binding against the dependency of libffi's
  binding. Our universes are per-project, so this pair is in nobody's;
  the solver reaches it for free.
- **A contract our probes rarely test.** These are *source* rebuilds —
  c2-shaped (does the OCaml surface still satisfy its consumers) rather
  than the c1-shaped question native probes answer.

Three treatments, increasing ambition: **record** it (parse
`--show-actions`, log the `↻` set as an event, which at least fixes blame
attribution); **verdict** it (per-item pass/fail as an outcome of the
scenario — still no new enumeration); **enumerate** it (admit
cross-project consumer/provider pairs as a scenario kind — a model
change).

Note the interaction with §4.2: a dedicated canary switch makes the
collateral set SMALLER and more meaningful (only canary's own packages),
rather than removing it. That is an argument for the one-switch middle
over B's fleet, which deletes the signal along with the hazard.

**Decide what tier 2 is FOR before isolating it away by default.**

## 6. The pin is a LOCK, so scenarios group by it — LANDED 2026-08-21

*(Stage-3 behaviour. Move to the stage-3 doc when it exists; the map is
[`README.md`](README.md).)*

`pin_check_post` had already made ordering irrelevant to *correctness*.
What was left was cost: scenarios needing the same store state should run
together. They did not, because the enumerated list IS the run order and
the product ranges over the lib axis outermost, so the binding pin
alternated on every row.

`Canary_project_run.store_state_key` derives the (artifact, pinned
version) pairs an assignment locks — artifacts whose PROVIDER declares
pins, placed at a concrete version. `scenarios_in_run_order` is
`scenarios_of` through a `List.stable_sort` on that key, and the runner
iterates it. Stable, so the enumeration's order (baseline first) survives
inside each group; `scenarios_of` itself is untouched, so `spec` and every
pure test still see enumeration order.

Measured on sqlite's ten scenarios: **9 real pin swaps → 2**, one per
group boundary; the other eight became `already installed` no-ops. Wall
clock moved only 57.4 s → 53.6 s, because reinstalling `sqlite3` is
cheap — **the saving is proportional to install cost**, which is why z3
motivated it. On z3's sixteen scenarios the binding placement alternated
`fetched, built, fetched, built, built, …`; six rows place the binding
`Fetched@4.16.0`, the opam `z3` package is `Package_builds_lib` (it
compiles libz3 from source), and `fetch_binding_ocaml` accumulated
**344 s** in one sampled window against ~2 s for a whole zlib scenario.
Grouping pays that build once.

Three things worth keeping in mind about it: it is an **ordering, not a
new axis** (the scenario set is unchanged, so it stays out of the
enumeration's semantics); reordering was **already safe** before the sort
(correctness never depended on order); and it **composes with the tiers**
— tier-1 pins get cheaper by exactly this factor, while tier 3 does not
become acceptable, it just gets performed once.

Pinned by `run_order.groups_by_store_state` over every catalogued
project, muted ones included, asserting both halves — the ordering is a
permutation of the enumeration, and each distinct key occupies one
contiguous run. Falsified by dropping the sort and by making it drop a
scenario.
