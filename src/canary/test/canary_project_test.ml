open Base

(* Project-definition layer tests (project_definition.md §8).

   The third testing axis: fast, hermetic, pure tests of the
   project *definition* layers — no PM installs, no builds. Step 1
   covers the action → artifact consumes/produces relation that the
   forecast-agnostic detection derives its inputs from. Later steps
   append store-derivation, detection-over-fixtures, fail-mode
   policy, and the tiny oracle check.

   Pure predicate tests only (no shell); mirrors the pure_test half
   of canary_artifact_test.ml. *)

module A = Canary_action
module B = Canary_basic
module L = Canary_lang

type pure_test = { name : string; check : unit -> bool }

let run_pure_test (t : pure_test) = try t.check () with _ -> false

(* ── helpers ── *)

let kinds_to_s (ks : B.artifact_kind list) : string =
  String.concat ~sep:";" (List.map ks ~f:B.string_of_artifact_kind)

let same_kinds (a : B.artifact_kind list) (b : B.artifact_kind list) : bool =
  List.equal Poly.equal a b

(* One row: an action with its expected consumes + produces sets. *)
let ocaml = L.OCaml

let catalogue : (B.action * B.artifact_kind list * B.artifact_kind list) list =
  B.[
    (Configure,                       [ Source ],            []);
    (Scan_sources,                    [ Source ],            []);
    (Build_headers,                   [ Source ],            [ Headers ]);
    (Build_lib,                       [ Source ],            [ Lib ]);
    (Install_lib,                     [ Lib ],               [ Lib ]);
    (Build_binding ocaml,             [ Lib ],               [ Binding ocaml ]);
    (Build_app { lang = ocaml },      [ Binding ocaml; Lib ],[ App ]);
    (Probe_lib,                       [ Lib ],               []);
    (Probe_binding ocaml,             [ Binding ocaml; Lib ],[]);
    (Probe_app { lang = ocaml },      [ Binding ocaml; Lib; App ], []);
    (Fetch Source,                    [],                    [ Source ]);
    (Fetch Lib,                       [],                    [ Lib ]);
    (Publish Lib,                     [ Lib ],               [ Lib ]);
  ]

(* ── the tests ── *)

let catalogue_tests : pure_test list =
  List.map catalogue ~f:(fun (a, exp_c, exp_p) ->
    { name =
        Printf.sprintf "consumes_produces.%s" (B.string_of_action a);
      check = (fun () ->
        same_kinds (A.consumes_of_action a) exp_c
        && same_kinds (A.produces_of_action a) exp_p) })

(* Invariant detection relies on: probes produce nothing, so for
   every Probe_* action consumes_of_action = artifacts_of_action
   (the legacy flat view). Locks the equivalence that lets detection
   reuse the existing artifact derivation at probe sites. *)
let probe_invariant : pure_test =
  { name = "probe_invariant.consumes_eq_artifacts";
    check = (fun () ->
      let probes =
        B.[ Probe_lib; Probe_binding ocaml; Probe_app { lang = ocaml };
            Probe_binding L.Python ]
      in
      List.for_all probes ~f:(fun a ->
        same_kinds (A.consumes_of_action a) (A.artifacts_of_action a)
        && List.is_empty (A.produces_of_action a))) }

(* The detection-scope inventory for a sqlite-like positive-only
   project: fetch source, build+fetch lib, build+probe the OCaml
   binding, probe the lib. The consumes-inventory is the deduped set
   of artifacts detection would inspect. *)
let inventory_test : pure_test =
  { name = "inventory.sqlite_like";
    check = (fun () ->
      let actions =
        B.[ Fetch Source; Build_lib; Fetch Lib;
            Build_binding ocaml; Probe_binding ocaml; Probe_lib ]
      in
      (* Fetch consumes nothing; Build_lib→Source; Fetch Lib→(none);
         Build_binding→Lib; Probe_binding→Binding+Lib; Probe_lib→Lib.
         First-appearance union: Source, Lib, Binding OCaml. *)
      same_kinds
        (A.consumed_artifacts_of_actions actions)
        B.[ Source; Lib; Binding ocaml ]) }

let all_tests : pure_test list =
  catalogue_tests @ [ probe_invariant; inventory_test ]

let run_tests () : bool =
  let results = List.map all_tests ~f:(fun t -> (t, run_pure_test t)) in
  List.iter results ~f:(fun (t, ok) ->
    Fmt.pr "[%s] %s@." (if ok then "PASS" else "FAIL") t.name;
    if not ok then
      (* Re-run to surface the mismatch on the catalogue rows. *)
      List.iter catalogue ~f:(fun (a, exp_c, exp_p) ->
        if String.equal (Printf.sprintf "consumes_produces.%s"
                           (B.string_of_action a)) t.name then
          Fmt.pr "    consumes: got [%s] want [%s]; produces: got [%s] want [%s]@."
            (kinds_to_s (A.consumes_of_action a)) (kinds_to_s exp_c)
            (kinds_to_s (A.produces_of_action a)) (kinds_to_s exp_p)));
  let passed = List.count results ~f:snd in
  let total = List.length results in
  Fmt.pr "@.Project-definition layer tests: %d/%d passed.@." passed total;
  passed = total
