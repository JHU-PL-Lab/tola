# Agreement landing tracker

**Kind: status, generated.** What is planned, what is actually in use, and
what the next step is for each. The model is in [`registry.md`](registry.md);
how a project reaches an agreement is [`pipeline.md`](pipeline.md).

```sh
canary checks --landing              # the live table
canary checks <project> --observed   # one project's last run
canary checks --agreement NAME       # one agreement's complete record
```

What each agreement IS — its claim, whose rule it recovers, what it is held
against, where it looks, what falsifies it — is
[`catalogue.md`](catalogue.md), generated from the registry. That file also
carries the **planned** half: its summary table's status column *is* the
registry's. This file is only the half no code can answer.

## Two columns, two sources — and only one of them lives here

| | answered from | true when | where |
| --- | --- | --- | --- |
| **planned** | the registry | the code has a method with an evaluator | [`catalogue.md`](catalogue.md) |
| **effective** | run logs | a real project's run reached `holds` or `violated` | here |

Neither is derived from the other, and the gap between them is the thing
this file exists to track. An agreement can be fully planned, ship a
counterexample, pass every test — and have never once looked at a real
artifact. That was true of every agreement in the registry until
2026-09-12, and reading a log rather than the code is what showed it.

**A row is LANDED only when a real run decided it.** Not when its
comparator exists, not when its fixture passes, not when the catalogue
describes it.

The planned column used to be repeated here beside the effective one, which
put the registry's status in two files and made this one go stale first
(2026-09-13). It is one column now, and the catalogue holds the other.

## Effective — 2026-09-15

Regenerate with `canary checks --landing`; this is a dated copy so the
tracker is readable without a checkout.

| | agreement | effective |
| --- | --- | --- |
| **LANDED** | `declared_symbols_exported` | **`holds` ×8 / `violated` ×8 on sqlite (2026-09-14) — and the falsification is the project's OWN 2×2, not a synthetic break: the dev channel builds 3.46.1 and exports the declared modern API; the stable channel builds 3.43.2 and is missing `sqlite3_get_clientdata`, `sqlite3_set_clientdata`. That forward cell was created deliberately on 2026-08-19 and had gone undetected since** |
| **LANDED** | `staged_interface_preserved` | **`holds` ×4 on sqlite. The first distance-0 agreement to decide: it needed a summary of the BUILD-TREE copy, which arrived when `build_lib` began inspecting its own output. An empty diff is the finding — sqlite's copy-out staging is interface-preserving** |
| **LANDED** | `soname_matches_requirement` | **`holds` ×6 on sqlite, ×2 on ssl (2026-09-15); falsified by bumping the provider's recorded soname to `libsqlite3.so.9` → `violated: libsqlite3.so.0` on that scenario alone** |
| **LANDED** | `dependencies_provided` | **`holds` ×6 on sqlite. On ssl it reports `violated: libcrypto.so.3` — a finding about the SPEC, not the artifacts: openssl ships two libraries and ssl declares one, so a dependency the world really provides has no modeled provider. See below** |
| **LANDED** | `required_versions_exported` | **`holds` ×2 on ssl — the only project whose consumer carries versioned references (`OPENSSL_3.0.0`), matched against libssl's version definitions. `unavailable` on sqlite, whose libsqlite3 has no version nodes at all** |
| **LANDED** | `api_names_present` | **decided in sqlite (OCaml and Python), ssl, and — since 2026-09-15 — cairo, libffi, zlib, zarith. Those four had reported `unavailable` for three days while writing perfectly good evidence: the Pattern A template hung its `ocamlfind`+`ocamlobjinfo` inspection on `Probe_binding` while the derivation asks for a binding's surface at the step that PROVISIONS it. One relocation, four projects, eight cells** |
| **LANDED** | `required_symbols_exported` | **decided in cairo, libffi, sqlite, ssl, z3, zarith. `holds` ×6 on sqlite's OCaml probe (2026-09-13); falsified by injecting a bogus required symbol → `violated: sqlite3_canary_not_a_real_symbol` on exactly that scenario. On **z3** (2026-09-15) `holds` ×8 / `violated` ×2 cold, and the violation is the FORWARD CELL reproduced from evidence: the arbipher-HEAD-built binding requires 776 `Z3_` symbols, apt's libz3 4.8.12 exports 705, **85 missing**. z3 used to answer that question with `assert_binary_symbols.py` gating its own link; the script is deleted. `unavailable` ×6 on sqlite's Python probe: CPython's `_sqlite3` extension is never inspected for its undefined references** |
| | `signatures_agree` | reported as `not_applicable`/`unavailable` |
| | `soname_matches_requirement` | reported as `not_applicable`/`unavailable` |
| | `required_versions_exported` | reported as `not_applicable`/`unavailable` |
| | `dependencies_provided` | reported as `not_applicable`/`unavailable` |
| **LANDED** | `soname_matches_declaration` | **`holds` ×16 on sqlite (2026-09-14); falsified by declaring `libsqlite3.so.99` → `violated: soname libsqlite3.so.0 != declared libsqlite3.so.99`. Landing it required fixing canary's own build: `cc_shared_lib_cmd` passed no `-Wl,-soname`, so every library canary built recorded no identity while apt's records `libsqlite3.so.0`** |
| | `declared_versions_exported` | `unavailable` — **the project declares no version tags, and that is the truth.** sqlite builds without a version script, so there are no version nodes to check. The projects that do use one (openssl) fetch their lib, so `build_lib` never fires for them |
| | `behavior_matches` | reported as `not_implemented` |
| | `repack_preserves_api` | reported as `not_implemented` |
| | `repack_complete` | reported as `not_implemented` |

**Eight landed of thirteen.** The three that arrived on 2026-09-15 came from
one correction: **the consumer is not the binding, it is the executable the
probe links.** A cstubs binding is a `.a`, which records no `DT_NEEDED` and no
symbol versions — true of the archive, and the wrong artifact to have been
asking about. `ssl_app_core` records `NEEDED libssl.so.3` and an
`OPENSSL_3.0.0` version requirement, and had done all along, unread. The probe
now summarises its own executable into `inspect_abi.json` (inside the probe
command, not a child step, so it exists before the same step's agreements are
evaluated), `mi_consumer_records_needed` became true for cstubs, and the three
consumer-side claims gained a column on the OCaml side.

**One thing that had to be fixed to land `required_versions_exported`
honestly.** A consumer records one versioned reference per (symbol, tag), and
most belong to somebody else: ssl's probe requires `OPENSSL_3.0.0` and
twenty-two `GLIBC_*` tags. Compared against one provider, every glibc tag reads
as missing — so the check would have reported `violated` on every project whose
consumer links libc, which is all of them. The rule is now **derived from the
provider**: a required tag is this provider's concern exactly when the provider
exports a tag in the same namespace. libssl participates in `OPENSSL` and not in
`GLIBC`, so the glibc tags are somebody else's; glibc *itself* participates in
`GLIBC`, so a consumer needing a newer glibc than the provider offers is still a
finding — which a hardcoded "GLIBC is ambient" list would have thrown away, and
which is one of this agreement's own counterexamples.

**A finding about ssl's spec, surfaced by `dependencies_provided`.** It reports
`violated: libcrypto.so.3` on ssl. libcrypto is genuinely present — it ships in
the same apt package as libssl — but ssl's artifact table declares **one** lib,
so canary's model of the world has no provider for it. That is the agreement's
documented limitation ("ONE modeled provider… a name supplied by a second
unmodeled library is reported unprovided") meeting a real project, and the
honest reading is that the spec is incomplete rather than the artifacts wrong.
Fixing it needs the multi-lib work (`A_lib of string option`, `issues.md`).

**Five landed of thirteen** (before 2026-09-15). Three arrived on 2026-09-14 from one change —
routing the project's own declared C API onto the agreement context — plus two
consequences of it. Once `build_lib` summarised its own output, the staging
comparison had a build-tree copy to hold the staged one against. And once the
declarations were reachable, `soname_matches_declaration` could be landed by
fixing the thing it was complaining about: canary's own `cc_shared_lib_cmd`
passed no `-Wl,-soname`, so every library canary built recorded no identity at
all while the system's records one. That was a FIDELITY bug, not a cosmetic
one — a consumer linked against a no-soname library records a path or a bare
filename in `DT_NEEDED`, so a Built world was not a model of a deployed one
precisely where the identity agreements read.

**A post-check reads the copy its own action produced.** Asking
`lib_evidence_paths` — "where is this world's library" — handed the three
`build_lib_post` agreements the STAGED copy in Installed worlds, and they
reported `inconclusive` against an artifact they were not asking about. That
is the rule the pre/post slots make explicit, and `built_lib_evidence_paths`
is its other half.

Note the four rows that now read `not_applicable`/`unavailable`
rather than `not_applicable` alone: sqlite grew a Python chain on 2026-09-12,
and a compiled extension is a shared object, so the mechanism that could not
carry those claims under OCaml's static archive *can* carry them under Python.
They moved from "no such artifact exists" to "the artifact exists and nobody
inspected it" — which is a smaller gap, and a different kind of work.

The last three are `not_implemented` for a reason no wiring changes: nothing
roots them. See the catalogue's second table.

## What each non-landed row is waiting on

The four effective states need four different kinds of work, and telling
them apart is most of the value of the table.

**`unavailable` — the evidence is not produced.** Wiring, no design
decision. These are the closest to landing.

- ~~`required_symbols_exported`~~ — landed 2026-09-13; see the Order section
  for the four things it turned out to need.
- `signatures_agree` needs the source-scanning inspectors, which sqlite does
  not wire at all.

**`not_applicable` — the mechanism has no such artifact.** Not a gap. A
cstubs binding archives a `.a`, which records no `DT_NEEDED` and no symbol
versions, so the identity and dependency agreements have nothing to read
under sqlite's OCaml binding.

Since sqlite grew a Python chain they are `unavailable` there instead: a
compiled extension is a `.so` and does record both, so the claim applies and
only the inspection is missing. What they need is a native summary of the
extension — the same wiring as the `unavailable` group above, on a different
artifact.

**~~`absent from every log`~~ — closed 2026-09-14.** The three declaration
agreements fire only at `build_lib`, and that column read `0/3` for three
stacked reasons, only the first of which was visible:

1. the step is nearly always warm-skipped, so nothing was logged. Forcing it
   cold showed the real blockers;
2. **the declaration reached no evaluator.** `m_inputs` saw the mechanism, the
   language and the world, and a declaration is none of those — so the
   reference half of every `Declared_facts` comparison was unreachable.
   `action_context` carries `ac_declared` now;
3. **the evidence was written by a later step.** The agreements fire at
   `build_lib` and the only native summary was the one `probe_lib` writes
   afterwards, so they decided only on a warm tree by reading the previous
   run's file. `build_lib` inspects its own output now.

Behind (3) sat a fourth: `Inspect_native_build` had existed unused since the
typed templates landed, because `merge_inspect` decided whether to take a
row's inspector by checking whether the row also set `inspect_note` — a proxy
that silently discarded any inspect row without a note. The closures compose
now, so no proxy is needed.

**`not_implemented` — there is no evaluator, and that is a catalogue
decision.** `behavior_matches` needs the project to state expected results
somewhere outside the probe's own source. The two repacking agreements need
their claim scoped before they can be named properly, let alone checked
(`registry.md` §6.3.1).

## Order

From `registry.md` §7.4.2, narrowed to what this table says is closest:

1. ~~`api_names_present` for **Python**~~ — done 2026-09-12, via a
   [dummy action](pipeline.md#the-dummy-action): CPython's `sqlite3` is
   stdlib, so there was no install step for the derivation to look at.
   sqlite now declares `Fetch (Binding Python)` as a dummy — a step that
   states plainly that the interpreter already provides the binding — and
   hangs the surface inspection on it. Falsified: a bogus attribute name in
   the Python watchlist flips those six scenarios to `violated` while the
   six OCaml ones keep holding.
2. ~~`required_symbols_exported` on sqlite~~ — done 2026-09-13. It needed
   four fixes, and only the first was the one predicted:

   - the **compiled-stub summary** was never generated, because an explicit
     `inspect` override used to suppress *all* auto-generated summaries
     rather than the one it replaced. It now replaces by output name, so a
     project that spells its own surface inspection keeps the stub one;
   - the **native summary** was never generated either, outside the two
     projects that hand-wrote the closure. `Native_lib_probe` now emits it
     beside the probe log — it already held the resolved library and the
     prefix, so a declared probe can no longer produce evidence nobody
     wrote;
   - `lib_evidence_tags` named only `probe_lib`, which is the **build-tree**
     probe's tag. The staged and PM probes suffix themselves, so an
     Installed or Fetched world looked for its library where only a Built
     world writes. Same world-blindness as the old constant `build_lib`,
     one level in;
   - the binding probe did not **depend on** the lib probe. Where the check
     decided, it decided by reading a file a *previous* run had left on
     disk; the Fetched world happened to order the two the other way and
     reported `unavailable`. A check that passes only on a warm tree is not
     a check, so the round-trip gate now clears the lib probes' output too.

   Falsified by injecting a bogus name into one scenario's stub summary:
   that scenario alone flipped to `violated`, naming the symbol, and the
   run recorded it as a disagreement the action did not itself surface.

   **It then landed on cairo, libffi, ssl and zarith with no per-project
   change at all** — which is the answer to "is this universal". It is,
   once the two facts a project already declares actually reach the
   runner: its `api_source` (on the source repo record) and the package
   its binding is (on the artifact table's binding row). Both were read
   only by `spec-check` and the CI renderer; `Canary_pipeline.with_declared_facts`
   routes them now. The remaining per-project work is zero for any project
   whose binding comes from a language PM.

   Two things that routing surfaced, both kept rather than papered over:

   - a **derived** package earns the stub inspection and *not* a surface
     one. Merging the two channels generated an mli scan beside each
     project's own inspection, and zarith's `Zarith_version` and libffi's
     `Ctypes_foreign_basis` ship without a `.mli` — so the generated
     summary reported missing what the project's own ocamlobjinfo summary
     lists, turning a holding agreement into a false `violated`.
     `binding_store_pkg` and `binding_user_facing_pkg` are separate fields
     for exactly this reason;
   - `check_api_consistency` used to `failwith` when a spec built a binding
     without a declared `source_dir`. Defensible while `api_source` was set
     only deliberately; fatal to zarith once every project's arrived. It is
     a warning now, and `spec-check`'s "binding dev source" item reports the
     gap — which is a real one, and newly visible rather than newly created.

3. ~~`api_names_present` on the Pattern A projects~~ — **done 2026-09-15**,
   and it was the one-line relocation this entry predicted: the template's
   inspect moved from `Probe_binding` to `Fetch (Binding _) | Build_binding _`,
   the two steps that PROVISION a binding, which is where
   `binding_evidence_tag` looks. cairo 1→4 decided, libffi 1→5, zlib 0→3,
   zarith 3→4.

   Nothing new is generated, which is what kept zarith safe: the trap of
   2026-09-13 was *adding* a derived mli scan beside this one, where
   `Zarith_version` ships no `.mli` and the scan reported missing what
   ocamlobjinfo lists. Moving the existing inspection does not create a
   second one.

   **Third instance of the class**, after tiny's filenames and the
   probe-vs-install step: the producer picks a step, the consumer derives
   one, and nothing makes them agree. The general fix — a typed evidence
   ADDRESS, produced and consumed from one place — is backlog §50.
4. The identity and dependency rows, now reachable through sqlite's Python
   extension — they need a native summary of the `.so`. **The lib half of
   this is now free** (every `Native_lib_probe` emits one); what is left is
   the consumer's recorded NEEDED/versioned references.
5. `signatures_agree` on a project that scans sources.

Each one ends the same way: run it, read the log, **falsify it**, and edit
the effective table above.

## The distance-0 backlog

[`theory.md`](theory.md) §5 lists, per action, the full-information agreement
the real tool established and what post-fact checking can recover. Walking
that list against the registry gives a second backlog, organised by **how far
apart the two sides of the comparison are** rather than by subject.

| distance | both sides are… | example |
| --- | --- | --- |
| **0** | available at the one action — an artifact and something we still hold | the build tree beside the staged tree; a library beside its declaration; a ref we can re-resolve |
| **1** | from adjacent actions; established by the toolchain only if same-origin | a stub's undefined references against a library's exports |
| **≥2** | from different worlds, or needing a runtime trace | denotation across worlds, interposition |

Distance 0 is where the least was lost, so it is where checking is cheapest
and strongest. Every registered agreement today is distance 1 or planned;
**six distance-0 checks from §5 have no registry row at all.**

| § | post-fact check | today | what it needs |
| --- | --- | --- | --- |
| 5.4 | the staged tree preserves the build tree's interface | **registered** 2026-09-12 as `staged_interface_preserved` | native inspections of both copies, in a project with Installed worlds |
| 5.1 | the source tree is the declared ref | runs, as a **shell assertion** in a `check_post` | the resolved commit RECORDED as evidence, then a row |
| 5.7 | the package contains the files the recipe named | runs, as **shell assertions** hand-listed per project | a package file manifest as evidence, then a row and a general form |
| 5.3 | exports the declaration does not account for | nothing | the declaration routed (item 3 above) — then it is the converse of `declared_symbols_exported`, and the two together make an equality rather than an inclusion |
| 5.2 | the build tree is configured for *this* source | nothing | an inspector over the configure cache |
| 5.3 | declared signatures match the library's debug info | prose proposal (registry §2.2) | a DWARF inspector, and `-g` |

**A correction, made while doing it.** This list first claimed the top three
all "already ran" and needed only a registry row. Only §5.4 did. Its
comparison was a real comparator over two inspection files
(`Canary_status.install_diff_note`) sitting in the status reporter instead of
the registry, so lifting it changed where the result is reported and nothing
about what it says.

§5.1 and §5.7 are different: they are **shell assertions inside commands** —
a `git rev-parse` in a postcondition, `test -f` lines in a packaging step.
They check something real, but there is no evidence file for an evaluator to
read, so registering them is not a lift. It requires recording the fact first
(§4: an identity gap closes by recording), which puts them in the inspector
tier rather than the free one. The distinction is worth keeping because
"already runs" and "already produces evidence" are not the same claim, and
only the second makes a registry row cheap.

### A precondition, and it is a bug

Before any of this: the lib-side evidence path is **world-blind**. A binding's
inspection is located by `binding_evidence_tag`, which reads the world's
provision and answers `fetch_binding_*` or `build_binding_*` accordingly. The
library's is the constant `build_lib_tag` in every agreement that reads it.

So in any world whose library is *not* Built, the native summary is looked for
where nothing writes it. Five projects — ssl, cairo, libffi, zstd, torch —
produce a native inspection at `probe_lib/inspect.json`, and nothing reads it.
This is the third instance of the path-mismatch class (after the tiny-only
filenames and the probe-vs-install step), and the fix is the obvious one: a
`lib_evidence_tag` mirroring the binding's.

It does not land an agreement on its own — the *other* side of each pair is
also missing on those projects — but every distance-0 and distance-1 item
below depends on it being right.

### Order

1. ~~`lib_evidence_tag`~~ — **done** 2026-09-12. It lands nothing on its own
   (verified against ssl, whose consumer side is missing too), but every
   lib-side path was Built-world-only before it.
2. ~~Lift the comparison that already runs~~ — **done**:
   `staged_interface_preserved`. §5.1 and §5.7 turned out not to qualify;
   see the correction above.
3. Route the declarations, which lands the three declaration agreements *and*
   makes the orphan-export converse writable.
4. The inspector work, cheapest first: a native summary where each project's
   world puts its library and a staged summary (these two land
   `staged_interface_preserved` and half of `required_symbols_exported`), a
   compiled-stub summary, then the recorded commit, the package manifest, the
   configure cache, and DWARF.
5. Distance ≥1 and cross-world — the three standing proposals.

Step 3 is the only remaining one that changes the landing table without a new
inspector, which is why it is next.

## The result table says it per cell — mark, then blame

`canary result <project>`'s check columns carry the gap directly, which
is where you meet it first. A **symbol** means the check reached a
verdict; a **word** means it did not:

| cell | outcome | means |
| --- | --- | --- |
| `✓` | holds | |
| `✗` | violated / error | |
| `no-evid` | unavailable | nothing wrote the inspection it reads |
| `no-decl` | undeclared | the artifact is readable; the project declared nothing to hold it against |
| `none` | vacuous | both sides reachable, nothing of this kind in this world |
| `no-ref` | inconclusive | read, nothing to compare against |
| `stale` | not_applicable | the log predates the registry — re-run |
| `off` | disabled | |
| `·` | — | no run has recorded this cell |

Those five used to be one dot. A check column only exists where the
claim *can* be decided (`check_cols_of_chain` requires an evaluator and
static applicability), so a non-verdict cell in one is a **defect**, not
a blank — which is why each carries a **blame**, counted under the table
and per agreement in the HTML key:

```
gap: 58 evidence  10 vacuous  4 version
```

| blame | owner | what to do |
| --- | --- | --- |
| `evidence` | wiring | nothing wrote the inspection, or the reader runs before the writer |
| `declaration` | spec | the project declared nothing to hold the artifact against |
| `version` | spec | one declared value, several version points — see [issues.md §1](../../project/issues.md) |
| `stale` | nobody | `make canary-refresh PROJECT=<p>` |
| `vacuous` | nobody | both sides read, neither has anything of this kind |

Every one is a **static scan** of the project spec plus the cell's
recorded outcome, so a blame can be attributed before the thing it
blames is fixed — which is the point: the count says how eager to be.

**And the outcome now says which, rather than the table guessing.**
`Unavailable` used to be one word for three situations — the artifact's
inspection absent, the project's declaration absent, or genuinely
nothing of this kind here — so a cell that needed nothing read exactly
like one waiting on an inspector. The evaluators always knew (they said
so in prose); the type discarded it. `unavailable_cause` is
`Missing_evidence | Missing_declaration | Nothing_to_check`, and the
three carry distinct outcome LABELS (`unavailable` / `undeclared` /
`vacuous`) so every reader — log, tracker, result marks — gets the
distinction at once. `Missing_evidence` keeps the old word, so nothing
that matched `unavailable` changed meaning and old logs still read as
what they were. No cache epoch: an `Unavailable` produces no prediction
whichever cause it carries, so no compat verdict moves.

It cost sqlite eight cells of false work queue on its first reading —
`declared_versions_exported` reports that the project declares no
symbol-version tags and adds, in the same sentence, that *"for most
libraries that is the truth rather than an omission"*. `undeclared`
fires on no live project cell today (every project that reaches those
evaluators does declare its soname and c_api); it is exercised by a
counterexample fixture, which is the honest way to keep a path that
should stay empty.

Two of them ask for nothing, deliberately. `vacuous` exists because a
PEER comparison that reaches `inconclusive` read both artifacts and
neither carried anything of this kind — sqlite's libsqlite3 has no
symbol versioning, so `required_versions_exported` has nothing to
compare and never will. Blaming that on the declaration put ten
permanent rows on the work queue. `version` is the only blame that
attaches to a **decided** cell: sqlite's four `dse ✗` are real
violations of a declaration that cannot say "these two symbols exist
from 3.44", so a reader counting findings has to be told which reds may
be the spec's fault. Pinned by `matrix.blame_is_static_and_glossed`.

## Could decide vs did decide — where the next landing comes from

This tracker is per AGREEMENT across projects. The other cut — one
project, every agreement — is `canary checks <project>`, which walks the
actions that project derives and prints, per cell, the agreement, its
method summary, and what the recorded runs decided there. The foot of it
is the gap:

```
COULD DECIDE vs DID DECIDE — 13 agreement(s) fire in this project; the registry declares 13
  decided         7  api_names_present, declared_symbols_exported, dependencies_provided, …
  could not       3  declared_versions_exported (unavailable), required_versions_exported (inconclusive/unavailable), signatures_agree (unavailable)
  no evaluator    3  behavior_matches, repack_complete, repack_preserves_api
```

Five classes, and they are five different jobs:

| class | what it means | what to do |
| --- | --- | --- |
| `decided` | a run reached `holds` or `violated` | nothing |
| `could not` | the evaluator ran and could not conclude — `unavailable` is missing evidence, `inconclusive` is evidence with nothing to compare against | wire the evidence, or fix the declaration |
| `never asked` | no log line at all at any of its cells | run the project cold |
| `stood down` | the log says `not_applicable` where the registry now says the claim applies | re-run: the log predates [static applicability](#) |
| `no evaluator` | every method firing there is planned | state a spec — these are the three unrooted agreements |

`stood down` is not a hypothesis. zarith showed three claims in it;
re-running zarith moved `dependencies_provided` and
`soname_matches_requirement` straight into `decided` and
`required_versions_exported` into `could not (inconclusive)`. Its
coverage had been understated for two days by three stale log lines.

Two things this cut is honest about that the per-agreement table is not:

- it reads EVERY recorded run, last-wins per (step, agreement, method),
  not just the last one — "has anything ever decided this here" is not a
  property of the newest run, it is a property of the newest run that
  LOOKED (same reasoning as `latest_observation`). The cost is that a
  cell keeps a stale word until something re-runs it, which is exactly
  what `stood down` is for;
- it asks each action in ITS OWN language. Asking the whole index with
  the project's first declared binding is how sqlite's index came to
  report that nothing fires at `probe_binding_python` while the result
  table had five Python columns there and the log had decided
  `api_names_present` six times. Pinned by
  `checks.index_speaks_each_action_language`.

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
- The effective half is a dated snapshot of run logs and can only be
  refreshed by running something. It is not pinned, on purpose: a pin that
  required run outputs would either be skipped in a fresh checkout or force
  a heavy run in the unit suite.
- `make canary-agreement-roundtrip` gates the one landed row, inside
  `make canary-post-check`.
