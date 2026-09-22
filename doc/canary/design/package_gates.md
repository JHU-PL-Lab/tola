# What does a successful package install actually establish?

> A question for discussion, not a decision. Written 2026-09-21 for
> readers outside this project: it assumes you know package managers and
> linking, and assumes nothing about canary. The measurements are real
> and reproducible; the questions at the end are genuinely open.

When `opam install zarith` exits 0, something has been established. The
interesting question is *what*, exactly — and our answer, after
measuring, is **less than almost anyone assumes**. For six of the eight
projects we have instrumented, a successful install establishes that a C
header was present on the machine. Not its version, not which copy, not
that the library the binding links is the one the dependency check found.

This document sets out the mechanism, what we measured, and the four
checks we think are recoverable — and then asks for help with what we have
not settled.

---

## 1. What canary is, in four paragraphs

Canary is a dependency-testing framework. It takes a C library with
language bindings — OCaml and Python today — and *enumerates the worlds
that library can be in*: built from source at a dev ref, installed from
the system package manager, staged into an install prefix, fetched as a
prebuilt, at each of several versions, crossed with each binding's own
provenance and version. It then runs the real build and probe actions in
each world and records what happened.

The point is the *cross* cells. A binding built against library version A
and run against version B is where dependency bugs live, and the
combination is usually unreachable through normal tooling, because the
package manager exists precisely to stop you from constructing it. Canary
constructs it deliberately. One of our projects reproduces a real ABI
break this way: an OCaml binding built from z3's HEAD requires 776 `Z3_`
symbols, and the system's libz3 4.8.12 exports 705 — 85 missing, found
from recorded evidence rather than from a crash.

The machinery is a six-pass pipeline (declare · analyse · enumerate ·
select · order · realize) that lowers a project's declaration into a
`step list`, which is then consumed by backends: one executes locally,
others render CI YAML, diagrams, or HTML. Everything before the last pass
is pure and world-free.

Sitting on top is what we call the **agreement layer** — the part this
document is about. It is the vocabulary for saying what a run has
actually shown.

## 2. The one concept you need: what an "agreement" is

This is canary's central idea and the rest of the document depends on it.

Think of an action — compiling, linking, installing, resolving — as a
function `A : I₁ × … × Iₙ → O`. It embodies a relation `R_A` over its
inputs: the tuples it accepts. A C compiler accepts (source, header)
pairs that typecheck together; a linker accepts (object, library) pairs
where the symbols resolve; a package solver accepts (package, world)
pairs satisfying the declared constraints.

**Running the action is the only witness that a tuple is in `R_A`.** And
the moment it finishes, the tuple is discarded. Only a *projection* of it
survives in the output — the built artifact, the installed package, an
exit code.

So an **agreement** is: *a necessary condition for membership in some
action's input relation, decidable from what survived.* It is always a
post-hoc reconstruction of a rule some real tool already enforced.

Three consequences we lean on constantly:

- **A passing agreement never means "compatible."** It means one
  necessary condition holds. Sufficiency would require re-implementing
  the tool.
- **An agreement needs a root** — a real tool whose rule really ran. If
  no tool ever enforced the relation, there is nothing to recover, and
  the claim is waiting on somebody to *state a specification*, which is a
  different and much harder kind of work. In our registry, the three
  claims with no evaluator are exactly the three with no root. That is
  not a coincidence; it is the theory predicting which work is blocked.
- **Two kinds of loss, with different ceilings.** *Identity* loss (which
  tuple was it?) closes exactly, by recording more. *Relation* loss (what
  did `R_A` require?) only ever converges.

Concretely: we have 13 implemented claims, 8 of which are "landed" — a
real project's real run has decided them `holds` or `violated`. Passing a
synthetic fixture does not count.

## 3. The mechanism under discussion: opam's `conf-*` packages

For readers outside the OCaml ecosystem.

An OCaml package that binds a C library cannot install the C library
itself — that is the system package manager's job. opam bridges this with
**virtual `conf-*` packages**. `zarith` (arbitrary-precision arithmetic,
binding GMP) declares a dependency on `conf-gmp`, and `conf-gmp` does two
things:

- **A check.** Its `build:` field runs a predicate against the system. For
  `conf-gmp.5` that is, in full:
  `pkg-config --print-errors --exists gmp || cc -c $CFLAGS -I/usr/local/include test.c`
  where `test.c` is a tiny file that includes `gmp.h`, fetched from
  opam's source archives with a checksum. It is a *presence* test, and it
  installs nothing.
- **A mapping.** Its `depexts:` field maps the virtual package to a
  per-distro system package name: `libgmp-dev` on Debian, `gmp` on
  Homebrew, `gmp`+`gmp-devel` on Fedora, and so on.

That is the whole mechanism. `flags: conf` marks it as config-only.

The structural consequence is the one that matters here: **a version
constraint on the conf package is not a version constraint on the C
library.** `conf-gmp`'s own opam version (5) tracks the *packaging* of the
check, not GMP. A binding that declares `conf-gmp {>= "4"}` has said
nothing whatsoever about which GMP may be installed — unless the conf
package's own check enforces a version, which it usually does not.

We measured how often it does, across every conf package's newest
revision in the opam repository: **13 of 370 (3.5%)**, by two mechanisms —
eight carry a hardcoded `pkg-config --atleast-version` predicate (all
floors), and five pass opam's own `version` variable into a discovery
script (all generation pins, e.g. LLVM). For the other ~357, the declared
bound is over packaging and the real freedom is *any version you can
obtain*.

## 4. What that looks like in our own projects

We declare each binding's gate as typed data, in a vocabulary that
distinguishes the shapes. The `tracks_lib` flag records whether a declared
bound actually reaches the C library.

| project | declared gate | real freedom | does the bound reach the library? |
|---|---|---|---|
| zarith | `Free_with_conf conf-gmp` | any version | no gate — presence only |
| cairo | `Free_with_conf conf-cairo` | any version | no gate |
| sqlite (OCaml) | `Free_with_conf conf-sqlite3` | any version | no gate |
| ssl | `Free_with_conf conf-libssl` | any version | no gate |
| zlib | `Free_with_conf conf-zlib` | any version | no gate — build is `pkg-config zlib` |
| libffi | `Bounded_with_conf conf-libffi >= 2.0.0` | **any version** | **no — the bound is over packaging** |
| zstd | `Bounded_with_conf conf-zstd >= 1.3.8` | within bound | **yes — `--atleast-version=1.3.8`** |
| llvm | `Fixed_with_conf conf-llvm-shared = 19` | wrapper needed | **yes — an exact generation pin** |
| z3 | `Package_builds_lib` | no pairing | n/a — the package builds the library |
| torch | `Pinned_depext libtorch >=2.1.0 <2.2.0` | wrapper needed | n/a — no conf hop, a direct depext |
| sqlite (Python) | *none* | — | n/a — CPython's stdlib; no PM in between |

**Eight of ten go through a conf hop, and six of those eight have no
effective version gate at all** — for those six, a successful
`opam install` establishes that a header was present and nothing more.
Only zstd and llvm carry a bound that reaches the library.

libffi is the most instructive row. It declares `conf-libffi {>= "2.0.0"}`
— which looks like a careful lower bound until you notice that libffi
itself is at 3.x, and that `conf-libffi.2.0.0`'s entire build is
`pkg-config libffi`. The constraint is real, well-formed, respected by the
solver, and constrains nothing about the library.

The last row is worth keeping in view for a different reason: Python's
`sqlite3` is a CPython stdlib extension, so no package manager stands
between the binding and libsqlite3 at all. The coupling is still real —
whoever built the interpreter chose a libsqlite3 — but there is no
declaration anywhere to check against. "No gate" and "no gate *mechanism*"
are different situations.

## 5. Three findings about our own instrumentation

Not about opam — about us. Each is uncomfortable in a useful way.

**(a) The gate declaration has no reader.** We built the typed vocabulary,
populated it across every project from the survey, and wrote a derivation
(`combination_freedom_of`) that answers "how hard is it to force a
combination this gate would refuse?" Nothing calls it outside the test
that asserts the values are what they are. No agreement reads it, no
pipeline pass reads it, the static spec auditor does not look at it. The
survey landed as a well-typed declaration that nothing consumes.

This is the second instance of the pattern for us. The first runs the
other way: our inspector has extracted Mach-O's `compatibility_version`
field since the macOS port and no check reads it. **Evidence with no
reader there; a declaration with no reader here.** Both are cheap to
close and both sat unnoticed for the same reason — nothing fails when a
value is merely unused.

**(b) We never exercise the gate.** Every opam install canary issues
carries `--assume-depexts`, which tells opam not to verify system
dependencies. This is *correct* for what canary does: canary has already
provisioned the library deliberately, possibly to a version the gate
would refuse, and letting opam second-guess the constructed world would
defeat the experiment. But the consequence is real — we surveyed 370 conf
packages and have never once run the mechanism. We tell opam "trust me"
and never record whether we were trustworthy.

**(c) Five projects hand-transcribe `opam show` output into comments.**
Our specs carry prose like *"`opam show camlzip --field=depends` → a bare
`conf-zlib`, no constraint"*, some dated and marked CONFIRMED. That is
useful provenance and it is also a hand-maintained copy of a machine-
readable fact, which drifts silently when upstream edits their metadata.
We have a standing rule against exactly this — a table the tool generates
does not get a hand copy — and here it is, five times, at a level where
the rule had not been applied.

## 6. The checks that look recoverable

Each has a real tool whose rule really ran, which by §2 is the
precondition for being recoverable at all.

| claim | asserts | rooted in | what is missing |
|---|---|---|---|
| **declared gate matches the package** | the gate we declare is the one the package's metadata declares | opam's solver, reading `depends:` | record `opam show <pkg> --field=depends` as evidence |
| **the gate bounds the library** | a declared bound really reaches the C library | the conf package's own build predicate | record `opam show conf-X --field=build` |
| **the gate admits the world** | the world we constructed would satisfy the gate, if opam were asked | opam's solver *and* the conf predicate — both deliberately bypassed | the library's version (already recorded) plus the gate |
| **discovery matches the link** | the library a discovery mechanism answers with is the one the artifact links | the linker, at binding-build time | record what `pkg-config` answered |

The third is the one we find most interesting, for three reasons.

It has a **live falsifier on the machine this was written on**. LLVM's
gate is an exact pin to generation 19 (`conf-llvm-shared {build & = "19"}`),
and this box has three generations installed side by side — `llvm-18`,
`llvm-19`, `llvm-24`. A world declaring 18 or 24 installs perfectly well
under `--assume-depexts`, and the gate would have refused both. No special
setup, no second machine, and the discriminating evidence — which
generation this world actually provisioned — is already recorded.

It is **the cross-package-manager question stated in one sentence**: does
what the *system* package manager provisioned satisfy what the *language*
package manager would accept? Those are two independent authorities over
one artifact, and nothing today asks whether they agree.

And it **makes an existing bypass honest** rather than adding a new
obligation. We already decided to skip the check; this records what
skipping it cost, per world. That is a better shape than a new rule.

The fourth claim also has a falsifier from our own history, which we
recorded at the time as a bug in canary rather than as an instance of a
claim: one project's library-probe resolved the library with
`pkg-config --variable=libdir` in *every* world, including the worlds that
built their own. Every recorded inspection named the system copy. We
deleted the override and moved on. It is exactly the phenomenon this claim
names — a discovery mechanism answering differently from what the world
intends — and we had the failure without having the claim.

## 7. The open questions

This is the part we would like other eyes on.

**7.1 Is "the gate admits the world" one claim or two?** The gate is a
conjunction of two independent predicates enforced by two different
tools: opam's *solver* checks the version constraint in `depends:`, and
the conf package's *build script* checks the system. They fail for
different reasons, are fixed by different people, and a world can satisfy
one and not the other. Splitting them doubles the rows; merging them
produces a verdict whose cause is ambiguous. We have split claims before
when the second side differed, and it has always been right — but that
was about *what is compared*, not *who enforces it*.

**7.2 Static audit or run-time agreement?** "Declared gate matches the
package" could live in our static spec auditor, which deliberately runs
offline and needs no world. But answering it needs a live opam switch,
which breaks that guarantee. As a run-time agreement it needs an
inspector that records the metadata, and then it rides the world — which
the third claim needs anyway. We lean toward the agreement form, but the
static form would catch drift much earlier, before anything is built. Is
there a principled line here, or is it a trade?

**7.3 Does a claim about a *declaration* deserve the same status as a
claim about an *artifact*?** Our kinds already accommodate this — one
landed claim compares an artifact against a project's declared API, and we
classify it by what it asserts rather than by what the second side is. But
the gate claims are a step further out: they compare *one declaration*
(ours) against *another declaration* (upstream's package metadata), with
no artifact involved on either side. Every tool involved really ran, so
§2 admits them. It still feels like a different kind of thing, and we are
not sure whether that feeling is informative or just unfamiliarity.

**7.4 Is "constrains nothing" a finding or a design choice?** Six of our
eight conf-mediated projects declare a dependency that bounds no library
version. We are inclined to report that as a gap. But zarith's
maintainers are not careless: GMP has held `libgmp.so.10` since 6.0, so
the flexible regime is *correct* for that library, and a bound would be
noise. A check that flags all six would be reporting on the ecosystem's
deliberate policy, not on a defect. What distinguishes a correctly
flexible gate from an under-specified one — and can that distinction be
decided from evidence, or does it need a human judgment the framework
should merely surface?

**7.5 What would make this generalize past opam?** The shape — a language
package manager with a constraint language that cannot express what its
artifacts actually require, bridged to a system package manager by a
mapping somebody maintains by hand — is not specific to OCaml. Python's
wheels, Rust's `-sys` crates, and Ruby's native gems each have their own
version of it. We would like the vocabulary to survive the move, and we
are not confident the current one would.

## 8. Reproducing any of this

The numbers in §3 come from a script that reads the opam repository
directly and regenerates the tables in our survey; it is in the repo as
`doc/canary/raw/conf_version_carriers.py`. The per-project gates in §4 are
typed values in each project's specification, not prose. The claims in §6
are stated against a registry of 13 implemented agreements whose current
status is generated rather than written down.

Within this repository: the conf mechanism and the position it prompted
are in [`../surveys/conf_mechanism.md`](../surveys/conf_mechanism.md); the
full classification of every conf package is
[`../surveys/conf_packages.md`](../surveys/conf_packages.md), with §G1a
holding the version-carrier measurement. The agreement theory sketched in
§2 is [`agreement/theory.md`](agreement/theory.md). The three parked
research directions, of which this is the second, are
[`directions.md`](directions.md), and current state is
[`../status.md`](../status.md) §2.5.
