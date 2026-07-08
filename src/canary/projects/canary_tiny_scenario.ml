(** Tiny scenario entries — hand-curated list of the 15 tiny scenarios.

    Each entry pairs a [Canary_scenario.scenario] (concept: id,
    name, description, actions, related_artifacts, optional
    abstract perturbation) with a [tiny_recipe] (implementation:
    patch files, expected step outcomes for the tiny probes).

    Post-§9.3 Task 1 shape update:
    - Scenario type unified (good = no perturbation; bad = has
      perturbation). Field renamed [interested_artifacts] →
      [related_artifacts].
    - Scenario carries [id] (Bs.N or Pc.N).
    - The abstract perturbation on [Canary_scenario.scenario]
      records target artifact / kind / manifest / detector — the
      annotations we can *reason* about generically. The tiny
      [tiny_recipe] still holds the concrete implementation
      details (which patch file, which step outcomes).

    Origin: OCaml port of
    [doc/_legacy_code/tiny_python_harness/scenarios.py (archived
    Phase E):SCENARIOS]. Order changed post-migration — now
    grouped by SSOT §5.1 (Bs.1..Bs.13 by Good scenario, then
    Pc.1, Pc.2 for positive coverage). *)

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
   accurate action lists, more precise cascade) is a follow-up.
   [related_artifacts] will eventually be derivable from actions
   via a [consumes/produces] helper on rule; deferred. *)

let a_ocaml = Canary_basic.Binding Canary_lang.OCaml
let a_python = Canary_basic.Binding Canary_lang.Python

(** Actions exercised by a full tiny run (configure → build → probe
    across both bindings + the downstream app). *)
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

(** Related-artifact groupings. Coarse; refine as the model bites. *)
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

(* ----- abstract-perturbation helper ----- *)

(** Build a [Canary_scenario.perturbation]. Wraps in Some for the
    scenario's optional field. *)
let pert
    ~(target : Canary_basic.artifact_kind)
    ~(kind : Canary_scenario.perturbation_kind)
    ~(manifest : Canary_scenario.manifest)
    ~(detector : Canary_scenario.detector)
    : Canary_scenario.perturbation option =
  Some { target; kind; manifest; detector }

(* ================================================================
   THE 15 ENTRIES — ordered per SSOT §5.1 (Bs.1..Bs.13, then
   Pc.1, Pc.2 for positive coverage)
   ================================================================ *)

(** Derive [belongs_to] from the entry id, post-language-split.
    Sc.1 stays shared (7 native perturbations Bs.1..Bs.7).
    Sc.2 splits by language: OCaml binding-side (Bs.8, Bs.9,
    Bs.10, Bs.13) vs Python binding-side (Bs.11, Bs.12).
    Positive coverage points at the OCaml stages it verifies. *)
let belongs_to_of_id (id : string) : string list =
  match id with
  | "Bs.1" | "Bs.2" | "Bs.3" | "Bs.4" | "Bs.5" | "Bs.6" | "Bs.7" ->
    [ "Sc.1" ]
  | "Bs.8" | "Bs.9" | "Bs.10" | "Bs.13" ->
    [ "Sc.2.OCaml" ]
  | "Bs.11" | "Bs.12" ->
    [ "Sc.2.Python" ]
  | "Pc.1" -> [ "Sc.3.OCaml"; "Sc.4.OCaml" ]
  | "Pc.2" -> [ "Sc.5.OCaml"; "Sc.6.OCaml" ]
  | other ->
    Stdlib.failwith
      (Printf.sprintf "unknown id for belongs_to derivation: %S" other)

let entries : entry list =
  let open Canary_compat in
  let open Canary_scenario in
  let mk ~id ~name ~description ~arts ~perturbs ~concrete_pert
         ~scenario_pert ~expected ~violates =
    { scenario = { id; name; description; actions = acts_full;
                   related_artifacts = arts;
                   perturbation = scenario_pert;
                   belongs_to = belongs_to_of_id id };
      recipe = { perturbs; perturbation = concrete_pert;
                 expected; violates };
    }
  in
  [
    (* Bs.1 *)
    mk ~id:"Bs.1" ~name:"symbol_missing"
      ~description:"Source patch renames tiny_sum -> tiny_total in C only; \
                    binding artifacts still expect tiny_sum."
      ~arts:arts_native_cascade
      ~perturbs:[ "c/src/tiny.c" ]
      ~concrete_pert:(c_patch "symbol_missing")
      ~scenario_pert:(pert ~target:Canary_basic.Source
                        ~kind:(On_artifact Source)
                        ~manifest:(Possible [ "Sc.4.OCaml"; "Sc.4.Python" ])
                        ~detector:(Wired C1))
      ~violates:[ C1 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Fail;
        "ocaml_app_binding", Fail; "ocaml_app_helper", Fail;
        "python_cext_probe", Fail; "python_ctypes_probe", Fail;
        "cmp_symbol_ocaml", Fail; "cmp_symbol_cext", Fail;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Skip;
        "cmp_api_complete_ctypes", Skip;
      ];

    (* Bs.2 *)
    mk ~id:"Bs.2" ~name:"header_arity_bump"
      ~description:"tiny.h declares tiny_sum with an extra (int c) parameter; \
                    tiny.c matches the new signature so the lib still builds. \
                    The cstub calls tiny_sum(a, b) — only 2 args. c6 cmp_type \
                    catches the static mismatch."
      ~arts:arts_native_cascade
      ~perturbs:[ "c/include/tiny.h"; "c/src/tiny.c" ]
      ~concrete_pert:(c_patch "header_arity_bump")
      ~scenario_pert:(pert ~target:Canary_basic.Source
                        ~kind:(On_artifact Source)
                        ~manifest:(Definite "Sc.2.OCaml")
                        ~detector:(Wired C6))
      ~violates:[ C6 ]
      ~expected:[
        "ocaml_build", Fail; "ocaml_probe", Skip;
        "ocaml_app_binding", Skip; "ocaml_app_helper", Skip;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    (* Bs.3 *)
    mk ~id:"Bs.3" ~name:"symbol_version_floor"
      ~description:"Lib's tiny.map version script is bumped from TINY_1.0 to \
                    TINY_2.0; rebuild emits libtiny.so with tiny_sum@@TINY_2.0. \
                    Cached cext records @TINY_1.0 in its NEEDED — dyld can't \
                    satisfy the version tag at load time. c5 cmp_sym_version \
                    catches the mismatch."
      ~arts:arts_native_cascade
      ~perturbs:[ "c/tiny.map" ]
      ~concrete_pert:(c_patch "symbol_version_floor")
      ~scenario_pert:(pert ~target:Canary_basic.Source
                        ~kind:(On_artifact Source)
                        ~manifest:(Definite "Sc.4.Python")
                        ~detector:(Wired C5))
      ~violates:[ C5 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Fail; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    (* Bs.4 *)
    mk ~id:"Bs.4" ~name:"abi_soname_bump"
      ~description:"SONAME bumped libtiny.so.1 -> libtiny.so.2 and file renamed; \
                    binding NEEDED libtiny.so.1 has nothing to resolve against. \
                    Symbols themselves unchanged."
      ~arts:arts_abi_cascade
      ~perturbs:[ "c/build/libtiny.so.1" ]
      ~concrete_pert:(Some (Soname_bump { from_so = "libtiny.so.1";
                                           to_so = "libtiny.so.2.0" }))
      ~scenario_pert:(pert ~target:Canary_basic.Lib
                        ~kind:(On_artifact Lib)
                        ~manifest:(Possible [ "Sc.4.OCaml"; "Sc.4.Python" ])
                        ~detector:(Wired C4))
      ~violates:[ C4 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Fail;
        "ocaml_app_binding", Fail; "ocaml_app_helper", Fail;
        "python_cext_probe", Fail; "python_ctypes_probe", Fail;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Skip;
        "cmp_api_complete_ctypes", Skip;
      ];

    (* Bs.5 *)
    mk ~id:"Bs.5" ~name:"type_wrong"
      ~description:"tiny_sum body takes (double, double); header still says \
                    (int, int). Symbol names unchanged; no static comparator \
                    catches this today."
      ~arts:arts_native_cascade
      ~perturbs:[ "c/src/tiny.c" ]
      ~concrete_pert:(c_patch "type_wrong")
      ~scenario_pert:(pert ~target:Canary_basic.Source
                        ~kind:(On_artifact Source)
                        ~manifest:(Possible [ "Sc.4.OCaml"; "Sc.4.Python" ])
                        ~detector:(Wired C6))
      ~violates:[ C6; C3 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Fail;
        "ocaml_app_binding", Fail; "ocaml_app_helper", Fail;
        "python_cext_probe", Fail; "python_ctypes_probe", Fail;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    (* Bs.6 — detection gap *)
    mk ~id:"Bs.6" ~name:"api_faithful"
      ~description:"C adds tiny_max; bindings don't wrap it. Build and probe \
                    all succeed; no static comparator catches the missing \
                    wrapper (c8 cmp_api_faithfulness doesn't exist yet)."
      ~arts:arts_native_cascade
      ~perturbs:[ "c/include/tiny.h"; "c/src/tiny.c" ]
      ~concrete_pert:(c_patch "api_faithful")
      ~scenario_pert:(pert ~target:Canary_basic.Source
                        ~kind:(On_artifact Source)
                        ~manifest:Unknown_gap
                        ~detector:Detector_gap)
      ~violates:[ C8 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    (* Bs.7 — behavior-flavoured perturbation *)
    mk ~id:"Bs.7" ~name:"behavior_silent"
      ~description:"tiny_sum body computes a-b-tiny_offset instead of \
                    a+b+tiny_offset. Every static contract still holds; only \
                    the running probe notices. Canonical demonstration that \
                    c3 cmp_behavior is non-redundant."
      ~arts:arts_native_cascade
      ~perturbs:[ "c/src/tiny.c" ]
      ~concrete_pert:(c_patch "behavior_silent")
      ~scenario_pert:(pert ~target:Canary_basic.Source
                        ~kind:On_behavior
                        ~manifest:(Possible [ "Sc.4.OCaml"; "Sc.4.Python" ])
                        ~detector:(Wired C3))
      ~violates:[ C3 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Fail;
        "ocaml_app_binding", Fail; "ocaml_app_helper", Fail;
        "python_cext_probe", Fail; "python_ctypes_probe", Fail;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    (* Bs.8 *)
    mk ~id:"Bs.8" ~name:"api_repack"
      ~description:"OCaml user-facing Tiny.diff reverses arguments before \
                    delegating. Stub-facing layer correct; intra-binding \
                    repack wrong; c7 cmp_api_repack doesn't exist yet."
      ~arts:arts_ocaml_only
      ~perturbs:[ "ocaml/tiny.ml" ]
      ~concrete_pert:(ml_patch "api_repack")
      ~scenario_pert:(pert ~target:a_ocaml
                        ~kind:(On_artifact a_ocaml)
                        ~manifest:(Definite "Sc.4.OCaml")
                        ~detector:(Wired C3))
      ~violates:[ C7; C3 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Fail;
        "ocaml_app_binding", Fail; "ocaml_app_helper", Fail;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    (* Bs.9 *)
    mk ~id:"Bs.9" ~name:"api_complete"
      ~description:"OCaml user-facing Tiny.mli drops 'val sum'. The library \
                    still compiles (tiny's dune sets -w -32) but every \
                    consumer that references Tiny.sum fails at compile time. \
                    c2 cmp_api_completeness statically catches the missing val."
      ~arts:arts_ocaml_only
      ~perturbs:[ "ocaml/tiny.mli" ]
      ~concrete_pert:(ml_patch "api_complete")
      ~scenario_pert:(pert ~target:a_ocaml
                        ~kind:(On_artifact a_ocaml)
                        ~manifest:(Definite "Sc.3.OCaml")
                        ~detector:(Wired C2))
      ~violates:[ C2 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Fail;
        "ocaml_app_binding", Fail; "ocaml_app_helper", Fail;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Fail; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    (* Bs.10 *)
    mk ~id:"Bs.10" ~name:"symbol_orphan"
      ~description:"OCaml stub introduces a caml_tiny_extra wrapper that calls \
                    tiny_extra; the C side never had tiny_extra. Dual of \
                    symbol_missing. On strict linkers ocaml_build fails; on \
                    permissive linkers only c1 catches it."
      ~arts:arts_ocaml_only
      ~perturbs:[ "ocaml/tiny_raw.ml"; "ocaml/tiny_raw.mli";
                  "ocaml/tiny_stubs.c" ]
      ~concrete_pert:(ml_patch "symbol_orphan")
      ~scenario_pert:(pert ~target:a_ocaml
                        ~kind:(On_artifact a_ocaml)
                        ~manifest:(Possible [ "Sc.2.OCaml"; "Sc.4.OCaml" ])
                        ~detector:(Wired C1))
      ~violates:[ C1 ]
      ~expected:[
        "ocaml_build", Fail; "ocaml_probe", Skip;
        "ocaml_app_binding", Skip; "ocaml_app_helper", Skip;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Fail; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    (* Bs.11 *)
    mk ~id:"Bs.11" ~name:"api_repack_python"
      ~description:"Python user-facing layer (both cext and ctypes \
                    __init__.py) reverses arguments on diff before \
                    delegating. Same shape as api_repack but on the Python side."
      ~arts:arts_python_only
      ~perturbs:[ "python_cext/tiny_cext/__init__.py";
                  "python_ctypes/tiny_ctypes/__init__.py" ]
      ~concrete_pert:(ml_patch "api_repack_python")
      ~scenario_pert:(pert ~target:a_python
                        ~kind:(On_artifact a_python)
                        ~manifest:(Definite "Sc.4.Python")
                        ~detector:(Wired C3))
      ~violates:[ C7; C3 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Fail; "python_ctypes_probe", Fail;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    (* Bs.12 *)
    mk ~id:"Bs.12" ~name:"api_complete_python"
      ~description:"Python user-facing layer drops the sum function. Probes \
                    raise AttributeError at runtime; c2 cmp_api_completeness \
                    catches it statically via watchlist {sum, diff, offset}."
      ~arts:arts_python_only
      ~perturbs:[ "python_cext/tiny_cext/__init__.py";
                  "python_ctypes/tiny_ctypes/__init__.py" ]
      ~concrete_pert:(ml_patch "api_complete_python")
      ~scenario_pert:(pert ~target:a_python
                        ~kind:(On_artifact a_python)
                        ~manifest:(Definite "Sc.4.Python")
                        ~detector:(Wired C2))
      ~violates:[ C2 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Fail; "python_ctypes_probe", Fail;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Fail;
        "cmp_api_complete_ctypes", Fail;
      ];

    (* Bs.13 — manifestation gap (c7 static-only, no probe manifestation) *)
    mk ~id:"Bs.13" ~name:"api_repack_stub_orphan"
      ~description:"Stub-side orphan: Tiny_raw.mli adds external alias_sum \
                    with a matching caml_tiny_alias_sum C wrapper, but \
                    Tiny.mli doesn't surface it. Binding compiles + links + \
                    probes pass; c7 cmp_api_repack catches via \
                    bo1.externals \\ bo4.vals."
      ~arts:arts_ocaml_only
      ~perturbs:[ "ocaml/tiny_raw.ml"; "ocaml/tiny_raw.mli";
                  "ocaml/tiny_stubs.c" ]
      ~concrete_pert:(ml_patch "api_repack_stub_orphan")
      ~scenario_pert:(pert ~target:a_ocaml
                        ~kind:(On_artifact a_ocaml)
                        ~manifest:Unknown_gap
                        ~detector:(Wired C7))
      ~violates:[ C7 ]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    (* Pc.1 — positive coverage of Sc.3-Sc.4 *)
    mk ~id:"Pc.1" ~name:"app_over_binding_ocaml"
      ~description:"Positive-coverage: an app linking directly against the \
                    Tiny OCaml binding builds and runs; transitive dependency \
                    on libtiny.so resolves. No perturbation."
      ~arts:arts_positive
      ~perturbs:[]
      ~concrete_pert:None
      ~scenario_pert:None
      ~violates:[]
      ~expected:[
        "ocaml_build", Ok; "ocaml_probe", Ok;
        "ocaml_app_binding", Ok; "ocaml_app_helper", Ok;
        "python_cext_probe", Ok; "python_ctypes_probe", Ok;
        "cmp_symbol_ocaml", Pass; "cmp_symbol_cext", Pass;
        "cmp_api_complete_ocaml", Pass; "cmp_api_complete_cext", Pass;
        "cmp_api_complete_ctypes", Pass;
      ];

    (* Pc.2 — positive coverage of Sc.5-Sc.6 *)
    mk ~id:"Pc.2" ~name:"app_over_helper_ocaml"
      ~description:"Positive-coverage: longest-interesting chain — app -> \
                    tiny_helper -> Tiny binding -> libtiny.so. Confirms \
                    intra-binding repacking composes across a downstream \
                    library layer. No perturbation."
      ~arts:arts_positive
      ~perturbs:[]
      ~concrete_pert:None
      ~scenario_pert:None
      ~violates:[]
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
   TINY GOOD SCENARIOS (Phase 1 of tiny–SSOT integration)
   ================================================================

   Tiny's instance of the 6 good scenarios (SSOT §4). Same ids as
   [Canary_scenario.good_scenarios]; tiny-specific descriptions.

   No [tiny_recipe] paired here — per user design note (Q1):
   "a scenario doesn't need to remember recipe; scenarios are
   meta-functions to prepare a tiny project artifact." Tiny's
   good-scenario preparation IS the baseline flow in
   [canary_tiny_baseline.ml]; a future task (deferred) ties
   the baseline functions to these Sc.N ids explicitly. *)

let tiny_good_scenarios : Canary_scenario.scenario list = [
  (* Shared upstream *)
  { id = "Sc.1"; name = "build_native_lib";
    description = "Tiny: build libtiny.so from c/src/tiny.c using \
                   gcc; symbol versioning via c/tiny.map (TINY_1.0 \
                   exports). Shared across OCaml and Python.";
    actions = acts_full;
    related_artifacts = [ Canary_basic.Source; Canary_basic.Lib ];
    perturbation = None;
    belongs_to = [ "Sc.1" ] };

  (* OCaml side *)
  { id = "Sc.2.OCaml"; name = "build_binding";
    description = "Tiny: build the OCaml binding (tiny.cmxa + \
                   libtiny_stubs.a) via cstubs against libtiny.so.";
    actions = acts_full;
    related_artifacts = [ Canary_basic.Lib; a_ocaml ];
    perturbation = None;
    belongs_to = [ "Sc.2.OCaml" ] };
  { id = "Sc.3.OCaml"; name = "build_app_with_binding";
    description = "Tiny: build probe_baseline.exe / app_binding.exe \
                   linking directly against the tiny OCaml binding.";
    actions = acts_full;
    related_artifacts = [ a_ocaml; Canary_basic.App ];
    perturbation = None;
    belongs_to = [ "Sc.3.OCaml" ] };
  { id = "Sc.4.OCaml"; name = "run_app_with_binding";
    description = "Tiny: exec probe_baseline / app_binding; loader \
                   resolves libtiny.so.1 at load time.";
    actions = acts_full;
    related_artifacts =
      [ a_ocaml; Canary_basic.Lib; Canary_basic.App ];
    perturbation = None;
    belongs_to = [ "Sc.4.OCaml" ] };
  { id = "Sc.5.OCaml"; name = "build_app_helper";
    description = "Tiny: build tiny_helper + app_helper.exe — app \
                   linked through an intermediate helper library \
                   over the OCaml binding.";
    actions = acts_full;
    related_artifacts = [ a_ocaml; Canary_basic.App ];
    perturbation = None;
    belongs_to = [ "Sc.5.OCaml" ] };
  { id = "Sc.6.OCaml"; name = "run_app_helper";
    description = "Tiny: exec app_helper.exe — full chain runs \
                   through tiny_helper into libtiny.so.";
    actions = acts_full;
    related_artifacts =
      [ a_ocaml; Canary_basic.Lib; Canary_basic.App ];
    perturbation = None;
    belongs_to = [ "Sc.6.OCaml" ] };

  (* Python side (cext under SCAB; ctypes uses DFFI, mechanism
     split deferred). No Sc.3.Python — .py IS the app. No
     Sc.5/Sc.6 — no Python helper in tiny. *)
  { id = "Sc.2.Python"; name = "build_binding";
    description = "Tiny: build the Python cext (\
                   _native.cpython-*.so) against libtiny.so.";
    actions = acts_full;
    related_artifacts = [ Canary_basic.Lib; a_python ];
    perturbation = None;
    belongs_to = [ "Sc.2.Python" ] };
  { id = "Sc.4.Python"; name = "run_app_with_binding";
    description = "Tiny: exec probe_baseline.py for the cext path \
                   (SCAB); dyld resolves libtiny.so.1 at import time. \
                   The ctypes probe (DFFI) would be a separate \
                   Sc.4.Python.ctypes once the mechanism axis is \
                   promoted; today it runs but isn't modeled as its \
                   own scenario.";
    actions = acts_full;
    related_artifacts =
      [ a_python; Canary_basic.Lib; Canary_basic.App ];
    perturbation = None;
    belongs_to = [ "Sc.4.Python" ] };
]

(** United list: 8 Sc + 13 Bs + 2 Pc = 23 scenarios. Reference
    for the `derive_scenarios` experiment (§9.3 backlog). *)
let all_scenarios : Canary_scenario.scenario list =
  tiny_good_scenarios
  @ List.map entries ~f:(fun e -> e.scenario)

(** Derived scenarios — enumerate all (Good × artifact ×
    applicable-kind) cells over tiny's good scenarios. Each
    cell is a candidate perturbation; concrete Bs entries fill
    a subset of these cells. *)
let derived_scenarios : Canary_scenario.scenario list =
  Canary_scenario.derive_scenarios tiny_good_scenarios

(** Does a hardcoded Bs entry match a derived cell? Match rule:
    same good scenario (via [belongs_to] intersection) + same
    target artifact + same kind. *)
let matches_derived_cell (bad : Canary_scenario.scenario)
    (derived : Canary_scenario.scenario) : bool =
  match bad.perturbation, derived.perturbation with
  | Some bp, Some dp ->
    Poly.equal bp.target dp.target
    && Poly.equal bp.kind dp.kind
    && List.exists bad.belongs_to ~f:(fun b ->
         List.mem derived.belongs_to b ~equal:String.equal)
  | _ -> false

(* ================================================================
   HELPERS
   ================================================================ *)

let find_by_name (n : string) : entry option =
  List.find entries ~f:(fun e -> String.equal e.scenario.name n)

(** Compact contract label — "c1".."c8" or "gap" for
    [Detector_gap]. *)
let detector_short = function
  | Canary_scenario.Wired c -> Canary_compat.string_of_contract_id c
  | Canary_scenario.Detector_gap -> "gap"

(** 1-based index of an artifact in a scenario's
    [related_artifacts], or [None] if not present. *)
let artifact_index (sc : Canary_scenario.scenario)
    (target : Canary_basic.artifact_kind) : int option =
  let rec find i = function
    | [] -> None
    | a :: _ when Poly.equal a target -> Some i
    | _ :: rest -> find (i + 1) rest
  in
  find 1 sc.related_artifacts

(** For a bad scenario, format its target relative to a Good
    scenario's [related_artifacts]: "A<idx>" or "A<idx>
    (behavior)" for On_behavior kind. *)
let bad_target_str (good : Canary_scenario.scenario)
    (bad : Canary_scenario.scenario) : string =
  match bad.perturbation with
  | None -> ""
  | Some p ->
    let idx_str = match artifact_index good p.target with
      | Some i -> Printf.sprintf "A%d" i
      | None -> "A?" in
    (match p.kind with
     | On_behavior -> Printf.sprintf "%s (behavior)" idx_str
     | On_artifact _ -> idx_str)

(** Classify a good-scenario id by its language qualifier.
    "Sc.N" (no suffix) → Shared. "Sc.N.OCaml" → OCaml.
    "Sc.N.Python" → Python. *)
type lang_group = Shared | OCaml_lang | Python_lang

let lang_of_id id =
  if String.is_suffix id ~suffix:".OCaml" then OCaml_lang
  else if String.is_suffix id ~suffix:".Python" then Python_lang
  else Shared

let pad_id id = Printf.sprintf "%-11s" id
let pad_name name = Printf.sprintf "%-26s" name

let print_one_good (good : Canary_scenario.scenario) : unit =
  Stdlib.print_endline
    (Printf.sprintf "  %s  %s" good.id good.name);
  let related_strs =
    List.mapi good.related_artifacts ~f:(fun i a ->
      Printf.sprintf "A%d(%s)" (i + 1)
        (Canary_basic.string_of_artifact_kind a))
  in
  Stdlib.print_endline
    (Printf.sprintf "    related: %s"
       (String.concat ~sep:", " related_strs));
  let belongs_to_here e =
    List.mem e.scenario.belongs_to good.id ~equal:String.equal in
  let bads = List.filter entries ~f:(fun e ->
    belongs_to_here e && Option.is_some e.scenario.perturbation) in
  (if List.is_empty bads then
     Stdlib.print_endline "    perturbations: none"
   else begin
     Stdlib.print_endline
       (Printf.sprintf "    perturbations (%d):" (List.length bads));
     List.iter bads ~f:(fun e ->
       let sc = e.scenario in
       let p = Option.value_exn sc.perturbation in
       let tgt = bad_target_str good sc in
       let det = detector_short p.detector in
       Stdlib.print_endline
         (Printf.sprintf "      %s %s  %-14s [%s]"
            (pad_id sc.id) (pad_name sc.name) tgt det))
   end);
  let pcs = List.filter entries ~f:(fun e ->
    belongs_to_here e && Option.is_none e.scenario.perturbation) in
  if not (List.is_empty pcs) then begin
    Stdlib.print_endline
      (Printf.sprintf "    verified by (%d):" (List.length pcs));
    List.iter pcs ~f:(fun e ->
      Stdlib.print_endline
        (Printf.sprintf "      %s %s"
           (pad_id e.scenario.id) e.scenario.name))
  end;
  Stdlib.print_endline ""

(** Show the derived enumeration and coverage against
    hand-listed Bs entries. For each derived cell (Good ×
    target × kind), report:
    - which Bs entries fill it (by name);
    - "GAP" if no Bs fills it;
    - "EXTRAS" section at the end for any Bs that didn't fit any
      derived cell (should be empty if [applicable_perturbations]
      is complete).

    Purpose (per §9.3 backlog): validate the hand-listed
    enumeration is consistent with a principled generator; find
    under-covered (Good × target × kind) cells. *)
let print_derive () =
  let bads = List.filter entries ~f:(fun e ->
    Option.is_some e.scenario.perturbation) in
  let bad_scenarios = List.map bads ~f:(fun e -> e.scenario) in
  Stdlib.print_endline
    (Printf.sprintf "Derived cells (%d) vs hand-listed Bs (%d):"
       (List.length derived_scenarios) (List.length bad_scenarios));
  Stdlib.print_endline "";
  let matched_bads = ref [] in
  List.iter derived_scenarios ~f:(fun d ->
    let target = match d.perturbation with
      | Some p -> Canary_basic.string_of_artifact_kind p.target
      | None -> "?" in
    let kind = match d.perturbation with
      | Some p -> Canary_scenario.string_of_perturbation_kind p.kind
      | None -> "?" in
    let matching = List.filter bad_scenarios ~f:(fun b ->
      matches_derived_cell b d) in
    matched_bads := (List.map matching ~f:(fun b -> b.id)) @ !matched_bads;
    let good_id = match d.belongs_to with
      | [ g ] -> g | _ -> "?" in
    let tag = if List.is_empty matching then "  [GAP]" else "" in
    let filled_by =
      if List.is_empty matching then ""
      else
        Printf.sprintf " ← %s"
          (String.concat ~sep:", "
             (List.map matching ~f:(fun b -> b.Canary_scenario.name)))
    in
    Stdlib.print_endline
      (Printf.sprintf "  %-12s  %-14s %-9s%s%s"
         good_id target kind tag filled_by));
  Stdlib.print_endline "";
  let all_matched = !matched_bads in
  let extras = List.filter bads ~f:(fun e ->
    not (List.mem all_matched e.scenario.id ~equal:String.equal)) in
  if not (List.is_empty extras) then begin
    Stdlib.print_endline "Extras (Bs not fitting any derived cell):";
    List.iter extras ~f:(fun e ->
      Stdlib.print_endline
        (Printf.sprintf "  %s  %s" e.scenario.id e.scenario.name))
  end;
  let n_gaps =
    List.count derived_scenarios ~f:(fun d ->
      not (List.exists bad_scenarios ~f:(fun b -> matches_derived_cell b d)))
  in
  Stdlib.print_endline
    (Printf.sprintf "Summary: %d derived cells, %d filled by Bs, %d GAPs, \
                     %d extras."
       (List.length derived_scenarios)
       (List.length derived_scenarios - n_gaps)
       n_gaps (List.length extras))

(** Show-list-but-no-run — the enumeration surface. Prints all
    tiny scenarios grouped by language (Shared / OCaml / Python),
    with each Good scenario followed by its perturbations (bad
    scenarios) and verifiers (positive coverage).

    Language-as-outer-loop reflects the user's design intent:
    scenarios are defined per (mechanism × language × stage),
    and grouping by language makes the mechanism-specific
    perturbation enumeration read cleanly. Sc.1 stays shared
    (native lib is language-agnostic under the SCAB assumption).

    See SSOT §5.1 for the full detail table. *)
let print_list () =
  let goods_by_lang lg =
    List.filter tiny_good_scenarios
      ~f:(fun g -> Poly.equal (lang_of_id g.id) lg)
  in
  let n_bad = List.count entries ~f:(fun e ->
    Option.is_some e.scenario.perturbation) in
  let n_pos = List.count entries ~f:(fun e ->
    Option.is_none e.scenario.perturbation) in
  Stdlib.print_endline
    (Printf.sprintf "Scenarios (%d total: %d good + %d bad + %d positive)"
       (List.length all_scenarios)
       (List.length tiny_good_scenarios) n_bad n_pos);
  Stdlib.print_endline "";
  let section title lg =
    let goods = goods_by_lang lg in
    if not (List.is_empty goods) then begin
      Stdlib.print_endline (Printf.sprintf "%s:" title);
      List.iter goods ~f:print_one_good
    end
  in
  section "Shared" Shared;
  section "OCaml" OCaml_lang;
  section "Python" Python_lang

(** Validate a scenario name at start-up. Returns the string
    unchanged if [n] is a known scenario name (one of the 15 in
    [entries]) or the special sentinel ["baseline"] (referring
    to [_cache/baseline/workspace/]). Raises [Failure] otherwise. *)
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
    Used by [print_expected] to preserve the JSON shape. *)
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
    [scenarios.py expected <name>]. *)
let print_expected (name : string) : unit =
  match find_by_name name with
  | None ->
    Stdlib.prerr_endline
      (Printf.sprintf "unknown scenario: %S; try `list`" name);
    Stdlib.exit 1
  | Some e ->
    Stdlib.print_endline (Yojson.Basic.pretty_to_string (json_of_entry e))

(* ================================================================
   STARTUP VALIDATION

   Runs at module load. Catches at start-up:
   - unknown Sc.N in a manifest ([Definite "Sc.4"] typo, etc.);
   - perturbation.target that isn't in the scenario's
     related_artifacts.

   Failure here means the entries above are structurally wrong;
   the module fails to initialise rather than silently
   propagating the bug through prepare / canary variants. *)

let () =
  List.iter tiny_good_scenarios ~f:Canary_scenario.validate_scenario;
  List.iter entries ~f:(fun e -> Canary_scenario.validate_scenario e.scenario)

