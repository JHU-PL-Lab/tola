open Base

(* ── Type definitions ── *)

type distro = Wsl | MacOS_local
type runner_os = Ubuntu | MacOS
type binding_lang = OCaml | Python
type package_manager = Apt | Brew | Opam | Unsupported
type code_step = Compile | Run
type compile_mode = Native | Bytecode
type origin = Source | Prebuilt

(* type matrix = {} * {} * {} * {}
                                - version selecitons

combination : 
 *)

(* 
job : step list
let stanard_test_job project_spec : job list = [ ] 
  *)

let all_compile_modes = [ Bytecode; Native ]
let all_code_steps = [ Compile; Run ]
let all_cc_and_modes = List.cartesian_product all_compile_modes all_code_steps

type location = Build_tree | System_pm | Lang_pm | Wild of string

type artifact =
  | Artifact_file of string
  | Artifact_dir of string
  | Artifact_package of string

type step_expectation =
  | Expect_success
  | Expect_failure_contains of {
      contains_any : string list;
      expected_returncode : int option;
    }
  | Expect_symbols_resolved of {
      required_libs : string list;
      provided_lib : string;
    }

type condition = On_runner_os of runner_os

type project_spec = {
  root : string;
  version : string;
  commit : string;
  bindings : (binding_lang * package_manager) list;
}

type 'a step = {
  name : string;
  guard : condition option;
  shell : string option;
  env_fields : (string * string) list;
  requires : artifact list;
  produces : artifact list;
  action : 'a;
  expectation : step_expectation;
}

type system_pkg = { linux_pkg : string; macos_pkg : string }

type phase_kind =
  | Install_pkg of system_pkg option
  | Install_local
  | Configure_build of string step list
  | Test_binding
  | Run_command of { name : string; command : string }

type phase_action = Install | Configure | Test

type step_phase = {
  kind : phase_kind;
  action : phase_action;
  location : location;
  requires : artifact list;
  produces : artifact list;
  expectation : step_expectation;
}

type job_spec = {
  distro : distro;
  id : string;
  phases : step_phase list;
  lib_origin : origin;
  binding_location : location;
  test_bindings : binding_lang list;
  example_name : string option;
  build_api_path : string option;
  if_disabled : bool;
}

type deploy_target = { contrib_abs : string; gh_abs : string }

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

type template_vars = { assert_result : string; assert_symbols : string }

type backend_scripts = {
  assert_result_script : string;
  assert_symbols_script : string;
}

type canary_paths = {
  root : string;
  templates_root : string;
  reference_root : string;
  out_root : string;
  contrib_rel : string;
}

type canary_backends = {
  yaml_root : string;
  shell_root : string;
  yaml_scripts : backend_scripts;
  shell_scripts : backend_scripts;
}

type canary_opam = {
  tpl_template : string;
  generated : string;
  in_generated : string;
}

type canary_config = {
  paths : canary_paths;
  backends : canary_backends;
  opam : canary_opam;
  template_vars : template_vars;
}

(* ── Functions ── *)

let detect_distro () =
  match Stdlib.Sys.command "uname -s 2>/dev/null | grep -q Darwin" with
  | 0 -> MacOS_local
  | _ -> Wsl

let z3_dev_root_of_distro : distro -> string = function
  | Wsl -> "/home/ex/code/ocaml-build-examples/vendor/z3"
  | MacOS_local -> "/Users/ex/code/repos/z3"

let z3_stable_root_of_distro : distro -> string = function
  | Wsl -> "/home/ex/code/ocaml-build-examples/vendor/z3-stable"
  | MacOS_local -> "/Users/ex/code/repos/z3-stable"

let z3_dev_spec distro : project_spec =
  {
    root = z3_dev_root_of_distro distro;
    version = "dev";
    commit = "HEAD";
    bindings = [ (OCaml, Opam); (Python, Unsupported) ];
  }

let z3_stable_spec distro : project_spec =
  {
    root = z3_stable_root_of_distro distro;
    version = "4.8.15";
    commit = "745087e";
    bindings = [ (OCaml, Opam); (Python, Unsupported) ];
  }

let name_of_job_spec (spec : job_spec) =
  [%string "%{spec.id} (${{ matrix.os }})"]

let origin_of_location = function
  | Build_tree -> Source
  | System_pm | Lang_pm | Wild _ -> Prebuilt

let default_template_vars =
  {
    assert_result = "%{ASSERT_RESULT_SCRIPT}%";
    assert_symbols = "%{ASSERT_SYMBOLS_SCRIPT}%";
  }

let default_canary_config =
  let root = "canary" in
  let templates_root = root ^ "/templates" in
  let reference_root = root ^ "/reference" in
  let out_root = "_out/canary" in
  let yaml_root = out_root ^ "/backend_yaml" in
  let shell_root = out_root ^ "/backend_shell" in
  let contrib_rel = "contrib/canary" in
  let assert_result = contrib_rel ^ "/scripts/assert_result.py" in
  let assert_symbols = contrib_rel ^ "/scripts/assert_binary_symbols.py" in
  {
    paths = { root; templates_root; reference_root; out_root; contrib_rel };
    backends =
      {
        yaml_root;
        shell_root;
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
      };
    opam =
      {
        tpl_template =
          templates_root ^ "/opam-local-repo/packages/z3/z3.dev/opam";
        generated =
          out_root ^ "/templates/opam-local-repo/packages/z3/z3.dev/opam";
        in_generated =
          out_root ^ "/templates/opam-local-repo/packages/z3/z3.dev/opam.in";
      };
    template_vars = default_template_vars;
  }

let project_yaml_path canary name =
  canary.backends.yaml_root ^ "/canary_" ^ name ^ ".yml"

let project_shell_path canary name =
  canary.backends.shell_root ^ "/canary_" ^ name ^ ".sh"

(* constructor helpers *)

let yaml_preamble_action ?name ?(with_fields = []) uses =
  { name; uses; with_fields }

let run_step ?guard ?shell ?(env_fields = []) ?(requires = []) ?(produces = [])
    ?(expectation = Expect_success) ~name action =
  ({ name; guard; shell; env_fields; requires; produces; action; expectation }
    : 'a step)

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

let apply_expectation expectation cmd =
  let vars = default_template_vars in
  match expectation with
  | Expect_success -> cmd
  | Expect_failure_contains { contains_any; expected_returncode } ->
      let wrapped =
        if multiline cmd then [%string "sh -ec '%{cmd}'"] else cmd
      in
      mk_assert_result_cmd ~assert_script:vars.assert_result
        ?expected_returncode ~contains_any wrapped
  | Expect_symbols_resolved { required_libs; provided_lib } ->
      let args =
        List.map required_libs ~f:(fun lib ->
            [%string "--required-lib \"%{lib}\""])
        @ [ [%string "--provided-lib \"%{provided_lib}\""] ]
        |> String.concat ~sep:" \\\n  "
      in
      [%string "python3 %{vars.assert_symbols} \\\n  %{args}"]

let resolve_backend_scripts ~(scripts : backend_scripts) action =
  let vars = default_template_vars in
  action
  |> String.substr_replace_all ~pattern:vars.assert_result
       ~with_:scripts.assert_result_script
  |> String.substr_replace_all ~pattern:vars.assert_symbols
       ~with_:scripts.assert_symbols_script

let resolve_job_scripts ~scripts (job : string job) =
  {
    job with
    steps =
      List.map job.steps ~f:(fun step ->
          { step with action = resolve_backend_scripts ~scripts step.action });
  }

let checkout_step =
  yaml_preamble_action ~name:"Checkout code" "actions/checkout@v6"

let setup_step =
  yaml_preamble_action
    ~with_fields:[ ("ocaml-version", "${{ matrix.ocaml-version }}") ]
    "./.github/actions/canary-test-setup"

let checkout_and_setup_preamble = [ checkout_step; setup_step ]

let job_of_spec ~(spec : job_spec) =
  {
    id = spec.id;
    if_disabled = spec.if_disabled;
    name = name_of_job_spec spec;
    runs_on = "${{ matrix.os }}";
    preamble = checkout_and_setup_preamble;
    steps = [];
  }

let make_job ~resolve_phase (spec : job_spec) =
  let job = job_of_spec ~spec in
  let (steps : string step list) =
    List.concat_map spec.phases ~f:(resolve_phase spec)
  in
  let steps =
    List.map steps ~f:(fun step ->
        { step with action = apply_expectation step.expectation step.action })
  in
  { job with steps }

let mk_system_dep_steps ~linux_cmd ~macos_cmd =
  [
    run_step ~name:"Install system dependencies (Linux)"
      ~guard:(On_runner_os Ubuntu) ~shell:"bash" linux_cmd;
    run_step ~name:"Install system dependencies (macOS)"
      ~guard:(On_runner_os MacOS) ~shell:"bash" macos_cmd;
  ]

let string_of_expectation = function
  | Expect_success -> "success"
  | Expect_failure_contains { contains_any; _ } ->
      [%string "failure(contains: %{String.concat ~sep:\", \" contains_any})"]
  | Expect_symbols_resolved { provided_lib; _ } ->
      [%string "symbols(%{provided_lib})"]

let dump_step (step : string step) =
  let guard_s =
    match step.guard with
    | None -> ""
    | Some (On_runner_os Ubuntu) -> " [linux]"
    | Some (On_runner_os MacOS) -> " [macos]"
  in
  let exp_s =
    match step.expectation with
    | Expect_success -> ""
    | exp -> [%string " (%{string_of_expectation exp})"]
  in
  let preview =
    let lines = String.split_lines step.action in
    match lines with [] -> "" | [ l ] -> l | l :: _ -> l ^ " ..."
  in
  Fmt.pr "  - %s%s%s@." step.name guard_s exp_s;
  Fmt.pr "    %s@." preview

let dump_job (job : string job) =
  Fmt.pr "Job: %s@." job.id;
  if job.if_disabled then Fmt.pr "  (disabled)@.";
  List.iter job.steps ~f:dump_step;
  Fmt.pr "@."

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
