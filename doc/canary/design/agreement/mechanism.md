# Mechanisms — what a binding IS, and which claims it can carry

**Kind: reference.** The two axes a binding world varies along, what
each one decides about applicability, how a project declares its side of
it, and the open question the catalogue exists to make askable.

**Why this is in `agreement/`** (moved 2026-09-17, user: *"given the
agreement for mechanism is more close to agreement, how about put it in
the agreement"*): the mechanism catalogue's decidable fields exist to
answer *can this project carry this claim* — they are read by
`m_applicable`, and nothing else dispatches on them. A mechanism's
relationship to agreements is the mechanism's most load-bearing
property, so it belongs beside the claims rather than in the general
design bucket.

> Merges `design/mechanism.md` (the catalogue, 2026-08-05) and
> `design/mechanism_payload.md` (the typed declaration, 2026-08-13),
> both retired here. 412 lines → this. What was cut: the M2 sequence
> checklist (all landed — `git show` the originals), the runner_spec
> absorption map (a plan that executed), and the per-mechanism prose
> that the generated catalogue now prints.

## 1. Two axes, and only one of them is modelled

A binding world has a consumer and a provider, and both vary.

| axis | values | in the code |
| --- | --- | --- |
| **consumer mechanism** | `Cstubs` `Cext` `Ctypes` `Cffi` `Dynlink` | `Canary_mechanism.mechanism`, with a `mechanism_info` row each |
| **provider linkage** | shared `.so` / static `.a` | **nothing** — see §3 |

`discipline` (`Static_c_abi` | `Dynamic_ffi`) is the coarse projection of
the first axis, and it is what the ENUMERATION ranges over: it decides
whether a `Build_binding` stage exists at all. The mechanism name is the
finer label under a discipline.

```
          static (linked into the app)   dynamic (dlopen at runtime)
  OCaml   cstubs                          Dynlink / .cmxs
  Python  cext (compiled .so)             ctypes / cffi
```

## 2. The three decidable facts — why the agreement layer reads this file

`mechanism_info` carries prose (coupling, check points) and three
booleans. **Only the booleans are dispatched on**, and each turns a
group of agreements on or off:

| field | asks | what it gates |
| --- | --- | --- |
| `mi_compiles_a_stub` | is there a compiled artifact whose undefined references ARE the requirement set? | `required_symbols_exported` |
| `mi_consumer_records_needed` | does that artifact record WHICH library it needs? | `soname_matches_requirement`, `required_versions_exported`, `dependencies_provided` |
| `mi_exposes_typed_stub` | is the boundary spelled where a signature can be read? | `signatures_agree` |

**The field that the one-bit approximation got wrong.** Before these
existed, the families used `is_dynamic` — and cstubs and cext share a
discipline while differing on the middle field: a `.a` records no
`DT_NEEDED` and no `SONAME` (those appear when the executable is
linked), while a cext is a `.so` that records both. One bit cannot say
that, and four families were guessing.

| | lang | discipline | stub? | records NEEDED? | typed stub? | wired |
| --- | --- | --- | --- | --- | --- | --- |
| `Cstubs` | OCaml | static | ✅ | ✅ *(via the linked executable)* | ✅ | yes |
| `Cext` | Python | static | ✅ | ✅ | ❌ *(no extractor — a canary gap, not a mechanism one)* | yes |
| `Ctypes` | Python | dynamic | ❌ | ❌ | ❌ *(types are values)* | yes |
| `Cffi` | Python | dynamic | ❌ | ❌ | ✅ *(a cdef re-declares the C surface)* | no |
| `Dynlink` | OCaml | dynamic | ❌ | ❌ | ❌ | no |

`Cffi` is the row worth remembering: the one dynamic mechanism with a
typed boundary, which is why "dynamic ⇒ nothing to read" is wrong as a
rule.

## 3. The provider axis, which does not exist yet

> 2026-09-17, user: *"I wish the mechanism can cover more binding cases
> including `{c-static-lib, c-dynamic-lib} × ({ocaml-binding-via-c-stub,
> ocaml-binding-via-dynlink} + {python-cstatic, python-ctypes})`."*

**A static provider turns off the same agreements a dynamic consumer
does, and for the same reason** — nobody recorded a dependency. Today
only the consumer half is a value.

`Canary_artifact.api_component` already distinguishes `Link_lib` (the
`.so` symlink **or** the `.a`) from `Runtime_lib` (the versioned `.so`,
*"absent for static linking"*). So the fact is encoded as *which
components a provider declares* — a shape nothing enumerates over.

The tooling is closer than the model: `inspect_binding.py --kind stub`
already reads both forms, because the consumer's stub comes in both —
`["nm", "-D", path] if is_shared else ["nm", path]`.
`Canary_artifact_native.nm_cmd`, the provider side, hardcodes `nm -D`.

### What a static provider changes

| agreement | shared `.so` | static `.a` |
| --- | --- | --- |
| `declared_symbols_exported` | `nm -D` | `nm` over the archive — same comparison |
| `required_symbols_exported` | unchanged | unchanged |
| `api_names_present` | unchanged | unchanged |
| `staged_interface_preserved` | unchanged | unchanged |
| `soname_matches_declaration` | reads `SONAME` | **no SONAME exists** → `not_applicable` |
| `soname_matches_requirement` | consumer records `NEEDED` | **nothing recorded** — the symbols were absorbed |
| `declared_versions_exported` | ELF version nodes | **none** |
| `required_versions_exported` | consumer's version refs | **none** |
| `dependencies_provided` | `NEEDED` vs providers | **the question moves**: the static lib's own deps become the CONSUMER's, transitively and silently |

### Every cell of the 2 × 4

The user asked for all of them, not just the impossible one. Two
questions per cell — *can it exist*, and *what does it mean* — and the
answers are not symmetric.

| | **cstubs** (OCaml) | **dynlink** (OCaml) | **cext** (Python) | **ctypes** (Python) |
| --- | --- | --- | --- | --- |
| **shared `.so`** | ✅ **wired** — most of the roster | ⬜ **possible, unwired.** A `.cmxs` links against the `.so`; `Dynlink` loads the `.cmxs`. Two dynamic levels, and the mechanism's own is the outer one | ✅ **wired** — sqlite | ✅ **wired** — z3, llvm. `CDLL` opens the `.so` by name |
| **static `.a`** | ⬜ **possible, unwired.** `ocamlmklib` absorbs the archive into the stub archive; the executable records nothing about the lib | ⚠ **possible and strange.** The `.cmxs` statically embeds the archive, so the *library* is static while the *binding* is dlopened. Two copies if two plugins embed it | ⬜ **possible, unwired.** The extension `.so` absorbs the archive; it records no `NEEDED` for the lib and every other `NEEDED` becomes its own | ❌ **IMPOSSIBLE.** `CDLL` calls `dlopen`, and an archive has nothing to open. Not unwired — refused |

Reading the grid:

- **Three cells are wired and all three are shared.** Canary has never
  tested a static provider at all, on any mechanism.
- **`ctypes × static` is the only impossible cell**, and the reason is a
  property of the mechanism (`dlopen` needs a load-time object), so the
  enumeration should REFUSE it with that reason rather than let a
  project report `unavailable` forever.
- **`dynlink × static` is the interesting one.** It is the only cell
  where "static" and "dynamic" are both true at different levels, and it
  is where a duplicate-implementation question becomes real: two plugins
  each embedding the archive means two copies of the library's state in
  one process. That is `no_duplicate_implementation`, one of the three
  standing proposals — **this cell is its specimen**, and canary has no
  other.
- **The three unwired-but-possible cells are cheap** and differ only in
  the provider inspection plus the four `not_applicable`s above.

### What landing it needs, in order

1. **A value in base** — `linkage = Shared | Static` on the native
   artifact. `canary_store`/`canary_artifact` vocabulary; the agreements
   dispatch on it, they do not own it.
2. **`nm_cmd` reads it** instead of assuming `-D`.
3. **Per-agreement applicability**, mirroring the consumer's three
   fields: `provider_records_needed`, `provider_carries_version_nodes`.
4. **An enumeration constraint** refusing `ctypes × static`, with the
   reason in the message.
5. **A witness** — a `libtiny.a` beside tiny's `libtiny.so.1` is one
   CMake target, and every admissible cell gets a controlled specimen.

**Do 1–3 before 4**: once linkage is a value, the refusal is derivable
from the catalogue (`Ctypes` needs a runtime carrier; `Static` provides
none) rather than hand-written.

## 4. How a project declares its binding

One record, and the split is the point: **facts are what the binding
IS** (stable — removing a field changes the binding); **analysis is what
canary checks** (watchlists, probe choice) and stays on canary's side.

```ocaml
type binding_decl = {
  mechanism    : Canary_mechanism.mechanism;  (* the identity label *)
  c_api        : c_api;      (* functions, enums — what it wraps *)
  native       : native;     (* prefix, soname, headers *)
  coupling     : coupling;   (* the ONE variant point *)
  surface_path : string;     (* the user-facing file: tiny.mli, __init__.py *)
}

type coupling =
  | Stub_archive of { sources : string list; archive : string }  (* cstubs *)
  | Compiled_ext of { source : string; product : string }        (* cext *)
  | Dlopen of { name : string }                                  (* ctypes/dynlink *)
```

A project **references a mechanism by name and never inlines its
facts**. The artifact identity carries it (`A_binding (lang, mech)`);
`canary spec` prints the per-binding mechanism line by reading the
catalogue, not the project.

**Three stages, and only the middle one is optional.**

1. **Declare** — the record above. Universal and mandatory: it is what
   applicability reads.
2. **Build** — `Canary_binding_templates.build_recipe`, derived from
   the facts where the mechanism determines them, `Raw` where it does
   not. **An external project's build command is respected as-is** —
   subtle command-line details are bypassed, not fixed; only in our own
   fork may we modify one. `pr_raw_build_overrides` + spec-check's *raw
   build overrides* item make the divergence visible.
3. **Check** — project-agnostic, artifact-type dependent, once (1) and
   (2) have identified the facts and the products.

> **The uniform part is the CHECKING, not the build** (user,
> 2026-08-15). However an external project builds its artifacts, how to
> USE them and how to CHECK them are relatively uniform, and the
> mechanism identification is what drives the selection.

⚠ **Two declarations of one fact.** A project can state its mechanism
here *or* on the artifact table's `a_binding` row, and pass 2 reads only
the first. The opam-binding template fills the second and leaves
`pr_binding_decls` empty, so cairo, libffi, zlib and zstd declare a
mechanism nothing sees. Recorded in
[`../../project/issues.md`](../../project/issues.md) §2 with the reason
it was not fixed on sight: it would flip four green libffi cells.

## 5. The open question the catalogue exists to ask

Mechanisms are **found objects** — cstubs, cext, ctypes grew
historically, each fixing one pain of its predecessor. Making each a
structured record turns the design space into data canary can range
over. The axes it already measures:

- **When is the surface agreement checked?** compile / link / load /
  first-call. A mechanism is, among other things, a POLICY for placing
  the checking points. Earlier is louder but stiffer.
- **What carries the surface claim?** headers, `.mli`, cdef strings,
  runtime `dir()` — each with a fidelity (typed vs name-only) and a
  drift mode.
- **How does version identity travel?** soname, symbol versions, package
  pins, watchlists — or not at all.
- **Who provides the native lib?** system / co-provider (the z3-solver
  wheel bundling libz3) / **static embedding** — §3's axis, seen from
  the packaging side.

**The instrument exists.** tiny binds ONE library through three
mechanisms and records, per mechanism, where each of its 22 mutations
manifests — build vs probe, attributed vs unattributed. That is
empirical data about the design space: a body-only signature lie is
invisible to every mechanism until run time, and a ctypes binding turns
even a missing symbol into a first-call failure.

The long-term question, in two steps:

1. **A binding mechanism from first principles** — given the axes, is
   there a point that dominates the found ones? A typed, machine-checked
   surface carrier (`signatures_agree` closed by construction);
   per-symbol version identity (`required_versions_exported` total);
   checks at the earliest site the provision allows. What does it cost
   in flexibility, and can canary QUANTIFY the trade — scenarios caught
   at build vs at probe, per mechanism?
2. **A package manager from first principles** — the same move one level
   up. A PM is a policy for provision × version identity × checking
   points across the store lifecycle.

> Framing (user, 2026-08-05): engineering cost has dropped; the leverage
> is theory and design. Canary's role in that regime is the EMPIRICAL
> instrument — the catalogue makes the design space explicit as data,
> the agreements make outcomes measurable, and tiny makes controlled
> experiments cheap.

## Where this sits

- The generated per-mechanism facts — `canary spec <project>`, and
  [`catalogue.md`](catalogue.md) for what each agreement's applicability
  does with them.
- Applicability as a pipeline pass —
  [`../enumeration/stage2_analyse_spec.md`](../enumeration/stage2_analyse_spec.md).
- What a project declares, as a pass —
  [`../enumeration/stage1_declare_spec.md`](../enumeration/stage1_declare_spec.md).
- The code — `base/canary_mechanism.ml` (vocabulary + catalogue),
  `base/canary_binding_decl.ml` (the declaration),
  `action/canary_binding_templates.ml` (the derivation).
