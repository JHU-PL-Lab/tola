# The action model — what an action is, what happens at its edges, and who decides

**Kind: rationale for §§1–3 and §5's occasions table**, which describe
what runs; **proposal for the rest.** **Landed when** a step carries no
boolean closure and `canary_gh.ml` still contains no verdict logic,
because by then it needs none.

Read it before adding an action, before adding a step whose name ends in
`_inspect`, before deciding where a check attaches, and before changing
anything in the agreement layer that resolves an evidence path. **If you
are coming from the agreement side, read §6 and stop** — it is what
breaks if this model moves. The procedure for *adding* an action is
[`action_playbook.md`](action_playbook.md); this is the model it
realizes.

## 1. An action is a moment with a typed footprint

An action is a node of the catalogue (`Canary_basic.store_actions`, SSOT
§6.5). It has a **name** (`build_lib`, `probe_binding_ocaml`), which is
also its step tag and output directory; a **footprint**
(`consumes_of_action` / `produces_of_action`, in coarse
`artifact_kind`s); and a **version rule** (`Ambient` | `Follows_input`).

Everything else — the shell command, the checks around it, the evidence
it leaves — is *not* part of the action. It is per-project, or derived,
or both. Every confusion below is one of those three written down as
though it were the action.

## 2. `<action>_post` is a hook, not a specification

`canary result`'s columns read `pre → action → artifact → post`. The
`_post` half is **a trigger moment: "the action has run, its outputs
exist"** — not a statement of what runs there.

The test of that: a library inspection (`nm -D` over the built object,
recorded as a summary) should run at `build_lib_post` when canary built
the library, at `fetch_lib_post` when a package manager delivered it, at
`install_lib_post` when it was staged, and at a `fetch_package_post` for
a package that *contains* a library, which canary does not model yet. It
is the **same inspection**; only **where the file is** differs. So it is
a property of the artifact, invoked at whichever moment produced it —
the moment asks *"what did I just produce, and what is there to say
about it?"*

Three consequences:

- **`build_lib_inspect` as a standalone step is wrong.** A check that
  needs `nm -D` should run `nm -D`. A step whose only job is to leave a
  file for a later step buys nothing and costs the addressing problem.
  Not hypothetical: a stub inspection added through the explicit
  `inspect` channel wrote correct evidence, that evidence was read
  correctly, and the step failed for a day — the channel hardcodes every
  summary's base name to `inspect`, so the stub landed at
  `inspect_stub_<vk>.json` and was judged against `inspect_<vk>.json`.
  The evidence arrived; the address did not.
- **`build_lib/` as a directory is necessary.** Logs, markers and
  outputs are per-moment.
- **`build_lib_post` as a column is right.** A column per moment is
  exactly the shape. What the column *carries* is derived.

## 3. The join — the hook's question, answered

A hook must answer "what did I just produce" in the project's own
vocabulary. `consumes_of_action` speaks in coarse KINDS (`Lib`,
`Binding OCaml`); a project declares refined IDENTITIES
(`A_lib (Some "crypto")`, `A_binding (OCaml, Cstubs)`). Nothing joined
them until pass 2 — spec-only and world-free, which is pass 2's
membership rule
([`enumeration/stage2_analyse_spec.md`](enumeration/stage2_analyse_spec.md)):

```
an_touches : (action * { tc_consumes; tc_produces }) list
```

| function | question |
| --- | --- |
| `touches an action` | what does this action touch here? `None` = not in this project |
| `produced_at an action` | **the hook's question** — what did it just make? |
| `producers_of an artifact` | backwards — where could this artifact's evidence come from? |

Print it: `canary emit sqlite --stage analyse`, or `--json`.

**Two lists, not one:** a hook reads the produced side, a precondition
the consumed side. The flat `artifacts_of_action` concatenates them,
which is right for the diagram and wrong for a hook. **And it returns
LISTS per kind**, not the first match —
`Canary_enumerate.find_artifact_of_kind` returns the first declared
artifact of a kind, which is already wrong (tiny-full declares two apps
and two Python bindings).

Pinned by `analysis.touches_joins_actions_to_declarations`: the join is
total over a project's declarations, a `Probe_*` produces nothing, and a
lib has more than one producer — the fact the hook model stands on.

**Nothing consumes the join yet.** §§4–9 are why.

## 4. What hangs at a hook is a check, and what checks carry

```ocaml
dep_dirs   : string list;   (* each dep's output dir; all must exist *)
check_post : output_dir:string -> variant_key:string -> bool;
```

Checks exist because commands lie: a build can exit 0 and produce
nothing; an opam fetch can exit 0 while the switch holds a different
version. The acceptance policy is *"the command succeeded **and** its
postcondition holds"*, and that second conjunct is the only reason a
step can fail after a successful command.

**`canary_gh.ml` renders `check_post` zero times** (measured
2026-09-21), so:

> **A green CI job means "every command exited 0". Nothing more.**

The sqlite pin bug surfaced locally as `check_post (FAIL)` after a
successful command. On CI that judgement does not exist — nor for a
staged lib that installs nothing, a fetch whose marker never appears, or
a build that produces no artifact. A closure cannot cross into rendered
YAML, so the backend either inlines a decision it computed itself or
omits the check. **The compiler emits decisions where it should emit
calls to a decision procedure**, and every bug in that class has been
the emitted shell disagreeing with the runner it mirrors.

### What the closures carry

**`check_pre` carried nothing** — no project ever supplied one, and the
predicate was one sentence. It is now `dep_dirs : string list`, data
(§9 step 1).

**`check_post` carries a closed vocabulary of six**, each *markers
exist* ∧ *(at most one extra probe)*:

| compositor | the extra conjunct | as shell |
| --- | --- | --- |
| `default_check_post` | — | `test -f` |
| `check_markers` | — | `test -f a && test -f b` |
| `has_file` (inline, inspect/scan steps) | — | `test -f` |
| `check_build_lib` | a native lib exists at a path | a glob test |
| `check_build_binding` | an OCaml archive exists at a path | a glob test |
| `pin_check_post` | the store holds `pkg@pin` | **already a shell string** |

**Every project-level override is `pin_check_post`** — sqlite, ssl, z3,
llvm, torch and the opam-binding template, one compositor six times,
differing in three strings `(pkg, pin, marker)`.

### The diagnosis: `step` is two types wearing one name

The closures do not fail because they cannot travel. They fail because
they sit in a record whose other consumers do not want them. There is a
*description of work* (tag, action, deps, expectation, `agreement_ctx`)
and an *executable plan* (`cmd`, `check_post`). Four backends consume the
step list; only the runner wants the second half. The tell is
`Canary_run_info.load_run_state`, which rebuilds a step from disk to
render HTML and must fabricate dead closures to get a view — two now,
three before step 1. The type cannot say that half of it is execution,
so every consumer works around it differently.

A closure earns its place when the predicate set is **open and
project-authored**. This one is closed at six and none are
project-authored. That is a data shape wearing a function's clothes.

## 5. Who evaluates a check, and when

Locally OCaml is the **interpreter**: canary runs, so checks are
functions it calls. For CI — and for a remote runner over ssh
([`../status.md`](../status.md) §2.1) — OCaml is the **compiler**: it
emits commands, and the far side has no running canary to call. The same
boundary twice.

**One constructor, or none.** A `check_post_sh : string` hand-written
beside the closure is a second representation of one decision, which is
the disease above. A check's predicate and its rendering must come from
one constructor, or the check must simply BE a command the runner
interprets like any other.

**Derived beats declared.** The standing fear about checks-as-data is
that the vocabulary grows into an expression language. The answer is not
a disciplined small ADT: it is that *"did this action produce its
artifacts?"* is `produced_at` plus a locator, and **a derived check
cannot grow**.

### A check is evaluated at three occasions

Measured in `canary_local_runner.ml`. This is the fact that decides
where the store predicate can live:

| occasion | where | what a failure does |
| --- | --- | --- |
| **graph start** — seed this step as already done? | `run_graph` ~892 | removes the marker; the step runs fresh |
| **warm gate** — skip this step? | `run_step` 453, 468 | removes the marker; the step runs |
| **after the command** — did the action do its job? | `run_step` 634 | the step **fails** |

The first two are one question — *is my cached verdict still true?* —
and the third is acceptance. The same predicate is correct at all three,
which is why the 2026-08-17 fix made the warm gate consult it.

**What differs between the compositors is whose hands the subject is
in.** A marker, or a `.so` this step built, changes only when this step
runs, so the early occasions are cheap insurance. `pin_check_post`'s pin
half is the only one whose subject is a **shared, single-valued store
that another scenario mutates**, so for it alone they are load-bearing:
scenario A's marker must not be served after scenario B re-pinned the
switch.

**So the pin half cannot become a `Canary_world` prelude.** `Opam_pin`
renders through `pre_shell` and aborts a command; the case the pin half
prevents is the one where the step is *skipped* and no command runs.
Adding a post position to that type would not help — the decision
happens before there is a command to prefix. `pin_check_post` *is* a
world assertion by what it asserts ([`agreement/theory.md`](agreement/theory.md)
§7.1 has classified it as one since 2026-09-15); what §6's registers
give is what a failure **means**, and the occasion gives what it
**does**. For the world register those differ — before the command it
aborts, at the warm gate it invalidates and re-runs — and both are
correct.

⚠ **The still-valid predicate is already written twice**: `run_step`
445-456 and `run_graph` 885-896 hold the same three branches (marker
exists, fingerprint matches, postcondition holds), the same event names
and the same removal. Whatever names this occasion should collapse them.

## 6. What the agreement layer needs from this model

*agreement/ owns the CLAIM; this document owns the OCCASION.* Both
READMEs state it that way. This section is here because §9 touches code
on the far side of the line.

| question | owner |
| --- | --- |
| what is claimed, against what evidence, to what `outcome` | [`agreement/README.md`](agreement/README.md) |
| whether a claim applies at all | pass 2 ([`stage2_analyse_spec.md`](enumeration/stage2_analyse_spec.md)) |
| **when it fires, where its evidence is, who evaluates it** | here, and [`stage6_realize_steps.md`](enumeration/stage6_realize_steps.md) §2b |

**One fact is misplaced in code**, which is different from the five
legitimate reads below: the agreement layer may read this model, but it
should not host a fact belonging to it. `binding_evidence_tag` and
`lib_evidence_tags` live in `agreement/canary_agreement_common.ml` and
map a world to the step tag where evidence should be. They are waiting
to be **derived** from `producers_of` (§9 step 5) — not moved, which
would relocate the duplication rather than remove it.

### Does a named check's failure fail its step?

**Decided 2026-09-21** from the agreement side, which owns `outcome` and
the acceptance policy.

**A named check's failure fails its step iff the check is a
POSTCONDITION — an assertion about what THIS action was asked to
produce. Never because it carries an agreement's name.** Naming is not
authority: step 7's win is that a reader sees *which* check failed
instead of "the probe failed", and a label must not smuggle semantics.

⚠ **The authority must be a function of the CONSTRUCTOR, not a value an
implementer supplies** — §5's one-constructor discipline applied to
authority instead of rendering. Each register has exactly one origin:
derived from the join → postcondition, built from `Canary_world.t` →
world assertion, selected from the registry → agreement. A
free-standing field can be set wrong, and a wrong value here is
invisible.

The distinguishing question is **whose obligation was it**, and there
are three registers:

| the check asserts | fails the step | because |
| --- | --- | --- |
| an artifact the action was asked to produce is at its location | **yes** | the action's own contract. This is what `check_post` is |
| the world is the one this scenario declared — the pin holds, the ref resolves | **yes, and loudest** | not a finding about software: this run tested something other than what it claims, so every verdict in it is suspect ([`agreement/theory.md`](agreement/theory.md) §7.1). `Canary_world`'s `Opam_pin` / `Log_names` |
| an agreement over the artifacts | **no** — yes under `--strict` | the action was never asked to make the claim true. sqlite's `dse ✗` at `build_lib` is a real violation of a declaration the compiler was not asked to satisfy; the build did its job |

Two constraints, both easy to lose:

- **`--strict` stays RUN-WIDE.** It is the one switch that makes the two
  views agree, it rides the step fingerprint, and it is pinned
  (`strict.acceptance_policy`). Step 7 must not turn it into per-check
  configuration.
- **A check's verdict stays boolean.** An agreement's is an `outcome`
  with eight constructors and ten labels — `unavailable` / `undeclared`
  / `vacuous` are distinct reasons a claim reached no verdict, and
  collapsing them into `false` is exactly what `unavailable_cause`
  undid. A named check has no need of `outcome`.

### Five couplings, each with the pin that catches it

Run `make canary-test` after every step; it is five seconds and every
one of these is in it.

| what the agreement layer reads | where | if §9 moves it |
| --- | --- | --- |
| **`ag_rooted_in.rt_action` is a STRING**, parsed by `action_of_string` | 10 registry rows | a renamed or split action stops parsing → the `R` mark silently vanishes. `agreements.rooting_names_an_action`, `agreements.overview_matches_rooting` |
| **`ag_slot` maps a claim to (action, stage)** — its column in `canary result` | every row | a moved action moves or deletes a check column. `matrix.key_explains_every_check_column`, `checks.index_speaks_each_action_language` |
| **`m_firing` names actions** — `firing_default`, `firing_lib_declaration`, `firing_probe_only` | `canary_agreement_common.ml` | a split changes WHERE claims fire: semantics, not a rename. `agreements.firing_defaults` |
| **The overview's columns ARE `store_actions`** | `overview_columns ()` | the table's width, row order and `lag` move with the catalogue. `agreements.rows_obey_their_own_laws`, `agreements.overview_groups_a_claims_patterns`, `matrix.page_titles_and_agreement_overview` |
| **`retarget_action` enumerates the lang-carrying constructors** | `canary_agreement.ml` | a NEW constructor carrying a language must be added there, or a row's `R` lands in another language's column. `agreements.rooting_speaks_the_rows_language` |

**Step 5 is the dangerous one, and `make canary-test` is not its gate.**
Retiring `binding_evidence_tag` / `lib_evidence_tags` changes where every
method looks for its evidence. Get it wrong and each landed agreement
quietly reports `unavailable` — not a test failure, a check that stopped
checking. The guard exists:

```sh
make canary-agreement-roundtrip      # inside make canary-post-check
```

It clears the deciding steps' markers, runs sqlite cold, and requires
seven NAMED agreements to reach `holds` or `violated` from that run
(`CANARY_LANDED_AGREEMENTS` in the Makefile). **That gate staying green
is the acceptance criterion for step 5**, and the only one that
distinguishes "the paths still resolve" from "the tests still pass".
`agreements.derived_evidence_matches_projects` is its static half.

**Step 8 inherits the risk.** `lib_evidence_tags` names `probe_lib`,
`probe_lib_staged` and `probe_lib_apt`, so splitting `probe_lib` renames
the tag role 2 (inspection) writes under. Do 5 first and the tags are
derived, so 8 is a rename the derivation follows; do 8 first and it is
four hand-edits and a silent `unavailable`.

**An opportunity, not a requirement.** `Probe_binding of lang` carries a
language and no MECHANISM, so tiny-full's two Python bindings (`Cext`,
`Ctypes`) realize one step, one log tag and one matrix column, and pass 2
sees only the first. `analysis.one_mechanism_per_language` ratchets it as
a named exception. If §9 opens the action vocabulary anyway, that is the
cheapest moment to add the mechanism.
[`../project/issues.md`](../project/issues.md) §2.

**What is NOT coupled.** The kind taxonomy, the row laws' content, the
external-tool rows and the saturation grid are about claims and
mechanisms rather than actions. Only `a_row_does_something` reads the
action cells, and it reads them as a guard — a claim left firing nowhere
by a split is exactly what it should report.

## 7. One design under two names: the umbrella and `[Pre; Action; Post]`

`status.md` §5's *"checks as actions — `[Pre; Action; Post]`"* (user,
2026-08-18, *"compiler perspective"*) says a moment's judgements should
be graph citizens the runner interprets. The roster measurements below
arrived at the same place from the other end: `probe_lib` becomes an
**umbrella**, where the moment keeps its name, directory and column
while the concrete checks under it take their names from the agreement
registry, so a reader sees *which* check failed.

Same shape — the moment is the node, the named checks are what it
carries. They are one design, so build one mechanism.

### `probe_lib` is three roles wearing one name

Measured 2026-09-15 by reading the commands:

| role | what it does | where it lives today |
| --- | --- | --- |
| **existence** | the artifact the world declares is there | `probe_lib`'s `test COUNT -gt 0` |
| **inspection** | record a projection as evidence | `probe_lib`'s appended summary; ALSO `build_lib`'s |
| **execution** | load it, run it, observe | **nowhere** |

`probe_lib` is static: `nm -D | grep -c <prefix>` then `test COUNT -gt
0`. Nothing loads, nothing executes. `probe_binding` *is* runtime and
fuses all three roles in one `&&` chain.

- **Role 1 is a degenerate ancestor of a landed agreement.** "count > 0"
  is the weakest "exports what was declared", and
  `declared_symbols_exported` reads the NAMES. So role 2 is what the
  step is really for.
- **Nothing ever `dlopen`s a library.** A lib can pass every static
  check and fail to load — a missing transitive `NEEDED`, an
  unresolvable `RUNPATH`, a version-script mismatch the symbol table
  does not show. A role-3 `probe_lib` is NEW COVERAGE, and it is the
  identity half [`agreement/theory.md`](agreement/theory.md) §5.9 calls
  missing.

## 8. One locator vocabulary, under all of it

Measured across the roster: all 13 `probe_lib*` steps run `nm -D` over
the resolved file; all 11 `probe_binding_ocaml` + `probe_app_ocaml`
steps compile and run an example. **llvm's `probe_lib` is the one
outlier** — `llvm-config --version` is *discovery*, not inspection. And
`build_lib` and `probe_lib` inspect the SAME file and write IDENTICAL
content (sqlite: 270 symbols, same hash); five such pairs exist.

**So the only genuinely per-project part of a lib inspection is the
LOCATOR** — everything after `LIB_NATIVE=…` is already shared. And three
locator vocabularies exist for one question:

| vocabulary | who uses it |
| --- | --- |
| typed `probe_lib_location` | sqlite, z3, llvm |
| `lib_locator` globs | the opam-binding template (cairo, libffi, zarith, zlib, zstd) |
| raw shell | llvm's `probe_lib` |

Deriving an inspection must resolve a location; so must a derived
`check_post`, to ask whether the artifact appeared. **One locator
vocabulary is a prerequisite for both**, which is why two refactors turn
out to be one.

## 9. The ordered plan

Tracked as [`../backlog.md`](../backlog.md) §52. **Step 3 gates
everything below it** and is the head of the queue. Landed and withdrawn
steps keep their slots, so "step 5" means step 5 everywhere.

1. ~~**Delete `check_pre`.**~~ **LANDED 2026-09-21** — exchanged for
   data, not deleted: `dep_dirs : string list`, resolved in
   `derive_steps` (which has the step list, so it can resolve an
   `output_tag`) and evaluated in the runner. The closure carried an
   address, not a decision. `load_run_state` no longer stubs it, and
   `steps.dep_dirs_correspond_to_deps` pins it — the first pin this
   predicate has had, because a closure can be called but not read.
   ⚠ Nothing currently depends on a step carrying an `output_tag`, so
   the pin guards the correspondence now and the resolution once step 4
   gives the attached inspectors consumers.
2. ~~**Split `pin_check_post`.**~~ **WITHDRAWN 2026-09-21** — §5's
   occasions table is why: the pin half is evaluated before a step is
   skipped, where its failure invalidates a marker, and a `pre_shell`
   prelude cannot do that. Its closure is removed by step 6 instead.
3. **One locator vocabulary.** Three exist (§8). Self-contained, and the
   blocking item for everything below.
4. **Derive the inspection from the join.** At `<action>_post`, for each
   artifact in `produced_at`, run the inspection that artifact's kind
   defines, resolved at the location the world gives.
5. **Retire the world→tag maps.** `binding_evidence_tag` /
   `lib_evidence_tags` become `producers_of` plus the world's provision
   — derived, and the same function the producer side uses. Closes the
   placement class (backlog §50) and settles backlog §49's ownership
   question: derived from the join, the map stops living in the
   agreement layer. ⚠ **Acceptance is `make canary-agreement-roundtrip`,
   not `make canary-test`** — see §6.
6. **Derive `check_post` from the join**, with a constructor for the
   store predicate: one definition, evaluated in process at all three of
   §5's occasions and rendered to shell for any other interpreter. This
   is where step 2's closure goes, and it collapses §5's duplicated
   still-valid gate. [`artifact_cache.md`](artifact_cache.md) §4.5 is the
   same question one strength up ("the key is present and its recorded
   hash matches"), so read it when designing the constructor.
7. **Name the checks under a moment** (§7), with §6's authority rule:
   the register comes from the constructor, and `--strict` stays
   run-wide.
8. **Split `probe_lib` into its three roles** and add role 3.

**Order.** 4 without 3 hand-writes a locator per project; 5 without 4
leaves two addressing schemes; 6 without 3 rebuilds the locator a third
time; 8 after 5, or it is four hand-edits and a silent `unavailable`.

## 10. Where this sits, and what it does not cover

- The pass that owns the join —
  [`enumeration/stage2_analyse_spec.md`](enumeration/stage2_analyse_spec.md).
- The pass that realizes a step, and §2b on when a check fires —
  [`enumeration/stage6_realize_steps.md`](enumeration/stage6_realize_steps.md).
- Adding an action, procedurally —
  [`action_playbook.md`](action_playbook.md).
- What a check CLAIMS, as against when it fires —
  [`agreement/README.md`](agreement/README.md).
- The result table these moments are the columns of —
  [`matrix.md`](matrix.md).

**[`artifact_cache.md`](artifact_cache.md) is deliberately separate.** It
answers *when may I skip work?*, not *did the work succeed?* The two meet
at one question — what a postcondition asserts about an artifact — and
its §4.5 points back here, so whichever of the two lands second reads the
other. Its §6 is the specimen where two independent caches both said "up
to date" about a binding linked against a soname no longer on the
machine.

**Out of scope: the expectation machinery.**
`predicted_contains_any_v2` parses the `inspect.json` a run produced and
drives the comparators. That is real OCaml over real data and *not*
shell-shaped, which is why the GH backend resolves predictions at
generation time from the laptop's cache, and why an xfail there is
checked by signature when that cache exists (ssl) and by polarity alone
when it does not (llvm). The cheap half is §9; the expectation half is
its own problem.
