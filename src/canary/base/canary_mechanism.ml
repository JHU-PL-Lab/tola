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
    two languages that appear as bindings and [None] for the rest.

    ⚠ PREFER {!mechanism_of_lang_exn}. Every one of this function's nine
    callers wrote [Option.value ~default:Cstubs] immediately after
    calling it (2026-09-14 survey), which silently treats a Rust or Java
    binding as OCaml cstubs — the caller asks a question, ignores the
    answer "there isn't one", and proceeds on a guess. The option is
    kept because two callers genuinely branch on absence. *)
let default_mechanism_of_lang : Canary_lang.lang -> mechanism option = function
  | Canary_lang.OCaml -> Some Cstubs
  | Canary_lang.Python -> Some Cext
  | Canary_lang.Cpp | Canary_lang.Rust | Canary_lang.CSharp | Canary_lang.Java ->
      (* not modeled yet (to-do); these never appear as binding artifacts
         in any current project. *)
      None

(** THE MECHANISM, or a refusal naming the language (2026-09-14, user).

    The defaulting the nine call sites shared was a decision — "a
    language canary has no binding mechanism for behaves like OCaml
    cstubs" — restated nine times and never written down. It is wrong
    for every language that would exercise it: a Rust binding is not a
    cstubs archive, and answering as though it were would let an
    agreement read evidence that cannot exist and report [unavailable]
    rather than the truth, which is that canary does not model this
    language's binding at all.

    Raising is right rather than harsh: the caller is always deep in a
    derivation that has no honest answer to give, and a language
    reaches here only by being declared in a project spec — so the
    failure is a spec error, at startup, with the language named. *)
let mechanism_of_lang_exn (l : Canary_lang.lang) : mechanism =
  match default_mechanism_of_lang l with
  | Some m -> m
  | None ->
      Stdlib.failwith
        (Printf.sprintf
           "canary models no binding mechanism for %s — declare one in \
            canary_mechanism.ml before a project declares a %s binding"
           (Canary_lang.string_of_lang l)
           (Canary_lang.string_of_lang l))

(* ── The mechanism CATALOGUE (reunited in base 2026-08-14) ──
   Mechanism DETAIL as standalone DATA, in the same file as the identity
   vocabulary — mechanism is BASE vocabulary: artifact identity carries
   [Ext_mechanism m] and the catalogue's facts are working code the
   lowering reads (not display-only prose). A project references a
   mechanism by name and never inlines mechanism facts; display layers
   ([spec]) read this catalogue.

   Mechanisms today are FOUND objects — cstubs / cext / ctypes grew
   historically. Making each one a structured record turns the design
   space into data canary can range over
   (design/agreement/components.md §3.3). *)

open Base

(** Structured per-mechanism facts. [discipline] is stored AND derivable
    ([discipline_of_mechanism]) — the project-test tests that they are
    equal so the catalogue cannot drift from the vocabulary. *)
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
  (* ── THE DECIDABLE FACTS (2026-09-14, user) ──

     The three fields agreements actually dispatch on. They lived as
     loose constants in [canary_agreement_cstubs.ml], which is why
     only cstubs had them and why the families approximated the whole
     table with one bit ([is_dynamic]) — a guess that happens to be
     right for cstubs and wrong for cext on the middle field.

     Booleans rather than an evidence reference: WHAT a mechanism
     offers is base vocabulary and belongs in the catalogue; WHERE the
     evidence sits is a path into a particular world's output tree,
     which only the agreement layer can name. The per-mechanism
     tier-1 module keeps that half. *)
  mi_compiles_a_stub : bool;
      (** is there a compiled artifact whose undefined references ARE
          the binding's requirement set? [ocamlmklib] archives stub
          objects into a [.a] and a cext is a [.so]; a dlopen binding
          has none and the probe's own failure is the evidence. *)
  mi_consumer_records_needed : bool;
      (** does that artifact record WHICH shared library it needs? A
          static archive does not — no [DT_NEEDED], no [SONAME], those
          appear when the executable is linked — while a cext is a
          shared object that records both. This is the field the
          one-bit approximation got wrong: cstubs and cext share a
          discipline and differ here. *)
  mi_exposes_typed_stub : bool;
      (** does the mechanism spell its boundary in a form a signature
          can be read from? [external] declarations do; a ctypes
          binding declares its types as values instead, which is a
          different shape read from a different place. *)
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
      mi_wired = true;
      mi_compiles_a_stub = true;
      (* TRUE SINCE 2026-09-15, and the change is about WHICH artifact
         counts as the consumer. The [.a] carries no DT_NEEDED and no
         SONAME — those appear when the executable is linked — so this
         read "false" while the question was about the binding. But the
         consumer that runs is the executable the probe links, and it
         records both; the probe now summarises it into
         [inspect_abi.json] and [consumer_record_inputs] names it
         first. Measured on ssl's ssl_app_core: NEEDED libssl.so.3 and
         a version-needs section naming OPENSSL_3.0.0. *)
      mi_consumer_records_needed = true;
      mi_exposes_typed_stub = true };
    { mi_mechanism = Cext; mi_lang = Canary_lang.Python;
      mi_discipline = Static_c_abi;
      mi_lib_coupling =
        "link-time: extension .so carries NEEDED + undefined symbols \
         against the lib";
      mi_check_points =
        [ "build_binding (cc of the extension)"; "probe (import + run)" ];
      mi_wired = true;
      mi_compiles_a_stub = true;
      (* THE ROW THE ONE-BIT APPROXIMATION GOT WRONG: cext shares
         [Static_c_abi] with cstubs and differs here, because an
         extension is a [.so] that records both NEEDED and its symbol
         versions. Any predicate keyed on discipline answered "no" for
         both. *)
      mi_consumer_records_needed = true;
      (* the extension's boundary is C source that a scanner could
         read, but canary has no extractor for it — a gap in canary
         rather than in the mechanism, so it is NOT stated as an
         absence here (see backlog.md §51) *)
      mi_exposes_typed_stub = false };
    { mi_mechanism = Ctypes; mi_lang = Canary_lang.Python;
      mi_discipline = Dynamic_ffi;
      mi_lib_coupling =
        "load-time: dlopen by lib name/path at import; symbols resolved \
         per call";
      mi_check_points =
        [ "probe only (no build stage; missing symbol surfaces at \
           first call)" ];
      mi_wired = true (* tiny's ctypes probe; z3-solver is ctypes-based *);
      (* nothing is compiled, so there is no artifact to read on the
         consumer side at all — the probe's own failure is the
         evidence. Its types are declared as VALUES rather than at a
         compiled boundary. *)
      mi_compiles_a_stub = false;
      mi_consumer_records_needed = false;
      mi_exposes_typed_stub = false };
    { mi_mechanism = Cffi; mi_lang = Canary_lang.Python;
      mi_discipline = Dynamic_ffi;
      mi_lib_coupling = "load-time: dlopen; cdef re-declares the C surface";
      mi_check_points = [ "probe only" ];
      mi_wired = false;
      mi_compiles_a_stub = false;
      mi_consumer_records_needed = false;
      (* a cdef RE-DECLARES the C surface, so cffi is the one dynamic
         mechanism with a typed boundary to read — unwired, and worth
         remembering when it lands *)
      mi_exposes_typed_stub = true };
    { mi_mechanism = Dynlink; mi_lang = Canary_lang.OCaml;
      mi_discipline = Dynamic_ffi;
      mi_lib_coupling = "load-time: OCaml Dynlink of a cmxs that dlopens";
      mi_check_points = [ "probe only" ];
      mi_wired = false;
      mi_compiles_a_stub = false;
      mi_consumer_records_needed = false;
      mi_exposes_typed_stub = false };
  ]

(** Catalogue lookup — total over the [mechanism] constructors (tested by
    the project-test, together with discipline consistency). *)
let info_of_mechanism (m : mechanism) : mechanism_info =
  match
    List.find mechanism_catalogue ~f:(fun i -> Poly.equal i.mi_mechanism m)
  with
  | Some i -> i
  | None ->
      (* unreachable while the totality test holds *)
      (* unreachable while the totality test holds; the decidable fields
         answer NO so an uncatalogued mechanism claims nothing *)
      { mi_mechanism = m; mi_lang = Canary_lang.OCaml;
        mi_discipline = discipline_of_mechanism m;
        mi_lib_coupling = "(uncatalogued)";
        mi_check_points = []; mi_wired = false;
        mi_compiles_a_stub = false;
        mi_consumer_records_needed = false;
        mi_exposes_typed_stub = false }

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

