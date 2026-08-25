# The result matrix — what a row is, and what names it

> Moved out of `enumeration/` on 2026-08-24. It had been numbered as
> "pass 6" of the pipeline, and that was wrong: the matrix is built by
> `canary result`, which READS `actions.log` after a run. The pipeline's
> dataflow ends at pass 5 writing verdicts; reporting is a CONSUMER of
> the log, not a pass in it. The enumeration map is
> [`enumeration/README.md`](enumeration/README.md).

**Kind: rationale.** The layout shipped 2026-08-19; §2's analysis is kept because it is the argument that produced it.

> 2026-08-19. Opened by the user's observation on the sqlite rows: "ref
> is not the only world … how do you explain #6?" **Resolved the same
> day** (§4 option 1, user-chosen): the row now leads with a SETTING
> block — one column per artifact, carrying that artifact's placement —
> and the single `ref` column is gone. §2's analysis is kept because it
> is the reason the layout changed.
> Renderer: [`canary_matrix.ml`](../../../src/canary/main/canary_matrix.ml);
> `canary result` writes `docs/canary/projects/matrix.html`.

## 1. What a row IS

A row is one **world** = one assignment = a `(provision × version)`
placement per declared artifact. Nothing less identifies it: two rows may
share every string the matrix currently prints in its `ref` column and
still be different worlds.

`canary spec` already prints the full thing:

```
binding:ocaml:cstubs=B:dev  source=F:pre-10549  lib=B:dev  binding:python:ctypes=F:stable
binding:ocaml:cstubs=B:dev  source=F:pre-10549  lib=I:dev  binding:python:ctypes=F:stable
```

The matrix compresses that into one `ref` cell plus per-column provision
annotations. The compression is where the identity gets lost.

## 2. What `ref` means — and that it differs per project

A ref marks a **source**: a repo at a commit that can provide a lib
and/or a binding. Which artifact it provides is a per-project fact the
column does not say:

| project | what the `ref` column actually names | worlds per ref |
| --- | --- | --- |
| z3 | the source of the lib AND the on-tree OCaml/Python bindings | **2** (build-tree face, staged face) — plus the stable ref's 1 |
| llvm | the source of the lib + on-tree OCaml binding | 1 |
| zarith | the source of the **binding** only (`1.14` / `master`); the lib is apt libgmp | 1–2 |
| sqlite | *nothing* — `(ambient)`, and correctly so: the C source is an amalgamation ZIP keyed by version, and the apt world reads no source at all | 5 in one "ref" |

So the column is:

- **identity** when each ref appears in exactly one world (llvm);
- **under-identifying** when one ref spawns several worlds (z3 — see §3);
- **ambiguous across projects** in what it refers to (zarith's ref is a
  binding's source, z3's is a lib's) with nothing on screen saying which;
- **empty and honestly so** when no source ref participates (sqlite).

`(ambient)` is therefore *correct output*, not a rendering bug. The
problem is that one coordinate is promoted to the row's name.

**This gets structurally worse, not better.** The repo model's
multi-repo principle (`stage1_declare_spec.md` §4) says a repo records *what
artifacts* it can contain, and different artifacts may come from
different repos; `Binding_source` already exists as a distinct artifact
kind awaiting its first off-tree consumer (the `fetch_binding_source`
column is wired in the matrix's column order for exactly that). The
first project with a lib source AND an off-tree binding source has **two
refs in one world** — and a single `ref` column cannot print them.

## 3. "How do you explain #6?" — the two faces of one ref

z3 rows #6 and #7 carry the same ref label, `pre-10549 (bc4585e0b)`:

| # | world | verdict |
| --- | --- | --- |
| #6 | `lib=B:dev` — the build-tree face | all ✓, no xfail |
| #7 | `lib=I:dev` — the staged face | install_lib **xfail**, probe_binding_ocaml **xfail** |

Both are honest. At that ref the *build tree* is complete — the OCaml
package is built, `z3ml.cmxa` is there, a consumer pointed at the build
tree links and runs. What #10549 fixed was the **install rules**, so the
defect exists only in what `cmake --install` stages: #7's install fails
its completeness assert and its consumer then finds no staged package.

That contrast is the finding, and it is only legible because the two
faces are separate rows. But the `ref` column labels them identically —
a reader must open the tooltip (or read the scenario name) to learn which
row is which. That is the concrete cost of naming a row after one
coordinate.

## 4. Options for the row's name — option 1 LANDED (2026-08-19)

Chosen and implemented: **the setting block**. The leading columns are
one per declared artifact KIND, each cell that artifact's placement in
this world (source cells carry their own ref link); the action columns
then hold verdict marks only, with the artifact's stage in the tooltip.

```
sqlite   | # | src | lib                | ocaml        | py          || build_lib | install_lib | probe_lib
         | 2 |  F  | I:s                | opam sqlite3 | pip sqlite3 ||     ✓     |      ✓      |     ·
         | 5 |  F  | apt sqlite3.3.45.1 | opam sqlite3 | pip sqlite3 ||     —     |      —      |     ✓

z3       | #11 | F pre-10549 | B:d | B:d | pip z3-solver || … install_lib —     … probe_b ✓
         | #12 | F pre-10549 | I:d | B:d | pip z3-solver || … install_lib xfail … probe_b xfail

zarith   | #19 | apt libgmp-dev | B:d         | ocaml-src F master | …
         | #20 | apt libgmp-dev | opam zarith | ocaml-src F 1.14   | …
```

Note what each fixes: z3's #11/#12 differ visibly (`B:d` vs `I:d`) where
one `ref` column labelled them identically; zarith names its BINDING's
source in a column that says so (§5 of the data fix below); sqlite's
`(ambient)` src cell is honest and the lib cell carries the identity.

Pinned: `matrix.setting_block_identifies_world` — one column per kind
with no duplicates, a cell iff the project declares that kind, and no two
rows of a project sharing their setting tuple (the property the `ref`
column lacked).

Rejected: keeping `ref` and adding `world` beside it (redundant where the
ref IS the identity), and status quo.

### The zarith data fix that came with it

`Canary_opam_binding.t` gained `source_of_binding`: Pattern A projects
say whether their declared repos are the C LIB's (cairo, libffi) or a
BINDING's (zarith — `ocaml/Zarith.git` over an apt libgmp). zarith's
repos now enumerate as `a_binding_source OCaml` and fetch through
`Fetch (Binding_source ocaml)`, so §2's table entry "zarith's ref column
names the binding's source with nothing saying so" no longer applies —
the column is literally labelled `ocaml-src`.

Three latent bugs surfaced with it, each caught by a check:
`binding_couples` (the Built-binding↔source channel coupling) existed in
TWO copies that disagreed once one learned about off-tree sources;
`source_for_assignment` read `a_source` unconditionally and fell through
to the stable head (every zarith scenario would have fetched the 1.14
worktree while claiming master — caught by `repo_model.axes_pins`, which
asserts the emitted command carries the scenario's ref); and
`worktree_ensure_cmd` hardcoded the `source.ok` marker, so the first
binding-source fetch ran fine and then failed its postcondition.

## Options as they were considered (kept for the record)

1. **A derived `world` column** — project the assignment onto the axes
   that VARY across that project's rows, and print those. z3:
   `pre-10549 · lib B` / `pre-10549 · lib I`; sqlite: `lib B stable` /
   `lib I dev` / `lib apt`; zarith: `binding-src master · binding B`.
   Self-describing per project, no fixed schema, and it says *which*
   artifact a ref belongs to. Cost: the column's width/shape varies by
   project, and the commit link needs a home.
2. **Keep `ref` as pure provenance, add `world`** — `ref` stays the
   linked commit (empty when ambient), `world` carries the rest.
   Redundant when the ref IS the identity (llvm).
3. **Status quo** — `#N` + the stable code + the scenario name in the
   tooltip already carry full identity; the `ref` column stays a
   provenance hint. Cheapest; leaves §3's ambiguity on screen.

## 5. A separable gap: sqlite cannot name its versions at all

Independent of the column question. sqlite's rows show `lib B:s` /
`lib B:d` and no row anywhere says **3.45.1** or **3.46.1**, because:

- the universe declares CHANNELS (`(Built, [Stable; Dev])`), and version
  ids reach the enumeration only through Fetched store pins;
- the concrete versions live in `sqlite_amalg`, a realization function
  (dotted version, amalgamation id, zip URL — hardcoded per channel),
  which the display cannot see.

Making the version visible means DECLARING it (per-channel source repos
with real ids, the z3 `Repo_axes` shape), which would also let the
amalgamation URL and numeric id derive from the declared version instead
of a parallel hardcoded table. It reorders sqlite's rows (the apt world
joins a ref group), which is why it is on hold with the rest.

Related: `stage1_declare_spec.md` §5 (version as artifact identity) is the
general form — version ids on Built/Installed provisions, not just
Fetched pins.

## 6. Landed while this was opened (not on hold)

- **Cell stage progression** (user-chosen 2026-08-19): a cell names the
  stage the STEP leaves the artifact in, so a staged world reads
  `src F → lib B:s → lib I:s → lib I:s` instead of `lib I:s` three
  times. Pin: `matrix.cell_stage_progression`.
- **Known display gap**: an Installed world's only lib probe is tagged
  `probe_lib_staged`, so the single `probe_lib` column renders `·` (not
  run) where `canary status` shows a pass. The fix is the location
  sub-axis (a column per probe location) — see `status_project.md`;
  marking the column from any `probe_lib*` step would conflate a
  build-tree pass with a staged failure, which is the distinction the
  Installed worlds exist to draw.

---

## 7. A `·` cell is not a neutral state

*(Absorbed from `run_model_revisit.md` §1 + §5, 2026-08-24. Both findings
are about what the matrix SAYS, so they belong here.)*

The matrix renders "not run" as `·`, visually adjacent to `✓`, and both
read as "nothing to worry about". They are not the same claim: `✓` says
*this was checked*, `·` says *nothing is known*.

**This is measured, not aesthetic.** Rows #17–29 had never run. Filling
five of them surfaced two bugs that had been latent for days — z3's
`env_guard` pointing at a nonexistent path (it still *set* the variable,
so nothing failed) and a `dllz3ml.so` linked against a soname the tree no
longer produced. Both lived entirely inside the `·` region, and one was
introduced by a change whose own pin passed.

**Enumeration coverage is not verification coverage.** The enumeration
says which worlds EXIST; the matrix presents that as the set CHECKED.
`matrix.registry_shape` pins 42 rows — a number about *enumeration* — and
nothing pins how many have ever run, so the fraction can fall silently. A
row that has never run is a claim we are **not** making, and saying so is
the honest version. Where it stands: 41 of 42 have run; the holdout is
#28 (llvm `latest`), whose source declares no local tree, so running it
means cloning llvm-project and building libLLVM from scratch. That
sentence is the metric this section asks for — the point is that the tool
should print it rather than a person reconstruct it.

### The signal is the diff

All three z3 refs have run. Taking `latest` as the baseline, the other two
differ in **four cells out of ~105 populated**:

| ref | cell | latest | this ref | why |
| --- | --- | --- | --- | --- |
| arbipher | #19 `probe_binding_ocaml` | ✓ | **✗** | the fork cannot serve a staged consumer — a deliberate red (`../../project/issues.md` §1) |
| pre-10549 | #24 `install_lib` | ✓ | **xfail** | predates PR #10549, which added the installed OCaml package |
| pre-10549 | #24 `probe_binding_ocaml` | ✓ | **xfail** | consequence — nothing staged to probe |
| pre-10549 | #25 `install_lib` | ✓ | **xfail** | same as #24 |

Everything else repeats the baseline exactly — including all three
forward cells' `✗`, which are **one finding, not three**: apt's libz3
4.8.12 exports 705 `Z3_` symbols where a HEAD-built binding needs 791.
That failure is a property of apt, and every ref restates it.

That is the right result — re-running the identical cells is how we know
they are identical — but it says two things about presentation and scale:

- **A ref is a PERTURBATION of a baseline world**, and the interesting
  output is where the perturbation shows. The matrix has no notion of
  "same as baseline", so a reader scanning 16 z3 rows must cell-compare to
  find the three that matter.
- **It bounds how far refs scale.** Measured over the complete set, **96%
  of non-baseline cells restate the baseline**. Three refs is fine; the
  tenth would not be, and the cost is not only reading — `arbipher` needed
  a cold z3 build to produce five rows of which one was new.
- **The grid says how many worlds failed, never how many distinct things
  are wrong.** The forward cell is the sharpest case: three rows, one
  finding, no way to see that from the matrix.

Note the relation to [`stage2_enumerate_worlds.md`](enumeration/stage2_enumerate_worlds.md) §4: the
unread-source collapse is the same observation about *inputs* — a ref
nothing reads produces identical runs, so only the canonical one survives.
This is the *output* version: a ref that IS read but changes nothing still
costs a full set of rows. Two different rules; only the first exists.
