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

### `pin_check_post` is split, not moved

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

Both halves then have a route out, and neither needs new vocabulary: the
marker half is derived, and the pin half joins a type that already renders
to shell — and whose own note records that `Opam_pin` is redundant given
correct dispatch and is a legitimate future deletion.

**After the split, no project-supplied check closure remains.**

## 6. The seam with the agreement layer

*agreement/ owns the CLAIM; this document owns the OCCASION.* Both READMEs
state it the same way, and the reason to restate it here is that the work
in §9 touches code on the far side of the line.

| question | owner |
| --- | --- |
| what is claimed, against what evidence, to what `outcome` | [`agreement/README.md`](agreement/README.md) |
| whether a claim applies at all | pass 2 ([`stage2_analyse_spec.md`](enumeration/stage2_analyse_spec.md)) |
| **when it fires, where its evidence is, who evaluates it** | here, and [`stage6_realize_steps.md`](enumeration/stage6_realize_steps.md) §2b |

**The line is crossed in code today, in one place.**
`binding_evidence_tag` and `lib_evidence_tags` live in
`agreement/canary_agreement_common.ml` and map a world to the step tag
where evidence should be. That is an occasion fact inside the claim layer.
It is waiting to be **derived** from `producers_of` (§9 step 5) — *not
moved*, because moving it would relocate the duplication rather than
remove it.

**Two distinctions to hold while doing this work**, because both are easy
to lose and each has already cost a bug:

1. **A check is not an agreement, and they fail differently.** A failed
   `check_post` fails its step. A violated agreement does **not** — the
   acceptance policy is "the command succeeded and its postcondition
   holds", and a disagreement about artifacts the action was never asked
   to fail on stays a finding (`--strict` flips this, deliberately, for
   one landing at a time). So when §9 step 7 gives the checks under a
   moment their names from the registry, **it must answer explicitly
   whether a named check's failure fails the step.** Today the two
   vocabularies answer oppositely, and inheriting that by accident would
   either turn ssl red for a real-but-tolerated finding, or silently
   demote `check_post` to advisory.
2. **A check's verdict is a boolean; an agreement's is an `outcome` with
   eight constructors and ten labels.** `unavailable` / `undeclared` /
   `vacuous` are all reasons a claim reached no verdict, and collapsing
   them into `false` is the exact collapse `unavailable_cause` was
   introduced to undo. A derived `check_post` should stay boolean and stay
   separate; it is not an evaluator.

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

Tracked as [`../backlog.md`](../backlog.md) §52. Steps 1 and 2 are
deletions and depend on nothing; step 3 gates everything below it.

1. **Delete `check_pre` as a field.** It is a pure function of `deps`, and
   `run_graph` has the step list. Zero design cost, one closure gone.
2. **Split `pin_check_post`** along §5's line: marker half stays a
   postcondition, pin half becomes a `Canary_world` assertion. The last
   project-supplied closure goes; no new vocabulary appears.
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
locator a third time. 8 is independent, and is new coverage rather than a
repair, so it is not urgent.

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
