open Base
open Canary_store

(* ── Type definitions ── *)

type runner_os = Ubuntu | MacOS
type binding_lang = OCaml | Python
type probe_action = Compile_example | Run_example
type compile_mode = Native | Bytecode
type artifact_kind = Source | Lib | Binding | App

let kind_order = function
  | Source -> 0 | Lib -> 1 | Binding -> 2 | App -> 3

type artifact = { kind : artifact_kind; name : string; location : location }

type artifact_node = {
  a_kind : artifact_kind;
  a_name : string;
  origin : location;
  a_location : location;
  built_from : artifact_node option;
  runtime_dep : artifact_node option;
}

type artifact_op = Compile | Fetch | Pack | Test

let all_compile_modes = [ Bytecode; Native ]
let all_probe_actions = [ Compile_example; Run_example ]

let all_cc_and_modes =
  List.cartesian_product all_compile_modes all_probe_actions

type condition = On_runner_os of runner_os

type project_spec = {
  root : string;
  version : string;
  commit : string;
  bindings : (binding_lang * package_manager) list;
  (* graph capabilities *)
  system_pm : package_manager;
  has_source : bool;
  has_system_pkg : bool;
  has_lang_pkg : bool;
  can_package : bool;
}

type cmdline = string

type step = {
  name : string;
  guard : condition option;
  shell : string option;
  env_fields : (string * string) list;
  requires : artifact list;
  produces : artifact list;
  action : cmdline;
}

type system_pkg = { linux_pkg : string; macos_pkg : string }

type phase_kind =
  | Pm_install of system_pkg option
  | Pm_install_local of package_manager
  | Cmake_buildgen of step
  | Cmake_build of step
  | Probe_test of { lang : binding_lang }
  | Run_command of { name : string; command : string }

type step_phase = {
  kind : phase_kind;
  location : location;
  requires : artifact list;
  produces : artifact list;
}

type job_spec = {
  distro : distro;
  id : string;
  description : string;
  phases : step_phase list;
  if_disabled : bool;
}

type deploy_target = { contrib_abs : string; gh_abs : string }

type yaml_preamble_action = {
  name : string option;
  uses : string;
  with_fields : (string * string) list;
}

type job = {
  id : string;
  description : string;
  if_disabled : bool;
  name : string;
  runs_on : string;
  preamble : yaml_preamble_action list;
  steps : step list;
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

let opam_local_repo_path ~pkg_name ~versioned_name =
  [%string "/opam-local-repo/packages/%{pkg_name}/%{versioned_name}/opam"]

type canary_config = {
  paths : canary_paths;
  backends : canary_backends;
  opam : canary_opam;
  template_vars : template_vars;
}

(* ── Functions ── *)

let string_of_lang = function OCaml -> "OCaml" | Python -> "Python"


let name_of_phase (phase : step_phase) =
  match phase.kind with
  | Pm_install _ -> (
      match phase.location with
      | System_pm -> "Install system dependencies"
      | Lang_pm -> "Install binding package"
      | loc -> [%string "Install via %{string_of_location loc}"])
  | Pm_install_local pm ->
      [%string "Install from local %{string_of_pm pm} repo"]
  | Cmake_buildgen _ -> "Configure with CMake"
  | Cmake_build _ -> "Build with CMake"
  | Probe_test { lang } -> [%string "Probe %{string_of_lang lang} binding"]
  | Run_command { name; _ } -> name

let detect_distro () =
  match Stdlib.Sys.command "uname -s 2>/dev/null | grep -q Darwin" with
  | 0 -> MacOS_local
  | _ -> Wsl


let name_of_job_spec (spec : job_spec) =
  [%string "%{spec.id} (${{ matrix.os }})"]


let default_template_vars =
  {
    assert_result = "%{ASSERT_RESULT_SCRIPT}%";
    assert_symbols = "%{ASSERT_SYMBOLS_SCRIPT}%";
  }

let mk_canary_config ?(pkg_name = "") ?(versioned_name = "") () =
  let root = "canary" in
  let templates_root = root ^ "/templates" in
  let reference_root = root ^ "/reference" in
  let out_root = "_out/canary" in
  let yaml_root = out_root ^ "/backend_yaml" in
  let shell_root = out_root ^ "/backend_shell" in
  let contrib_rel = "contrib/canary" in
  let assert_result = contrib_rel ^ "/scripts/assert_result.py" in
  let assert_symbols = contrib_rel ^ "/scripts/assert_binary_symbols.py" in
  let opam_rel = opam_local_repo_path ~pkg_name ~versioned_name in
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
        tpl_template = templates_root ^ opam_rel;
        generated = out_root ^ "/templates" ^ opam_rel;
        in_generated = out_root ^ "/templates" ^ opam_rel ^ ".in";
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
    ~name action =
  ({ name; guard; shell; env_fields; requires; produces; action } : step)

(* utilities *)

let multiline s = String.is_substring s ~substring:"\n"

let indent_block spaces s =
  let pad = String.make spaces ' ' in
  String.split_lines s
  |> List.map ~f:(fun l -> pad ^ l)
  |> String.concat ~sep:"\n"

let resolve_backend_scripts ~(scripts : backend_scripts) action =
  let vars = default_template_vars in
  action
  |> String.substr_replace_all ~pattern:vars.assert_result
       ~with_:scripts.assert_result_script
  |> String.substr_replace_all ~pattern:vars.assert_symbols
       ~with_:scripts.assert_symbols_script

let resolve_job_scripts ~scripts (job : job) =
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
    description = spec.description;
    if_disabled = spec.if_disabled;
    name = name_of_job_spec spec;
    runs_on = "${{ matrix.os }}";
    preamble = checkout_and_setup_preamble;
    steps = [];
  }

let make_job ~steps_of_phase ~config (spec : job_spec) =
  let job = job_of_spec ~spec in
  let (steps : step list) =
    List.concat_map spec.phases ~f:(steps_of_phase config)
  in
  { job with steps }

let mk_system_dep_steps ~name ~linux_cmd ~macos_cmd =
  [
    run_step ~name:[%string "%{name} (Linux)"] ~guard:(On_runner_os Ubuntu)
      ~shell:"bash" linux_cmd;
    run_step ~name:[%string "%{name} (macOS)"] ~guard:(On_runner_os MacOS)
      ~shell:"bash" macos_cmd;
  ]

let pp_step ppf (step : step) =
  let guard_s =
    match step.guard with
    | None -> ""
    | Some (On_runner_os Ubuntu) -> " [linux]"
    | Some (On_runner_os MacOS) -> " [macos]"
  in
  let preview =
    let lines = String.split_lines step.action in
    match lines with [] -> "" | [ l ] -> l | l :: _ -> l ^ " ..."
  in
  Fmt.pf ppf "  - %s%s@." step.name guard_s;
  Fmt.pf ppf "    %s@." preview

let pp_job ppf (job : job) =
  Fmt.pf ppf "Job: %s@." job.id;
  if not (String.is_empty job.description) then
    Fmt.pf ppf "  %s@." job.description;
  if job.if_disabled then Fmt.pf ppf "  (disabled)@.";
  List.iter job.steps ~f:(pp_step ppf);
  Fmt.pf ppf "@."

let dump_step = pp_step Fmt.stdout
let dump_job = pp_job Fmt.stdout

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
