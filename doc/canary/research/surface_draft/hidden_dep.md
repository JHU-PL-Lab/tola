### 4. Hidden dependencies

Not all dependencies appear in the syntactic surface (s1
`native_header`). Some are injected by the build system or the
binding's implementation strategy, visible only in the semantic
surface (s2 `native_lib`):

```
LLVM 19 binding NEEDED:  libffi.so.8, libedit.so.2, libzstd.so.1
LLVM dev binding NEEDED: (none of these)
```

These three libraries are not declared in any LLVM header, CMake
file, or opam dependency. They are pulled in by the 19 build's
specific configuration — libffi for the OCaml binding's runtime,
libedit for the debugger, libzstd for compression. The dev build,
configured differently, doesn't need them.

#### 4.1 Why hidden dependencies matter

A binding author writing a probe expects to link against
`libLLVM.so`. They don't expect the probe to fail because
`libffi.so.8` is missing — they never asked for it. Yet the NEEDED
section of the 19 build's ELF tells a different story: the probe
will not load without it.

This is a **hidden dependency** — a semantic requirement with no
syntactic declaration. The surface model makes it visible because
the semantic extractor (`inspect_native.py` on `n4` `lib_native.so`,
via `readelf -d`) captures NEEDED unconditionally, regardless of
whether any human documented the dependency.

#### 4.2 Hidden C-runtime dependency: glibc vs. musl

The libffi case is about a *named* hidden dependency that appears in
NEEDED. There is a subtler version: the **C runtime** itself. A
library compiled against glibc 2.31 carries versioned symbol
requirements:

```
$ nm -D libz3.so | grep -E 'malloc|cxa_throw'
  U malloc@GLIBC_2.17
  U __cxa_throw@GLIBC_2.3.4
```

A system running glibc 2.17, or running musl libc (which doesn't
implement `@GLIBC_*` versioning at all), cannot satisfy
`malloc@GLIBC_2.31`. In our model this is a **SymbolVersion**
contract violation (§2.4); it's also an **ABI** identity question
(which libc is loaded). The information is present in the artifacts
the whole time — `@@VER` annotations on the libc, `@VER`
requirements on the consumer.

This case is *especially silent at build time*: a binary built on
Ubuntu 20.04 compiles, links, and tests fine; it only fails when
shipped to a host with an older or different libc. A wired `c5
cmp_sym_version` plus libc identification on the host would catch
this class end-to-end. Today canary has the inspector half (the
`versioned_req` / `versioned_exports` fields emitted by
`inspect_native.py` on `n4`) but not the comparator — see §2.7's
comparator-only-gap group.