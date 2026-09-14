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

## Effective — 2026-09-13

Regenerate with `canary checks --landing`; this is a dated copy so the
tracker is readable without a checkout.

| | agreement | effective |
| --- | --- | --- |
| **LANDED** | `api_names_present` | **decided in sqlite (OCaml and Python), ssl** |
| **LANDED** | `required_symbols_exported` | **`holds` ×6 on sqlite's OCaml probe (2026-09-13); falsified by injecting a bogus required symbol → `violated: sqlite3_canary_not_a_real_symbol` on exactly that scenario. `unavailable` ×6 on the Python probe: CPython's `_sqlite3` extension is never inspected for its undefined references** |
| | `signatures_agree` | reported as `not_applicable`/`unavailable` |
| | `soname_matches_requirement` | reported as `not_applicable`/`unavailable` |
| | `required_versions_exported` | reported as `not_applicable`/`unavailable` |
| | `dependencies_provided` | reported as `not_applicable`/`unavailable` |
| | `declared_symbols_exported` | absent from every log |
| | `soname_matches_declaration` | absent from every log |
| | `declared_versions_exported` | absent from every log |
| | `staged_interface_preserved` | new 2026-09-12 — a lift of `install_diff_note`; needs native inspections of both copies |
| | `behavior_matches` | reported as `not_implemented` |
| | `repack_preserves_api` | reported as `not_implemented` |
| | `repack_complete` | reported as `not_implemented` |

One landed. Note the four rows that now read `not_applicable`/`unavailable`
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

**`absent from every log` — the step was never observed.** The three
declaration agreements fire only at `build_lib`, and no run has emitted an
outcome there: either the step was warm-skipped, or no project with a Built
lib has run since the context path landed. They additionally need the
declaration routed into the step's evidence (`Declared_exports`,
`Declared_soname`, `Declared_version_tags`) — see `registry.md` §7.4.2
item 3.

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

3. The identity and dependency rows, now reachable through sqlite's Python
   extension — they need a native summary of the `.so`. **The lib half of
   this is now free** (every `Native_lib_probe` emits one); what is left is
   the consumer's recorded NEEDED/versioned references.
4. `signatures_agree` on a project that scans sources.

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
