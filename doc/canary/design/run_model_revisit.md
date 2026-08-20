# What the reruns taught the model (2026-08-20)

> Opened by the user after filling z3's `pre-10549` cells: *"we need a
> revisit on the current running and enumeration model after these
> rerun."* Everything here is grounded in something that happened on
> 2026-08-20, not in a design preference. Companion reading:
> [`artifact_cache.md`](artifact_cache.md) (the store proposal these
> findings keep arriving at), [`matrix.md`](matrix.md) (what a row is),
> [`../project/landing.md` §4](../project/landing.md) (the checks that
> do not check).

## 0. What happened, briefly

Rows #17–29 of the result matrix had never been run. Filling five of them
(z3's `pre-10549` ref) took three attempts and surfaced two bugs that had
been latent for days:

- z3's `env_guard` had pointed at a nonexistent path since 2026-08-19,
  when per-ref build dirs made `build` absolute and a `$(pwd)/` prefix
  started corrupting it. The guard still *set* the variable, so nothing
  failed; the dll shadowing it exists to prevent simply returned.
- `build-pre-10549/src/api/ml/dllz3ml.so` was linked against
  `libz3.so.5.0` while the tree's own lib exports `SONAME libz3.so.5.1`,
  and no `libz3.so.5.0` exists on this machine. Ninja called the binding
  up to date; canary's step marker agreed.

Both lived entirely inside the unrun region. That is the first finding.

## 1. A `·` cell is not a neutral state

The matrix renders "not run" as `·`, visually adjacent to `✓`, and both
read as "nothing to worry about here". They are not the same claim at
all: `✓` says *this was checked*, `·` says *nothing is known*. Two real
bugs sat under `·` for three days, and one of them (the env_guard) was
introduced by a change whose own pin passed.

**Enumeration coverage is not verification coverage.** The enumeration's
job is to say which worlds EXIST; the matrix currently presents that as if
it were the set of worlds CHECKED. `matrix.registry_shape` pins 42 rows —
a number about enumeration — and nothing pins how many of them have ever
run, so the fraction can fall silently.

What follows from it:

- The matrix should distinguish "never run" from "ran and passed" more
  loudly than one glyph does — a per-project *coverage* figure (rows run
  / rows enumerated), and a run age, so a stale row reads as stale.
- A row that has never run is a claim we are *not* making. Saying so is
  the honest version, and it is what would have made rows #17–29 look
  like the debt they were.

**Where it stands after 2026-08-20**: 41 of 42 rows have run. The one
holdout is #28 (llvm `latest`), whose source declares no local tree, so
running it means cloning llvm-project and building libLLVM from scratch —
hours, deliberately deferred rather than forgotten. That sentence is the
metric this section asks for; the point is that it should be printed by
the tool rather than reconstructed by hand.

## 2. Cost is a property of a scenario, and the model has no word for it

Deciding what to run meant `ls`-ing `contrib/z3-all/`:
`build-pre-10549/libz3.so` existed (warm, minutes), `build-arbipher/` did
not (cold, a full z3 build). Nothing in the spec, the enumeration, the
matrix or `status` carries that distinction, so the only way to know what
a run costs is to look at the filesystem and know what you are looking at.

The same call had to be made twice more the same afternoon, both times by
hand: llvm's `arbipher` was warm (`llvm-all/build/lib/libLLVM.so.23.0git`,
509 MB, built weeks earlier) so it ran in minutes, while llvm's `latest`
declares `locals = []` and would have cloned and built LLVM from scratch.
Running `action llvm` would have started that; `action llvm --refs
19,arbipher` was the right command, and nothing in the tool suggests it.
A cost mark would have.

This matters more as the registry grows: `action @all` is now ten
projects, and its cost is dominated by whichever build trees happen to be
cold. A scenario's cost is not incidental — it decides what a person can
run before lunch.

The shape of the fix is small and it is data, not code: each Built/
Installed placement already names a build tree, so a `warm | cold` mark is
derivable by asking whether the tree's product exists. Surfacing it in
`spec` and `status` would make "what will this cost me" a question the
tool answers.

## 3. Two independent caches agreed about an artifact that was wrong

The stale `dllz3ml.so` is worth stating precisely, because both caching
layers behaved *correctly by their own rules* and the result was still a
lie:

| layer | what it checks | verdict | correct? |
| --- | --- | --- | --- |
| ninja | did any recorded input of this target change? | up to date | yes, by its rules |
| canary's step marker | same realized command + expectation, and `check_post` passes? | warm skip | yes, by its rules |
| reality | does the binding load the lib beside it? | **no** | — |

Neither layer models the thing that changed: **the identity of the input
artifact**. libz3 bumped soname 5.0 → 5.1; nothing in either cache's key
mentions the soname, the version, or the content of the library the
binding links against.

This is exactly what [`artifact_cache.md`](artifact_cache.md) §5 proposes
as step 2 — *a step's fingerprint includes the identity of its INPUT
artifacts, not only its own command text* — and it is now not a
hypothetical. The prior evidence for that proposal was sqlite's staging
copy-out; this is a second, independent instance in a different project
and a different build system.

It also sharpens the proposal in one way. The earlier framing was about
canary's own cache. Here the *external* build system had the same blind
spot, which means canary cannot delegate the question to it: "ninja said
it was up to date" is not evidence about the artifact. A canary step that
shells out to a build tool has to check the product itself.

## 4. A step's failure output is not on disk

`build_binding_ocaml` runs a bare `ninja …` with no redirection, so when
it failed the error existed only in the run's stdout. Diagnosing it meant
re-running ninja by hand outside canary. `actions.log` recorded exactly:

```
build_binding_ocaml   cmd_fail    (exit 1)
build_binding_ocaml   detect      (error, output present)
build_binding_ocaml   check_post  (FAIL)
```

"output present" — and the output is gone. This is plan item **A3**
(`status -v` should tail a failed step's own log), and it now has a
measured cost: the two bugs above took three run/diagnose cycles, and the
first two produced no on-disk evidence at all. Probe steps already
redirect to a per-variant `probe.log`; build steps should do the same,
and the detection event should name the file.

## 5. A ref is a perturbation, and the matrix re-states the baseline

All three z3 refs have now run (2026-08-20, `action z3` full — 16/16
rows). Taking `latest` as the baseline and comparing the other two
cell-by-cell, they differ in **four cells out of ~105 populated**:

| ref | cell | latest | this ref | why |
| --- | --- | --- | --- | --- |
| arbipher | #19 `probe_binding_ocaml` | ✓ | **✗** | the fork cannot serve a staged consumer — a known, deliberately-red finding (`../project/issues.md` §1) |
| pre-10549 | #24 `install_lib` | ✓ | **xfail** | predates PR #10549, which added the installed OCaml package |
| pre-10549 | #24 `probe_binding_ocaml` | ✓ | **xfail** | consequence of the above — nothing staged to probe |
| pre-10549 | #25 `install_lib` | ✓ | **xfail** | same as #24 |

Everything else repeats the baseline exactly — including all three
forward cells' `✗` (#16, #21, #26), which are one finding, not three:
apt's libz3 4.8.12 exports 705 `Z3_` symbols and a HEAD-built binding
needs 791. That failure is a property of apt, and every ref restates it.

That is the *right* result: it is what makes the three differing cells
meaningful, and re-running the identical ones is how we know they are
identical. But it says something about presentation and about scale:

- **The signal is the diff.** A reader scanning 16 z3 rows has to
  cell-compare to find the three that matter. A ref is a PERTURBATION of
  a baseline world; the interesting output is where the perturbation
  shows. The matrix has no notion of "same as baseline".
- **The unread-source collapse already embodies half of this.** z3 folds
  three all-Fetched worlds into one because the source ref is never read —
  a rule about *inputs*. The observation here is about *outputs*: a ref
  that is read but changes nothing still costs a full set of rows. The two
  are different rules; only the first exists.
- **It bounds how far refs scale.** Every additive ref multiplies rows by
  the cell count, and measured over the complete set, **96% of the
  non-baseline cells restate the baseline** (4 differ of ~105). Three refs
  is fine — the repetition is what makes those four legible. The tenth
  would not be, and the cost is not only reading: `arbipher` needed a cold
  z3 build to produce five rows of which one was new.
- **The forward cell is the sharpest case.** It is `✗` under all three
  refs for a reason that involves no ref at all. Three rows carry one
  finding, and a reader has no way to see that from the matrix — which is
  the presentation half of §1's problem: the grid says how many worlds
  failed, never how many distinct things are wrong.

## 6. What to change, in order

Ordered so each step pays for itself and nothing depends on an unbuilt
piece:

1. **Build steps redirect to a log, and the detect event names it** (§4).
   Smallest, and it is the one that makes every later investigation
   cheaper. Plan item A3.
2. **The matrix reports run coverage and age per project** (§1) — rows
   run / rows enumerated, oldest run timestamp. Turns `·` from decoration
   into an accounted debt. Pin the ratio so it cannot fall silently.
3. **A post-`build_binding` soname assertion** (§3, the cheap instance):
   every `NEEDED` entry naming the project's lib must match the soname the
   tree's lib exports. Catches this class at the step that produced it,
   without waiting for the store.
4. **Warm/cold on Built and Installed placements** (§2) — derived from
   whether the tree's product exists; shown by `spec` and `status`.
5. **Input-artifact identity in the step fingerprint**
   ([`artifact_cache.md`](artifact_cache.md) §5 step 2). The real fix for
   §3, and the prerequisite for the artifact store.
6. **A baseline-relative view of ref rows** (§5). Presentation first —
   mark cells identical to the baseline ref — and only consider an
   enumeration-level rule if the row count actually becomes a problem.

Items 1–4 are each a day or less and independent. Item 5 is the arc.
Item 6 should wait until a fourth ref exists to prove the need.
