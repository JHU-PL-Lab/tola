## Part D — Principles

These are not axioms in a formal system but design constraints the theory
must satisfy. They are falsifiable: if the implementation violates one, the
theory needs revision or the implementation needs fixing.

### P1. Observational

Every property in an artifact record must be extractable by a
deterministic, read-only inspection of the artifact on disk. No property may
require execution, network access, or knowledge of how the artifact was
produced. This is what makes static inference sound: two inspectors looking
at the same artifact see the same record.

### P2. Decomposed into contracts

Compatibility is decomposed into independent contracts (§2.4), each
pinning a specific pair of surfaces. Contracts may be
refinement-ordered (e.g. SymbolVersion ⊑ Symbol) or parallel (e.g.
Symbol and ABI are orthogonal). A contract failure pinpoints which
surface pair disagrees; in general it does *not* imply failure of
other contracts. This makes blame precise: "the SONAME is wrong" is a
different diagnosis from "a symbol is missing," and neither says
anything about whether the user-facing API was correctly repacked.

### P3. Black-box

Build systems, compilers, and package managers are treated as black boxes.
The theory models their *input/output relation* on artifact records, not
their internal logic. This makes the model portable across toolchains: cmake
and bazel are different black boxes but the record types are the same.

### P4. Covariant providers, contravariant consumers

A provider with *more* symbols, *higher* version tags, or *more*
modules is always substitutable for one with fewer. A consumer that
*needs* fewer symbols or *tolerates* more versions is compatible
with more providers. The §2.4 contracts encode this directly: each
comparator's set-inclusion direction (e.g. `c1 cmp_symbol` checks
`consumer.requires ⊆ provider.symbols`) is the
covariance/contravariance dial for one contract.

### P5. Surface preservation

A syntactic surface that cannot be verified against a semantic
surface is a documentation claim, not a checkable property. Every
syntactic claim the theory tracks must have a corresponding semantic
extractor (or a clear argument for why one cannot exist). This is the
closure that makes blame possible: if a failure occurs and no
contract predicted it, the contract list is incomplete.

### P6. PM uniformity

The record types are independent of how the artifact was obtained.
`nm -D` produces the same record structure whether the `.so` came
from `apt`, `cmake --build`, or a pip wheel. This is what enables
the provider matrix (§3): the same library from different PMs can
be compared at the record level.
