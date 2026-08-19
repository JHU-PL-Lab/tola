# The result matrix — what a row is, and what names it

> 2026-08-19. Opened by the user's observation on the sqlite rows: "ref
> is not the only world … how do you explain #6?" This is the analysis,
> not a decision — the column change is ON HOLD pending discussion.
> Renderer: [`canary_matrix.ml`](../../src/canary/main/canary_matrix.ml);
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
multi-repo principle (`repo_model.md`) says a repo records *what
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

## 4. Options for the row's name (undecided)

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

Related: `versioning.md` (typed version as artifact identity) is the
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
