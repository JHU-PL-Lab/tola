# Landing an agreement — the walkthrough, and what is left

**Kind: walkthrough + status.** One project end to end, showing every
point where a run consults the registry and what is actually in use at
each; then the checklist, and the work that is not per-agreement.

Read it when you are landing an agreement on a project and need to know
where to look when it reports `unavailable`.

The worked example is **sqlite**, because it is real, it is cheap, and
every failure mode below was found in it.

```sh
canary checks --landing            # WHICH are landed — the live table
canary checks <project>            # one project's coverage, per action
canary checks <project> --observed # what its LAST run decided
```

**Per-agreement status lives in [`catalogue.md`](catalogue.md) now**, in
its *What is done, and what is left* table, which is GENERATED. This
file carried that by hand until 2026-09-17 and had reached the state of
listing three agreements twice with contradictory verdicts — once as
LANDED with a specific verdict, once as "reported as
`not_applicable`/`unavailable`" — while the tool said eight were landed.
Two other hand copies of generated tables had gone stale the same way
(the retired `registry.md`'s §1.7 and §7.4.1), which is the rule this
directory now enforces: **a table the tool generates does not get a hand
copy.**

**A row is LANDED only when a real run decided it.** Not when its
comparator exists, not when its fixture passes, not when the catalogue
describes it. That was true of every agreement in the registry until
2026-09-12, and reading a log rather than the code is what showed it.

> Absorbed `pipeline.md` on 2026-09-17. That file was the walkthrough
> and this one the tracker, and once the tracker's table became
> generated what was left of it — the four states, the distance-0
> backlog, the procedure — was the walkthrough's tail. Merging them also
> left ONE `pipeline.md` in the tree, which is the enumeration's.

## The shape, in one picture

```text
  the project's own words              the enumeration                the registry
  ┌─────────────────────┐        ┌──────────────────────────┐   ┌──────────────────┐
  │ pr_artifacts        │──1────▶│ pass 1  declare          │   │ the agreements   │
  │ pr_binding_decls    │        │ pass 2  ANALYSE ─────────┼─2▶│ each with        │
  │ pr_runner_spec      │        │   which claims THIS      │   │ methods          │
  └─────────┬───────────┘        │   project can carry      │   └────────┬─────────┘
            │                    │ passes 3-5 → a WORLD     │            │
            │ 4                  │   (one assignment)       │            │
            │                    └────────────┬─────────────┘            │
            │                                 │ 3                        │
            │                                 ▼                          │
            │                    ┌──────────────────────────┐            │
            └───────────────────▶│ pass 6  realize          │            │
                                 │  step + agreement_ctx    │            │
                                 └────────────┬─────────────┘            │
                                              │ 5                        │
                                              ▼                          │
                                 ┌──────────────────────────┐   6        │
                                 │ run_step                 │◀───────────┘
                                 │  evaluate_step           │
                                 └────────────┬─────────────┘
                                              │ 7
                                              ▼
                                 actions.log: agreement_outcome
                                              │ 8
                                              ▼
                                 canary checks <p> --observed
```

Eight numbered points. Only two of them are in the agreement layer; the
other six are where a project usually goes wrong.

> **This diagram was wrong until 2026-09-17** (user: *"the pipeline in
> agreement doesn't look correct, given the use of project spec
> analyzed"*). It read `passes 1-5 → a WORLD` and routed the project's
> declarations straight into `derive_steps`, which left **pass 2
> invisible** — and pass 2 is the one that matters most to this layer.
> APPLICABILITY, *can this project carry this claim at all*, is
> `(mechanism, lang, declaration)` with no world in it, so it is decided
> there and not at the step. `pr_binding_decls` reaches the registry via
> pass 2, which is the edge the picture was missing; a reader following
> the old one would have looked for applicability at point 4 or 5 and
> found nothing.

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

## 2. Pass 2 decides which claims this project can carry

**This is the point the old picture was missing**, and it is the one
that decides whether an agreement is even in play for a project.

APPLICABILITY is `(mechanism, lang, declaration)` — no world in it — so
it is answered from the spec alone, at
[pass 2](../enumeration/stage2_analyse_spec.md). sqlite says its Python
binding is `Cext`; z3 says its is `Ctypes`. Ctypes compiles no stub and
records no dependency, so `required_symbols_exported`,
`dependencies_provided`, `soname_matches_requirement`,
`required_versions_exported` and `signatures_agree` cannot be carried
there at all — five of thirteen, decided before any world exists.

See it:

```sh
canary emit z3 --stage analyse     # "claims this project can carry", per language
```

Two consequences for landing:

- **If a claim is not carried here, no amount of wiring will land it.**
  `canary checks <p>` reports such rows as `no evaluator` or omits them;
  the answer is the mechanism, not the evidence.
- **It used to be re-answered per step**, and logged — sqlite emitted
  the same six `not_applicable` sentences on each of ten scenarios,
  sixty lines restating one static fact about cstubs. A
  `not_applicable` in a log now means the log PREDATES 2026-09-14:
  `make canary-refresh PROJECT=<p>`.

## 3. The enumeration produces a world

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

## 4. `derive_steps` attaches the action context

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

## 5. The step runs

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

## 6. `evaluate_step` — the only agreement-layer entry point a run uses

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

## 7. The log is the interface

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

## 8. Read it back

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

1. `canary checks <p>` — does it fire at any of this project's actions?
   If not, the world or the mechanism is the answer and no wiring will
   help; [pass 2](../enumeration/stage2_analyse_spec.md) decided it.
2. `canary emit <p> --stage realize` — is there an inspector step for the
   evidence it needs, at the step the derivation names? If you do not see
   `*_inspect` steps, nothing downstream can work.
3. Run it, with the deciding steps COLD. A warm step re-checks nothing
   and emits no `agreement_outcome`, so a cached verdict reads as an
   empty report: `make canary-refresh PROJECT=<p>`.
4. `canary checks <p> --observed` — did it decide?
5. **Falsify it.** Break the declaration it is held against and confirm
   the same run flips to `violated`. A check that has only ever said
   `holds` has not been shown to be a check.
6. If it had an `ag_waiting_on`, clear it. Nothing else to record — the
   catalogue's table is generated, and the landed/not split is
   `canary checks --landing`'s to state.

## Four states, four kinds of work

Telling them apart is most of the value of asking.

| the log says | it means | the work |
| --- | --- | --- |
| `unavailable` | the evidence was not produced | WIRING — an inspector is missing, or the reader runs before the writer |
| `undeclared` | the artifact was read; the project declared nothing to hold it against | the SPEC |
| `vacuous` | both sides read, nothing of this kind exists here | nobody's — this is a correct answer |
| `not_implemented` | no evaluator | a CATALOGUE decision: state the claim's scope first |

`not_applicable` in a log means something else again: applicability
became a static property of the project on 2026-09-14, so a fresh run
drops such a method before it evaluates. Seeing it means the log
predates that — `make canary-refresh PROJECT=<p>` and read it again.

## What a landing has cost, so far

Every landing so far has turned out to need something other than the
comparator, and it has been the same something four times:
**the producer picks a step, the consumer derives one, and nothing makes
them agree.** tiny's filenames; sqlite's binding inspected at the probe
while the derivation names the install; `lib_evidence_tags` naming only
the build-tree probe's tag; the opam-binding template inspecting at
`Probe_binding` rather than where a binding is provisioned. Four
instances, each fixed individually, none fixing the class.

The walkthrough above positions each failure mode at the point in a run
where you meet it; backlog §50 is the general fix and
[`../action_model.md`](../action_model.md) §6 says what it needs.

Two more that are worth knowing and are not that class:

- **A check that passes only on a warm tree is not a check.**
  `probe_binding` did not depend on `probe_lib`, so where the check
  decided it decided by reading a file a PREVIOUS run had left behind.
  The round-trip gate clears the lib probes' output too.
- **A derived package earns the STUB inspection only.** Merging the two
  channels generated an mli scan beside each project's own, and zarith's
  `Zarith_version` and libffi's `Ctypes_foreign_basis` ship with no
  `.mli` — so the generated summary reported missing what ocamlobjinfo
  lists, turning a holding agreement into a false `violated`.
  `binding_store_pkg` and `binding_user_facing_pkg` are separate fields
  for exactly this reason.

**The universality answer is good news:** `required_symbols_exported`
landed on cairo, libffi, ssl and zarith *with no per-project change*,
once the two facts a project already declares reached the runner — its
`api_source` and the package its binding is
(`Canary_pipeline.with_declared_facts`). Both had been read only by
`spec-check` and the CI renderer.

## The distance-0 backlog

[`theory.md`](theory.md) §5 lists, per action, the full-information
agreement the real tool established and what post-fact checking can
recover. Walking that against the registry gives a second backlog,
ordered by **how far apart the two sides of the comparison are** rather
than by subject.

| distance | both sides are… | example |
| --- | --- | --- |
| **0** | available at the one action — an artifact and something we still hold | the build tree beside the staged tree; a library beside its declaration; a ref we can re-resolve |
| **1** | from adjacent actions; established by the toolchain only if same-origin | a stub's undefined references against a library's exports |
| **≥2** | from different worlds, or needing a runtime trace | denotation across worlds, interposition |

Distance 0 is where the least was lost, so it is where checking is
cheapest and strongest. Every registered agreement is distance 1 or
planned; the distance-0 checks with no row are:

| theory § | post-fact check | today | what it needs |
| --- | --- | --- | --- |
| 5.1 | the source tree is the declared ref | runs, as a **shell assertion** in a `check_post` | the resolved commit RECORDED as evidence, then a row |
| 5.7 | the package contains the files the recipe named | runs, as **shell assertions** hand-listed per project | a package file manifest as evidence, then a row and a general form |
| 5.3 | exports the declaration does not account for | nothing | the converse of `declared_symbols_exported`; together they make an equality rather than an inclusion |
| 5.2 | the build tree is configured for *this* source | nothing | an inspector over the configure cache |
| 5.3 | declared signatures match the library's debug info | prose proposal ([`components.md`](components.md) §2.2) | a DWARF inspector, and `-g` |

**"Already runs" is not "already produces evidence",** and the
distinction is why this list shrank rather than landing. It first
claimed the top three needed only a registry row. Only one did —
`staged_interface_preserved`, lifted from a comparator that was sitting
in the status reporter (`Canary_status.install_diff_note`). §5.1 and
§5.7 are shell assertions *inside commands*: a `git rev-parse` in a
postcondition, `test -f` lines in a packaging step. They check something
real, but there is no evidence file for an evaluator to read, so
registering them means recording the fact first — the inspector tier,
not the free one.

Two preconditions that were on this list are **done**: `lib_evidence_tag`
(2026-09-12, world-aware at last) and routing the declarations
(2026-09-13, `with_declared_facts`), which is what let the three
declaration agreements decide at all.

## `--strict` — while you are landing one

By default a detected disagreement does **not** fail the step. That is
deliberate and it stays: an `Expect_success` step's acceptance policy is
"the command succeeded and its postcondition holds", and a violated
agreement there is a finding about *artifacts* that the action was never
asked to fail on. ssl's `dependencies_provided: violated libcrypto.so.3`
is a real finding about a real spec gap, and it must not turn ssl red.

The cost of that default shows up exactly while an agreement is being
landed: `canary result` prints `✗` in the check column and the scenario
line says `PASS`, so the two views of one run disagree and you have to
read the log to learn which is right.

```sh
canary action sqlite --thin --strict     # CANARY_STRICT=1 for Makefile targets
```

Under `--strict` a violation fails the step that read the evidence, so
the two views agree and the run stops at the action that saw the problem
rather than three actions later. It adds no evaluation — the violations
are the same ones already reported; it only decides what they mean. The
failure is logged as `strict_violation` with the `slug/method: outcome`
of each, and the run header says `agreements: strict`.

It rides the step fingerprint, so a verdict earned permissively is never
served to a strict run. The permissive digest is unchanged, so turning
strict *off* again costs nothing — but a strict run is always cold.
Pinned by `strict.acceptance_policy`.

Note what this means on a project with declared mismatch cells: sqlite's
built-Stable lib is 3.43.2, chosen as the last release *before* 3.44.0
added `sqlite3_get_clientdata`, so `--strict` fails `build_lib` in those
four scenarios on the first run. That is the agreement being right about
a world the project built to be wrong. `--strict` is a debugging mode for
one landing, not a gate to put in CI.


## Keeping this honest

- `agreements.planned_says_what_it_waits_on` — an agreement with no
  evaluator must declare `ag_waiting_on`, so a new planned row cannot be
  registered without saying what is in its way. It replaces
  `agreements.landing_doc_lists_every_agreement`, which pinned that this
  file had a row per agreement; the catalogue is generated from the
  registry and covers every agreement by construction, so that pin was
  asserting what the generator guarantees.
- `make canary-agreement-roundtrip` gates the landed rows against a real
  sqlite run, inside `make canary-post-check`.

## Where the neighbouring material went

- **What each agreement IS, and what is in its way** —
  [`catalogue.md`](catalogue.md), generated.
- **`canary result`'s per-cell marks and blames** — [`../matrix.md`](../matrix.md).
  A verdict is a symbol, a gap is a word, and every non-verdict cell in
  a check column carries who to blame.
- **Could decide vs did decide, per project** — `canary checks <p>`
  prints it, with a five-class gap summary.
- **The open work that is not per-agreement** — `../../backlog.md` §51.
