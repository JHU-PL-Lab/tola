open Base
open Tola_std
open Canary_basic_store
open Canary_basic
open Canary_basic_ocaml
open Canary

type z3_instance = { root : string; external_libz3 : string }

let canary = Canary_basic.mk_canary_config ~pkg_name:"z3" ~versioned_name:"z3.dev" ()
let mk_instance root = { root; external_libz3 = root $/ ".helper/z3_root" }

let mk_deploy root =
  { contrib_abs = root $/ canary.paths.contrib_rel; gh_abs = root $/ ".github" }

let z3_dev_root_of_distro : distro -> string = function
  | Wsl -> "/home/ex/code/ocaml-build-examples/vendor/z3"
  | MacOS_local -> "/Users/ex/code/repos/z3"

let z3_stable_root_of_distro : distro -> string = function
  | Wsl -> "/home/ex/code/ocaml-build-examples/vendor/z3-stable"
  | MacOS_local -> "/Users/ex/code/repos/z3-stable"

let z3_dev_spec distro : project_spec =
  {
    root = z3_dev_root_of_distro distro;
    version = "dev";
    commit = "HEAD";
    bindings = [ (OCaml, Opam); (Python, Unsupported) ];
    system_pm = Brew;
    has_source = true;
    has_system_pkg = true;
    has_lang_pkg = true;
    can_package = true;
  }

let z3_stable_spec distro : project_spec =
  {
    root = z3_stable_root_of_distro distro;
    version = "4.8.15";
    commit = "745087e";
    bindings = [ (OCaml, Opam); (Python, Unsupported) ];
    system_pm = Brew;
    has_source = true;
    has_system_pkg = true;
    has_lang_pkg = true;
    can_package = true;
  }

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
        example_name = "ml_example";
        example_file = "examples/ml/ml_example.ml";
        binding_lib_name = "z3";
        build_api_path = Some "build/src/api/ml";
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

let cc_env_fields =
  [
    ( "CC",
      "${{ matrix.os == 'macos-latest' && 'ccache clang' || 'ccache gcc' }}" );
    ( "CXX",
      "${{ matrix.os == 'macos-latest' && 'ccache clang++' || 'ccache g++' }}"
    );
  ]

let source_source_spec distro : job_spec =
  {
    distro;
    id = "source-source";
    description = "Build libz3 from source, build binding from source tree, probe";
    phases =
      [
        {
          kind =
            Cmake_buildgen
              (run_step ~env_fields:cc_env_fields ~name:"Configure with CMake"
                 binding_buildgen);
          location = Build_tree;
          requires = [];
          produces = [];
          expectation = Expect_success;
        };
        {
          kind =
            Cmake_build
              (run_step ~name:"Build Z3 and OCaml binding" binding_build);
          location = Build_tree;
          requires = [];
          produces =
            [
              { kind = Lib; name = "z3"; location = Build_tree };
              { kind = Binding; name = "z3"; location = Build_tree };
            ];
          expectation = Expect_success;
        };
        {
          kind = Probe_test { lang = OCaml };
          location = Build_tree;
          requires = [ { kind = Binding; name = "z3"; location = Build_tree } ];
          produces = [];
          expectation = Expect_success;
        };
      ];
    if_disabled = true;
  }

let prebuilt_source_spec distro : job_spec =
  {
    distro;
    id = "prebuilt-source";
    description = "Install libz3 from system PM, build binding from source tree, probe";
    phases =
      [
        {
          kind = Pm_install (Some { linux_pkg = "z3"; macos_pkg = "z3" });
          location = System_pm;
          requires = [];
          produces = [ { kind = Lib; name = "z3"; location = System_pm } ];
          expectation = Expect_success;
        };
        {
          kind =
            Cmake_buildgen
              (run_step ~name:"Configure with CMake"
                 (binding_buildgen_use_external
                    z3_ocaml_config.toolchain.prefix_envar));
          location = Build_tree;
          requires = [ { kind = Lib; name = "z3"; location = System_pm } ];
          produces = [];
          expectation = Expect_success;
        };
        {
          kind =
            Cmake_build
              (run_step ~name:"Build OCaml and Python bindings" binding_build);
          location = Build_tree;
          requires = [ { kind = Lib; name = "z3"; location = System_pm } ];
          produces = [ { kind = Binding; name = "z3"; location = Build_tree } ];
          expectation = Expect_success;
        };
        {
          kind = Probe_test { lang = Python };
          location = Build_tree;
          requires = [ { kind = Binding; name = "z3-python"; location = Build_tree } ];
          produces = [];
          expectation = expected_python_failure;
        };
      ];
    if_disabled = false;
  }

let prebuilt_packaged_spec distro : job_spec =
  {
    distro;
    id = "prebuilt-packaged";
    description = "Install libz3 from system PM, build binding, package into local opam, probe";
    phases =
      [
        {
          kind = Pm_install (Some { linux_pkg = "z3"; macos_pkg = "z3" });
          location = System_pm;
          requires = [];
          produces = [ { kind = Lib; name = "z3"; location = System_pm } ];
          expectation = Expect_success;
        };
        {
          kind =
            Cmake_buildgen
              (run_step ~name:"Configure with CMake (external libz3)"
                 (binding_buildgen_use_external
                    z3_ocaml_config.toolchain.prefix_envar));
          location = Build_tree;
          requires = [ { kind = Lib; name = "z3"; location = System_pm } ];
          produces = [];
          expectation = Expect_success;
        };
        {
          kind =
            Cmake_build
              (run_step ~name:"Build OCaml and Python bindings" binding_build);
          location = Build_tree;
          requires = [ { kind = Lib; name = "z3"; location = System_pm } ];
          produces = [ { kind = Binding; name = "z3"; location = Build_tree } ];
          expectation = Expect_success;
        };
        {
          kind = Pm_install_local Opam;
          location = Lang_pm;
          requires = [ { kind = Binding; name = "z3"; location = Build_tree } ];
          produces = [ { kind = App; name = "z3"; location = Lang_pm } ];
          expectation = Expect_success;
        };
        {
          kind = Probe_test { lang = OCaml };
          location = Lang_pm;
          requires = [ { kind = App; name = "z3"; location = Lang_pm } ];
          produces = [];
          expectation = expected_symbol_failure;
        };
      ];
    if_disabled = false;
  }

(* ── Action steps (derived from script_spec) ── *)

let detect_pm () =
  if Stdlib.Sys.command "which brew > /dev/null 2>&1" = 0 then "brew"
  else "apt-get"

let mk_script_spec distro : Canary_action.script_spec =
  let root = z3_dev_root_of_distro distro in
  let pm = detect_pm () in
  let example = z3_ocaml_config.ocaml.example_file in
  let target = z3_ocaml_config.ocaml.example_target in
  let binding_lib = z3_ocaml_config.ocaml.binding_lib_name in
  let api_path = Option.value_exn z3_ocaml_config.ocaml.build_api_path in
  { Canary_action.empty_script_spec with
    fetch_source = Some (fun ~output_dir ->
      (* source is already on disk — record its location *)
      [%string "test -d %{root}/src && echo '%{root}' > %{output_dir}/source.ok"]);
    build_lib = Some (fun ~output_dir ->
      [%string "cd %{root} && eval $(opam env) && cmake -B build -G Ninja -DCMAKE_VERBOSE_MAKEFILE=ON -DZ3_BUILD_LIBZ3_SHARED=ON -DZ3_BUILD_EXECUTABLE=OFF -DZ3_BUILD_TEST_EXECUTABLES=OFF -DZ3_LINK_TIME_OPTIMIZATION=ON -DZ3_BUILD_JAVA_BINDINGS=OFF -DZ3_BUILD_OCAML_BINDINGS=ON -DZ3_BUILD_PYTHON_BINDINGS=ON && ninja -C build && echo 'ok' > %{output_dir}/build.ok"]);
    build_binding = Some (fun ~output_dir ->
      (* ninja rebuilds only changed targets; cmake configure reuses cache *)
      [%string "cd %{root} && eval $(opam env) && ninja -C build && echo 'ok' > %{output_dir}/build.ok"]);
    fetch_lib = Some (fun ~output_dir ->
      [%string "%{pm} install z3 && echo 'installed' > %{output_dir}/lib.ok"]);
    (* fetch_binding = None: z3 opam package requires LLVM on PATH,
       not available on all machines. Use build_binding → pack_binding instead. *)
    pack_binding = Some (fun ~output_dir ->
      let contrib_rel = canary.paths.contrib_rel in
      [%string "cd %{root} && eval $(opam env) && %{install_local_cmd z3_ocaml_config.toolchain ~canary_contrib_rel:contrib_rel} && echo 'ok' > %{output_dir}/pack.ok"]);
    probe_lib = Some (fun ~output_dir ->
      [%string "test -f %{root}/build/libz3.so && echo 'ok' > %{output_dir}/probe.log || test -f %{root}/build/libz3.dylib && echo 'ok' > %{output_dir}/probe.log"]);
    probe_binding = Some (fun ~output_dir ->
      (* compile example against build tree *)
      [%string "cd %{root} && eval $(opam env) && ocamlfind ocamlopt -package %{binding_lib} -linkpkg -I %{api_path} %{example} -o %{output_dir}/%{target} && %{output_dir}/%{target} 2>&1 | tee %{output_dir}/probe.log"]);
  }

(* Full spec: all actions including build-from-source *)
let action_steps ?(quick = false) ~root ~project distro =
  let spec = mk_script_spec distro in
  let spec = if quick then Canary_action.no_source spec else spec in
  Canary_action.derive_steps ~root ~project spec

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
        source_source_spec distro;
        prebuilt_source_spec distro;
        prebuilt_packaged_spec distro;
      ];
    deploy = Some (mk_deploy z3_dev.root);
    opam_template_bindings = [ ("%{BUILD_Z3_IN_OPAM}%", build_z3_in_opam) ];
  }
