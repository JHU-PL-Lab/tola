open Base

(* Artifact primitive testing: generate and run tests for the
   canary_artifact_* modules, mirroring canary_pm_test.ml.

   Two test kinds:
   - shell_test: run a shell command, check exit code (reuses canary_pm_test)
   - pure_test:  evaluate an OCaml predicate in-process

   Fixtures are auto-detected: sqlite3 .so on Linux, libSystem.dylib on
   macOS, opam pkg "fmt", python "sys". Tests for unavailable fixtures
   are skipped. *)

type pure_test = { name : string; check : unit -> bool }

let run_pure_test (t : pure_test) =
  let ok = try t.check () with _ -> false in
  ok

(* ── Fixture discovery ── *)

let first_existing paths =
  List.find paths ~f:Stdlib.Sys.file_exists

let native_lib_fixture () =
  if Canary_artifact_native.is_macos then
    (* macOS 15+: /usr/lib/*.dylib live only in the dyld shared cache, so
       file-existence checks fail. Use a Homebrew-shipped on-disk dylib
       (sqlite mirrors the Linux fixture; falls back to libffi/openssl). *)
    first_existing [
      "/opt/homebrew/opt/sqlite/lib/libsqlite3.dylib";
      "/opt/homebrew/opt/libffi/lib/libffi.dylib";
      "/opt/homebrew/opt/openssl@3/lib/libssl.dylib";
      "/usr/local/opt/sqlite/lib/libsqlite3.dylib";  (* Intel Macs *)
    ]
  else
    first_existing [
      "/usr/lib/x86_64-linux-gnu/libsqlite3.so.0";
      "/usr/lib/x86_64-linux-gnu/libc.so.6";
      "/lib/x86_64-linux-gnu/libc.so.6";
    ]

(* ── Pure predicate tests ── *)

let native_pure_tests = [
  { name = "native.is_native_lib(.so)"; check = fun () -> Canary_artifact_native.is_native_lib "foo.so" };
  { name = "native.is_native_lib(.dylib)"; check = fun () -> Canary_artifact_native.is_native_lib "foo.dylib" };
  { name = "native.is_native_lib(.a)"; check = fun () -> Canary_artifact_native.is_native_lib "foo.a" };
  { name = "native.is_native_lib(.so.1.2)"; check = fun () -> Canary_artifact_native.is_native_lib "libfoo.so.1.2" };
  { name = "native.!is_native_lib(.cmxa)"; check = fun () -> not (Canary_artifact_native.is_native_lib "foo.cmxa") };
]

let ocaml_pure_tests = [
  { name = "ocaml.is_ocaml_archive(.cmxa)"; check = fun () -> Canary_artifact_lang.is_ocaml_archive "foo.cmxa" };
  { name = "ocaml.is_ocaml_archive(.cma)"; check = fun () -> Canary_artifact_lang.is_ocaml_archive "foo.cma" };
  { name = "ocaml.!is_ocaml_archive(.so)"; check = fun () -> not (Canary_artifact_lang.is_ocaml_archive "foo.so") };
  { name = "ocaml.cmxa_stub_archive"; check = fun () ->
      String.equal (Canary_artifact_lang.cmxa_stub_archive "/x/z3ml.cmxa") "/x/libz3ml.a" };
]

(* Compat-helper tests: feed a synthetic summary.json into
   predicted_contains_any_v2 and assert the right substrings come out.
   Exercises both Ocaml_mli (dotted-name expansion) and Python_attrs
   (flat names) input variants without needing a real probe run. *)
let compat_pure_tests =
  let tmp_root = "_out/canary/test/compat-helper" in
  let _ = Stdlib.Sys.command [%string "mkdir -p %{tmp_root}"] in
  let write_inspect kind name watchlist_missing =
    let path = tmp_root ^ "/" ^ name in
    let missing_json =
      "[" ^ (List.map watchlist_missing ~f:(fun s -> "\"" ^ s ^ "\"")
             |> String.concat ~sep:",") ^ "]"
    in
    let body =
      [%string {|{"kind": "%{kind}", "path": "fixture",
  "watchlist": {"present": [], "missing": %{missing_json}}}|}]
    in
    let oc = Stdlib.open_out path in
    Stdlib.output_string oc body;
    Stdlib.close_out oc;
    path
  in
  let mli_path = write_inspect "ocaml_mli" "mli.json" [ "Llvm.Opcode.UncondBr" ] in
  let py_path  = write_inspect "python"   "py.json"  [ "Solver.add"; "BitVec" ] in
  let l3_only = Canary_compat_run.predicted_contains_any_v2 ~resolve:Fn.id
      [ Canary_compat.Ocaml_mli [ mli_path ] ] in
  let py_only = Canary_compat_run.predicted_contains_any_v2 ~resolve:Fn.id
      [ Canary_compat.Python_attrs [ py_path ] ] in
  let mixed = Canary_compat_run.predicted_contains_any_v2 ~resolve:Fn.id
      [ Canary_compat.Ocaml_mli [ mli_path ]; Canary_compat.Python_attrs [ py_path ] ] in
  let mem xs s = List.mem xs s ~equal:String.equal in
  [
    { name = "compat.mli_dotted_expansion";
      check = fun () ->
        mem l3_only "Llvm.Opcode.UncondBr"
        && mem l3_only "Opcode.UncondBr"
        && mem l3_only "UncondBr" };
    { name = "compat.python_attr_expansion";
      check = fun () ->
        mem py_only "Solver.add" && mem py_only "add"
        && mem py_only "BitVec" };
    { name = "compat.mixed_inputs_union";
      check = fun () ->
        mem mixed "UncondBr" && mem mixed "BitVec" };
    { name = "compat.empty_inputs";
      check = fun () ->
        List.is_empty (Canary_compat_run.predicted_contains_any_v2 ~resolve:Fn.id []) };
    (* A7 phase 1 — the per-contract form. Both fixture inputs are L3
       completeness, so exactly ONE registry row fires (c2) and it carries
       the union of both inputs' expansions. *)
    { name = "compat.by_contract_attribution";
      check = fun () ->
        match
          Canary_compat_run.predicted_by_contract_v2 ~resolve:Fn.id
            [ Canary_compat.Ocaml_mli [ mli_path ];
              Canary_compat.Python_attrs [ py_path ] ]
        with
        | [ (c, subs) ] ->
            Poly.equal c.Canary_compat.id Canary_compat.C2
            && mem subs "UncondBr" && mem subs "BitVec"
        | _ -> false };
    (* the flat form is exactly the flatten of the per-contract form *)
    { name = "compat.by_contract_flatten_equals_v2";
      check = fun () ->
        let flat =
          Canary_compat_run.predicted_by_contract_v2 ~resolve:Fn.id
            [ Canary_compat.Ocaml_mli [ mli_path ];
              Canary_compat.Python_attrs [ py_path ] ]
          |> List.concat_map ~f:snd
          |> List.dedup_and_sort ~compare:String.compare
        in
        List.equal String.equal flat mixed };
    (* per-call disable drops the row AND shows up as a skip with the
       per-call reason (registry-disabled rows carry their status) *)
    { name = "compat.by_contract_disabled_skips";
      check = fun () ->
        List.is_empty
          (Canary_compat_run.predicted_by_contract_v2
             ~disabled:[ Canary_compat.C2 ] ~resolve:Fn.id
             [ Canary_compat.Ocaml_mli [ mli_path ] ])
        && List.exists
             (Canary_compat_run.skipped_checks ~disabled:[ Canary_compat.C2 ] ())
             ~f:(fun (c, reason) ->
               Poly.equal c.Canary_compat.id Canary_compat.C2
               && String.equal reason "disabled per call")
        && List.exists (Canary_compat_run.skipped_checks ())
             ~f:(fun (c, reason) ->
               Poly.equal c.Canary_compat.id Canary_compat.C3
               && String.is_substring reason ~substring:"registry") };
  ]

(* Step 3b — Unit-test layer for primitives.
   Synthetic provider+consumer fixtures exercise each comparator without
   needing a real artifact or build. Reciprocal coverage (positive +
   negative) per comparator: every accept case is paired with a reject
   case so the test catches "always says compatible" / "always says
   incompatible" regressions.

   Today's coverage: c1 cmp_symbol (4 cases) + c2 prediction shape
   (2 cases). c4 cmp_abi / c5 cmp_sym_version / c6 cmp_type / c7 cmp_repack
   / c8 cmp_api_faithfulness will add fixtures here as they land — see
   plan.md §6 Step 4 (a). *)
let cmp_symbol_pure_tests =
  let stub_of requires : Canary_compat.stub_inspect =
    { path = "fixture-stub"; requires } in
  let native_of symbols : Canary_compat.native_inspect =
    { path = "fixture-native"; symbols } in
  [
    { name = "cmp_symbol.compatible";
      check = fun () ->
        let r = Canary_compat.check_c_compat
            ~binding_stub:(stub_of [ "tiny_sum"; "tiny_diff" ])
            ~native_lib:(native_of [ "tiny_sum"; "tiny_diff"; "tiny_offset" ]) in
        match r with Compatible -> true | _ -> false };
    { name = "cmp_symbol.missing_one";
      check = fun () ->
        let r = Canary_compat.check_c_compat
            ~binding_stub:(stub_of [ "tiny_sum"; "tiny_diff" ])
            ~native_lib:(native_of [ "tiny_total"; "tiny_diff"; "tiny_offset" ]) in
        match r with
        | Missing { symbols } ->
            List.equal String.equal symbols [ "tiny_sum" ]
        | _ -> false };
    { name = "cmp_symbol.missing_multiple";
      check = fun () ->
        let r = Canary_compat.check_c_compat
            ~binding_stub:(stub_of [ "tiny_sum"; "tiny_diff"; "tiny_extra" ])
            ~native_lib:(native_of [ "tiny_offset" ]) in
        match r with
        | Missing { symbols } ->
            (* Order in 'missing' matches input order *)
            List.length symbols = 3
            && List.mem symbols "tiny_sum" ~equal:String.equal
            && List.mem symbols "tiny_diff" ~equal:String.equal
            && List.mem symbols "tiny_extra" ~equal:String.equal
        | _ -> false };
    { name = "cmp_symbol.unknown_empty_requires";
      check = fun () ->
        let r = Canary_compat.check_c_compat
            ~binding_stub:(stub_of [])
            ~native_lib:(native_of [ "tiny_sum" ]) in
        match r with Unknown -> true | _ -> false };
    { name = "cmp_symbol.unknown_empty_symbols";
      check = fun () ->
        let r = Canary_compat.check_c_compat
            ~binding_stub:(stub_of [ "tiny_sum" ])
            ~native_lib:(native_of []) in
        match r with Unknown -> true | _ -> false };
  ]

(* c4 cmp_abi — provider.SONAME ∈ consumer.NEEDED?
   Catches tiny scenario e2 abi_soname_bump (and the same shape on
   z3/llvm: libz3.so.4 vs libz3.so.5 etc.). *)
let cmp_abi_pure_tests =
  [
    { name = "cmp_abi.compatible_soname_in_needed";
      check = fun () ->
        let r = Canary_compat.check_abi
            ~provider_soname:(Some "libtiny.so.1")
            ~consumer_needed:[ "libc.so.6"; "libtiny.so.1" ] in
        match r with Abi_compatible -> true | _ -> false };
    { name = "cmp_abi.mismatch_soname_bumped";
      check = fun () ->
        (* e2-shape: provider bumped to libtiny.so.2 but consumer still
           references libtiny.so.1. The Abi_mismatch carries the
           expected (provider) SONAME for diagnostics. *)
        let r = Canary_compat.check_abi
            ~provider_soname:(Some "libtiny.so.2")
            ~consumer_needed:[ "libc.so.6"; "libtiny.so.1" ] in
        match r with
        | Abi_mismatch { expected_soname; consumer_needed } ->
            String.equal expected_soname "libtiny.so.2"
            && List.equal String.equal consumer_needed
                 [ "libc.so.6"; "libtiny.so.1" ]
        | _ -> false };
    { name = "cmp_abi.mismatch_when_only_system_libs";
      check = fun () ->
        (* Consumer only needs libc — doesn't reference our provider at
           all. Treated as a mismatch since the provider's SONAME isn't
           in the list. (Could be relaxed to Compatible if "consumer
           doesn't need our lib at all" is fine; today's check is
           strict.) *)
        let r = Canary_compat.check_abi
            ~provider_soname:(Some "libtiny.so.1")
            ~consumer_needed:[ "libc.so.6" ] in
        match r with
        | Abi_mismatch { expected_soname; _ } ->
            String.equal expected_soname "libtiny.so.1"
        | _ -> false };
    { name = "cmp_abi.unknown_no_provider_soname";
      check = fun () ->
        let r = Canary_compat.check_abi
            ~provider_soname:None
            ~consumer_needed:[ "libtiny.so.1" ] in
        match r with Abi_unknown -> true | _ -> false };
    { name = "cmp_abi.unknown_empty_needed";
      check = fun () ->
        let r = Canary_compat.check_abi
            ~provider_soname:(Some "libtiny.so.1")
            ~consumer_needed:[] in
        match r with Abi_unknown -> true | _ -> false };
  ]

(* c6 cmp_type — header function arity ↔ binding external arity.
   Today's check is arity-only after applying a declared name
   mapping (binding externals → header function names). Full
   type-equivalence comparison would also map C types ↔ OCaml types;
   left for a later refinement. *)
let cmp_type_pure_tests =
  let open Canary_compat in
  [
    { name = "cmp_type.compatible_arity_match";
      check = fun () ->
        (* tiny baseline shape: tiny.h declares int tiny_sum(int, int)
           etc.; bo1 declares external sum : int -> int -> int. Both
           arities = 2. *)
        let r = check_type
            ~header_functions:[ ("tiny_sum", 2); ("tiny_diff", 2) ]
            ~binding_externals:[ ("sum", 2); ("diff", 2) ]
            ~name_mapping:[ ("sum", "tiny_sum"); ("diff", "tiny_diff") ] in
        match r with Type_compatible -> true | _ -> false };
    { name = "cmp_type.arity_mismatch_header_added_arg";
      check = fun () ->
        (* Synthetic e15-shape: header bumped tiny_sum to 3 args; binding
           still expects 2. *)
        let r = check_type
            ~header_functions:[ ("tiny_sum", 3); ("tiny_diff", 2) ]
            ~binding_externals:[ ("sum", 2); ("diff", 2) ]
            ~name_mapping:[ ("sum", "tiny_sum"); ("diff", "tiny_diff") ] in
        match r with
        | Type_arity_mismatch { mismatches } ->
            List.equal Poly.equal mismatches [ ("sum", 2, 3) ]
        | _ -> false };
    { name = "cmp_type.arity_mismatch_header_dropped_arg";
      check = fun () ->
        let r = check_type
            ~header_functions:[ ("tiny_sum", 1) ]
            ~binding_externals:[ ("sum", 2) ]
            ~name_mapping:[ ("sum", "tiny_sum") ] in
        match r with
        | Type_arity_mismatch { mismatches } ->
            List.equal Poly.equal mismatches [ ("sum", 2, 1) ]
        | _ -> false };
    { name = "cmp_type.compatible_with_extra_unmapped";
      check = fun () ->
        (* tiny's get_offset is an extern var, not a function; it's
           intentionally excluded from name_mapping. Other mapped
           externals match → Type_compatible (unmapped externals are
           informational only). *)
        let r = check_type
            ~header_functions:[ ("tiny_sum", 2); ("tiny_diff", 2) ]
            ~binding_externals:[ ("sum", 2); ("diff", 2); ("get_offset", 1) ]
            ~name_mapping:[ ("sum", "tiny_sum"); ("diff", "tiny_diff") ] in
        match r with Type_compatible -> true | _ -> false };
    { name = "cmp_type.unmapped_all";
      check = fun () ->
        (* No name_mapping at all → can't compare anything → Type_unmapped. *)
        let r = check_type
            ~header_functions:[ ("tiny_sum", 2) ]
            ~binding_externals:[ ("sum", 2) ]
            ~name_mapping:[] in
        match r with
        | Type_unmapped { externals } ->
            List.equal String.equal externals [ "sum" ]
        | _ -> false };
    { name = "cmp_type.mapped_to_nonexistent_header_fn";
      check = fun () ->
        (* Binding has external mapping to a header function name
           that doesn't appear in header_functions. Treated as a
           -1 vs binding_arity mismatch. *)
        let r = check_type
            ~header_functions:[ ("tiny_other", 1) ]
            ~binding_externals:[ ("sum", 2) ]
            ~name_mapping:[ ("sum", "tiny_sum") ] in
        match r with
        | Type_arity_mismatch { mismatches } ->
            List.equal Poly.equal mismatches [ ("sum", 2, -1) ]
        | _ -> false };
    { name = "cmp_type.unknown_empty";
      check = fun () ->
        let r = check_type
            ~header_functions:[] ~binding_externals:[] ~name_mapping:[] in
        match r with Type_unknown -> true | _ -> false };
  ]

(* c7 cmp_api_repack — stub externals ↔ user vals (intra-binding,
   modulo declared renames).
   Catches the new tiny scenario e14 api_repack_stub_orphan. *)
let cmp_api_repack_pure_tests =
  let open Canary_compat in
  [
    { name = "cmp_api_repack.compatible_exact_match";
      check = fun () ->
        let r = check_api_repack
            ~stub_externals:[ "sum"; "diff"; "offset" ]
            ~user_vals:[ "sum"; "diff"; "offset" ]
            ~renames:[] in
        match r with Repack_compatible -> true | _ -> false };
    { name = "cmp_api_repack.compatible_with_rename";
      check = fun () ->
        (* tiny baseline: bo1 has get_offset, bo4 has offset. Rename
           pair declared → Compatible. *)
        let r = check_api_repack
            ~stub_externals:[ "sum"; "diff"; "get_offset" ]
            ~user_vals:[ "sum"; "diff"; "offset" ]
            ~renames:[ ("get_offset", "offset") ] in
        match r with Repack_compatible -> true | _ -> false };
    { name = "cmp_api_repack.stub_orphan_unrenamed";
      check = fun () ->
        (* e14 shape: stub has an extra external not in vals and not
           declared as a rename source. *)
        let r = check_api_repack
            ~stub_externals:[ "sum"; "diff"; "offset"; "alias_sum" ]
            ~user_vals:[ "sum"; "diff"; "offset" ]
            ~renames:[] in
        match r with
        | Repack_stub_orphan { externals_not_exposed } ->
            List.equal String.equal externals_not_exposed [ "alias_sum" ]
        | _ -> false };
    { name = "cmp_api_repack.stub_orphan_with_rename_ignored";
      check = fun () ->
        (* Rename map filters out get_offset/offset but alias_sum is
           still an orphan. *)
        let r = check_api_repack
            ~stub_externals:[ "sum"; "diff"; "get_offset"; "alias_sum" ]
            ~user_vals:[ "sum"; "diff"; "offset" ]
            ~renames:[ ("get_offset", "offset") ] in
        match r with
        | Repack_stub_orphan { externals_not_exposed } ->
            List.equal String.equal externals_not_exposed [ "alias_sum" ]
        | _ -> false };
    { name = "cmp_api_repack.user_phantom_unbacked";
      check = fun () ->
        (* Synthetic: a val without a backing external. Unreachable in
           well-typed OCaml; still a meaningful Python/non-OCaml case. *)
        let r = check_api_repack
            ~stub_externals:[ "sum"; "diff" ]
            ~user_vals:[ "sum"; "diff"; "phantom_thing" ]
            ~renames:[] in
        match r with
        | Repack_user_phantom { vals_without_external } ->
            List.equal String.equal vals_without_external [ "phantom_thing" ]
        | _ -> false };
    { name = "cmp_api_repack.unknown_both_empty";
      check = fun () ->
        let r = check_api_repack
            ~stub_externals:[] ~user_vals:[] ~renames:[] in
        match r with Repack_unknown -> true | _ -> false };
  ]

(* c8 cmp_api_faithfulness — pure composition of c1, c6, c7.
   Catches tiny scenario e4 api_faithful when the action pipeline
   wires c8 (today e4 is silent at the c1/c2/c3 level). *)
let cmp_api_faithfulness_pure_tests =
  let open Canary_compat in
  let stub_of requires : Canary_compat.stub_inspect =
    { path = "fixture-stub"; requires } in
  let native_of symbols : Canary_compat.native_inspect =
    { path = "fixture-native"; symbols } in
  [
    { name = "cmp_faithful.all_compatible";
      check = fun () ->
        let r = check_api_faithfulness
            ~type_verdict:Type_compatible
            ~symbol_verdict:(check_c_compat
                ~binding_stub:(stub_of [ "tiny_sum" ])
                ~native_lib:(native_of [ "tiny_sum"; "tiny_diff" ]))
            ~repack_verdict:Repack_compatible in
        match r with Faithful -> true | _ -> false };
    { name = "cmp_faithful.type_drift_unfaithful";
      check = fun () ->
        let type_v = Type_arity_mismatch
            { mismatches = [ ("sum", 2, 3) ] } in
        let r = check_api_faithfulness
            ~type_verdict:type_v
            ~symbol_verdict:Compatible
            ~repack_verdict:Repack_compatible in
        match r with
        | Unfaithful { type_issue = Some _; symbol_issue = None;
                       repack_issue = None } -> true
        | _ -> false };
    { name = "cmp_faithful.symbol_drift_unfaithful";
      check = fun () ->
        let sym = Missing { symbols = [ "tiny_sum" ] } in
        let r = check_api_faithfulness
            ~type_verdict:Type_compatible
            ~symbol_verdict:sym
            ~repack_verdict:Repack_compatible in
        match r with
        | Unfaithful { type_issue = None; symbol_issue = Some _;
                       repack_issue = None } -> true
        | _ -> false };
    { name = "cmp_faithful.repack_orphan_unfaithful";
      check = fun () ->
        (* e14 shape after c8 wires: repack issue surfaces under
           api-faithfulness as a stub_orphan attribution. *)
        let rep = Repack_stub_orphan
            { externals_not_exposed = [ "alias_sum" ] } in
        let r = check_api_faithfulness
            ~type_verdict:Type_compatible
            ~symbol_verdict:Compatible
            ~repack_verdict:rep in
        match r with
        | Unfaithful { type_issue = None; symbol_issue = None;
                       repack_issue = Some _ } -> true
        | _ -> false };
    { name = "cmp_faithful.multiple_issues";
      check = fun () ->
        let r = check_api_faithfulness
            ~type_verdict:(Type_arity_mismatch
                { mismatches = [ ("a", 1, 2) ] })
            ~symbol_verdict:(Missing { symbols = [ "x" ] })
            ~repack_verdict:Repack_compatible in
        match r with
        | Unfaithful { type_issue = Some _; symbol_issue = Some _;
                       repack_issue = None } -> true
        | _ -> false };
    { name = "cmp_faithful.unknown_when_all_unknown";
      check = fun () ->
        let r = check_api_faithfulness
            ~type_verdict:Type_unknown
            ~symbol_verdict:Unknown
            ~repack_verdict:Repack_unknown in
        match r with Faithfulness_unknown -> true | _ -> false };
    { name = "cmp_faithful.partial_unknown_still_faithful";
      check = fun () ->
        (* Two constituents Unknown, one Compatible — overall Faithful
           because no constituent reported a definite Unfaithful. *)
        let r = check_api_faithfulness
            ~type_verdict:Type_compatible
            ~symbol_verdict:Unknown
            ~repack_verdict:Repack_unknown in
        match r with Faithful -> true | _ -> false };
  ]

(* n3 inspector: inspect_header.py parses C function declarations and
   `extern` variable declarations from a .h file. Today's parser is
   regex-based, scoped to tiny.h-shape headers (flat, no preprocessor
   tricks). Real-world headers will need a libclang or tree-sitter
   upgrade — see plan.md §6 Step 4 (a). *)
let n3_header_inspect_pure_tests =
  let tmp_root = "_out/canary/test/n3-header" in
  let _ = Stdlib.Sys.command [%string "mkdir -p %{tmp_root}"] in
  let write_h name body =
    let path = tmp_root ^ "/" ^ name ^ ".h" in
    let oc = Stdlib.open_out path in
    Stdlib.output_string oc body;
    Stdlib.close_out oc;
    path in
  let inspect h_path =
    let out_file = h_path ^ ".inspect.json" in
    let cmd = [%string
      "python3 canary/scripts/inspect_header.py --path %{h_path} > %{out_file}"] in
    let rc = Stdlib.Sys.command cmd in
    if rc <> 0 then failwith [%string "inspect_header failed (rc=%{rc#Int})"];
    Yojson.Basic.from_file out_file in
  let funcs_of j =
    Yojson.Basic.Util.(j |> member "functions" |> to_list) in
  let vars_of j =
    Yojson.Basic.Util.(j |> member "extern_vars" |> to_list) in
  let fn_name j = Yojson.Basic.Util.(j |> member "name" |> to_string) in
  let fn_arity j =
    Yojson.Basic.Util.(j |> member "arg_types" |> to_list |> List.length) in

  let tinyh = write_h "tiny_like"
    {|#ifndef TINY_H
#define TINY_H

/* Read-mostly global. Initial value 42. */
extern int tiny_offset;

/* Returns a + b + tiny_offset. */
int tiny_sum(int a, int b);

/* Returns a - b. */
int tiny_diff(int a, int b);

#endif
|} in
  let bumped_h = write_h "bumped"
    {|int tiny_sum(int a, int b, int c);
int tiny_diff(int a, int b);
|} in
  let void_h = write_h "void_args"
    {|void tiny_init(void);
int tiny_count(void);
|} in
  let tiny_j = inspect tinyh in
  let bumped_j = inspect bumped_h in
  let void_j = inspect void_h in
  [
    { name = "n3.tiny_like_two_fns_one_var";
      check = fun () ->
        let fns = funcs_of tiny_j in
        let vars = vars_of tiny_j in
        List.length fns = 2
        && List.length vars = 1
        && List.equal String.equal (List.map fns ~f:fn_name)
             [ "tiny_sum"; "tiny_diff" ]
        && (Yojson.Basic.Util.(List.hd_exn vars |> member "name" |> to_string)
            |> String.equal "tiny_offset") };
    { name = "n3.arity_extracted";
      check = fun () ->
        let arities =
          funcs_of tiny_j |> List.map ~f:fn_arity in
        List.equal Int.equal arities [ 2; 2 ] };
    { name = "n3.bumped_header_3_args";
      check = fun () ->
        let arities = funcs_of bumped_j |> List.map ~f:fn_arity in
        (* Mirrors the c6 e15-shape test: header bumped tiny_sum to 3 args. *)
        List.equal Int.equal arities [ 3; 2 ] };
    { name = "n3.void_args_treated_as_zero";
      check = fun () ->
        let arities = funcs_of void_j |> List.map ~f:fn_arity in
        List.equal Int.equal arities [ 0; 0 ] };
  ]

(* bo1 inspector: `^external` parse in inspect_binding.py --kind mli.
   The s3 stub-facing surface for OCaml bindings. Written as shell
   tests because the inspector is a separate Python script; tests
   produce synthetic .mli fixtures, run the script, parse the JSON,
   and assert the externals / vals fields. *)
let bo1_external_inspect_pure_tests =
  let tmp_root = "_out/canary/test/bo1-external" in
  let _ = Stdlib.Sys.command [%string "mkdir -p %{tmp_root}"] in
  let write_mli name body =
    let path = tmp_root ^ "/" ^ name ^ ".mli" in
    let oc = Stdlib.open_out path in
    Stdlib.output_string oc body;
    Stdlib.close_out oc;
    path in
  let inspect mli_path =
    let out_file = mli_path ^ ".inspect.json" in
    let cmd = [%string
      "python3 canary/scripts/inspect_binding.py --kind mli --path %{mli_path} > %{out_file}"] in
    let rc = Stdlib.Sys.command cmd in
    if rc <> 0 then failwith [%string "inspect_binding failed (rc=%{rc#Int})"];
    Yojson.Basic.from_file out_file in
  let str_list_of_json j name =
    Yojson.Basic.Util.(j |> member name |> to_list |> filter_string) in
  let int_of_json j key =
    Yojson.Basic.Util.(j |> member "counts" |> member key |> to_int) in

  let stub_path = write_mli "stub"
    {|external sum        : int -> int -> int = "caml_tiny_sum"
external diff       : int -> int -> int = "caml_tiny_diff"
external get_offset : unit -> int       = "caml_tiny_get_offset"
|} in
  let user_path = write_mli "user"
    {|val sum    : int -> int -> int
val diff   : int -> int -> int
val offset : unit -> int
|} in
  let mixed_path = write_mli "mixed"
    {|external raw_alpha : int -> int = "c_alpha"
val cooked : int -> int
external raw_beta  : int -> int = "c_beta"
|} in
  let stub_j = inspect stub_path in
  let user_j = inspect user_path in
  let mixed_j = inspect mixed_path in
  [
    { name = "bo1.stub_mli_has_externals_no_vals";
      check = fun () ->
        let externals = str_list_of_json stub_j "externals" in
        let vals = str_list_of_json stub_j "vals" in
        int_of_json stub_j "externals" = 3
        && List.equal String.equal externals
             [ "sum"; "diff"; "get_offset" ]
        && List.is_empty vals };
    { name = "bo1.user_mli_has_vals_no_externals";
      check = fun () ->
        let externals = str_list_of_json user_j "externals" in
        let vals = str_list_of_json user_j "vals" in
        int_of_json user_j "vals" = 3
        && int_of_json user_j "externals" = 0
        && List.equal String.equal vals [ "sum"; "diff"; "offset" ]
        && List.is_empty externals };
    { name = "bo1.mixed_mli_separates_externals_and_vals";
      check = fun () ->
        let externals = str_list_of_json mixed_j "externals" in
        let vals = str_list_of_json mixed_j "vals" in
        List.equal String.equal externals [ "raw_alpha"; "raw_beta" ]
        && List.equal String.equal vals [ "cooked" ] };
  ]

(* c5 cmp_sym_version — provider's exported @@VER set ⊇ consumer's
   required @VER set?
   Catches the deferred tiny scenario e9 symbol_version_floor and,
   end-to-end, the glibc/musl version-drift case (surface_theory §4.2). *)
let cmp_sym_version_pure_tests =
  [
    { name = "cmp_sym_version.compatible_exact_match";
      check = fun () ->
        let r = Canary_compat.check_sym_version
            ~provider_versioned_exports:
              [ "malloc", "GLIBC_2.17"; "__cxa_throw", "GLIBC_2.3.4" ]
            ~consumer_required_versions:[ "GLIBC_2.17" ] in
        match r with Sym_version_compatible -> true | _ -> false };
    { name = "cmp_sym_version.compatible_subset";
      check = fun () ->
        (* Consumer requires a subset of what provider exports. *)
        let r = Canary_compat.check_sym_version
            ~provider_versioned_exports:
              [ "malloc", "GLIBC_2.31"; "memcpy", "GLIBC_2.17";
                "__cxa_throw", "GLIBC_2.3.4" ]
            ~consumer_required_versions:[ "GLIBC_2.17"; "GLIBC_2.3.4" ] in
        match r with Sym_version_compatible -> true | _ -> false };
    { name = "cmp_sym_version.missing_newer_version";
      check = fun () ->
        (* The glibc-musl case: consumer built against GLIBC_2.31 but
           running on a host with only GLIBC_2.17 exports. *)
        let r = Canary_compat.check_sym_version
            ~provider_versioned_exports:[ "malloc", "GLIBC_2.17" ]
            ~consumer_required_versions:[ "GLIBC_2.31" ] in
        match r with
        | Sym_version_missing { missing_versions } ->
            List.equal String.equal missing_versions [ "GLIBC_2.31" ]
        | _ -> false };
    { name = "cmp_sym_version.missing_multiple";
      check = fun () ->
        let r = Canary_compat.check_sym_version
            ~provider_versioned_exports:[ "malloc", "GLIBC_2.17" ]
            ~consumer_required_versions:
              [ "GLIBC_2.31"; "GLIBC_2.34"; "GLIBC_2.17" ] in
        match r with
        | Sym_version_missing { missing_versions } ->
            (* missing_versions deduplicated + sorted; GLIBC_2.17 not in *)
            List.equal String.equal missing_versions
              [ "GLIBC_2.31"; "GLIBC_2.34" ]
        | _ -> false };
    { name = "cmp_sym_version.unknown_no_consumer_req";
      check = fun () ->
        (* Consumer has no @VER requirements at all — nothing to check. *)
        let r = Canary_compat.check_sym_version
            ~provider_versioned_exports:[ "malloc", "GLIBC_2.17" ]
            ~consumer_required_versions:[] in
        match r with Sym_version_unknown -> true | _ -> false };
    { name = "cmp_sym_version.unknown_no_provider_exports";
      check = fun () ->
        (* Tiny baseline today: provider has no @@VER annotations even
           though it could in principle. We can't decide either way. *)
        let r = Canary_compat.check_sym_version
            ~provider_versioned_exports:[]
            ~consumer_required_versions:[ "GLIBC_2.17" ] in
        match r with Sym_version_unknown -> true | _ -> false };
  ]

(* c2 prediction shape: a JSON whose watchlist.missing is [] should
   produce NO failure-string predictions (the positive complement to
   the existing compat.mli_dotted_expansion test which checks the
   non-empty case). *)
let c2_prediction_pure_tests =
  let tmp_root = "_out/canary/test/compat-helper" in
  let _ = Stdlib.Sys.command [%string "mkdir -p %{tmp_root}"] in
  let write_inspect kind name watchlist_missing =
    let path = tmp_root ^ "/" ^ name in
    let missing_json =
      "[" ^ (List.map watchlist_missing ~f:(fun s -> "\"" ^ s ^ "\"")
             |> String.concat ~sep:",") ^ "]"
    in
    let body =
      [%string {|{"kind": "%{kind}", "path": "fixture",
  "watchlist": {"present": [], "missing": %{missing_json}}}|}]
    in
    let oc = Stdlib.open_out path in
    Stdlib.output_string oc body;
    Stdlib.close_out oc;
    path
  in
  let mli_clean = write_inspect "ocaml_mli" "mli_clean.json" [] in
  let py_clean  = write_inspect "python"   "py_clean.json"  [] in
  [
    { name = "c2_prediction.mli_no_missing_no_strings";
      check = fun () ->
        let r = Canary_compat_run.predicted_contains_any_v2 ~resolve:Fn.id
            [ Canary_compat.Ocaml_mli [ mli_clean ] ] in
        List.is_empty r };
    { name = "c2_prediction.python_no_missing_no_strings";
      check = fun () ->
        let r = Canary_compat_run.predicted_contains_any_v2 ~resolve:Fn.id
            [ Canary_compat.Python_attrs [ py_clean ] ] in
        List.is_empty r };
  ]

(* ── §7.2 Phase 1: parametric mutation constructors ──
   Two layers of test.

   1. Pure — constructor round-trip. Verifies that
      [Source.rename_c_symbol ~file ~from_ ~to_] etc. return
      exactly the expected variant. Cheap; catches typos in
      the helper implementations.

   2. Shell — apply on a scratch sandbox + inspect result.
      Copies a source fixture, runs [apply_cmds], greps for
      the mutation's mark. Verifies the shell command
      actually does what its variant claims.

   3. Regression anchor — for each parametric mutation with
      an existing tiny .patch mapping, apply BOTH to a clean
      tiny tree (in separate sandboxes) and diff. Byte-
      identical trees = parity confirmed. This is the strong
      evidence that the parametric constructor faithfully
      reproduces the hand-authored patch. *)

let mutation_pure_tests =
  let module M = Canary_artifact_mutation in
  [
    { name = "mut.Source.rename_c_symbol constructor";
      check = fun () ->
        Poly.equal
          (M.Source.rename_c_symbol ~file:"foo.c" ~from_:"a" ~to_:"b")
          (M.Source.Rename_c_symbol { file = "foo.c"; from_ = "a"; to_ = "b" }) };
    { name = "mut.Source.rename_version_tag constructor";
      check = fun () ->
        Poly.equal
          (M.Source.rename_version_tag ~file:"foo.map" ~from_:"V1" ~to_:"V2")
          (M.Source.Rename_version_tag { file = "foo.map"; from_ = "V1"; to_ = "V2" }) };
    { name = "mut.Native.soname_bump constructor";
      check = fun () ->
        Poly.equal
          (M.Native.soname_bump ~from_so:"libx.so.1.0" ~to_so:"libx.so.2.0")
          (M.Native.Soname_bump { from_so = "libx.so.1.0"; to_so = "libx.so.2.0" }) };
    { name = "mut.Binding.drop_ocaml_val constructor";
      check = fun () ->
        Poly.equal
          (M.Binding.drop_ocaml_val ~file:"x.mli" ~name:"sum")
          (M.Binding.Drop_ocaml_val { file = "x.mli"; name = "sum" }) };
    { name = "mut.Binding.drop_python_attr constructor";
      check = fun () ->
        Poly.equal
          (M.Binding.drop_python_attr ~file:"x.py" ~name:"sum")
          (M.Binding.Drop_python_attr { file = "x.py"; name = "sum" }) };
    { name = "mut.rename_c_symbol apply_cmds shape";
      check = fun () ->
        let cmds = M.Source.apply_cmds ~sandbox:"/tmp/sb"
                     (M.Source.rename_c_symbol ~file:"c/src/tiny.c"
                        ~from_:"tiny_sum" ~to_:"tiny_total")
        in
        List.length cmds = 1
        && String.is_substring (List.hd_exn cmds) ~substring:"sed -i"
        && String.is_substring (List.hd_exn cmds) ~substring:"tiny_sum"
        && String.is_substring (List.hd_exn cmds) ~substring:"tiny_total"
        && String.is_substring (List.hd_exn cmds) ~substring:"/tmp/sb/c/src/tiny.c" };
    { name = "mut.soname_bump apply_cmds shape (5 shell steps)";
      check = fun () ->
        let cmds = M.Native.apply_cmds ~sandbox:"/tmp/sb"
                     (M.Native.soname_bump ~from_so:"libtiny.so.1.0"
                        ~to_so:"libtiny.so.2.0")
        in
        (* mv + rm + 2 ln -sf + patchelf = 5 commands *)
        List.length cmds = 5 };
    { name = "mut.top-level apply_cmds dispatch: Of_native → Native.apply_cmds";
      check = fun () ->
        let m = M.Of_native (M.Native.soname_bump
                               ~from_so:"libx.so.1.0" ~to_so:"libx.so.2.0") in
        let dispatched = M.apply_cmds ~sandbox:"/tmp/sb" m in
        let direct = M.Native.apply_cmds ~sandbox:"/tmp/sb"
                       (M.Native.soname_bump ~from_so:"libx.so.1.0"
                          ~to_so:"libx.so.2.0") in
        Poly.equal dispatched direct };
  ]

(* Shell-level: apply a parametric mutation to a copy of tiny's
   source tree in /tmp, then verify the specific change happened.
   Fixture assumption: tiny source at canary/examples/tiny/ is
   present (repo-local); test skips gracefully if not. *)
let mutation_shell_apply_tests ~tiny_src ~output_dir : Canary_pm_test.test_case list =
  let sb_root = output_dir ^ "/mut_apply" in
  let sb1 = sb_root ^ "/rename_c_symbol" in
  let sb2 = sb_root ^ "/rename_version_tag" in
  let sb3 = sb_root ^ "/drop_ocaml_val" in
  let sb4 = sb_root ^ "/drop_python_attr" in
  let module M = Canary_artifact_mutation in
  let rename_c_cmds = M.Source.apply_cmds ~sandbox:sb1
      (M.Source.rename_c_symbol ~file:"c/src/tiny.c"
         ~from_:"tiny_sum" ~to_:"tiny_total") in
  let rename_v_cmds = M.Source.apply_cmds ~sandbox:sb2
      (M.Source.rename_version_tag ~file:"c/tiny.map"
         ~from_:"TINY_1.0" ~to_:"TINY_2.0") in
  let drop_val_cmds = M.Binding.apply_cmds ~sandbox:sb3
      (M.Binding.drop_ocaml_val ~file:"ocaml/tiny.mli" ~name:"sum") in
  let drop_attr_cmds = M.Binding.apply_cmds ~sandbox:sb4
      (M.Binding.drop_python_attr
         ~file:"python_cext/tiny_cext/__init__.py" ~name:"sum") in
  let seed sb =
    [%string "rm -rf %{sb} && mkdir -p %{sb} && cp -r %{tiny_src}/. %{sb}/"]
  in
  let run_seq cmds =
    String.concat ~sep:" && " (seed sb1 :: cmds) in
  let seq1 =
    [%string "rm -rf %{sb1} && mkdir -p %{sb1} && cp -r %{tiny_src}/. %{sb1}/ && \
              %{String.concat ~sep:\" && \" rename_c_cmds}"] in
  let seq2 =
    [%string "rm -rf %{sb2} && mkdir -p %{sb2} && cp -r %{tiny_src}/. %{sb2}/ && \
              %{String.concat ~sep:\" && \" rename_v_cmds}"] in
  let seq3 =
    [%string "rm -rf %{sb3} && mkdir -p %{sb3} && cp -r %{tiny_src}/. %{sb3}/ && \
              %{String.concat ~sep:\" && \" drop_val_cmds}"] in
  let seq4 =
    [%string "rm -rf %{sb4} && mkdir -p %{sb4} && cp -r %{tiny_src}/. %{sb4}/ && \
              %{String.concat ~sep:\" && \" drop_attr_cmds}"] in
  ignore run_seq;
  [
    { name = "mut.apply.rename_c_symbol produces tiny_total";
      cmd = [%string "%{seq1} && grep -q 'int tiny_total' %{sb1}/c/src/tiny.c \
                       && ! grep -q 'int tiny_sum(' %{sb1}/c/src/tiny.c"];
      expected_rc = 0 };
    { name = "mut.apply.rename_version_tag produces TINY_2.0";
      cmd = [%string "%{seq2} && grep -q '^TINY_2\\.0 {' %{sb2}/c/tiny.map \
                       && ! grep -q '^TINY_1\\.0 {' %{sb2}/c/tiny.map"];
      expected_rc = 0 };
    { name = "mut.apply.drop_ocaml_val removes val sum";
      cmd = [%string "%{seq3} && ! grep -q '^val sum' %{sb3}/ocaml/tiny.mli \
                       && grep -q '^val diff' %{sb3}/ocaml/tiny.mli"];
      expected_rc = 0 };
    { name = "mut.apply.drop_python_attr removes def sum";
      cmd = [%string "%{seq4} && ! grep -q '^def sum(' \
                       %{sb4}/python_cext/tiny_cext/__init__.py \
                       && grep -q '^def diff(' \
                       %{sb4}/python_cext/tiny_cext/__init__.py"];
      expected_rc = 0 };
  ]

(* Regression anchor: apply the parametric constructor AND the
   hand-authored .patch to two clean tiny sandboxes; assert the
   resulting trees are byte-identical (diff -r empty). Proves the
   new primitive faithfully reproduces the existing patch. *)
let mutation_regression_tests ~tiny_src ~patches_dir ~output_dir
  : Canary_pm_test.test_case list =
  let anchor ~name ~patch_file ~apply_param_cmds =
    let root = [%string "%{output_dir}/mut_regress/%{name}"] in
    let sb_p = root ^ "/via_patch" in
    let sb_m = root ^ "/via_mutation" in
    (* Resolve patch path to absolute so `patch` still finds it
       after `cd`ing into the sandbox. `readlink -f` returns the
       absolute path; wrap with a shell subst that eval's at run
       time (patches_dir may be a relative repo path). *)
    (* Subshell so the `cd` doesn't leak into subsequent commands. *)
    let patch_cmd =
      [%string
        "( PATCH_ABS=$(readlink -f '%{patches_dir}/%{patch_file}') && \
           cd %{sb_p} && patch -p1 < \"$PATCH_ABS\" > /dev/null )"]
    in
    let seed sb =
      [%string "rm -rf %{sb} && mkdir -p %{sb} && cp -r %{tiny_src}/. %{sb}/"]
    in
    let mut_seq =
      String.concat ~sep:" && " (seed sb_m :: apply_param_cmds)
    in
    let cmd =
      [%string
        "%{seed sb_p} && %{patch_cmd} && \
         %{mut_seq} && \
         diff -r %{sb_p} %{sb_m}"]
    in
    { Canary_pm_test.name = "mut.regress." ^ name; cmd; expected_rc = 0 }
  in
  let module M = Canary_artifact_mutation in
  [
    anchor ~name:"symbol_missing"
      ~patch_file:"symbol_missing.patch"
      ~apply_param_cmds:(M.Source.apply_cmds ~sandbox:(output_dir ^ "/mut_regress/symbol_missing/via_mutation")
        (M.Source.rename_c_symbol ~file:"c/src/tiny.c"
           ~from_:"tiny_sum" ~to_:"tiny_total"));
    anchor ~name:"symbol_version_floor"
      ~patch_file:"symbol_version_floor.patch"
      ~apply_param_cmds:(M.Source.apply_cmds ~sandbox:(output_dir ^ "/mut_regress/symbol_version_floor/via_mutation")
        (M.Source.rename_version_tag ~file:"c/tiny.map"
           ~from_:"TINY_1.0" ~to_:"TINY_2.0"));
    anchor ~name:"api_complete"
      ~patch_file:"api_complete.patch"
      ~apply_param_cmds:(M.Binding.apply_cmds ~sandbox:(output_dir ^ "/mut_regress/api_complete/via_mutation")
        (M.Binding.drop_ocaml_val ~file:"ocaml/tiny.mli" ~name:"sum"));
    (* api_complete_python.patch hits BOTH python_cext and
       python_ctypes __init__.py, so parity needs both drops. *)
    anchor ~name:"api_complete_python"
      ~patch_file:"api_complete_python.patch"
      ~apply_param_cmds:
        (let sb = output_dir ^ "/mut_regress/api_complete_python/via_mutation" in
         M.Binding.apply_cmds ~sandbox:sb
           (M.Binding.drop_python_attr
              ~file:"python_cext/tiny_cext/__init__.py" ~name:"sum")
         @ M.Binding.apply_cmds ~sandbox:sb
             (M.Binding.drop_python_attr
                ~file:"python_ctypes/tiny_ctypes/__init__.py" ~name:"sum"));
  ]

(* ── §7.9: related_artifacts derivation spec tests ──
   Hand-listed [related_artifacts] was removed from the
   [scenario] type on 2026-07-10; the derivation from
   [actions] is now the sole source. These tests pin
   the derivation output against small hard-coded
   references — one per canonical Sc.N shape — so the
   actions in [artifacts_of_action] can't silently drift. *)
let scenario_derivation_pure_tests =
  let open Canary_basic in
  let open Canary_lang in
  let derived actions =
    Canary_scenario.related_artifacts_of_actions actions
  in
  let cases = [
    "Sc.1", [ Configure; Scan_sources; Build_lib; Install_lib ],
              [ Source; Lib ];
    "Sc.2.OCaml", [ Build_binding OCaml ],
              [ Lib; Binding OCaml ];
    "Sc.3.OCaml", [ Build_app { lang = OCaml } ],
              [ Binding OCaml; App ];
    "Sc.4.OCaml", [ Probe_app { lang = OCaml } ],
              [ Binding OCaml; Lib; App ];
    "Sc.2.Python", [ Build_binding Python ],
              [ Lib; Binding Python ];
    "Sc.4.Python", [ Probe_app { lang = Python } ],
              [ Binding Python; Lib; App ];
    (* Chained: pieces of tiny's acts_full expected to
       collapse under first-appearance union. *)
    "chain.build+probe",
      [ Build_lib; Build_binding OCaml; Probe_app { lang = OCaml } ],
      [ Source; Lib; Binding OCaml; App ];
  ] in
  List.map cases ~f:(fun (name, actions, expected) ->
    { name = "derive." ^ name;
      check = fun () -> Poly.equal (derived actions) expected })

(* ── Shell tests (reuse canary_pm_test.test_case) ── *)

(* Weak generic shape check on a summary JSON. Kept for backwards
   compatibility with existing tests; per-script schema helpers below
   are stricter. *)
let summary_json_valid_cmd path =
  [%string {|python3 -c "
import json, sys
with open('%{path}') as f:
    d = json.load(f)
for k in ('kind','path','counts','watchlist'):
    assert k in d, 'missing key: ' + k
print('ok')
" |}]

(* ── Per-script JSON schema tests ────────────────────────────
   The 4 inspect_*.py scripts are the project-standard producers of
   summary JSONs; multiple callers (tiny's baseline/prepare + the
   tool builders in Canary_artifact_native / _lang) all shell out to
   them. Pinning the output shape here decouples the schema from
   which caller invoked the script, so the R2 sub-gap 2 refactor
   (routing tiny through tool builders instead of inlined pipes) is
   safe by construction: as long as the same script is invoked with
   the same arguments, the JSON is byte-identical; these tests keep
   that invariant honest.

   Each check runs `python3 -c` against a body that:
   - loads the JSON
   - asserts [kind] equals the expected literal
   - asserts every required top-level key exists
   - type-checks values (int / list / dict) for keys where the
     shape is fixed
   Exits 0 on success, non-zero (assertion) on any drift. *)

let schema_check_cmd ~path ~kind ~asserts =
  let body =
    Printf.sprintf
      "import json%s\
       with open('%s') as f: d = json.load(f)%s\
       assert d.get('kind') == '%s', 'wrong kind: ' + str(d.get('kind'))%s\
       %s%s\
       print('ok')"
      "\n" path "\n" kind "\n" asserts "\n"
  in
  [%string {|python3 -c "%{body}" |}]

(* inspect_native.py — kind='native'. Shape: counts.total(int) +
   counts.by_prefix(dict), versioned_req(dict), versioned_exports(dict),
   watchlist.{present,missing}(lists). *)
let native_schema_cmd path =
  schema_check_cmd ~path ~kind:"native" ~asserts:
    "assert isinstance(d['counts']['total'], int), 'counts.total not int'\n\
     assert isinstance(d['counts']['by_prefix'], dict), 'counts.by_prefix not dict'\n\
     assert isinstance(d['versioned_req'], dict), 'versioned_req not dict'\n\
     assert isinstance(d['versioned_exports'], dict), 'versioned_exports not dict'\n\
     assert isinstance(d['watchlist']['present'], list), 'watchlist.present not list'\n\
     assert isinstance(d['watchlist']['missing'], list), 'watchlist.missing not list'\n\
     assert d['counts']['total'] > 0, 'no defined symbols in native fixture'"

(* inspect_ocaml.py — kind='ocaml'. Shape: counts.modules(int),
   counts.imports(list), modules(list), watchlist.{present,missing}. *)
let ocaml_schema_cmd path =
  schema_check_cmd ~path ~kind:"ocaml" ~asserts:
    "assert isinstance(d['counts']['modules'], int), 'counts.modules not int'\n\
     assert isinstance(d['modules'], list), 'modules not list'\n\
     assert isinstance(d['watchlist']['present'], list), 'watchlist.present not list'\n\
     assert isinstance(d['watchlist']['missing'], list), 'watchlist.missing not list'\n\
     assert d['counts']['modules'] > 0, 'no modules in ocaml fixture'"

(* inspect_binding.py --kind mli — kind='ocaml_mli'. Shape:
   counts.{vals,externals,constructors,modules}, vals/externals/... lists,
   externals_detail(list), watchlist.{present,missing}. *)
let mli_schema_cmd path =
  schema_check_cmd ~path ~kind:"ocaml_mli" ~asserts:
    "for k in ('vals','externals','constructors','modules'):\n\
     \    assert isinstance(d['counts'][k], int), 'counts.' + k + ' not int'\n\
     \    assert isinstance(d[k], list), k + ' not list'\n\
     assert isinstance(d['externals_detail'], list), 'externals_detail not list'\n\
     assert isinstance(d['watchlist']['present'], list), 'watchlist.present not list'\n\
     assert isinstance(d['watchlist']['missing'], list), 'watchlist.missing not list'\n\
     assert d['counts']['vals'] > 0, 'no vals in mli fixture'"

(* inspect_binding.py --kind stub — kind='c_stub'. Shape:
   counts.required(int), requires(list), versioned_req(dict), watchlist. *)
let c_stub_schema_cmd path =
  schema_check_cmd ~path ~kind:"c_stub" ~asserts:
    "assert isinstance(d['counts']['required'], int), 'counts.required not int'\n\
     assert isinstance(d['requires'], list), 'requires not list'\n\
     assert isinstance(d['versioned_req'], dict), 'versioned_req not dict'\n\
     assert isinstance(d['watchlist']['present'], list), 'watchlist.present not list'\n\
     assert isinstance(d['watchlist']['missing'], list), 'watchlist.missing not list'\n\
     assert d['counts']['required'] > 0, 'no requires in stub fixture'"

(* inspect_python.py — kind='python'. Two shapes:
   - success: counts.attrs(int), attrs(list), version(str|None),
     extra(dict), watchlist.{present,missing}
   - error: only kind, path, error(str) — no counts/attrs/watchlist
   Assumption for schema tests: fixture imports successfully, so
   assert the success shape. *)
let python_schema_cmd path =
  schema_check_cmd ~path ~kind:"python" ~asserts:
    "assert 'error' not in d, 'python fixture failed to import: ' + d.get('error','')\n\
     assert isinstance(d['counts']['attrs'], int), 'counts.attrs not int'\n\
     assert isinstance(d['attrs'], list), 'attrs not list'\n\
     assert isinstance(d['extra'], dict), 'extra not dict'\n\
     assert isinstance(d['watchlist']['present'], list), 'watchlist.present not list'\n\
     assert isinstance(d['watchlist']['missing'], list), 'watchlist.missing not list'\n\
     assert d['counts']['attrs'] > 0, 'no attrs in python fixture'"

let native_shell_tests ~lib ~output_dir : Canary_pm_test.test_case list =
  let prefix = if Canary_artifact_native.is_macos then "_" else "" in
  let sum_dir = output_dir ^ "/native_inspect" in
  [
    { name = "native.nm_cmd";
      cmd = Canary_artifact_native.nm_cmd lib;
      expected_rc = 0 };
    { name = "native.probe_cmd";
      cmd = Canary_artifact_native.native_lib_probe_cmd
              ~lib ~prefix ~output_dir:(output_dir ^ "/native_probe") ~variant_key:"";
      expected_rc = 0 };
    { name = "native.inspect_cmd";
      cmd = Canary_artifact_native.inspect_cmd
              ~lib ~prefixes:[ prefix ] ~watchlist:[]
              ~output_dir:sum_dir ~variant_key:"" ();
      expected_rc = 0 };
    { name = "native.summary_json_valid";
      cmd = summary_json_valid_cmd (sum_dir ^ "/inspect.json");
      expected_rc = 0 };
    { name = "native.summary_json_schema";
      cmd = native_schema_cmd (sum_dir ^ "/inspect.json");
      expected_rc = 0 };
  ]

let ocaml_shell_tests ~pkg ~output_dir : Canary_pm_test.test_case list =
  let sum_dir = output_dir ^ "/ocaml_inspect" in
  let mli_dir = output_dir ^ "/ocaml_mli_inspect" in
  [
    { name = "ocaml.opam_pkg_inspect";
      cmd = Canary_artifact_lang.opam_pkg_inspect_cmd
              ~pkg ~output_dir:(output_dir ^ "/ocaml_inspect");
      expected_rc = 0 };
    { name = "ocaml.inspect_opam_pkg_cmd";
      cmd = Canary_artifact_lang.inspect_opam_pkg_cmd
              ~pkg ~watchlist:[] ~output_dir:sum_dir ~variant_key:"" ();
      expected_rc = 0 };
    { name = "ocaml.summary_json_valid";
      cmd = summary_json_valid_cmd (sum_dir ^ "/inspect.json");
      expected_rc = 0 };
    { name = "ocaml.summary_json_schema";
      cmd = ocaml_schema_cmd (sum_dir ^ "/inspect.json");
      expected_rc = 0 };
    (* mli-based summary (inspect_binding.py --kind mli). Verifies
       summary.json kind == ocaml_mli with non-zero counts. *)
    { name = "ocaml.mli_inspect_opam_pkg_cmd";
      cmd = Canary_artifact_lang.mli_inspect_opam_pkg_cmd
              ~pkg ~watchlist:[] ~output_dir:mli_dir ~variant_key:"" ();
      expected_rc = 0 };
    { name = "ocaml.mli_inspect_json_valid";
      cmd = [%string {|python3 -c "
import json
with open('%{mli_dir}/inspect.json') as f:
    d = json.load(f)
assert d['kind'] == 'ocaml_mli', 'wrong kind: ' + d['kind']
assert d['counts']['vals'] > 0, 'no vals'
assert d['counts']['modules'] > 0, 'no modules'
print('ok')
" |}];
      expected_rc = 0 };
    { name = "ocaml.mli_inspect_json_schema";
      cmd = mli_schema_cmd (mli_dir ^ "/inspect.json");
      expected_rc = 0 };
  ]

(* Stub-archive summary tests. Requires a pkg that ships a C stub archive
   (lib<name>.a alongside .cmxa). [pkg] is a known stub-bearing pkg like
   "zarith" that the caller verified is installed. *)
let ocaml_stub_shell_tests ~pkg ~output_dir : Canary_pm_test.test_case list =
  let stub_dir = output_dir ^ "/ocaml_stub_inspect" in
  [
    { name = "ocaml.stub_inspect_opam_pkg_cmd";
      cmd = Canary_artifact_lang.stub_inspect_opam_pkg_cmd
              ~pkg ~prefix:"" ~watchlist:[] ~output_dir:stub_dir ~variant_key:"" ();
      expected_rc = 0 };
    { name = "ocaml.stub_inspect_json_valid";
      cmd = [%string {|python3 -c "
import json
with open('%{stub_dir}/inspect_stub.json') as f:
    d = json.load(f)
assert d['kind'] == 'c_stub', 'wrong kind: ' + d['kind']
assert d['counts']['required'] > 0, 'no required symbols'
print('ok')
" |}];
      expected_rc = 0 };
    { name = "ocaml.stub_inspect_json_schema";
      cmd = c_stub_schema_cmd (stub_dir ^ "/inspect_stub.json");
      expected_rc = 0 };
  ]

let python_shell_tests ~pkg ~output_dir : Canary_pm_test.test_case list =
  let sum_dir = output_dir ^ "/py_inspect" in
  [
    { name = "python.import_cmd";
      cmd = Canary_artifact_lang.python_import_cmd
              ~pkg ~output_dir:(output_dir ^ "/py_import");
      expected_rc = 0 };
    { name = "python.import_cmd(bad)";
      cmd = Canary_artifact_lang.python_import_cmd
              ~pkg:"canary_nonexistent_pkg" ~output_dir:(output_dir ^ "/py_import_bad");
      expected_rc = 1 };
    { name = "python.inspect_cmd";
      cmd = Canary_artifact_lang.python_inspect_cmd
              ~pkg ~watchlist:[] ~output_dir:sum_dir ~variant_key:"" ();
      expected_rc = 0 };
    { name = "python.summary_json_valid";
      (* Python summary has no "counts" if error — check kind + path + attrs or error *)
      cmd = [%string {|python3 -c "
import json, sys
with open('%{sum_dir}/inspect.json') as f:
    d = json.load(f)
for k in ('kind','path'):
    assert k in d, 'missing key: ' + k
assert d['kind'] == 'python'
print('ok')
" |}];
      expected_rc = 0 };
    (* Full schema check — assumes `sys` fixture imports successfully. *)
    { name = "python.summary_json_schema";
      cmd = python_schema_cmd (sum_dir ^ "/inspect.json");
      expected_rc = 0 };
  ]

(* ── Runner ── *)

let run_tests ?(output_dir = "_out/canary/test/artifact-test") () =
  (* Probe commands tee into sub-dirs; ensure they all exist up front. *)
  List.iter
    [ ""; "/native_probe"; "/native_inspect";
      "/ocaml_inspect"; "/ocaml_inspect";
      "/ocaml_mli_inspect"; "/ocaml_stub_inspect";
      "/py_import"; "/py_import_bad"; "/py_inspect" ]
    ~f:(fun sub ->
      ignore (Stdlib.Sys.command [%string "mkdir -p %{output_dir}%{sub}"] : int));

  (* Pure tests: always run *)
  let pure_pass = ref 0 in
  let pure_fail = ref 0 in
  let pure_all =
    native_pure_tests @ ocaml_pure_tests @ compat_pure_tests
    @ cmp_symbol_pure_tests @ cmp_abi_pure_tests
    @ cmp_sym_version_pure_tests @ cmp_api_repack_pure_tests
    @ cmp_type_pure_tests @ cmp_api_faithfulness_pure_tests
    @ n3_header_inspect_pure_tests @ bo1_external_inspect_pure_tests
    @ c2_prediction_pure_tests
    @ scenario_derivation_pure_tests
    @ mutation_pure_tests in
  Fmt.pr "Pure predicate tests:@.";
  List.iter pure_all ~f:(fun t ->
      let ok = run_pure_test t in
      if ok then Int.incr pure_pass else Int.incr pure_fail;
      Fmt.pr "  %-40s %s@." t.name (if ok then "PASS" else "FAIL"));
  Fmt.pr "@.";

  (* Shell tests: only run for available fixtures *)
  let shell_tests =
    let native = match native_lib_fixture () with
      | Some lib -> Fmt.pr "native fixture: %s@." lib;
                    native_shell_tests ~lib ~output_dir
      | None -> Fmt.pr "native fixture: none found — skipping native shell tests@."; []
    in
    let ocaml_ =
      if Stdlib.Sys.command "which opam > /dev/null 2>&1" = 0
      then (Fmt.pr "opam found — testing ocaml_pkg_inspect on fmt@.";
            ocaml_shell_tests ~pkg:"fmt" ~output_dir)
      else (Fmt.pr "opam not found — skipping ocaml shell tests@."; [])
    in
    let ocaml_stub =
      if Stdlib.Sys.command
           "eval $(opam env) && ocamlfind query zarith > /dev/null 2>&1" = 0
      then (Fmt.pr "zarith found — testing stub summary on zarith@.";
            ocaml_stub_shell_tests ~pkg:"zarith" ~output_dir)
      else (Fmt.pr "zarith not installed — skipping stub summary tests@."; [])
    in
    let python =
      if Stdlib.Sys.command "which python3 > /dev/null 2>&1" = 0
      then (Fmt.pr "python3 found — testing python_import on sys@.";
            python_shell_tests ~pkg:"sys" ~output_dir)
      else (Fmt.pr "python3 not found — skipping python shell tests@."; [])
    in
    let mutation_apply =
      let tiny_src = "canary/examples/tiny" in
      let patches_dir = "canary/examples/tiny/scenarios/patches" in
      if Stdlib.Sys.file_exists tiny_src
      && Stdlib.Sys.file_exists patches_dir then
        (Fmt.pr "tiny source present — testing mutation apply + regression@.";
         mutation_shell_apply_tests ~tiny_src ~output_dir
         @ mutation_regression_tests ~tiny_src ~patches_dir ~output_dir)
      else
        (Fmt.pr "tiny source missing — skipping mutation apply tests@.";
         [])
    in
    native @ ocaml_ @ ocaml_stub @ python @ mutation_apply
  in
  let sh_pass = ref 0 in
  let sh_fail = ref 0 in
  Fmt.pr "@.Shell tests:@.";
  let results = List.map shell_tests ~f:(fun t ->
      let r = Canary_pm_test.run_test t in
      let ok = Canary_pm_test.is_pass r in
      if ok then Int.incr sh_pass else Int.incr sh_fail;
      let snippet = String.prefix (String.rstrip r.output) 60 in
      Fmt.pr "  %-40s %s  (rc=%d) %s@."
        t.name (if ok then "PASS" else "FAIL") r.actual_rc snippet;
      r)
  in

  (* Write log *)
  let log_path = output_dir ^ "/artifact_test.log" in
  let oc = Stdlib.open_out log_path in
  List.iter pure_all ~f:(fun t ->
      let ok = run_pure_test t in
      Stdlib.Printf.fprintf oc "[%s] %s\n" (if ok then "PASS" else "FAIL") t.name);
  Stdlib.output_string oc "\n";
  List.iter results ~f:(fun r ->
      let status = if Canary_pm_test.is_pass r then "PASS" else "FAIL" in
      Stdlib.Printf.fprintf oc "[%s] %s (expected=%d, actual=%d)\n  cmd: %s\n  out: %s\n\n"
        status r.test.name r.test.expected_rc r.actual_rc r.test.cmd
        (String.prefix r.output 200));
  Stdlib.close_out oc;

  let total_pass = !pure_pass + !sh_pass in
  let total_fail = !pure_fail + !sh_fail in
  Fmt.pr "@.Summary: %d passed, %d failed (pure=%d/%d, shell=%d/%d). Log: %s@."
    total_pass total_fail !pure_pass (!pure_pass + !pure_fail)
    !sh_pass (!sh_pass + !sh_fail) log_path;
  total_fail = 0
