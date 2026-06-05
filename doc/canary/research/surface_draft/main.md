# Surface theory — artifact records and compatibility

> **Role (2026-06-04 onward).** This file is the **materials
> collection** — older drafts, longer derivations, alternative
> phrasings — to be mined from when prose in the manuscript
> doc ([`surface.md`](surface.md)) demands content. It is *not*
> the authoritative writeup; structure and confirmed framing
> live in `surface.md`. Where this file and `surface.md` disagree
> in vocabulary or framing, `surface.md` wins (per the
> "few-to-one source of truth" principle). Code citations
> below may be stale; verify against the codebase before
> repeating.

> **Structural reorg (2026-06-04).** Top-level partition is now
> by content-kind: **Part A** motivation & empirics, **Part B**
> theory primitives, **Part C** contracts & derivations, **Part D**
> principles, **Part E** extensions, **Part F** pointers & context.
> Existing §0..§6 numbering preserved at `###` level inside Parts
> for cross-reference stability — code and other docs that cite
> "§2.7" still resolve. §2.6 (actions/phases) moved to Part E;
> §2.7 (implementation pointers) moved to Part F; §2.8 and §2.9
> moved to Part C (alongside §2.4, §2.5).

think about the title and the scope of the paper

### For introduction and motivation

**problem**
Real-world projects with multiple languages bindings are ubiquitos and critical, e.g. torch, llvm, z3.
They are very error-prone because
- they have to interact with tools and many-layers of systems
  - many tools and systems are not specified and updates frequently
  - the whole systems are very flexible, while package managers can update random components of them
- it involves many people and machine, while people (project developer, package maintainer, register admin) have limited knowledge of itw own domain knowledge
- blaming is chanllende
- t.b.c (I found I have an old write-up in doc-pkgm, which may need updating)

**solution**
we observe the existing tools are behavior-based, while the actions are based on the chaining of all the involved tools. These tools are usually best-effect, which mean some flaws may have to be found in later staged.

we estabilish a series of construct including
- a surface theory which covers all components by their beharios believes and contracts, that tools reply and use. serving as rules and inviants. like a spec space
  - we see the widely used c-api based approach as a theory instance (one spec), and as a theory (rule,metarule) it can also support ctypes, rust ffi, .... we don't go deep in the project
- tiny is a pivot (canary/smoke) testing for tools and systems
  - for all the involved langauge, system, package management tools (we missed this in code), binding mechanism, as well as compiling and linking, loaders, since running is the ultimate checking, we need a mechanism-complete but material-naive examples
  - if tiny works for both the positive and negative cases, it means any concrete traces align well withe the surface theory.
  - for practicality, we can never test e.g. all compileing flags, linux release, so this is out of our assumptions if not explicit tests
- canary actions is to apply the tiny template for real-workd packages
  - we can see here only three components are needed. the standalone tiny and canary tiny's problem is not meaningful to audiences


### 5. Relationship to other theories

- **SemVer and version constraints.** Version numbers are coarse
  proxies for surface compatibility. The surface model refines them:
  two artifacts with the same version number may present different
  surfaces (different PMs, build configs); two artifacts with
  different version numbers may be surface-compatible (symbol
  subset unchanged).
- **Type systems for linking.** Surface theory plays the role of a
  *gradual type system* for binary interfaces: Symbol is untyped
  name matching; Type adds structural typing (via `.cmi` digest /
  header parse); Behavior would be full behavioral specification.
  The progression is gradual in granularity, not a single linear
  chain.
- **Nix / reproducible builds.** Nix ensures the *same* artifact is
  produced from the same inputs. Surface theory checks whether
  *different* artifacts (same library, different PM/version) are
  compatible. Complementary guarantees.

A fuller bibliography lives at [`literature.md`](literature.md),
covering verified compilation (CompCert, CakeML), type-preserving
compilation (TIL, TAL, GHC Core), linking calculi (Cardelli,
Flatt-Felleisen, MixML), Java dynamic-linking semantics
(Drossopoulou-Wragg-Eisenbach), ELF semantics (Kell), FFI semantics
(Furr-Foster, Patterson-Garg-Ahmed), and ABI tooling (libabigail).

## Part F — Pointers & context

*Implementation map (which file does what), relation to other
theories, and the calculus direction. The most stale-prone part
of this materials doc — code citations may drift.*

### 6. Toward a typed calculus

The long-term goal is a **typed calculus of artifact composition**.
Artifact records (§1) are values; surface roles (§2.1) are types;
the build / compile / link / pack / install operations canary
already wraps are typed transformers:

```
fetch   : Package(PM) → Source
build   : Source → Native × Headers
compile : Native × Headers → Binding(L)
pack    : Binding(L) → Package(PM')
link    : Binding(L) × Native → App
install : Package(PM) → Path

Γ ⊢ compile(native, headers, strategy) : Binding_record(L)
  where strategy ∈ {stub, ffi, jit, bindgen}
```

Transformers are *partial*: `build` fails if the source is
misconfigured; `compile` fails if the native interface doesn't
satisfy the binding's expectations; `link` fails if symbols are
missing or SONAME mismatches. Canary today wraps each transformer
with pre/post inspections; the formal version would type-check the
composition statically.

The syntactic surface is the **declared type** — what the developer
wrote. The semantic surface is the **inferred type** — what the
inspector extracts. A well-behaved build pipeline satisfies:

```
inferred_type(artifact) <: declared_type(artifact)
```

When this fails — the inferred type is *weaker* than the declared
type — there is a gap that either the toolchain or the theory must
explain. The verification angle: if each transformer has a type
signature (pre-surface → post-surface), the composition can be
checked *before* running a full build. A mismatch (e.g. a libffi
dependency that won't be satisfied at load time) becomes a type
error at the artifact level rather than a probe failure at runtime.

This is the direction roadmap step 4 starts to enable: as
inspectors and comparators land (c4..c8), the contract checks
become real predicates over typed surface roles, and per-transformer
type-checking becomes a tractable static analysis.

---

## Appendix: Raw draft inputs from the manuscript (2026-06-04)

> Moved here from the top of `surface.md` on 2026-06-04 as part of
> the materials/manuscript discipline. These are the user's raw
> framing notes that fed the §0 BB Motivation absorption pass.
> Spelling and grammar are preserved as the original draft;
> reference for prose drafting, not authoritative content.