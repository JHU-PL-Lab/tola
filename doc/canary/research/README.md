# `doc/canary/research/` — surface theory and the `tiny` example

Entry point for the surface-theory write-up. Three documents, one
purpose each. Read this README first, then the doc whose pillar you
care about.

## The four pillars

The work is organised around four aligned views of the same problem:

| #   | Pillar       | Question it answers                                                                          | Lives in                                             |
| --- | ------------ | -------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| 1   | **Theory**   | What are the surfaces, contracts, and what counts as a violation?                            | [`surface_theory.md`](surface_theory.md) §§0–2.6, §6 |
| 2   | **Witness**  | Is there a minimal artifact that instantiates every surface and every contract reproducibly? | [`tiny.md`](tiny.md)                                 |
| 3   | **Coverage** | Which contracts does canary check, with which inspector + comparator?                        | [`surface_theory.md`](surface_theory.md) §2.7 alignment table |
| 4   | **Plan**     | What changes — to canary, to tiny, to docs — close the remaining coverage gaps?              | [`plan.md`](plan.md) (venues + milestones + roadmap) |

The alignment is *load-bearing*: every contract named in Theory
appears in Witness as at least one scenario, in Coverage as a row in
the inspector/comparator tables, and in Plan as a step toward closing
its gap.

## The three documents

### [`surface_theory.md`](surface_theory.md)

The abstract framework. Defines the **six surface roles** (`s1
native_header`, `s2 native_lib`, `s3 binding_stub`, `s4 binding_header`,
`s5 binding_lib`, `s6 runtime_trace`), the **eight contracts**
(Type, Symbol, ABI, SymbolVersion, API-repacking, API-completeness,
API-faithfulness, Behavior), the **inspector** (`i*`) /
**comparator** (`c*`) split, and the §2.7 coverage table that maps
each contract to the canary-core machinery checking it today.
Packaging and co-providers are §3 (a section, not a sibling doc).

This is the document a reader new to the project should start with.

### [`tiny.md`](tiny.md)

The concrete witness. A two-function, one-global C library with three
hand-written bindings (OCaml cstubs, Python CPython C extension,
Python ctypes) and eight deliberately-broken scenarios — one per
contract violation. Holds the file-level spec, the build
instructions, the per-scenario detail with stage tables, the
coverage matrix, and the findings from building it.

This is the document a reader who wants to *touch the code* should
read alongside the theory.

### [`plan.md`](plan.md)

Paper venues + milestones + working roadmap, in one doc. Tracks
which conference we're aiming at (OOPSLA primary; PLDI / POPL
optional), what's needed by each deadline, and the five-step
alignment of theory / tiny / canary. §6 is the working roadmap with
status checkboxes; step 1 (unified vocabulary) and step 2 (packaging
as a §3 section, not a separate doc) are done; steps 3–5 are live.

## What about packaging?

It's a section in `surface_theory.md` (§3 "Packaging and
co-providers"), not a separate file. If that section grows large it
graduates to its own doc; for now the entire model lives in one
place.

## Companion bibliography

[`literature.md`](literature.md) collects related work in compiler
correctness, type-preserving compilation, linking calculi, ELF
semantics, FFI semantics, ABI tooling. Each entry has an "Inherits
/ Departs" note tying it back to surface theory.

## Companion bibliography

[`literature.md`](literature.md) collects related work in compiler
correctness, type-preserving compilation, linking calculi, ELF
semantics, FFI semantics, ABI tooling. Each entry has an "Inherits
/ Departs" note tying it back to surface theory.

## What was here before

Earlier design write-up `../design/api_surface.md` is retired —
content folded into `surface_theory.md` (theory + implementation
pointers + glibc/musl case) or deferred to packaging
(`package_theory.md`, future). If you arrive at a cross-reference to
that file, the redirect goes through this README.
