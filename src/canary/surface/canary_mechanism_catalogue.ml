(** Mechanism catalogue + stage-existence predicate (M2 step 1,
    2026-08-12). The DESIGN half of mechanism — moved out of
    [base/canary_mechanism.ml] (which keeps the identity vocabulary:
    [discipline], [mechanism], defaults).

    Lives in surface/ next to the contracts ([Canary_compat]) —
    contracts are WHAT to check; this catalogue is HOW each mechanism
    manifests the checks (which stages exist, where checking points
    lie). A project references a mechanism by name (an artifact id
    carries [Ext_mechanism m]) and never inlines mechanism facts;
    display layers ([spec]) read this catalogue.

    Mechanisms today are FOUND objects — cstubs / cext / ctypes grew
    historically. Making each one a structured record turns the design
    space into data canary can range over (design/mechanism.md). *)

open Base

(** Structured per-mechanism facts. [discipline] is stored AND derivable
    ([discipline_of_mechanism]) — the project-test pins them equal so the
    catalogue cannot drift from the vocabulary. *)
type mechanism_info = {
  mi_mechanism : Canary_mechanism.mechanism;
  mi_lang : Canary_lang.lang;
  mi_discipline : Canary_mechanism.discipline;
  mi_artifact_shape : string list;
      (** the file forms that embody a binding of this mechanism *)
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
    { mi_mechanism = Canary_mechanism.Cstubs; mi_lang = Canary_lang.OCaml;
      mi_discipline = Canary_mechanism.Static_c_abi;
      mi_artifact_shape =
        [ "lib<pkg>_stubs.a (C stubs)"; "<pkg>.cmxa/.cma"; "*.mli"; "META" ];
      mi_lib_coupling =
        "link-time: stub archive carries undefined C symbols the lib must \
         provide (c1's consumer side)";
      mi_check_points =
        [ "build_binding (stub compile/link)"; "probe (link + run)" ];
      mi_wired = true };
    { mi_mechanism = Canary_mechanism.Cext; mi_lang = Canary_lang.Python;
      mi_discipline = Canary_mechanism.Static_c_abi;
      mi_artifact_shape =
        [ "_native.<EXT_SUFFIX>.so (compiled extension)"; "__init__.py" ];
      mi_lib_coupling =
        "link-time: extension .so carries NEEDED + undefined symbols \
         against the lib";
      mi_check_points =
        [ "build_binding (cc of the extension)"; "probe (import + run)" ];
      mi_wired = true };
    { mi_mechanism = Canary_mechanism.Ctypes; mi_lang = Canary_lang.Python;
      mi_discipline = Canary_mechanism.Dynamic_ffi;
      mi_artifact_shape = [ "pure .py source (no build product)" ];
      mi_lib_coupling =
        "load-time: dlopen by lib name/path at import; symbols resolved \
         per call";
      mi_check_points =
        [ "probe only (no build stage; missing symbol surfaces at \
           first call)" ];
      mi_wired = true (* tiny's ctypes probe; z3-solver is ctypes-based *) };
    { mi_mechanism = Canary_mechanism.Cffi; mi_lang = Canary_lang.Python;
      mi_discipline = Canary_mechanism.Dynamic_ffi;
      mi_artifact_shape = [ "pure .py + cdef declarations" ];
      mi_lib_coupling = "load-time: dlopen; cdef re-declares the C surface";
      mi_check_points = [ "probe only" ];
      mi_wired = false };
    { mi_mechanism = Canary_mechanism.Dynlink; mi_lang = Canary_lang.OCaml;
      mi_discipline = Canary_mechanism.Dynamic_ffi;
      mi_artifact_shape = [ ".cmxs (plugin)"; "toplevel/utop load" ];
      mi_lib_coupling = "load-time: OCaml Dynlink of a cmxs that dlopens";
      mi_check_points = [ "probe only" ];
      mi_wired = false };
  ]

(** Catalogue lookup — total over the [mechanism] constructors (pinned by
    the project-test, together with discipline consistency). *)
let info_of_mechanism (m : Canary_mechanism.mechanism) : mechanism_info =
  match
    List.find mechanism_catalogue ~f:(fun i -> Poly.equal i.mi_mechanism m)
  with
  | Some i -> i
  | None ->
      (* unreachable while the totality pin holds *)
      { mi_mechanism = m; mi_lang = Canary_lang.OCaml;
        mi_discipline = Canary_mechanism.discipline_of_mechanism m;
        mi_artifact_shape = []; mi_lib_coupling = "(uncatalogued)";
        mi_check_points = []; mi_wired = false }

(** One-line display form for [spec] — the project spec REFERENCES the
    mechanism; the facts printed come from here, never from the project. *)
let one_line_of_info (i : mechanism_info) : string =
  Printf.sprintf "%s (%s%s) — %s; checks: %s"
    (Canary_mechanism.string_of_mechanism i.mi_mechanism)
    (Canary_mechanism.string_of_discipline i.mi_discipline)
    (if i.mi_wired then "" else "; unwired")
    i.mi_lib_coupling
    (String.concat ~sep:", " i.mi_check_points)

(** Does language [l]'s (default) binding compile against the native
    surface? True for OCaml/Python today. The coverage catalogue uses
    this to decide whether a [build_binding] stage exists — a
    [Dynamic_ffi] binding would have none. (The HOW: which stages a
    mechanism realizes.) *)
let is_static_binding_lang (l : Canary_lang.lang) : bool =
  match Canary_mechanism.default_mechanism_of_lang l with
  | Some m -> (match Canary_mechanism.discipline_of_mechanism m with
      | Canary_mechanism.Static_c_abi -> true
      | Canary_mechanism.Dynamic_ffi -> false)
  | None -> false

(* ── M2 step 2+3: the contract×lang×mechanism input template ──
   WHAT each contract's predict closure reads (input KINDS), with the
   STANDARD inspect-file paths per language (tiny's convention: inspect
   attached to build_binding/build_lib, files inspect.json /
   inspect_mli.json / inspect_attrs.json). A project whose layout
   deviates (z3's fetch-step attrs inspect, llvm's summary_stub.json +
   location-suffixed probe_lib) keeps hand-writing those rows — the
   template covers the common case, not every case.

   Mechanism refinement (dynamic bindings have no stub input) comes
   with the mechanism axis (M2 step 3). *)

let inputs_of_contract ?mechanism (c : Canary_compat.contract_id)
    (l : Canary_lang.lang) : Canary_compat.inspect_input list =
  let open Canary_compat in
  (* mechanism defaults to the language's default (static for OCaml/Python
     today) — current callers unchanged; a dynamic binding (ctypes/dynlink)
     has NO stub input (it dlopens at runtime). *)
  let m =
    Option.value mechanism
      ~default:
        (Option.value (Canary_mechanism.default_mechanism_of_lang l)
           ~default:Canary_mechanism.Cstubs)
  in
  let is_dynamic =
    Poly.equal (Canary_mechanism.discipline_of_mechanism m)
      Canary_mechanism.Dynamic_ffi
  in
  let tag action = Canary_basic.string_of_action action in
  let build_binding_tag = tag (Canary_basic.Build_binding l) in
  let build_lib_tag = tag Canary_basic.Build_lib in
  match c, l with
  | C1, (Canary_lang.OCaml | Canary_lang.Python) when not is_dynamic ->
      [ C_stub [ build_binding_tag ^ "/inspect.json" ];
        Native_lib [ build_lib_tag ^ "/inspect.json" ] ]
  | C1, (Canary_lang.OCaml | Canary_lang.Python) ->
      (* dynamic: no compiled stub to inspect — the runtime fallback
         (probe.log presence) catches missing-symbol failures *)
      []
  | C2, Canary_lang.OCaml ->
      [ Ocaml_mli [ build_binding_tag ^ "/inspect_mli.json" ] ]
  | C2, Canary_lang.Python ->
      [ Python_attrs [ build_binding_tag ^ "/inspect_attrs.json" ] ]
  | C4, Canary_lang.Python when not is_dynamic ->
      [ Native_lib [ build_lib_tag ^ "/inspect.json" ];
        Abi_surface [ build_binding_tag ^ "/inspect.json" ] ]
  | C5, Canary_lang.Python when not is_dynamic ->
      [ Versioned_exports [ build_lib_tag ^ "/inspect.json" ];
        Versioned_req [ build_binding_tag ^ "/inspect.json" ] ]
  | C6, Canary_lang.OCaml when not is_dynamic ->
      [ Typed_header [ "scan_sources/inspect_typed_header.json" ];
        Typed_binding_stub
          [ "scan_sources/inspect_typed_binding_stub_ocaml.json" ] ]
  | _ -> []  (* placeholder / unwired / behavior-grep / dynamic — no inputs *)
