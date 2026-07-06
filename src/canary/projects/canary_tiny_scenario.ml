(** Tiny scenario entries — hand-curated list of the 15 tiny scenarios.

    Task 1 of [ssot.md] §9.3: each entry pairs a general
    [Canary_scenario.scenario] (name / description / actions /
    interested_artifacts — the concept) with a project-specific
    [tiny_recipe] (perturbs / perturbation / expected / violates —
    how tiny constructs and observes this scenario). The split
    replaces the pre-Task-1 monolithic [scenario_spec] that mixed
    concept and impl.

    Origin: OCaml port of
    [doc/_legacy_code/tiny_python_harness/scenarios.py (archived
    Phase E):SCENARIOS]. Order preserved for parity with
    [scenarios.py list]. *)

open Base

(* ================================================================
   TINY RECIPE — implementation-side (how tiny constructs a scenario)
   ================================================================ *)

(** Per-step expected outcome. Mirrors the Python [expected] dict:
    - [Ok] / [Fail] — build / probe step outcome
    - [Pass] / [Fail] — comparator outcome
    - [Skip] — step not exercised because an earlier step failed *)
type outcome = Ok | Fail | Pass | Skip

let string_of_outcome = function
  | Ok -> "ok"
  | Fail -> "fail"
  | Pass -> "pass"
  | Skip -> "skip"

(** Build target a patch perturbation should rebuild before probes
    run. Source patches under [c/] need a cmake rebuild; OCaml /
    Python source patches don't (canary rebuilds the binding itself). *)
type rebuild_target =
  | Rebuild_native_c
  | Rebuild_none

(** How a scenario mutates the tiny tree in the sandbox.
    - [Patch] applies [scenarios/patches/<patch_file>] as a unified diff.
    - [Soname_bump] renames the shared object + rewrites its SONAME
      (patchelf or byte surgery).
    Positive-coverage scenarios carry [None]. *)
type perturbation =
  | Patch of { patch_file : string; rebuild : rebuild_target }
  | Soname_bump of { from_so : string; to_so : string }

(** Tiny-specific recipe: everything about how to construct this
    scenario's world in the sandbox. Kept OFF the general
    [Canary_scenario.scenario] type because it's tiny-project
    machinery — other projects would have different recipes. *)
type tiny_recipe = {
  perturbs : string list;
  perturbation : perturbation option;
  expected : (string * outcome) list;
  violates : Canary_compat.contract_id list;
}

(** Pairing of concept ([Canary_scenario.scenario]) + implementation
    ([tiny_recipe]). The unit users of the tiny harness manipulate. *)
type entry = {
  scenario : Canary_scenario.scenario;
  recipe : tiny_recipe;
}

(* ----- recipe constructor helpers ----- *)

let c_patch name =
  Some (Patch { patch_file = name ^ ".patch"; rebuild = Rebuild_native_c })

let ml_patch name =
  Some (Patch { patch_file = name ^ ".patch"; rebuild = Rebuild_none })

(* ================================================================
   ACTIONS + ARTIFACTS PALETTE — for hand-mapping the 15 entries
   ================================================================

   Coarse first-pass hand-mapping. Refinement (per-scenario
   accurate action lists, more precise cascade) is a follow-up. *)

let a_ocaml = Canary_basic.Binding Canary_lang.OCaml
let a_python = Canary_basic.Binding Canary_lang.Python

(** Actions exercised by a full tiny run (configure → build → probe
    across both bindings + the downstream app). Most scenarios use
    this shape; per-scenario refinement to only the affected subset
    is a follow-up. *)
let acts_full : Canary_basic.rule list = [
  Configure; Scan_sources;
  Build_lib;
  Build_binding Canary_lang.OCaml;
  Build_binding Canary_lang.Python;
  Build_app;
  Probe (Binding Canary_lang.OCaml);
  Probe (Binding Canary_lang.Python);
  Probe App;
]

(** Interested-artifact groupings. Coarse; refine as the model bites. *)
let arts_native_cascade : Canary_basic.artifact_kind list =
  [ Source; Lib; a_ocaml; a_python; App ]
let arts_ocaml_only : Canary_basic.artifact_kind list =
  [ a_ocaml; App ]
let arts_python_only : Canary_basic.artifact_kind list =
  [ a_python; App ]
let arts_abi_cascade : Canary_basic.artifact_kind list =
  [ Lib; a_ocaml; a_python; App ]
let arts_positive : Canary_basic.artifact_kind list =
  [ Source; Lib; a_ocaml; a_python; App ]

(* ================================================================
   THE 15 ENTRIES (order = scenarios.py:SCENARIOS insertion order)
   ================================================================ *)

let entries : entry list =
  let open Canary_compat in
  let mk ~name ~description ~arts ~perturbs ~perturbation ~expected ~violates =
    { scenario = { name; description; actions = acts_full;
                   interested_artifacts = arts };
      recipe = { perturbs; perturbation; expected; violates };
    }
  in
  [
    mk ~name:"symbol_missing"
      ~description:"Source patch renames tiny_sum -> tiny_total in C only; \
                    binding artifacts still expect tiny_sum."
      ~arts:arts_native_cascade
      ~perturbs:[ "c/src/tiny.c" ]
      ~perturbation:(c_patch "symbol_missing")
      ~violates:[ C1 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Fail;
        "ocaml_app_binding", Fail; "ocaml_app_helper", Fail;
        "python_cext_probe", Fail; "python_ctypes_probe", Fail;
        "cmp_symbol_ocaml", Fail; "cmp_symbol_cext", Fail;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Skip;
        "cmp_api_complete_ctypes", Skip;
      ];

    mk ~name:"header_arity_bump"
      ~description:"tiny.h declares tiny_sum with an extra (int c) parameter; \
                    tiny.c matches the new signature so the lib still builds. \
                    The cstub calls tiny_sum(a, b) — only 2 args. c6 cmp_type \
                    catches the static mismatch."
      ~arts:arts_native_cascade
      ~perturbs:[ "c/include/tiny.h"; "c/src/tiny.c" ]
      ~perturbation:(c_patch "header_arity_bump")
      ~violates:[ C6 ]
      ~expected:[
        "ocaml_build", Fail; "ocaml_probe", Skip;
        "ocaml_app_binding", Skip; "ocaml_app_helper", Skip;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    mk ~name:"symbol_version_floor"
      ~description:"Lib's tiny.map version script is bumped from TINY_1.0 to \
                    TINY_2.0; rebuild emits libtiny.so with tiny_sum@@TINY_2.0. \
                    Cached cext records @TINY_1.0 in its NEEDED — dyld can't \
                    satisfy the version tag at load time. c5 cmp_sym_version \
                    catches the mismatch."
      ~arts:arts_native_cascade
      ~perturbs:[ "c/tiny.map" ]
      ~perturbation:(c_patch "symbol_version_floor")
      ~violates:[ C5 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Fail; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    mk ~name:"abi_soname_bump"
      ~description:"SONAME bumped libtiny.so.1 -> libtiny.so.2 and file renamed; \
                    binding NEEDED libtiny.so.1 has nothing to resolve against. \
                    Symbols themselves unchanged."
      ~arts:arts_abi_cascade
      ~perturbs:[ "c/build/libtiny.so.1" ]
      ~perturbation:(Some (Soname_bump { from_so = "libtiny.so.1";
                                          to_so = "libtiny.so.2.0" }))
      ~violates:[ C4 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Fail;
        "ocaml_app_binding", Fail; "ocaml_app_helper", Fail;
        "python_cext_probe", Fail; "python_ctypes_probe", Fail;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Skip;
        "cmp_api_complete_ctypes", Skip;
      ];

    mk ~name:"type_wrong"
      ~description:"tiny_sum body takes (double, double); header still says \
                    (int, int). Symbol names unchanged; no static comparator \
                    catches this today."
      ~arts:arts_native_cascade
      ~perturbs:[ "c/src/tiny.c" ]
      ~perturbation:(c_patch "type_wrong")
      ~violates:[ C6; C3 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Fail;
        "ocaml_app_binding", Fail; "ocaml_app_helper", Fail;
        "python_cext_probe", Fail; "python_ctypes_probe", Fail;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    mk ~name:"api_faithful"
      ~description:"C adds tiny_max; bindings don't wrap it. Build and probe \
                    all succeed; no static comparator catches the missing \
                    wrapper (c8 cmp_api_faithfulness doesn't exist yet)."
      ~arts:arts_native_cascade
      ~perturbs:[ "c/include/tiny.h"; "c/src/tiny.c" ]
      ~perturbation:(c_patch "api_faithful")
      ~violates:[ C8 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    mk ~name:"api_repack"
      ~description:"OCaml user-facing Tiny.diff reverses arguments before \
                    delegating. Stub-facing layer correct; intra-binding \
                    repack wrong; c7 cmp_api_repack doesn't exist yet."
      ~arts:arts_ocaml_only
      ~perturbs:[ "ocaml/tiny.ml" ]
      ~perturbation:(ml_patch "api_repack")
      ~violates:[ C7; C3 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Fail;
        "ocaml_app_binding", Fail; "ocaml_app_helper", Fail;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    mk ~name:"api_complete"
      ~description:"OCaml user-facing Tiny.mli drops 'val sum'. The library \
                    still compiles (tiny's dune sets -w -32) but every \
                    consumer that references Tiny.sum fails at compile time. \
                    c2 cmp_api_completeness statically catches the missing val."
      ~arts:arts_ocaml_only
      ~perturbs:[ "ocaml/tiny.mli" ]
      ~perturbation:(ml_patch "api_complete")
      ~violates:[ C2 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Fail;
        "ocaml_app_binding", Fail; "ocaml_app_helper", Fail;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Fail; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    mk ~name:"behavior_silent"
      ~description:"tiny_sum body computes a-b-tiny_offset instead of \
                    a+b+tiny_offset. Every static contract still holds; only \
                    the running probe notices. Canonical demonstration that \
                    c3 cmp_behavior is non-redundant."
      ~arts:arts_native_cascade
      ~perturbs:[ "c/src/tiny.c" ]
      ~perturbation:(c_patch "behavior_silent")
      ~violates:[ C3 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Fail;
        "ocaml_app_binding", Fail; "ocaml_app_helper", Fail;
        "python_cext_probe", Fail; "python_ctypes_probe", Fail;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    mk ~name:"symbol_orphan"
      ~description:"OCaml stub introduces a caml_tiny_extra wrapper that calls \
                    tiny_extra; the C side never had tiny_extra. Dual of \
                    symbol_missing. On strict linkers ocaml_build fails; on \
                    permissive linkers only c1 catches it."
      ~arts:arts_ocaml_only
      ~perturbs:[ "ocaml/tiny_raw.ml"; "ocaml/tiny_raw.mli";
                  "ocaml/tiny_stubs.c" ]
      ~perturbation:(ml_patch "symbol_orphan")
      ~violates:[ C1 ]
      ~expected:[
        "ocaml_build", Fail; "ocaml_probe", Skip;
        "ocaml_app_binding", Skip; "ocaml_app_helper", Skip;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Fail; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    mk ~name:"api_repack_python"
      ~description:"Python user-facing layer (both cext and ctypes \
                    __init__.py) reverses arguments on diff before \
                    delegating. Same shape as api_repack but on the Python side."
      ~arts:arts_python_only
      ~perturbs:[ "python_cext/tiny_cext/__init__.py";
                  "python_ctypes/tiny_ctypes/__init__.py" ]
      ~perturbation:(ml_patch "api_repack_python")
      ~violates:[ C7; C3 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Fail; "python_ctypes_probe", Fail;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    mk ~name:"api_complete_python"
      ~description:"Python user-facing layer drops the sum function. Probes \
                    raise AttributeError at runtime; c2 cmp_api_completeness \
                    catches it statically via watchlist {sum, diff, offset}."
      ~arts:arts_python_only
      ~perturbs:[ "python_cext/tiny_cext/__init__.py";
                  "python_ctypes/tiny_ctypes/__init__.py" ]
      ~perturbation:(ml_patch "api_complete_python")
      ~violates:[ C2 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Fail; "python_ctypes_probe", Fail;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Fail;
        "cmp_api_complete_ctypes", Fail;
      ];

    mk ~name:"app_over_binding_ocaml"
      ~description:"Positive-coverage: an app linking directly against the \
                    Tiny OCaml binding builds and runs; transitive dependency \
                    on libtiny.so resolves. No perturbation."
      ~arts:arts_positive
      ~perturbs:[]
      ~perturbation:None
      ~violates:[]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    mk ~name:"app_over_helper_ocaml"
      ~description:"Positive-coverage: longest-interesting chain — app -> \
                    tiny_helper -> Tiny binding -> libtiny.so. Confirms \
                    intra-binding repacking composes across a downstream \
                    library layer. No perturbation."
      ~arts:arts_positive
      ~perturbs:[]
      ~perturbation:None
      ~violates:[]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    mk ~name:"api_repack_stub_orphan"
      ~description:"Stub-side orphan: Tiny_raw.mli adds external alias_sum \
                    with a matching caml_tiny_alias_sum C wrapper, but \
                    Tiny.mli doesn't surface it. Binding compiles + links + \
                    probes pass; c7 cmp_api_repack catches via \
                    bo1.externals \\ bo4.vals."
      ~arts:arts_ocaml_only
      ~perturbs:[ "ocaml/tiny_raw.ml"; "ocaml/tiny_raw.mli";
                  "ocaml/tiny_stubs.c" ]
      ~perturbation:(ml_patch "api_repack_stub_orphan")
      ~violates:[ C7 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];
  ]

(* ================================================================
   HELPERS
   ================================================================ *)

let find_by_name (n : string) : entry option =
  List.find entries ~f:(fun e -> String.equal e.scenario.name n)

(** Print scenario names, one per line — legacy parity target for
    [python3 doc/_legacy_code/tiny_python_harness/scenarios.py list]. *)
let print_list () =
  List.iter entries ~f:(fun e -> Stdlib.print_endline e.scenario.name)

(** Validate a scenario name at start-up. Returns the string
    unchanged if [n] is a known scenario name (one of the 15 in
    [entries]) or the special sentinel ["baseline"] (referring
    to [_cache/baseline/workspace/]). Raises [Failure] otherwise.

    Phase D.1 of the tiny migration: make the variant/scenario
    coupling type-safe. *)
let name_of_string (n : string) : string =
  if String.equal n "baseline" then n
  else
    match find_by_name n with
    | Some _ -> n
    | None ->
      let known = List.map entries ~f:(fun e -> e.scenario.name) in
      Stdlib.failwith
        (Printf.sprintf
           "unknown tiny scenario: %S. Known: %s (or \"baseline\")"
           n (String.concat ~sep:", " known))

(** Human-readable contract label used by the Python harness's JSON
    output ("Symbol", "Type", "ABI", …). Distinct from
    [Canary_compat.string_of_contract_id] which emits "c1".."c8".
    Used by [print_expected] to preserve the JSON shape consumed by
    [_harness/check.py]. *)
let violates_label = function
  | Canary_compat.C1 -> "Symbol"
  | C2 -> "API-completeness"
  | C3 -> "Behavior"
  | C4 -> "ABI"
  | C5 -> "SymbolVersion"
  | C6 -> "Type"
  | C7 -> "API-repacking"
  | C8 -> "API-faithfulness"

let json_of_entry (e : entry) : Yojson.Basic.t =
  `Assoc [
    "scenario", `String e.scenario.name;
    "description", `String e.scenario.description;
    "violates", `List (List.map e.recipe.violates
                         ~f:(fun c -> `String (violates_label c)));
    "perturbs", `List (List.map e.recipe.perturbs
                         ~f:(fun p -> `String p));
    "outcomes",
      `Assoc (List.map e.recipe.expected
                ~f:(fun (k, v) -> k, `String (string_of_outcome v)));
  ]

(** Print one scenario's expected JSON — parity target for
    [scenarios.py expected <name>]. Consumed by
    [_harness/check.py]. JSON formatting is allowed to drift; the
    shape (keys, value types) must match. *)
let print_expected (name : string) : unit =
  match find_by_name name with
  | None ->
    Stdlib.prerr_endline
      (Printf.sprintf "unknown scenario: %S; try `list`" name);
    Stdlib.exit 1
  | Some e ->
    Stdlib.print_endline (Yojson.Basic.pretty_to_string (json_of_entry e))
