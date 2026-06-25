Today's task is 
- to finish section 2 for material 
- and section 3 for idea pipeline
- sync-ing a bit on SSOT

# Issues

## Material Issues

### 1 Role of behavior

Manuscript reclassified the former s6 `runtime_trace` as a
**runtime observation**, not a surface (§3.3 *The five surface
roles* + §3.4 c3 Behavior footnote). The code still treats it as
a surface peer to s1..s5. Items to align eventually:

`runtime_trace` is not a surface (from §3.3 decision)

- **OCaml source** (`src/canary/`):
  - `Σ_RT` / `runtime_trace` naming — rename to
    `runtime_observation` (or `behavioral_trace`), or drop the
    `Σ_*` formal label entirely for this case.
  - Any type or constructor in the `inspect_input` ADT that
    treats `Runtime_trace` as a surface-family peer — split out
    as a separate variant or document the asymmetry inline.
  - Surface-role enum / friendly-name mapping: surface roles are
    now s1..s5; runtime observation gets its own slot.
- **Python inspectors** (`canary/scripts/`):
  - `inspect_*` scripts emit JSON with a `kind` field. Probe-trace
    output's `kind` should reflect "observation" not "surface."

> **sw** behaviour based compatibility
No existing tool provides a unified answer to "is this binding compatible with this
library?"

- Static comparators: predict failure substrings from cached
  JSONs; runner greps probe.log for them.
- Probe runner: `Expect_failure { contains_any }` matches against
  embedded assertions in the probe binary.
- The two mechanisms are independent; some rules use one, some
  the other, occasionally both.

AI Impact:
  agreement for tool-use

### 2 Coverage

This is originally in tiny, but should be lifted to SS1 in gaps we
don't want to cover

design space limitation for tiny
for practicality, we can never test e.g. all compileing flags, linux release, so this is out of our assumptions if not explicit tests
movitation: tiny exists to witness each rule reproducibly

### 3 Term

**sw** we use the term `compile` or `interpret` when the action is performed by one language's compiler or interpreter. We use the term build when multiple tools are used in this aciton.

### 4 Syntactical vs Semantics

**syntactic** (declared by the developer) surfaces show source and 
**semantic** (extracted from a compiled artifact)

  rules over surfaces; the spec
   space. Need not be one section internally.

### Finding a project-level Single Source of Truth (SSOT)

The writeup uses several ID prefixes that grew chapter by chapter
without a coordinated audit:

- `Sn.X` — snippets (§2)
- `s1..s5` — surfaces (§3)
- `c1..c7` — contracts (§3)
- `A0/A1/A2` — artifacts (§2)
- `C0..C7` — agreements (§2, semantically overlapping with §3's `c1..c7`)
- `S1..S6` — scenarios (§2)

Plus code-side names: `Σ_*` formal notation, `cmp_*` comparator
names, `inspect_*` script kinds, tiny scenario filenames. These
don't map cleanly to the writeup prefixes.

When tackled (probably as a coordinated pass closer to
submission):
- Decide which IDs are **global** (used across chapters + code)
  vs **local** (defined within one chapter).
- For global IDs: pick canonical prefix and tabulate the
  writeup ↔ code mapping (e.g. `s5 binding_lib` ↔ `Σ_BL` ↔
  `inspect_binding.py --kind stub`).
- For local IDs: document the local scheme where introduced.
- Address §2's `C0..C7` agreements vs §3's `c1..c7` contracts —
  same concepts, different numbering; needs deciding which is
  authoritative.

Cross-references: ties to "Role of behavior" (s6 / Sn.6 naming
asymmetry), runtime_trace code naming, and any future artifact
table (§3.1).

### Fill bugs for SS 1.2 as eye-catcher and implementation result
  concrete bugs we found and better to be issued 
and fixed by the developers

# Outline & To-do

## §1 Background & Motivation (BB)
### 1.1 Motivation: real-world gaps
check with the old write-up
build/install, package integrity
```
Real-world package managers usually have 
the flexibitility to put arbitrary files in a package, so every file 
can be wrongly placed and used.
```

A reader who only reads §1 should know what
canaries are for, what surface theory claims, what tiny argues,
what canary does on real-world packages, what topics MM gathers,
and that an implementation chapter sits at the back.

### 1.2 Approach

Restruct with this presenting:
**error-prone**: 
  - **Management latency**
    - testing coverage full life cycle from develop to users, every language bindings
  - **principly tests** derive from a given project spec
  - unified interface for tools
**insufficent or infeasible specification**: 
  - behavior-based checking on tool result
  - a tiny project, with pertubations to cover every interested scenaratios
    - establish a ground truth
  - _surface ~theory~_(rule of thumb) as a pre-and-post condition, which are implicitly obeyed
**ubiquitos**: evaluation covering widely used package and a large part of OCaml package

uniform-review (record) is a mnemonic
sw: benefit of artifact views is to convert 
  heretogenous pkgm as key-value store
  artifact store
  uniform interface
  artifact/surface/inspector/comparator
    - how resolving behaves

**movitation of surface theory** simpler, quick pre-and-post condition
a surface theory which covers all components by their beharios believes 
and contracts, that tools reply and use. serving as rules and inviants. like a spec space

### 1.3 Organising grid

- [ ] An better place should be in SS 1.1

> we see the widely used c-api based approach as a theory instance (one spec), 
> and as a theory (rule,metarule) it can also support ctypes, rust ffi, ....

**sw**: a bit distrated for the last two sentences. Maybe can move to later places

The work focuses on things around upstream projects and their bindings in
different languages, and we maximize the combinations in those components; 
however, we cannot emunerate any possible combinations of versions and
configurations for C compilers, system loaders and linkers, binary utilies 
on different systems. If the tools can detect our dedicated perturbated
error in tiny e.g. one mismatch between binding and stub APIs, we assumes that
it should also be able to find the real-world project having the 
same case; however, we cannot assume the tools we have to use it reliable.

### 1.4 Roadmap/Outline

Every topic the rest of the writeup touches, in a sentence each
— a prose elaboration of the grid above. The reader should leave
§1 knowing *what* is coming and *where*.

## §2 Tiny (TT) — a mechanism-complete, material-naive

<!-- what is the essential differenec between source code and binary format -->

- [ ] should unify the naming scheme
- [ ] headers are considered as an artifact

Tiny is a minimal testbed with a hand-controlled perturbation budget; every active Contract has a witness scenario.
  
we need a per-side artifact, surface, and agreement summary
also to emphasize the record-like structures.

**sw** the id are global indexing in both writeup and code. 
The n-th artifact and the coresponding n-th surface.

three binding mechanisms (OCaml cstubs, Python cext, Python
ctypes)

In the real-world, not all native lib are created on the fly. Whether such 
agreements are kept or broken, will be discuss in the next subsection.

sync-ing with [`tiny.md`](tiny.md)

Anatomy absorbed into §2
(touchstone); §4 focuses on witness role + perturbation matrix
(§4.2) + what tiny demonstrates/doesn't (§4.3).

**sw: we don't define good and bad scenario**
The Good, the Bad and the Ugly

controlled witness.

can be future work
- tiny can be more complex when it contains multiple libs

## §3 Surface theory (SS)

The problem of this section is we shouldn't start with surface thoery, but we should start from tiny on what is checking, and how to check it better. Thus for some case/contract, we can check from surface; for some cases, we have to use behavior check
  - we can observe the pattern that we gradually move from surface to runtime check
  - we need to assign runtime-behavor/testing/runtime probe a good role
  - back to the problem on role of the behavior

I need to outline the introduction and developing of term _surface_

> **sw** up to §2, we don't discuss the necessary and effective of
> why using surface checking; thought the idea is very simple, a 
> failing bug can often by find by a simpler check based on the 
> belief(agreement) on surface
> **sw** maybe we should also discuss the category of bugs

find a good place for 
> | **s6** | `runtime_trace`  | Σ_RT   | runtime | semantic  | observable call trace at runtime — probe input/output behaviour            |

### need a term for binding mechanism
in spirite, static means early-binding while dynamic means later-binding (thus keep open)

## §4 Tiny 
should be merged to SS 2; We can go over all the examples of tiny in S2.

## §5 Canary (CC)

- [ ] from practical, another thing is the spec driven, so that any project
- [ ] synthetic user library
- [ ] we don't explicitly use the term _producers_
- [ ] runner is not an excellent abstracting term
  runner/backend/cache is a uniform caching system

canary actions is to apply the tiny template for real-workd packages

§5.1–5.2 (stores), §5.4 (scan_sources
  placement mechanism, §7.2 home), §5.5 (validation), §5.6
  (natural producers), §5.7 (real-project demos).
the framework that scales the witness to
   natural producers (opam, pip, apt, …); includes a methodological
   validation step against tiny.
   `worklog_2026_06.md` (Phase 14/15 mechanics);
  [`../design/harness_canary_orthogonality.md`](../design/harness_canary_orthogonality.md)
  (orthogonal factoring); `CLAUDE.md` (orientation map);

## §6 Miscellaneous (MM) — principles
  packaging as a trace source, versioning cross-cuts, hidden
  dependencies, related work, calculus sketch. The
  "extensions" pattern from PL papers is **held in mind** here,
  not committed.
   — `surface_draft/principle.md` (full principles);
  `surface_draft/package.md` (packaging);
  `surface_draft/versioning.md` (versioning cross-cuts);
  `surface_draft/surface.md` §4 (hidden deps);
  `surface_draft/main.md` §5 (related work) + §6 (calculus
  sketch); [`literature.md`](literature.md).

## §7 Implementation (Impl) — how the theory is realised in
   code: the two engines (mutation, combinator), inspectors and
   check mechanisms, code-citation map, the boundary between
   harness and canary. Skippable for readers who only want the
   conceptual narrative.
    `surface_draft/implementation.md` §2.7 (code map);
    `worklog_2026_06.md` (engine machinery + harness leaks);
    [`../design/harness_canary_orthogonality.md`](../design/harness_canary_orthogonality.md)
    (engine boundary cleanness); existing code in
    `src/canary/projects/`, `src/canary/surface/`,
    `canary/examples/tiny/scenarios/`, `canary/scripts/inspect_*`.

# Unchecked material

They evolved organically: `gcc` checks that
headers exist but not that the symbols they declare match the `.so`; `ld`
resolves symbols by name but ignores version annotations unless configured
otherwise; `pip` installs a wheel but cannot tell you whether the bundled
`.so` is compatible with the system `libstdc++`.

--

The theory serves two purposes: (i) it **justifies** the implementation —
every design choice in Canary should be derivable from a principle stated
here; (ii) it **predicts** — a new library, language, or package manager
should fit into the model without ad-hoc extension.

## The two engines

Where harness and canary plug into the rule/trace framework. The
slots aren't part of the theory; they record how each piece is
realised today.

| Slot                | Mutation engine (harness on tiny)                 | Combinator engine (canary)                                             |
| ------------------- | ------------------------------------------------- | ---------------------------------------------------------------------- |
| **World shape**     | one source tree, all artifacts derived from it    | per-kind stores, independently sourceable                              |
| **World build**     | `scenarios.py apply` / `revert` (mutate in place) | spec-driven cross product (variant matrix in `canary_project_tiny.ml`) |
| **Trace**           | mutation `μ`: patch one surface, rebuild          | configuration `W`: pick one artifact per kind from stores              |
| **Verdict (pred.)** | `confirm_ill.json`                                | `Expect_compat_failure`                                                |
| **Verdict (obs.)**  | `probe.log`                                       | `actions.log`                                                          |
| **Code locus**      | `canary/examples/tiny/scenarios/`                 | `src/canary/projects/canary_project_tiny.ml` + action graph            |

The two engines validate the same rules from opposite directions:
mutation gives depth (controlled, reproducible perturbations);
combinator gives breadth (configurations sourced from independent
producers).

**Engine boundary cleanness**

- The mutation engine (harness) and combinator engine (canary)
  must stay operationally separate so the methodological claim
  ("two independent engines validate the same rules") is honest.
- Where the boundary leaks today (e.g. `_snapshot_workspace`'s
  RUNPATH-strip and libtiny.so symlink synthesis) is tracked in
  [`../design/harness_canary_orthogonality.md`](../design/harness_canary_orthogonality.md).
- Phase 16's refactor goal: close those leaks.

## implementation

**What's general vs what's framework-private**

- General: store model, spec model, scan_sources, inspect ADT,
  comparator / runner layering, producer-agnosticism.
- Framework-private: hardcoded-grep inspectors
  (`inspect_tiny_typed.py`), workspace-materialisation fixups —
  details in
  [`../design/harness_canary_orthogonality.md`](../design/harness_canary_orthogonality.md).

tiny should have packages