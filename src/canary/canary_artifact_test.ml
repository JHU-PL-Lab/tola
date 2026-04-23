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
    first_existing [
      "/usr/lib/libSystem.dylib";
      "/usr/lib/libc.dylib";
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
  { name = "ocaml.is_ocaml_archive(.cmxa)"; check = fun () -> Canary_artifact_ocaml.is_ocaml_archive "foo.cmxa" };
  { name = "ocaml.is_ocaml_archive(.cma)"; check = fun () -> Canary_artifact_ocaml.is_ocaml_archive "foo.cma" };
  { name = "ocaml.!is_ocaml_archive(.so)"; check = fun () -> not (Canary_artifact_ocaml.is_ocaml_archive "foo.so") };
  { name = "ocaml.cmxa_stub_archive"; check = fun () ->
      String.equal (Canary_artifact_ocaml.cmxa_stub_archive "/x/z3ml.cmxa") "/x/libz3ml.a" };
]

(* ── Shell tests (reuse canary_pm_test.test_case) ── *)

(* Run a command and check the process exit code against expectation.
   Writes output to {output_dir}/{name}.log for inspection. *)
(* Verify that a summary.json produced by a summary_cmd is valid JSON with
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
  let sum_dir = output_dir ^ "/native_summary" in
  [
    { name = "native.nm_cmd";
      cmd = Canary_artifact_native.nm_cmd lib;
      expected_rc = 0 };
    { name = "native.probe_cmd";
      cmd = Canary_artifact_native.native_lib_probe_cmd
              ~lib ~prefix ~output_dir:(output_dir ^ "/native_probe");
      expected_rc = 0 };
    { name = "native.summary_cmd";
      cmd = Canary_artifact_native.summary_cmd
              ~lib ~prefixes:[ prefix ] ~watchlist:[]
              ~output_dir:sum_dir ();
      expected_rc = 0 };
    { name = "native.summary_json_valid";
      cmd = summary_json_valid_cmd (sum_dir ^ "/summary.json");
      expected_rc = 0 };
  ]

let ocaml_shell_tests ~pkg ~output_dir : Canary_pm_test.test_case list =
  let sum_dir = output_dir ^ "/ocaml_summary" in
  [
    { name = "ocaml.opam_pkg_inspect";
      cmd = Canary_artifact_ocaml.opam_pkg_inspect_cmd
              ~pkg ~output_dir:(output_dir ^ "/ocaml_inspect");
      expected_rc = 0 };
    { name = "ocaml.summary_opam_pkg_cmd";
      cmd = Canary_artifact_ocaml.summary_opam_pkg_cmd
              ~pkg ~watchlist:[] ~output_dir:sum_dir ();
      expected_rc = 0 };
    { name = "ocaml.summary_json_valid";
      cmd = summary_json_valid_cmd (sum_dir ^ "/summary.json");
      expected_rc = 0 };
  ]

let python_shell_tests ~pkg ~output_dir : Canary_pm_test.test_case list =
  let sum_dir = output_dir ^ "/py_summary" in
  [
    { name = "python.import_cmd";
      cmd = Canary_artifact_python.python_import_cmd
              ~pkg ~output_dir:(output_dir ^ "/py_import");
      expected_rc = 0 };
    { name = "python.import_cmd(bad)";
      cmd = Canary_artifact_python.python_import_cmd
              ~pkg:"canary_nonexistent_pkg" ~output_dir:(output_dir ^ "/py_import_bad");
      expected_rc = 1 };
    { name = "python.summary_cmd";
      cmd = Canary_artifact_python.summary_cmd
              ~pkg ~watchlist:[] ~output_dir:sum_dir ();
      expected_rc = 0 };
    { name = "python.summary_json_valid";
      (* Python summary has no "counts" if error — check kind + path + attrs or error *)
      cmd = [%string {|python3 -c "
import json, sys
with open('%{sum_dir}/summary.json') as f:
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
    [ ""; "/native_probe"; "/native_summary";
      "/ocaml_inspect"; "/ocaml_summary";
      "/py_import"; "/py_import_bad"; "/py_summary" ]
    ~f:(fun sub ->
      ignore (Stdlib.Sys.command [%string "mkdir -p %{output_dir}%{sub}"] : int));

  (* Pure tests: always run *)
  let pure_pass = ref 0 in
  let pure_fail = ref 0 in
  let pure_all = native_pure_tests @ ocaml_pure_tests in
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
    let python =
      if Stdlib.Sys.command "which python3 > /dev/null 2>&1" = 0
      then (Fmt.pr "python3 found — testing python_import on sys@.";
            python_shell_tests ~pkg:"sys" ~output_dir)
      else (Fmt.pr "python3 not found — skipping python shell tests@."; [])
    in
    native @ ocaml_ @ python
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
