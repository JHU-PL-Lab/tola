# SSOT — Single Source of Truth for Canary IDs

This file is the canonical catalogue for IDs used in the manuscript
(`draft.md`), materials (`surface_draft/`), and the canary code. Any
new occurrence of an ID type listed here should reference this file;
any rename/renumber happens here first and ripples out.

**Status legend.**

- **stable** — name and ID fixed; manuscript + code agree.
- **drift** — manuscript and code names/counts disagree; needs a decision.
- **placeholder** — listed in the manuscript as roadmap; not yet in code.
- **roadmap** — planned but not in either manuscript or code.

**Code commands that re-emit canonical lists** (rerun to confirm
this file is current):

```sh
dune exec src/bin/canary_main.exe -- tiny-scenarios list  # bad-scenario names
dune exec src/bin/canary_main.exe -- paths                # 15-pattern action table
dune exec src/bin/canary_main.exe -- graph                # rule schema diagram
```

When manuscript prose forces a decision, update the relevant table
below, then propagate to `draft.md` (and code, when the polish pass
arrives).

---

## 1. Artifacts (`Ar.X`)

**Flow.** `canary_basic.ml: artifact_kind` + tiny `scenarios.py`
artifact tree ──► SSOT §1 ──► draft.md §2 / §3; consumed by every
project spec.
**Co-providers.** `artifact_kind` (code) and tiny's scenario
artifacts must agree on kinds and global Ar.X identity. Drift here
breaks scenario→artifact mapping in §5.

Status: **drift** — manuscript Ar.0..Ar.3 (4 kinds); code has 5 (adds
`Headers`). §2's `Ar.0..Ar.2` vs §3's `Ar.1..Ar.3` is another internal
numbering inconsistency.

**Decision needed:** does the manuscript collapse `Headers` into `Lib`
(as the table currently does) or surface it as `Ar.X`?

| ID   | Manuscript name | Code (`artifact_kind`) | §2 use         | §3 use          | Status      |
| ---- | --------------- | ---------------------- | -------------- | --------------- | ----------- |
| Ar.0 | native_source   | `Source`               | L189, L252     | (TBD)           | drift       |
| Ar.1 | native_lib      | `Lib`                  | L222           | source-lib pair | drift       |
| Ar.2 | binding_source  | (part of `Binding L`)  | L222           | (TBD)           | drift       |
| Ar.3 | binding_lib     | (part of `Binding L`)  | L282           | (TBD)           | drift       |
| —    | (headers)       | `Headers`              | not in manu    | not in manu     | drift       |
| —    | app             | `App`                  | not enumerated | not enumerated  | placeholder |

## 2. Surfaces (`Sf.X`)

**Flow.** `canary_compat.ml: inspect_input` + manuscript catalogue
──► SSOT §2 ──► draft.md §3; `inspect_*.py` JSON `kind` field.
**Co-providers.** code's 10 `inspect_input` variants and manuscript's
5 Sf roles are parallel hand-curated lists; the aggregation mapping
must be kept here.
**Principle.** Sf.X numbering should align with Ar.X numbering
(Sf.k is the inspectable face of Ar.k). Current draft does not
fully honour this — see Open Reconciliation §7.

Status: **drift** — manuscript 5 surfaces; code 10 inspect_input
variants (one surface aggregates several inspect kinds).

| ID   | Manuscript name  | Aggregates code `inspect_input`                  | Status |
| ---- | ---------------- | ------------------------------------------------ | ------ |
| Sf.1 | native_source    | `Typed_header`                                   | drift  |
| Sf.2 | native_lib       | `Native_lib`, `Versioned_exports`, `Abi_surface` | drift  |
| Sf.3 | binding_source   | `Ocaml_mli`, `Typed_binding_user`                | drift  |
| Sf.4 | binding_lib      | `C_stub`, `Typed_binding_stub`, `Versioned_req`  | drift  |
| Sf.5 | (Python/runtime) | `Python_attrs`                                   | drift  |

**Roadmap / parked**

- `runtime_trace` — demoted out of surface catalogue (a runtime
  observation, not a static surface). Sn.6 in snippets kept.

## 3. Agreements (`Ag.X`)

**Flow.** `canary_compat.ml: contract_id` (C1..C8) + manuscript §3
catalogue (Ag.1..Ag.7) ──► SSOT §3 ──► draft.md §3 prose;
`Expect_compat_failure` predicate derivation.
**Co-providers.** code's `contract_id` and manuscript's `Ag.X` are
parallel hand-curated lists. C8 (API-faithfulness) currently has
no manuscript Ag.

Status: **drift** — manuscript Ag.1..Ag.7 (7 agreements); code
`contract_id = C1..C8` (8 contracts).

**Decision needed:** add `Ag.8` to the manuscript or fold C8 into an
existing Ag.

| ID   | Manuscript name  | Code `contract_id`          | OCaml fn (`canary_compat.ml`) | Status |
| ---- | ---------------- | --------------------------- | ----------------------------- | ------ |
| Ag.1 | Symbol           | C1 (`cmp_symbol`)           | `check_c_compat`              | drift  |
| Ag.2 | API-completeness | C2                          | (see compat.ml)               | drift  |
| Ag.3 | Behavior         | C3 (`cmp_behavior`)         | runtime probe                 | drift  |
| Ag.4 | ABI              | C4 (`cmp_abi`)              | `check_abi`                   | drift  |
| Ag.5 | SymbolVersion    | C5 (`cmp_sym_version`)      | `check_sym_version`           | drift  |
| Ag.6 | Type             | C6 (`cmp_type`)             | `check_type`                  | drift  |
| Ag.7 | API-repacking    | C7 (`cmp_api_repack`)       | `check_api_repack`            | drift  |
| —    | API-faithfulness | C8 (`cmp_api_faithfulness`) | `check_api_faithfulness`      | drift  |

**§2 vs §3 collision.** §2 currently uses `Ag.0..Ag.7` (eight
stage-introduced agreements, numbered from 0). §3 uses `Ag.1..Ag.7`
(the catalogue, numbered from 1). Reconciliation: prefer §3's
catalogue numbering; rewrite §2 references to point at the §3 IDs.

## 4. Good Scenarios (`Sc.X`)

**Flow.** manuscript Sc.1..Sc.6 (hand-curated) + canary action
graph aggregation ──► SSOT §4 ──► draft.md §2 + §4 prose.
**Co-providers.** the six aggregate stages and the 15-pattern
action-path table (from `canary paths-md`) describe the same
space at different granularity. Each Sc.N corresponds to a
subgraph of the action catalogue (§6.5).

Status: **stable for manuscript**. Used in draft.md L349 table.

| ID   | Scenario name            | Stage                  | Inputs → Outputs                                  |
| ---- | ------------------------ | ---------------------- | ------------------------------------------------- |
| Sc.1 | `build_native_lib`       | Upstream               | Ar.0 (native_source) → Ar.1 (native_lib)          |
| Sc.2 | `build_binding`          | Binding creation       | Ar.1 + Ar.2 (binding_source) → Ar.3 (binding_lib) |
| Sc.3 | `build_app_with_binding` | Binding use (direct)   | Ar.3 + app_src → app_binary                       |
| Sc.4 | `run_app_with_binding`   | Binding use (direct)   | app_binary + Ar.1 (runtime) → run_output          |
| Sc.5 | `build_app_helper`       | Binding use (indirect) | Ar.3 + helper_src + app_src → helper + app_binary |
| Sc.6 | `run_app_helper`         | Binding use (indirect) | app_binary + helper + Ar.1 (runtime) → run_output |

**Code correspondence.** The 6 good scenarios aggregate over the
finer action graph (§6.5): `Fetch/Build_lib/Build_binding/Build_app/Probe`
crossed with artifact kinds. The 15-pattern action-path table
(`canary paths`) is the full enumeration at a finer grain.
Project-agnostic patterns live at `Canary_scenario.good_scenarios`;
tiny's instances (same ids, tiny-specific descriptions) at
`Canary_tiny_scenario.tiny_good_scenarios`.

### 4.1 Concrete good scenarios

Each `Sc.N × language` admits **concrete good scenarios** —
specific workspaces (tiny today; future project-N tomorrow)
that instantiate the abstract Sc.N pattern end-to-end. A
concrete scenario is **good** (all steps `Expect_success`,
scenario carries `origin = None`) or **bad** (one or more
steps expected to fail; scenario carries `origin = Some _`
naming the cause). §5 enumerates the bad ones; the good ones
live here.

Tiny's concrete good scenarios:

| Scenario id  | Exercises               | Name                     | What it does                                                 |
| ------------ | ----------------------- | ------------------------ | ------------------------------------------------------------ |
| `Sc.4.OCaml` | Sc.3.OCaml + Sc.4.OCaml | `app_over_binding_ocaml` | App links against binding, uses it directly; build + run     |
| `Sc.6.OCaml` | Sc.5.OCaml + Sc.6.OCaml | `app_over_helper_ocaml`  | App uses a helper library that uses the binding; build + run |

Naming convention: the id **is** the run-stage Sc.N (naming
after the most-downstream stage exercised — the run
implicitly includes its build prereq). A concrete good
scenario reuses the Sc.N id of the pattern it instantiates;
the (id, origin) joint distinguishes the concrete good
scenario from the abstract Sc.N pattern of §4 (which is a
description, not a runnable).

These concrete good scenarios used to be catalogued as `Pc.N`
(positive coverage), then briefly as "unmutated witnesses";
those labels are retired. They're just good scenarios (search
for "Pc.1"/"Pc.2" or "unmutated" in git history).

Running a concrete good scenario is what `probe_app_<lang>`
does under the hood — build the app, run it, expect success.
The `probe_` prefix reads narrow for the app step (an app
isn't observed from the outside; it's *used*), but the
semantic is already the right one: the app step exercises the
artifact as its end-user would.

### 4.2 Scenario enumeration — one abstract algorithm

There is **one** scenario enumeration. It is *abstract*: applied to a
project it yields that project's **concrete scenarios** — the set the
project admits. tiny is not a special case — tiny's inputs give tiny's
concrete scenarios; a general project's inputs give its variants. One
abstract algorithm, different inputs; the two listings that look separate
are the same algorithm under two configs (below).

**The scenario space is a product.** The abstract core is the artifact
pipeline (Ar.0 native_source → Ar.1 native_lib → Ar.3 binding_lib → app;
§1). The enumeration ranges over the **artifacts** (`Canary_basic.artifact_kind`
— source, lib, each binding; and Headers/App, usually not independently
provided). A **scenario/variant** assigns every artifact its coordinates,
so a scenario is one point *across* all the artifacts — a different level
from a single artifact. Each artifact carries several **independent axes**:

| axis | values | note |
|---|---|---|
| **provision** (which store) | `Absent` · from a PM · `Built` (from source) · `Vendored` | a supplied copy at a path — local *or* remote — not built here and not PM-resolved |
| **version** | stable · dev · a tag | which upstream version (§4.2.2) |
| **mechanism** (bindings) | static (cstubs/cext) · dynamic (ctypes/dynlink) | §4.2.1(b) |
| **mutation** (defect) | `None` · `symbol_missing` · `abi_mismatch` · … (§5.3) | the injected fault |

A project may carry further **structural axes** — e.g. *app wiring* (link
the app directly vs. through a helper library, tiny's Sc.4 vs Sc.6). These
are not outside the algorithm; they are simply more axes, handled by the
same mechanism below. The complete space is the product of every axis over
every artifact — exhaustive, and verbose.

**A config tames the product by setting a *level* per axis.** Each axis
gets one of:

- **Free** — collapse to a single representative value.
- **Subset [..]** — a curated list (the *interesting* values).
- **Full** — every value.

A **config** assigns one level to each axis; instantiating the abstract
algorithm with a config gives a project's concrete scenarios. The
algorithm is **product-then-filter**: the config's levels form the
product, then constraints prune it (a binding needs a lib; a lib `Built`
from source needs the source; a mutation applies only to a *provided*
artifact). Those constraints are the **artifact dependency graph** — the
non-cartesian skeleton the cartesian axes decorate; see §4.2.4.

**Every use is one config** — this is what unifies tiny and a real
project: not two enumerations, but one algorithm under two configs.

| use | provision | version | mechanism | mutation |
|---|---|---|---|---|
| **tiny — defect coverage** | Free (all `Built`) | Free | Subset (cext + ctypes — both must be tooling-tested) | **Full** (all defects) |
| **a real project — variants** | Subset (its PMs + source) | Subset (stable, dev) | Free | Free (`None`) |
| **model completeness** | Free (one PM stands in) | Free | Free | Full (all defect patterns) |
| **PM-coverage testing** | **Full/Subset** (every interesting PM) | Free | Free | Free |

tiny pins provision and walks mutation; a real project pins mutation and
walks provision. The levels are independent per axis — Full on mutation
with Free on provision (tiny), or Subset on provision with Free on
mutation (a real project's variants). The two extremes have names worth
keeping: **all-Free** (one representative per axis — the smallest set that
still exercises every scenario *pattern*) and **all-Full** (the complete
product).

Correspondences already in place: `origin` (the project dimension,
[`new_project.md` §0](new_project.md)) **is** the provision coordinate; the
variant list **is** the provision enumeration; the mutation vocabulary
(§5.3) **is** the other axis; and provision decides which action-graph
actions run (§6.5 — `Built` ⇒ `Build_lib`, `Fetched` ⇒ `Fetch Lib`).

The provision axis spans the **store lifecycle** — an artifact moves
source → `Build` (build-tree) → `Publish` (PM) → `Fetch` (local) →
`Probe` (§6.5 actions across `Canary_store.location`). So `Publish` and
`Fetch` are transitions **in** the enumeration core; a project covers the
*segment* its provision-path uses and the rest is **symmetric N/A** —
tiny (build + probe locally) shows N/A on `Publish`/`Fetch` exactly as a
`Fetched` general project shows N/A on `Build`. The round-trip
(`Build → Publish → Fetch`) is the "canary builds and publishes its own
conf" case, the only one that covers `Publish`. No project is
special-cased. See [`scenario_coverage.md`](scenario_coverage.md) §2.

Every axis of a project's concrete scenarios is one the algorithm can
range or pin; nothing a project needs sits "outside" it — a coordinate the
algorithm doesn't yet range (a version, an app wiring) is a *missing axis
to add*, not a reason to keep a second, hand-written enumeration. The
target is a single algorithm that, given a project's available values per
axis and a config, produces the concrete scenarios that today's
hand-written specs list by hand.

> Implementation state (algorithm module, which axes are wired, what each
> `canary` subcommand renders today) lives in
> [`../status.md`](../status.md), not here — this section is the model.

### 4.2.1 Two refinements: abstract stages, and binding discipline

Two places where the naive model is too coarse. Both are properties of the
abstract algorithm, not of any one project.

**(a) A pipeline stage is *abstract*; its *realizations* are the concrete
actions, chosen by provision.** One abstract stage is realized differently
by the build vs the PM provision:

| abstract stage | build realization (`Built`) | fetch realization (from a PM) |
|---|---|---|
| provide source | `Fetch Source` / local | — |
| provide lib | `Build_lib` | `Fetch Lib` |
| provide binding | `Build_binding` | `Fetch Binding` |
| run app | `Probe_app` | `Probe_binding` (the example *is* the app) |

A project covers an abstract stage via **whichever realization its
provision uses** — so tiny (`Probe_app`, `Build_lib`) and a PM-provisioned
project (`Probe_binding`, `Fetch Lib`) both map to *run app* / *provide
lib* instead of missing each other. Keying coverage off abstract stages
(not concrete actions) is what lets one catalogue place every project, and
makes an unused segment of the pipeline show as a visible gap rather than a
spurious mismatch.

**(b) A binding's identity is `(language × discipline)`.** The axis is the
binding's **discipline** — *not* the open set of mechanism names — because
the discipline is what changes the pipeline shape (whether a *provide
binding* build stage exists, and where the surface-check fires). A
**mechanism** is the finer descriptive label under a discipline:

| discipline | binds by | *provide binding* build stage | check fires | mechanisms |
|---|---|---|---|---|
| **static (C-ABI)** | compiling a stub linked to the lib | a real build (needs headers + link) | build (link) *and* probe | cstubs (OCaml), cext (Python) |
| **dynamic (FFI)** | `dlopen`ing the lib at runtime | none (pure source) | probe only (resolve by name) | ctypes/cffi (Python), Dynlink (OCaml) |

The two disciplines line up across languages — the payoff of keying on
discipline, not name: OCaml `Dynlink`/utop is the *same value* as Python
`ctypes` (both dlopen late, both break on loader-path / symbol resolution),
so it needs no per-language machinery. A dynamic binding has no *provide
binding* build stage, so that stage shows as a gap and *run app* carries
the whole check — which (a) already renders. So `binding(Python, static)`
(cext) and `binding(Python, dynamic)` (ctypes) are **distinct artifacts**
that build and probe differently.

Together these make two axes of §4.2 faithful: the **provision** axis
ranges over abstract stages × realizations, and a binding's **identity**
carries `(language × discipline)` — so the mechanism axis is a real axis,
not a flattened assumption.

### 4.2.2 The version axis

Version is a **per-artifact tag**, and one of the §4.2 axes.

**Pre-condition — same version ⇒ identical artifact.** For source-format
artifacts this is exact; for binary artifacts it holds *given the same
tooling*. This reproducibility belief makes version a sufficient **identity
key**: canary need not re-verify byte-identity — it trusts version (+
tooling) as the artifact's identity. (A checking pre-condition; it lives
with the compat model, not the enumeration.)

**Source-primary tagging.** A built artifact's version follows its source
(`Built ⇒ version = source.version`). Its dynamically-linked dependencies
are *separate artifacts / axes* — combinatorially checked in their own
right, but **not part of this artifact's identity**: a dep is respected as
a dependency, not used to tag the lib.

**Each version is an id.** A `Dev` version is identified by its commit
**hash**; a `Stable` version by its **tag / release name**. Attaching a
version to an artifact means recording that id on the artifact; enumerating
each artifact at **two** versions (one `Dev`, one `Stable`) is already
adequate coverage.

**A `level` axis, reusing `Canary_basic.version` (`Dev | Stable`).** Like
provision, version takes a per-axis level:

- `Free` → one representative (`single_version`)
- `Subset` → `two_versions = [Dev; Stable]` — the meaningful test set
- `Full` → the project spec's declared versions

**Per-artifact ⇒ mismatch is the interesting result.** Because each
artifact carries its own version, a cross-artifact version *mismatch* — a
binding built against lib `v1` but resolved against lib `v2` — is
representable. That is exactly the z3/llvm dev-vs-stable demo, now a
version-axis instance rather than a hand-written variant. Source-primary
prunes incoherent assignments, so the surviving differences are the real
mismatches (e.g. a fetched binding at one version over a built lib at
another).

**Package version ≠ artifact version.** The axis is the *artifact's*
version. A package (a `provision`) delivers artifacts, each carrying its
own version — every artifact can be packaged, so the tractable question is
"what version is the artifact *content* inside this package," not "what is
the package's version." `provision` answers *which package/store*;
`version` answers *which artifact-version*; the package→artifact-version
mapping is a provision-side resolution detail, and one package may bundle
artifacts at differing versions (e.g. a `z3-dev` package's header+lib at
one version, a prebuilt binding built against another).

**A *co-package* is spec-authoring, not enumeration.** A **co-package** is
one package that supplies several artifacts at once (e.g. `z3-dev` ships
both a header and a lib). That is captured where a project lists an
artifact's **`components`** (the api surface), not by any special concept
in the algorithm: the enumeration treats each artifact's provision
independently — "this package provides the lib" and, separately, "this
package provides the header"; their sharing a package is incidental. *(A
co-**package** — one package, many artifacts — is unrelated to ssot's
"**Co-providers**" blocks, which are a documentation convention naming the
co-defining sources of an SSOT ID, e.g. code vs manuscript vs tiny.)*

### 4.2.3 The artifact & axis model — decisions

Decisions from the 2026-07-30 review, refining §4.2's axes. (Most are not
yet wired — see [`status.md`](../status.md) for the code state.)

- **A binding carries its mechanism; a lib may expose several bindings.**
  The binding artifact's identity is `(language × mechanism)` (§4.2.1b).
  A single lib can expose *multiple* bindings at once — a Python `cext`
  binding and a Python `ctypes` binding are two distinct artifacts. A
  language offers several mechanisms, not all implemented for a given
  project; **tiny-factory supports them all**. So the artifact set can hold
  several `Binding` entries, each with its own mechanism.

- **App is a first-class artifact (0 / 1 / many), and its wiring is
  enumerated.** Like Lib/Headers, a project has zero, one, or several apps.
  An app that links the library **directly** and an app that goes **via a
  helper** are *both* enumerated — distinct app artifacts. So App carries a
  wiring/identity, paralleling `Binding of lang`.

- **Provision carries PM and distro.** `Fetched` names *which* PM
  (apt / opam / pip / brew), and provision spans a **distro** dimension
  (WSL / macOS / CI images). The enumeration ranges over one distro locally
  and several on GH CI — the provision axis's level picks one or many
  `(PM × distro)` combinations.

- **Headers are a flexible artifact, not always derived.** A project may
  ship a **standalone** header, a **package** may co-provide it (a
  co-package), or the header may be a **build result** — produced by
  compiling the source (`Build_headers`) and fetched from there. So Headers
  has its own provision, including `Built`.

**Meta note — mutation & result (still being refined).** Mutating a lib to
drop a symbol does **not** create a new scenario: it is the *same* scenario
with a **bad artifact**, whose badness surfaces at a later stage (the
result / oracle). So **tiny-factory is a *meta-scenario computation*** over
the structural scenario space (provision × version × mechanism × app), not
a generator of new scenarios; mutation + result sit *over* that space
rather than expanding it as a peer axis.

### 4.2.4 The scenario space = a dependency graph × per-node cartesian

The scenario space has **two parts**, and keeping them separate is the
principle the enumeration should follow.

**(1) A dependency graph — the non-cartesian structure.** Artifacts form a
DAG:

- a **lib** (binary) depends on the **source** (it is built from it);
- a **header** is either **static** — part of the source (a source
  sub-artifact) — or **built** — a build-result of the source, so it
  behaves like a lib (depends on the source via a build);
- a **binding** depends on the **lib**;
- an **app** depends on the **binding** in its language.

This is the artifact dependency graph — exactly what canary's action graph
builds dynamically (§6.5). Its **edges *are* the enumeration's filter**:
`assignment_ok` (a provided binding needs its lib, an app needs a binding, a
`Built` lib needs the source) *is* this graph.

**(2) The cartesian axes apply per node — and version applies per *edge*.**
Each artifact carries provision × mechanism × mutation. **Version, though,
is per dependency *edge*, not per node**, and edges are typed **create
(build) vs use (run)**: an artifact is *built at* a version, so several
instances co-exist (source@dev/@stable; lib@dev/@stable), and **each
consumer edge independently picks which version of the dependency it
consumes**, build and run separately. So:

- an OCaml binding built against a **header** and a **lib** ranges
  header-version × lib-version = 4 (with two versions) — the off-diagonal
  points are compile-time **mismatches**;
- an app **built** with a lib and **run** with a lib ranges
  build-lib-version × run-lib-version = 4 — the off-diagonal is the classic
  **deploy mismatch** (a package developer builds a lib; a user runs it on a
  different host at a different version).

These mismatch points are **canary's whole purpose** (cross-version compat),
so they are **first-class scenarios**, not "bad" ones. Collapsing version to
one-per-scenario discards exactly the space canary checks. The full space:

```
scenario space = (∏ over graph EDGES of the consumed version, create/use apart,
                  × per-node provision/mechanism/mutation)   filtered by  the graph
```

So the count is a **product over consumption edges** (binding = header×lib,
app = build-lib×run-lib, …), *far* larger than "2 global versions" — that
edge-product is the mismatch space. What remains after the graph filter is a
*choice* among graph-valid scenarios — the **config-level taming** (the
Free/Subset/Full levels, §4.2). *(Earlier note: the raw cartesian over
per-artifact **presence** — 2048 → 58 — was the wrong axis; a project ships
its whole declared set, presence is not a choice. The real breadth is the
per-edge version product above.)*

**Reality — an artifact *instance* is one concrete thing (its `placement`);
the *group* is the choice space.** An artifact **instance** is a single
concrete thing: one `(provision/location × version)` with its metadata —
exactly the per-artifact `placement`. The **cartesian choices** for one
artifact (which version, which store **location** — build tree / staged
install / PM site) are carried by its **artifact group**; the enumeration
picks one concrete instance from each group.

- **build tree** — built and left at the build path;
- **staged install** — installed to a prefix (a *customized* prefix,
  **not** the global system path — especially for cmake, to avoid depending
  on / polluting the global system);
- **PM site** — published.

These are the store-lifecycle locations (`Canary_store.location` =
`Build_tree | Staged | Pm`; §4.2 source→Build→Publish→Fetch), so **provision
folds into location** (build tree ⇒ "built", PM ⇒ "fetched", staged ⇒
"installed"). A consumption edge consumes a specific instance, and different
edges may consume **different instances** of the same group — an app built
against `lib@1.0` (build tree) and run against `lib@2.0` (PM) = the deploy
mismatch. **Using an instance at a different location needs a different
command** — the concern of the per-project `runner_spec` (the old one
covered this). *(Open: how a scenario represents an artifact consumed at two
instances — build vs run — while keeping one `placement` per instance;
likely the graph edge carries the consumed instance.)*

**Header flavor — payload, not a new kind.** A header's flavor (static vs
built) changes its position in the graph (part-of-source vs
built-from-source), so it is a **payload on the `Headers` artifact** —
`Headers of (static | built)` — the same shape as `Binding of (lang ×
mechanism)` (§4.2.1b) and modeled the same way (an `artifact_ext` payload,
clearer than separate variants; the two are convertible).

**Principle.** The ideal enumeration is *dependency graph (skeleton) +
per-node cartesian (decoration), the graph filtering the product*. The
current implementations should follow this in spirit — canary's action
graph *is* the dependency graph; z3/llvm's hand-written variants are
particular graph-valid points that the algorithm should instead derive.

## 5. Bad Scenarios (`Bs.N`; `snake_case` names)

**Flow.** `dune exec canary_main -- tiny-scenarios list` ──►
SSOT §5.1 ──► draft.md L382 table, tiny variant matrix.
**Co-providers.** OCaml (`Canary_tiny_scenario.scenario_specs`) is the
sole producer as of Phase E; the legacy Python harness
(`scenarios.py`) was archived under
[`../_legacy_code/tiny_python_harness/`](../_legacy_code/tiny_python_harness/).
**Status.** stable — 13 Bs rows here (all Mutation-origin) +
2 concrete good scenarios in §4.1 = 15 concrete scenarios in
`scenario_specs`.

**Roadmap rows** (not in code yet):

- `pkg_*` — packaging scenarios; placeholder for opam/pip/apt
  repackaging mismatches. Tracked as §7 Principle 4 gap.

### 5.1 Per-scenario detail

Columns split into two:
- **Physical facts** (constructed setup): `ID`, `Good scenario`,
  `Mutation`.
- **Secondary / derived**: `Name` (= agreement label — what's
  *expected* in the good scenario, named after what gets
  violated), `Manifests` (where the failure first surfaces
  today), `Detector today` (which contract check catches it, or
  gap).

`Bs.N` = **B**ad **s**cenario number N. IDs are stable — new
scenarios append; renames don't renumber.

Concrete good scenarios (`app_over_binding_ocaml`,
`app_over_helper_ocaml`) are catalogued under §4.1, not here.
§5 enumerates only bad scenarios; a scenario with
`origin = None` belongs under the Sc.N it instantiates.

Bad scenarios can arise from several origins (all typed via
[`Canary_scenario.origin`](../../src/canary/action/canary_scenario.ml)):

- **`Mutation`** — patch the source or binary of one artifact
  in the chain. All of tiny's 13 Bs entries today.
- **`Version_mismatch`** — pair well-formed artifacts at
  incompatible versions. Currently modeled ad-hoc in the
  llvm/z3 stable variants (`llvm.19-shared` binding + LLVM 21
  example; z3-solver pip wheel + dev example). The
  constructor is reserved in the `origin` variant but not
  wired through canary's factory.
- **`Packaging`** — wrong files in an opam/pip/apt payload.
  Roadmap row `pkg_*`; no code yet.

Ordering convention: rows grouped by Good scenario, then by
mutation similarity. Renumbering when scenarios reorder is
acceptable while §5.1 is still churning; once stable, IDs freeze.

**Code correspondence.** The 13 Bs rows below plus the 2
concrete good scenarios from §4.1 (= **15 concrete scenarios**
covering the tiny Sc.N patterns) live at
`Canary_tiny_scenario.scenario_specs`. Each carries a
`belongs_to` field naming the Good scenario(s) it relates to
— for Bs.N this is the `mutated_at` Sc.N; for a concrete good
scenario this is the Sc.N(s) it exercises.
`Canary_tiny_scenario.all_scenarios` unions the 8
language-split tiny good scenarios (Sc.1 shared + 5 .OCaml +
2 .Python) + 15 instantiations = **23 scenarios** as the
reference list for the `derive_entries` experiment (§9.3
backlog).

| ID    | Good scenario | Mutation                          | Name                     | Manifests                         | Detector today                                           |
| ----- | ------------- | --------------------------------- | ------------------------ | --------------------------------- | -------------------------------------------------------- |
| Bs.1  | Sc.1          | native_source (c/src)             | `symbol_missing`         | Sc.4 (probe fail)                 | c1 cmp_symbol                                            |
| Bs.2  | Sc.1          | native_source (c/{include,src})   | `header_arity_bump`      | Sc.2 (binding build fail)         | c6 cmp_type                                              |
| Bs.3  | Sc.1          | native_source (c/tiny.map)        | `symbol_version_floor`   | Sc.4 (dyld load fail)             | c5 cmp_sym_version                                       |
| Bs.4  | Sc.1          | native_lib (binary surgery)       | `abi_soname_bump`        | Sc.4 (dyld load fail)             | c4 cmp_abi                                               |
| Bs.5  | Sc.1          | native_source (c/src signature)   | `type_wrong`             | Sc.4 (probe fail)                 | (weak — c6 wants clang AST)                              |
| Bs.6  | Sc.1          | native_source (c adds fn)         | `api_faithful`           | — (nothing detects)               | **gap** — c8 not wired                                   |
| Bs.7  | Sc.1          | behavior (native src semantics)   | `behavior_silent`        | Sc.4 (probe fail)                 | c3 cmp_behavior                                          |
| Bs.8  | Sc.2          | binding_source (ocaml user)       | `api_repack`             | Sc.4 (probe fail)                 | c3 cmp_behavior via probe                                |
| Bs.9  | Sc.2          | binding_source (ocaml mli)        | `api_complete`           | Sc.3 (app build fail)             | c2 cmp_api_completeness                                  |
| Bs.10 | Sc.2          | binding_source (ocaml stub)       | `symbol_orphan`          | Sc.2 (link fail on strict linker) | c1 cmp_symbol                                            |
| Bs.11 | Sc.2          | binding_source (python)           | `api_repack_python`      | Sc.4 (probe fail)                 | c3 cmp_behavior via probe                                |
| Bs.12 | Sc.2          | binding_source (python)           | `api_complete_python`    | Sc.4 (probe fail)                 | c2 cmp_api_completeness                                  |
| Bs.13 | Sc.2          | binding_source (ocaml stub layer) | `api_repack_stub_orphan` | — (probe passes)                  | **gap** — c7 static-only (bo1↔bo4 comparison, not probe) |

**Observations.**

1. **Sc.4 (runtime probe) is the dominant manifestation stage
   (8/13).** Static comparators catch things earlier (Sc.2/Sc.3
   build) when they exist; otherwise badness surfaces at runtime.
2. **Sc.3–Sc.6 have zero bad scenarios in the current
   catalogue.** Sc.1 and Sc.2 hold everything — the stages where
   sources are authored. Sc.3+ are use-and-run stages; badness
   propagates *through* them but the *construction*
   (mutation) sits at Sc.1/Sc.2. Whether Sc.3–Sc.6 admit
   their own bad scenarios (assembly-time or run-time patches) is
   an open question.
3. **Two detection gaps.** Bs.6 `api_faithful` (c8 not wired) and
   Bs.13 `api_repack_stub_orphan` (c7 static-only, not probe).
   Ideally the `derive_entries` experiment (§9.3 backlog) finds
   these automatically as "no-detector" cells.
4. **The two columns `Good scenario` and `Manifests` are
   perpendicular perspectives on each row.** `Good scenario`
   locates *where the construction happens* (mutation
   perspective); `Manifests` locates *where the failure surfaces
   downstream* (manifestation perspective). The latter recovers
   the earlier "dual-view" idea (§7 Principle 3). Their alignment
   across rows is the invariant §7 Principle 3 wants — checkable
   once the agreement/checker registry is in place.

### 5.2 Patterns vs instances

Both good scenarios (§4) and bad scenarios (§5.1) here are
**patterns** — abstract descriptions of a construction. A
concrete project (tiny today, or a future z3/llvm equivalent)
provides the **instances**: the actual mutation files,
sandbox paths, build commands, expected outcomes.

The code split reflects this:

- `Canary_scenario.scenario` — the pattern (project-agnostic).
- `Canary_tiny_scenario.entry` — a tiny instance (concrete files
  + expected outcomes for tiny).

A same-shape recipe for another project would live in a
`canary_<project>_scenario.ml` file and produce
`Canary_scenario.scenario` patterns paired with a
project-specific recipe.

**Synthesis path (§7.2 Phase 3, 2026-07-20).** For tiny, a
derived cell (Good × artifact × applicable_kind) can now be
turned into a concrete instance automatically via
[`Canary_tiny_scenario.recipe_of_derived_cell`](../../src/canary/projects/canary_tiny_scenario.ml)
— given a derived scenario, returns a `tiny_recipe option`
built from the parametric mutation vocabulary of §5.3.
Cells whose (target, kind) has an implemented primitive
synthesize; cells whose primitive is missing (§5.3's
"Missing on purpose") stay [None] — the empty cell stays
visibly empty. After §7.2 Phase 4 (2026-07-20)
`all_scenario_specs = 15 hand + 6 derived = 21` and
coverage stands at 12 of 20 cells filled after §7.1's
`Drop_python_attr` primitive landed (2026-07-21); 8 remain
awaiting App-level primitives + c4 wiring for OCaml. See
[`derived_vs_hardcoded.md`](derived_vs_hardcoded.md) for
the full field-by-field derived-vs-hand map, and
[`tiny.md §7.1`](tiny.md#71-fill-the-9-remaining-empty-derived-cells)
for the blocker-primitive breakdown.

### 5.3 Mutation shapes (parametric vocabulary)

**Flow.** [`Canary_artifact_mutation`](../../src/canary/tool/canary_artifact_mutation.ml)
 ──► per-artifact submodules (Source / Native / Binding) each
own a `type t` enumerating that artifact's mutations, plus
matching constructor helpers and an `apply_cmds` shell-command
builder. Top-level `type mutation` is a thin union
(`Of_source | Of_native | Of_binding | Patch`) for callers
that need a homogeneous type. Shipped §7.2 Phase 1
(2026-07-20).

**Framing.** "A mutation is just an artifact-flavored fact" —
per-artifact types make that framing structural, mirroring the
inspection layer symmetry (canary_artifact_source / _native /
_lang each own their artifact's inspect wrappers).

Currently implemented (with existing-patch parity where a
tiny reference case exists):

| Module    | Variant                                   | Reference patch              |
| --------- | ----------------------------------------- | ---------------------------- |
| `Source`  | `Rename_c_symbol { file; from_; to_ }`    | `symbol_missing.patch`       |
| `Source`  | `Rename_version_tag { file; from_; to_ }` | `symbol_version_floor.patch` |
| `Native`  | `Soname_bump { from_so; to_so }`          | `abi_soname_bump` (Bs.4)     |
| `Binding` | `Drop_ocaml_val { file; name }`           | `api_complete.patch`         |

Freeform edits (add-declaration, coordinated multi-file
changes, in-place body rewrites) stay as top-level
`Patch { patch_file }` — the escape hatch. Of tiny's 13 bad
scenarios: 4 have parametric constructors (rename + drop
shapes); 9 stay as `Patch` (adds + body/signature rewrites).

**Missing on purpose** (per user 2026-07-20 principle
"per-artifact ops make missing-ness visible"):

- `Source.Drop_c_symbol` — remove a C function definition
  (multi-line, needs brace-matching). No current tiny cell
  needs it; add when one does.

**Recently added:**

- `Binding.Drop_python_attr` — sed-range primitive that
  deletes from `^def <name>(` through the next blank line.
  Byte-parity with the existing
  `api_complete_python.patch` verified in
  `mutation_regression_tests`. Adequate for tiny; would
  need an [ast]-based upgrade for projects with decorators
  / nested defs / non-blank-line-separated defs. Landed
  §7.1 2026-07-21.

**Tests** (in
[`canary_artifact_test.ml`](../../src/canary/test/canary_artifact_test.ml),
`mutation_pure_tests` / `mutation_shell_apply_tests` /
`mutation_regression_tests`):

- Pure: constructor round-trip + apply_cmds shape.
- Shell apply: run the emitted commands on a scratch sandbox,
  grep for the mutation's mark.
- Regression anchor: apply the parametric constructor AND the
  hand-authored `.patch` file to two clean tiny sandboxes,
  assert `diff -r` reports empty. Confirms byte-identical
  parity with the existing patch for the 4 mapped variants.

### 5.4 Contract bindings (expectation lowering vocabulary)

**Motivation.** A scenario declares which contracts its
mutation `violates` (e.g. Bs.4 abi_soname_bump violates
c4). Turning that high-level fact into per-step
expectations for the runner used to happen inside
`expectation_of_entry` via ad-hoc `match rule with`
branches — every new contract-firing-site or lang
extension added another branch. §7.1 (2026-07-21) lifted
the switch table into typed data, keyed on **contract
bindings**.

**Types** (in
[`canary_scenario.ml`](../../src/canary/action/canary_scenario.ml)):

```ocaml
type firing_site =
  | At_build_binding of Canary_lang.lang
  | At_probe_binding of Canary_lang.lang
  | At_build_app of Canary_lang.lang
  | At_probe_app of Canary_lang.lang

type loc_filter =              (* Task 2 Phase B, 2026-07-21 *)
  | Any
  | At_pm_lang of Canary_lang.lang   (* fires only at that lang's PM location *)
  | Not_pm_lang of Canary_lang.lang  (* fires everywhere except that lang's PM *)
  | Only_if of (Canary_store.location option -> bool)

type expectation_source =
  | From_artifact of {
      inputs : inspect_input list;
      version_info : version_info option;    (* Task 2 Phase C, 2026-07-21 *)
    }
  | From_behavior_grep of {
      contains_any : string list;
      version_info : version_info option;
    }
  | Placeholder of { reason : string }

type firing = {                (* record shape, not 3-tuple, for future fields *)
  site : firing_site;
  loc_filter : loc_filter;
  source : expectation_source;
}

type contract_binding = {
  contract : contract_id;
  lang     : Canary_lang.lang;
  firings  : firing list;
}
```

Two-category framing: `From_artifact` is *static-sourced,
dynamic-checked* (read cached inspect JSONs → compute
predicted substrings via the contract's predict closure →
grep probe.log). `From_behavior_grep` is *dynamic-only*
(assert log substring). `Placeholder` is *shape committed,
content TBD* — emits `Expect_success` at runtime, but the
binding is registered so `binding_has_live_firing` and the
startup validator can see it. Same "missing-ness visible"
principle as §5.3's Missing-on-purpose mutation shapes.

`loc_filter` (Phase B) lets one binding row express "fires
at OCaml probe but not pip-python probe" without duplicating
the whole row — llvm's inline expectation used a nested
match on `(rule, loc)`; the same behaviour comes from
`{ site = At_probe_binding OCaml; loc_filter = Not_pm_lang Python; ... }`.
`version_info` (Phase C) carries the human-readable
provider/consumer strings that today's `Expect_compat_failure`
attaches (`provider_version = "llvm 19"; consumer_requires
= "Opcode.UncondBr"; since = ...`); tiny sets it to `None`
throughout, llvm/z3 populate it.

**Per-project data** — a project supplies its own
bindings table. Tiny's lives in
`canary_tiny_scenario.ml:tiny_contract_bindings`; c1-c7
wired for the relevant langs, c4-OCaml and c8-OCaml as
Placeholder. `expectation_of_entry` becomes a pure lookup
over this table.

**Guard consumer.** `Canary_scenario.binding_has_live_firing
bindings contract lang` returns true iff the (contract,
lang) has at least one non-Placeholder firing. Used by
`recipe_of_derived_cell`'s synthesis guards to decide
whether a mutation targeting a contract will produce a
detectable failure or emit silent Expect_success.

**Startup validator** (in `canary_tiny_scenario.ml`):
every scenario with `manifest = Possible _` must have at
least one live firing across its `violates × langs`.
Catches "you wired a Bs entry expecting failure, but
every contract you listed is Placeholder" — a design gap
that would otherwise silently pass.

**Cross-project uptake** (Task 2 Phases D/E/F,
2026-07-21). z3, llvm, sqlite now all consume the same
lowering (`Canary_scenario.lower_expectation`) over their
own bindings:
- **z3** — one binding (C2 / Python at
  `At_probe_binding Python` with `At_pm_lang Python`
  filter, `parser_context` version_info).
- **llvm** — one binding (C2 / OCaml, `Opcode.UncondBr`
  version_info). Dev variant passes `has_manifest=false`
  to short-circuit the lookup.
- **sqlite** — no bindings (positive-only project).

Every hand-coded `Expect_compat_failure` in project specs
now flows through this pattern; there is no remaining
project-side `match rule with` on step expectation.

## 6. Operational taxonomy — project / scenario / action / step

Canonical reference for terms used across code + writeup. Add a
row here before introducing a term anywhere else.

### 6.1 Term ↔ code

Canonical name-to-code map. If a term isn't in this table, add a
row before using it in code or writeup. Term names are shared with
the writeup — no need for a separate alignment section.

| Level                 | Term                       | Meaning                                                                                                                                                         | Code                                 |
| --------------------- | -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------ |
| **Top**               | **project**                | System under test + coverage config bundle. Owns scenarios + contract bindings.                                                                                 | `Canary_project.project` (`action/`) |
| Middle                | **scenario** ≡ **variant** | One runnable configuration. Named collection of actions + interested artifacts. `Sc.N` (pattern) / `Bs.N` (mutation instance) / dev, stable (llvm/z3 variants). | `Canary_scenario.scenario`           |
| Below-middle          | **runner_spec**            | Runner-facing handoff for one scenario/variant: `expectation` closure + build/probe/inspect commands. One per scenario.                                         | `Canary_step_builder.runner_spec`    |
| Below-middle          | **action_graph**           | Actions-plus-pools schema (declared actions + the artifact-node pools produced by applying them).                                                               | `Canary_action.action_graph`         |
| Low                   | **step**                   | Concrete instantiation of an action: cmdline + env + expectation. Runtime unit consumed by the four backends.                                                   | `Canary_step_model.step`             |
| Low (legacy)          | **step_body**              | Shell-command record used by the retired YAML backend + `canary_toolchain`'s `verify_*_step` helpers (zero live consumers). Kept as placeholder.                | `Canary_basic.step_body`             |
| Action verb           | **action**                 | Operational verb (`Build_lib`, `Probe_binding L`, …). See §6.5 for the catalogue.                                                                               | `Canary_basic.action`                |
| Attribute of action   | **stage**                  | Pipeline phase (Upstream / Binding-creation / Downstream-use). Matches writeup "Stage for …" headings.                                                          | (doc-only)                           |
| Attribute of artifact | **artifact_status**        | Lifecycle state (`Built \| Installed \| Packed \| Fetched`). Complement to `location`.                                                                          | `Canary_store.artifact_status`       |
| Theory                | **rule**                   | *What an action is for* — operational semantics / invariants. Doc-only concept; no code counterpart.                                                            | —                                    |

**Same-word-different-level pitfalls.**

- **project** (top) vs the historical **project_spec** (renamed to
  **runner_spec** 2026-07-21). One `project` produces many
  `runner_spec`s — one per scenario/variant.
- **scenario** ≡ **variant** — same taxonomy position; tiny calls them scenarios
  (22 concrete), z3/llvm call them variants (2-3 each).
  `Canary_run_info.run_project_multi` consumes both under the same
  `variants` list.
- **action** (verb, code) vs **rule** (theory, doc-only) — freed by
  the 2026-07-21 rename. Pre-rename, `rule` was overloaded.
- **stage** (pipeline phase, doc-only) vs **artifact_status**
  (lifecycle state, code) — pre-rename, `stage` was overloaded.
- **step** (runtime, `Canary_step_model`) vs **step_body** (legacy
  shell carrier, `Canary_basic`) — kept apart post-rename.

**Ownership.** Project owns scenarios semantically (each is tied to
what it exercises), but `Canary_project.project` does *not* hold a
`scenarios` field — each project's module keeps concrete ownership.
See [`canary_project.ml`](../../src/canary/action/canary_project.ml)
for the layer + concrete-vs-polymorphic rationale.

**Pattern vs instance.** `Sc.1..Sc.6` patterns live project-agnostic
in `Canary_scenario.good_scenarios`. Concrete scenarios (`Bs.N`,
project variants) live under their owning project's module.

Rename chronicle 2026-07-21 (`project_spec → runner_spec`,
`rule → action`, `action_rule → action_graph`, `action_step → step`,
`step → step_body`, `stage → artifact_status`) captured in
[`worklog_2026_07.md`](../worklog/worklog_2026_07.md).

### 6.5 Action catalogue

Constructors on `Canary_basic.action`. Enumeration + per-action
metadata are two views of one catalogue and live colocated in
[`canary_action.ml`](../../src/canary/action/canary_action.ml)
(colocated 2026-07-22):

- **Enumeration** — `store_actions ~langs` (which actions run
  for a project). Consumed by `derive_steps`, `canary paths`
  (15-pattern renderer), and the four backends.
- **Per-action consumes/produces** — `artifacts_of_action`
  (what artifacts each action touches; prereq → target). Fed
  into `Canary_scenario.related_artifacts_of_actions` (§7.9).
- **Categorical kind** (upstream / native / per-language /
  per-store / downstream) — SSOT-only today; no code type
  named `action_kind` yet.

The single table below is authoritative for all three views:

| Action name     | Constructor                | Kind         | Artifacts (prerequisite → target)      |
| --------------- | -------------------------- | ------------ | -------------------------------------- |
| `configure`     | `Configure`                | upstream     | `[Source]`                             |
| `scan_sources`  | `Scan_sources`             | upstream     | `[Source]`                             |
| `build_headers` | `Build_headers`            | native       | `[Source; Headers]`                    |
| `build_lib`     | `Build_lib`                | native       | `[Source; Lib]`                        |
| `install_lib`   | `Install_lib`              | native       | `[Lib]`                                |
| `build_binding` | `Build_binding of lang`    | per language | `[Lib; Binding L]`                     |
| `build_app`     | `Build_app of app_info`    | downstream   | `[Binding L; App]`                     |
| `probe_lib`     | `Probe_lib`                | native       | `[Lib]`                                |
| `probe_binding` | `Probe_binding of lang`    | per language | `[Binding L; Lib]` (runtime dep last)  |
| `probe_app`     | `Probe_app of app_info`    | downstream   | `[Binding L; Lib; App]`                |
| `fetch_<kind>`  | `Fetch of artifact_kind`   | per store    | `[k]`                                  |
| `pack_<kind>`   | `Publish of artifact_kind` | per store    | `[k]`                                  |

**Order convention**: prerequisite first, target next, runtime
deps trail. Union across a scenario's `actions` follows
first-appearance order (no dedup rearrangement), so §4 Good
scenarios' displayed `A1(...) A2(...) A3(...)` labels stay stable
across releases. Test spec at
[`canary_artifact_test.ml`](../../src/canary/test/canary_artifact_test.ml)
under `scenario_derivation_pure_tests`.

`canary paths` enumerates the 15 structural composition patterns
over these actions (`dune exec src/bin/canary_main.exe -- paths-md`).

#### 6.5.a Known refinement concerns

Anchor for future work on the action layer. Recorded so they
surface when we next touch action-related code.

1. **`action_kind` is doc-only.** The categorical column above
   isn't a typed value in code. Promote to a proper type +
   attach to `artifacts_of_action`'s return if a future backend
   or renderer wants to group actions by kind.
2. **Parametric vs concrete asymmetry.** `store_actions ~langs`
   is *parametric* on language list (expands per-lang variants);
   `artifacts_of_action` is a *concrete* projection
   (pattern-matches on the given action). Unifying around a
   single `action_meta_of : action → { kind; artifacts }` record
   would collapse the two views (colocated but not yet fused).
3. **`scan_sources` placement is project-dependent.** Canonical
   order runs after `Configure`; z3 overrides via
   `scan_sources_after = Some Build_lib` because z3 generates
   binding source at build_lib time. Documented in
   `canary_step_builder.ml`, not here — surface if a second
   project overrides.
4. **App has no `Fetch` / `Publish`.** Contrast with `Binding L`
   which has both. Apps are always built in-tree today (no
   packaged apps). `store_actions` lists `Fetch App` /
   `Publish App` but no store wiring for them.
5. **`action_of_string` is a fragile inverse.** Round-trip parser
   in `canary_basic.ml`; used to deserialize actions from
   `actions.log`. No property test — could silently break under
   a new variant.
6. **Backend-specific action-to-string** mappings recur across
   `canary_gh.ml`, `canary_diagram.ml`, `canary_html.ml`. Each
   backend rebuilds its own view rather than consuming a shared
   catalogue projection. Small duplication.
7. **`canary_scenario_util.ml` is a tiny grab-bag** (~90 LOC of
   helpers extracted from tiny 2026-07-08 for future projects;
   all consumers today are tiny via `let alias = ...`). Fold
   back into `canary_scenario.ml` or wait for a second
   scenario-driven project to justify the split.
8. **The `open Canary` shim** (`canary.ml`, 27 LOC) re-exports
   `Canary_action + Canary_step_model + Canary_path_table`.
   Still used by `canary_project_llvm.ml` + `canary_diagram.ml`;
   retire once those two switch to explicit module refs.
9. **Tiny's `runner_spec` doesn't emit `build_app` / `probe_app`
   steps.** Sc.3/4/5/6 unmutated scenarios exercise app-level
   paths via `probe_binding`. Adding App-level mutations (§7.1
   remaining blocker) requires extending `make_base_runner_spec`
   with per-Sc.N app-file closures — factory-shape refactor
   beyond a primitive add.

### 6.6 `runner_spec` — the code-side scenario handoff

**Flow.** Project's per-scenario factory (or per-variant hand-code)
constructs a [`Canary_step_builder.runner_spec`](../../src/canary/action/canary_step_builder.ml)
──► `derive_steps` walks it ──► `step list` ──► one of four
backends (local runner / GH YAML / Mermaid / HTML).

**Shape** — a record with two kinds of fields (full list at
[`canary_step_builder.ml:88`](../../src/canary/action/canary_step_builder.ml#L88)):

- **Action closures** (one `option` field per §6.5 verb): each
  closure has type `~output_dir -> ~variant_key -> string` and
  emits the shell command for that action. Missing (`None`) →
  action dropped from the step list. Multi-instance verbs
  (`build_binding`, `probe_*`) carry per-language / per-location
  lists.
- **Policies + metadata**: `expectation` (per-rule /
  per-loc `step_expectation`; today lowered from contract
  bindings by `Canary_scenario.lower_expectation`), `check_post`,
  `symbol_check`, `inspect`, `disabled_contracts`,
  `api_source` (`Canary_artifact_api.t option`),
  `binding_user_facing_pkg` (drives auto-generated inspector
  step after `Probe_binding`), diagram wiring fields.

**Derivation** (`derive_steps ~root ~project ?(langs = [OCaml])
(spec : runner_spec) : step list`) traverses §6.5's verbs in
dependency order; for each present closure emits a `step` with
`cmd` + `expectation` + `check_post` + `symbol_check` +
per-artifact metadata. Auto-inserts inspector steps after
`Probe_binding` and a `scan_source` step to verify `api_source`
claims exist post-fetch.

**Four backends** consume the resulting `step list`:

| Backend      | File                                                                                | What it does                                               |
| ------------ | ----------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| local runner | [`backend/canary_local_runner.ml`](../../src/canary/backend/canary_local_runner.ml) | Executes each step in order, honours cache, records status |
| GH YAML      | [`backend/canary_gh.ml`](../../src/canary/backend/canary_gh.ml)                     | Renders as GitHub Actions job(s)                           |
| Mermaid      | [`backend/canary_diagram.ml`](../../src/canary/backend/canary_diagram.ml)           | Renders as an action-graph diagram                         |
| HTML         | [`backend/canary_html.ml`](../../src/canary/backend/canary_html.ml)                 | Renders interactive result viewer                          |

**Multi-scenario projects.** One `runner_spec` per scenario/variant;
`run_project_multi` runs each independently. Concrete factories:

- **tiny** — [`Canary_tiny_scenario.runner_spec_of_entry`](../../src/canary/projects/canary_tiny_scenario.ml)
  wraps a shared chassis `make_base_runner_spec ~stores` and
  overrides `expectation` from the scenario's recipe (22 scenarios).
- **z3 / llvm** — `mk_runner_spec ~source` per variant (dev / stable).
  Both project's `expectation` closures flow through
  `Canary_scenario.lower_expectation` over their own
  `<project>_contract_bindings` (Task 2 D/E/F, 2026-07-21).
- **sqlite** — `runner_spec` uses `empty_runner_spec` with no
  scenarios, no compat expectations (positive-only).

---

## 7. Principles the SSOT should honour (awareness, not action)

Captured for later; surface here so they're visible per-section.

1. **Artifacts are globally named and indexed.** The Ar.X list is
   one flat catalogue, not per-section. Any artifact mentioned in
   any chapter resolves to the same Ar.X.
2. **Surface IDs align with artifact IDs.** Sf.k is the inspectable
   face of Ar.k. Current draft is not fully consistent (Sf.1
   pointing at native_source while §2 has Ar.0 = native_source) —
   resolving this is part of §8.
3. **Good scenarios × mutation matrix = bad scenarios.**
   Bad scenarios are the projection of a scenario's interested
   entities (artifacts) through the agreement catalogue —
   computed, not maintained. Dual view (artifact-indexed
   mutations) is a checkable alignment invariant, postponed
   to a follow-up after §9.3 scenario remodel lands.
4. **Tiny does not exercise packaging errors.** Bad-scenario
   coverage stops at the build/link/runtime layer. Packaging
   mistakes (wrong files in opam/pip/apt artefacts; cross-PM SONAME
   inconsistencies; metadata drift) are out of tiny's current
   reach — see §8 reconciliation tail.
5. **Anticipations are empirical, not sound.** Uninterested
   entities (system tools, compiler settings, OS behavior,
   hardware) are outside the model. Expected outcomes are bets
   tested against real runs, not theorems. Two flavours worth
   flagging: (i) emergent behavior — all static checks pass,
   specific input triggers wrong output; (ii) environmental
   interaction — artifacts good, uninterested-entity corner case
   flips result. Only discoverable empirically.
6. **Interested vs uninterested entities.** A scenario models
   its interested entities (artifacts explicitly on the
   mutation/violation path). Uninterested entities exist and
   affect outcomes but aren't enumerated in the SSOT. Boundary
   is empirical (we add to the "interested" set when a
   real-world case forces it).

## 8. Downstream usage in `draft.md`

Tables in `draft.md` that should be replaced with references or
generated from this file once SSOT stabilises:

- L349 — Good scenarios table → §4 here
- L382 — Bad scenarios table → §5 here
- §3 agreements catalogue → §3 here
- (any future) artifact/surface catalogue → §1/§2 here

