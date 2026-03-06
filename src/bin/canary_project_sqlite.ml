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
        binding_lib_name = "sqlite3";
      };
    prebuilt =
      Some
        {
          opam_package = "sqlite3";
          system_package_linux = "sqlite3";
          system_package_macos = "sqlite";
        };
  }

let download_and_test_spec distro : job_spec =
  {
    distro;
    id = "download-and-test";
    phases =
      [
        {
          kind =
            Install_pkg
              (Some
                 {
                   linux_pkg =
                     (prebuilt_info_exn sqlite_ocaml_config)
                       .system_package_linux;
                   macos_pkg =
                     (prebuilt_info_exn sqlite_ocaml_config)
                       .system_package_macos;
                 });
          action = Install;
          location = System_pm;
          requires = [];
          produces = [];
          expectation = Expect_success;
        };
        {
          kind = Install_pkg None;
          action = Install;
          location = Lang_pm;
          requires = [];
          produces = [ Artifact_package "sqlite3" ];
          expectation = Expect_success;
        };
        {
          kind = Test_binding;
          action = Test;
          location = Lang_pm;
          requires = [ Artifact_package "sqlite3" ];
          produces = [];
          expectation = Expect_success;
        };
      ];
    lib_origin = Prebuilt;
    binding_location = Lang_pm;
    test_bindings = [ OCaml ];
    example_name = Some "sqlite3 example";
    build_api_path = None;
    if_disabled = false;
  }

let config distro =
  {
    canary = Canary_basic.default_canary_config;
    workflow_name = "Canary Testing for SQLite3 OCaml";
    name = "sqlite";
    project =
      {
        root = "";
        version = "system";
        commit = "";
        bindings = [ (OCaml, Opam) ];
      };
    ocaml = sqlite_ocaml_config;
    job_specs = [ download_and_test_spec distro ];
    deploy = None;
    opam_template_bindings = [];
  }
