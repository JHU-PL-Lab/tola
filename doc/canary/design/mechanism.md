# Mechanism as a first-class object — the catalogue + the research question

**Kind: rationale + open research.** The catalogue shipped 2026-08-05; the "derive a better mechanism from first principles" half is a research direction, not queued work.

> Created 2026-08-05 (user-directed). Two layers: a settled engineering
> contract (the mechanism catalogue, shipped) and an OPEN research
> direction (derive a better binding mechanism — or a better PM — from
> first principles). Status pointer: status.md §D.

## The catalogue (shipped 2026-08-05)

Mechanism DETAIL is standalone DATA in ONE file —
[`base/canary_mechanism.ml`](../../../src/canary/base/canary_mechanism.ml):
per mechanism (cstubs / cext / ctypes / cffi / dynlink), a
`mechanism_info` record holds its language, discipline, the file forms
that embody a binding of that mechanism, how it couples to the native lib
(link-time undefined-symbol requirements vs runtime dlopen), where its
surface checks manifest, and its wiring state.

The layering contract:

- **A project spec never inlines mechanism facts.** It references a
  mechanism by name — an artifact identity carries it (`A_binding (l, m)`) — and that
  is all. (`spec` prints the per-binding mechanism line by reading the
  catalogue, not the project.)
- **Base-layer discipline**: descriptive fields are prose/lists here;
  contract ids (surface/) and typed firing sites (action/) live in upper
  layers, which pin their structures against the catalogue in tests
  (`mechanism.catalogue_total_and_consistent`) rather than by depending
  downward. The stored discipline is pinned equal to
  `discipline_of_mechanism`, so the catalogue cannot drift from the
  vocabulary.
- **Known declared-vs-real divergence** (deliberate, A5 phase 1): z3's
  python binding is declared `Cext` to match `default_mechanism_of_lang`
  and every existing view, though z3-solver is really ctypes-based; the
  flip rides the deferred `Dynamic_ffi` wiring round (ssot §4.2.1b). The
  catalogue display makes this divergence visible instead of buried.

What should MIGRATE into (or hang off) the catalogue as it matures: the
mechanism-coupled fragments still living in project files and the
toolchain layer — probe shapes per mechanism (`ocamlfind ocamlopt
-package …` vs `python3 -c "import …"`), build recipes (cext via
sysconfig, cstubs via dune/ocamlfind), inspector selections (stub
archive vs mli vs attrs). Natural vehicle: A9-step-2's action-variant
table, where command templates become declared rows — a mechanism then
becomes a ROW GROUP in that table.

## The research question (OPEN — the point of the exercise)

Today's mechanisms are FOUND objects: cstubs, cext, ctypes grew
historically, each fixing one pain of its predecessor. The catalogue
turns them into comparable points in a design space whose axes canary
already measures:

- **When is the surface agreement checked?** — compile / link / load /
  first-call. The discipline axis, generalized: a mechanism is (among
  other things) a POLICY for placing the agreements' checking points. Earlier
  is louder but stiffer; later is flexible but silent until production.
- **What carries the surface claim?** — headers, .mli, cdef strings,
  runtime `dir()`; each carrier has a fidelity (typed vs name-only) and a
  drift mode (the gap between carrier and truth that `api_names_present`
  and `signatures_agree` each see one face of).
- **How does version identity travel?** — soname, symbol versions,
  package pins, watchlists; or not at all (the Fetched-ambient world).
- **Who provides the native lib?** — external (link/load against the
  system) vs co-provider (the z3-solver wheel bundling libz3; backlog
  #45) vs static embedding. This axis is `dep_mode`
  (Lockstep/Independent/Ambient) seen from the packaging side.

**The instrument already exists**: tiny binds ONE lib through three
mechanisms (cstubs / cext / ctypes), and the oracle + the derived
expectation layer record, per mechanism, WHERE each of the 22 mutations
manifests (build vs probe, attributed contract vs unattributed
behavioral). That per-mechanism manifestation matrix is empirical data
about the design space — e.g. a body-only signature lie is invisible to
every mechanism until run time today, and a ctypes binding turns even a
missing symbol into a first-call failure.

The long-term question, in two steps:

1. **Binding mechanism from first principles** — given the axes, is there
   a point that dominates the found ones? E.g. a mechanism whose surface
   carrier is typed and machine-checked (`signatures_agree` closed by
   construction), whose version identity is carried per-symbol
   (`required_versions_exported` total), and whose
   checks fire at the earliest site the provision allows. What would it
   cost in flexibility, and can canary QUANTIFY the trade (scenarios
   caught at build vs at probe, per mechanism)?
2. **PM from first principles** — the same move one level up: a package
   manager is a policy for provision × version identity × checking
   points across the store lifecycle. The distro × sys-PM × lang-PM
   enumeration (status §1b packaging) is the found-object survey; the
   question is what the derived point looks like.

Framing note (user, 2026-08-05): engineering cost has dropped (AI does
the plumbing); the leverage is theory and design. Canary's role in that
regime is the EMPIRICAL instrument — the catalogue makes the design
space explicit as data, the contracts make outcomes measurable, and
tiny makes controlled experiments cheap.

## The axis that is missing: what the PROVIDER is

> 2026-09-17, from the user: *"I wish the mechanism can cover more
> binding cases including `{c-static-lib, c-dynamic-lib} × (
> {ocaml-binding-via-c-stub, ocaml-binding-via-dynlink} +
> {python-cstatic, python-ctypes})`."*

The catalogue above ranges over the CONSUMER's mechanism. It has no
value for the provider's linkage, and it should: **a static provider
changes which agreements apply as much as the consumer's mechanism
does.**

### It is already there, as a shape rather than a value

`Canary_artifact.api_component` distinguishes `Link_lib` (the `.so`
symlink **or** the `.a`) from `Runtime_lib` (the versioned `.so`,
"absent for static linking"). So the fact is encoded as *which
components a provider declares* — a shape nothing enumerates over, and
nothing dispatches on. Compare `mi_consumer_records_needed`, which is
exactly this distinction on the consumer side and IS a value.

The tooling is closer than the model. `inspect_binding.py --kind stub`
already reads a `.a` with plain `nm` and a `.so` with `nm -D`, because
the consumer's stub comes in both forms:

```python
cmd = ["nm", "-D", path] if is_shared else ["nm", path]
```

`Canary_artifact_native.nm_cmd` — the PROVIDER side — hardcodes `nm -D`.
That one line is most of what stands between canary and a static
provider.

### What a static provider changes

| agreement | shared provider | static provider |
| --- | --- | --- |
| `declared_symbols_exported` | `nm -D` | `nm` over the archive — same comparison |
| `required_symbols_exported` | unchanged | unchanged |
| `soname_matches_declaration` | reads `SONAME` | **no SONAME exists.** `not_applicable`, not `unavailable` |
| `soname_matches_requirement` | consumer records `NEEDED` | **the consumer records nothing** — the symbols were absorbed at link |
| `declared_versions_exported` | ELF version nodes | **none** |
| `required_versions_exported` | consumer's version refs | **none** |
| `dependencies_provided` | `NEEDED` vs providers | **the question moves**: a static lib's own dependencies become the CONSUMER's, transitively and silently |
| `staged_interface_preserved` | unchanged | unchanged |

Four agreements go `not_applicable` and one changes meaning. Note the
shape: it is the same set that `mi_consumer_records_needed = false`
turns off on the consumer side, which is not a coincidence — **they are
the same claim read from the two ends of one link.**

### The 2 × 4 grid, with its holes

The holes are the interesting part, and stating them is what an
enumeration constraint is for.

| | cstubs (OCaml) | dynlink (OCaml) | cext (Python) | ctypes (Python) |
| --- | --- | --- | --- | --- |
| **shared `.so`** | ✅ wired — the roster | ⬜ unwired | ✅ wired — sqlite | ✅ wired — z3, llvm |
| **static `.a`** | ⬜ plausible | ⚠ see below | ⬜ plausible | ❌ **impossible** |

- **ctypes × static is impossible**, and that is a fact about the
  mechanism rather than a gap: `ctypes.CDLL` calls `dlopen`, and there
  is nothing to `dlopen` in an archive. A constraint should refuse the
  cell rather than a project reporting `unavailable` forever.
- **dynlink × static is possible but subtle.** OCaml `Dynlink` loads a
  `.cmxs`, and that `.cmxs` may itself have statically linked the C
  archive. So the provider is static while the BINDING is dynamically
  loaded — the two "dynamics" are at different levels, and conflating
  them is the trap `discipline` already warns about.
- **cstubs × static and cext × static are the cheap ones.** Both compile
  a stub; the stub's undefined references are the same set; only the
  provider-side inspection and the four `not_applicable`s change.

### What landing it needs, in order

1. **A value, in base.** `linkage = Shared | Static` on the native
   artifact, beside `discipline` on the consumer side. It is
   `canary_store`/`canary_artifact` vocabulary, not agreement
   vocabulary — the agreements DISPATCH on it, they do not own it.
2. **`nm_cmd` reads it** instead of assuming `-D`.
3. **An applicability predicate per agreement**, the mirror of
   `mi_consumer_records_needed`: `provider_records_needed`,
   `provider_carries_version_nodes`. Four agreements gain a second
   `Inapplicable` reason.
4. **An enumeration constraint** refusing ctypes × static, with the
   reason in the message.
5. **A witness.** tiny already builds `libtiny.so.1`; a `libtiny.a`
   beside it, and the 2 × 4 grid has a controlled specimen for every
   admissible cell. That is the cheapest new axis tiny has ever had —
   one CMake target.

**Do 1–3 before 4.** A constraint that refuses a cell nothing can
describe yet is a guess; once the linkage is a value, the refusal is
derivable from the mechanism catalogue (`Ctypes` needs a runtime
carrier; `Static` provides none).
