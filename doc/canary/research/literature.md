# Literature — semantic preservation across language/binding boundaries

Working bibliography for `surface_theory.md`. Each entry includes a
short note on what the work *does* and what surface theory *inherits
from* or *departs from* it. Living doc; add as we read more.

Originating question (2026-05-13 session): "How does traditional
compiling handle semantic preservation, e.g. an OCaml or Python `int`
mapping to LLVM IR `iN` or x86-64 GPRs?" The answer points at four
families of techniques, all of which assume *one designer owns the
whole pipeline*. Surface theory is what's left when that assumption
fails.

## 1. Verified compilation (operational refinement)

The textbook approach: state a relation `R` between source and target
states, prove forward simulation pass-by-pass, conclude that the
observable trace of the compiled program refines the source.

- **Leroy, X.** "Formal verification of a realistic compiler." *CACM*
  52(7), 2009. — CompCert. Cminor → RTL → LTL → Mach → x86, every
  pass simulated in Coq. C `int` flows through as `Vint(n)` with the
  simulation relation preserving observable trace.
- **Kumar, R., Myreen, M.O., Norrish, M., Owens, S.** "CakeML: A
  verified implementation of ML." *POPL 2014*. — End-to-end verified
  ML compiler down to machine code, including the tagged-int
  representation.
- **Ševčík, J. et al.** "CompCertTSO: A verified compiler for
  relaxed-memory concurrency." *JACM 2013*. — Extends CompCert with a
  weak-memory model. Relevant if surface theory ever models concurrent
  artifacts.

**Inherits:** the idea that a "behavior layer" check is really a
refinement-of-observable-trace check.
**Departs:** verified compilation owns every pass. Surface theory's
Behavior layer can't prove refinement — only test it at runtime.

## 2. Type-preserving compilation (TPC)

Types from the source ride through every IR. Ill-typed translations
are syntactically rejected. Semantic preservation gets a stronger
form: well-typed source → well-typed target → progress + preservation
end-to-end.

- **Tarditi, D. et al.** "TIL: A Type-Directed Optimizing Compiler for
  ML." *PLDI 1996*. — Early TPC for SML.
- **Morrisett, G., Walker, D., Crary, K., Glew, N.** "From System F to
  Typed Assembly Language." *TOPLAS* 21(3), 1999. — TAL. Types all the
  way down to assembly.
- **Chlipala, A.** "A certified type-preserving compiler from lambda
  calculus to assembly language." *PLDI 2007*. — Mechanised TPC.
- **GHC Core** (Peyton Jones et al., various). — Production-grade
  typed IR; closest to a working multi-pass TPC.

**Inherits:** the Type layer of surface theory is the right
descendant of TPC's per-name type discipline. An `.mli` digest
plays the role of an IR-level type stamp.
**Departs:** TPC's types are written by one author. The OCaml binding
author and the C library author are different people; the Type-layer
check is *cross-author* type matching, not within-compiler preservation.

## 3. Representation discipline (no proof, just convention)

Ad-hoc rules that have been tested into stability. No theorem; the
preservation lives in the test suite.

- **MLton, OCaml native backend.** — `int` is `(value << 1) | 1` so
  the GC distinguishes immediates from pointers. Arithmetic uses
  native 63-bit ops; overflow is ignored. Comparisons mask the tag.
- **CPython.** — `int` is a `PyLongObject*` — heap-allocated big-num.
  `BINARY_ADD` dispatches to `long_add`, which carries between limbs.
  "Preservation" is enforced by `Lib/test/test_long.py`, not a proof.

**Inherits:** most real-world `int`-to-machine translations are this
kind, not the verified kind. The Type layer of surface theory should
not assume formal proof exists upstream.
**Departs:** these implementations are still *within one team*. In
packaging, the equivalent rules (tag layout, overflow semantics) are
implicit contracts between independently maintained components.

## 4. JIT / runtime type specialization

Sidestep static translation by observing values at runtime.

- **PyPy** (Rigo, Pedroni, Bolz, et al.). — RPython's tracing JIT.
  Observes a Python `int` loop stays in int31 for many iterations;
  emits specialized x86 with an overflow guard that bails to the
  interpreter on promotion.
- **V8** (Google). — Hidden classes, inline caches, TurboFan. Same
  philosophy for JS `Number`.

**Inherits:** the idea that some compatibility properties are
*dynamic* — checked at every call, not proven once. Surface theory's
runtime canary is a coarse cousin: check at execution time, fall back
if a guard fails.
**Departs:** JITs control the guard *and* the deopt path. Surface
theory's runtime check just observes pass/fail, with no deopt — if
the probe fails, the user gets an error message.

## 5. Multi-language semantics — directly relevant

Two language fragments must agree on representations at a boundary.
This is the closest classical analogue to "OCaml binding ↔ C
library."

- **Matthews, J., Findler, R.B.** "Operational semantics for
  multi-language programs." *POPL 2007*. — Boundary terms `MO(e)` and
  `OM(e)` between two languages with explicit conversion semantics
  and proven type soundness across the boundary.
- **Patterson, D., Perconti, J., Dimoulas, C., Ahmed, A.** "FunTAL:
  reasonably mixing a functional language with assembly." *PLDI 2017*.
  — Mixes a functional language with TAL via well-typed boundaries.

**Inherits:** the conceptual framework. Surface theory's
provider/consumer split is the multi-language boundary with the
languages being "C ABI" and "OCaml binding ABI."
**Departs:** Matthews-Findler and FunTAL both *design* the boundary
typing. Surface theory has to *check* a boundary that already exists
and was authored without coordination.

## 6. Compiler-correctness meta-theory

What does "the compiler is correct" even mean when source and target
types disagree?

- **Patterson, C., Ahmed, A.** "The next 700 compiler correctness
  theorems." *ICFP 2019*. — Catalogues the design space: contextual
  equivalence preservation, fully-abstract compilation, source-level
  reasoning preservation. Argues different settings need different
  notions.

**Inherits:** the framing. Surface theory needs to state *which*
correctness property it's checking at each layer (Symbol = name
preservation, Type = signature preservation, Behavior = trace
preservation). Patterson-Ahmed give the vocabulary.
**Departs:** their notions are all "the compiler preserves X." Ours
are "the cross-team chain preserves X." The proof obligation
becomes *checking* rather than *proving*.

## 7. Linking calculi (module-theoretic)

The "linking is a formal operation" line.

- **Cardelli, L.** "Program fragments, linking, and modularization."
  *POPL 1997*. — Foundational. Linking as substitution; modules are
  explicit fragments with import/export interfaces.
- **Flatt, M., Felleisen, M.** "Units: Cool modules for HOT
  languages." *PLDI 1998*. — First-class, mutually recursive linking
  units; later became Racket's unit system.
- **Glew, N., Morrisett, G.** "Type-safe linking and modular assembly
  language." *POPL 1999*. — Lifts TAL to multi-module assembly with
  cross-module type checks at link time.
- **Rossberg, A., Russo, C., Dreyer, D.** "Mixin' Up the ML Module
  System." *TOPLAS 2014* (MixML). — Generalises ML modules to permit
  mutual recursion across compilation units.

**Inherits:** direct ancestors of Type / API layer reasoning *when one
designer owns both ends*. Cardelli's "linking is substitution" is the
clean model.
**Departs:** the C/OCaml binding world *fails to live up to* this
model because `ld` doesn't substitute typed fragments — it
pattern-matches symbol names with no type information.

## 8. Java dynamic linking semantics

Surprisingly deep formal line because the JVM has runtime
classloading + binary-compatibility rules baked in. The closest formal
cousin to what surface theory is trying to do for ELF.

- **Drossopoulou, S., Eisenbach, S.** "Java is type-safe — probably."
  *ECOOP 1997*. — First formal soundness for Java with classloading.
- **Liang, S., Bracha, G.** "Dynamic class loading in the Java
  virtual machine." *OOPSLA 1998*. — Operational model of the
  classloader; verified linking semantics.
- **Drossopoulou, S., Wragg, D., Eisenbach, S.** "What is Java binary
  compatibility?" *OOPSLA 1998*. — Formalises *exactly* which source
  changes preserve binary compatibility in the JVM model.

**Inherits:** Drossopoulou-Wragg-Eisenbach is the single most relevant
prior formalisation. They define binary-compatibility predicates over
class-file changes; surface theory wants the same for ELF symbol-table
changes.
**Departs:** ELF's contract is much weaker than class files — no
method signatures in the symbol table, no constant pool, no version
field per entry. Surface theory has less to work with at the binary
layer.

## 9. ELF / dynamic-linker semantics

Most lives in systems / books, not POPL — but Stephen Kell's line of
work is the formal exception, and the closest single cite for the
Symbol and ABI layers.

- **Kell, S.** "Towards a dynamic object model within Unix processes."
  *Onward! 2015*. And his thesis: **"In search of types"** (2017). And
  **Kell, Mulligan, Sewell, et al.** "Towards a formal semantics for
  ELF dynamic linking." — Treats the dynamic linker + ELF + libc as a
  (degenerate) runtime type system.
- **Levine, J.** *Linkers and Loaders.* Morgan Kaufmann, 1999. — The
  canonical reference; semi-academic, but the only place where ELF /
  Mach-O / PE semantics are stated together.
- **Drepper, U.** "How to write shared libraries." 2011. — Practitioner
  reference; necessary reading for any rigorous ABI-layer claim.

**Inherits:** Kell's framing — `nm` / `readelf` / `ld.so` as a type
system — *is* surface theory's framing for Symbol + ABI. He plants the
flag; surface theory extends it across language bindings.
**Departs:** Kell's work is mostly process-internal (one running
program's dynamic-linker state). Surface theory is cross-installation
(does *this* installed `.so` satisfy *this* binding).

## 10. FFI / cross-language semantics

When two languages must agree at a binary boundary. Overlaps with §5
(multi-language semantics) but emphasises *checking* the boundary
rather than designing it.

- **Furr, M., Foster, J.S.** "Checking type safety of foreign function
  calls." *PLDI 2005*. — Static type-checking of OCaml's FFI to C.
  Detects mismatches between C type and OCaml `external` declaration.
  Closest precedent for the Type layer.
- **Furr, M., Foster, J.S.** "Polymorphic type inference for the JNI."
  *ESOP 2006*. — Same line for Java.
- **Tan, G., Morrisett, G., et al.** "JNI light: An operational model
  for the core JNI." *APLAS 2010*. — Formal operational semantics for
  JNI.
- **Patterson, D., Garg, N., Ahmed, A.** "Semantic Soundness for
  Language Interoperability." *PLDI 2022*. — When does compiling two
  languages with an FFI preserve semantic equivalence? Recent and
  directly relevant.
- **Patrignani, M., Devriese, D., Clarke, D.** "On modular and
  fully-abstract compilation." *POPL 2016* and follow-ups. — Secure
  compilation: what must be preserved at the linker boundary against
  an *active* attacker.

**Inherits:** Furr-Foster is the most direct precedent for the Type
layer — they're doing OCaml-FFI Type-layer checking, just with a
different name and on a smaller scale.
**Departs:** Furr-Foster requires the C source to be available; we
work post-binary. Patterson-Garg-Ahmed assumes both compilers are
co-designed; we don't.

## 11. Compositional / verified linking

Adding linking to verified-compilation frameworks. Shows that *even
with a verified compiler*, the linking step needs its own preservation
theorem.

- **Stewart, G., Beringer, L., Cuellar, S., Appel, A.W.**
  "Compositional CompCert." *POPL 2015*. — Adds separate compilation +
  linking to CompCert; proves semantic preservation across linked
  units.
- **Song, Y., Cho, M., Kim, D., Kim, Y., Kang, J., Hur, C.**
  "CompCertM: CompCert with C-Assembly Linking and Lightweight
  Modular Verification." *POPL 2020*. — Extends Compositional CompCert
  with mixed C/assembly linking.

**Inherits:** the proof-of-concept that the *linker* needs its own
contract, separate from the compiler's. Surface theory's Symbol /
ABI layers are exactly that contract.
**Departs:** Compositional CompCert co-verifies both compilers and
the linker. Surface theory accepts that no one verified anything and
checks the linker contract empirically.

## 12. Empirical ABI / binary-compatibility tooling

Tool / empirical papers — the baselines a PLDI track would need to
beat or complement.

- **Seketeli, D.** *libabigail* (Red Hat, ongoing). — `abidiff` and
  `abicompat`; computes ABI changes between two shared libraries.
  Production-grade; the obvious baseline for surface theory's Symbol /
  SymbolVersion / ABI checks.
- **Foo, D., Yip, S., Zhong, J., et al.** "Efficient static checking
  of library updates." *ESEC/FSE 2018*. — Empirical study of API/ABI
  break detection at scale.
- **Lam, P., Dietrich, J., Pearce, D.** "Putting the semantics into
  semantic versioning." *Onward! 2020*. — Empirical study of SemVer
  vs. actual API-break behavior. Sister study to surface theory's
  coverage map.

**Inherits:** the empirical motivation. Lam-Dietrich-Pearce is the
"SemVer is a lie" study; surface theory is what to do once you accept
that.
**Departs:** these tools operate one library at a time. Surface
theory crosses the language-binding boundary, which is where the
existing tooling's coverage map ends.

## Honest gaps in this literature

- **No one formalises the cross-team boundary itself.** Every formal
  paper either owns both sides (verified compilation, TPC,
  Compositional CompCert) or assumes the binary interface is a known
  specification (Drossopoulou for Java). Nobody models "the OCaml
  binding author *believes* the C library has symbol `foo` of type
  `int → int` and is wrong" — which is the actual failure mode in
  packaging.
- **ELF semantics is folklore.** Kell is the closest, but there's no
  published "ELF dynamic linker = this small-step relation" the way
  there is for the JVM. Partly opportunity (surface theory could plant
  a flag), partly hazard (no shoulders to stand on).
- **Versioning across schemes is unstudied formally.** SemVer has
  formal-ish work (Lam-Dietrich-Pearce); SONAME drift is folklore;
  opam version constraints have practical work (opam-deps,
  opam-monorepo); none of these meet up.

## Thread tying these to surface theory

Classical compilation gets semantic preservation by **owning the
pipeline**. CompCert authored every pass; MLton authored every pass;
CPython authored both bytecode and C runtime. The argument is
*internal* — the designer chose the IR types, the calling convention,
the GC interface, the tag layout, and proved (or stress-tested) the
chain end-to-end.

Package management splits the pipeline across teams:

```
C library author  →  C header author  →  OCaml stub author  →
opam packager  →  distro packager  →  end user
```

No one is "the compiler." The translation from `Z3_int` (C `int`,
32-bit signed) to OCaml `int` (63-bit tagged) is *declarative* — it
lives in the stub file as a few lines of `Z3_mk_int` taking `int` in
the `.mli`. Whether the stub author's belief about the C side is still
true at runtime is exactly what surface theory's Type / SymbolVersion
/ ABI checks try to *check* — because it can no longer be *proved*.

| Classical compilation     | Surface theory                                      |
| ------------------------- | --------------------------------------------------- |
| Forward simulation proof  | Behavior layer — runtime canary, no proof           |
| Type-preserving IR        | Type layer — `.cmi` digest / header parse           |
| Calling-convention design | ABI layer — SONAME / NEEDED inspection              |
| Symbol-table linkage      | Symbol layer — `nm -D`                              |
| GC tag layout (within)    | (no analogue — outside surface theory's scope)      |
| JIT speculation + guard   | Runtime canary's pass/fail dichotomy (no deopt)     |

**Slogan for the paper.** Classical compilation gets semantic
preservation by *proving* what it owns. Package management has to
*check* what it doesn't own. Surface theory is the discipline of
turning a cross-team binding into a checkable contract — degrading
"prove" to "check post-hoc" along every layer that's already escaped
the compiler's control.

The linking / ABI side (§§7–12) gives the second half of the
ancestry: Cardelli's linking-as-substitution is the clean model;
Drossopoulou-Wragg-Eisenbach show what binary-compatibility checking
*looks like* when the interface is well-specified (Java class files);
Kell shows that the ELF analogue is degenerate but real; Furr-Foster
and Patterson-Garg-Ahmed cover the FFI boundary; Compositional
CompCert proves the linker step needs its own contract.

## Open follow-ups

- Read Patterson-Ahmed (ICFP 2019) in full; it likely structures §9 of
  `surface_theory.md` better than the current ad-hoc related-work.
- Read Drossopoulou-Wragg-Eisenbach (OOPSLA 1998) in full and compare
  their JVM binary-compatibility predicates to what's checkable at the
  ELF level. Likely a paragraph in §9 and possibly a worked example
  in §1.
- Track down Kell's "Towards a formal semantics for ELF dynamic
  linking" draft; if cite-able, it's the strongest precedent for the
  Symbol + ABI layers.
- Look up Krishnaswami-Pradic-Tabareau on "interaction trees" — there
  may be a runtime-side analogue worth citing for the Behavior layer.
- Check what's been written on **ABI stability** in the C++ community
  (Vandevoorde's "ABI" talks, Boost.SmartPtr ABI breaks). Practitioner
  literature; useful empirical grounding for §10 hidden-deps.
- libabigail's design docs — extract the algorithm they use for
  `abidiff` and compare to surface theory's `Predict`. Likely
  baseline-comparison fodder for the PLDI track.
