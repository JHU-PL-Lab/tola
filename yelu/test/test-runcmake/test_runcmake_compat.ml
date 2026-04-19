(** Run RunCMake positive-test scripts directly via cmake -P, bypassing CTest.
    Each test: run <dir>/<name>.cmake, check exit 0, match <name>-stdout.txt patterns. *)

open Yelu_runner.Cmake_runner

let runcmake_dir =
  match Sys.getenv_opt "RUNCMAKE_DIR" with
  | Some d -> d
  | None ->
    (* Walk up from CWD to find the source workspace root.
       The source root contains yelu/vendor/; the build tree does not. *)
    let rec find dir depth =
      if depth > 10 then
        failwith ("cannot find workspace root from " ^ Sys.getcwd ())
      else
        let marker = Filename.concat dir "yelu/vendor" in
        if Sys.file_exists marker then dir
        else find (Filename.dirname dir) (depth + 1)
    in
    let ws_root = find (Sys.getcwd ()) 0 in
    let vendor_cmake = Filename.concat ws_root "yelu/vendor/cmake" in
    let resolved = try Unix.realpath vendor_cmake with Unix.Unix_error _ -> vendor_cmake in
    Filename.concat resolved "Tests/RunCMake"

let script_dir d = Filename.concat runcmake_dir d

let check name dir =
  Alcotest.test_case name `Quick (fun () ->
    let script = Filename.concat dir (name ^ ".cmake") in
    let result = run_script_file script in
    check_exit 0 result;
    check_stdout_patterns (load_stdout_patterns dir name) result)

let () =
  Alcotest.run "RunCMake compat"
    [ ("math", [
        check "MATH"     (script_dir "math");
        check "Overflow" (script_dir "math") ]);
      ("list", [
        check "JOIN"     (script_dir "list");
        check "SORT"     (script_dir "list");
        check "POP_BACK" (script_dir "list");
        check "POP_FRONT"(script_dir "list");
        check "PREPEND"  (script_dir "list") ]);
      ("string", [
        check "Concat"   (script_dir "string");
        check "Append"   (script_dir "string");
        check "Join"     (script_dir "string");
        check "Hex"      (script_dir "string");
        check "Uuid"     (script_dir "string");
        check "Repeat"   (script_dir "string") ]);
      ("foreach", [
        check "foreach-all-test" (script_dir "foreach") ]);
      ("message", [
        check "newline"          (script_dir "message");
        check "message-indent"   (script_dir "message") ]);
    ]
