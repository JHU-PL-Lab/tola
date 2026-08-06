# Mechanism as a first-class object — the catalogue + the research question

> Created 2026-08-05 (user-directed). Two layers: a settled engineering
> contract (the mechanism catalogue, shipped) and an OPEN research
> direction (derive a better binding mechanism — or a better PM — from
> first principles). Status pointer: status.md §D.

## The catalogue (shipped 2026-08-05)

Mechanism DETAIL is standalone DATA in ONE file —
[`base/canary_mechanism.ml`](../../src/canary/base/canary_mechanism.ml):
per mechanism (cstubs / cext / ctypes / cffi / dynlink), a
`mechanism_info` record holds its language, discipline, the file forms
that embody a binding of that mechanism, how it couples to the native lib
(link-time undefined-symbol requirements vs runtime dlopen), where its
surface checks manifest, and its wiring state.

The layering contract:

- **A project spec never inlines mechanism facts.** It references a
  mechanism by name — an artifact id carries `Ext_mechanism m` — and that
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
  other things) a POLICY for placing the c1..c8 checking points. Earlier
  is louder but stiffer; later is flexible but silent until production.
- **What carries the surface claim?** — headers, .mli, cdef strings,
  runtime `dir()`; each carrier has a fidelity (typed vs name-only) and a
  drift mode (the c2/c6 gap between carrier and truth).
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
about the design space — e.g. a body-only c6 lie is invisible to every
mechanism until run time today, and a ctypes binding turns even c1 into
a first-call failure.

The long-term question, in two steps:

1. **Binding mechanism from first principles** — given the axes, is there
   a point that dominates the found ones? E.g. a mechanism whose surface
   carrier is typed and machine-checked (c6 closed by construction),
   whose version identity is carried per-symbol (c5 total), and whose
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
