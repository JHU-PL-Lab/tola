# Stage 1 — what a project declares (`project_spec`)

**Kind: rationale.** Standalone: everything needed to read or write a
project's declaration, without opening another doc. The stage this feeds
is [`filters.md`](filters.md) (stage 2, which consumes the universe);
the map is [`README.md`](README.md).

> First per-stage document (2026-08-23, user: *"each stage (layer) should
> be standalone enough"*). It ABSORBED `repo_model.md` and
> `versioning.md`, which were purged 2026-08-23 (user: *"a record for
> design and track, which is less interested to read"*) — their live
> content is here, their open decisions moved to
> `../../project/status_project.md` §2, and `git show 781f98e` has the
> originals. It also took pin declaration from `store_switching.md` and
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

| field | what it states |
| --- | --- |
| `artifact` | the identity (§2) |
| `universe` | which provisions, and at which channels (§3) |
| `provider` | where it comes from (§4) — four things are DERIVED from it |
| `follows` | this artifact's channel is locked to another's (§6) |
| `runtime` | the runtime-edge mode, when the provider does not imply it (§6) |
| `rationale` | WHY the universe stops where it does (§7) |

## 2. Artifact identity

```ocaml
type artifact_id = { kind : artifact_kind; ext : artifact_ext }
```

`kind` is the coarse role — `Source`, `Headers`, `Lib`,
`Binding of lang`, `Binding_source of lang`, `App`. `ext` refines it
where one kind can appear more than once in a project: a binding by its
**mechanism** (`Ext_mechanism Cstubs`), an app by its **wiring**
(`Ext_wiring`). Sources are `Ext_none`.

Two consequences worth knowing before you declare:

- **`Binding_source lang` is a separate artifact from `Source`**
  (2026-08-18). A binding may live in a different repo than the lib —
  zarith's binding is `ocaml/Zarith`, its lib is the system gmp. A repo
  providing both (z3's on-tree bindings) makes the second fetch
  idempotent; the repo is already there.
- **`Lib` carries no name.** One C library per project is baked into the
  identity, which is why a project cannot declare a second one. That is
  the open blocker in [`multi_lib.md`](multi_lib.md), and it is a stage-1
  limitation, not a runner one.

Ids are born-safe (`binding-ocaml-cstubs`, `-` not `:`) because they
reach `PYTHONPATH` / `LD_LIBRARY_PATH`. The `:` form
(`pretty_id`) is display-only — never a key or a path.

## 3. The universe — provisions × channels, per artifact

```ocaml
~universe:[ (Fetched,   [ Stable ]);
            (Built,     [ Stable; Dev ]);
            (Installed, [ Stable; Dev ]) ]
```

A **provision** is how the artifact is obtained:

| provision | meaning |
| --- | --- |
| `Absent` | not present in this world (an optional dep that is off) |
| `Fetched` | a package manager or a repo fetch supplies it |
| `Built` | canary compiles it from source |
| `Installed` | canary staged a Built artifact into an install prefix, and the world probes the STAGED copy |
| `Vendored` | a pre-existing local copy canary only probes (a prepared prebuilt) |

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
[`staged_parity.md`](staged_parity.md) for what that check is.

## 4. Providers — and the four things derived from them

```ocaml
type provider =
  | Absent
  | Vendored of string | Cached of string      (* a local path *)
  | Repo of source_repo                        (* one repo *)
  | Repo_axes of source_repo list              (* a repo FAMILY, per channel *)
  | Sys_pkg of system_package_spec             (* apt / brew *)
  | Lang_pkg of { lang; pm; package; self_contained; versions }
```

A project declares the provider once; canary derives the rest, so the
axis and the detail cannot drift:

| derived | function | what it gives |
| --- | --- | --- |
| the coarse provision | `provision_of_provider` | the axis value the universe must agree with |
| the runtime edge | `dep_mode_of_provider` | `Ambient` when a lang package bundles its own native lib (`self_contained = true`) |
| the store pins | `versions_of_provider` | the identity-bearing versions (§5) |
| the producing action | `providing_action_of` | `Fetch` / `Build_lib` / `Install_lib` / … |

That last one is **the arrow** (user, 2026-08-06): an artifact comes from
its provider *via an action*, and **fetching is the same shape as
building**. Building is the case where the provider is itself an
enumerated artifact (a repo whose checkout is the `Source` the build
consumes); fetching is the case where the provider sits at the
enumeration's boundary. `None` — a `Vendored`/`Cached` path — means no
canary action produces it: the arrow starts outside the run. Pinned
total and consistent against the inverse (`provision_of_actions`) by
`arrow.providing_action_total_and_consistent`.

**`Repo` vs `Repo_axes`.** A single `Repo` is one checkout. `Repo_axes`
is a repo *family* covering one artifact's channels — official stable,
official dev, plus a labeled fork when one exists. Each repo carries its
own `version` record, and those project into the pins with the **channel
preserved**, which is what lets the thin policy's `Subset [Stable]` drop
the dev repos. The stable repo is listed first; that ordering is the
canonical pin (§5).

**What a repo provider needs on disk** (the decided lifecycle, 2026-08-15):

- **A repo is DISTRIBUTED.** The local checkout and the remote are
  modelled separately and may differ — the official repo can have a
  local fork, and our fork has its own remote.
- **One repository, a `git worktree` per tracked ref.** Shared objects,
  no in-place `git checkout` churn, several versions coexisting. So
  *stable* and *latest* are **descriptive markers that can move**, not
  fixed identities. Pinned by `repo_model.worktree_paths`.
- **Refresh is on demand.** A version refreshes when a run or a prepare
  asks for it; nothing chases nightlies.
- **The layout is a setting, not a hardcode.**
  `~/code/contrib/<project>-all/<repo-variant>` is the convention, held
  as data in the base layer. Directory naming follows the repo's official
  name.
- **A fork needs no remote.** `remote : repo_remote option`; `None` is a
  local-only fork, which `spec-check` reports as a WARNING, not an error
  — we survey many projects and may never find a bug worth pushing. What
  is required is the local checkout. Pin: `spec_check.local_fork_warns`.
- **An inaccessible source does not break checking.** The enumeration and
  the artifact checks still detect and blame a wrong scenario; the source
  repo is optional provenance. (GMP's repo is open but hg + tarballs, so
  gmp dev stays unmodelled.)

**A repo declares what it contains, not the reverse** (user,
2026-08-15). `source_repo.artifacts` lists the artifact ids a repo can
provide — `Z3Prover/z3` = [lib; binding OCaml; binding Python],
`ocaml/Zarith` = [binding OCaml]. On-tree vs off-tree is then DERIVED,
not declared: on-tree means the artifact's repo is shared with the
project's others. An artifact must appear in its provider repo's
contents — pinned by `repo_model.contents_invariant`. Repo lifecycle
(worktrees, forks, remotes, refresh) is above; the open decisions it
left are `../../project/status_project.md` §2.

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

**Why pins exist at all**, since it constrains what you may declare: opam
allows exactly one version of a package per switch — a core solver
invariant with no escape hatch. A pin is therefore not a preference but
**store state**, and declaring two of them means the two scenarios cannot
run at the same time. Declaration is free; the cost is at run time, and
before declaring a pair you should dry-run the older pin
(`opam install <pkg>.<v> --show-actions --dry-run`) and see what it
drags: one package (fine), collateral rebuilds of other projects'
packages (a design question), or the compiler (do not). See
[`store_switching.md`](store_switching.md).

`ps_versions_of` reads it back: a `Fetched` artifact with pins ranges
over the pins; everything else ranges over the channel list. The
downstream half — the pin as an exclusive lock on a single-valued store,
the pin-checked fetch, the run order — is
[`store_switching.md`](store_switching.md). The version-as-identity
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
[`filters.md`](filters.md) §3–4 before reaching for `follows`.

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
  ~universe:[ (Fetched, [ Stable; Dev ]) ]
  ~provider:(Repo sqlite_source_stable) ();

artifact_row ~artifact:a_lib
  ~universe:[ (Fetched,   [ Stable ]);        (* apt libsqlite3-dev   *)
              (Built,     [ Stable; Dev ]);   (* two amalgamations    *)
              (Installed, [ Stable; Dev ]) ]  (* their staged faces   *)
  ~provider:(Sys_pkg prebuilt.system_package) ();

artifact_row ~artifact:(a_binding OCaml Cstubs)
  ~runtime:Independent
  ~universe:[ (Fetched, [ Stable ]) ]
  ~provider:(Lang_pkg { …; versions = Some [ 5.1.0; 5.4.1 ] }) ();

artifact_row ~artifact:(a_binding Python Cext)
  ~universe:[ (Fetched, [ Stable ]) ]
  ~provider:sqlite_python_provider ();
```

Read it as: the lib has **five placements** (one fetched + two built +
their two staged faces), the OCaml binding has **two** (its store pins),
5 × 2 = 10, and the Python binding is ambient in every one. Pinned by
`enumerate.project_spec_sqlite_shape` and `sqlite.provider_rows`.

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

| | binding stable | binding latest |
| --- | --- | --- |
| **lib stable** | baseline — both released, must pass | **FORWARD**: the new binding wants API the old lib lacks |
| **lib latest** | **BACKWARD**: the new lib dropped or renamed what the old binding uses | dev baseline — both HEAD, must pass |

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
   ([`filters.md`](filters.md) §5) will collapse a same-version pair
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

| pin | asserts |
| --- | --- |
| `enumerate.project_spec_sqlite_shape` | the worked example's rows produce the expected universe |
| `enumerate.per_artifact_provisions` | each artifact draws from its own provision universe |
| `enumerate.per_artifact_versions` | …and its own version universe |
| `enumerate.per_provision_versions` | version is per (artifact × provision), not flat |
| `arrow.providing_action_total_and_consistent` | provider → action is total, and inverse-consistent with `provision_of_actions` |
| `repo_model.axes_pins` | a repo family's per-channel pins reach the axes with the channel preserved |
| `repo_model.contents_invariant` | every artifact appears in its provider repo's declared contents |
| `spec.vendored_prebuilt_pair` | a declared prebuilt pair really produces two probe worlds |
| `spec.pm_dep_gate_groups` | the declared PM gates classify into the expected freedom groups |
| `sqlite.provider_rows`, `z3.provider_rows` | each project's rows match its baseline provisions |
| `spec_check.local_fork_warns` | a labeled repo without a remote warns rather than errors |
