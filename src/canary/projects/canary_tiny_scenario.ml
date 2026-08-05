(** Tiny scenario entries — hand-curated list of the 15 tiny scenarios.

    Each entry pairs a [Canary_scenario.scenario] (concept: id,
    name, description, actions, related_artifacts, optional
    abstract mutation) with a [tiny_recipe] (implementation:
    patch files, expected step outcomes for the tiny probes).

    Post-§9.3 Task 1 shape update:
    - Scenario type unified (good = no mutation; bad = has
      mutation). Field renamed [interested_artifacts] →
      [related_artifacts].
    - Scenario carries [id]: Bs.N for mutation-carrying
      scenarios; the Sc.N (run-stage) id itself for unmutated
      scenarios (SSOT §4.1) — a scenario with mutation = None
      IS the Sc.N run, not a separate id. Legacy label: Pc.N.
    - The abstract mutation on [Canary_scenario.scenario]
      records target artifact / kind / manifest / detector — the
      annotations we can *reason* about generically. The tiny
      [tiny_recipe] still holds the concrete implementation
      details (which patch file, which step outcomes).

    Origin: OCaml port of
    [doc/_legacy_code/tiny_python_harness/scenarios.py (archived
    Phase E):SCENARIOS]. Order changed post-migration — now
    grouped by SSOT §5.1 (Bs.1..Bs.13 by Good scenario, then
    the two unmutated Sc.N runs Sc.4.OCaml, Sc.6.OCaml — see
    SSOT §4.1). *)

open Base
open Canary_basic
open Canary

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

(* mutation + patch constructor moved to Canary_artifact_mutation
   2026-07-09. Per-artifact split landed 2026-07-20 (§7.2 Phase 1):
   Source / Native / Binding modules now own their own mutation
   types; top-level [mutation] is a thin union over them plus a
   Patch escape hatch. Re-exported as a type equation so internal
   uses of [Patch] and the [Of_*] wrappers stay unqualified. *)
type mutation = Canary_artifact_mutation.mutation =
  | Of_source of Canary_artifact_mutation.Source.t
  | Of_native of Canary_artifact_mutation.Native.t
  | Of_binding of Canary_artifact_mutation.Binding.t
  | Patch of { patch_file : string }

(** Tiny-specific recipe: everything about how to construct this
    scenario's world in the sandbox. Kept OFF the general
    [Canary_scenario.scenario] type because it's tiny-project
    machinery — other projects would have different recipes. *)
type tiny_recipe = {
  mutates : string list;
  mutation : mutation option;
  expected : (string * outcome) list;
  violates : Canary_compat.contract_id list;
}

(** Pairing of concept ([Canary_scenario.scenario]) + implementation
    ([tiny_recipe]). The unit users of the tiny harness manipulate. *)
type scenario_spec = {
  scenario : Canary_scenario.scenario;
  recipe : tiny_recipe;
}

(* ----- recipe constructor helpers ----- *)

let patch = Canary_artifact_mutation.patch

(* ================================================================
   ACTIONS + ARTIFACTS PALETTE — for hand-mapping the 15 entries
   ================================================================

   Coarse first-pass hand-mapping. Refinement (per-scenario
   accurate action lists, more precise cascade) is a follow-up.
   [related_artifacts] will eventually be derivable from actions
   via a [consumes/produces] helper on action; deferred. *)

let a_ocaml = Canary_basic.Binding Canary_lang.OCaml
let a_python = Canary_basic.Binding Canary_lang.Python

(* [acts_full] retired 2026-07-10: every scenario now carries
   its parent Sc.N's actions (via [actions_of_parents]
   below), not a uniform tiny-wide list. Both cargo-culted
   uses (all Bs's + all Pc's carrying it identically) are
   gone. *)

(* arts_native_cascade / arts_ocaml_only / arts_python_only /
   arts_abi_cascade / arts_positive retired 2026-07-10: they
   were hand-picked narrowing hints for a `related_artifacts`
   field that no longer exists. The field derives from
   [scenario.actions] via
   [Canary_scenario.related_artifacts_of_actions]. *)

(* ----- abstract-mutation helper ----- *)

(* (was Canary_scenario_util 2026-07-08 → folded back 2026-08-05: the
   "project-agnostic scenario helpers" file never gained a second consumer —
   these are tiny's display/oracle helpers.) *)

(** Build a {!Canary_scenario.origin} option wrapping a Mutation — the common
    case where a bad scenario's origin is a mutation (all tiny Bs entries). *)
let pert
    ~(target : Canary_basic.artifact_kind)
    ~(kind : Canary_scenario.mutation_kind)
    ~(manifest : Canary_scenario.manifest)
    ~(detector : Canary_scenario.detector)
    : Canary_scenario.origin option =
  Some (Canary_scenario.Mutation { target; kind; manifest; detector })

(* ================================================================
   THE 15 CONCRETE INSTANTIATIONS — ordered per SSOT §5.1 for
   Bs.1..Bs.13 (mutation-carrying), then SSOT §4.1 for
   Sc.4.OCaml and Sc.6.OCaml (unmutated Sc.N runs).
   ================================================================ *)

(** Derive [belongs_to] from the entry id, post-language-split.
    Sc.1 stays shared (7 native mutations Bs.1..Bs.7).
    Sc.2 splits by language: OCaml binding-side (Bs.8, Bs.9,
    Bs.10, Bs.13) vs Python binding-side (Bs.11, Bs.12).
    Unmutated Sc.N runs (Pc.N, SSOT §4.1) point at the OCaml
    stages they exercise. *)
let belongs_to_of_id (id : string) : string list =
  match id with
  | "Bs.1" | "Bs.2" | "Bs.3" | "Bs.4" | "Bs.5" | "Bs.6" | "Bs.7" ->
    [ "Sc.1" ]
  | "Bs.8" | "Bs.9" | "Bs.10" | "Bs.13" ->
    [ "Sc.2.OCaml" ]
  | "Bs.11" | "Bs.12" ->
    [ "Sc.2.Python" ]
  | "Sc.4.OCaml" -> [ "Sc.3.OCaml"; "Sc.4.OCaml" ]
  | "Sc.6.OCaml" -> [ "Sc.5.OCaml"; "Sc.6.OCaml" ]
  | other ->
    Stdlib.failwith
      (Printf.sprintf "unknown id for belongs_to derivation: %S" other)

(* Actions for a Bs.N or Pc entry = union of its belongs_to
   parents' actions. Matches the "this scenario is a mutation
   instance of Sc.N" semantic: Bs.N's derived
   [related_artifacts] equals the parent Sc.N's, so
   [validate_mutation_target]'s membership check passes and
   the mutation.target sits in the parent's artifact set.
   For Pc entries with multiple parents (Pc.1 → Sc.3+Sc.4),
   the union covers both halves of the chain.

   Static metadata note (2026-07-10): [scenario.actions] here
   reflects the *conceptual* action scope of the mutation, not
   what canary literally runs (canary's factory always emits
   the full spec — every action closure fires). Future
   "sync-static-with-runtime" task will make the factory
   respect [scenario.actions] and only emit steps for the
   listed actions; until then, treat this field as metadata. *)
let actions_of_parents (parents : string list) : Canary_basic.action list =
  let open Base in
  List.concat_map parents ~f:(fun sc_id ->
    match List.find Canary_scenario.good_scenarios
            ~f:(fun g -> String.equal g.id sc_id) with
    | Some g -> g.actions
    | None -> [])
  |> List.fold ~init:[] ~f:(fun acc r ->
      if List.mem acc r ~equal:Poly.equal then acc else acc @ [ r ])

let scenario_specs : scenario_spec list =
  let open Canary_compat in
  let open Canary_scenario in
  let mk ~id ~name ~description ~mutates ~concrete_pert
         ~scenario_pert ~expected ~violates =
    let parents = belongs_to_of_id id in
    let actions = actions_of_parents parents in
    { scenario = { id; name; description; actions;
                   origin = scenario_pert;
                   belongs_to = parents };
      recipe = { mutates; mutation = concrete_pert;
                 expected; violates };
    }
  in
  [
    (* Bs.1 *)
    mk ~id:"Bs.1" ~name:"symbol_missing"
      ~description:"Source patch renames tiny_sum -> tiny_total in C only; \
                    binding artifacts still expect tiny_sum."
      ~mutates:[ "c/src/tiny.c" ]
      ~concrete_pert:(patch "symbol_missing")
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
      ~mutates:[ "c/include/tiny.h"; "c/src/tiny.c" ]
      ~concrete_pert:(patch "header_arity_bump")
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
      ~mutates:[ "c/tiny.map" ]
      ~concrete_pert:(patch "symbol_version_floor")
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
      ~mutates:[ "c/build/libtiny.so.1" ]
      ~concrete_pert:(Some (Of_native (Soname_bump { from_so = "libtiny.so.1.0";
                                                     to_so = "libtiny.so.2.0" })))
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
      ~mutates:[ "c/src/tiny.c" ]
      ~concrete_pert:(patch "type_wrong")
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
      ~mutates:[ "c/include/tiny.h"; "c/src/tiny.c" ]
      ~concrete_pert:(patch "api_faithful")
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

    (* Bs.7 — behavior-flavoured mutation *)
    mk ~id:"Bs.7" ~name:"behavior_silent"
      ~description:"tiny_sum body computes a-b-tiny_offset instead of \
                    a+b+tiny_offset. Every static contract still holds; only \
                    the running probe notices. Canonical demonstration that \
                    c3 cmp_behavior is non-redundant."
      ~mutates:[ "c/src/tiny.c" ]
      ~concrete_pert:(patch "behavior_silent")
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
      ~mutates:[ "ocaml/tiny.ml" ]
      ~concrete_pert:(patch "api_repack")
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
      ~mutates:[ "ocaml/tiny.mli" ]
      ~concrete_pert:(patch "api_complete")
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
      ~mutates:[ "ocaml/tiny_raw.ml"; "ocaml/tiny_raw.mli";
                  "ocaml/tiny_stubs.c" ]
      ~concrete_pert:(patch "symbol_orphan")
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
      ~mutates:[ "python_cext/tiny_cext/__init__.py";
                  "python_ctypes/tiny_ctypes/__init__.py" ]
      ~concrete_pert:(patch "api_repack_python")
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
      ~mutates:[ "python_cext/tiny_cext/__init__.py";
                  "python_ctypes/tiny_ctypes/__init__.py" ]
      ~concrete_pert:(patch "api_complete_python")
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
      ~mutates:[ "ocaml/tiny_raw.ml"; "ocaml/tiny_raw.mli";
                  "ocaml/tiny_stubs.c" ]
      ~concrete_pert:(patch "api_repack_stub_orphan")
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

    (* Sc.4.OCaml — unmutated run (SSOT §4.1) exercising the
       Sc.3.OCaml + Sc.4.OCaml chain (build_app_with_binding +
       run_app_with_binding). Shares the id string with the
       Good scenario Sc.4.OCaml — a scenario with
       mutation = None IS the Sc.4.OCaml run, not a separate
       id. Legacy id: Pc.1. *)
    mk ~id:"Sc.4.OCaml" ~name:"app_over_binding_ocaml"
      ~description:"Unmutated Sc.N run (SSOT §4.1): an app linking \
                    directly against the Tiny OCaml binding builds and \
                    runs; transitive dependency on libtiny.so resolves."
      ~mutates:[]
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

    (* Sc.6.OCaml — unmutated run (SSOT §4.1) exercising the
       Sc.5.OCaml + Sc.6.OCaml chain (build_app_helper +
       run_app_helper). Same id shape as Sc.4.OCaml above.
       Legacy id: Pc.2. *)
    mk ~id:"Sc.6.OCaml" ~name:"app_over_helper_ocaml"
      ~description:"Unmutated Sc.N run (SSOT §4.1): longest-interesting \
                    chain — app -> tiny_helper -> Tiny binding -> \
                    libtiny.so. Confirms intra-binding repacking \
                    composes across a downstream library layer."
      ~mutates:[]
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

(* Per-Sc.N actions mirror the abstract [Canary_scenario.good_scenarios]
   list. Previously all 8 entries carried [acts_full] (the union of
   every tiny action) — cargo-culted since only downstream copiers read
   [actions] and none dispatched by content. Making this per-scenario
   is the §7.9 prerequisite for [related_artifacts_of_actions] to
   derive the correct hand-lists. *)
let tiny_good_scenarios : Canary_scenario.scenario list = [
  (* Shared upstream *)
  { id = "Sc.1"; name = "build_native_lib";
    description = "Tiny: build libtiny.so from c/src/tiny.c using \
                   gcc; symbol versioning via c/tiny.map (TINY_1.0 \
                   exports). Shared across OCaml and Python.";
    actions = [ Configure; Scan_sources; Build_lib; Install_lib ];
    origin = None;
    belongs_to = [ "Sc.1" ] };

  (* OCaml side *)
  { id = "Sc.2.OCaml"; name = "build_binding";
    description = "Tiny: build the OCaml binding (tiny.cmxa + \
                   libtiny_stubs.a) via cstubs against libtiny.so.";
    actions = [ Build_binding Canary_lang.OCaml ];
    origin = None;
    belongs_to = [ "Sc.2.OCaml" ] };
  { id = "Sc.3.OCaml"; name = "build_app_with_binding";
    description = "Tiny: build probe_baseline.exe / app_binding.exe \
                   linking directly against the tiny OCaml binding.";
    actions = [ Build_app { lang = Canary_lang.OCaml } ];
    origin = None;
    belongs_to = [ "Sc.3.OCaml" ] };
  { id = "Sc.4.OCaml"; name = "run_app_with_binding";
    description = "Tiny: exec probe_baseline / app_binding; loader \
                   resolves libtiny.so.1 at load time.";
    actions = [ Probe_app { lang = Canary_lang.OCaml } ];
    origin = None;
    belongs_to = [ "Sc.4.OCaml" ] };
  { id = "Sc.5.OCaml"; name = "build_app_helper";
    description = "Tiny: build tiny_helper + app_helper.exe — app \
                   linked through an intermediate helper library \
                   over the OCaml binding.";
    actions = [ Build_app { lang = Canary_lang.OCaml } ];
    origin = None;
    belongs_to = [ "Sc.5.OCaml" ] };
  { id = "Sc.6.OCaml"; name = "run_app_helper";
    description = "Tiny: exec app_helper.exe — full chain runs \
                   through tiny_helper into libtiny.so.";
    actions = [ Probe_app { lang = Canary_lang.OCaml } ];
    origin = None;
    belongs_to = [ "Sc.6.OCaml" ] };

  (* Python side (cext under SCAB; ctypes uses DFFI, mechanism
     split deferred). No Sc.3.Python — .py IS the app. No
     Sc.5/Sc.6 — no Python helper in tiny. *)
  { id = "Sc.2.Python"; name = "build_binding";
    description = "Tiny: build the Python cext (\
                   _native.cpython-*.so) against libtiny.so.";
    actions = [ Build_binding Canary_lang.Python ];
    origin = None;
    belongs_to = [ "Sc.2.Python" ] };
  { id = "Sc.4.Python"; name = "run_app_with_binding";
    description = "Tiny: exec probe_baseline.py for the cext path \
                   (SCAB); dyld resolves libtiny.so.1 at import time. \
                   The ctypes probe (DFFI) would be a separate \
                   Sc.4.Python.ctypes once the mechanism axis is \
                   promoted; today it runs but isn't modeled as its \
                   own scenario.";
    actions = [ Probe_app { lang = Canary_lang.Python } ];
    origin = None;
    belongs_to = [ "Sc.4.Python" ] };
]

(** United list: 8 Sc + 15 concrete instantiations (13 Bs +
    2 unmutated Sc.N runs per SSOT §4.1) = 23 scenarios.
    Reference for the `derive_scenarios` experiment
    (§9.3 backlog). *)
let all_scenarios : Canary_scenario.scenario list =
  tiny_good_scenarios
  @ List.map scenario_specs ~f:(fun e -> e.scenario)

(** Derived scenarios — enumerate all (Good × artifact ×
    applicable-kind) cells over tiny's good scenarios. Each
    cell is a candidate mutation; concrete Bs entries fill
    a subset of these cells. *)
let derived_scenarios : Canary_scenario.scenario list =
  Canary_scenario.derive_scenarios tiny_good_scenarios

(** Does a hardcoded Bs entry match a derived cell? Match action:
    same good scenario (via [belongs_to] intersection) + same
    target artifact + same kind. *)
(** Does a bad scenario fill a derived cell? Match action: same Good scenario
    (via [belongs_to] intersection) + same target artifact + same kind. Used
    to compute the "filled vs empty" coverage view over the
    [derive_scenarios] enumeration. *)
let matches_derived_cell
    (bad : Canary_scenario.scenario)
    (derived : Canary_scenario.scenario) : bool =
  match bad.origin, derived.origin with
  | Some (Canary_scenario.Mutation bp),
    Some (Canary_scenario.Mutation dp) ->
    Poly.equal bp.target dp.target
    && Poly.equal bp.kind dp.kind
    && List.exists bad.belongs_to ~f:(fun b ->
         List.mem derived.belongs_to b ~equal:String.equal)
  | _ -> false

(* ================================================================
   §7.2 PHASE 3 — RECIPE SYNTHESIS FROM DERIVED CELLS

   Turns a derived cell (Good × artifact × mutation_kind) into a
   runnable tiny_recipe. Uses the parametric mutation vocabulary
   Phase 1 shipped. Cells whose (target, kind) maps to a mutation
   variant not yet implemented (Drop_c_symbol, Drop_python_attr,
   App-level anything) return [None] — the cell stays empty until
   the primitive lands. Missing-ness stays visible.

   Default target ("which symbol"): hardcoded per user
   2026-07-09 design decision — [tiny_sum] for source-side
   mutations, [sum] for mli. Heuristic picking from
   [api_source.stable_symbols] is future work.
   ================================================================ *)

(** Tiny's contract binding table — the data half of the
    expectation lowering (§7.1 structural expectation, 2026-07-21).
    Each entry declares, for one (contract, language) pair, the
    firing sites where the contract's failure observation shows up
    and how the observation is sourced (artifact prediction /
    behavior grep / placeholder).

    This replaces the ad-hoc [compat_inputs_of_contract] +
    [is_expect_failure_contract] switch tables that used to be
    read from inside [expectation_of_entry]. Adding a new contract
    or wiring one for a new language is a data change: append a
    row here, no code change in the lowering.

    Convention: entries listed even when [firings = []] would be
    valid (silent for this lang). Placeholder entries make the
    "not wired yet" state visible instead of implicit (like
    §5.3's "missing-ness visible" for mutation primitives).

    Positioned before [recipe_of_derived_cell] so the synthesis
    guard there can consult
    {!Canary_scenario.binding_has_live_firing}. *)
let tiny_contract_bindings : Canary_scenario.contract_binding list =
  let module CC = Canary_compat in
  let module CS = Canary_scenario in
  [
    (* c1 — symbol set. Fires at Probe_binding: stub link (Python
       cext import / OCaml stub load) fails when a referenced
       symbol vanished from the native lib. *)
    { contract = CC.C1; lang = Canary_lang.OCaml;
      firings = [
        { site = CS.At_probe_binding Canary_lang.OCaml;
          loc_filter = CS.Any;
          source = CS.From_artifact {
            inputs = CC.[
              C_stub     [ "build_binding_ocaml/inspect.json" ];
              Native_lib [ "build_lib/inspect.json" ];
            ];
            version_info = None;
          }};
      ]};
    { contract = CC.C1; lang = Canary_lang.Python;
      firings = [
        { site = CS.At_probe_binding Canary_lang.Python;
          loc_filter = CS.Any;
          source = CS.From_artifact {
            inputs = CC.[
              C_stub     [ "build_binding_python/inspect.json" ];
              Native_lib [ "build_lib/inspect.json" ];
            ];
            version_info = None;
          }};
      ]};

    (* c2 — API completeness. Probe references a name the binding
       no longer exports. OCaml: undefined value at compile;
       Python: AttributeError at import. Both surface at Probe. *)
    { contract = CC.C2; lang = Canary_lang.OCaml;
      firings = [
        { site = CS.At_probe_binding Canary_lang.OCaml;
          loc_filter = CS.Any;
          source = CS.From_artifact {
            inputs = CC.[
              Ocaml_mli [ "build_binding_ocaml/inspect_mli.json" ];
            ];
            version_info = None;
          }};
      ]};
    { contract = CC.C2; lang = Canary_lang.Python;
      firings = [
        { site = CS.At_probe_binding Canary_lang.Python;
          loc_filter = CS.Any;
          source = CS.From_artifact {
            inputs = CC.[
              Python_attrs [ "build_binding_python/inspect_attrs.json" ];
            ];
            version_info = None;
          }};
      ]};

    (* c3 — API repack. Behavioral; probe emits "FAIL …" when the
       user-facing name maps to the wrong native symbol. *)
    { contract = CC.C3; lang = Canary_lang.OCaml;
      firings = [
        { site = CS.At_probe_binding Canary_lang.OCaml;
          loc_filter = CS.Any;
          source = CS.From_behavior_grep {
            contains_any = [ "FAIL " ]; version_info = None;
          }};
      ]};
    { contract = CC.C3; lang = Canary_lang.Python;
      firings = [
        { site = CS.At_probe_binding Canary_lang.Python;
          loc_filter = CS.Any;
          source = CS.From_behavior_grep {
            contains_any = [ "FAIL " ]; version_info = None;
          }};
      ]};

    (* c4 — ABI (SONAME). Python cext is cached from baseline; on
       lib SONAME bump the cached NEEDED still points at the old
       filename, dyld fails to load. OCaml binding rebuilds fresh
       against the current lib and picks up the new SONAME — c4
       is silent for OCaml under tiny's current store convention.
       See §7.1 remaining blocker: switching to a "packed .a" OCaml
       binding would let c4 fire (Placeholder documents that). *)
    { contract = CC.C4; lang = Canary_lang.Python;
      firings = [
        { site = CS.At_probe_binding Canary_lang.Python;
          loc_filter = CS.Any;
          source = CS.From_artifact {
            inputs = CC.[
              Native_lib  [ "build_lib/inspect.json" ];
              Abi_surface [ "build_binding_python/inspect.json" ];
            ];
            version_info = None;
          }};
      ]};
    { contract = CC.C4; lang = Canary_lang.OCaml;
      firings = [
        { site = CS.At_probe_binding Canary_lang.OCaml;
          loc_filter = CS.Any;
          source = CS.Placeholder { reason =
            "OCaml ABI-analogue: packed .a NEEDED vs libtiny.so \
             SONAME. Awaiting SSOT §? — decide whether tiny's OCaml \
             store convention rebuilds fresh (current: c4 silent) or \
             caches the packed .a (future: c4 fires at Probe_binding \
             OCaml or Build_app OCaml, depending on link timing)." }};
      ]};

    (* c5 — versioned symbol floor. Same store-convention lang scope
       as c4 (cached Python cext carries stale @VER references). *)
    { contract = CC.C5; lang = Canary_lang.Python;
      firings = [
        { site = CS.At_probe_binding Canary_lang.Python;
          loc_filter = CS.Any;
          source = CS.From_artifact {
            inputs = CC.[
              Versioned_exports [ "build_lib/inspect.json" ];
              Versioned_req     [ "build_binding_python/inspect.json" ];
            ];
            version_info = None;
          }};
      ]};

    (* c6 — type/arity. Only OCaml binding rebuilds against the
       mutated header; cstub compile fails at Build_binding OCaml.
       The Probe_binding step of tiny's factory also rebuilds the
       same cstub via dune, so the same failure surfaces there too. *)
    { contract = CC.C6; lang = Canary_lang.OCaml;
      firings =
        (let c6_inputs = CC.[
           Typed_header
             [ "scan_sources/inspect_typed_header.json" ];
           Typed_binding_stub
             [ "scan_sources/inspect_typed_binding_stub_ocaml.json" ];
         ] in
         [
           { site = CS.At_build_binding Canary_lang.OCaml;
             loc_filter = CS.Any;
             source = CS.From_artifact {
               inputs = c6_inputs; version_info = None } };
           { site = CS.At_probe_binding Canary_lang.OCaml;
             loc_filter = CS.Any;
             source = CS.From_artifact {
               inputs = c6_inputs; version_info = None } };
         ])};

    (* c7 — stub orphan. Behavioral: static-only mismatch surfaces
       as probe "FAIL …" line (per api_repack_stub_orphan). *)
    { contract = CC.C7; lang = Canary_lang.OCaml;
      firings = [
        { site = CS.At_probe_binding Canary_lang.OCaml;
          loc_filter = CS.Any;
          source = CS.From_behavior_grep {
            contains_any = [ "FAIL " ]; version_info = None;
          }};
      ]};

    (* c8 — API faithfulness. Blocked on c6+c7 per SSOT §3.4
       contract_status (Blocked [C6; C7]). Placeholder here so the
       shape commits; today's api_faithful Bs enters as
       Expect_success. *)
    { contract = CC.C8; lang = Canary_lang.OCaml;
      firings = [
        { site = CS.At_probe_binding Canary_lang.OCaml;
          loc_filter = CS.Any;
          source = CS.Placeholder { reason =
            "c8 dormant — blocked on c6 + c7 detecting the cases c8 \
             would need. Corresponds to Bs.6 api_faithful, which \
             runs Expect_success everywhere today." }};
      ]};
  ]

(** Synthesize a [tiny_recipe] from a derived cell. Returns [None]
    when the cell's (target, kind) has no implemented parametric
    primitive — the design-space slot exists but no code can fill
    it yet. See tiny.md §7.2. *)
let recipe_of_derived_cell (cell : Canary_scenario.scenario)
  : tiny_recipe option =
  let open Canary_basic in
  let open Canary_artifact_mutation in
  match cell.origin with
  | None
  | Some (Canary_scenario.Version_mismatch | Canary_scenario.Packaging) ->
      None
  | Some (Canary_scenario.Mutation { target; kind; _ }) ->
    (match target, kind with
     | Source, On_artifact Source ->
         (* Rename a C source symbol. Default: tiny_sum → tiny_total.
            Mirrors the existing Bs.1 (symbol_missing) recipe. *)
         let file = "c/src/tiny.c" in
         Some {
           mutates = [ file ];
           mutation = Some (Of_source (Source.rename_c_symbol
             ~file ~from_:"tiny_sum" ~to_:"tiny_total"));
           expected = [];
           violates = [ Canary_compat.C1 ];
         }
     | Source, On_behavior ->
         (* No parametric behavior-change primitive. behavior_silent
            stays as freeform Patch (Bs.7). *)
         None
     | Headers, _ ->
         (* No parametric header mutations. header_arity_bump stays
            as freeform Patch (Bs.2). *)
         None
     | Lib, On_artifact Lib ->
         (* Binary SONAME bump. Default: libtiny.so.1.0 →
            libtiny.so.2.0. Mirrors Bs.4 (abi_soname_bump).
            Skips when c4 has no live firing for any of this
            cell's languages — the C4/OCaml binding is a
            Placeholder today (see tiny_contract_bindings), so
            Sc.2/4/6.OCaml Lib cells synthesize None until the
            placeholder is wired. Sc.1 (langs = [OCaml; Python])
            and Sc.*.Python still synthesize because C4/Python
            has a live From_artifact firing. *)
         let langs = Canary_scenario.langs_of_scenario cell in
         let live = List.exists langs ~f:(fun l ->
           Canary_scenario.binding_has_live_firing
             tiny_contract_bindings Canary_compat.C4 l) in
         if live then
           Some {
             mutates = [ "c/build/libtiny.so.1.0" ];
             mutation = Some (Of_native (Native.soname_bump
               ~from_so:"libtiny.so.1.0" ~to_so:"libtiny.so.2.0"));
             expected = [];
             violates = [ Canary_compat.C4 ];
           }
         else None
     | Binding Canary_lang.OCaml, On_artifact (Binding Canary_lang.OCaml) ->
         (* Drop a val from tiny.mli. Default: val sum. Mirrors Bs.9
            (api_complete). *)
         let file = "ocaml/tiny.mli" in
         Some {
           mutates = [ file ];
           mutation = Some (Of_binding (Binding.drop_ocaml_val
             ~file ~name:"sum"));
           expected = [];
           violates = [ Canary_compat.C2 ];
         }
     | Binding Canary_lang.Python, On_artifact (Binding Canary_lang.Python) ->
         (* Drop a top-level def from tiny_cext/__init__.py. Default:
            def sum. Mirrors Bs.12 (api_complete_python) but on
            python_cext only (Bs.12's patch also hits python_ctypes).
            Byte-parity with the api_complete_python.patch
            python_cext hunk is verified in mutation_regression_tests. *)
         let file = "python_cext/tiny_cext/__init__.py" in
         Some {
           mutates = [ file ];
           mutation = Some (Of_binding (Binding.drop_python_attr
             ~file ~name:"sum"));
           expected = [];
           violates = [ Canary_compat.C2 ];
         }
     | Binding Canary_lang.Python, _ -> None
     | App, _ ->
         (* App-level mutations not parametrized. Sc.3-Sc.6 cells
            stay empty for now — future primitive (App_swap? patch
            of the app source?) needed. *)
         None
     | _ -> None)

(** Convenience: synthesize a full [scenario_spec] from a derived
    cell. Rebuilds the cell's origin with a proper manifest +
    detector so [expectation_of_entry] can derive the right
    [Expect_compat_failure] instead of falling through to
    [Expect_success]. [derive_scenario] defaults to
    [manifest = Unknown_gap] because it's project-agnostic —
    only the project's synthesis table knows which contract
    fires at which step. *)
let scenario_spec_of_derived_cell (cell : Canary_scenario.scenario)
  : scenario_spec option =
  Option.map (recipe_of_derived_cell cell) ~f:(fun recipe ->
    let scenario =
      match cell.origin, recipe.violates with
      | Some (Canary_scenario.Mutation m), first :: _ ->
        (* Attach the first violated contract as the detector,
           and set manifest to Possible over the cell's belongs_to
           (the parent Sc.N id) — that flips
           has_probe_manifestation to true and lets the factory
           derive Expect_compat_failure for probe steps. *)
        { cell with origin = Some (Canary_scenario.Mutation
          { m with
            manifest = Canary_scenario.Possible cell.belongs_to;
            detector = Canary_scenario.Wired first;
          }) }
      | _ -> cell
    in
    { scenario; recipe })

(** All derived cells that successfully synthesize into a
    [scenario_spec]. Enumerable design-space fills. *)
let derived_scenario_specs : scenario_spec list =
  List.filter_map derived_scenarios ~f:scenario_spec_of_derived_cell

(** §7.2 Phase 4: union of hand-listed [scenario_specs] and
    synthesized [derived_scenario_specs], with derived cells that
    duplicate an existing hand-listed Bs (same target + kind +
    belongs_to intersection, per [matches_derived_cell]) dropped.
    Hand takes precedence — a hand-authored Bs's specific mutation
    (patch or Soname_bump) survives; the parametric would produce
    the same design-space slot.

    Concrete count (2026-07-20): 15 hand-listed + N derived after
    dedup. Startup assertion enforces the counts as design-check.
    Use [all_scenario_specs] instead of [scenario_specs] for
    iteration (tiny list / tiny run / tiny status), enumeration,
    and lookup. *)
let all_scenario_specs : scenario_spec list =
  let deduped =
    List.filter derived_scenario_specs ~f:(fun (ds : scenario_spec) ->
      not (List.exists scenario_specs ~f:(fun (h : scenario_spec) ->
        matches_derived_cell h.scenario ds.scenario)))
  in
  scenario_specs @ deduped

(* ================================================================
   ENGINE RENDERING (§4.2 convergence — tiny's mutation axis)
   ================================================================

   Render tiny's designed scenarios as a *projection* of the shared
   enumeration engine [Canary_enumerate]: tiny = fix provision = all
   [Built], walk the mutation axis. Each mutation-carrying [scenario_spec]
   becomes an engine mutation [(slot, id)]; [tiny_slice] then yields one
   point per mutation + one positive — i.e. the old tiny scenarios rendered
   through the new method.

   Two honest caveats (this is the combinatorial skeleton, not a
   replacement):
   - the engine's single positive point collapses tiny's *two* unmutated
     app-wiring runs (Sc.4.OCaml direct, Sc.6.OCaml via-helper): app wiring
     is a tiny-specific sub-axis the abstract engine does not model
     (scenario_coverage §6, "helper scenarios are tiny-specific").
   - the rich per-scenario detail (recipe, contract [violates], the
     [expected] table) stays on [scenario_spec]; the engine carries only
     the (provision, mutation) coordinates. *)

let is_pipeline_artifact : Canary_basic.artifact_kind -> bool = function
  | Canary_basic.Source | Canary_basic.Lib | Canary_basic.Binding _ -> true
  | Canary_basic.Headers | Canary_basic.App -> false

let mutation_target_of_spec (s : scenario_spec) :
    Canary_basic.artifact_kind option =
  match s.scenario.origin with
  | Some (Canary_scenario.Mutation m) -> Some m.Canary_scenario.target
  | _ -> None

(** Default precise identity for a binding kind (used only as a fallback when
    the mutated files don't pin a mechanism). *)
let id_of_kind : Canary_basic.artifact_kind -> Canary_enumerate.artifact_id =
  function
  | Canary_basic.Source -> Canary_enumerate.a_source
  | Canary_basic.Lib -> Canary_enumerate.a_lib
  | Canary_basic.Binding l ->
      let m =
        Option.value
          (Canary_mechanism.default_mechanism_of_lang l)
          ~default:Canary_mechanism.Cstubs
      in
      Canary_enumerate.a_binding l m
  | Canary_basic.Headers -> Canary_enumerate.a_headers
  | Canary_basic.App ->
      Canary_enumerate.{ kind = Canary_basic.App; ext = Ext_none }

(** The precise binding artifact(s) a mutation touches, read off its mutated
    files: [ocaml/] → cstubs, [python_cext/] → cext, [python_ctypes/] →
    ctypes. A mutation on both Python layers (e.g. api_repack_python) yields
    both cext and ctypes. *)
let binding_ids_of_mutates (mutates : string list) :
    Canary_enumerate.artifact_id list =
  let touches p = List.exists mutates ~f:(String.is_prefix ~prefix:p) in
  List.filter_opt
    [ (if touches "ocaml/" then
         Some
           (Canary_enumerate.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs)
       else None);
      (if touches "python_cext/" then
         Some
           (Canary_enumerate.a_binding Canary_lang.Python Canary_mechanism.Cext)
       else None);
      (if touches "python_ctypes/" then
         Some
           (Canary_enumerate.a_binding Canary_lang.Python Canary_mechanism.Ctypes)
       else None) ]

(** The mutation axis: each mutation-carrying spec maps to the precise
    artifact(s) it touches — source/lib coarse, a binding to its exact
    (lang × mechanism) instance(s). A spec that mutates both Python layers
    yields two points (cext and ctypes). *)
let engine_mutations : (Canary_enumerate.artifact_id * string) list =
  List.concat_map all_scenario_specs ~f:(fun s ->
      match mutation_target_of_spec s with
      | Some Canary_basic.Source -> [ (Canary_enumerate.a_source, s.scenario.id) ]
      | Some Canary_basic.Lib -> [ (Canary_enumerate.a_lib, s.scenario.id) ]
      | Some (Canary_basic.Binding _ as k) -> (
          match binding_ids_of_mutates s.recipe.mutates with
          | [] -> [ (id_of_kind k, s.scenario.id) ]
          | ids -> List.map ids ~f:(fun aid -> (aid, s.scenario.id)))
      | Some (Canary_basic.Headers | Canary_basic.App) | None -> [])

(** tiny's full artifact set (all [Built]): source, lib, all three binding
    instances (ocaml cstubs, python cext, python ctypes), and both app
    wirings (direct link, via a helper lib). *)
let engine_artifacts : Canary_enumerate.artifact_id list =
  Canary_enumerate.
    [ a_source; a_lib;
      a_binding Canary_lang.OCaml Canary_mechanism.Cstubs;
      a_binding Canary_lang.Python Canary_mechanism.Cext;
      a_binding Canary_lang.Python Canary_mechanism.Ctypes;
      a_app Direct; a_app Via_helper ]

let engine_points : string Canary_enumerate.point list =
  Canary_enumerate.tiny_slice ~artifacts:engine_artifacts
    ~mutations:engine_mutations

(* ── cross-check: engine projection ↔ hand-written factory ──
   The runner (`tiny run`) executes [all_scenario_specs]; `tiny engine`
   renders [engine_mutations], derived from those specs. These startup
   assertions enforce that the derived view stays faithful as either side
   changes — no mutation-carrying spec silently dropped, no phantom point,
   and the multi-mechanism split (a spec mutating both Python layers ⇒ cext
   *and* ctypes points) holds. *)
let () =
  let pipeline_spec_ids =
    List.filter_map all_scenario_specs ~f:(fun s ->
        match mutation_target_of_spec s with
        | Some (Canary_basic.Source | Canary_basic.Lib | Canary_basic.Binding _)
          ->
            Some s.scenario.id
        | _ -> None)
    |> List.dedup_and_sort ~compare:String.compare
  in
  let engine_ids =
    List.map engine_mutations ~f:snd
    |> List.dedup_and_sort ~compare:String.compare
  in
  let minus a b =
    List.filter a ~f:(fun x -> not (List.mem b x ~equal:String.equal))
  in
  let dropped = minus pipeline_spec_ids engine_ids in
  let phantom = minus engine_ids pipeline_spec_ids in
  if not (List.is_empty dropped && List.is_empty phantom) then
    Stdlib.failwith
      (Printf.sprintf
         "tiny engine \xE2\x86\x94 factory drift: dropped=[%s] phantom=[%s]"
         (String.concat ~sep:";" dropped)
         (String.concat ~sep:";" phantom))

let () =
  List.iter all_scenario_specs ~f:(fun s ->
      let touches pfx =
        List.exists s.recipe.mutates ~f:(String.is_prefix ~prefix:pfx)
      in
      if touches "python_cext/" && touches "python_ctypes/" then
        let exts =
          List.filter_map engine_mutations ~f:(fun (aid, id) ->
              if String.equal id s.scenario.id then Some aid.Canary_enumerate.ext
              else None)
        in
        let has e = List.mem exts e ~equal:Canary_enumerate.equal_artifact_ext in
        if
          not
            (has (Canary_enumerate.Ext_mechanism Canary_mechanism.Cext)
            && has (Canary_enumerate.Ext_mechanism Canary_mechanism.Ctypes))
        then
          Stdlib.failwith
            (Printf.sprintf
               "tiny engine: %s mutates both Python layers but its engine \
                points miss cext/ctypes"
               s.scenario.id))

(** Print the tiny → engine projection + a correspondence report. *)
let print_engine_render () : unit =
  let p = Stdlib.Printf.printf in
  p "tiny → engine projection (tiny_slice: all Built × mutation axis)\n";
  p "  artifacts: %s\n"
    (String.concat ~sep:", "
       (List.map engine_artifacts ~f:Canary_enumerate.string_of_id));
  List.iter engine_points ~f:(fun pt ->
      match pt.Canary_enumerate.mutations with
      | [] -> p "  [positive]  all-Built pipeline\n"
      | (aid, id) :: _ ->
          p "  [mutation]  %-24s on %s\n" id
            (Canary_enumerate.string_of_id aid));
  let n_points_mut = List.length engine_mutations in
  let n_specs =
    List.count all_scenario_specs ~f:(fun s ->
        match mutation_target_of_spec s with
        | Some (Canary_basic.Source | Canary_basic.Lib | Canary_basic.Binding _)
          -> true
        | _ -> false)
  in
  (* mutation-carrying specs whose target is not a pipeline artifact
     (Headers/App) → the engine doesn't place them (a real gap if non-empty). *)
  let unmappable =
    List.filter_map all_scenario_specs ~f:(fun s ->
        match mutation_target_of_spec s with
        | Some k when not (is_pipeline_artifact k) -> Some s.scenario.id
        | _ -> None)
  in
  p "\n  artifacts: %d (incl. both app wirings + all 3 binding mechanisms)\n"
    (List.length engine_artifacts);
  p "  engine:    1 positive + %d mutation point(s)\n" n_points_mut;
  p "  from:      %d mutation-carrying spec(s) — a spec touching both Python \
     layers yields 2 points (cext + ctypes)\n" n_specs;
  match unmappable with
  | [] -> p "  \xE2\x9C\x93 every tiny mutation maps to a precise pipeline artifact\n"
  | ids ->
      p "  \xE2\x9C\x97 unrenderable (not a pipeline artifact): %s\n"
        (String.concat ~sep:", " ids)

(* ── tiny-full (step A: the positive-variant enumeration view) ──
   tiny as a *general project*: the algorithm enumerates the positive
   scenario space over provider × version (a project ships its whole
   declared artifact set; presence is not a choice). This is the *view*
   ([print_tiny_full]); the good+bad RUN — positive witnesses + the
   enumerated mutation points, algorithm-driven — is [run_tiny_full] below
   (shipped 2026-08-02). status.md §1a. *)
let tiny_full_artifacts : Canary_enumerate.artifact_id list = engine_artifacts

let tiny_full_points : string Canary_enumerate.point list =
  (* A project ships its *whole declared set* of artifacts (the binding list
     is a fixed set of (lang, mechanism) pairs — presence is not a choice).
     So the positive space is the project's **variants** = provider × version,
     all artifacts present. v1: provider fixed [Built] (Fetched needs
     packaging); version whole-scenario (per-artifact version *mismatch* is a
     bad scenario, not here). → the analogue of z3's dev/stable variants. *)
  List.concat_map Canary_basic.two_channels ~f:(fun v ->
      Canary_enumerate.general_slice ~artifacts:tiny_full_artifacts
        ~provisions:Canary_enumerate.[ Built ] ~versions:[ v ])

let print_tiny_full () : unit =
  let p = Stdlib.Printf.printf in
  p "tiny-full — general-project enumeration (positive; provision × version)\n";
  p "  artifacts: %s\n"
    (String.concat ~sep:", "
       (List.map tiny_full_artifacts ~f:Canary_enumerate.string_of_id));
  List.iteri tiny_full_points ~f:(fun i pt ->
      p "  [%3d] %s\n" (i + 1)
        (Canary_enumerate.string_of_assignment pt.Canary_enumerate.assignment));
  p "\n  %d positive scenarios = tiny-full's variants (all declared \
     artifacts present; provider fixed Built, version {dev,stable}). Grows \
     with the provider axis (Built/Fetched) once tiny is packaged; the \
     interesting space is the mutations (step B).\n"
    (List.length tiny_full_points)

(* Startup assertion — count of derived cells after dedup. Update
   the expected count when the synthesis table or the hand-listed
   Bs's change. *)
let () =
  let derived_after_dedup =
    List.length all_scenario_specs - List.length scenario_specs
  in
  (* 11 synthesized - 4 deduped (Bs.1/4/8-13 + Bs.12 api_complete_python
     on Sc.2.Python.A2) = 7 net. *)
  let expected_derived_after_dedup = 7 in
  if derived_after_dedup <> expected_derived_after_dedup then
    Stdlib.failwith
      (Printf.sprintf
         "all_scenario_specs: %d derived cells after dedup \
          (expected %d). Check dedup action + synthesis table."
         derived_after_dedup expected_derived_after_dedup)

(* Startup assertion: the synthesis table doesn't crash on any
   derived cell; count Some vs None matches the design table in
   tiny.md §7.2 Phase 3. Update this expected count whenever the
   synthesis table grows a new (target, kind) entry. *)
let () =
  let some_n = List.length derived_scenario_specs in
  let none_n = List.length derived_scenarios - some_n in
  (* 14 total = 3 Source + 3 Lib (Python-in-langs only, 3 skipped OCaml)
     + 4 Binding OCaml + 2 Binding Python + 2 On_behavior + 4 Headers +
     App slots + N. Net Some = 11 (Source×3 + Lib×3 + BindingOCaml×3
     + BindingPython×2); None = 9. Adjust when the synthesis table
     changes. *)
  let expected_some = 11 in
  let expected_none = 9 in
  if some_n <> expected_some || none_n <> expected_none then
    Stdlib.failwith
      (Printf.sprintf
         "recipe_of_derived_cell: synthesized %d/%d cells (expected \
          %d Some + %d None). Update the count if the synthesis \
          table changed."
         some_n (some_n + none_n) expected_some expected_none)

(* Startup validator — a scenario that claims [manifest = Possible _]
   (expected to fire at probe) must have at least one live firing in
   [tiny_contract_bindings] for one of its violates × langs. Catches
   the shape "you wired a Bs entry expecting failure detection, but
   every contract you listed is a Placeholder for the relevant
   languages" — the mutation would apply, expectation_of_entry would
   emit Expect_success everywhere, and the run would silently pass
   (or unexpected_failure). Aligns with the §7.2 "missing-ness
   visible" principle. *)
let () =
  let open Base in
  let module CS = Canary_scenario in
  let has_live entry =
    let langs = CS.langs_of_scenario entry.scenario in
    List.exists entry.recipe.violates ~f:(fun c ->
      List.exists langs ~f:(fun l ->
        CS.binding_has_live_firing tiny_contract_bindings c l))
  in
  let offenders =
    List.filter all_scenario_specs ~f:(fun entry ->
      CS.has_probe_manifestation entry.scenario
      && not (has_live entry))
  in
  if not (List.is_empty offenders) then
    Stdlib.failwith
      (Printf.sprintf
         "tiny_contract_bindings validator: %d scenario(s) claim \
          manifest=Possible but no live firing exists in the \
          bindings table for any of their (violates × langs) — \
          probe would silently emit Expect_success. \
          Offenders: %s. Wire the binding, mark the scenario \
          Unknown_gap, or remove the empty violates entry."
         (List.length offenders)
         (String.concat ~sep:", "
            (List.map offenders ~f:(fun e -> e.scenario.name))))

(* ================================================================
   HELPERS
   ================================================================ *)

let find_by_name (n : string) : scenario_spec option =
  List.find all_scenario_specs ~f:(fun e -> String.equal e.scenario.name n)

(** Look up a spec by its scenario id ("Bs.1", …). The mutation axis
    ([engine_mutations]) keys on [scenario.id]; the runner keys on
    [scenario.name] — this bridges the two so the algorithm-driven
    tiny-full run can resolve an enumerated mutation point to a runnable
    scenario. *)
let find_by_id (scenario_id : string) : scenario_spec option =
  List.find all_scenario_specs ~f:(fun e ->
      String.equal e.scenario.id scenario_id)

(** Shared iteration over {!all_scenario_specs} — hand-listed
    Bs's + Pc unmutated witnesses + synthesized derived cells
    (§7.2 Phase 4). Callers pass a per-spec callback receiving
    1-based index + total. Guarantees a single ordering source
    for [tiny list], [tiny run], [tiny status] and any future
    enumeration — update the ordering here (or by reordering
    [scenario_specs] / [derived_scenario_specs]) and the change
    propagates to all three. *)
let iter_scenario_specs
    ~(f : index:int -> total:int -> spec:scenario_spec -> unit)
  : unit =
  let n = List.length all_scenario_specs in
  List.iteri all_scenario_specs
    ~f:(fun i spec -> f ~index:(i + 1) ~total:n ~spec)

(** Compact contract label — ["c1"..."c8"] via
    {!Canary_compat.string_of_contract_id}, or ["gap"] for [Detector_gap]. *)
let detector_short = function
  | Canary_scenario.Wired c -> Canary_compat.string_of_contract_id c
  | Canary_scenario.Detector_gap -> "gap"

(** 1-based index of an artifact in a scenario's [related_artifacts], or
    [None] if not present. *)
let artifact_index (sc : Canary_scenario.scenario)
    (target : Canary_basic.artifact_kind) : int option =
  let rec find i = function
    | [] -> None
    | a :: _ when Poly.equal a target -> Some i
    | _ :: rest -> find (i + 1) rest
  in
  find 1 (Canary_scenario.related_artifacts sc)

(** For a bad scenario, format its target relative to a Good scenario's
    [related_artifacts]: ["A<idx>"] or ["A<idx> (behavior)"] for
    [On_behavior] kind. Used by display code. *)
let bad_target_str (good : Canary_scenario.scenario)
    (bad : Canary_scenario.scenario) : string =
  match bad.origin with
  | None | Some (Canary_scenario.Version_mismatch | Canary_scenario.Packaging) -> ""
  | Some (Canary_scenario.Mutation p) ->
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

(** Print one Good scenario with its full mutation-cell
    grid (from [derived_scenarios]). Under each cell
    (Good × target × kind):
    - "— empty" if no Bs entry fills the cell (a design-space
      gap the current inventory doesn't cover);
    - otherwise the Bs entries that instantiate the cell,
      each with its detector tag.

    Cells come from principled enumeration; Bs entries are
    hand-listed instances. This layout makes the coverage vs
    hardcoded diff visible inline. *)
let print_one_good
    ?(status_of : (string -> string option) option) (good : Canary_scenario.scenario) : unit =
  let status_suffix name =
    match status_of with
    | None -> ""
    | Some f -> (match f name with Some s -> " " ^ s | None -> "") in
  Stdlib.print_endline
    (Printf.sprintf "  %s  %s" good.id good.name);
  let related_strs =
    List.mapi (Canary_scenario.related_artifacts good) ~f:(fun i a ->
      Printf.sprintf "A%d(%s)" (i + 1)
        (Canary_basic.string_of_artifact_kind a))
  in
  Stdlib.print_endline
    (Printf.sprintf "    related: %s"
       (String.concat ~sep:", " related_strs));
  let belongs_to_here e =
    List.mem e.scenario.belongs_to good.id ~equal:String.equal in
  let cells_here = List.filter derived_scenarios ~f:(fun d ->
    List.mem d.belongs_to good.id ~equal:String.equal) in
  let bads = List.filter all_scenario_specs ~f:(fun e ->
    belongs_to_here e && Option.is_some e.scenario.origin) in
  let n_filled = List.count cells_here ~f:(fun d ->
    List.exists bads ~f:(fun e -> matches_derived_cell e.scenario d)) in
  let n_empty = List.length cells_here - n_filled in
  (if List.is_empty cells_here then
     Stdlib.print_endline "    cells: (none)"
   else begin
     Stdlib.print_endline
       (Printf.sprintf "    cells (%d: %d filled, %d empty):"
          (List.length cells_here) n_filled n_empty);
     List.iter cells_here ~f:(fun d ->
       let tgt = bad_target_str good d in
       let matching = List.filter bads ~f:(fun e ->
         matches_derived_cell e.scenario d) in
       if List.is_empty matching then
         Stdlib.print_endline
           (Printf.sprintf "      %-14s — empty" tgt)
       else
         List.iteri matching ~f:(fun i e ->
           let sc = e.scenario in
           let m = match sc.origin with
             | Some (Canary_scenario.Mutation m) -> m
             | _ -> failwith "expected Mutation origin"
           in
           let det = detector_short m.detector in
           let prefix = if i = 0 then tgt else "" in
           Stdlib.print_endline
             (Printf.sprintf "      %-14s %s %s [%s]%s"
                prefix (pad_id sc.id) (pad_name sc.name) det
                (status_suffix sc.name))))
   end);
  Stdlib.print_endline ""

(* print_derive removed 2026-07-07: coverage view now folded
   into print_list (Option 1). Derived cells iterated inline
   under each Good scenario; filled cells show their Bs; empty
   cells show "— empty". derived_scenarios /
   matches_derived_cell helpers stay for use inside print_list. *)

(** Show-list-but-no-run — the enumeration surface. Prints all
    tiny Good scenarios grouped by language (Shared / OCaml /
    Python), with each followed by its mutations (bad
    scenarios). Unmutated Sc.N runs (SSOT §4.1) are rendered
    separately as a top-level "Unmutated" section (not folded
    under each Sc.N block, which would be a trivial
    self-reference).

    Language-as-outer-loop reflects the user's design intent:
    scenarios are defined per (mechanism × language × stage),
    and grouping by language makes the mechanism-specific
    mutation enumeration read cleanly. Sc.1 stays shared
    (native lib is language-agnostic under the SCAB assumption).

    See SSOT §5.1 for the full detail table. *)
let print_list ?(status_of : (string -> string option) option) () =
  let goods_by_lang lg =
    List.filter tiny_good_scenarios
      ~f:(fun g -> Poly.equal (lang_of_id g.id) lg)
  in
  let bads = List.filter all_scenario_specs ~f:(fun e ->
    Option.is_some e.scenario.origin) in
  let n_bad = List.length bads in
  let n_cells = List.length derived_scenarios in
  let n_cells_filled = List.count derived_scenarios ~f:(fun d ->
    List.exists bads ~f:(fun e -> matches_derived_cell e.scenario d)) in
  Stdlib.print_endline
    (Printf.sprintf "Good scenarios: %d (Sc.N patterns)"
       (List.length tiny_good_scenarios));
  Stdlib.print_endline
    (Printf.sprintf "Bad scenarios:  %d (all Mutation-origin today), \
                     covering %d of %d design-space cells (%d empty)"
       n_bad n_cells_filled n_cells (n_cells - n_cells_filled));
  Stdlib.print_endline "";
  let section title lg =
    let goods = goods_by_lang lg in
    if not (List.is_empty goods) then begin
      Stdlib.print_endline (Printf.sprintf "%s:" title);
      List.iter goods ~f:(print_one_good ?status_of)
    end
  in
  section "Shared" Shared;
  section "OCaml" OCaml_lang;
  section "Python" Python_lang

(** Validate a scenario name at start-up. Returns the string
    unchanged if [n] is a known scenario name (one of the 15 in
    [scenario_specs]) or the special sentinel ["baseline"] (referring
    to [_cache/baseline/workspace/]). Raises [Failure] otherwise. *)
let name_of_string (n : string) : string =
  if String.equal n "baseline" then n
  else
    match find_by_name n with
    | Some _ -> n
    | None ->
      let known = List.map all_scenario_specs ~f:(fun e -> e.scenario.name) in
      Stdlib.failwith
        (Printf.sprintf
           "unknown tiny scenario: %S. Known: %s (or \"baseline\")"
           n (String.concat ~sep:", " known))

(** Human-readable contract label used by the Python harness's JSON
    output ("Symbol", "Type", "ABI", …). Distinct from
    [Canary_compat.string_of_contract_id] which emits "c1".."c8".
    Used by [print_expected] to preserve the JSON shape. *)
(** Human-readable contract label — ["Symbol"], ["ABI"], ["Type"], …
    Distinct from {!Canary_compat.string_of_contract_id} (["c1"..."c8"]).
    Used by tiny's [confirm_ill.json] and [tiny expected] output for legacy
    parity with the Python harness. *)
let violates_label = function
  | Canary_compat.C1 -> "Symbol"
  | C2 -> "API-completeness"
  | C3 -> "Behavior"
  | C4 -> "ABI"
  | C5 -> "SymbolVersion"
  | C6 -> "Type"
  | C7 -> "API-repacking"
  | C8 -> "API-faithfulness"

let json_of_entry (e : scenario_spec) : Yojson.Basic.t =
  `Assoc [
    "scenario", `String e.scenario.name;
    "description", `String e.scenario.description;
    "violates", `List (List.map e.recipe.violates
                         ~f:(fun c -> `String (violates_label c)));
    "mutates", `List (List.map e.recipe.mutates
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
   - mutation.target that isn't in the scenario's
     related_artifacts.

   Failure here means the entries above are structurally wrong;
   the module fails to initialise rather than silently
   propagating the bug through prepare / canary variants. *)

let () =
  List.iter tiny_good_scenarios ~f:Canary_scenario.validate_scenario;
  List.iter all_scenario_specs ~f:(fun e -> Canary_scenario.validate_scenario e.scenario)

(* §7.9 (2026-07-10): [related_artifacts] is no longer a
   field on [scenario] — it derives from [scenario.actions]
   via [Canary_scenario.related_artifacts_of_actions]. No
   hand-vs-derived invariant to enforce; the derivation is
   the sole source of truth. *)

(* ── tiny-full as a mutation-AGNOSTIC project spec (Phase 2a, 2026-08-02) ──

   Core principle (status §1a): the tiny-full *runner* knows NOTHING about
   mutations. Badness lives in the artifact's VERSION IDENTITY — a
   [Canary_enumerate.build_id] whose [quality] is [Bad tag], where [tag] is an
   OPAQUE build tag (the "special version string"). The runner ranges over
   [Canary_enumerate.assignment]s (one placement = provision × version) exactly
   as a general project does; a bad build is just a build at a bad-quality
   version. Only the materializer (below) knows a bad tag corresponds to a
   mutation. This mirrors a real project: z3 builds `lib@stable` and canary
   *detects* the mismatch. (P2a folded away the Phase-1 `variant_tag` side
   channel — the tag is now part of `placement.version`.) *)

(* The bad build tags a project offers per artifact = the factory's mutation
   catalogue grouped by the artifact each mutation targets (from
   [engine_mutations]); the tag is the factory scenario id, but the runner
   never interprets it. *)
let tiny_full_bad_tags_of (aid : Canary_enumerate.artifact_id) : string list =
  List.filter_map engine_mutations ~f:(fun (a, sid) ->
      if Canary_enumerate.equal_artifact_id a aid then Some sid else None)

type tiny_full_spec = {
  tf_artifacts : Canary_enumerate.artifact_id list;
  tf_bad_tags_of : Canary_enumerate.artifact_id -> string list;
}

let tiny_full_spec : tiny_full_spec =
  { tf_artifacts = engine_artifacts; tf_bad_tags_of = tiny_full_bad_tags_of }

(* A tiny-full placement: the artifact is a [Vendored] local resource — the
   tiny-factory provides each artifact's variants (good + bad) as pre-built
   resources, and tiny-full points at the chosen one (it does not rebuild per
   scenario). The only thing that varies is the version [quality] (Good / Bad
   tag), i.e. WHICH vendored variant. *)
let tiny_full_placement ?(provision = Canary_enumerate.Vendored)
    ?(channel = Canary_basic.Stable) ?(quality = Canary_enumerate.Good) () :
    Canary_enumerate.placement =
  let open Canary_enumerate in
  { provision; version = { channel; quality } }

(* P2a assignment enumeration: the good+bad space as [Canary_enumerate.assignment]s
   over one fixed artifact set — 1 all-Good + one point per (artifact, bad-tag)
   with that artifact at version [dev#tag]. Phase 3 generalises to several bad
   artifacts per assignment (= combinations). *)
let tiny_full_assignments (spec : tiny_full_spec) :
    Canary_enumerate.assignment list =
  (* A4: the good baseline + single-bads come from a DECLARED spec (stage 1)
     enumerated under a POLICY (stage 2), not a hand-built list. The spec is the
     project fact — the artifacts, all Vendored @ Stable. The mutation universe
     (the (artifact, bad-tag) fault injection) is the tiny-factory's testing
     POLICY, so it lives in the policy, not the spec. *)
  let tiny_enum_spec : Canary_enumerate.project_spec =
    { ps_universe =
        List.map spec.tf_artifacts ~f:(fun a ->
            (a, [ (Canary_enumerate.Vendored, [ Canary_basic.Stable ]) ])) }
  in
  let tiny_policy : string Canary_enumerate.policy =
    { config =
        Canary_enumerate.{ provision = Free; version = Free; mutation = Full };
      mutations =
        List.concat_map spec.tf_artifacts ~f:(fun aid ->
            List.map (spec.tf_bad_tags_of aid) ~f:(fun tag -> (aid, tag))) }
  in
  let good_and_bads =
    Canary_enumerate.enumerate ~tag:Fn.id ~policy:tiny_policy tiny_enum_spec
  in
  (* Built-lib provision/version variants — KEPT hand-built: the lib is [Built]
     (canary compiles it) at [Stable] and [Dev] (with -DTINY_DEV) while the other
     artifacts stay [Vendored]@[Stable]. The per-artifact provision+version axes
     CAN now express this shape (A1 + per-artifact version), but routing it
     through the spec needs the source-primary resolution first: tiny's [Dev] is
     a -DTINY_DEV build flag, not a source version, so a Built@Dev lib over a
     Stable source violates source-primary. Hand-built until that's resolved. *)
  let all_good_built_lib_at channel =
    List.map spec.tf_artifacts ~f:(fun a ->
        if Canary_enumerate.equal_artifact_id a Canary_enumerate.a_lib then
          (a, tiny_full_placement ~provision:Canary_enumerate.Built ~channel ())
        else (a, tiny_full_placement ()))
  in
  good_and_bads
  @ [ all_good_built_lib_at Canary_basic.Stable;
      all_good_built_lib_at Canary_basic.Dev ]

(* tiny-full's GENERAL project_spec (stage 1, DECLARED — no mutations): the
   good baseline + the built-lib provision/version variants all come out of the
   one enumeration, like sqlite. The mutation faults (flavor-1, the fault
   ORACLE) are tiny1's job (`canary tiny run`), NOT a general project_run
   mechanism; [tiny_full_assignments]/[tiny_full_combinations] stay here as
   tiny-factory machinery.

   Two declaration choices (both the sqlite precedent):
   - [a_source] is NOT an enumerated artifact: tiny's Built lib is
     SELF-CONTAINED — the materializer compiles the vendored source tree
     inside the runner_spec closure, exactly as sqlite's build_lib fetches the
     amalgamation internally. This is also what resolves the old
     source-primary blocker: tiny's Dev is a -DTINY_DEV build *flag* on the
     one vendored source tree, not a source version, so there is no
     source@version chain for [assignment_ok] to enforce. (a_source stays in
     [tiny_full_artifacts] for the spec display.)
   - PER-PROVISION versions: the Vendored lib exists only as the Stable cached
     artifact; the Built lib ranges over {Stable, Dev} (the -DTINY_DEV build).
   - The OCAML BINDING carries its own version axis {Stable, Dev}: the Dev
     binding is the [ocaml_dev/] source variant — a consumer requiring the
     dev-only [tiny_scale] (the forward/deploy MISMATCH, status §B; tiny's
     analogue of llvm_example_dev.ml). Binding version ≠ lib version is a
     legal world by design ("that difference is the interesting mismatch"):
     binding@dev × lib@stable FAILS at the probe link (c1 predicts
     "tiny_scale" agnostically → detected xfail); binding@dev × lib built@dev
     passes. Product: 3 lib instances × 2 binding versions = 6 worlds. *)
let tiny_full_general_spec (spec : tiny_full_spec) :
    Canary_enumerate.project_spec =
  let a_oc =
    Canary_enumerate.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs
  in
  (* ONE data table (A8): per artifact, (provision × versions). Derived from
     [tf_artifacts] so the factory stays the artifact-set source. *)
  { ps_universe =
      List.filter_map spec.tf_artifacts ~f:(fun a ->
          if Canary_enumerate.equal_artifact_id a Canary_enumerate.a_source
          then None
          else if Canary_enumerate.equal_artifact_id a Canary_enumerate.a_lib
          then
            Some
              ( a,
                [ (Canary_enumerate.Vendored, [ Canary_basic.Stable ]);
                  (Canary_enumerate.Built, Canary_basic.[ Stable; Dev ]) ] )
          else if Canary_enumerate.equal_artifact_id a a_oc then
            Some
              (a, [ (Canary_enumerate.Vendored, Canary_basic.[ Stable; Dev ]) ])
          else
            Some
              (a, [ (Canary_enumerate.Vendored, [ Canary_basic.Stable ]) ])) }

(* No assignment-list wrappers here: the general algorithm
   ([Canary_project_run.scenarios_of] over [tiny_full_general_spec]) is the
   only producer of tiny-full's scenario list — full or thin
   ([Canary_project_run.thin_policy]) is the RUNNER's policy choice. *)

(* P3 combination enumeration: representative MULTI-bad assignments along the
   dependency chain (source → lib → ocaml binding), one representative (first)
   bad-tag per bad artifact. These are the scenarios beyond tiny1 — a single
   tiny-full project holds what tiny1 splits into separate projects. tiny-full
   just DECLARES these resource-sets; it does NOT predict the outcome. Canary
   runs fail-fast over the vendored resources and discovers the first failure
   itself — the "collapse" is emergent from canary's run, not a spec
   computation. *)
let tiny_full_combinations (spec : tiny_full_spec) :
    Canary_enumerate.assignment list =
  let first_tag aid = List.hd (spec.tf_bad_tags_of aid) in
  (* combinations range over DISTINCT vendored resources (ssot §4.2.5): source
     and lib collapse to the same "lib" resource in the vendored model
     ([resource_id_of_tag]), so a source+lib pair would overlay the SAME slot
     and degenerate to a single bad variant. The real multi-bad axis is
     lib × ocaml-binding × python-binding — three separate overlay slots.
     canary runs fail-fast and detects the FIRST failure down the chain; the
     later badness is masked — the emergent "collapse". *)
  let chain =
    List.filter_map
      Canary_enumerate.
        [ a_lib;
          a_binding Canary_lang.OCaml Canary_mechanism.Cstubs;
          a_binding Canary_lang.Python Canary_mechanism.Cext ]
      ~f:(fun aid ->
        match first_tag aid with Some t -> Some (aid, t) | None -> None)
  in
  let assignment_with bads =
    List.map spec.tf_artifacts ~f:(fun a ->
        match
          List.find bads ~f:(fun (aid, _) ->
              Canary_enumerate.equal_artifact_id aid a)
        with
        | Some (_, tag) ->
            (a, tiny_full_placement ~quality:(Canary_enumerate.Bad tag) ())
        | None -> (a, tiny_full_placement ()))
  in
  (match chain with
   | [ a; b; c ] -> [ [ a; b ]; [ b; c ]; [ a; c ]; [ a; b; c ] ]
   | _ -> [])
  |> List.map ~f:assignment_with

let assignment_is_all_good (a : Canary_enumerate.assignment) : bool =
  let open Canary_enumerate in
  List.for_all a ~f:(fun (_, pl) ->
      match pl.version.quality with Good -> true | Bad _ -> false)

(** Tiny lives in-tree. All shell commands here run from the tola
    repository root (canary's runner inherits the invoker's cwd, which
    for [dune exec] is the project root). Relative paths anchor to
    [canary/examples/tiny/] explicitly. *)
let tiny_root = "canary/examples/tiny"

(** Absolute path to tiny's cmake build directory (where {i n4
    lib_native.so} ends up). Used for [LIBRARY_PATH] / [LD_LIBRARY_PATH]
    so the OCaml binding's cstubs link against the right libtiny. *)
let tiny_lib_dir = Printf.sprintf "$PWD/%s/c/build" tiny_root

(** The three C symbols the tiny native lib exports — what every binding
    requires. Drift here is what {i e1 symbol_missing} induces; canary
    catches it via the [stable_symbols] watchlist in [api_source]. *)
let tiny_native_stable_symbols = [ "tiny_sum"; "tiny_diff"; "tiny_offset" ]

(** Module + val watchlist on {i bo4 user_binding_ocaml.mli}. The dotted
    paths resolve against the [Tiny] module's vals at inspect time.
    Dropping one of these from [Tiny.mli] (= {i e6 api_complete}) makes
    {i c2 cmp_api_completeness} predict the failure. *)
let tiny_ocaml_module_watchlist =
  [ "Tiny"; "Tiny.sum"; "Tiny.diff"; "Tiny.offset" ]

(** Attribute watchlist on {i bpe2 user_binding_cext.py}. Dropping one
    of these from [tiny_cext/__init__.py] (= {i e11 api_complete_python})
    makes {i c2 cmp_api_completeness} on the Python side predict the
    failure. (Python ctypes — {i bpc2} — is intentionally not driven
    by canary; see header docstring.) *)
let tiny_python_module_watchlist = [ "sum"; "diff"; "offset" ]

(** Canary's [api_source] is the typed declaration of what tiny's surfaces
    are. [derive_steps] uses this to auto-generate inspect-and-watchlist
    steps after each Build/Probe, which is how canary detects drift the
    same way the standalone harness does.

    - [native_api.headers] declares {i n3 header_native.h}.
    - [native_api.components = [Headers; Runtime_lib; Link_lib]] declares
      that tiny exposes a header file, a runtime [.so] ({i n4}), and a
      link-time symlink (also {i n4} via [libtiny.so → libtiny.so.1]).
    - [stable_symbols] drives a symbol-level watchlist that {i c1
      cmp_symbol} would check against {i n4}'s exported set (catches {i e1
      symbol_missing}).
    - The OCaml binding_api carries the module watchlist (catches
      {i e6 api_complete}).
    - The Python binding_api carries the attr watchlist (catches
      {i e11 api_complete_python}). *)
let tiny_api_source : Canary_artifact_api.t =
  let native_api : Canary_artifact_api.native_api =
    {
      kind = C;
      components = [ Headers; Runtime_lib; Link_lib ];
      headers =
        Some
          {
            dir = "c/include";
            files = [ "tiny.h" ];
          };
      symbol_prefixes = [ "tiny_" ];
      stable_symbols = tiny_native_stable_symbols;
      versioned_symbols = [];
      soname    = Some "libtiny.so.1";   (** {i c4 cmp_abi} reference SONAME (live via [lib_soname_bumped] variant) *)
      c_runtime = None;
      cxx_abi   = None;
    }
  in
  let ocaml_binding : Canary_artifact_api.binding_api =
    {
      lang = OCaml;
      source_dir = Some "ocaml";
      module_watchlist = tiny_ocaml_module_watchlist;
      type_watchlist = [];
    }
  in
  let python_binding : Canary_artifact_api.binding_api =
    {
      lang = Python;
      source_dir = Some "python_cext/tiny_cext";
      module_watchlist = tiny_python_module_watchlist;
      type_watchlist = [];
    }
  in
  { native_api; binding_apis = [ ocaml_binding; python_binding ] }

(** {1 Variants}

    Tiny is multi-variant. Each variant is a named [runner_spec] value
    whose expectation field encodes which surface-theory contracts canary
    expects to fire at which stages — {i not} which scenario produced the
    artifacts. The harness↔canary mapping lives in
    [doc/canary/research/tiny.md] (or a wrapper script), not here.

    - [base_runner_spec]: unmutated Sc.N run (SSOT §4.1).
      Every step is expected to succeed (Expect_success).
      Corresponds to the unmutated tiny build / harness
      scenarios [e12 baseline_canary] / [e13 baseline_unbroken].
    - [lib_broken_runner_spec]: at probe_binding_ocaml, expect c1
      cmp_symbol to fire. Used when the lib at runtime lacks a symbol
      the OCaml binding stub requires. Maps to harness scenario
      [e1 symbol_missing] but doesn't know it.

    More variants land as we expand coverage (next candidates:
    [binding_mli_broken] for c2, [binding_python_attrs_broken] for c2
    Python, [binding_overdeclares_stubs] for c1 from the orphan
    direction).

    Convenience: [runner_spec] aliases [base_runner_spec] for callers
    that don't need to distinguish variants.
*)

(** {1 Per-artifact-kind stores (Phase 14b', 2026-06-02)}

    The spec is parameterized by [stores] rather than a single
    workspace path. Each field is a directory serving one artifact
    kind:

    - [source]: tree root containing [c/], [ocaml/], [python_cext/].
      Provides source files for all builds (dune compiles binding from
      [source/ocaml/], cmake configures from [source/c/], Python probe
      reads [source/python_cext/examples/]). Also the dune workspace
      root ([dune build --root source] — outputs land at
      [source/_build/default/]).

    - [lib_dir]: directory containing [libtiny.so*]. The provider for
      the Lib artifact. Canary's [build_lib] verifies presence here
      rather than running cmake; [LIBRARY_PATH] and [LD_LIBRARY_PATH]
      point at this dir.

    - [python_cext_root]: directory under which the [tiny_cext/]
      package lives. The provider for the Python Binding artifact
      ([python_cext_root/tiny_cext/_native.cpython-*.so]). Used as
      [PYTHONPATH] when running Python probes.

    For today's three variants every store points into the same
    materialized workspace (via [stores_of_workspace]). Cross-product
    variants — e.g. baseline source + mutated lib — would construct
    stores with paths from different workspaces. Cross-products are
    parked under Phase 14c in [plan.md]; this layout opens the door. *)
type tiny_stores = {
  source : string;
  lib_dir : string;
  lib_filename : string;  (* basename within lib_dir, e.g. "libtiny.so.1" *)
  python_cext_root : string;
}

(** Default stores derived from a single materialized workspace —
    the common case when a variant uses one harness scenario.
    [lib_filename] defaults to [libtiny.so.1]; SONAME-bump variants
    override it (e.g. abi_soname_bump's workspace has [libtiny.so.2]). *)
let stores_of_workspace ?(lib_filename = "libtiny.so.1") ~workspace_root () = {
  source = workspace_root;
  lib_dir = [%string "%{workspace_root}/c/build"];
  lib_filename;
  python_cext_root = [%string "%{workspace_root}/python_cext"];
}

let make_base_runner_spec
    ?(probe_exe = "ocaml/examples/probe_baseline.exe")
    ?(channel = Canary_basic.Stable)
    ~(stores : tiny_stores) () : Canary_step_builder.runner_spec =
  let { source; lib_dir; lib_filename; python_cext_root } = stores in
  (* version axis: a [Dev] lib is compiled with -DTINY_DEV and the dev version
     script (adds tiny_scale@@TINY_2.0); [Stable] is the base TINY_1.0. Only
     the Built path uses this (the guarded build below); Vendored just probes a
     pre-built lib. *)
  let is_dev = match channel with Canary_basic.Dev -> true | Canary_basic.Stable -> false in
  (* Absolute lib_dir for {LIBRARY,LD_LIBRARY,LD_RUN}_PATH — $PWD
     anchors to canary's invocation cwd (the tola root). *)
  let abs_lib_dir = [%string "$PWD/%{lib_dir}"] in
  let lib_path = [%string "%{lib_dir}/%{lib_filename}"] in
  let ocaml_build_dir =
    [%string "%{source}/_build/default/ocaml"] in
  let cext_so_glob =
    [%string "%{python_cext_root}/tiny_cext/_native.cpython-*.so"] in
  {
    Canary_step_builder.empty_runner_spec with

    (* No fetch_source: workspace is pre-materialized. *)
    api_source = Some tiny_api_source;

    (* Configure / Build_lib: the workspace store provides libtiny.so.*
       pre-built (the harness ran cmake at prepare-all time). Canary
       verifies the cached artifact rather than re-running cmake — the
       workspace deliberately omits CMakeCache.txt because it encodes
       the live tree's absolute source path. This matches the long-term
       "store provides artifacts" model: a mutated-lib variant just
       points at a different store. *)
    configure = Some (fun ~output_dir ~variant_key ->
      Printf.sprintf
        "test -d %s || { echo 'lib_dir missing: %s'; exit 1; }"
        lib_dir lib_dir
      |> Canary_build_cmd.with_marker
           ~marker:"conf.ok" ~output_dir ~variant_key);

    (* Build_lib: GUARDED REAL BUILD (provision axis). If the lib is already
       present (Vendored — the factory pre-built it, or it was assembled),
       skip; else BUILD it from source with `cc` (mirrors the factory's
       build_c_lib). So the provision is expressed by what materialize placed:
       a tree with a pre-built libtiny.so ⇒ Vendored (skip); a source-only tree
       ⇒ Built (canary compiles + links it here, observably — a bad source
       makes this step fail). *)
    build_lib = Some (fun ~output_dir ~variant_key ->
      let obj = [%string "%{lib_dir}/tiny.o"] in
      let so_full = [%string "%{lib_dir}/libtiny.so.1.0"] in
      let version_script =
        if is_dev then [%string "%{source}/c/tiny.dev.map"]
        else [%string "%{source}/c/tiny.map"]
      in
      let defines = if is_dev then [ "TINY_DEV" ] else [] in
      let build =
        String.concat ~sep:" && "
          [ [%string "mkdir -p %{lib_dir}"];
            Canary_cc.cc_compile_obj ~defines
              ~include_dirs:[ [%string "%{source}/c/include"] ]
              ~src:[%string "%{source}/c/src/tiny.c"] ~out:obj ();
            Canary_cc.cc_link_shared ~soname:"libtiny.so.1"
              ~version_script ~inputs:[ obj ] ~out:so_full ();
            Canary_cc.symlink ~target:"libtiny.so.1.0"
              ~linkname:[%string "%{lib_dir}/libtiny.so.1"] ();
            Canary_cc.symlink ~target:"libtiny.so.1"
              ~linkname:[%string "%{lib_dir}/libtiny.so"] () ]
      in
      Printf.sprintf "test -f %s || { %s ; }" lib_path build
      |> Canary_build_cmd.with_marker
           ~marker:"build.ok" ~output_dir ~variant_key);

    (* Scan_sources: emit typed-signature JSONs derived directly from
       source files (Phase 15.5a). Runs after Configure (the default
       scan_sources_after), so it's available to any downstream step
       — critically including Build_binding_<lang>, which is where c6's
       type-mismatch mutations cause compile failure. *)
    scan_sources = Some (fun ~output_dir ~variant_key ->
      let mk base layer src =
        let out = Canary_basic.filename ~variant_key ~base ~ext:"json" in
        Printf.sprintf
          "python3 canary/scripts/inspect_tiny_typed.py --layer %s \
           --path %s/%s > %s/%s"
          layer source src output_dir out
      in
      let cmds = [
        mk "inspect_typed_header" "header"
          "c/include/tiny.h";
        mk "inspect_typed_binding_stub_ocaml" "stub_ocaml"
          "ocaml/tiny_raw.mli";
        mk "inspect_typed_binding_user_ocaml" "user_ocaml"
          "ocaml/tiny.mli";
        mk "inspect_typed_binding_stub_python" "stub_python"
          "python_cext/tiny_cext/_native.c";
        mk "inspect_typed_binding_user_python" "user_python"
          "python_cext/tiny_cext/__init__.py";
      ] in
      String.concat ~sep:" && " cmds
      |> Canary_build_cmd.with_marker
           ~marker:"scan.ok" ~output_dir ~variant_key);

    (* Build_binding OCaml: build the binding {b library} only —
       tiny.cmxa (bo6) and libtiny_stubs.a (bo7). dune --root pins the
       source tree as workspace; targets are relative to that root.
       Consumer compile (examples/probe_baseline.exe) is deferred to
       Probe so that mli mismatches surface there rather than here. *)
    build_binding = [
      (Canary_lang.OCaml,
       fun ~output_dir ~variant_key ->
         (* Capture dune's stderr into output_dir/build.log so c6's
            substring-match has something to grep against when the
            cstub compile fails (header arity mismatch etc.). The
            marker echo runs only on dune success. *)
         let build_log =
           Canary_basic.variant_file ~variant_key "build.log" in
         let dune_cmd =
           Canary_build_cmd.dune_build_cmd
             ~env_extra:[
               [%string "LIBRARY_PATH=%{abs_lib_dir}"];
               [%string "LD_RUN_PATH=%{abs_lib_dir}"];
             ]
             ~root:source
             ~target:"ocaml/tiny.cmxa ocaml/libtiny_stubs.a" () in
         Printf.sprintf
           "(%s) > %s/%s 2>&1"
           dune_cmd output_dir build_log
         |> Canary_build_cmd.with_marker
              ~marker:"build.ok" ~output_dir ~variant_key);
      (* Build_binding Python: verify the prebuilt cext exists in the
         python_cext_root store. *)
      (Canary_lang.Python,
       fun ~output_dir ~variant_key ->
         Printf.sprintf "ls %s > /dev/null" cext_so_glob
         |> Canary_build_cmd.with_marker
              ~marker:"build.ok" ~output_dir ~variant_key);
    ];

    (* Probe_lib: nm against the lib_dir store's actual libtiny. *)
    probe_lib = [
      (Canary_store.Build_tree,
       fun ~output_dir ~variant_key ->
         let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
         Printf.sprintf
           "nm -D %s | grep -E '^[0-9a-f]+ T tiny_' \
            > %s/%s 2>&1"
           lib_path output_dir probe_log);
    ];

    (* Probe_binding OCaml: dune build + exec probe_baseline.exe with
       source as the dune workspace root. mli mismatches surface here
       as consumer-compile failures; runtime symbol failures show up
       when exec runs against [abs_lib_dir]'s libtiny. *)
    probe_binding = [
      (Canary_lang.OCaml,
       Canary_store.Build_tree,
       fun ~output_dir ~variant_key ->
         let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
         Printf.sprintf
           "(LIBRARY_PATH=%s LD_RUN_PATH=%s dune build --root %s %s \
            && LD_LIBRARY_PATH=%s %s/_build/default/%s) > %s/%s 2>&1"
           abs_lib_dir abs_lib_dir source probe_exe
           abs_lib_dir source probe_exe output_dir probe_log);
      (* Probe_binding Python (cext): the probe script lives with the
         source tree (probes are source-coupled); the cext .so it
         imports lives in [python_cext_root]. *)
      (Canary_lang.Python,
       Canary_store.Build_tree,
       fun ~output_dir ~variant_key ->
         let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
         Printf.sprintf
           "LD_LIBRARY_PATH=%s PYTHONPATH=%s python3 \
            %s/python_cext/examples/probe_baseline.py > %s/%s 2>&1"
           abs_lib_dir python_cext_root source output_dir probe_log);
    ];

    (* binding_user_facing_pkg drives auto-generation of inspect steps
       after each Probe (Binding lang) — OCaml gets an [mli]
       inspect on the bo4 user_binding_ocaml.mli; Python gets a [dir(pkg)]
       inspect on bpe2 user_binding_cext.py. The pkg names match the
       package containing the user-facing surface. *)
    binding_user_facing_pkg = [
      (Canary_lang.OCaml, "tiny");
      (Canary_lang.Python, "tiny_cext");
    ];

    (* Inspect overrides — produce per-artifact JSON for each binding-side
       artifact. These are what the standard tiny harness comparators
       consume, restated in canary's vocabulary so [canary action tiny]
       writes the same JSONs as [make scenarios-cached] does:

       - Build_binding OCaml   → bo7 compiled_binding_ocaml.stub-a
         (libtiny_stubs.a). Feeds c1 cmp_symbol.
       - Build_binding Python  → bpe3 compiled_binding_cext.so
         (_native.cpython-*.so). Feeds c1 cmp_symbol (cext flavor).
       - Probe (Binding OCaml) → bo4 user_binding_ocaml.mli (tiny.mli)
         with module + val watchlist. Feeds c2 cmp_api_completeness.
       - Probe (Binding Python)→ bpe2 user_binding_cext.py (dir(tiny_cext))
         with attr watchlist. Feeds c2 cmp_api_completeness (Python). *)
    inspect = (fun action _loc ->
      let lib_inspect_cmd ~output_dir ~variant_key =
        (* Native nm-derived inspect of libtiny.so for c1 / c4 / c5.
           typed_header.json moved to scan_sources in Phase 15.5a so
           it's available even when later build steps fail. *)
        Canary_artifact_native.inspect_cmd
          ~lib:lib_path
          ~prefixes:[ "tiny_" ]
          ~watchlist:tiny_native_stable_symbols
          ~output_dir ~variant_key () in
      match action with
      | Build_lib ->
          (* Inspect the lib as soon as we've verified it exists in the
             workspace. Critical for c1 cmp_symbol ordering: the runner's
             topological sort can put probe_lib after probe_binding, but
             c1's expectation at probe_binding needs the lib JSON
             already-present. Attaching the inspect to build_lib makes
             the JSON available before any Probe step evaluates. *)
          Some lib_inspect_cmd
      | Build_binding Canary_lang.OCaml ->
          Some (fun ~output_dir ~variant_key ->
            (* Two-file inspect: stub (c1) + mli (c2). Typed signatures
               moved to scan_sources in Phase 15.5a — they live at
               scan_sources/inspect_typed_*.json so c6 can cite them
               even when Build (Binding OCaml) fails. *)
            let stub_file =
              Canary_basic.filename ~variant_key
                ~base:"inspect" ~ext:"json" in
            let mli_file =
              Canary_basic.filename ~variant_key
                ~base:"inspect_mli" ~ext:"json" in
            let watchlist_csv =
              String.concat ~sep:"," tiny_ocaml_module_watchlist in
            Printf.sprintf
              "python3 canary/scripts/inspect_binding.py --kind stub \
               --path %s/libtiny_stubs.a --prefix tiny_ > %s/%s && \
               python3 canary/scripts/inspect_binding.py --kind mli \
               --module-prefix Tiny \
               --path %s/ocaml/tiny.mli --watchlist '%s' > %s/%s"
              ocaml_build_dir output_dir stub_file
              source watchlist_csv output_dir mli_file)
      | Build_binding Canary_lang.Python ->
          Some (fun ~output_dir ~variant_key ->
            (* Two-file inspect on the Python side. Mirrors the OCaml
               binding's two-file inspect.
               - inspect.json (c_stub via [inspect_binding.py --kind
                 stub] on the cext .so) — undefined refs into libtiny,
                 the Python analog of libtiny_stubs.a. Feeds c1
                 cmp_symbol's C_stub input.
               - inspect_attrs.json (Python dir() attrs via
                 [inspect_python.py]) — user-facing surface for
                 c2 cmp_api_completeness's Python_attrs input.

               The cext .so doesn't {b export} tiny_* — those are
               undefined refs satisfied by libtiny at load time. So we
               use the stub inspector here, not the native one
               (which would always report zero defined tiny_* symbols
               and was misleading before Phase 14c-followup,
               2026-06-02). *)
            let stub_file =
              Canary_basic.filename ~variant_key
                ~base:"inspect" ~ext:"json" in
            let attrs_file =
              Canary_basic.filename ~variant_key
                ~base:"inspect_attrs" ~ext:"json" in
            let attrs_watchlist_csv =
              String.concat ~sep:"," tiny_python_module_watchlist in
            (* Two-file inspect at Build (Binding Python): c_stub (c1)
               + attrs (c2). Typed-signature inspects moved to
               scan_sources (Phase 15.5a). *)
            Printf.sprintf
              "python3 canary/scripts/inspect_binding.py --kind stub \
               --path %s --prefix tiny_ > %s/%s && \
               LD_LIBRARY_PATH=%s PYTHONPATH=%s \
               python3 canary/scripts/inspect_python.py --pkg tiny_cext \
               --watchlist '%s' > %s/%s"
              cext_so_glob output_dir stub_file
              abs_lib_dir python_cext_root
              attrs_watchlist_csv output_dir attrs_file)
      | Probe_binding Canary_lang.OCaml ->
          Some (fun ~output_dir ~variant_key ->
            let out_file =
              Canary_basic.filename ~variant_key
                ~base:"inspect" ~ext:"json" in
            let watchlist_csv =
              String.concat ~sep:"," tiny_ocaml_module_watchlist in
            Printf.sprintf
              "python3 canary/scripts/inspect_binding.py --kind mli \
               --module-prefix Tiny \
               --path %s/ocaml/tiny.mli --watchlist '%s' > %s/%s"
              source watchlist_csv output_dir out_file)
      | Probe_binding Canary_lang.Python ->
          Some (fun ~output_dir ~variant_key ->
            let out_file =
              Canary_basic.filename ~variant_key
                ~base:"inspect" ~ext:"json" in
            let watchlist_csv =
              String.concat ~sep:"," tiny_python_module_watchlist in
            Printf.sprintf
              "LD_LIBRARY_PATH=%s PYTHONPATH=%s \
               python3 canary/scripts/inspect_python.py --pkg tiny_cext \
               --watchlist '%s' > %s/%s"
              abs_lib_dir python_cext_root watchlist_csv output_dir out_file)
      | _ -> None);

    (* Diagram labels: bind the canary kinds to the canonical names tiny uses. *)
    artifact_name = (function
      | Headers -> Some "header_native.h (tiny.h)"
      | Lib -> Some "lib_native.so (libtiny.so.1)"
      | Binding Canary_lang.OCaml ->
          Some "compiled_binding_ocaml (tiny.cmxa + libtiny_stubs.a)"
      | Binding Canary_lang.Python ->
          Some "compiled_binding_cext (_native.cpython-*.so)"
      | App -> Some "probe_baseline.exe / .py"
      | _ -> None);

    expectation = (fun _action _loc -> Expect_success);
  }


(** Default workspace path for tiny's harness-materialized caches.
    Variants append a scenario name to this. *)
let cache_workspace_of ~scenario =
  [%string "%{tiny_root}/scenarios/_cache/%{scenario}/workspace"]

(** Convenience aliases at the live-tree path for callers that don't
    distinguish variants. The live tree {b is} a valid dune workspace
    (the tola workspace root supplies dune-project), so passing
    live-tree stores works for ad-hoc invocations even though the
    canonical flow points each variant at its own materialized cache. *)
let base_runner_spec =
  make_base_runner_spec
    ~stores:(stores_of_workspace ~workspace_root:tiny_root ()) ()
let runner_spec = base_runner_spec

(** {1 Scenario factory}

    Turns each {!entry} into a
    {!Canary_step_builder.runner_spec} canary can run as its
    own project. Uniform pipeline:

    {[
      entry
        |> stores_of_entry ~stores : may override stores.lib_filename
                                     from recipe.mutation
        |> { base with expectation = expectation_of_entry entry }
    ]}

    Merged from the retired [canary_tiny_scenario_project]
    module 2026-07-08. See [doc/canary/design/tiny.md] §3 for
    the derivation shape. *)

(** Tiny's per-scenario ORACLE expectation — a tiny-factory COMBINATOR over
    the one framework derivation (A7 refactor, 2026-08-05: the old sibling
    [Canary_scenario.lower_expectation] is retired; how a check derives
    from declared bindings at a firing site is framework machinery, and
    the oracle-ness is factory POLICY layered on top). Three policy moves:

    - RESTRICT: consult only the contracts this scenario's recipe VIOLATES
      (a plain filter on the bindings data — the recipe made the fault, so
      it knows which contract it broke);
    - GATE: a scenario whose fault has no probe manifestation expects
      success everywhere ([has_probe_manifestation]);
    - STRENGTHEN — at PROBE-class sites only: [Expect_compat_derived]
      (inspection decides) → [Expect_compat_failure] (failure REQUIRED).
      This is the answer-key property: a watchlist-blind inspector must go
      RED at the terminal detector (the probe), where the derived path
      would silently expect success. BUILD-class sites stay Derived — the
      evidence decides: a declaration-level c6 lie (header_arity_bump)
      derives a non-empty prediction and still must-fail at build, while a
      body-only c6 lie (type_wrong: header/stub agree, the .c body lies)
      legitimately BUILDS GREEN (its own expected table says
      `"ocaml_build", Ok`; the manifestation is Sc.4 — the probe). The
      pre-A7 blanket build-site strengthening made type_wrong demand a
      build failure that the mutation never produces (the oracle's one
      standing red, triaged 2026-08-05). Grep-sourced firings are already
      must-fail ([Expect_failure]) and pass through unchanged. *)
let expectation_of_entry (entry : scenario_spec)
  : Canary_basic.action -> Canary_store.location option ->
    Canary_step_model.step_expectation
  =
  let module CS = Canary_scenario in
  let module SM = Canary_step_model in
  if not (CS.has_probe_manifestation entry.scenario) then
    fun _ _ -> SM.Expect_success
  else
    let bindings =
      Base.List.filter tiny_contract_bindings ~f:(fun (b : CS.contract_binding) ->
          Base.List.mem entry.recipe.violates b.CS.contract
            ~equal:Base.Poly.equal)
    in
    let derive =
      CS.lower_expectation_agnostic ~bindings
        ~langs:(CS.langs_of_scenario entry.scenario)
    in
    fun action loc ->
      match derive action loc with
      | SM.Expect_compat_derived { inputs; version_info } as e -> (
          match action with
          | Canary_basic.Probe_binding _ | Canary_basic.Probe_app _ ->
              SM.Expect_compat_failure { inputs; version_info }
          | _ -> e)
      | e -> e

(** The mutation-AGNOSTIC expectation for tiny-full: derived from the
    spec-level contract bindings + inspection alone — no per-scenario
    [violates]/[has_manifest]. Canary inspects each step's artifacts and
    decides whether to expect a failure (P2b). This is what "tiny-full
    declares resources; canary computes the expectation" means concretely. *)
let tiny_expectation_agnostic
  : Canary_basic.action -> Canary_store.location option ->
    Canary_step_model.step_expectation
  =
  Canary_scenario.lower_expectation_agnostic
    ~bindings:tiny_contract_bindings
    ~langs:Canary_lang.[ OCaml; Python ]

(** Derive tiny_stores adjustments from the recipe's concrete
    mutation. Today only Soname_bump needs it. *)
let stores_of_entry
    ~(stores : tiny_stores)
    (entry : scenario_spec)
  : tiny_stores
  =
  let open Base in
  let is_all_digits s =
    (not (String.is_empty s))
    && String.for_all s ~f:Char.is_digit
  in
  let strip_trailing_minor s =
    match List.rev (String.split ~on:'.' s) with
    | last :: (second :: _ as rest_rev)
      when is_all_digits last && is_all_digits second ->
      String.concat ~sep:"." (List.rev rest_rev)
    | _ -> s
  in
  match entry.recipe.mutation with
  | Some (Of_native (Soname_bump { to_so; _ })) ->
    { stores with lib_filename = strip_trailing_minor to_so }
  | _ -> stores

(** Build the runner_spec for a scenario. Uniform code path:
    base spec with expectation derived from the entry. *)
let runner_spec_of_entry
    ~(mutated_stores : tiny_stores)
    (entry : scenario_spec)
  : Canary_step_builder.runner_spec
  =
  let stores = stores_of_entry ~stores:mutated_stores entry in
  { (make_base_runner_spec ~stores ()) with
    expectation = expectation_of_entry entry;
  }

(** Convenience: look up entry by scenario name and build
    the spec. *)
let runner_spec_of_name
    ~(mutated_stores : tiny_stores)
    (name : string)
  : Canary_step_builder.runner_spec
  =
  let name = name_of_string name in
  match find_by_name name with
  | Some entry -> runner_spec_of_entry ~mutated_stores entry
  | None ->
    Stdlib.failwith
      (Printf.sprintf
         "Canary_project_tiny: no entry with name %S" name)

(* (A6, 2026-08-05: the [tiny_project : Canary_project.project] bundle that
   lived here was deleted with the never-read [Canary_project] type — tiny1's
   runner walks [all_scenario_specs] directly and always did; tiny-full's
   identity is [Canary_project_tiny.tiny_full_run].) *)
