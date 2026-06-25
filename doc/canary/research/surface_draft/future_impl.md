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