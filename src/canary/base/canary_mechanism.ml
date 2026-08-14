(** Binding mechanism + discipline vocabulary (ssot §4.2.1b).

    A binding's *discipline* is the axis the scenario enumerator ranges
    over: does the binding **compile against** the native surface (a
    build-time ABI check) or **[dlopen] it at runtime** (a runtime symbol
    check)? Two values only — deliberately *not* the open set of mechanism
    {i names}, because what changes the pipeline shape (whether a
    [Build_binding] stage exists, and where the surface-check fires) is the
    discipline, not the name. The mechanism is the finer descriptive label
    under a discipline.

    - [Static_c_abi]  — the binding is a compiled stub linked to the lib
                        (OCaml cstubs, Python cext). Has a real
                        [Build_binding] stage; checked at link {i and}
                        probe; breaks on soname/ABI/type mismatch at build.
    - [Dynamic_ffi]   — the binding is pure source that [dlopen]s the lib
                        at runtime (Python ctypes/cffi, OCaml
                        Dynlink/utop). No [Build_binding] stage; the whole
                        surface-check is at probe; breaks on missing symbol
                        / signature at run.

    The two disciplines line up across languages, which is the payoff of
    keying on discipline rather than mechanism name:

    {v
              static (linked into the app)   dynamic (dlopen at runtime)
      OCaml   cstubs                          Dynlink / .cmxs (utop)
      Python  cext (compiled .so)             ctypes / cffi
    v}

        The catalogue + stage-existence predicate moved to
    [surface/canary_mechanism_catalogue.ml] (M2 step 1, 2026-08-12) —
    this file keeps only the identity vocabulary that artifact
    identity ([Canary_artifact.Ext_mechanism]) and the enumeration
    ([Canary_enumerate.discipline_of_mechanism]) need.

    **Round 1 (2026-07): only [Static_c_abi] is wired** — it is what every
    current project definition uses (OCaml = cstubs, Python = cext). The
    [Dynamic_ffi] constructors are typed but not yet produced. Deferred
    (to-do): threading discipline through the binding artifact identity
    ([Binding of lang] → binding(lang, discipline)), the coverage/enumerator
    handling of the missing [Build_binding] stage for a dynamic binding, and
    splitting tiny's ctypes probe out of its cext binding. See
    scenario_coverage.md §5 and ssot §4.2.1b. *)

type discipline =
  | Static_c_abi  (** compiled stub linked to the lib; build-time ABI check *)
  | Dynamic_ffi  (** pure-source [dlopen] at runtime; runtime symbol check — to-do *)
[@@deriving show, eq]

type mechanism =
  | Cstubs  (** OCaml, static *)
  | Cext  (** Python, static *)
  | Ctypes  (** Python, dynamic — to-do *)
  | Cffi  (** Python, dynamic — to-do *)
  | Dynlink  (** OCaml, dynamic (utop / toplevel) — to-do *)
[@@deriving show, eq]

let discipline_of_mechanism = function
  | Cstubs | Cext -> Static_c_abi
  | Ctypes | Cffi | Dynlink -> Dynamic_ffi

let string_of_mechanism = function
  | Cstubs -> "cstubs"
  | Cext -> "cext"
  | Ctypes -> "ctypes"
  | Cffi -> "cffi"
  | Dynlink -> "dynlink"

let string_of_discipline = function
  | Static_c_abi -> "static_c_abi"
  | Dynamic_ffi -> "dynamic_ffi"

(** The mechanism each language uses today. Round 1 wires only the static
    mechanism per language; a language's dynamic mechanism (Python ctypes,
    OCaml Dynlink) is deferred, so this is [Some] a static mechanism for the
    two languages that appear as bindings and [None] for the rest. *)
let default_mechanism_of_lang : Canary_lang.lang -> mechanism option = function
  | Canary_lang.OCaml -> Some Cstubs
  | Canary_lang.Python -> Some Cext
  | Canary_lang.Cpp | Canary_lang.Rust | Canary_lang.CSharp | Canary_lang.Java ->
      (* not modeled yet (to-do); these never appear as binding artifacts
         in any current project. *)
      None
