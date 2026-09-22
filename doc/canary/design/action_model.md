# The action model — what an action is, what happens at its edges, and who decides

**Kind: rationale for §§1–3**, which describe what runs today;
**proposal for §§4–9**, which do not; §10 is pointers. **Landed when** a
step carries no boolean closure and `canary_gh.ml` still contains no
verdict logic — because by then it needs none.

Read it before adding an action, before adding a step whose name ends in
`_inspect`, before deciding where a check attaches, and before changing
anything in the agreement layer that resolves an evidence path. The
procedure for *adding* an action is
[`action_playbook.md`](action_playbook.md); this is the model the
playbook realizes.

> Opened 2026-09-16 (user), from a question the codebase had answered
> four times in four places without ever stating: **what does
> `<action>_post` actually mean?** The answer is a distinction — a
> *moment* versus a *specification* — and the join it needs did not
> exist. It does now.
>
> Merged 2026-09-21 with `check_evaluation.md` (2026-08-30), which had
> reached the second half of the same subject from the opposite side: a
> CI backend that kept re-implementing verdicts and getting them wrong.
> One document, because "what a hook is" and "what may hang at one" turn
> out to be a single question with a single blocker.

## 1. An action is a moment with a typed footprint

An action is a node of the catalogue (`Canary_basic.store_actions`, SSOT
§6.5). It has:

- a **name** (`build_lib`, `probe_binding_ocaml`), which is also its step
  tag and its output directory;
- a **footprint** — `consumes_of_action` / `produces_of_action`, in coarse
  `artifact_kind`s;
- a **version rule** (`Ambient` | `Follows_input`) saying whether it
  inherits its inputs' version.

Everything else about it — the shell command, the checks around it, the
evidence it leaves — is *not* part of the action. It is per-project, or
derived, or both. Every confusion in this document is one of those three
written down as though it were the action.

## 2. `<action>_post` is a hook, not a specification

`canary result`'s columns read `pre → action → artifact → post`. The
`_post` half is **a trigger moment: "the action has run, its outputs
exist"**. It is not a statement of what runs there.

Here is the test of that. A **library inspection** — `nm -D` over the
built object, recorded as a summary — should be runnable at
`build_lib_post` when canary built the library, at `fetch_lib_post` when
a package manager delivered it, at `install_lib_post` when it was staged
into a prefix, and at a `fetch_package_post` for a package that happens
to *contain* a library, which canary does not model yet.

It is the **same inspection** in all four. What differs is only **where
the file is**. So the inspection cannot be a property of `build_lib`; it
is a property of the artifact `lib`, invoked at whichever moment this
world actually produced it. From the invoking side, in the user's phrase:
the moment asks *"what did I just produce, and what is there to say about
it?"* — rather than each action carrying a hand-placed list.

### What this rules out, and why

**`build_lib_inspect` as a standalone step is wrong.** A check that needs
`nm -D` should just run `nm -D`. A step whose only job is to leave a file
for a later step to read buys nothing and costs the addressing problem:
two names, two tags, two chances to disagree.

That is not hypothetical. A stub inspection added through the explicit
`inspect` channel wrote correct evidence, that evidence was read
correctly, and **the step failed for a day** — because the channel
hardcodes every summary's base name to `inspect`, so a stub attached
through it lands at `inspect_stub_<vk>.json` and is judged against
`inspect_<vk>.json`. The evidence arrived; the address did not.

**`build_lib/` as a directory is necessary.** Logs, markers and outputs
are per-moment and have to live somewhere per-moment.

**`build_lib_post` as a column is still right.** An action ran, and
something is true afterwards that was not true before. A column per
moment is exactly that. What the column *carries* is derived.

## 3. The join — the hook's question, answered

A hook must answer "what did I just produce" in the project's own
vocabulary, and that answer did not exist. `consumes_of_action` speaks in
coarse KINDS (`Lib`, `Binding OCaml`); a project declares refined
IDENTITIES (`A_lib (Some "crypto")`, `A_binding (OCaml, Cstubs)`).
Nothing joined them.

The join is **pass 2** — spec-only and world-free, which is pass 2's
membership rule
([`enumeration/stage2_analyse_spec.md`](enumeration/stage2_analyse_spec.md)):

```
an_touches : (action * { tc_consumes; tc_produces }) list
```

with three questions over it:

| function | question |
| --- | --- |
| `touches an action` | what does this action touch here? `None` = not in this project |
| `produced_at an action` | **the hook's question** — what did it just make? |
| `producers_of an artifact` | the hook's question backwards — where could this artifact's evidence come from? |

Print it with `canary emit sqlite --stage analyse` (the join is the first
table), or `--json` for a diffable form.

**Two lists and not one**, deliberately: a hook reads the produced side, a
precondition the consumed side. The flat `artifacts_of_action`
concatenates them, which is right for the diagram and wrong for a hook.
**And it returns LISTS per kind**, not the first match:
`Canary_enumerate.find_artifact_of_kind` returns the first declared
artifact of a kind, which was fair while every project had one lib and one
binding per language, and is already wrong — tiny-full declares two apps
and two Python bindings, and `A_lib of string option` landed in 2026-08-25
for the second lib that is coming.

Pinned by `analysis.touches_joins_actions_to_declarations`, which asserts
the join is **total** over a project's declarations (a declared artifact no
action reaches is unreachable), that a `Probe_*` **produces nothing**, and
that a lib has **more than one** producer — the fact the hook model stands
on.

Nothing consumes the join yet. §§4–9 are why.

## 4. What hangs at a hook is a check — and today a check is a closure

The step model says it plainly:

```ocaml
check_pre  : unit -> bool;
check_post : output_dir:string -> variant_key:string -> bool;
```

These exist because commands lie. A build can exit 0 and produce nothing;
an opam fetch can exit 0 while the switch holds a different version. The
acceptance policy is therefore *"the command succeeded **and** its
postcondition holds"*, and that second conjunct is the only reason a step
can be judged failed after a successful command.

### What a green CI job means today

`canary_gh.ml` renders `check_pre` and `check_post` **zero times** —
still true, measured 2026-09-21.

> **A green CI job means "every command exited 0". Nothing more.**

Locally the sqlite pin bug surfaced as `check_post (FAIL)` after a command
that succeeded, because the switch did not hold the declared pin. On CI
that judgement does not exist. Neither would a staged lib that installs
nothing, a fetch whose marker never appears, or a build that produces no
artifact — every failure mode `check_post` was written to catch.

A closure cannot cross into rendered YAML, so the backend has two options
and takes both badly: inline a decision it computed itself, or omit the
check. **The compiler emits decisions where it should emit calls to a
decision procedure.** That cost three bugs in one day, all of them the
emitted shell disagreeing with the runner it was meant to mirror — a
derived expectation rendered with the oracle's polarity, an unresolved
prediction read as "artifact is good", and a verify grepping a log
filename the step does not write. Each was fixed in the shell copy. None
could have existed with one copy.

### What the two closures actually carry, measured

This is the part that decides the design, and it was measured 2026-09-21
rather than assumed.

**`check_pre` carries nothing.** No project supplies one. There is exactly
one formula, built in `Canary_step_builder.mk_step` and rebound once in
`derive_steps` against a tag→`output_dir` map:

> every dep tag's `output_dir` exists

It is a closure only because it needs that map at construction time.
`run_graph` already holds the whole step list.

**`check_post` carries a closed vocabulary of six**, every one of shape
*markers exist* ∧ *(at most one extra probe)*:

| compositor | the extra conjunct | as shell |
| --- | --- | --- |
| `default_check_post` | — | `test -f` |
| `check_markers` | — | `test -f a && test -f b` |
| `has_file` (inline, inspect/scan steps) | — | `test -f` |
| `check_build_lib` | a native lib exists at a path | a glob test |
| `check_build_binding` | an OCaml archive exists at a path | a glob test |
| `pin_check_post` | the store holds `pkg@pin` | **already a shell string** |

And **every project-level override is `pin_check_post`** — sqlite, ssl, z3,
llvm, torch and the opam-binding template, the same compositor six times,
differing in three strings `(pkg, pin, marker)`. The vocabulary has not
grown since the compositors were gathered into one file.

### The diagnosis: `step` is two types wearing one name

The closures do not fail because they cannot travel. They fail because
they are in a record whose other consumers do not want them.

There is a *description of work* — tag, action, deps, expectation,
`agreement_ctx` — and an *executable plan* — `cmd`, `check_pre`,
`check_post`. Four backends consume the step list; only the runner wants
the second half. The tell is `Canary_run_info.load_run_state`, which
rebuilds a step from disk to render HTML and must fabricate **three dead
closures** (`cmd` returns `""`, both checks return `false`) to get a view.
Meanwhile `canary_gh` silently drops two of them. The type cannot say that
half of it is execution, so every consumer works around it differently.

The second reading is about fit. A closure earns its place when the
predicate set is **open and project-authored**. Here it is closed at six,
and none are project-authored — six projects reach for one compositor with
three string parameters. That is a data shape wearing a function's
clothes.

## 5. Who evaluates a check — and why the closure goes

Locally, OCaml is the **interpreter**: canary runs, so a step's checks are
functions it calls. For CI — and for a remote runner over ssh
([`../status.md`](../status.md) §2.1) — OCaml is the **compiler**: it emits
commands, and the far side has no running canary whose functions can be
called. The same boundary, twice.

**One constructor, or none.** The tempting shortcut is a `check_post_sh :
string` beside the closure, hand-written. That is a second representation
of one decision — precisely the disease that produced the three bugs
above. If a check has a predicate and a rendering, both must come out of
one constructor; or the check must simply BE a command the runner
interprets like any other.

**Derived beats declared.** The standing fear about making checks data is
that the vocabulary grows into an expression language, at which point a
shell has been rebuilt inside OCaml types. The answer is not to keep a
small ADT disciplined. It is that after §9's steps there is almost nothing
left to declare: *"did this action produce its artifacts?"* is
`produced_at` plus a locator, and **a derived check cannot grow.** That is
why a small dual ADT is not worth building as a stepping stone — not
because a later redesign deletes it, but because the derivation is
reachable directly.

**And one closure is already a shell-out wearing a predicate's clothes.**
`pin_check_post` calls `Canary_store.sh_in_switch`. As a command it
becomes *more* honest, not less.

### `pin_check_post`: two claims, and neither one moves

It is a conjunction of two different claims, and only one of them is a
postcondition:

```ocaml
has_file marker                                    (* the step's output exists *)
&& sh_in_switch (holds_pin_cmd ~pkg ~pin) = 0       (* the switch holds pkg@pin *)
```

The first is an ordinary `check_post`, derivable from the join. The second
is a statement about **which world this is**, and canary already has a
typed vocabulary for exactly that: `Canary_world.t`, whose `Opam_pin`
constructor renders to shell through `pre_shell`. CLAUDE.md already calls
them siblings — *`pin_check_post` proves the fetch left the pin in place;
the world assertion proves the PROBE ran in that world.*

⚠ **`Canary_world`'s header refuses the conflation, and it is right to.**
It states that a world assertion "is not a `check_pre`/`check_post`
(whether the step's inputs and outputs exist)… Those say what happens in a
world; this says which world it is." So the move is a **split along that
line**, not a relocation of the whole compositor. Reading it the other way
would put "the marker exists" into a type about identity.

⚠ **But the pin half does not move to `Canary_world` either, and the
reason is the next subsection.** That conclusion stood here until
2026-09-21 and was wrong: `Opam_pin` renders as a `pre_shell` prelude that
aborts a command, and aborting a command is not what the pin half does.

### A check is evaluated at three occasions, not one

Measured in `canary_local_runner.ml`, because this is the fact the split
above was missing:

| occasion | where | what a failure does |
| --- | --- | --- |
| **graph start** — should this step be seeded as already done? | `run_graph`, ~line 892 | removes the marker; the step runs fresh |
| **warm gate** — should this step be skipped? | `run_step`, ~lines 453, 468 | removes the marker; the step runs |
| **after the command** — did the action do its job? | `run_step`, ~line 634 | the step FAILS |

The first two are one question — *is my cached verdict still true?* — and
the third is acceptance. The same predicate is correct at all three, which
is why the 2026-08-17 fix made the warm gate consult it; that is not an
accident to be tidied away.

**What differs between the compositors is whose hands the subject is in.**
A marker, or a `.so` this step built, changes only when this step runs (or
someone deletes a file), so evaluating it at the first two occasions is
cheap insurance. `pin_check_post`'s pin half is the only one whose subject
is a **shared, single-valued store that another scenario mutates** — so
for it alone the early occasions are load-bearing rather than defensive.
That is the whole reason it exists: scenario A's marker must not be served
after scenario B re-pinned the switch.

So `Canary_world` cannot take it. A prelude that aborts a command never
runs when the step is *skipped*, and skipping is precisely the case the
pin half is there to prevent. Nothing in that type can invalidate a
marker, and adding a post position would not help — the decision happens
before any command exists to prefix.

**The reconciliation with §6, which this extends rather than contradicts:**
`pin_check_post` *is* a world assertion by what it asserts, exactly as
[`agreement/theory.md`](agreement/theory.md) §7.1 classifies it. §6's
registers say what a failure **means**. The occasion says what it
**does** — and for one register those differ: a world assertion caught
before the command aborts loudly, while the same assertion caught at the
warm gate invalidates and re-runs, which is the correct quiet response.
Both are right. §6 answered the acceptance question and did not need this
axis; step 2 did, and assumed a single occasion.

⚠ **And the still-valid predicate is already written twice.**
`run_step` (445-456) and `run_graph` (885-896) each hold the same three
branches — marker exists, fingerprint matches, postcondition holds —
with the same event names and the same removal. Two copies of one
decision, which is §4's diagnosis about the GH backend appearing a second
time inside the runner. Whatever names this occasion should collapse them.

**So no project-supplied check closure is removed by a split.** It is
removed by making `check_post` data with a constructor for the store
predicate — one constructor, evaluated in process at all three occasions
and rendered to shell for any other interpreter, which is §5's own rule
and §9's step 6. Step 2 has nothing left of its own to do.

## 6. The seam with the agreement layer

*agreement/ owns the CLAIM; this document owns the OCCASION.* Both READMEs
state it the same way, and the reason to restate it here is that the work
in §9 touches code on the far side of the line.

| question | owner |
| --- | --- |
| what is claimed, against what evidence, to what `outcome` | [`agreement/README.md`](agreement/README.md) |
| whether a claim applies at all | pass 2 ([`stage2_analyse_spec.md`](enumeration/stage2_analyse_spec.md)) |
| **when it fires, where its evidence is, who evaluates it** | here, and [`stage6_realize_steps.md`](enumeration/stage6_realize_steps.md) §2b |

**The line is MISPLACED in code today, in one place** — which is not the
same as the five legitimate READS the subsection below enumerates. The
agreement layer is entitled to read this model; what it should not do is
host a fact belonging to it. `binding_evidence_tag` and `lib_evidence_tags`
live in `agreement/canary_agreement_common.ml` and map a world to the step
tag where evidence should be. That is an occasion fact inside the claim
layer. It is waiting to be **derived** from `producers_of` (§9 step 5) —
*not moved*, because moving it would relocate the duplication rather than
remove it.

**Two distinctions to hold while doing this work**, because both are easy
to lose and each has already cost a bug:

1. **A check is not an agreement, and they fail differently.** A failed
   `check_post` fails its step. A violated agreement does **not** — the
   acceptance policy is "the command succeeded and its postcondition
   holds", and a disagreement about artifacts the action was never asked
   to fail on stays a finding (`--strict` flips this, deliberately, for
   one landing at a time). Inheriting either semantics by accident would
   turn ssl red for a real-but-tolerated finding, or silently demote
   `check_post` to advisory.

   **DECIDED 2026-09-21** (asked by the agent who would own §9 step 7,
   answered from the agreement side, which owns `outcome` and the
   acceptance policy).

   **A named check's failure fails its step iff the check is a
   POSTCONDITION — an assertion about what THIS action was asked to
   produce. Never because it carries an agreement's name.** Naming is
   not authority: step 7's win is that a reader sees *which* check
   failed instead of "the probe failed", and a label must not smuggle
   semantics with it. So the check constructor carries its authority as
   its own field; it is not read off the name, and it is not read off
   the registry.

   ⚠ **And the field must be a function of the CONSTRUCTOR, not a value
   an implementer supplies** — which is §5's "one constructor" discipline
   applied to authority instead of to rendering. Each register has exactly
   one origin: a check derived from the join is a postcondition, one built
   from `Canary_world.t` is a world assertion, one selected from the
   registry is an agreement. If authority is a free-standing field it can
   be set wrong, and a wrong value here is invisible — the failure class
   this whole document is about. Derived from which constructor made the
   check, it cannot be set wrong at all.

   The distinguishing question is **whose obligation was it**, and there
   are THREE registers, not two. ⚠ A register says what a failure
   **means**; §5's three-occasions subsection adds what it **does**, and
   for the world register those differ — caught before the command it
   aborts, caught at the warm gate it invalidates a marker. That is why
   §9 step 2 was withdrawn and not because this table is wrong. Two of
   the three registers were already separate in the theory, because
   [`agreement/theory.md`](agreement/theory.md) §7.1 already lists
   `pin_check_post` among the world assertions (2026-09-15), beside
   `Log_names`, `Opam_pin` and z3's `SYSTEM LIB MISSING`. The
   classification existed in the theory before the code had anywhere to
   put it, so step 6 inherits it rather than proposing it:

   | the check asserts | fails the step | because |
   | --- | --- | --- |
   | an artifact the action was asked to produce is at its location | **yes** | the action's own contract. This is what `check_post` is |
   | the world is the one this scenario declared — the pin holds, the ref resolves | **yes, and loudest** | not a finding about software: it says this run tested something other than what it claims, so every verdict in it is suspect ([`agreement/theory.md`](agreement/theory.md) §7.1). `Canary_world`'s `Opam_pin` / `Log_names` |
   | an agreement over the artifacts | **no** — yes under `--strict` | the action was never asked to make the claim true. sqlite's `dse ✗` at `build_lib` is a real violation of a declaration the compiler was not asked to satisfy; the build did its job |

   Two constraints that fall out, and both are easy to lose:

   - **`--strict` stays a RUN-WIDE policy.** It is the one switch that
     makes the two views agree, it rides the step fingerprint so a
     permissive verdict is never served to a strict run, and it is
     pinned (`strict.acceptance_policy`). Step 7 must not turn it into
     per-check configuration; a pile of switches does not mean "make the
     two views agree".
   - **A check's verdict stays boolean** — see distinction 2. A named
     check that evaluated an agreement would still not fail its step, so
     it has no need of `outcome`, and giving it one would invite exactly
     the collapse `unavailable_cause` undid.
2. **A check's verdict is a boolean; an agreement's is an `outcome` with
   eight constructors and ten labels.** `unavailable` / `undeclared` /
   `vacuous` are all reasons a claim reached no verdict, and collapsing
   them into `false` is the exact collapse `unavailable_cause` was
   introduced to undo. A derived `check_post` should stay boolean and stay
   separate; it is not an evaluator.

### What the agreement layer READS from this model

*(2026-09-21, before dispatching an agent at §9. The seam above says who
OWNS what; this says what breaks if the model moves, because §9 steps 5,
7 and 8 all touch code the agreement work depends on.)*

Five couplings, each with the pin that catches it. Run
`make canary-test` after every step; it is five seconds and every one of
these is in it.

| what the agreement layer reads | where | if §9 moves it |
| --- | --- | --- |
| **`ag_rooted_in.rt_action` is a STRING**, parsed by `action_of_string` | 10 registry rows | a renamed or split action stops parsing → the `R` mark silently vanishes. `agreements.rooting_names_an_action` and `agreements.overview_matches_rooting` |
| **`ag_slot` maps a claim to (action, stage)** — its column in `canary result` | every row | a moved action moves or deletes a check column. `matrix.key_explains_every_check_column`, `checks.index_speaks_each_action_language` |
| **`m_firing` names actions** — `firing_default`, `firing_lib_declaration`, `firing_probe_only` | `canary_agreement_common.ml` | a split changes WHERE claims fire, which is a semantic change, not a rename. `agreements.firing_defaults` |
| **The overview's columns ARE `store_actions`** | `overview_columns ()` | the table's width, row order and `lag` all move with the catalogue. `agreements.rows_obey_their_own_laws`, `agreements.overview_groups_a_claims_patterns`, `matrix.page_titles_and_agreement_overview` |
| **`retarget_action` enumerates the lang-carrying constructors** | `canary_agreement.ml` | a NEW constructor carrying a language must be added there, or a row's `R` lands in another language's column again. `agreements.rooting_speaks_the_rows_language` |

**Step 5 is the dangerous one, and it has an acceptance gate.** Retiring
`binding_evidence_tag` / `lib_evidence_tags` changes where every method
LOOKS for its evidence. Get it wrong and each landed agreement quietly
reports `unavailable` — which is not a test failure, it is a check that
stopped checking. The guard already exists:

```sh
make canary-agreement-roundtrip      # inside make canary-post-check
```

It clears the deciding steps' markers, runs sqlite cold, and requires
seven NAMED agreements to reach `holds` or `violated` from that run
(`CANARY_LANDED_AGREEMENTS` in the Makefile). **That gate staying green
is the acceptance criterion for step 5**, and it is the only one that
distinguishes "the paths still resolve" from "the tests still pass".
`agreements.derived_evidence_matches_projects` is its static half.

**Step 8 inherits the same risk.** `lib_evidence_tags` names
`probe_lib`, `probe_lib_staged` and `probe_lib_apt`; splitting
`probe_lib` into three roles renames the tag that role 2 (inspection)
writes under. Do 5 first and the tags are derived, so 8 becomes a
rename the derivation follows. Do 8 first and it is four hand-edits and
a silent `unavailable`.

**An opportunity while in here, not a requirement.**
`Probe_binding of lang` carries a language and no MECHANISM, so
tiny-full's two Python bindings (`Cext` and `Ctypes`) realize one step,
one log tag and one matrix column, and pass 2 sees only the first.
`analysis.one_mechanism_per_language` ratchets it as a named exception.
If §9 is opening the action vocabulary anyway, that is the cheapest
moment to add the mechanism — and the most expensive moment to do it is
any other. [`../project/issues.md`](../project/issues.md) §2.

**What is NOT coupled, so it does not need guarding.** The kind
taxonomy, the row laws' content, the external-tool rows and the
saturation grid are all about claims and mechanisms rather than actions;
only `a_row_does_something` reads the action cells, and it reads them as
a guard — a claim left firing nowhere by a split is exactly what it
should report.

## 7. One design under two names: the umbrella and `[Pre; Action; Post]`

These were proposed independently and they are the same design.

`status.md` §5's *"checks as actions — `[Pre; Action; Post]`"* (user,
2026-08-18, *"compiler perspective"*) says a moment's judgements should be
graph citizens the runner interprets. The roster measurements below
arrived at the same place from the other end: `probe_lib` should become an
**umbrella**, where the moment keeps its name, its directory and its column,
while the concrete checks under it take their names from the agreement
registry, so a reader sees *which* check failed rather than "the probe
failed".

Same shape: the moment is the node; the named checks are what it carries.
Stating them as one avoids building two mechanisms for it.

### `probe_lib` is three roles wearing one name

Measured 2026-09-15 by reading the commands, not inferred:

| role | what it does | where it lives today |
| --- | --- | --- |
| **existence** | the artifact the world declares is there | `probe_lib`'s `test COUNT -gt 0` |
| **inspection** | record a projection as evidence | `probe_lib`'s appended summary; ALSO `build_lib`'s |
| **execution** | load it, run it, observe | **nowhere** |

`probe_lib` is static: `nm -D | grep -c <prefix>` then `test COUNT -gt 0`.
Nothing loads and nothing executes. `probe_binding` *is* runtime — it
links a consumer, runs it, greps the output for a world witness — and it
fuses all three roles in one `&&` chain.

Two consequences worth stating plainly:

- **Role 1 is a degenerate ancestor of a landed agreement.** "count > 0"
  is the weakest possible "exports what was declared", and
  `declared_symbols_exported` reads the NAMES. So role 2 is what the step
  is really for.
- **Nothing ever `dlopen`s a library.** A lib can pass every static check
  and fail to load — a missing transitive `NEEDED`, an unresolvable
  `RUNPATH`, a version-script mismatch the symbol table does not show. A
  role-3 `probe_lib` is NEW COVERAGE, not a reclassification, and it is
  the identity half [`agreement/theory.md`](agreement/theory.md) §5.9
  calls missing.

## 8. One locator vocabulary, under all of it

Measured across the roster: all 13 `probe_lib*` steps run `nm -D` over the
resolved file; all 11 `probe_binding_ocaml` + `probe_app_ocaml` steps
compile and run an example; sqlite's `probe_binding_python` runs the
interpreter. **llvm's `probe_lib` is the one outlier** — it runs
`llvm-config --version`, which is *discovery*, not inspection. And
`build_lib` and `probe_lib` inspect the SAME file and write IDENTICAL
content (sqlite: 270 symbols, same hash); five such pairs exist.

**So the only genuinely per-project part of a lib inspection is the
LOCATOR.** Everything after `LIB_NATIVE=…` is already shared. That is the
good news for the hook model, and it is where the next mess is: **three
locator vocabularies exist, for one question.**

| vocabulary | who uses it |
| --- | --- |
| typed `probe_lib_location` | sqlite, z3, llvm |
| `lib_locator` globs | the opam-binding template (cairo, libffi, zarith, zlib, zstd) |
| raw shell | llvm's `probe_lib` |

A hook that derives "inspect whatever this moment produced" must resolve a
location. A derived `check_post` must resolve the same location to ask
whether the artifact appeared. **One locator vocabulary is therefore a
prerequisite for both**, not a follow-up — which is why it sits where it
does in §9 and why two separate refactors turn out to be one.

## 9. The ordered plan

Tracked as [`../backlog.md`](../backlog.md) §52. **Step 3 gates everything
below it**, and after 2026-09-21 it is the head of the queue: step 1 is
landed and step 2 is withdrawn into step 6. Both slots are kept rather
than renumbered, so a reference to "step 5" elsewhere still means step 5.

Worth noting what the two cheap steps actually bought, since neither
ended up being the deletion it was described as. Step 1 exchanged a
closure for data and got the first pin this predicate has ever had; step 2
dissolved on contact with the code and took a latent regression with it.
The pattern to expect from the rest: the plan is a set of hypotheses about
a codebase nobody has read closely at this depth, and the reading is where
the work is.

1. ~~**Delete `check_pre` as a field.**~~ **LANDED 2026-09-21**, and one
   detail came out differently: the field was not deleted, it was
   **exchanged for data** — `dep_dirs : string list`, the resolved
   directories, with the predicate spelled in the runner. It cannot
   simply be recomputed there from `deps`, because the resolution needs
   the whole step list (a dep's `output_dir` differs from its tag's
   directory when `output_tag` is set) and `derive_steps` is what has it;
   recomputing in the runner would put that map in two places, which is
   backlog §50's producer/consumer split. The closure carried an
   **address**, not a decision.
   Payoff, immediately: `Canary_run_info.load_run_state` no longer
   fabricates a stub for it (two closures left, both §9 steps 6–7), and
   `steps.dep_dirs_correspond_to_deps` pins it — the first pin this
   predicate has ever had, because a closure can be called but not read.
   ⚠ Measured while pinning it: **nothing currently depends on a step
   that has an `output_tag`**, so the resolution and the tag-derived
   fallback agree everywhere today. The pin guards the correspondence now
   and starts guarding the resolution as soon as step 4 gives the
   attached inspectors consumers.
2. ~~**Split `pin_check_post`.**~~ **WITHDRAWN 2026-09-21** — it had
   nothing of its own to do, and doing it as written would have restored
   a bug fixed on 2026-08-17. The step was "move the pin half to
   `Canary_world` and the last project-supplied closure is gone"; §5's
   three-occasions subsection is why neither half moves. The short
   version: the pin half is evaluated **before** a step is skipped, where
   its failure invalidates a marker rather than failing anything, and a
   `pre_shell` prelude cannot do that because a skipped step runs no
   command. The closure it was trying to remove is removed by **step 6**
   instead — `check_post` as data, with a constructor for the store
   predicate, evaluated in process and rendered to shell from one
   definition. Two things to carry into step 6 from here: the three
   occasions are three consumers of that constructor, and the
   still-valid half is currently written **twice** (`run_step` 445-456,
   `run_graph` 885-896), so step 6 collapses a duplication as well as a
   closure. [`artifact_cache.md`](artifact_cache.md) §4.5 is the same
   question one strength up ("the key is present and its recorded hash
   matches"), so read it when designing the constructor.
3. **One locator vocabulary.** Three exist. Self-contained, and the
   blocking item for everything below.
4. **Derive the inspection from the join.** At `<action>_post`, for each
   artifact in `produced_at`, run the inspection that artifact's kind
   defines, resolved at the location the world gives.
5. **Retire the world→tag maps.** `binding_evidence_tag` /
   `lib_evidence_tags` become `producers_of` plus the world's provision —
   derived, not written, and the same function the producer side uses.
   That closes the placement class (backlog §50: *"the producer chooses a
   step, the consumer derives one, and nothing makes them agree"*, four
   instances, each fixed individually) and settles the ownership question
   backlog §49 turns on: derived from the join, the map stops living in
   the agreement layer at all.
   ⚠ **This is the dangerous step, and its acceptance criterion is not
   `make canary-test`** — it is `make canary-agreement-roundtrip` staying
   green, because getting the paths wrong turns a landed claim into a
   silent `unavailable`, which no test failure reports. §6 has the
   argument and the other four couplings.
6. **Derive `check_post` from the join.** Same mechanism as 4 and the
   reason 3 is shared: *did the artifacts in `produced_at` appear at their
   locations?* The remaining hand-written compositors dissolve, and the
   rendering for any other interpreter — GH, a remote runner — is a
   command like `inspect`'s, not a second implementation.
7. **Name the checks under a moment** (§7), answering §6's question about
   whether a named check's failure fails its step.
8. **Split `probe_lib` into its three roles** and add role 3.

**Do them in that order.** 4 without 3 hand-writes a locator per project;
5 without 4 leaves two addressing schemes; 6 without 3 rebuilds the
locator a third time.

⚠ **And 8 after 5, which corrects an earlier reading of this list.** Step
8 looked independent — it is new coverage rather than a repair, so it
carried no urgency. It is not independent: `lib_evidence_tags` names
`probe_lib`, `probe_lib_staged` and `probe_lib_apt`, so splitting
`probe_lib` renames the tag role 2 writes evidence under. After 5 those
tags are derived and 8 is a rename the derivation follows; before 5 it is
four hand-edits and a silent `unavailable`. §6 measured this from the
code.

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

**Not merged, deliberately:**
[`artifact_cache.md`](artifact_cache.md) answers a different question —
*when may I skip work?*, not *did the work succeed?* — and folding it in
would give this document a title nobody could write. The two meet at one
idea: a postcondition proves an artifact exists at a path, while a keyed
store would let it prove that *the artifact with this identity* is
present, which is strictly stronger. Its §4.5 records that; §6 there is
the specimen where two independent caches both said "up to date" about a
binding linked against a soname no longer on the machine. Read it when
step 6 above is being designed, because it is the argument for what a
derived postcondition should assert.

**Also out of scope:** the expectation machinery.
`predicted_contains_any_v2` parses the `inspect.json` a run produced and
drives the comparators; that is real OCaml over real data and it is *not*
shell-shaped. Conflating it with `check_post` makes this work look larger
than it is — which is why the current GH backend resolves predictions at
generation time from the laptop's cache, and why an xfail there is checked
by signature when that cache exists (ssl) and by polarity alone when it
does not (llvm). The cheap half is §9; the expectation half is its own
problem.
