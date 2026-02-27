open Base
open Tola_std

open Canary_helper

type binding_lang = OCaml | Python
type package_manager = Apt | Brew | Opam

type canary_paths = {
  root : string;
  templates_root : string;
  workflows_root : string;
  out_root : string;
  yaml_template : string;
  yaml_generated : string;
  opam_tpl_template : string;
  opam_generated : string;
  opam_in_generated : string;
  contrib_rel : string;
  assert_result : string;
  assert_symbols : string;
}

type z3_project_spec = {
  version : string;
  commit : string;
  bindings : binding_lang list;
  package_managers : package_manager list;
}

type z3_project_instance = {
  root : string;
  external_libz3 : string;
  canary_contrib_abs : string;
  canary_gh_abs : string;
  canary_yaml_output : string;
  canary_z3_src : string;
}

type z3_projects = {
  dev : z3_project_spec * z3_project_instance;
  stable : z3_project_spec * z3_project_instance;
}

type ocaml_language = {
  example_target : string;
  example_file : string;
  binding_lib_name : string;
}

type language_config = { opam : Canary_opam.t; ocaml : ocaml_language }

type z3_config = {
  canary : canary_paths;
  z3 : z3_projects;
  languages : language_config;
}

let config =
  let canary_root = "canary" in
  let canary_templates_root = canary_root $/ "templates" in
  let canary_workflows_root = canary_root $/ "workflows" in
  let canary_out_root = "_out/canary" in
  let canary_contrib_rel = "contrib/canary" in
  let z3_dev_root = "/home/ex/code/ocaml-build-examples/vendor/z3" in
  let z3_stable_root = "/home/ex/code/ocaml-build-examples/vendor/z3-stable" in
  let mk_instance root =
    {
      root;
      external_libz3 = root $/ ".helper/z3_root";
      canary_contrib_abs = root $/ canary_contrib_rel;
      canary_gh_abs = root $/ ".github";
      canary_yaml_output = root $/ ".github/workflows/canary_binding_pkg.yml";
      canary_z3_src = [%string "git+file://%{root}"];
    }
  in
  {
    canary =
      {
        root = canary_root;
        templates_root = canary_templates_root;
        workflows_root = canary_workflows_root;
        out_root = canary_out_root;
        yaml_template = canary_workflows_root $/ "canary_binding_pkg.tpl.yml";
        yaml_generated = canary_out_root $/ "workflows/canary_binding_pkg.yml";
        opam_tpl_template =
          canary_templates_root $/ "opam-local-repo/packages/z3/z3.dev/opam";
        opam_generated =
          canary_out_root $/ "opam-local-repo/packages/z3/z3.dev/opam";
        opam_in_generated =
          canary_out_root $/ "opam-local-repo/packages/z3/z3.dev/opam.in";
        contrib_rel = canary_contrib_rel;
        assert_result = canary_contrib_rel $/ "scripts/assert_result.py";
        assert_symbols = canary_contrib_rel $/ "scripts/assert_z3_symbols.py";
      };
    z3 =
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
      };
    languages =
      {
        opam = Canary_opam.default;
        ocaml =
          {
            example_target = "ml_example";
            example_file = "examples/ml/ml_example.ml";
            binding_lib_name = "z3";
          };
      };
  }

let z3_dev_spec, z3_dev_instance = config.z3.dev
let z3_stable_spec, z3_stable_instance = config.z3.stable

(* input files *)
let lib_so_path root = [%string "%{root}/build/libz3.so"]
let ocaml_ci root = root $/ ".github/workflows/ocaml.yaml"

(* output files *)
let clang_header_parse header_path json_path =
  [%string
    "clang -fsyntax-only -Xclang -ast-dump=json -Xclang -I%{header_path} \
     %{header_path}/z3.h > %{json_path}"]

let out_h_json ver = [%string "_out/z3_h_%{ver}.json"]

(* -S . \ *)

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
  [%string
    {|cmake \
  %{shared_flags}
  -DZ3_BUILD_LIBZ3_CORE=OFF \
  -DZ3_ROOT=%{config.languages.opam.prefix_var} \
  -DZ3_BUILD_OCAML_BINDINGS=ON \
  -DZ3_BUILD_PYTHON_BINDINGS=OFF|}]

(* opam switch 5.3.0 && eval $(opam env) *)

let binding_build =
  {|eval $(opam env)
ninja -C build build_z3_ocaml_bindings
ninja -C build build_z3_python_bindings|}

let missing_symbols =
  [ "Z3_solver_register_on_clause"; "Z3_mk_seq_replace_all" ]

let contain_specs =
  missing_symbols
  |> List.map ~f:(fun sym -> [%string "--contains-any '%{sym}'"])
  |> String.concat ~sep:" \\\n  "

let run_python_binding =
  [%string
    {|python3 %{config.canary.assert_result} \
  --expected-returncode 1 \
  --contains-any 'Z3_solver_register_on_clause' \
  --contains-any 'Z3_mk_seq_replace_all' \
  -- \
  env PYTHONPATH="build/python" python3 -S -c "import z3; print(z3.__file__)"|}]

let install_local_opam_z3_dev_cmd =
  Canary_opam.install_local_cmd config.languages.opam
    ~canary_contrib_rel:config.canary.contrib_rel

type z3_project = {
  root : string;
  c_header_path : string;
  version : string;
  commit : string;
}

type build_config = { source : build_source; mode : ocaml_mode }

type stage_action =
  | Stage_install_system_deps of runner_os * string
  | Stage_configure_bindings_from_source
  | Stage_configure_bindings_with_external_z3
  | Stage_build_bindings
  | Stage_install_local_opam_z3_dev
  | Stage_run_python_binding
  | Stage_compile_example of build_config
  | Stage_run_example of build_config

type stage_definition = {
  placeholder : string;
  action : stage_action;
  expectation : stage_expectation;
}

let mk_z3_project ~root ~version ~commit =
  { root; c_header_path = root $/ "src/api"; version; commit }

let compiler_of_mode = function Bytecode -> "ocamlc" | Native -> "ocamlopt"

let build_lib_of_mode name = function
  | Bytecode -> [%string "%{name}ml.cma"]
  | Native -> [%string "%{name}ml.cmxa"]

(* example *)
let example_output_file base mode with_pkg =
  let with_pkg_s = if with_pkg then "_with_pkg" else "" in
  let mode_s = match mode with Bytecode -> ".byte" | Native -> "" in
  [%string "%{base}%{with_pkg_s}%{mode_s}"]

(* TODO: -dllpath is only useful for bytecode a.k.a ocamlc *)
let ocaml_cc_with_obj mode api_path target =
  let compiler = compiler_of_mode mode in
  let build_lib = build_lib_of_mode config.languages.ocaml.binding_lib_name mode in
  let dllpath_flag =
    match mode with
    | Bytecode -> [%string "-dllpath %{api_path}"]
    | Native -> ""
  in
  [%string
    {|eval $(opam env)
ocamlfind %{compiler} -o %{target} \
  -package zarith \
  -linkpkg \
  -I %{api_path} \
  %{dllpath_flag} \
  %{api_path}/%{build_lib} \
  %{config.languages.ocaml.example_file}
|}]

let ocaml_cc_with_pkg mode target =
  let compiler = compiler_of_mode mode in
  [%string
    {|eval $(opam env)
ocamlfind %{compiler} -o %{target} \
  -package %{config.languages.ocaml.binding_lib_name} \
  -linkpkg \
  %{config.languages.ocaml.example_file}
|}]

let export_dyld_envar on =
  if on then "export DYLD_LIBRARY_PATH=$(pwd)/build" else ""

let run_example_bytecode_cmd patch_dyld target =
  [%string
    {|eval $(opam env)
%{export_dyld_envar patch_dyld}
ocamlrun ./%{target}|}]

let run_example_native_cmd patch_dyld target =
  [%string {|%{export_dyld_envar patch_dyld}
./%{target}|}]

let run_expected_failure_cmd cmd =
  [%string
    {|python3 %{config.canary.assert_result} \
  --contains-any 'undefined symbol' \
  --contains-any 'Z3_mk_u32string' \
  -- \
  sh -ec '%{cmd}'|}]

let command_of_stage_action = function
  | Stage_install_system_deps (os, pkg) ->
      Canary_opam.install_and_prefix_cmds config.languages.opam os pkg
  | Stage_configure_bindings_from_source -> binding_buildgen
  | Stage_configure_bindings_with_external_z3 ->
      binding_buildgen_use_external config.languages.opam.prefix_envar
  | Stage_build_bindings -> binding_build
  | Stage_install_local_opam_z3_dev -> install_local_opam_z3_dev_cmd
  | Stage_run_python_binding -> run_python_binding
  | Stage_compile_example { mode; source } -> (
      let target =
        example_output_file config.languages.ocaml.example_target mode
          (Poly.( = ) source With_pkg)
      in
      match source with
      | From_build -> ocaml_cc_with_obj mode "build/src/api/ml" target
      | With_pkg -> ocaml_cc_with_pkg mode target)
  | Stage_run_example { mode; source } -> (
      let target =
        example_output_file config.languages.ocaml.example_target mode
          (Poly.( = ) source With_pkg)
      in
      match mode with
      | Bytecode ->
          run_example_bytecode_cmd (Poly.( = ) source From_build) target
      | Native -> run_example_native_cmd (Poly.( = ) source From_build) target)

let apply_expectation expectation cmd =
  match expectation with
  | Expect_success -> cmd
  | Expect_failure_contains _ -> run_expected_failure_cmd cmd
  | Expect_symbols_resolved { required_libs; provided_lib } ->
      let args =
        List.map required_libs ~f:(fun lib ->
            [%string "--required-lib \"%{lib}\""])
        @ [ [%string "--provided-lib \"%{provided_lib}\""] ]
        |> String.concat ~sep:" \\\n  "
      in
      [%string "python3 %{config.canary.assert_symbols} \\\n  %{args}"]

let stage_to_substitution stage =
  let base_cmd = command_of_stage_action stage.action in
  (stage.placeholder, apply_expectation stage.expectation base_cmd)

let canary_stage_definitions =
  [
    {
      placeholder = "configure_bindings_from_source";
      action = Stage_configure_bindings_from_source;
      expectation = Expect_success;
    };
    {
      placeholder = "build_bindings";
      action = Stage_build_bindings;
      expectation = Expect_success;
    };
    {
      placeholder = "configure_bindings_with_external_z3";
      action = Stage_configure_bindings_with_external_z3;
      expectation = Expect_success;
    };
    {
      placeholder = "run_python_binding";
      action = Stage_run_python_binding;
      expectation = Expect_success;
    };
    {
      placeholder = "install_system_deps_ubuntu";
      action = Stage_install_system_deps (Ubuntu, "z3");
      expectation = Expect_success;
    };
    {
      placeholder = "install_system_deps_macos";
      action = Stage_install_system_deps (MacOS, "z3");
      expectation = Expect_success;
    };
    {
      placeholder = "install_local_opam_z3_dev";
      action = Stage_install_local_opam_z3_dev;
      expectation = Expect_success;
    };
    {
      placeholder = compile_placeholder Bytecode From_build;
      action = Stage_compile_example { mode = Bytecode; source = From_build };
      expectation = Expect_success;
    };
    {
      placeholder = run_placeholder Bytecode From_build;
      action = Stage_run_example { mode = Bytecode; source = From_build };
      expectation = Expect_success;
    };
    {
      placeholder = compile_placeholder Native From_build;
      action = Stage_compile_example { mode = Native; source = From_build };
      expectation = Expect_success;
    };
    {
      placeholder = run_placeholder Native From_build;
      action = Stage_run_example { mode = Native; source = From_build };
      expectation = Expect_success;
    };
    {
      placeholder = compile_placeholder Bytecode With_pkg;
      action = Stage_compile_example { mode = Bytecode; source = With_pkg };
      expectation = Expect_success;
    };
    {
      placeholder = run_placeholder Bytecode With_pkg;
      action = Stage_run_example { mode = Bytecode; source = With_pkg };
      expectation = Expect_success;
    };
    {
      placeholder = compile_placeholder Native With_pkg;
      action = Stage_compile_example { mode = Native; source = With_pkg };
      expectation = Expect_success;
    };
    {
      placeholder = run_placeholder Native With_pkg;
      action = Stage_run_example { mode = Native; source = With_pkg };
      expectation = Expect_success;
    };
    {
      placeholder = run_with_pkg_expected_failure_placeholder Bytecode;
      action = Stage_run_example { mode = Bytecode; source = With_pkg };
      expectation =
        Expect_failure_contains [ "undefined symbol"; "Z3_mk_u32string" ];
    };
    {
      placeholder = run_with_pkg_expected_failure_placeholder Native;
      action = Stage_run_example { mode = Native; source = With_pkg };
      expectation =
        Expect_failure_contains [ "undefined symbol"; "Z3_mk_u32string" ];
    };
    {
      placeholder = compile_with_pkg_expected_failure_placeholder Native;
      action = Stage_compile_example { mode = Native; source = With_pkg };
      expectation =
        Expect_failure_contains [ "undefined symbol"; "Z3_mk_u32string" ];
    };
  ]

let canary_stage_substitutions =
  List.map canary_stage_definitions ~f:stage_to_substitution

let render_opam_templates bindings files =
  List.iter files ~f:(fun (src, dst) ->
      let rendered =
        List.fold bindings ~init:(read_file src) ~f:(fun acc (k, v) ->
            String.substr_replace_all acc ~pattern:k ~with_:v)
      in
      let parent = Stdlib.Filename.dirname dst in
      ignore (Stdlib.Sys.command (Fmt.str "mkdir -p %s" parent));
      write_file dst rendered)

let run_canary_pipeline () =
  Fmt.pr "------------------YAML for OCaml CI------------------@.";
  let yaml_path = config.canary.yaml_template in
  check_file_exists_exn yaml_path;
  run_cmd_exn
    (Fmt.str "rm -rf %s && mkdir -p %s && cp -a %s/. %s/" config.canary.out_root
       config.canary.out_root config.canary.root config.canary.out_root);
  Yaml_helper.replace_in_yaml_file yaml_path config.canary.yaml_generated
    canary_stage_substitutions;
  render_opam_templates
    [ ("%{BUILD_Z3_IN_OPAM}%", build_z3_in_opam) ]
    [
      (config.canary.opam_tpl_template, config.canary.opam_generated);
      (config.canary.opam_tpl_template, config.canary.opam_in_generated);
    ];
  run_cmd_exn
    (Fmt.str "find %s -type f \\( -name '*.tpl.*' -o -name 'tpl.*' \\) -delete"
       config.canary.out_root);
  run_cmd_exn
    (Fmt.str "python -c \"import yaml,sys; yaml.safe_load(open('%s'))\""
       config.canary.yaml_generated);
  run_cmd_exn
    (Fmt.str "rm -rf %s && mkdir -p %s && cp -a %s/. %s/"
       z3_dev_instance.canary_contrib_abs z3_dev_instance.canary_contrib_abs
       config.canary.out_root z3_dev_instance.canary_contrib_abs);
  check_file_exists_exn config.canary.yaml_generated;
  check_file_exists_exn config.canary.opam_generated;
  check_file_exists_exn config.canary.opam_in_generated;
  run_cmd_exn
    (Fmt.str "mkdir -p %s/workflows && cp -f %s %s" z3_dev_instance.canary_gh_abs
       config.canary.yaml_generated z3_dev_instance.canary_yaml_output)

(* 
-Werror=dev \
--warn-uninitialized \
*)
