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

let z3_dev_root = "/home/ex/code/ocaml-build-examples/vendor/z3"
let z3_stable_root = "/home/ex/code/ocaml-build-examples/vendor/z3-stable"

let versions : z3_versions =
  {
    dev =
      ( {
          version = "dev";
          commit = "HEAD";
          bindings = [ OCaml; Python ];
          package_managers = [ Opam ];
        },
        mk_instance z3_dev_root );
    stable =
      ( {
          version = "4.8.15";
          commit = "745087e";
          bindings = [ OCaml; Python ];
          package_managers = [ Opam ];
        },
        mk_instance z3_stable_root );
  }

let z3_dev_spec, z3_dev_instance = versions.dev
let _z3_stable_spec, _z3_stable_instance = versions.stable

let build_and_test_spec : job_spec =
  {
    id = "build-and-test";
    lib_origin = Source;
    binding_location = Build_tree;
    test_bindings = [ OCaml ];
    example_name = Some "ml_example";
    build_api_path = Some "build/src/api/ml";
    if_disabled = true;
  }

let download_and_test_spec : job_spec =
  {
    id = "download-and-test";
    lib_origin = Prebuilt;
    binding_location = Build_tree;
    test_bindings = [ Python ];
    example_name = None;
    build_api_path = None;
    if_disabled = false;
  }

let packaging_spec : job_spec =
  {
    id = "packaging-from-prebuilt";
    lib_origin = Prebuilt;
    binding_location = Lang_pm;
    test_bindings = [ OCaml ];
    example_name = Some "ml_example";
    build_api_path = Some "build/src/api/ml";
    if_disabled = false;
  }

let config =
  {
    canary;
    workflow_name = "Canary Testing for Bindings and Packages";
    project = z3_dev_spec;
    ocaml =
      Source_binding
        {
          opam = Canary_basic_ocaml.default;
          ocaml =
            {
              example_target = "ml_example";
              example_file = "examples/ml/ml_example.ml";
              binding_lib_name = "z3";
            };
        };
    capabilities =
      {
        supports_source_build = true;
        supports_prebuilt_packaging = true;
        supports_python_binding = true;
      };
    job_specs = [ build_and_test_spec; download_and_test_spec; packaging_spec ];
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
    Canary_basic_ocaml.toolchain_of_ocaml_tool_config config.ocaml
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

let missing_symbols =
  [ "Z3_solver_register_on_clause"; "Z3_mk_seq_replace_all" ]

let run_python_binding canary missing_symbols =
  mk_assert_result_cmd ~assert_script:canary.assert_result
    ~expected_returncode:1 ~contains_any:missing_symbols
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
    Canary_basic_ocaml.toolchain_of_ocaml_tool_config config.ocaml
  in
  [
    run_stage ~name:configure_name
      (binding_buildgen_use_external toolchain.prefix_envar);
    run_stage ~name:"Build OCaml and Python bindings" binding_build;
  ]

let python_binding_stages =
  [
    run_stage ~name:"Run Python binding"
      (run_python_binding config.canary missing_symbols);
  ]

let install_local_opam_z3_dev_stages =
  let toolchain =
    Canary_basic_ocaml.toolchain_of_ocaml_tool_config config.ocaml
  in
  [
    run_stage ~name:"Install z3.dev from contrib/canary local opam repo"
      (Canary_basic_ocaml.install_local_cmd toolchain
         ~canary_contrib_rel:config.canary.contrib_rel);
  ]

let expected_symbol_failure =
  Expect_failure_contains [ "undefined symbol"; "Z3_mk_u32string" ]

let with_pkg_expected_failure_cases =
  List.map (Canary_basic_ocaml.default_ocaml_step_descs ~source:With_pkg)
    ~f:(fun ({ code_step; mode; _ } as step_spec) ->
      let expectation =
        match (code_step, mode) with
        | Compile, Bytecode -> Expect_success
        | Run, Bytecode | Compile, Native | Run, Native ->
            expected_symbol_failure
      in
      { step_spec with expectation })

let build_and_test_job =
  Canary_basic_ocaml.job_of_spec ~spec:build_and_test_spec
    ~steps:
      (configure_with_cmake_from_source_stages
      @ Canary_basic_ocaml.mk_ocaml_test_stages ~config ~spec:build_and_test_spec ())

let download_and_test_job =
  let toolchain =
    Canary_basic_ocaml.toolchain_of_ocaml_tool_config config.ocaml
  in
  let post_build_stages =
    if config.capabilities.supports_python_binding then python_binding_stages
    else []
  in
  Canary_basic_ocaml.job_of_spec ~spec:download_and_test_spec
    ~steps:
      (Canary_basic_ocaml.install_system_dep_stages toolchain "z3" "z3"
      @ configure_with_external_z3_stages ~configure_name:"Configure with CMake"
      @ post_build_stages)

let packaging_from_prebuilt_job =
  let toolchain =
    Canary_basic_ocaml.toolchain_of_ocaml_tool_config config.ocaml
  in
  Canary_basic_ocaml.job_of_spec ~spec:packaging_spec
    ~steps:
      (Canary_basic_ocaml.install_system_dep_stages toolchain "z3" "z3"
      @ configure_with_external_z3_stages
          ~configure_name:"Configure with CMake (external libz3)"
      @ install_local_opam_z3_dev_stages
      @ Canary_basic_ocaml.mk_ocaml_test_stages ~config ~spec:packaging_spec
          ~ocaml_step_descs:with_pkg_expected_failure_cases ())

let jobs =
  List.filter_opt
    [
      when_enabled config.capabilities.supports_source_build build_and_test_job;
      Some download_and_test_job;
      when_enabled config.capabilities.supports_prebuilt_packaging
        packaging_from_prebuilt_job;
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
