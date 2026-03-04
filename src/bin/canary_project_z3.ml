open Base
open Tola_std
open Canary_basic
open Canary_basic_ocaml

type z3_instance = {
  root : string;
  external_libz3 : string;
  canary_contrib_abs : string;
  canary_gh_abs : string;
  canary_yaml_output : string;
  canary_z3_src : string;
}

type z3_versions = {
  dev : project_spec * z3_instance;
  stable : project_spec * z3_instance;
}

let canary = Canary_basic.default_canary_paths

let mk_instance root =
  {
    root;
    external_libz3 = root $/ ".helper/z3_root";
    canary_contrib_abs = root $/ canary.contrib_rel;
    canary_gh_abs = root $/ ".github";
    canary_yaml_output = root $/ ".github/workflows/canary_z3.yml";
    canary_z3_src = [%string "git+file://%{root}"];
  }

let mk_versions distro : z3_versions =
  let dev = z3_dev_spec distro in
  let stable = z3_stable_spec distro in
  {
    dev = (dev, mk_instance dev.root);
    stable = (stable, mk_instance stable.root);
  }

let z3_dev_instance_of_distro distro = mk_instance (z3_dev_spec distro).root

let missing_symbols =
  [ "Z3_solver_register_on_clause"; "Z3_mk_seq_replace_all" ]

let expected_symbol_failure =
  Expect_failure_contains
    { contains_any = [ "undefined symbol"; "Z3_mk_u32string" ];
      expected_returncode = None }

let expected_python_failure =
  Expect_failure_contains
    { contains_any = missing_symbols; expected_returncode = Some 1 }

let build_and_test_spec distro : job_spec =
  {
    distro;
    id = "build-and-test";
    phases =
      [ { kind = Configure "Configure with CMake";
          action = Configure; location = Build_tree;
          requires = []; produces = [ Artifact_dir "build" ];
          expectation = Expect_success };
        { kind = Ocaml_test;
          action = Test; location = Build_tree;
          requires = [ Artifact_dir "build/src/api/ml" ]; produces = [];
          expectation = Expect_success };
      ];
    lib_origin = Source;
    binding_location = Build_tree;
    test_bindings = [ OCaml ];
    example_name = Some "ml_example";
    build_api_path = Some "build/src/api/ml";
    if_disabled = true;
  }

let download_and_test_spec distro : job_spec =
  {
    distro;
    id = "download-and-test";
    phases =
      [ { kind = Install_system_deps;
          action = Install; location = System_pm;
          requires = []; produces = [];
          expectation = Expect_success };
        { kind = Configure "Configure with CMake";
          action = Configure; location = Build_tree;
          requires = []; produces = [ Artifact_dir "build" ];
          expectation = Expect_success };
        { kind = Python_binding_test;
          action = Test; location = Build_tree;
          requires = [ Artifact_dir "build/python" ]; produces = [];
          expectation = expected_python_failure };
      ];
    lib_origin = Prebuilt;
    binding_location = Build_tree;
    test_bindings = [ Python ];
    example_name = None;
    build_api_path = None;
    if_disabled = false;
  }

let packaging_spec distro : job_spec =
  {
    distro;
    id = "packaging-from-prebuilt";
    phases =
      [ { kind = Install_system_deps;
          action = Install; location = System_pm;
          requires = []; produces = [];
          expectation = Expect_success };
        { kind = Configure "Configure with CMake (external libz3)";
          action = Configure; location = Build_tree;
          requires = []; produces = [ Artifact_dir "build" ];
          expectation = Expect_success };
        { kind = Install_local_opam;
          action = Install; location = Lang_pm;
          requires = []; produces = [ Artifact_package "z3" ];
          expectation = Expect_success };
        { kind = Ocaml_test;
          action = Test; location = Lang_pm;
          requires = [ Artifact_package "z3" ]; produces = [];
          expectation = expected_symbol_failure };
      ];
    lib_origin = Prebuilt;
    binding_location = Lang_pm;
    test_bindings = [ OCaml ];
    example_name = Some "ml_example";
    build_api_path = Some "build/src/api/ml";
    if_disabled = false;
  }

let z3_ocaml_config =
  Source_binding
    {
      opam = Canary_basic_ocaml.default;
      ocaml =
        {
          example_target = "ml_example";
          example_file = "examples/ml/ml_example.ml";
          binding_lib_name = "z3";
        };
    }

let config distro =
  {
    canary;
    workflow_name = "Canary Testing for Bindings and Packages";
    project = z3_dev_spec distro;
    ocaml = z3_ocaml_config;
    job_specs =
      [
        build_and_test_spec distro;
        download_and_test_spec distro;
        packaging_spec distro;
      ];
  }

let out_h_json ver = [%string "_out/z3_h_%{ver}.json"]

let clang_header_parse header_path json_path =
  [%string
    "clang -fsyntax-only -Xclang -ast-dump=json -Xclang -I%{header_path} \
     %{header_path}/z3.h > %{json_path}"]

let lib_so_path root = [%string "%{root}/build/libz3.so"]

let shared_flags =
  {| -B build -G Ninja \
  -DCMAKE_VERBOSE_MAKEFILE=ON \
  -DZ3_BUILD_LIBZ3_SHARED=ON \
  -DZ3_BUILD_EXECUTABLE=OFF \
  -DZ3_BUILD_TEST_EXECUTABLES=OFF \
  -DZ3_LINK_TIME_OPTIMIZATION=ON \
  -DZ3_BUILD_JAVA_BINDINGS=OFF \|}

let binding_buildgen =
  [%string
    {|eval $(opam env)
cmake \
  %{shared_flags}
  -DZ3_BUILD_OCAML_BINDINGS=ON \
  -DZ3_BUILD_PYTHON_BINDINGS=ON \|}]

let binding_buildgen_use_external libz3_path =
  [%string
    {|eval $(opam env)
cmake \
  %{shared_flags}
	-DZ3_BUILD_LIBZ3_CORE=OFF \
  -DZ3_ROOT=%{libz3_path} \
  -DZ3_BUILD_OCAML_BINDINGS=ON \
  -DZ3_BUILD_PYTHON_BINDINGS=ON|}]

let build_z3_in_opam =
  let toolchain =
    Canary_basic_ocaml.toolchain_of_ocaml_tool_config z3_ocaml_config
  in
  [%string
    {|cmake \
  %{shared_flags}
  -DZ3_BUILD_LIBZ3_CORE=OFF \
  -DZ3_ROOT=%{toolchain.prefix_var} \
  -DZ3_BUILD_OCAML_BINDINGS=ON \
  -DZ3_BUILD_PYTHON_BINDINGS=OFF|}]

(* opam switch 5.3.0 && eval $(opam env) *)

let binding_build =
  {|eval $(opam env)
ninja -C build build_z3_ocaml_bindings
ninja -C build build_z3_python_bindings|}

let python_binding_cmd =
  {|env PYTHONPATH="build/python" python3 -S -c "import z3; print(z3.__file__)"|}

let configure_with_cmake_from_source_stages =
  [
    run_stage ~name:"Configure with CMake"
      ~env_fields:
        [
          ( "CC",
            "${{ matrix.os == 'macos-latest' && 'ccache clang' || 'ccache gcc' \
             }}" );
          ( "CXX",
            "${{ matrix.os == 'macos-latest' && 'ccache clang++' || 'ccache \
             g++' }}" );
        ]
      binding_buildgen;
    run_stage ~name:"Build Z3 and OCaml binding" binding_build;
  ]

let configure_with_external_z3_stages ~configure_name =
  let toolchain =
    Canary_basic_ocaml.toolchain_of_ocaml_tool_config z3_ocaml_config
  in
  [
    run_stage ~name:configure_name
      (binding_buildgen_use_external toolchain.prefix_envar);
    run_stage ~name:"Build OCaml and Python bindings" binding_build;
  ]

let install_local_opam_z3_dev_stages =
  let toolchain =
    Canary_basic_ocaml.toolchain_of_ocaml_tool_config z3_ocaml_config
  in
  [
    run_stage ~name:"Install z3.dev from contrib/canary local opam repo"
      (Canary_basic_ocaml.install_local_cmd toolchain
         ~canary_contrib_rel:canary.contrib_rel);
  ]

let resolve_phase spec phase =
  match phase.kind with
  | Install_system_deps ->
    let toolchain =
      Canary_basic_ocaml.toolchain_of_ocaml_tool_config z3_ocaml_config
    in
    Canary_basic_ocaml.install_system_dep_stages toolchain "z3" "z3"
  | Configure name -> (
    match spec.lib_origin with
    | Source -> configure_with_cmake_from_source_stages
    | Prebuilt -> configure_with_external_z3_stages ~configure_name:name)
  | Install_local_opam -> install_local_opam_z3_dev_stages
  | Ocaml_test ->
    let source = build_source_of_location spec.binding_location in
    let ocaml_step_descs =
      match phase.expectation with
      | Expect_success -> None
      | exp ->
        Some (Canary_basic_ocaml.ocaml_step_descs_with_expectation ~source exp)
    in
    Canary_basic_ocaml.mk_ocaml_test_stages ~config:(config spec.distro) ~spec
      ?ocaml_step_descs ()
  | Python_binding_test ->
    [ run_stage ~name:"Run Python binding"
        ~expectation:phase.expectation python_binding_cmd ]
  | Prebuilt_setup -> []

let make_job spec = make_job ~resolve_phase spec

let jobs distro =
  [
    make_job (build_and_test_spec distro);
    make_job (download_and_test_spec distro);
    make_job (packaging_spec distro);
  ]

let render_opam_templates bindings files =
  List.iter files ~f:(fun (src, dst) ->
      let rendered =
        List.fold bindings ~init:(read_file src) ~f:(fun acc (k, v) ->
            String.substr_replace_all acc ~pattern:k ~with_:v)
      in
      let parent = Stdlib.Filename.dirname dst in
      ignore (Stdlib.Sys.command (Fmt.str "mkdir -p %s" parent));
      write_file dst rendered)
