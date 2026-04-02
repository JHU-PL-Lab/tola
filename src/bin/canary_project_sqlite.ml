open Canary_basic
open Canary_basic_ocaml
open Canary

let sqlite_ocaml_config : ocaml_tool_config =
  {
    toolchain =
      {
        prefix_name = "SQLITE3_PREFIX";
        prefix_var = "$SQLITE3_PREFIX";
        prefix_envar = "${SQLITE3_PREFIX}";
        libdir_name = "SQLITE3_LIB_DIR";
        libdir_var = "$SQLITE3_LIB_DIR";
        local_repo_name = "local-sqlite3";
        package_name = "sqlite3";
        package_version = "system";
        canary_src_var = "CANARY_SQLITE3_SRC";
      };
    ocaml =
      {
        example_file = "canary/examples/sqlite3/sqlite3_example.ml";
        example_target = "sqlite3_example";
        example_name = "sqlite3 example";
        binding_lib_name = "sqlite3";
        build_api_path = None;
      };
    prebuilt =
      Some
        {
          opam_package = "sqlite3";
          system_package_linux = "sqlite3";
          system_package_macos = "sqlite";
        };
  }

let prebuilt_prebuilt_spec distro : job_spec =
  {
    distro;
    id = "prebuilt-prebuilt";
    description = "Install system sqlite, install opam sqlite3 binding, probe";
    phases =
      [
        {
          kind =
            Pm_install
              (Some
                 {
                   linux_pkg =
                     (prebuilt_info_exn sqlite_ocaml_config)
                       .system_package_linux;
                   macos_pkg =
                     (prebuilt_info_exn sqlite_ocaml_config)
                       .system_package_macos;
                 });
          location = System_pm;
          requires = [];
          produces = [ { kind = Lib; name = "sqlite3"; location = System_pm } ];
          expectation = Expect_success;
        };
        {
          kind = Pm_install None;
          location = Lang_pm;
          requires = [ { kind = Lib; name = "sqlite3"; location = System_pm } ];
          produces = [ { kind = App; name = "sqlite3"; location = Lang_pm } ];
          expectation = Expect_success;
        };
        {
          kind = Probe_test { lang = OCaml };
          location = Lang_pm;
          requires = [ { kind = App; name = "sqlite3"; location = Lang_pm } ];
          produces = [];
          expectation = Expect_success;
        };
      ];
    if_disabled = false;
  }

let config distro =
  {
    canary = Canary_basic.mk_canary_config ();
    workflow_name = "Canary Testing for SQLite3 OCaml";
    name = "sqlite";
    project =
      {
        root = "";
        version = "system";
        commit = "";
        bindings = [ (OCaml, Opam) ];
        system_pm = Brew;
        has_source = false;
        has_system_pkg = true;
        has_lang_pkg = true;
        can_package = false;
      };
    ocaml = sqlite_ocaml_config;
    job_specs = [ prebuilt_prebuilt_spec distro ];
    deploy = None;
    opam_template_bindings = [];
  }

(* ── Action steps ── *)

let prebuilt = prebuilt_info_exn sqlite_ocaml_config

let script_spec : Canary_action.script_spec =
  let pm = Canary_basic_store.detect_pm () in
  let sys_pkg = match pm with
    | Brew -> prebuilt.system_package_macos
    | _ -> prebuilt.system_package_linux in
  let opam_pkg = prebuilt.opam_package in
  let example = sqlite_ocaml_config.ocaml.example_file in
  let target = sqlite_ocaml_config.ocaml.example_target in
  let binding_lib = sqlite_ocaml_config.ocaml.binding_lib_name in
  { Canary_action.empty_script_spec with
    fetch_lib = Some (fun ~output_dir ->
      [%string "%{Canary_basic_store.pm_install_cmd pm ~pkg:sys_pkg} && echo 'installed' > %{output_dir}/lib.ok"]);
    fetch_binding = Some (fun ~output_dir ->
      [%string "%{Canary_basic_store.pm_install_cmd Opam ~pkg:opam_pkg} && echo 'installed' > %{output_dir}/binding.ok"]);
    probe_binding = Some (fun ~output_dir ->
      [%string "eval $(opam env) && ocamlfind ocamlopt -package %{binding_lib} -linkpkg %{example} -o %{output_dir}/%{target} && %{output_dir}/%{target} 2>&1 | tee %{output_dir}/probe.log"]);
  }

let action_steps ~root ~project =
  Canary_action.derive_steps ~root ~project script_spec
