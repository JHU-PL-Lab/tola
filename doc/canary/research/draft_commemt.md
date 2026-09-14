---
---

<!-- TITLE, parked (2026-09-03): the thing built targets the large —
     it is closer to a *binding package harness*, checking and
     assisting beyond finding faults — while bug-finding and fixing is
     the more practical thing to announce. Both can stand: harness as
     the artifact, bug-finding as the evaluation.

     WHEN TO DECIDE: writing §5. A bug-finder is judged by the bugs it
     found (and today that is 0 upstream PRs); a harness is judged by
     what it can express. Claiming narrow costs nothing as long as the
     harness framing stays in §7 and future work — over-claiming in the
     title is the only expensive mistake here. -->

<!-- The canary framework provides scenario patterns tepmlates depending on
the bindings that the project provide. For example, if it only provides 
an OCaml finding, canary 
The pattern is based on the existence of some project field. For example, 
if a project has OCaml binding which usually relies on a native library, 
the enumeration will cover each provider components to make that binding,
and each consumer component to use that binding.
 -->

## 2. Our solution, and why it wins

*Thesis: §1's gap is a join nobody owns, so we take the join as the
object of study — enumerate the worlds a binding is really delivered
into, realize each one while applying the agreements that must hold
there, and attribute a violation to the party whose claim it was. It wins not by checking
any single artifact better than the specialists do, but by being the
only thing that owns both sides of a join.*

<!-- what the solution is -->

- **The claim is composition, not absence.** The pieces exist —
  solvers, ecosystem mappings, FFI analyses, ABI checkers, rebuild
  infrastructure — and nothing connects them. Existing checkers become
  **backends**, not rivals; what is new is the thing that decides what
  to hand them, and what to make of the answer.
- **The method is three tiers, and each needs the one before it.**
  - **Enumerate** — decide *which* worlds are worth having, and build
    them. A world is not a description: it is realized, and the record
    of how it was realized — which provider, which build mode, which
    transform — is kept, because that record is what the third tier
    reads.
  - **Realize** — build the world and observe it. The agreements that
    hold there are applied as it is built: each a named relation over
    two surfaces carrying a falsifier, with the existing specialist
    checkers running underneath as backends.
  - **Attribute** — name the party. A violation is charged to the
    declaration, the provisioning, the pairing or the cooperation,
    read off the source of the claim rather than off whichever
    artifact happened to fail.

<!-- why it works: what each tier gives the next, and the oracle the
     first tier manufactures -->

- **Each tier is worth little alone, and that is the argument.** More
  worlds under an exit-code oracle finds almost nothing; a sharper
  check inside one world finds its bug once; a blame rule with no
  derivation behind it is a guess. §1's tools are strong precisely
  because each stays inside one tier.
- **Enumerating worlds manufactures an oracle that does not otherwise
  exist.** When a world holds two provisions of the same artifact —
  the same library from apt and from a source build — their
  disagreement is *itself* evidence, with no declaration needed to
  judge it. The blame then falls on neither artifact but on the
  **provisioning**. This is why the tiers are not independent: the
  first creates a source of belief the second can check against, which
  is exactly what a test matrix does not do.
- **Owning both sides makes the join checkable.** Every tool in §1
  stops because it is handed the other side; here both sides are
  chosen, so the pairing itself can be varied, mismatched
  deliberately, and held responsible.
- **Keeping the derivation makes blame possible.** A failure in a
  realized world is not just a red cell: the world knows which
  provider it drew from and which transition produced each artifact,
  which is what turns "this broke" into "this declaration was wrong".

<!-- the stance that follows from it -->

- **We show a bug is present; we never show one is absent.** Every
  failure reported is a real one, witnessed by a run or by a
  prediction grounded in a real tool, and we do not claim to have
  found them all.
- **Verification is unavailable here by nature, not by choice**: the
  tools are unspecified and partly behaviour-determined, so there is
  nothing to prove against.
- The consequence that shapes the rest of the paper: every agreement
  must carry a **falsifier** — a check that can exhibit a witness —
  rather than a proof obligation.

<!-- commentary: what is unsettled, and what it opens -->

- **The tier that is genuinely uncontested is the third.** Enumeration
  has partial prior art (rebuild infrastructure, HyperRes); realization and its checks
  have heavy prior art (`abicompat`, `abicheck`, FFI checkers, distro
  QA). Carrying a world's derivation far enough to blame a
  provisioning decision is the part no surveyed system does — so
  leading on worlds and checks alone leads with the two *contested*
  tiers and hides the one that is not.
- **Open**: from the tiers alone the method can look like a product
  with a test runner. The answers above — the manufactured oracle,
  owning both sides, the kept derivation — are the case that it is
  not, and they need one more argument from necessity: the ecosystem
  grows faster than anyone can track, so incompatibility is not
  avoidable by care.
- **The design space this opens** (softer, and unverified): a
  vocabulary for component-interaction faults that no tool currently
  names, and possibly guidance for new binding and FFI mechanisms.
- **Position and contribution** — where this sits, and the
  contribution list itself.

### Limitations

*Stated here rather than discovered by a reader — and every one of
them is a consequence of the stance above, not an accident of the
implementation.*

- **A pass certifies nothing.** A green result is bounded by what was
  observed, and that bound differs by depth: one artifact statically,
  two surfaces statically, an action's postcondition, the join
  actually happening, the program running. A full matrix of ticks
  means "no counterexample was found by these observations", never
  "compatible".
- **Practical, not exhaustive, and this bounds all three tiers.** The
  space of possible checks cannot be enumerated. We are
  mechanism-complete and material-naive: build and compile flags,
  distributions and libc variants are out of assumption unless a test
  names them. The error-prone build arguments are the near-term
  priority, not a solved case.
- **Two families are genuine gaps, not deferred work** — value
  representation (integer width, `NULL`/`None`, struct layout,
  ownership of returned pointers) and lifetime/ownership. No inspector
  here touches them. Other consumer languages, other producing
  languages and other object formats are *parameters* rather than
  gaps: the claims survive and only the instrument and the spelling
  change (§4).
- **Attribution is a model with two working instances, not a
  localizer.** Party-level blame is not implemented; what exists is
  the agreement that confirmed a failure, and direction (§5).
- **The results are bounded by the instruments.** Every claim rests on
  `nm`, `readelf`, `ocamlobjinfo`, `dir()` and their kin behaving as
  assumed — which is why they are themselves under test (§7), and why
  a gap in a tool becomes a gap here.
- **The enumeration is of worlds we can realize.** A world that cannot
  be built on the machine at hand is declared and not run, and the
  distinction between *does not exist* and *was not run* has to stay
  visible in the results or the coverage claim quietly inflates.

### Four objections, and the answer to each

- **"Isn't this `abicheck`?"** Closest prior art, and a candidate
  backend rather than a rival. The difference is deciding **which**
  cross-ecosystem artifacts should be compared at all, and tying the
  failure back to the packaging decision that produced the pair. If we
  only compare binaries someone else selected, this objection sinks
  the novelty.
- **"Isn't this HyperRes or the Package Calculus?"** They constrain
  the *conceptual* novelty of cross-ecosystem resolution and we should
  concede that plainly. But neither is deployed, and both stop before
  deployment realization — which is where we begin. The feedback loop
  from a realized counterexample back to a declared constraint is the
  extension they leave open.
- **"Don't FFI checkers already find these bugs?"** Yes, and we claim
  no new theory of FFI faults. The contribution is a common agreement
  interface that runs such checks inside systematically constructed
  worlds and combines their evidence with provenance, so a fault
  arrives with a party attached.
- **"Isn't this a rebuild farm?"** The honest difference is **not**
  oracle strength — modern ecosystems already embed artifact-level
  checks. It is the unit of exploration: they vary versions and
  reverse-dependents within one ecosystem or a curated universe,
  normalising foreign dependencies into their own package model, while
  here heterogeneous providers stay first-class and provenance is a
  deliberate experimental axis.

## 3 Practical enumeration

<!-- 
- A world is a choice of **provenance × version** (× platform) for
  every artifact in the chain: this library from the distribution,
  that one built from source, the binding pinned at a version its
  ecosystem happens to hold. The deployed set is far larger than the
  set any project tests.

- The chain runs through to a **consumer application**, because that
  is what reaches *use*; a world that stops at the binding cannot
  observe the failures §1 is about.

- **The worlds are a product, then pruned.** Five constraints do the
  pruning, and each exists because the raw product over-generated:
  coherence (is this world meaningful at all), declared coupling,
  a built binding matching its own source's channel, the collapse of
  worlds that differ only in a source nobody reads, and a prebuilt
  shadowing a same-cell source build.
- **What a run asks for is a separate question from what exists.**
  Selection narrows the enumerated set — a thin policy, or a named set
  of refs — so "this did not run" has two distinct answers: the world
  does not exist, or it was not asked for. Conflating them is how a
  matrix silently shrinks.
- **Identity decides what is the same world.** A fetched artifact is
  version-ambient — the package manager picks, so its declared version
  is not part of the world's identity — while a built or vendored one
  carries its version. Two worlds that differ only in an unobservable
  therefore collapse into one.
- **Order is a pass, not a sort.** Worlds are grouped by the store
  state each one locks, because the stores are exclusive resources: an
  opam switch holds one version of a package, an install prefix one
  copy of a library. The rule is *partition a place, serialize a
  state*.
- **A world lowers to a step list**, and the step list is the object
  code: the same list is executed locally, rendered as CI YAML, drawn
  as a diagram, or printed. Executing is one backend among four, not a
  privileged stage above them.
-->

<!-- 
- **One store interface over heterogeneous package managers.** apt,
  opam, pip, conda, a source build and a staged install prefix all
  answer the same questions, which is what lets provenance be a
  variable in the model instead of a fork in the code.
- **Every pass prints.** The declaration, the enumerated worlds, the
  selection, the run order and the realized steps can each be dumped
  without running anything, so a claim about the world set is
  inspectable rather than asserted.
- **Realization keeps its derivation** — which provider each artifact
  came from, which build mode, which transform — because that record
  is what tier three reads. A world that has forgotten how it was made
  can report a failure but cannot attribute one.
- **What exists today**: ten projects and their bindings, 42 declared
  worlds, 41 of them actually run. [status snapshot]

_Material: design/enumeration/ (one doc per pass); project/projects.md._
-->

## 4

<!-- _position-independent_ -->


<!-- ### 4.3 Artifacts, surfaces and observations

- Start with fixed artifacts available at known locations; defer how versions
  and package managers select them.
- Distinguish presence, identity and surface: finding a file does not establish
  that it is the intended artifact or offers the required interface.
- Introduce source and realized surfaces through the native provider: header
  declarations versus library exports and recorded metadata. “Semantic surface”
  means the observable realized interface, not full program semantics.
- Separate the agreement from its checking method. For each check, identify the
  reference expectation, evidence and falsifier; one agreement can have several
  observations. Example: exports versus a project declaration, or exports versus
  a consumer's recorded requirements.
- Explain the observation's limit: a successful build, a symbol comparison and
  a probe establish different facts. Observe early where possible; retain later
  observations where they add coverage.

*Material: [agreement design](../design/agreement/registry.md), §§1–2.* -->

## 5


<!-- why checking are hard
- **Provenance is not recoverable from the artifact.** Given a
  library, you cannot recover which agreement it once satisfied, nor
  predict the next. The method therefore inspects rather than looks up.
  
- **Declared surfaces are trusted but not verified**: the build
  succeeds if the header exists, whatever the binary actually
  provides.

- **Version beliefs are systematically wrong.** "I'm running libz3
  4.15.0" names a package manifest — not the soname the loader
  resolves, nor the constant the library itself reports.

- **A pass is never "compatible".** It is bounded by what was
  observed, and that bound differs by depth: one artifact statically,
  two surfaces statically, an action's postcondition, the join
  actually happening, the program running. Writing that bound beside
  each agreement is what stops a green matrix from reading as
  verified.

- **An agreement is a named relation over two surfaces**, stated as
  its own falsifier, naming the surfaces its witness is read from and
  the actions at which it can fire.
- **The agreement is not the check.** One agreement can be checked
  several ways and one mechanism can serve several agreements, so the
  catalogue names obligations, not implementations — which is what
  lets existing specialist checkers sit underneath as backends. 
-->

<!-- 

  - **Two axes, and they do not collapse.** WHAT is observed (one
    artifact against a claim · several artifacts compared · a tool
    invocation · a program execution) is independent of WHAT A PASS
    ESTABLISHES for each. Worth stating explicitly that a compiler's
    verdict is obtained by running something and is still a claim about
    structure — that case is why the two are separate axes rather than
    one. Your draft already has the solo/several half; the tool-vs-
    program half is the part not yet written.

  - **Every check needs an authority to disagree with.** Nothing is
    checkable in isolation — a library exporting 462 symbols is not
    wrong until something says 463. The source of the claim (self ·
    declaration · peer artifact · sibling world · prior version ·
    upstream statement · behavioural expectation) fixes two things at
    once: WHEN the check is available at all, and WHO is answerable when
    it fails. This is the bullet that carries §5 later.

  - **Availability is not guaranteed by existence.** A 2x2 holds
    SEPARATE worlds; one assignment picks one placement per artifact.
    Comparing sibling worlds needs an explicit correspondence and
    retained evidence from both — otherwise the source exists on paper
    and not in the run. (Design §1.6, and it qualifies the "enumeration
    manufactures an oracle" claim in §2.)

  - **Names.** Stable slugs; a family may implement several observations
    (solo and pair cells) without becoming several agreements. Language
    and mechanism are ARGUMENTS a check is instantiated at, never part
    of its identity — which is why §4.4 is a separate subsection rather
    than a column here.

  - **The catalogue as it stands** (2026-09-09, `canary checks`): twelve
    entries — **six wired** (symbol_exported, api_surface_complete,
    soname_denotes_needed, symbol_versions_present, c_types_agree,
    needed_names_provided), one blocked, two stubbed, three proposed.
    Say the boundary with the number: "wired" means an enabled predictor
    exists subject to applicable inputs, not that every language, action
    or provision is covered.

  - **Why explicit rather than complete** — your §4.1 already argues
    this and the glance should land it: whether a replacement artifact
    is compatible is not decidable, and no versioning scheme carries the
    invariants, so the catalogue's contribution is that each claim is
    NAMED and each has a falsifier — not that the list is closed. This
    is also where the reader is told §4.3-§4.7 walk the components.

  NOTE, numbers elsewhere in this draft are stale against the above:
  §4.7 and §7 still say five wired / four proposed / "thirty-eight
  checks across the three targets" (that table is gone, and §1.5 now has
  FOUR targets). Fix when you prose those.
-->

## 6

*Thesis: the three tiers together find real defects that none of them
finds alone, and the standard of proof is a repair upstream.*

- **Findings to date**, each with the agreement it violates, the world
  that exhibited it, and the party it is charged to.
- **The witness bounds the false-negative story.** Tiny perturbs one
  artifact at a time so that every artifact × action failure has a
  known-detectable case — the coverage argument for the *bad* side,
  and the check that the tiers compose as claimed.
- **Upstream repair is the evidence standard** — reported, and fixed.
  [to do: zero PRs filed]
- What a green matrix does *not* establish, restated from §4's
  depth-of-pass reading, so a table of ticks is not misread.

*Material: project/report_ncurses_libtinfo.md; project/issues.md;
../plan.md §4.*

## 7

- **The uniform artifact store**: a user may take an artifact from
  anywhere, so heterogeneous package managers are reduced to one store
  with a uniform interface — which is what makes the world enumeration
  implementable and extensible.
- **The tools are not themselves trustworthy**, so they are under
  test: if tiny's perturbation is detected we expect the same case to
  be detected in a real project, but that inference is only as good as
  `nm`, `readelf`, `ocamlobjinfo` and friends behaving as assumed.
- **Which agreements are grounded, published rather than claimed.**
  Twelve are declared; five have a working falsifier, one is blocked,
  two are stubbed, four are proposed. The wiring status is part of the
  honest picture, not an embarrassment to hide, and the tool prints it.
- **The registry is the layer the runner reads**, not a table beside
  it: a project's declared facts select the agreements, which select
  the inputs, which the steps carry. The per-project check tables
  converge onto it and are deleted.
- Inspector coverage, the agreement × mechanism bridge, and the
  per-language input templates.
- Implementation map: where each piece lives.

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
  §7 material. Author to read and decide.
- **Resource substrates** (registry §1.1–1.6) — filesystem, web, PM and
  extensible resources.
- **Cache behaviour** — explicitly outside the agreement model
  (registry §0.5).
- **Vocabulary threads** — static = early binding / dynamic = late
  binding; *compile or interpret* (one language's tool) versus *build*
  (several).
