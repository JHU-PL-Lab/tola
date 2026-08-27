### 3. Packaging and co-providers

The surface model's six roles (§2.1) describe what an artifact
*presents*; they say nothing about *which* artifact populates a
role. Packaging is the sibling concern that picks the concrete
artifact: apt vs. opam vs. pip vs. source-build, system vs.
vendored, one version vs. another. Because P6 holds (record
uniformity across PMs), the contracts in §2.4 compare cleanly across
cells of a **provider matrix** indexed by `(PM, version, binding
language)`.

The compatibility matrix for a library is:

```
Compat(Lib) = { ((pm, v), (l, r_prov, r_cons)) |
                (pm, r_prov) ∈ Providers(Lib, v),
                r_cons ∈ Consumers(Lib, l),
                contracts in §2.4 all satisfied between r_prov and r_cons }
```

Each cell is a canary action: fetch provider, fetch binding,
compile, run, check contracts.

#### 3.1 Co-providers

Some packages **bundle** their own copy of the native library — the
canonical examples are `llvmlite` (bundles libLLVM) and the
`z3-solver` pip wheel (bundles libz3). The outer package is a
**co-provider**: it carries a Native record (s2 `native_lib`)
*inside* a Package record. The bundled native is inspectable just
like a system-provided one; if `libz3.so` from `apt` and the bundled
`libz3.so` from the pip wheel present different surfaces, a binding
may work against one but not the other.

The §2.3 static/dynamic axis interacts with co-providers: a dynamic
binding (`tiny_ctypes`-style) would normally rely on a system
libtiny, but a co-provider model would bundle libtiny inside the
Python wheel. `tiny` deliberately *doesn't* exercise co-providers —
packaging is sibling, not foundational, and we want the witness to
isolate the surface contracts (see [`tiny.md`](tiny.md) on why
packaging stays out of scope).

#### 3.2 Status

The provider-matrix angle is deferred work — the model is sketched
above but not used in canary's per-action checks today. See
[`plan.md`](../../plan.md) (roadmap step 2) for the rationale and the
deferral plan.