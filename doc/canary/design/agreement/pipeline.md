# How a project reaches an agreement

**Kind: walkthrough.** One project, end to end, showing every point where
the run consults the registry and what is *actually* in use at each. The
model is in [`model.md`](model.md); what is landed is in
[`landing.md`](landing.md).

Read this when you are landing an agreement on a project and need to know
where to look when it reports `unavailable`.

The worked example is **sqlite**, because it is real, it is cheap, and every
one of the failure modes below was found in it.

> **WHAT THIS DOC OWNS, since the seam was drawn (2026-09-16).**
> *agreement/ owns the CLAIM, enumeration/ owns the OCCASION.* The
> mechanics of when a check fires and where it reads are the
> enumeration's — they are `(world, action, mechanism, lang)` — and
> they are stated once, in
> [`../enumeration/stage6_realize_steps.md`](../enumeration/stage6_realize_steps.md)
> §2b. What is here is the **project-facing walkthrough**: the seven
> points a run touches, and the **four failure modes**, which are what
> you actually came for. Points 2–4 below therefore say what a project
> author has to get right and point at the mechanics rather than
> restating them.

## The shape, in one picture

```text
     project spec                    the enumeration                the registry
  ┌────────────────┐          ┌───────────────────────┐       ┌──────────────────┐
  │ pr_artifacts   │──1──────▶│ passes 1–5 → a WORLD  │       │ the agreements   │
  │ pr_binding_decls│         │  (an assignment)      │       │ each with        │
  │ pr_runner_spec │          └──────────┬────────────┘       │ methods          │
  └────────────────┘                     │                    └────────┬─────────┘
          │                              │ 2                           │
          │ 3                            ▼                             │
          │                   ┌──────────────────────┐                 │
          └──────────────────▶│ pass 6: derive_steps │                 │
                              │  step + agreement_ctx│                 │
                              └──────────┬───────────┘                 │
                                         │ 4                           │
                                         ▼                             │
                              ┌──────────────────────┐   5             │
                              │ run_step             │◀────────────────┘
                              │  evaluate_step       │
                              └──────────┬───────────┘
                                         │ 6
                                         ▼
                              actions.log: agreement_outcome
                                         │ 7
                                         ▼
                              canary checks <p> --observed
```

Seven numbered points. Only two of them are in the agreement layer; the
other five are where a project usually goes wrong.

## 1. The project declares facts, never an agreement

sqlite's `pr_artifacts` says its lib can be Fetched, Built or Installed and
its OCaml binding is Fetched from opam at one of two pins. Its
`pr_binding_decls` says that binding is `Cstubs`. That is all the registry
needs, and it is deliberately all the project gets to say: **no project
names an agreement.** Which checks those facts imply is the framework's
knowledge (`agreements_for`, `evaluate_in_context`).

What a project *does* choose is where its evidence comes from — the
inspector closures on its `runner_spec`. That choice is point 3, and it is
the one that decides whether any agreement can reach anything.

## 2. The enumeration produces a world

Passes 1–5 ([`../enumeration/README.md`](../enumeration/README.md)) turn the
artifact table into an `assignment`: one placement per artifact. For one
sqlite scenario:

```text
source=fetched@stable  lib=built@stable  binding-ocaml-cstubs=fetched-5.4.1
```

This matters to agreements for one reason: **the world decides where a
binding's evidence lives.** `binding_evidence_tag` reads the binding's
provision — `Fetched` means the inspection sits at the step that fetches
and installs it, `Built` means the step that builds it. Get the world
wrong and every path is wrong.

The derivation itself, and why it is the enumeration's rather than this
layer's, is
[`../enumeration/stage6_realize_steps.md`](../enumeration/stage6_realize_steps.md)
§2b.

## 3. `derive_steps` attaches the action context

Pass 6 attaches an `agreement_ctx` — mechanism, language, world — to the
steps that have binding facts; the mechanics are
[`../enumeration/stage6_realize_steps.md`](../enumeration/stage6_realize_steps.md)
§2b. What matters to a project author is the next paragraph.

**This is also where the inspector steps are attached.** `attach_inspect`
consults `spec.inspect action loc` first, then falls back to
`auto_binding_summaries` (which needs `api_source` *and*
`binding_user_facing_pkg`). Whatever those produce is the only evidence any
agreement will ever see.

> **Failure mode 1 — the spec the run uses is not the spec you wrote.**
> sqlite declared `api_source` and inspector closures on a `base_spec` that
> its `realize` never passed to `realize_from_rows`. The default is
> `empty_runner_spec`, so the run produced *no inspection JSON at all* and
> every agreement reported `unavailable`. The declarations were reviewed,
> documented — and unreachable. Check `canary emit <p> --stage realize`:
> if you do not see `*_inspect` steps, nothing downstream can work.

## 4. The step runs

`run_step` resolves each declared relative path against the world's output
tree (`resolve_input`: `"fetch_binding_ocaml/inspect.json"` becomes
`<project_dir>/fetch_binding/ocaml/inspect_<variant>.json`, applying the
step-dir mapping and the variant key).

> **Failure mode 2 — the filename convention.** The framework's binding
> summaries land in `inspect.json` and its compiled-stub summary in
> `inspect_stub.json`; tiny writes its stub to `inspect.json` and its
> surface to `inspect_mli.json`. The derived paths originally spelled
> tiny's names only, so they resolved on tiny and on nothing else. A
> surface input now carries both spellings and the reader selects by the
> `kind` the inspector declared — see point 5.

> **Failure mode 3 — the step.** sqlite inspected its binding at the *probe*
> step while the derivation names the step that *installs* it. Both work as
> commands; only one is where anything looks. Installing is also the earliest
> point the evidence exists, which is what [`model.md`](model.md) §1.3 asks for.

### The dummy action

Failure mode 3 has a variant with no obvious fix: **what if there is no
install step?** CPython's `sqlite3` is part of the interpreter. Nothing is
fetched, nothing is installed, and the step the derivation names does not
exist — so the binding's surface has nowhere to be inspected from.

Two ways out. Teach every consumer that an ambient binding is the exception,
or give the graph a place to hang things. Canary does the second:

```ocaml
fetch_binding = [ (Python, Canary_step_builder.Dummy
                     "CPython ships sqlite3 in the standard library — the \
                      interpreter already provides this binding, so there \
                      is nothing to fetch or install") ]
```

A **dummy action** occupies its place in the graph, performs no work, and
carries the reason it is empty. It still writes its marker, so "nothing to
do" stays distinguishable from "did not run"; it logs a `dummy` event, so a
reader scanning for real work can tell without reading the command; and an
inspector attached to it is *not* a dummy — running the inspector is the
entire reason the step exists.

It is **not** a stub, a skip, or an unwritten command. It asserts something
true and worth asserting: *no action provisions this artifact.* If that stops
being true — a venv, a pip build of `pysqlite3` — the dummy is wrong and
should become a real fetch.

They are countable, which is the point of marking rather than inferring
them:

```sh
canary checks --dummies          # every dummy across the registry, with its reason
```

One caveat this exposed: a binding with no consumer is dropped by
`drop_unread_fetches`, so a dummy install alone is not enough. sqlite's
Python side was entirely decorative — a watchlist, an expect-missing list and
a provider, with no `probe_binding` entry, so no Python step existed at all
and the chain was pruned. The dummy needed a probe beside it before anything
downstream could run.

## 5. `evaluate_step` — the only agreement-layer entry point a run uses

One call, one record ([`model.md`](model.md) §2.1):

- **selection** — every method whose `m_firing` contains this step's action,
  under this mechanism/language/world;
- **applicability** — a mechanism that cannot carry the claim reports
  `not_applicable` and is not confused with missing evidence;
- **evidence** — each method's own `m_inputs`, resolved, and picked by
  declared `kind` rather than by first-path-wins;
- **evaluation** — one `outcome` per method.

A compat expectation may also hand over an input list; that route is merged
into the same record, preferring whichever side actually decided.

## 6. The log is the interface

The runner writes one `agreement_outcome` event per selected method,
including the ones with no evaluator. Reading a real one:

```text
probe_binding_ocaml  agreement_outcome  (api_names_present/watchlist_vs_user_surface: holds)
probe_binding_ocaml  agreement_outcome  (required_symbols_exported/…: unavailable: no compiled-stub inspection in this world)
probe_binding_ocaml  agreement_outcome  (soname_matches_requirement/…: not_applicable: this binding mechanism produces no artifact carrying a dependency record…)
probe_binding_ocaml  agreement_outcome  (behavior_matches/probe_assertions: not_implemented: the expected values live inside the probe's source…)
```

Different reasons, different fixes — and since 2026-09-15 the outcome
*word* tells them apart rather than leaving it to the reason string:

| outcome | mark in `canary result` | what to do about it |
| --- | --- | --- |
| `holds` / `violated` | `✓` / `✗` | nothing — this agreement is decided here |
| `unavailable` | `no-evid` | produce the evidence (points 3–4). A WIRING gap: nothing wrote the inspection, or the reader runs before the writer |
| `undeclared` | `no-decl` | the artifact is readable and the PROJECT declared nothing to hold it against. A spec to-do |
| `vacuous` | `none` | nothing — both sides were reachable and there is genuinely nothing of this kind in this world (a library with no symbol versioning, for instance) |
| `inconclusive` | `no-ref` | evidence read, nothing to compare against |
| `not_applicable` | `stale` | **re-run.** Applicability became a static property of the project (2026-09-14), so in a fresh run the selection drops such a method before it evaluates. A `not_applicable` in a log therefore means the log predates that: `make canary-refresh PROJECT=<p>` |
| `not_implemented` | `planned` | the agreement has no evaluator; that is a catalogue decision, not a wiring one |

> The first three were ONE outcome until 2026-09-15. `Unavailable` carried
> a free-text reason that the evaluators wrote and the type discarded, so a
> cell that needed nothing read exactly like one waiting on an inspector —
> and `canary result`'s blame column had to guess between them.
> `unavailable_cause` is `Missing_evidence | Missing_declaration |
> Nothing_to_check`, and `Missing_evidence` kept the old word so nothing
> that matched `unavailable` changed meaning.

## 7. Read it back

```sh
canary checks sqlite --observed     # what the LAST run evaluated
canary checks --landing             # planned vs effective, all agreements
```

> **Failure mode 4 — a warm run reports nothing.** A step whose verdict
> marker is trusted is skipped, and a skipped step re-checks nothing. Its
> old outcomes are not re-emitted, so an agreement can be missing from a log
> for no reason except caching. `--observed` prints the skip count for
> exactly this reason. To force a real re-read:
>
> ```sh
> make canary-refresh PROJECT=sqlite
> ```
>
> It drops the markers of the steps that DECIDE — probes, binding builds,
> staging — and re-runs; fetches and the library build stay warm, because
> the point is to re-run the step that reads the evidence, not to rebuild
> the world. (It was a hand-written `rm -f` of one project's probe markers
> until 2026-09-15; the target exists because clearing `stale` is a thing
> you do repeatedly, and because guessing which markers matter is how you
> end up deleting an output tree.)

## The checklist

Landing an agreement on a project, in order:

1. `canary checks <p>` — does the agreement fire at any of this project's
   actions? If not, the world or the mechanism is the answer, not the
   wiring.
2. `canary emit <p> --stage realize` — is there an inspector step for the
   evidence it needs, at the step the derivation names?
3. Run the project. Drop the verdict markers of the steps that read the
   evidence first, or you will read a cached verdict and an empty report.
4. `canary checks <p> --observed` — did it decide?
5. **Falsify it.** Break the declaration the agreement is held against and
   confirm the same run flips to `violated`. A check that has only ever
   said `holds` has not been shown to be a check.
6. Record it in [`landing.md`](landing.md).
