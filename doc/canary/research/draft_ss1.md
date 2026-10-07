## 1. The problem

**The claim.** This is a bug-finding framework, not a verifier: it 
does not prove a deployment
sound, it exhibits real failures in one. It works in three
operations — **enumerate** the worlds a binding is actually deployed
into, **realize** each one while keeping the record of how it was
built, and **attribute** a violation back to the declaration or
transition that produced it, with the agreement registry supplying the
checks applied inside each world. The evidence is real defects,
reported and fixed upstream.

*Thesis: a language binding is assembled by many parties out of many
tools, each of which checks its own step and takes the rest on trust.
So the agreements between steps are never checked by anyone, and a
defect made in one place is found in another, long afterwards, and
charged to the wrong party.*

<!-- the setting: who builds this, and where they meet -->

- Multi-language bindings are ubiquitous and critical, and the chain
  that delivers them crosses tools and people no one specified together.
- Defects are therefore quirky, surface late, and get blamed wrong.
- **The chain spans actors**: the upstream library developer, the
  binding author (on-tree or off), maintainers in several package
  managers, an administrator, and an end user. Each sees one hop, and
  no one sees the chain.
- **Packaging is where those actors meet.** It is what delivers and
  distributes the software, so it is also where their cooperation has
  to hold. The end user starts from a *package* — never from the
  source the developer wrote, and rarely from the combination the
  binding author tested.

<!-- what holds the chain together, and why it is fragile -->

- **The chain rests on a mixture of agreements.** A few are specified;
  more are conventions; many are purely **behavioural** — true only
  because a compiler, a linker or a loader happens to act that way.
  None of them is owned by the party on the other side of the join.
- **The only oracle in use is a successful command**, and it is weak
  twice over. It is narrow: violations that some tool enforces get
  rejected, while everything merely *tolerated* passes green until
  usage finally touches it. And it is unfaithful: a linker may
  silently drop a version script, a build may not re-run, an install
  may skip a rule — all of it reported as success.

<!-- why the failures land late, and on the wrong party -->

- **A defect is a property of the package *and* the use.** Different
  end uses touch different parts of a surface, so a deployment that is
  healthy under one user's usage is broken under another's. This is
  why checking has to reach the run and cannot stop at the build.
- **Management latency puts distance between cause and symptom.** The
  packaged binding lags the library it wraps, so a defect enters
  upstream and surfaces downstream — long after shipping, and far from
  the party who could fix it.
- Together these make binding packages **error-prone to produce, hard
  to test, and hard to attribute** once something breaks.

### What already exists, component by component

<!-- the honest survey: each component HAS a checker; each stops at
     the same boundary -->

- **The native library.** Consumers rest on its exported symbols, its
  soname, its version nodes. This is the best-served component:
  `abidiff`, `abicompat` and the newer `abicheck` compare a library
  against a consumer, and Debian's symbols machinery and
  Fedora/openSUSE ABI QA run such checks routinely. They compare the
  two binaries they are handed, and never ask which two a user will
  actually have.
- **The foreign interface** — the binding's stubs and declarations.
  Per-language analyses exist (Jinn, TurboJet, FFIChecker, Python/C
  checkers), as do the generators (SWIG, `bindgen`, cffi). Each covers
  one language's protocol, and a generator validates against the
  header it was given rather than the library that will be loaded.
- **The binding's user-facing API** — what the repacking presents
  upward. Essentially only the binding's own test suite covers it, and
  a test suite exercises what its author thought to exercise, in the
  one configuration its author had.
- **Versions and dependency constraints.** Every ecosystem ships a
  resolver — opam, pip, conda, dose3 — and cross-ecosystem resolution
  now has research systems too: HyperRes, and the Package Calculus.
  The deployed resolvers decide what *may* be installed together from
  **declared metadata**, never whether the installed artifacts fit;
  the research systems model resolution and stop, deliberately, before
  anything is realized.
- **Where each artifact came from.** SBOM formats, SLSA and
  reproducible builds record provenance faithfully. Provenance answers
  *where it came from*, which is a different question from *does it
  fit*.
- **The realized deployment, and the run.** Ecosystems run substantial
  rebuild-and-test infrastructure — autopkgtest, conda-forge
  migrators, opam bulk builds, `cibuildwheel`, `auditwheel`,
  `rpminspect`. Each explores within one ecosystem, at the versions
  that ecosystem chose, normalising foreign dependencies into its own
  package model.
- **The two package managers, by side:** apt and brew on the system
  side, opam and pip on the language side (page §3.1).
- **Where they meet:** a bridge, or nothing (page §3.3). opam's conf-*
  packages and depexts are bridges; pip bundles the library instead.
  Cargo's `*-sys` crates meet through a capability file and no bridge.
  That contrast left the page and belongs here or in §8.

<!-- the payoff: why none of it closes the three properties above -->

- **Every partial answer stops at the same boundary: it takes the
  other side as given.** The library checker is handed its consumer;
  the FFI checker is handed its library; the resolver hands over
  metadata and stops; the rebuild farm fixes the ecosystem and varies
  inside it. The defect lives in the join, and the join is the one
  thing no party owns.
- **The asymmetry is one of adoption, not only of ideas.** Everything
  that became production infrastructure is *local* — `auditwheel` and
  manylinux, `cibuildwheel`, opam `depexts`, conda-forge migrators,
  Debian archive QA, `rpminspect`, libabigail. Everything
  compositional is a prototype or an emerging standard. A correct
  compositional check therefore helps nobody today, because nothing
  runs it in the world the user gets.
- **So a binding can fail while every local subsystem behaved
  correctly by its own contract.** The questions nobody asks are the
  compositional ones: which header did the binding actually observe,
  which implementation did its package manager intend, which provider
  did the build select, which one did the runtime finally load, and
  does the declaration the binding carries match that provider?

_Material: draft_old.md §Motivation; the courtesy paragraph;
related/canary-practical-cross-language-bindings-report.md §§2–5, 9–10;
related/adoption-in-practice.md (the adoption asymmetry)._
