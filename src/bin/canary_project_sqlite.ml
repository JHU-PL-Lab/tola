open Canary_basic
open Canary_basic_ocaml

let download_and_test_spec distro : job_spec =
  {
    distro;
    id = "download-and-test";
    phases =
      [
        {
          kind = Prebuilt_setup;
          action = Install;
          location = Lang_pm;
          requires = [];
          produces = [ Artifact_package "sqlite3" ];
          expectation = Expect_success;
        };
        {
          kind = Ocaml_test;
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
    project =
      {
        root = "";
        version = "system";
        commit = "";
        bindings = [ (OCaml, Opam) ];
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
    job_specs = [ download_and_test_spec distro ];
  }

let resolve_phase spec phase =
  match phase.kind with
  | Prebuilt_setup ->
      let cfg = config spec.distro in
      let binding = Canary_basic_ocaml.prebuilt_binding_exn cfg.ocaml in
      Canary_basic_ocaml.prebuilt_setup_stages binding
  | Ocaml_test ->
      let cfg = config spec.distro in
      Canary_basic_ocaml.mk_ocaml_test_stages ~config:cfg ~spec ()
  | _ -> []

let make_job spec = make_job ~resolve_phase spec
let jobs distro = [ make_job (download_and_test_spec distro) ]
