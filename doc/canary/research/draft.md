---
---

<!-- SKELETON, 2026-08-26. Bullet stage: every bullet is a CLAIM, not a
     topic — a topic can be filled a hundred ways, a claim one way, so
     filling is retrieval rather than invention. One level deep on
     purpose: nothing below a section gets written until that section's
     thesis is accepted. Material to mine: draft_old.md,
     draft_comment_old.md, surface_draft/ (incl. tiny.md), and design/.

     DECIDED 2026-08-26: the word "complete" is OUT — too dangerous a
     term to carry. This is a bug-finding / testing framework, and
     "practical" is in the title in its place. Do not reintroduce a
     completeness claim without revisiting this. -->

# Practical Bug-Finding for Language Bindings across Package Managers


**The claim.** A language binding reaches its user through packaging —
several package managers, several maintainers, and a developer none of
them talk to — and no party checks the whole chain. Defects are
therefore quirky, surface late, and get blamed wrong. This is a
bug-finding framework, not a verifier: it does not prove a deployment
sound, it exhibits real failures in one. It works along two axes — the
framework multiplies the **worlds** a binding is actually deployed
into, and the agreement registry multiplies the **checks** applied
inside each world, beyond "the command exited 0." The evidence is real
defects, reported and fixed upstream.

**Status snapshot — 2026-08-27.** Working-draft furniture; delete
before submission. Baseline from the 2026-08-26 progress review, with
the checking row added and the paper row rewritten after this
session's work. Percentages are judgement, evidence is not.

| Track                                 | State                     | Evidence                                                                                                                                                                                                                                                                                                                                                       |
| ------------------------------------- | ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Framework** (canary core)           | ~80%                      | M1 closed 2026-08-16. M2: steps 1–3 done, 7 of 10 open. Five-pass pipeline with `emit --stage N` dumps (08-24); own opam switch, platform carried not sniffed (08-26); four test suites green on Linux and macOS                                                                                                                                               |
| **Checking** (the agreement registry) | ~25%                      | **5 of 8 agreements have a working falsifier** (symbol, api-completeness, abi, symbol-version, type); behaviour blocked, repacking stubbed, one off by design. The registry has **no production consumer** — the pipeline calls the flat table and the registry wraps it. Catalogue doc is **3 of 20 sections** (§0.x, §1.x, §2.x written; §3–§9 do not exist) |
| **Witness** (tiny)                    | ~85%, regressed           | tiny1 22/22 pass, but detection coverage 12/24 — watchlist-blind on c5/c6/abi. tiny-full advertises six worlds and runs **one**; its lib and binding axes sit in dead code. Open decision: restore or delete                                                                                                                                                   |
| **Projects** (empirical breadth)      | ~45%                      | 10 registry projects + tiny1, 42 scenarios, 41 run. Against the declared 2×2 lower bound: 2 full, 1 collapse-only, 6 half, 1 neither                                                                                                                                                                                                                           |
| **Findings** (the product)            | ~50%                      | Real and reproducible: z3's forward cell (791 symbols required, 705 provided), ncurses `libtinfo` closure-shape segfault with identical symbol sets, zstd symbol-count-as-packager-policy, sundials 6→7 API break. **Zero upstream PRs filed**                                                                                                                 |
| **Paper**                             | ~20% prose, spine settled | Old manuscript retired to `draft_old.md` (873 lines, largely roadmap bullets). This file is a bullet skeleton: claim agreed, two axes agreed, materials triaged with a fate per file. **Prosing.**                                                                                                                                                             |
| **Delivery / ops**                    | ~25%                      | CI still runs the pre-A5 shape, one chain per project rather than the enumerated set; web results page not built; report milestone deferred                                                                                                                                                                                                                    |

**The through-line.** The runner is the finished half and the checker is
not: landing a project is cheap, but what a landing *checks* is still
per-project tables, and no repair has yet been driven off a check.
Growing the roster adds rows, not claims.

else, _material: literature.md_

---

## 1. The problem

*Thesis: we systemize the bug-finding and fixing for packages for language bindings
via a **practical enumeration** of software actions and **principled checkings**.

- Multi-language bindings are ubiquitous and critical, and the chain
  that delivers them crosses tools no one specified together.
- **The chain spans actors, and packaging is where they meet**: a
  developer, a binding author, maintainers in several package
  managers, an administrator, an end user. Each sees one hop. The end
  user starts from a *package*, never from the source the developer
  wrote.
- The agreements these tools rely on are **behavioural, not written** —
  determined by what a compiler, a linker or a loader happens to do.
- **Management latency**: the packaged binding lags the library, so a
  defect is introduced upstream and discovered downstream, after
  shipping.
- The only oracle in use is a **successful command**: violations some
  tool enforces get rejected, everything merely *tolerated* passes
  green until usage finally touches it.
- **Different end uses touch different parts.** A deployment that is
  healthy under one user's usage is broken under another's, so a defect
  is not a property of the package alone but of the package *and* the
  use — which is why checking has to reach the run, not stop at the
  build.

_Material: draft_old.md §Motivation; the courtesy paragraph._

## 2. The stance

*Thesis: we find bugs rather than prove their absence — and the limits
of that are stated up front, not discovered by a reader.*

- Every failure we report is a **real** one, witnessed by a run or by a
  prediction grounded in a real tool. We do not claim to have found
  them all.
- Verification is unavailable here by nature, not by choice: the tools
  are unspecified and partly behaviour-determined, so there is nothing
  to prove against.
- The consequence that shapes the rest of the paper: every agreement
  must carry a **falsifier** — a check that can exhibit a witness —
  rather than a proof obligation.
- **Practical, not exhaustive**, and this bounds both axes. The space
  of possible checks cannot be enumerated; we are mechanism-complete
  and material-naive, with build and compile flags, distributions and
  libc variants out of assumption unless a test names them. The
  error-prone build arguments are the near-term priority.
- **Position and contribution** — where this sits against related work,
  why the surface/agreement method answers what per-tool checking,
  dependency resolution and ABI-diff tooling cannot, and the
  contribution list itself. 

> **Question**: from the two axes the method looks straightforward — worlds × checks. 
Why is it a study rather than a cartesian product with a test runner? 
Practitioners will not press hard if it works; the theory reader will.

- Leads, undecided: **necessity** — the ecosystem grows faster than
  anyone can track it, so incompatibility is not avoidable by care;
  **non-obviousness** — which cells are real, where a check attaches,
  and whether a red cell is a bug at all.

## 3. Practical enumeration

*Thesis: A project only provides necessary dependent commands and declares its provided artifact provision. The canary framework derives the rest of the worlds.* 

- **Packaging supplies alternatives for every component**, so the
  number of worlds is a product rather than a list — and anything that
  can be substituted eventually is.
- A world is a choice of provenance × version (× platform) for every
  artifact in the chain; the deployed set is far larger than the set a
  project tests.
- The enumeration is derived from what a project **declares**, not from
  a script per case.
- Each world is realisable and reproducible (best effect).
- Mismatch worlds (a new binding against an old library, and the
  reverse) are the ones that carry real defects.
- **Spec-driven onboarding.** A project is landed by declaring a spec,
  not by writing a harness: the framework already supplies the common
  facilities, so a new project costs no extra machinery.
  
#### Details

- **Co-providers**: some packages bundle their own copy of the native
  library (the z3-solver wheel, llvmlite), so the outer package carries
  a native artifact inside it and "the library" stops naming one thing.
  Already expressible in the project spec.
- The chain runs through to a **consumer app** — the synthetic user application is what actually reaches *use*.


*Material: design/enumeration/ (five passes); project/projects.md.*

## 4. Principled checkings

*Thesis: these agreements are already relied on at every stage, but
were never written down — making them explicit is what turns a green
build into a check.*

<!-- TENTATIVE GROUPING 2026-08-27: principles and motivation here;
     mechanics (which comparator is wired, inspector coverage, the
     registry's absorption of canary_compat) moved to §6. The backbone
     is design/agreement_registry_audit.md, whose §0.3 / §0.4 / §2.1 /
     §10.x already state several of these better than the draft does.
     Regroup freely — the [OPEN] terms question below may reorganize
     this whole section. -->

### Why checking is hard here

- **Information loss is intrinsic**: compiling erases, and linking and
  loading never recover — so less is knowable about a binary than was
  known about its source.

### the agreement registry

- A *central collection* that spans static and dynamic agreements based
on per-language artifact, language tools, binding mechanisms

> Why checking is hard here

- **A green run confirms something — just not what you need.** This
  holds for the ordinary build-and-run *and* for our own checking
  actions: a success says the dependent library loaded, not that it
  exports every symbol the binding needs, nor that any function is
  semantically right. A pass is never "compatible" — it is bounded by
  what was observed, and that bound differs per observation depth
  (one artifact / two surfaces / an action postcondition / the meeting
  / the run). 

#### Details

- **Provenance is not recoverable from an artifact**: given a library,
  you cannot recover which agreement it once satisfied, nor predict the
  next. This is why the method inspects rather than looks up.

- **Declared surfaces are trusted but not verified**: the build
  succeeds if the header exists, whatever the binary actually provides.

[registry §10.1 says this well]

- **Boundary and surface are not the same thing**: the boundary is the
  objective locus where two artifacts meet, the surface is what is
  *detected* there, and the inspector is what bridges them.

- **Version beliefs are systematically wrong**: "I'm running libz3
  4.15.0" names a package manifest, not the SONAME the loader resolves
  nor the constant the library itself reports.

- A **surface** has two faces — *declared* (syntactic) and *extracted*
  (semantic / "realized" in the registry's wording). The gap between
  them is what tools should catch and don't.
<!-- - An agreement is a **named relation over two surfaces**, carrying a
  falsifier-phrased invariant and naming the surfaces its witness is
  read from. -->

- **(OPEN) One set of terms.** The surface narrative
  (`surface_draft/surface.md`, `surface_why.md`) and the
  agreement-registry narrative are two accounts of the same material —
  down to *semantic* vs *realized* for the same face. Reconcile them
  here, before writing further.

### 4.3 What is in scope

- **We model agreements, not tools.** What each tool consumes and
  produces (`gcc`: headers → undefined symbols; `ld`: undefined symbols
  → NEEDED and SONAME) is where the syntactic/semantic split comes
  from — but the tools get few words; they are not the object of study.
- **What today's tools concretely miss**: `gcc` checks that a header
  exists but not that its declarations match the `.so`; `ld` resolves
  symbols by name and ignores version annotations unless told
  otherwise; `pip` installs a wheel without knowing whether its bundled
  `.so` matches the system `libstdc++`.
- **Versioning is asserted at six sites**, and the split between
  *intrinsic* (the artifact carries it — SONAME, `@@VER`, an embedded
  constant) and *extrinsic* (an authority records it — repo tag,
  package manifest, filename) is exactly the line between what this
  method checks and what packaging owns.
- **Inspection is not resolution**: what an artifact presents is a
  different question from which artifact the loader or the package
  manager will pick. [registry §2.8]

### 4.4 The catalogue

- One statement per agreement: the **falsifier**, its tool-grounded
  **inputs**, the **evidence kind**, and the **firing** derived from
  mechanism × provision. The per-project tables converge onto it and
  are deleted. [status.md M2 step 6 — declared not descopable]
- **Checks migrate from surface to runtime** as an agreement gets
  harder to see statically — which is why the runtime observation needs
  a role of its own, now that it is no longer counted as a surface.
- **Openness, and nothing in between.** Composing the two axes invents
  no rules of its own — the framework *is* the composition — so a new
  tool, package manager, artifact kind or checker enters as a new
  (surface, agreement) pair rather than as a change to the framework.
  [true, but a minor claim — do not lead with it]
- Parked properties: refinement order (`SymbolVersion ⊑ Symbol`),
  conjunctive satisfaction, static/dynamic as an *implementation* axis,
  the behavioural-subtyping echo for the runtime agreement.

### 4.5 The phenomena a catalogue has to cover

- **Hidden dependencies** — a semantic requirement that no syntactic
  surface declares. LLVM 19's binding needs `libffi`, `libedit` and
  `libzstd`, named in no header, CMake file or opam constraint.
- **The silent case is the C runtime**: `malloc@GLIBC_2.17` builds,
  links and tests clean on the build host, and fails only once shipped
  to one with a different libc.
- Bad artifacts split in two: **wrong** (should never have been offered
  at all) and **incomplete** (compiles, but unusable on this platform
  or with this binding mechanism).
- **A taxonomy of the defects** this exposes. [to write]

*Material: design/agreement_registry_audit.md (the backbone);
canary_contract_registry.ml.*

## 5. Evidence

*Thesis: the two axes together find real defects that neither finds
alone.*

- Findings to date, each with the surface it violates and the party it
  belongs to.
- Blame as an output, not a narrative: the check names the surface, the
  surface names the actor.
- Upstream repair as the evidence standard — reported, and fixed.
  [plan / to-do]
- **Tiny and its perturbations**: every artifact × action failure is
  witnessed, one at a time — the coverage argument for the *bad* side,
  and the validation of axes 1 and 2 once they are combined. (The two
  engines behind it — mutation for depth, combinator for breadth — are
  trivial implementations, not a claim.)

*Material: project/report_ncurses_libtinfo.md; project/issues.md; ../plan.md §4.*

## 6. Implementation and apparatus

*Thesis: the results are only as good as the tools underneath, so the
tools are themselves under test.*

- **The uniform artifact store**: a user may take an artifact from
  anywhere, so heterogeneous package managers are reduced to one store
  with a uniform interface — which is what makes the world enumeration
  implementable and extensible.
- **The tools are not themselves trustworthy**, so they are under test:
  if tiny's perturbation is detected we expect the same case to be
  detected in a real project, but that inference is only as good as
  `nm`, `readelf`, `ocamlobjinfo` and friends behaving as assumed.
- **Which agreements are actually grounded today**: five of eight have
  a working falsifier (symbol, api-completeness, abi, symbol-version,
  type); behaviour is blocked, repacking stubbed, and one is off by
  design. The wiring status is part of the honest picture, not an
  embarrassment to hide.
- **The registry owns the checking.** Today the pipeline calls the flat
  check table directly and the registry wraps it, so the registry has
  no production caller. Inverting that — the rows' inputs and
  predictions become the registry's own, and the flat table becomes a
  projection — is what makes the catalogue the thing that runs.
  [status.md M2 step 6]
- Inspector coverage, the contract × mechanism bridge, and the
  per-language input templates.
- Implementation map: where each piece lives.

## 7. Related work

- [placeholder — literature.md]

---

## Not in this draft — reviewed and left out

Recorded so the next pass does not re-discover them. Nothing here is
rejected; each is parked with a reason.

- **Artifact records and the PL scaffold** (`surface_draft/notation.md`)
  — records as typed property sets, the traces analogy, and §2.9's
  surface-satisfaction predicate.
- **The typed calculus** (`surface_draft/future_impl.md`) — artifacts as
  values, surface roles as types, build/compile/link as partial typed
  transformers. Author to read and decide.
- **P1–P6 principles** (`surface_draft/principle.md`) — judged outdated
  and largely covered elsewhere. **P4** (covariant providers,
  contravariant consumers — a comparator's set-inclusion direction is
  the variance dial) is the one item not covered anywhere else.
- **The provider-matrix formalism** (`surface_draft/package.md`) —
  `Compat(Lib)` as a comprehension over (PM, version, language). Axis
  one carries the idea in prose; the formal version is unused.
- **Inspector coverage tables** (`surface_draft/implementation.md`) —
  §6 material. Author to read and decide.
- **Resource substrates** (registry §1.1–1.6) — filesystem, web, PM and
  extensible resources.
- **Cache behaviour** — explicitly outside the agreement model
  (registry §0.5).
- **Vocabulary threads** — static = early binding / dynamic = late
  binding; *compile or interpret* (one language's tool) versus *build*
  (several).
