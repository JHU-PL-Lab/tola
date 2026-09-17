# Landing an agreement — what is left, and what it costs

**Kind: status.** The half of agreement coverage that no code can
answer: for each agreement that has not been decided by a real run, what
it is waiting on.

```sh
canary checks --landing            # WHICH are landed — the live table
canary checks <project>            # one project's coverage, per action
canary checks <project> --observed # what its LAST run decided
```

**The live table is not copied here.** It used to be, as a dated
"Effective" section, and by 2026-09-17 that copy listed three agreements
twice — once as LANDED with a verdict, once as "reported as
`not_applicable`/`unavailable`" — while the tool said eight were landed.
The file had already diagnosed this for the *planned* column
(*"repeating it here made this one go stale first"*) and then did it for
the effective one. Same defect in `registry.md` §1.7 and §7.4.1, which
is part of why that file is gone.

**A row is LANDED only when a real run decided it.** Not when its
comparator exists, not when its fixture passes, not when the catalogue
describes it. That was true of every agreement in the registry until
2026-09-12, and reading a log rather than the code is what showed it.

## What each row is waiting on

One row per registered agreement, which is what
`agreements.landing_doc_lists_every_agreement` requires: a new agreement
cannot be added without saying what would land it. **State** is as of
2026-09-17; re-read it from `canary checks --landing` rather than
trusting the word here.

| agreement | state | waiting on |
| --- | --- | --- |
| `declared_symbols_exported` | landed | — |
| `required_symbols_exported` | landed | — |
| `api_names_present` | landed | — |
| `soname_matches_declaration` | landed | — |
| `soname_matches_requirement` | landed | — |
| `required_versions_exported` | landed | — |
| `dependencies_provided` | landed | — (it reports a real `violated` on ssl: openssl ships two libraries and ssl declares one, so a dependency the world provides has no modeled provider. A finding about the SPEC) |
| `staged_interface_preserved` | landed | — |
| `signatures_agree` | **evaluated, never decided** | the source-scanning inspectors, which no project wires. Also: replace the fixed binding-signature table with a real extractor, so it compares what the binding DECLARES rather than what the inspector was told to assume |
| `declared_versions_exported` | **`vacuous`** | a project that BUILDS a library carrying a version script. sqlite builds without one, so there are no version nodes — the truth rather than a gap. openssl has one and canary fetches its lib, so `build_lib` never fires |
| `behavior_matches` | **no evaluator** | somebody to state a spec. One row standing for a CATEGORY: derived compatibility tests, the project's own suite, a provider↔consumer round trip |
| `repack_preserves_api` | **no evaluator** | what "preserves" permits ([`components.md`](components.md) §6.3.1) |
| `repack_complete` | **no evaluator** | the same, plus the two agreements it composes |

The last three are exactly the three with no `ag_rooted_in`. That is not
a coincidence: no tool enforced the relation, so there is nothing to
re-derive, and they wait on a specification rather than on wiring.
**Prefer landing tool-rooted ones.**

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

[`pipeline.md`](pipeline.md) positions the failure modes at the point in
a run where you meet them; backlog §50 is the general fix and
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

## The procedure

1. `canary checks <p>` — does it fire at any of this project's actions?
   If not, the world or the mechanism is the answer, not the wiring.
2. `canary emit <p> --stage realize` — is there an inspector step for the
   evidence it needs, at the step the derivation names?
3. Run it. Drop the verdict markers of the steps that READ the evidence
   first, or you will read a cached verdict and an empty report:
   `make canary-refresh PROJECT=<p>`.
4. `canary checks <p> --observed` — did it decide?
5. **Falsify it.** Break the declaration it is held against and confirm
   the same run flips to `violated`. A check that has only ever said
   `holds` has not been shown to be a check.
6. Update this file's *waiting on* column, and nothing else — the
   landed/not split is `canary checks --landing`'s to state.

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

- `agreements.landing_doc_lists_every_agreement` pins that the table names
  exactly the registered agreements with exactly the registry's planned
  status — so the doc cannot drift from the code half.

## Keeping this honest

- `agreements.landing_doc_lists_every_agreement` pins that every
  registered agreement has a row here, so a new one cannot be added
  without saying what would land it. It pins COMPLETENESS only: the
  planned status lives in the generated [`catalogue.md`](catalogue.md)
  and the effective one in `canary checks --landing`, and pinning a
  hand copy of either is the mistake this file was rebuilt to stop.
- `make canary-agreement-roundtrip` gates the landed rows against a real
  sqlite run, inside `make canary-post-check`.

## Where the neighbouring material went

- **`canary result`'s per-cell marks and blames** — [`../matrix.md`](../matrix.md).
  A verdict is a symbol, a gap is a word, and every non-verdict cell in a
  check column carries who to blame.
- **Could decide vs did decide, per project** — `canary checks <p>`
  prints it, with a five-class gap summary.
- **What each agreement IS** — [`catalogue.md`](catalogue.md), generated.
- **The open work that is not per-agreement** — `../../backlog.md` §51.
