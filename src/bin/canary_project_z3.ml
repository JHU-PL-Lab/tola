open Base
open Tola_std
open Canary_basic
open Canary_basic_ocaml
open Canary

type z3_instance = { root : string; external_libz3 : string }

let canary = Canary_basic.default_canary_config
let mk_instance root = { root; external_libz3 = root $/ ".helper/z3_root" }

let mk_deploy root =
  { contrib_abs = root $/ canary.paths.contrib_rel; gh_abs = root $/ ".github" }

let z3_dev_instance_of_distro distro = mk_instance (z3_dev_spec distro).root

let missing_symbols =
  [ "Z3_solver_register_on_clause"; "Z3_mk_seq_replace_all" ]

let expected_symbol_failure =
  Expect_failure_contains
    {
      contains_any = [ "undefined symbol"; "Z3_mk_u32string" ];
      expected_returncode = None;
    }

let expected_python_failure =
  Expect_failure_contains
    { contains_any = missing_symbols; expected_returncode = Some 1 }

let z3_ocaml_config : Canary_basic_ocaml.ocaml_tool_config =
  {
    toolchain = Canary_basic_ocaml.default;
    ocaml =
      {
        example_target = "ml_example";
        example_file = "examples/ml/ml_example.ml";
        binding_lib_name = "z3";
      };
    prebuilt = None;
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
  let toolchain = z3_ocaml_config.toolchain in
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

let configure_with_cmake_from_source_steps =
  [
    run_step ~name:"Configure with CMake"
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
    run_step ~name:"Build Z3 and OCaml binding" binding_build;
  ]

let configure_with_external_z3_steps ~configure_name =
  let toolchain = z3_ocaml_config.toolchain in
  [
    run_step ~name:configure_name
      (binding_buildgen_use_external toolchain.prefix_envar);
    run_step ~name:"Build OCaml and Python bindings" binding_build;
  ]

let build_and_test_spec distro : job_spec =
  {
    distro;
    id = "build-and-test";
    phases =
      [
        {
          kind = Configure_build configure_with_cmake_from_source_steps;
          action = Configure;
          location = Build_tree;
          requires = [];
          produces = [ Artifact_dir "build" ];
          expectation = Expect_success;
        };
        {
          kind = Test_binding;
          action = Test;
          location = Build_tree;
          requires = [ Artifact_dir "build/src/api/ml" ];
          produces = [];
          expectation = Expect_success;
        };
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
      [
        {
          kind = Install_pkg (Some { linux_pkg = "z3"; macos_pkg = "z3" });
          action = Install;
          location = System_pm;
          requires = [];
          produces = [];
          expectation = Expect_success;
        };
        {
          kind =
            Configure_build
              (configure_with_external_z3_steps
                 ~configure_name:"Configure with CMake");
          action = Configure;
          location = Build_tree;
          requires = [];
          produces = [ Artifact_dir "build" ];
          expectation = Expect_success;
        };
        {
          kind =
            Run_command
              { name = "Run Python binding"; command = python_binding_cmd };
          action = Test;
          location = Build_tree;
          requires = [ Artifact_dir "build/python" ];
          produces = [];
          expectation = expected_python_failure;
        };
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
      [
        {
          kind = Install_pkg (Some { linux_pkg = "z3"; macos_pkg = "z3" });
          action = Install;
          location = System_pm;
          requires = [];
          produces = [];
          expectation = Expect_success;
        };
        {
          kind =
            Configure_build
              (configure_with_external_z3_steps
                 ~configure_name:"Configure with CMake (external libz3)");
          action = Configure;
          location = Build_tree;
          requires = [];
          produces = [ Artifact_dir "build" ];
          expectation = Expect_success;
        };
        {
          kind = Install_local;
          action = Install;
          location = Lang_pm;
          requires = [];
          produces = [ Artifact_package "z3" ];
          expectation = Expect_success;
        };
        {
          kind = Test_binding;
          action = Test;
          location = Lang_pm;
          requires = [ Artifact_package "z3" ];
          produces = [];
          expectation = expected_symbol_failure;
        };
      ];
    lib_origin = Prebuilt;
    binding_location = Lang_pm;
    test_bindings = [ OCaml ];
    example_name = Some "ml_example";
    build_api_path = Some "build/src/api/ml";
    if_disabled = false;
  }

let config distro =
  let z3_dev = z3_dev_spec distro in
  {
    canary;
    workflow_name = "Canary Testing for Bindings and Packages";
    name = "z3";
    project = z3_dev;
    ocaml = z3_ocaml_config;
    job_specs =
      [
        build_and_test_spec distro;
        download_and_test_spec distro;
        packaging_spec distro;
      ];
    deploy = Some (mk_deploy z3_dev.root);
    opam_template_bindings = [ ("%{BUILD_Z3_IN_OPAM}%", build_z3_in_opam) ];
  }
