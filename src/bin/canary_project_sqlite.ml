open Canary_basic
open Canary_basic_ocaml

let config =
  {
    canary = Canary_basic.default_canary_paths;
    workflow_name = "Canary Testing for SQLite3 OCaml";
    project =
      {
        version = "system";
        commit = "";
        bindings = [ OCaml ];
        package_managers = [ Apt; Brew; Opam ];
      };
    ocaml =
      Prebuilt_binding
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
          opam_package = "sqlite3";
          system_package_linux = "sqlite3";
          system_package_macos = "sqlite";
          example_file = "canary/examples/sqlite3/sqlite3_example.ml";
          example_target = "sqlite3_example";
          binding_lib_name = "sqlite3";
        };
    capabilities =
      {
        supports_source_build = false;
        supports_prebuilt_packaging = false;
        supports_python_binding = false;
      };
  }

let download_and_test_job =
  let { toolchain; opam_package; system_package_linux; system_package_macos; _ }
      =
    Canary_basic_ocaml.prebuilt_binding_exn config.ocaml
  in
  let context =
    Canary_basic_ocaml.context_of_ocaml_tool_config config.ocaml
  in
  let name_of_case =
    Canary_basic_ocaml.example_name_of_case ~example_name:"sqlite3 example"
      ~variant_suffix:""
  in
  Canary_basic_ocaml.mk_canary_job ~id:"download-and-test"
    ~name:"download-and-test (${{ matrix.os }})" ~runs_on:"${{ matrix.os }}"
    ~strategy_yaml:strategy_anchor_yaml
    ~stages:
      (Canary_basic_ocaml.install_system_dep_stages toolchain
         system_package_linux system_package_macos
      @ install_opam_package_stage ~name:"Install sqlite3 OCaml package"
          opam_package
      @ Canary_basic_ocaml.mk_stages ~context ~source:With_pkg ~name_of_case
          ())
    ()

let jobs = collect_some [ Some download_and_test_job ]
