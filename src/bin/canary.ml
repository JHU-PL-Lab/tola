open Canary_basic
open Canary_basic_ocaml

type project_config = {
  canary : canary_config;
  workflow_name : string;
  name : string;
  project : project_spec;
  ocaml : ocaml_tool_config;
  job_specs : job_spec list;
  deploy : deploy_target option;
  opam_template_bindings : (string * string) list;
}

let resolve_phase (config : project_config) (spec : job_spec)
    (phase : step_phase) =
  match phase.kind with
  | Install_pkg system_pkg -> (
      match phase.location with
      | System_pm ->
          let { linux_pkg; macos_pkg } =
            match system_pkg with
            | Some p -> p
            | None -> failwith "Install_pkg at System_pm requires system_pkg"
          in
          install_system_dep_steps config.ocaml.toolchain linux_pkg macos_pkg
      | Lang_pm ->
          let info = prebuilt_info_exn config.ocaml in
          install_opam_package_step info.opam_package
      | _ -> failwith "Install_pkg: unsupported location")
  | Install_local ->
      let pkg = pkg_full config.ocaml.toolchain in
      [
        run_step
          ~name:[%string "Install %{pkg} from contrib/canary local opam repo"]
          (install_local_cmd config.ocaml.toolchain
             ~canary_contrib_rel:config.canary.paths.contrib_rel);
      ]
  | Configure_build steps -> steps
  | Test_binding ->
      mk_ocaml_test_steps ~ocaml:config.ocaml ~spec
        ~test_expectation:phase.expectation ()
  | Run_command { name; command } ->
      [ run_step ~name ~expectation:phase.expectation command ]

let make_job config spec =
  Canary_basic.make_job ~resolve_phase:(resolve_phase config) spec
