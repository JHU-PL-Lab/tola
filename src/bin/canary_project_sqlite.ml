open Canary_basic
open Canary_basic_ocaml

let download_and_test_spec : job_spec =
  {
    id = "download-and-test";
    lib_origin = Prebuilt;
    binding_location = Lang_pm;
    test_bindings = [ OCaml ];
    example_name = Some "sqlite3 example";
    build_api_path = None;
    if_disabled = false;
  }

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
    job_specs = [ download_and_test_spec ];
  }

let download_and_test_job =
  let binding = Canary_basic_ocaml.prebuilt_binding_exn config.ocaml in
  Canary_basic_ocaml.job_of_spec ~spec:download_and_test_spec
    ~steps:
      (Canary_basic_ocaml.prebuilt_setup_stages binding
      @ Canary_basic_ocaml.mk_ocaml_test_stages ~config ~spec:download_and_test_spec ())

let jobs = [ download_and_test_job ]
