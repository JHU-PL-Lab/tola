open Base

(* basic datatypes *)

type code_step = Compile | Run
type build_source = From_build | With_pkg
type runner_os = Ubuntu | MacOS
type binding_lang = OCaml | Python
type package_manager = Apt | Brew | Opam

type project_spec = {
  version : string;
  commit : string;
  bindings : binding_lang list;
  package_managers : package_manager list;
}

type project_capabilities = {
  supports_source_build : bool;
  supports_prebuilt_packaging : bool;
  supports_python_binding : bool;
}

type origin = Source | Prebuilt
type location = Build_tree | System_pm | Lang_pm | Wild of string

type job_spec = {
  id : string;
  lib_origin : origin;
  binding_location : location;
  test_bindings : binding_lang list;
  example_name : string option;
  build_api_path : string option;
  if_disabled : bool;
}

let name_of_job_spec (spec : job_spec) =
  [%string "%{spec.id} (${{ matrix.os }})"]

let is_job_enabled capabilities (spec : job_spec) =
  match (spec.lib_origin, spec.binding_location) with
  | Source, _ -> capabilities.supports_source_build
  | Prebuilt, Lang_pm -> capabilities.supports_prebuilt_packaging
  | Prebuilt, _ -> true

let build_source_of_location = function
  | Build_tree -> From_build
  | System_pm | Lang_pm | Wild _ -> With_pkg

type stage_expectation =
  | Expect_success
  | Expect_failure_contains of string list
  | Expect_symbols_resolved of {
      required_libs : string list;
      provided_lib : string;
    }

type stage_artifact =
  | Artifact_file of string
  | Artifact_dir of string
  | Artifact_package of string

type stage_guard = Guard_runner_os of runner_os

type 'a step = {
  name : string;
  guard : stage_guard option;
  shell : string option;
  env_fields : (string * string) list;
  requires : stage_artifact list;
  produces : stage_artifact list;
  action : 'a;
  expectation : stage_expectation;
}

type yaml_preamble_action = {
  name : string option;
  uses : string;
  with_fields : (string * string) list;
}

type 'a job = {
  id : string;
  if_disabled : bool;
  name : string;
  runs_on : string;
  preamble : yaml_preamble_action list;
  steps : 'a step list;
}

type backend_scripts = {
  assert_result_script : string;
  assert_symbols_script : string;
}

type canary_paths = {
  root : string;
  templates_root : string;
  reference_root : string;
  out_root : string;
  backend_yaml_root : string;
  backend_shell_root : string;
  opam_tpl_template : string;
  opam_generated : string;
  opam_in_generated : string;
  contrib_rel : string;
  assert_result : string;
  assert_symbols : string;
  yaml_scripts : backend_scripts;
  shell_scripts : backend_scripts;
}

let default_canary_paths =
  let root = "canary" in
  let templates_root = root ^ "/templates" in
  let reference_root = root ^ "/reference" in
  let out_root = "_out/canary" in
  let backend_yaml_root = out_root ^ "/backend_yaml" in
  let backend_shell_root = out_root ^ "/backend_shell" in
  let contrib_rel = "contrib/canary" in
  let assert_result = contrib_rel ^ "/scripts/assert_result.py" in
  let assert_symbols = contrib_rel ^ "/scripts/assert_binary_symbols.py" in
  {
    root;
    templates_root;
    reference_root;
    out_root;
    backend_yaml_root;
    backend_shell_root;
    opam_tpl_template =
      templates_root ^ "/opam-local-repo/packages/z3/z3.dev/opam";
    opam_generated =
      out_root ^ "/templates/opam-local-repo/packages/z3/z3.dev/opam";
    opam_in_generated =
      out_root ^ "/templates/opam-local-repo/packages/z3/z3.dev/opam.in";
    contrib_rel;
    assert_result;
    assert_symbols;
    yaml_scripts =
      {
        assert_result_script = assert_result;
        assert_symbols_script = assert_symbols;
      };
    shell_scripts =
      {
        assert_result_script = "${CANARY_ROOT}/scripts/assert_result.py";
        assert_symbols_script =
          "${CANARY_ROOT}/scripts/assert_binary_symbols.py";
      };
  }

let project_yaml_path canary name =
  canary.backend_yaml_root ^ "/canary_" ^ name ^ ".yml"

let project_shell_path canary name =
  canary.backend_shell_root ^ "/canary_" ^ name ^ ".sh"

(* constructor helpers *)

let yaml_preamble_action ?name ?(with_fields = []) uses =
  { name; uses; with_fields }

let run_stage ?guard ?shell ?(env_fields = []) ?(requires = []) ?(produces = [])
    ?(expectation = Expect_success) ~name action =
  ({ name; guard; shell; env_fields; requires; produces; action; expectation }
    : 'a step)

let when_enabled enabled value = if enabled then Some value else None

(* utilities *)

let multiline s = String.is_substring s ~substring:"\n"

let indent_block spaces s =
  let pad = String.make spaces ' ' in
  String.split_lines s
  |> List.map ~f:(fun l -> pad ^ l)
  |> String.concat ~sep:"\n"

let mk_assert_result_cmd ~assert_script ?expected_returncode
    ?(contains_any = []) command =
  let expected_returncode_args =
    match expected_returncode with
    | None -> []
    | Some code -> [ [%string "--expected-returncode %{Int.to_string code}"] ]
  in
  let args =
    expected_returncode_args
    @ List.map contains_any ~f:(fun s -> [%string "--contains-any '%{s}'"])
    |> String.concat ~sep:" \\\n  "
  in
  let arg_block = if String.is_empty args then "" else args ^ " \\\n  " in
  [%string {|python3 %{assert_script} \
  %{arg_block}-- \
  %{command}|}]

let apply_expectation ~(scripts : backend_scripts) expectation cmd =
  match expectation with
  | Expect_success -> cmd
  | Expect_failure_contains contains_any ->
      mk_assert_result_cmd ~assert_script:scripts.assert_result_script
        ~contains_any [%string "sh -ec '%{cmd}'"]
  | Expect_symbols_resolved { required_libs; provided_lib } ->
      let args =
        List.map required_libs ~f:(fun lib ->
            [%string "--required-lib \"%{lib}\""])
        @ [ [%string "--provided-lib \"%{provided_lib}\""] ]
        |> String.concat ~sep:" \\\n  "
      in
      [%string "python3 %{scripts.assert_symbols_script} \\\n  %{args}"]

let checkout_step =
  yaml_preamble_action ~name:"Checkout code" "actions/checkout@v6"

let setup_step =
  yaml_preamble_action
    ~with_fields:[ ("ocaml-version", "${{ matrix.ocaml-version }}") ]
    "./.github/actions/canary-test-setup"

let checkout_and_setup_preamble = [ checkout_step; setup_step ]

let mk_system_dep_stages ~linux_cmd ~macos_cmd =
  [
    run_stage ~name:"Install system dependencies (Linux)"
      ~guard:(Guard_runner_os Ubuntu) ~shell:"bash" linux_cmd;
    run_stage ~name:"Install system dependencies (macOS)"
      ~guard:(Guard_runner_os MacOS) ~shell:"bash" macos_cmd;
  ]

let check_file_exists_exn path =
  let exists = Stdlib.Sys.file_exists path in
  Fmt.pr "File ./%s %s.@." path (if exists then "exists" else "missing");
  Fmt.pr "[Check_exists] %b@." exists;
  if not exists then failwith [%string "Missing file: %{path}"]

let run_cmd ?(strict = true) cmd =
  Fmt.pr "[Command] %s@." cmd;
  let code = Stdlib.Sys.command cmd in
  Fmt.pr "[Command][Output]@.";
  if code <> 0 then
    let msg = [%string "Command failed (%{Int.to_string code}): %{cmd}"] in
    if strict then failwith msg else Fmt.pr "[Command][Warning] %s@." msg

let run_cmd_exn cmd = run_cmd ~strict:true cmd
