# Draft drift: what draft.md does not say yet

*2026-09-29.* A checklist for writing [`draft.md`](draft.md) against the
overview page (`docs/canary/overview.html`, `make view`), which is the
current picture. The draft's prose dates from 2026-08-26 to 09-03 and
its §0 snapshot from 09-03. Each item gives what exists now, whether
the paper can claim it, where it belongs in the draft, and where to read
it.

- **landed**: a real run decides it;
- **partial**: some of it runs;
- **planned**: designed, not built.

Numbers are a snapshot, so re-run the command beside a number before
citing it.

## 1. Terms to settle first

The page defines its terms in §0.1. The draft uses other words for some
of the same things, and in one place the same word for a different
thing.

| page | draft | to decide |
| --- | --- | --- |
| **world**: one choice of where each of a project's artifacts comes from, and at which version | scenario (§2.1, §3) | The code enumerates worlds; "scenario" survives in older docs and code names. Pick one for the paper. |
| **chain**: one world in one binding language, the path from two package managers to the programs | the chain of actors (§1); the action chain (§2.1) | §1's sense and the page's agree; the paper should use one and define it. |
| **side**: the system side and the language side | native side, binding side (§2.0, §4.1) | §2.0's "binding side pm and package" seems to mean the system side, but the binding itself sits on the language side. |
| **layer**: package manager, package, artifact, program | "four components at three layers" (§4.1) | The page has four layers on two sides. §4.1's cut is the same, with the package manager folded into the package layer. |
| **cooperation**: how two package managers are joined (§3.3, 11 kinds) | "pm cooperation" (§2.0), "cooperation patterns" (§4.1) | Same concept; the page has the catalogue. |
| **bridge** and **capability file** | "virtual conf-package", `depext` (§4.1) | The page keeps them apart. A bridge (opam's conf-* packages and depexts fields) is package content made for cooperation. A capability file (`.pc`, META) says what a package offers, and belongs to that package. |
| **binding mechanism** | "bind mechanism" (§4.2) | Same; the catalogue has five. |
| **agreement**, **candidate**, **claim site**, **kind** | agreement (§4) | The page adds candidates (claims named, with no evaluator), sites (the edges of the model a claim sits on) and six kinds (§2 below). |
| **blame**: why a check has no verdict (evidence, declaration, version, stale, vacuous) | blame: the party answerable for a failure (§5) | **A collision.** The page's word names a gap in canary's own evidence or spec; §5's names a party. The paper needs two words. |
| **linking lift** | "artifact-to-package lift" (§2.0) | Same idea; pick one name. |
| a project's **declarations** | "project manifest" (§3.4, proposed) | The code says spec, `project_run`; the page says declarations. "Manifest" works if the paper defines it. |
| **frame**: one action as §1 draws it, a column group of §1.2 and §2 | — | Only needed if the paper shows the result table. |

## 2. Section by section

### §0 Meta: the snapshot is stale

| the draft says (09-03) | now | re-derive with |
| --- | --- | --- |
| 12 agreements, 5 wired, under slugs such as `symbol_exported` and `soname_denotes_needed` | 14 registered agreements: 11 with an evaluator, 9 **landed**. With 16 candidates, 30 claims sit on the model. Slugs renamed, e.g. `required_symbols_exported`, `soname_matches_requirement` | `canary checks --landing` |
| a five-pass pipeline | six passes over four IRs | `canary emit <p> --stage N` |
| 10 projects and tiny1, 42 scenarios, 41 run | the record holds 10 projects, 28 worlds, 42 chains; z3 is muted and runs separately | `canary overview --json` |
| z3's forward cell: 791 symbols required, 705 provided | the notes disagree: 791/705 (08-19) and 776/705 with 85 missing (09-15). Run z3 and read its stub inspection before citing | `canary action z3`, then the record |
| web results page not built | the overview page is the results page | `make view` |
| the agreement catalogue doc (2382 lines) | retired; page §2 is the catalogue. Four agreement docs remain, due a cleanup | — |

### §1 The problem

Aligned. Two points the page now makes concrete:

- **The two package managers, by side:** apt and brew on the system
  side, opam and pip on the language side (page §3.1).
- **Where they meet:** a bridge, or nothing (page §3.3). opam's conf-*
  packages and depexts are bridges; pip bundles the library instead.
  Cargo's `*-sys` crates meet through a capability file and no bridge.
  That contrast left the page and belongs here or in §8.

### §2.0 Rationale and §2.1 Canary overall

- **The layered model** (built from code, and drawn). Your split — a
  package manager and package layer per side, their cooperation and its
  irregularities, then the package-free binding mechanism — is the
  page's §1 and §3. A chain joins three things:
  - two package managers, one per side by its driver's scope (§3.1);
  - a binding mechanism, which decides which artifacts exist (§3.2);
  - a cooperation, which decides the package nodes and joining edges
    (§3.3). It is derived per world from where its artifacts come from
    and the gates its project declares.

  One fixed, hand-written graph carries every chain: 16 nodes and 21
  edges, each edge named by an action family. Read the page's §1 note
  "A chain is a join", and §3's intro.
- **"Package special irregularity"** is what the cooperation kinds
  record:
  - *absorbed by the consumer package*: opam's z3 and llvm packages
    build the library inside;
  - *no package manager between*: sqlite's Python binding ships with
    CPython, so its fetch is an "included" step;
  - *unified package universe*: torch, with libtorch as an opam package;
  - *⚠ bridge still gates against a system this world does not use*:
    cairo, libffi, sqlite.

  Seven of the 11 kinds have worlds. Four are named only: undeclared,
  direct depext, artifact-centric capability-mediated, and incomplete.
- **"Artifact-to-package lift"** is the page's linking lift, **planned**.
  What exists: the two consumer programs, artifact-linked and
  package-linked, are nodes of the model, and z3 has both probes wired.
  The package-linked one is blocked by a publish bug (project
  issues.md §1). The claim between them, `package_resolution_suffices`,
  is a candidate with no evaluator. The design, which keeps a name apart
  from a resolution the package failed to provide, is overview.md §6.2
  step 5.
- **Placeholders** (landed): steps that stand for what a package manager
  does inside our actions and canary cannot record — apt's policy,
  opam's plan, solver and build. The page draws them as "inside" marks.
  They are an honest boundary of observation.
- **"NEED AN EXAMPLE"**: candidates, each drawn on the page (§3.4):
  - zarith: the conf-gmp bridge, whose own check a bridge step records,
    decided by `gate_admits_the_world`;
  - sqlite: a staged copy beside the build tree, and a Python binding
    included with the language;
  - llvm: `Opcode.UncondBr` — the released binding (LLVM 19) lacks what
    its example uses (LLVM 21 and later).

  tiny remains the minimal witness.
- **Figures.** The page's §1 diagram is the model figure. The page's
  §0.2 figure is the architecture figure: code, passes, run, record and
  page, with what the harness holds.

### §3 Practical enumeration

- **The pipeline** has six passes over four IRs (read
  `enumeration/pipeline.md`; `canary emit` prints each):
  1. declare, to the spec;
  2. analyse, to the analysis: which chains the spec admits, each
     language's mechanism, and which claims it can carry, all before any
     world exists;
  3. enumerate, to every world the project has;
  4. select, to what this run asked for (`--thin`, `--refs`);
  5. order, grouping worlds by the store state each one locks, since
     opam holds one version of a package per switch;
  6. realize, to the steps.

  §3.4's "collection pass" is passes 1–2. §3.5's uninstall-and-install
  cost is what pass 5 orders around.
- **Realize adds steps the project never wrote:** inspection steps that
  record evidence, placeholders, included steps and bridge steps. A
  run's record is its manifests (what each world realized), its
  `actions.log` and its inspections. The page's §1.2 shows one row per
  chain.
- **Numbering:** §3.3 is missing.

### §4 Principled checking

- **Categorizing agreements by layer is built.** Every agreement and
  candidate has a claim site, the edges of the model it sits on. Page
  §2.1 groups them by reach and layer. §2.2 lists them edge by edge,
  with the four edges that carry no claim: `resolve_sys`, `realize_hdr`,
  `realize_cap`, `build_hdr`.
- **What is claimed: six kinds.**
  - admissibility: would one action have accepted these inputs together?
  - promise: is this artifact what its producer said it would be?
  - quality: is it sound on its own terms? (no agreement yet)
  - preservation: is it still the same after a transformation?
  - behaviour: does running it produce what was specified?
  - composition: a verdict over other verdicts.
- **Whose rule: four bases.** A toolchain rule, a project declaration, a
  compatibility policy, or a behavioural spec. §4.2's "what do we check
  against — t.b.c." is answered by the basis plus the evidence each
  method reads: a peer artifact, a declaration, or a staged copy.
- **Rooting and firing** are the R and D marks of page §2: where the
  tool's rule ran, and where the check runs. §4.1's "search of the lost
  agreement" is this: the rule runs at one action, and the evidence
  survives to a later one.
- **Landed, to cite in §4.3–4.4:**
  - symbols: `required_symbols_exported`, `declared_symbols_exported`;
  - library identity: `soname_matches_declaration`,
    `soname_matches_requirement`, `required_versions_exported`;
  - linking: `dependencies_provided`;
  - the staged copy: `staged_interface_preserved`;
  - the binding's surface: `api_names_present`;
  - the bridge: `gate_admits_the_world`, the first package-layer
    agreement, decided on zarith.
- **Not landed:**
  - `declared_versions_exported`: vacuous where nothing is declared;
  - `signatures_agree`: evaluated, no evidence yet;
  - `behavior_matches`, `repack_preserves_api`, `repack_complete`: no
    evaluator.
- **§4.3's "no local paths under the install profile"** is not
  registered; it may be a candidate.
- **§4.4:** OCaml has two mechanisms in the catalogue (cstubs, dynlink),
  and Python three (cext, ctypes, cffi). The draft says OCaml binds only
  through compiled C stubs. The mechanism decides which claims apply: a
  ctypes binding has no stub, so no stub claim.
- **§4.5–4.7's materials** point to `design/agreement/`, which is due a
  cleanup. Page §2 and `canary checks --agreement NAME` are current.

### §5 Attribution and blame

- **The word collision** in §1 of this doc.
- **"§4's seven sources"** predates the registry, which now has four
  bases and six kinds. Remap the bullets onto them.
- **What exists.** The draft's claim still holds: party-level blame is
  not implemented, and direction (forward, backward) is computed per
  world. New since then:
  - a check that cannot decide says why (the page's blame words);
  - an unavailable outcome carries a typed cause;
  - `--strict` fails the step that read a violation.
- **The cooperation as the blamed party** (the ncurses specimen) is the
  page's cooperation: a failure in the join, not in either artifact.

### §6 Implementation (empty)

- Page §0.2 is the architecture figure.
- The code's layers: base, agreement, tool, action, backend, then
  project and main.
- The harness: 195 project, 120 artifact and 17 package-manager tests;
  a round-trip gate that fails if a landed agreement stops deciding on
  sqlite; pins that hold the page's own lists to the code.
- Canary runs in its own opam switch, and the platform is carried, not
  sniffed.

### §7 Evaluation (plan)

- **Scale** (`canary overview --json` and the page):
  - 10 projects with runs, plus z3, muted and run separately;
  - 28 worlds and 42 chains;
  - 4 package managers with drivers, and 5 binding mechanisms;
  - 11 cooperation kinds, 7 with worlds;
  - a model of 16 nodes and 21 edges;
  - 14 registered agreements (9 landed) and 16 candidates.
- **Findings to verify before citing:**
  - z3's forward cell: symbols a HEAD binding requires that apt's libz3
    lacks.
  - z3's both-released world: the opam package ships its own libz3, so
    the declared apt library is never loaded.
  - ssl: `dependencies_provided` violated on `libcrypto.so.3`.
  - sqlite: the built 3.43.2 violates its own declared exports, because
    the declaration cannot say "from 3.44"; the blame falls on the
    declaration.
  - zarith: the conf-gmp gate, recorded.
  - torch: the stock package does not build with dune 3.23.1; canary
    carries the one-line fix.

  The 09-03 snapshot said zero upstream PRs; check.

### §8 Related work

- **Bridges across ecosystems:** opam's conf-* and depexts; Cargo's
  `*-sys` crates, with a capability file and no bridge.
- **The network analogy**, removed from the page. In a network stack
  both hosts run the same protocol at each layer, so a per-layer and an
  end-to-end invariant both have a contract to check against. Here the
  package layer's horizontal relation is a bridge someone wrote, or
  nothing, and a bridge may carry identity while dropping version: it
  forwards the address and drops the checksum. That is why the
  end-to-end claims are the ones missing.

## 3. Prose the page dropped that the paper may want

The restructure of 2026-09-29 cut comparisons and history from the
page's asides:
- the Cargo contrast;
- the network analogy;
- "a binding-level view cannot see a bridge, which is why the layered
  model exists".

Recover the earlier text with
`git show 36714267:canary/overview/page.html`.

## 4. Refreshing this doc

`canary checks --landing`, `canary overview --json`,
`canary overview --flow`, `make view`, `canary spec-check @all`.
