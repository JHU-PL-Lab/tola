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
  let l3_only = Canary_compat.predicted_contains_any_v2
      [ Canary_compat.Ocaml_mli mli_path ] in
  let py_only = Canary_compat.predicted_contains_any_v2
      [ Canary_compat.Python_attrs py_path ] in
  let mixed = Canary_compat.predicted_contains_any_v2
      [ Canary_compat.Ocaml_mli mli_path; Canary_compat.Python_attrs py_path ] in
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
        List.is_empty (Canary_compat.predicted_contains_any_v2 []) };
  ]

(* ── Shell tests (reuse canary_pm_test.test_case) ── *)

(* Run a command and check the process exit code against expectation.
   Writes output to {output_dir}/{name}.log for inspection. *)
(* Verify that a summary.json produced by a inspect_cmd is valid JSON with
   the expected top-level fields. Returns 0 on success, 1 on failure. *)
let summary_json_valid_cmd path =
  [%string {|python3 -c "
import json, sys
with open('%{path}') as f:
    d = json.load(f)
for k in ('kind','path','counts','watchlist'):
    assert k in d, 'missing key: ' + k
print('ok')
" |}]

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
  let pure_all = native_pure_tests @ ocaml_pure_tests @ compat_pure_tests in
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
    native @ ocaml_ @ ocaml_stub @ python
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
