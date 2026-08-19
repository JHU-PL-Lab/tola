# Agreement catalogue — what we can check, by artifact, mechanism, and bug

> 2026-08-18. A companion to [`contract_registry.md`](contract_registry.md):
> the registry is the MODULE (rows, firing, fixtures); this is the
> CATALOGUE (which agreements exist and where each is checkable). Split
> out because it grows along different axes — mechanism lifecycles and
> real-world bugs — and it is the material the registry's cells get
> filled FROM.

## 0. Terminology — "agreement" is the umbrella (user, 2026-08-18)

`invariant`, `contract`, and `agreement` are all in use for the same
idea. The preferred umbrella is **agreement** (it is also the
manuscript's term — ssot §3's `Ag.X`); `contract` survives in the code
as `contract_id`/`contract_row`, `invariant` in prose. **Unification is
a later task** — it rides with the canonical-naming settle (M2 step 10),
where the `c1..c8` index is replaced by names derived from the
artifact-surface / action primitives. Until then the three words mean
the same thing here, and no code is renamed.

## 1. The regression-driven ladder — the mindset (user, 2026-08-18)

The catalogue is populated the way a regression suite is: **from real
bugs, backwards**. For each issue found in the world:

1. name the AGREEMENT it violated;
2. find the EARLIEST place that violation is observable;
3. record which place we actually check today.

The ladder, cheapest/earliest first — a bug should be caught as far up
as it can be:

| rung | place | evidence | example of what it catches |
|---|---|---|---|
| 1 | **one artifact, statically** | inspect that artifact's surface, compare to the declaration | a declared symbol missing from the built lib; a soname that is not the declared one; a build-tree path baked into a staged binary |
| 2 | **two declarations, statically** | pair two artifacts' surfaces without running anything | the binding's stub references a symbol the lib does not export; header types vs the wrapper's declared types |
| 3 | **one action's postcondition** | the action produced what it must | the install did not stage a declared file (#10549); a fetched package is not at its pinned version |
| 4 | **the meeting** | the compile/link/load either accepts the pairing or refuses | an ABI shape the static surfaces cannot express; a loader failure from a broken NEEDED closure |
| 5 | **the run** — last resort | execute and observe | behaviour changes with identical surfaces; ordering/timing; anything the four rungs above cannot express |

Two rules follow:

- **Escalate only when forced.** A bug catchable at rung 1 must not be
  left to rung 5: a run-time failure is slower, flakier, and blames
  less precisely.
- **A rung-5-only bug is a finding about the FRAMEWORK**, not just
  about the project — it names a surface we do not yet inspect. Those
  are the entries that generate new agreements.

The collection itself (real bugs → agreement → rung) is future work;
`project/status_project.md` holds the bug list to mine.

## 2. The lib — beyond symbols

Symbols are the best-developed family; two others are open and
substantial.

### 2a. Symbols (developed)

Exports vs declared API (c1), versioned symbols (c5), the soname (c4),
and the coarse `readelf -sW` shape. See the registry's §8b lib-only
cells.

### 2b. Paths — the biggest untouched family

Every stage of a lib's life is mediated by a path mechanism, and they
differ per platform. The inventory (to be developed WITH the user's
pre-existing study, which predates this work and should be brought in
before designing cells):

| kind | Linux/ELF | macOS/Mach-O | where it bites |
|---|---|---|---|
| loader search | `LD_LIBRARY_PATH`, `/etc/ld.so.conf`, `ldconfig` cache | `DYLD_LIBRARY_PATH` (stripped by SIP for protected binaries) | which lib actually loads — a system copy can shadow the built one |
| embedded search | `DT_RPATH` / `DT_RUNPATH` (`-Wl,-rpath`, `LD_RUN_PATH`) | `LC_RPATH` + `@rpath` / `@loader_path` / `@executable_path` | a build-tree path baked into a staged artifact (the portability falsifier) |
| identity | `DT_SONAME` | `LC_ID_DYLIB` / install_name | what dependents record; must be the INSTALLED identity |
| language-side | `CAML_LD_LIBRARY_PATH` (OCaml stublibs), `PYTHONPATH`, `OCAMLPATH` | same | the binding's own artifacts, not the C lib |
| build-time discovery | `PKG_CONFIG_PATH`, `LIBRARY_PATH`, cmake prefix paths | same | which headers/libs the BUILD picked — often not the ones we think |
| tool lookup | `PATH` | `PATH` | which compiler/linker/tool ran at all |

Known trap classes to turn into agreements: `DT_RUNPATH` does NOT
apply to transitive dependencies (unlike `DT_RPATH`) — a lib that
works standalone can fail as a dependency; ordering/shadowing between
a system lib and a built one; `LD_LIBRARY_PATH` ignored for
setuid/setgid; macOS install_name that must be patched AFTER the move.

### 2c. Hidden dependencies

Things `nm` on the lib does not reveal:

- **transitive `NEEDED`** — a dependency of a dependency that must be
  present at load;
- **`dlopen`'d plugins** — resolved by name at run time, invisible to
  static inspection (this is exactly what the ctypes/cffi mechanisms
  ARE, so the binding side has the same shape);
- **symbol interposition** — another loaded object providing the same
  symbol first (LD_PRELOAD, link order, a system copy);
- **weak symbols and default version resolution** — which definition
  wins when several exist.

These are the natural home for the interposition-shim RECORDER idea
(observe what is actually requested/resolved at load) — see the
registry's blame axis.

## 3. Per-mechanism lifecycles

"The lib" above implicitly means the **C lib**. Once `lang × mechanism`
is in play, each mechanism has its OWN artifact chain and its own
agreements. This is the second group of tables; sketches, to be filled
the same way (from real bugs, up the ladder).

### 3a. Cstubs (OCaml, `Static_c_abi`)

| stage | artifacts | agreements |
|---|---|---|
| build stub | `*_stubs.c` → `.o` → `lib<pkg>_stubs.a` (+ `dll<pkg>_stubs.so` for bytecode) | the stub compiles against the header (types); the archive's undefined refs ⊆ the lib's exports |
| build OCaml | `.cmi/.cmx/.cmxa/.cma` | the `.mli` surface is what the package claims; module names survive dune's wrapping convention |
| link | linkopts inside the `.cmxa` | the recorded `-L`/`-l` resolve OUTSIDE the build tree (the `$CAMLORIGIN/../..` trap) |
| install | ocamlfind layout, `META` | `directory`/`archive(native)`/`requires` describe the real layout; `dll*_stubs.so` lands in the switch's `stublibs` |
| use | `CAML_LD_LIBRARY_PATH`, RPATH | the stub `.so` that loads is THIS package's (a stale one in the switch shadows it) |

### 3b. Cext (Python, `Static_c_abi`)

| stage | artifacts | agreements |
|---|---|---|
| build | `_native.c` → `_native.<EXT_SUFFIX>.so` | the `EXT_SUFFIX` matches the interpreter that will import it (ABI tag + version); `PyInit_<name>` exists and matches the module name |
| link | NEEDED + RPATH of the extension | the C lib is resolvable from the extension's own search path |
| package | `__init__.py`, wheel metadata | the user-facing surface is the package's, not the extension's |
| import | the load meeting | no unresolved symbol at import; the right interpreter |

### 3c. Ctypes / Cffi (Python, `Dynamic_ffi`)

| stage | artifacts | agreements |
|---|---|---|
| (no build) | pure `.py` | — the absence of a build stage is itself the point: no build-time falsifier exists |
| load | `dlopen` by name | the declared soname/path resolves at import |
| call | `argtypes`/`restype` declarations | the DECLARED types match the C signatures — checkable only against the header: this is the prime consumer-side case for the carried type oracle (registry §8c) |
| failure mode | per-call resolution | a missing symbol surfaces at FIRST CALL, not at import — so coverage of the declared API determines what is caught at all |

### 3d. Dynlink (OCaml, `Dynamic_ffi`) — not wired

`.cmxs` plugin loading; the same shape as 3c (load-time resolution, no
build-time falsifier).

## 4. How this feeds the registry

Each table row above is a candidate CELL: an agreement + the artifact
whose surface carries the evidence + the action where it is observable
(the ladder rung). Filling the registry = promoting rows from here into
`contract_registry.md`'s matrix with a falsifier fixture attached.
