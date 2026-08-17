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

(* ── The mechanism CATALOGUE (reunited in base 2026-08-14) ──
   Mechanism DETAIL as standalone DATA, in the same file as the identity
   vocabulary — mechanism is BASE vocabulary: artifact identity carries
   [Ext_mechanism m] and the catalogue's facts are working code the
   lowering reads (not display-only prose). A project references a
   mechanism by name and never inlines mechanism facts; display layers
   ([spec]) read this catalogue.

   Mechanisms today are FOUND objects — cstubs / cext / ctypes grew
   historically. Making each one a structured record turns the design
   space into data canary can range over (design/mechanism.md). *)

open Base

(** Structured per-mechanism facts. [discipline] is stored AND derivable
    ([discipline_of_mechanism]) — the project-test pins them equal so the
    catalogue cannot drift from the vocabulary. *)
type mechanism_info = {
  mi_mechanism : mechanism;
  mi_lang : Canary_lang.lang;
  mi_discipline : discipline;
  mi_lib_coupling : string;
      (** how the native lib is bound: link-time undefined-symbol
          requirements vs a runtime dlopen by path/name *)
  mi_check_points : string list;
      (** where surface agreements manifest for this mechanism (prose;
          upper layers own the typed firing sites) *)
  mi_wired : bool;  (** round-1 wiring state (produced by live projects) *)
}

let mechanism_catalogue : mechanism_info list =
  [
    { mi_mechanism = Cstubs; mi_lang = Canary_lang.OCaml;
      mi_discipline = Static_c_abi;
      mi_lib_coupling =
        "link-time: stub archive carries undefined C symbols the lib must \
         provide (c1's consumer side)";
      mi_check_points =
        [ "build_binding (stub compile/link)"; "probe (link + run)" ];
      mi_wired = true };
    { mi_mechanism = Cext; mi_lang = Canary_lang.Python;
      mi_discipline = Static_c_abi;
      mi_lib_coupling =
        "link-time: extension .so carries NEEDED + undefined symbols \
         against the lib";
      mi_check_points =
        [ "build_binding (cc of the extension)"; "probe (import + run)" ];
      mi_wired = true };
    { mi_mechanism = Ctypes; mi_lang = Canary_lang.Python;
      mi_discipline = Dynamic_ffi;
      mi_lib_coupling =
        "load-time: dlopen by lib name/path at import; symbols resolved \
         per call";
      mi_check_points =
        [ "probe only (no build stage; missing symbol surfaces at \
           first call)" ];
      mi_wired = true (* tiny's ctypes probe; z3-solver is ctypes-based *) };
    { mi_mechanism = Cffi; mi_lang = Canary_lang.Python;
      mi_discipline = Dynamic_ffi;
      mi_lib_coupling = "load-time: dlopen; cdef re-declares the C surface";
      mi_check_points = [ "probe only" ];
      mi_wired = false };
    { mi_mechanism = Dynlink; mi_lang = Canary_lang.OCaml;
      mi_discipline = Dynamic_ffi;
      mi_lib_coupling = "load-time: OCaml Dynlink of a cmxs that dlopens";
      mi_check_points = [ "probe only" ];
      mi_wired = false };
  ]

(** Catalogue lookup — total over the [mechanism] constructors (pinned by
    the project-test, together with discipline consistency). *)
let info_of_mechanism (m : mechanism) : mechanism_info =
  match
    List.find mechanism_catalogue ~f:(fun i -> Poly.equal i.mi_mechanism m)
  with
  | Some i -> i
  | None ->
      (* unreachable while the totality pin holds *)
      { mi_mechanism = m; mi_lang = Canary_lang.OCaml;
        mi_discipline = discipline_of_mechanism m;
        mi_lib_coupling = "(uncatalogued)";
        mi_check_points = []; mi_wired = false }

(** One-line display form for [spec] — the project spec REFERENCES the
    mechanism; the facts printed come from here, never from the project. *)
let one_line_of_info (i : mechanism_info) : string =
  Printf.sprintf "%s (%s%s) — %s; checks: %s"
    (string_of_mechanism i.mi_mechanism)
    (string_of_discipline i.mi_discipline)
    (if i.mi_wired then "" else "; unwired")
    i.mi_lib_coupling
    (String.concat ~sep:", " i.mi_check_points)

(** Does language [l]'s (default) binding compile against the native
    surface? True for OCaml/Python today. The coverage catalogue uses
    this to decide whether a [build_binding] stage exists — a
    [Dynamic_ffi] binding would have none. (The HOW: which stages a
    mechanism realizes.) *)
let is_static_binding_lang (l : Canary_lang.lang) : bool =
  match default_mechanism_of_lang l with
  | Some m -> (match discipline_of_mechanism m with
      | Static_c_abi -> true
      | Dynamic_ffi -> false)
  | None -> false

