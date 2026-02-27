open Base

type ocaml_mode = Native | Bytecode
type build_source = From_build | With_pkg
type runner_os = Ubuntu | MacOS

type stage_expectation =
  | Expect_success
  | Expect_failure_contains of string list
  | Expect_symbols_resolved of {
      required_libs : string list;
      provided_lib : string;
    }

let mode_slug = function Bytecode -> "bytecode" | Native -> "native"
let source_slug = function From_build -> "from_build" | With_pkg -> "with_pkg"

let compile_placeholder mode source =
  [%string "compile_%{mode_slug mode}_%{source_slug source}"]

let run_placeholder mode source =
  [%string "run_%{mode_slug mode}_%{source_slug source}"]

let run_with_pkg_expected_failure_placeholder mode =
  [%string "run_%{mode_slug mode}_with_pkg_expected_failure"]

let compile_with_pkg_expected_failure_placeholder mode =
  [%string "compile_%{mode_slug mode}_with_pkg_expected_failure"]

let check_file_exists_exn path =
  let exists = Stdlib.Sys.file_exists path in
  Fmt.pr "File ./%s %s.@." path (if exists then "exists" else "missing");
  Fmt.pr "[Check_exists] %b@." exists;
  if not exists then failwith [%string "Missing file: %{path}"]

let run_cmd_exn cmd =
  Fmt.pr "[Command] %s@." cmd;
  let code = Stdlib.Sys.command cmd in
  Fmt.pr "[Command][Output]@.";
  if code <> 0 then failwith [%string "Command failed (%{Int.to_string code}): %{cmd}"]
