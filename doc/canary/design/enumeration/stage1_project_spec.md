# Pass 1 — declare: what a project states (`project_spec`)

**Kind: rationale.** Pass 1 of five. Standalone: everything needed to
read or write a project's declaration, without opening another doc. What
consumes it is [`stage2_filters.md`](stage2_filters.md) (pass 2, the
product over this universe); the map is [`README.md`](README.md).

> First per-stage document (2026-08-23, user: *"each stage (layer) should
> be standalone enough"*). It ABSORBED `repo_model.md` and
> `versioning.md`, which were purged 2026-08-23 (user: *"a record for
> design and track, which is less interested to read"*) — their live
> content is here, their open decisions moved to
> `../../project/status_project.md` §2, and `git show 781f98e` has the
> originals. It also took pin declaration from `../../project/opam_exclusive_store_issue.md` and
> the worked example from `algorithm_explainer.md` §3; both keep what is
> not stage 1.

Stage 1 is **pure declaration**: project facts, no execution and no
policy. A project states which artifacts exist, how each can be
provided, at which versions, and who provides it. Everything downstream
— which scenarios exist, which commands run, which cells the matrix has
— is computed from this table.

## 1. The unit — one artifact, one row

```ocaml
artifact_row ~artifact ~universe ?follows ?runtime ?provider ?rationale ()
```

`project_spec_of_rows` turns a row list into the spec the enumeration
reads. `pr_artifacts` on a `project_run` IS that row list — there is no
second place a project describes itself.

| field       | what it states                                                  |
| ----------- | --------------------------------------------------------------- |
| `artifact`  | the identity (§2)                                               |
| `universe`  | which provisions, and at which channels (§3)                    |
| `provider`  | where it comes from (§4) — four things are DERIVED from it      |
| `follows`   | this artifact's channel is locked to another's (§6)             |
| `runtime`   | the runtime-edge mode, when the provider does not imply it (§6) |
| `rationale` | WHY the universe stops where it does (§7)                       |

## 2. Artifact identity

```ocaml
type artifact_info =
  | A_source | A_headers | A_lib
  | A_binding of lang * mechanism
  | A_binding_source of lang
  | A_app of app_wiring

val kind_of : artifact_info -> artifact_kind      (* the coarse role *)
```

An artifact's identity carries whatever refines it: a binding by its
**mechanism**, an app by its **wiring**. Source, headers and lib are
one-per-project, so they carry nothing.

**`artifact_kind` is a separate, coarser type**, projected out by
`kind_of`. Several consumers want only the role and not the refinement —
`kind_order` (the matrix's column order), the action catalogue's
`consumes_of_action` / `produces_of_action` (a `Build_binding l` consumes
`Lib` whatever the mechanism), `string_of_artifact_kind`,
`scenario_dir_of`'s naming. Keeping the coarse view as its own type means
those say what they mean instead of writing `Binding (l, _)` everywhere.

**Why three constructors carry nothing.** `A_source`, `A_headers` and
`A_lib` have no payload because this type is pure IDENTITY — everything
that varies lives in the structures that use it: `placement`
(`{ provision; version }`), `artifact_axes` (the declaration), and
`assignment` (the pairing). A lib's provision, version, provider and pins
are all present; none of them is part of what the lib *is*.

A payload-free constructor means **one per project**. There is one
source, one header set, one lib, so there is nothing to tell two of them
apart. `A_binding` carries lang × mechanism because a project has several
bindings. So `A_lib` is the encoding of a known limitation rather than an
oversight — one C library per project is exactly what
[`multi_lib.md`](multi_lib.md) is blocked on, and the change it proposes
gives `A_lib` a name. **A constructor here gains a payload when the thing
it names stops being unique.**

> **This was a record until 2026-08-24** — `{ kind; ext }`, two fields
> where the second refined the first and the pairing rule was held only
> by convention. It let `{ kind = Lib; ext = Ext_mechanism Cstubs }` and
> `{ kind = Binding OCaml; ext = Ext_none }` typecheck, both nonsense.
> Making it a sum found a live instance immediately: tiny's `id_of_kind`
> fallback built an `App` with `Ext_none` — an app with no wiring, which
> the smart constructor could not produce and nothing downstream could
> read a wiring out of.
>
> An `ext_of` projection survived the first cut, for consumers that
> wanted "whatever refines this kind" without caring which flavour. It
> was removed the same day: once the identity was a sum, four of the five
> turned out to want only the mechanism (`mechanism_of`), and the fifth
> was a node field that had never been read. Keeping it would have left
> the record's shape behind in a type that no longer had it.

Two consequences worth knowing before you declare:

- **`Binding_source lang` is a separate artifact from `Source`**
  (2026-08-18). A binding may live in a different repo than the lib —
  zarith's binding is `ocaml/Zarith`, its lib is the system gmp. A repo
  providing both (z3's on-tree bindings) makes the second fetch
  idempotent; the repo is already there.
- **`A_lib` carries an OPTIONAL name** (2026-08-25). `None` = "this
  project has one lib, naming it would be redundant" — true of all nine —
  and it still prints plain `lib`, so no id moved. `Some n` names one of
  several. One C library per project is therefore no longer baked into
  *identity*; it is still baked into the **action catalogue**, whose
  `as_consumes : artifact_kind list` cannot say which of two libs a step
  links and which it loads. See [`multi_lib.md`](multi_lib.md) §3a —
  what is left is a stage-1-and-4 limitation, not a runner one.

Ids are born-safe (`binding-ocaml-cstubs`, `-` not `:`) because they
reach `PYTHONPATH` / `LD_LIBRARY_PATH`. The `:` form
(`pretty_id`) is display-only — never a key or a path.

## 3. The universe — which provisions, at which channels

```ocaml
~universe:[ (Fetched (Sys_pkg libsqlite3_dev), [ Stable ]);
            (Built_from a_source,              [ Stable; Dev ]);
            (Installed,                        [ Stable; Dev ]) ]
```

Each entry names a **provision spec** — the coarse provision plus where
that particular one comes from (§4). The coarse view below is the
projection the enumeration ranges over.

A **provision** is how the artifact is obtained:

| provision   | meaning                                                                                     |
| ----------- | ------------------------------------------------------------------------------------------- |
| `Absent`    | not present in this world (an optional dep that is off)                                     |
| `Fetched`   | a package manager or a repo fetch supplies it                                               |
| `Built`     | canary compiles it from source                                                              |
| `Installed` | canary staged a Built artifact into an install prefix, and the world probes the STAGED copy |
| `Vendored`  | a pre-existing local copy canary only probes (a prepared prebuilt)                          |

Two properties of this table are load-bearing, and both exist because the
flat version worked and then didn't:

- **Per-artifact.** Each artifact draws from its OWN universe. Real
  projects are heterogeneous — a lib at `{Fetched, Built}` × `{Stable,
  Dev}` beside a binding only at `Fetched@Stable`. A single global list
  was a tiny-shaped simplification. Pins:
  `enumerate.per_artifact_provisions`, `enumerate.per_artifact_versions`.
- **Version is per-PROVISION, not per-artifact.** An artifact's version
  universe depends on HOW it is provided: a `Fetched` lib is
  version-ambient (the PM picks — declare one representative), a `Built`
  lib ranges over the versions canary can build, a `Vendored` one over
  the prepared variants. Without this the flat provision × version
  product over-generates — a `Vendored@Dev` world no prebuilt backs, or a
  `Fetched@Dev` that only dedups away downstream. Pin:
  `enumerate.per_provision_versions`.

`Installed` is a **separate world, not a view of `Built`** (2026-08-18,
the provider-exclusive-rows model): each built version gets its staged
face as its own row, because the install is a copy-*transform* and its
divergences are the bug class worth checking. See
[`../staged_parity.md`](../staged_parity.md) for what that check is.

## 4. Origins — one declaration per admissible provision

A row states, for each way the artifact can exist, **where that one comes
from**:

```ocaml
type provision_spec =
  | Absent
  | Fetched of provider          (* a PM, a repo, a repo family *)
  | Built_from of artifact_info  (* the artifact it compiles from *)
  | Installed                    (* the staged face of its own Built_from *)
  | Vendored_at of string        (* a local path that pre-exists the run *)
```

sqlite's lib, which is the case that forced this:

```ocaml
artifact_row ~artifact:a_lib
  ~universe:
    [ (Fetched (Sys_pkg libsqlite3_dev), [ Stable ]);
      (Built_from a_source,              [ Stable; Dev ]);
      (Installed,                        [ Stable; Dev ]) ]
  ()
```

### The axis this encodes

Not external vs internal — `Vendored` is external too, since `canary
prebuilt` downloads conda-forge tarballs before the run. The question
each constructor answers is **which action in THIS run produces it**:

| spec | producing action |
| --- | --- |
| `Absent` | — |
| `Vendored_at` | **none** — it pre-exists the run |
| `Fetched` | `Fetch` |
| `Built_from` | `Build_*` |
| `Installed` | `Install_lib` |

Which is exactly what `providing_action_of` computes, and why a Vendored
artifact has none: the arrow starts outside the run. Where its bytes came
from is a *preparation* concern — hence `canary prebuilt` being a
separate command.

### Payloads, by the same rule as §2

Each branch carries what its action needs and nothing more.
`Installed` carries nothing because it is always the staged face of *this
artifact's own* `Built_from` — one possibility, so nothing to name.
`Built_from` carries the artifact it compiles from, and that **deleted a
hardcode**: `build_deps_of` used to read

```ocaml
if id = a_lib && declared a_source then [ a_source ] else []
```

so zarith — whose binding builds from `a_binding_source OCaml`, not the
lib's source — was a special case. Now the row says it.

### What is derived from it

| derived | from | what it gives |
| --- | --- | --- |
| the coarse `provision` | `provision_of_spec` | the axis value the enumeration ranges over |
| the runtime edge | the **Fetched** branch's provider | `Ambient` when a lang package bundles its own native lib |
| the store pins | the **Fetched** branch's provider | identity-bearing versions (§5) |
| the producing action | the spec | `Fetch` / `Build_lib` / `Install_lib` / none |

The runtime edge comes from the Fetched branch and there is no ambiguity
to resolve: `Ambient` means the *package* bundles its own lib, and a
Built artifact is built here and bundles nothing.

> **This was two declarations until 2026-08-25.** A row carried a coarse
> `~universe` AND one `?provider` for the whole artifact, and the two only
> lined up for one of the provisions — sqlite declared `Sys_pkg
> libsqlite3-dev` beside `{Fetched, Built, Installed}`, where the package
> explains only the Fetched case. That needed a special rule ("the
> provider's provision is a BASELINE, not the whole truth") and a
> per-project pin to stop the two drifting. Both are gone: there is one
> declaration, the coarse axis is a projection of it, and
> `<project>.providers_match_baseline_provisions` retired because the type
> now does what it watched for.
>
> The relationship is the one §2 already has:
>
> ```
> provision_spec  ──provision_of_spec──▶  provision
> artifact_info   ──kind_of────────────▶  artifact_kind
> ```

### The provider, now narrower

`provider` still exists and still names a fetch origin — `Sys_pkg`,
`Lang_pkg`, `Repo`, `Repo_axes` — but it is reachable only *inside*
`Fetched`. `provider_of_row` returns `None` for a row that is only built,
staged or vendored, which is the honest answer where the old model had to
invent one.

**The `Repo` vs `Repo_axes` distinction is unchanged.** A single `Repo`
is one checkout; `Repo_axes` is a family covering one artifact's channels
— official stable, official dev, plus a labeled fork when one exists.
Each repo carries its own `version`, and those project into the pins with
the **channel preserved**, which is what lets thin's `Subset [Stable]`
drop the dev repos.

**A repo declares what it contains, not the reverse** (user, 2026-08-15).
`source_repo.artifacts` lists the artifact ids a repo can provide —
`Z3Prover/z3` = [lib; binding OCaml; binding Python], `ocaml/Zarith` =
[binding OCaml]. On-tree vs off-tree is then DERIVED, not declared: on-tree
means the artifact's repo is shared with the project's others. An artifact
must appear in its provider repo's contents — pinned by
`repo_model.contents_invariant`.

**What a repo provider needs on disk** (the decided lifecycle, 2026-08-15):

- **A repo is DISTRIBUTED.** The local checkout and the remote are
  modelled separately and may differ.
- **One repository, a `git worktree` per tracked ref.** Shared objects, no
  in-place `git checkout` churn. So *stable* and *latest* are
  **descriptive markers that can move**, not fixed identities. Pinned by
  `repo_model.worktree_paths`.
- **Refresh is on demand.** Nothing chases nightlies.
- **The layout is a setting.** `~/code/contrib/<project>-all/<repo-variant>`,
  held as data in the base layer.
- **A fork needs no remote.** `None` is a local-only fork, which
  `spec-check` reports as a WARNING — we survey many projects and may
  never find a bug worth pushing. Pin: `spec_check.local_fork_warns`.
- **An inaccessible source does not break checking.** The enumeration and
  the artifact checks still detect and blame a wrong scenario.

## 5. Versions — ambient, or identity-bearing

```ocaml
type build_id = { channel : channel; id : string; quality : quality }
```

`channel` is `Dev | Stable`. `id` is the concrete version — a tag for
stable, a commit or ref label for dev — and it is **empty for an
unpinned artifact**.

The precondition that makes this work is ssot §4.2.2's: *same version ⇒
identical artifact* (for binaries, given the same tooling) — so a version
is a sufficient identity key. Note `source_repo` carries a typed
`version` **beside** its `ref_` string; the strings were left in place
rather than migrated, so both exist and the typed field is the one the
axes read.

That empty string is the whole rule:

- **`id = ""` ⇒ version-ambient.** The PM picks. Two `Fetched@v`
  scenarios that differ only in a declared version dedup to one run,
  because the declared version is not part of scenario identity.
- **`id` non-empty ⇒ identity-bearing.** The version reaches
  `scenario_dir_of`, the ambient key, and assignment dedup — so
  `ssl@0.6.0` and `ssl@0.7.0` are two scenarios, and `z3` at `latest`
  vs `arbipher` are two chains.

A project never hand-writes the pin axis. It declares versions on the
**provider**, and `artifact_row` projects them into `ax_pins`:

```ocaml
~provider:(Lang_pkg { lang = OCaml; pm = Opam; package = "sqlite3";
                      self_contained = false;
                      versions = Some [ { pin_version = "5.1.0"; install_name = None };
                                        { pin_version = "5.4.1"; install_name = None } ] })
```

`install_name` is the escape for packages whose install target is not
`<package>.<version>` — e.g. an opam package literally named
`llvm.19-shared` whose version is not `19-shared`.

**What declaring a pin commits you to.** A pin is not a preference, it is
a required **state of a singleton resource** — opam holds one version of
a package per switch. So declaring two pins on one artifact declares two
worlds that **cannot coexist**, and the runner has to serialize and
verify them: [`stage4_order.md` §2](stage4_order.md) is the general
principle (partition a place, serialize a state), and
[`../../project/opam_exclusive_store_issue.md`](../../project/opam_exclusive_store_issue.md) is opam's case.

Declaration is free; the cost is at run time. Before declaring a pair,
dry-run the older pin —
`opam install <pkg>.<v> --show-actions --dry-run` — and see what it
drags: one package (fine), collateral rebuilds of other projects'
packages (a design question), or the compiler (do not).

`ps_versions_of` reads it back: a `Fetched` artifact with pins ranges
over the pins; everything else ranges over the channel list. The
downstream half — the pin as an exclusive lock on a single-valued store,
the pin-checked fetch, the run order — is
[`../../project/opam_exclusive_store_issue.md`](../../project/opam_exclusive_store_issue.md). The version-as-identity
model is ssot §4.2.2 plus §5 here.

## 6. `follows` and `runtime`

`~follows:other` locks this artifact's channel to another's. Use it when
the two versions are the same fact: sqlite's source row follows the lib,
because the amalgamation version IS the lib's version.

Use it *sparingly*. It is the blunt instrument, and it has cost real
coverage: source rows once carried `~follows:a_lib`, which killed the
phantom refs but also forbade the FORWARD cell — a binding built from a
dev tree probed against the released lib, which is the world most likely
to find a bug. Two narrower constraints replaced it; see
[`stage2_filters.md`](stage2_filters.md) §3–4 before reaching for `follows`.

`~runtime` states the runtime-edge mode (`Lockstep` / `Independent` /
`Ambient why`) when the provider does not imply one. A self-contained
lang package implies `Ambient`; a normal opam binding over a system lib
is `Independent`.

## 7. `rationale` — why the axis stops

```ocaml
~rationale:"apt ships one libgmp; upstream publishes no Linux binary"
```

Added 2026-08-19 (user: *"add the project spec explanation … to let
other readers know our selection"*). A one-point axis is usually a
**fact about the world**, not an omission — and without the rationale a
reader cannot tell those apart. Surfaced by `canary spec` and beside
`spec-check`'s warnings.

## 8. Worked example — sqlite

Four rows produce ten scenarios and the registry's first full 2×2:

```ocaml
artifact_row ~artifact:a_source ~follows:a_lib
  ~universe:[ (Fetched (Repo sqlite_source_stable), [ Stable; Dev ]) ] ();

artifact_row ~artifact:a_lib
  ~universe:[ (Fetched (Sys_pkg libsqlite3_dev), [ Stable ]);
              (Built_from a_source,              [ Stable; Dev ]);
              (Installed,                        [ Stable; Dev ]) ] ();

artifact_row ~artifact:(a_binding OCaml Cstubs) ~runtime:Independent
  ~universe:[ (Fetched (Lang_pkg { …; versions = Some [5.1.0; 5.4.1] }),
               [ Stable ]) ] ();

artifact_row ~artifact:(a_binding Python Cext)
  ~universe:[ (Fetched sqlite_python_provider, [ Stable ]) ] ();
```

Read it as: the lib has **five placements** (one fetched + two built +
their two staged faces), the OCaml binding has **two** (its store pins),
5 × 2 = 10, and the Python binding is ambient in every one. Pinned by
`enumerate.project_spec_sqlite_shape` and `sqlite.provider_rows`.

### What else these four rows determine

The scenario count is the visible consequence. There is a second one, and
it is easy to miss because it has no pass of its own: **the declaration
also decides which action CHAINS this project can run.**

`chain_applicable` filters the **38 universal chains** (`canary paths`)
using the spec alone — no policy, no assignment, no scenario. A chain
survives when, for every step in it:

- the step's output artifact is **declared**, and
- declared at a provision the step's version rule needs — `Ambient` wants
  `Fetched`, `Follows_input` wants `Built` — with **`Vendored` passing
  through**, since the artifact exists and no action has to produce it;
- and a `build_binding` step has a **static** binding to build (a
  `Dynamic_ffi` binding has no build stage, so chains that would build it
  are not applicable).

`patterns_of` then pairs each surviving chain with each assignment that
matches it. That pairing is what makes a **scenario** a chain plus
coordinates — [`stage0_naming.md`](stage0_naming.md) sense 1 — rather
than coordinates alone.

Read against sqlite's rows above: declaring `Built_from a_source` on the
lib is what keeps the `build_lib → fetch_source → …` chains applicable,
and declaring the Python binding as `Cext` (static) is what keeps
`build_binding_python` ones alive. Drop a provision from a universe and
chains disappear silently — the scenario count moves, and nothing says
which shapes of run went with it.

**Nothing prints a project's surviving chains.** `canary paths` shows the
unfiltered 38. Naming and exposing them is a tracker item
(`../../project/status_project.md`).

## 9. The channel pair — why a universe should have two points

*(2026-08-19 user framing, moved here from the purged `repo_model.md`.)*

Every artifact — the C lib, and each binding at a given (lang ×
mechanism) — should offer **two** choices, a **stable** and a **latest**.
Two, not three: the earlier "3-way" framing counted official-stable,
official-latest and our fork as three points on one axis, and they are
not. **The fork is not a version** — it is where a fix lives, it carries
no coverage of its own, and it sits outside the matrix.

One lib × one binding then gives a 2×2, and each cell is a distinct
question:

|                | binding stable                                                         | binding latest                                           |
| -------------- | ---------------------------------------------------------------------- | -------------------------------------------------------- |
| **lib stable** | baseline — both released, must pass                                    | **FORWARD**: the new binding wants API the old lib lacks |
| **lib latest** | **BACKWARD**: the new lib dropped or renamed what the old binding uses | dev baseline — both HEAD, must pass                      |

More bindings multiply it: OCaml + Python is 2×2×2.

**Realizing a pair — three ways, cheapest first:**

1. **Two store pins** on one `Fetched` provision (§5). No build, no
   repo, pure declaration. ssl and sqlite's binding do this.
2. **Two prebuilt versions**, where the platform ships more than one —
   apt's `llvm-19-dev` vs a newer one, or apt vs a conda-forge prebuilt
   (zlib, zstd, cairo, libffi).
3. **Prebuilt vs source-built** — expensive, and the only option when the
   ecosystem ships exactly one version (sqlite's amalgamation; z3/llvm's
   HEAD builds). Pick this last: the prebuilt-shadows-source rule
   ([`stage2_filters.md`](stage2_filters.md) §5) will collapse a same-version pair
   anyway.

Say **channel** for the axis and **fix fork** for the repair repo. Do not
call the fork a channel, a version, or a third way.

## 10. What stage 1 cannot express

Known limits, each with its own note:

- **A second C library.** `Lib` has no name —
  [`multi_lib.md`](multi_lib.md).
- **A binding-version axis on a template project.**
  `Canary_opam_binding` hardcodes `versions = None`, so the five template
  projects cannot declare pins — `../../project/issues.md`.
- **A gate inside the binding's own build.** `pm_dep_gate` describes
  gates a package manager enforces; a version test a package runs in its
  own `build:` (mlmpfr) has no representation. Pin for what IS
  expressible: `spec.pm_dep_gate_groups`.
- **A pinned version for an artifact the PM chooses.** A project that
  wants to pin a `Fetched` version overrides through its provider; for
  system packages (`Sys_pkg`) that is not wired.

## Pins guarding this stage

| pin                                           | asserts                                                                        |
| --------------------------------------------- | ------------------------------------------------------------------------------ |
| `enumerate.project_spec_sqlite_shape`         | the worked example's rows produce the expected universe                        |
| `enumerate.per_artifact_provisions`           | each artifact draws from its own provision universe                            |
| `enumerate.per_artifact_versions`             | …and its own version universe                                                  |
| `enumerate.per_provision_versions`            | version is per (artifact × provision), not flat                                |
| `arrow.providing_action_total_and_consistent` | provider → action is total, and inverse-consistent with `provision_of_actions` |
| `repo_model.axes_pins`                        | a repo family's per-channel pins reach the axes with the channel preserved     |
| `repo_model.contents_invariant`               | every artifact appears in its provider repo's declared contents                |
| `spec.vendored_prebuilt_pair`                 | a declared prebuilt pair really produces two probe worlds                      |
| `spec.pm_dep_gate_groups`                     | the declared PM gates classify into the expected freedom groups                |
| `sqlite.provider_rows`, `z3.provider_rows`    | each project's rows match its baseline provisions                              |
| `spec_check.local_fork_warns`                 | a labeled repo without a remote warns rather than errors                       |
