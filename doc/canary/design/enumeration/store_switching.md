# The opam switch — one instance of an exclusive resource

**Kind: rationale + open decisions.** The **opam-specific** case: what
opam's one-version-per-switch rule costs us, what a per-version switch
would cost instead, and the two questions still open. The GENERAL principle — how to
run a scenario that needs exclusive use of a mutated singleton, and how
to choose between partitioning and serializing it — is
[`stage3_identity.md` §2](stage3_identity.md).

> Narrowed 2026-08-24 (user: *"the remaining part is still an opam
> store_switching issue, which is a specific problem"*). The general
> principle and the landed run-order behaviour moved to stage 3; pin
> DECLARATION moved to [`stage1_project_spec.md` §5](stage1_project_spec.md)
> on 2026-08-23; the per-project cost table lives in
> `../../project/issues.md`. `git show 5f5f12c` has the 604-line version
> and `git show 781f98e` the original.

## 1. The opam constraint, precisely

opam allows exactly **one version of a package per switch** — a core
solver invariant, no escape hatch in 2.5.x. `store_behavior_of_pm` types
it as `Isolated_store "switch"`: isolated from the system, and internally
single-valued.

So opam is the **serialize** case in stage 3's taxonomy, not the
partition case: the resource is not a directory we can copy per world,
and the alternative (a switch per version) changes the world under test
rather than duplicating it.

The realization: pins are enumeration data; a pinned fetch's
`check_post` verifies the switch actually holds the pin
(`SB.pin_check_post` over `Canary_pm_opam.holds_pin_cmd`), so a warm skip
fires only when it provably does and otherwise the fetch re-pins. Probes
carry a `Canary_world.Opam_pin` pre-check. That closed the hazard on
2026-08-12 — no scenario can run on the wrong pin.

Still open from that plan: the **naive-spec harness** — pure tests that a
Fetched binding on a single-valued store with ≥2 declared versions pins
each of them, that a pinned fetch has a pin-checked `check_post`, and
that a one-version spec is *marked* as such rather than looking like an
under-declared two-version one. Deferred (user: "no hurry").

## 2. The per-version switch, and why it stays on the table (measured 2026-08-12)

The alternative is one lightweight switch per version — the python-venv
analogue, i.e. **partitioning** what §1 serializes. The old objection was
cost, and the measurement killed it: the expensive part
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

Serializing works only while a pin is **self-contained**, and that is a
property of the dependency graph, not of our design. Measured with
`opam install <pkg>.<v> --show-actions --dry-run`, the four candidate
binding pairs fell into three tiers — one package alone (fine),
collateral rebuilds of other projects' packages (a design question), and
a whole-switch compiler downgrade (out). The table is in
`../../project/issues.md`; the rule it produced belongs to landing:
**before declaring a binding pair, dry-run the older pin and record its
tier.**

## 4. OPEN — shared switch, one canary switch, or one per version?

The two conditions that were supposed to force a per-version switch
never fired: we did not want scenario parallelism, and the world
assertions turned out not to be fragile. A third one did — serializing
in the shared switch only works for self-contained pins.

1. **The shared switch stays right for tier 1.** Two more full 2×2s for
   one field on the template.
2. **Tier 3 needs an isolated switch**, and that is now a requirement
   rather than a preference. Not a per-version fleet necessarily — ONE
   canary-owned switch is the cheap middle: a destructive pin can be
   destructive where nothing else lives, without paying per-scenario
   switch cost. It does not give parallelism; a per-version fleet still does.
3. **Tier 2 is a design question, not a switch question** — see §5.

§1's machinery settles none of this. The pin check and the world
assertion catch *crossing* — scenario X running under scenario Y's pin.
They say nothing about a switch that is correct for libffi and quietly
different for llvm, or correct for zstd@0.3 and unusable for everything
else. Correctness was never the open question here; blast radius is.

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
over a per-version fleet, which deletes the signal along with the hazard.

**Decide what tier 2 is FOR before isolating it away by default.**

