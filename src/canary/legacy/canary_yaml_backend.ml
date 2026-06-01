(** [Canary_yaml_backend] — retired YAML-and-shell backend plumbing.

    Lifted from [base/canary_basic.ml] and [action/canary.ml] on
    2026-06-01 into the legacy/ sub-library. These types and helpers
    drove an earlier yaml + shell backend that has since been replaced
    by the current action-graph pipeline ([Canary_action.script_spec]
    + [Canary_action.derive_steps] + [Canary_backend_gh] for GH YAML).

    Nothing in the live pipeline references this module — it remains
    only because {!Canary_dead_code} consumed [mk_canary_config] and
    the [job_spec] / [phase_kind] vocabulary to encode the
    distro × sys-PM × lang-PM enumeration intent. The intent is still
    worth preserving (see CLAUDE.md "Retire legacy config distro /
    project_config / job_spec plumbing") but the implementation is
    not.

    Delete this whole file when the intent is either re-modelled in the
    live pipeline or judged not worth carrying forward. *)

open Base
open Canary_store
open Canary_basic

(* ── Phase / job vocabulary ── *)

type system_pkg = { linux_pkg : string; macos_pkg : string }

type phase_kind =
  | Pm_install of system_pkg option
  | Pm_install_local of package_manager
  | Cmake_buildgen of step
  | Cmake_build of step
  | Probe_test of { lang : Canary_lang.lang }
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

(* ── Phase / job helpers ── *)

let name_of_phase (phase : step_phase) =
  match phase.kind with
  | Pm_install _ -> (
      match phase.location with
      | Pm _ -> "Install binding package"
      | loc -> [%string "Install via %{string_of_location loc}"])
  | Pm_install_local pm ->
      [%string "Install from local %{string_of_pm pm} repo"]
  | Cmake_buildgen _ -> "Configure with CMake"
  | Cmake_build _ -> "Build with CMake"
  | Probe_test { lang } -> [%string "Probe %{Canary_lang.string_of_lang lang} binding"]
  | Run_command { name; _ } -> name

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

(* ── Constructors ── *)

let yaml_preamble_action ?name ?(with_fields = []) uses =
  { name; uses; with_fields }

(* ── Backend script substitution ── *)

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

(* ── project_config + phase-driven step generation (was in action/canary.ml) ── *)

type project_config = {
  canary : canary_config;
  workflow_name : string;
  name : string;
  project : project_spec;
  ocaml : Canary_toolchain.ocaml_tool_config;
  job_specs : job_spec list;
  deploy : deploy_target option;
  opam_template_bindings : (string * string) list;
}

let verify_of_phase (config : project_config) (phase : step_phase) =
  let open Canary_toolchain in
  let name = [%string "Verify: %{name_of_phase phase}"] in
  match phase.kind with
  | Pm_install _system_pkg -> (
      match phase.location with
      | Pm _ ->
          let info = prebuilt_info_exn config.ocaml in
          verify_opam_install_spec_step ~name info.opam_package_spec
      | _ -> [])
  | Pm_install_local Opam ->
      let pkg = pkg_full config.ocaml.toolchain in
      verify_opam_install_step ~name pkg
  | Pm_install_local _ -> []
  | Cmake_buildgen _ | Cmake_build _ -> []
  | Probe_test _ -> []
  | Run_command _ -> []

let steps_of_phase (config : project_config) (phase : step_phase) =
  let open Canary_toolchain in
  let name = name_of_phase phase in
  let action_steps =
    match phase.kind with
    | Pm_install _system_pkg -> (
        match phase.location with
        | Pm _ ->
            let info = prebuilt_info_exn config.ocaml in
            install_opam_package_spec_step ~name info.opam_package_spec
        | _ -> failwith "Pm_install: unsupported location")
    | Pm_install_local pm -> (
        match pm with
        | Opam ->
            [
              run_step ~name
                (install_local_cmd config.ocaml.toolchain
                   ~canary_contrib_rel:config.canary.paths.contrib_rel);
            ]
        | _ -> failwith "Pm_install_local: only Opam is currently supported")
    | Cmake_buildgen step | Cmake_build step -> [ step ]
    | Probe_test { lang } -> (
        match lang with
        | Canary_lang.OCaml ->
            mk_ocaml_test_steps ~ocaml:config.ocaml
              ~binding_location:phase.location ()
        | Canary_lang.Python ->
            let pkg = config.ocaml.ocaml.binding_lib_name in
            [
              run_step ~name
                [%string
                  {|env PYTHONPATH="build/python" python3 -S -c "import %{pkg}; print(%{pkg}.__file__)"|}];
            ]
        | _ -> failwith "Probe_test: unsupported lang")
    | Run_command { name = _; command } ->
        [ run_step ~name command ]
  in
  action_steps @ verify_of_phase config phase
