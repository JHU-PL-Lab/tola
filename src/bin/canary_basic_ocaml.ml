open Base
open Tola_std
open Canary_basic_store
open Canary_basic

(* ── Type definitions ── *)

type ocaml_binding = {
  example_target : string;
  example_name : string;
  example_file : string;
  binding_lib_name : string;
  build_api_path : string option;
}

type opam_spec = {
  prefix_name : string;
  prefix_var : string;
  prefix_envar : string;
  libdir_name : string;
  libdir_var : string;
  local_repo_name : string;
  package_name : string;
  package_version : string;
  canary_src_var : string;
}

type prebuilt_info = {
  opam_package : string;
  system_package_linux : string;
  system_package_macos : string;
}

type ocaml_tool_config = {
  toolchain : opam_spec;
  ocaml : ocaml_binding;
  prebuilt : prebuilt_info option;
}

type ocaml_test_case = {
  probe_action : probe_action;
  mode : compile_mode;
  binding_location : location;
  expectation : step_expectation;
}

type ocaml_test_context = {
  ocaml : ocaml_binding;
  package_name : string;
  build_api_path : string option;
  target_suffix : string;
}

(* ── Functions ── *)

let compiler_of_mode = function Bytecode -> "ocamlc" | Native -> "ocamlopt"
let ext_of_mode = function Bytecode -> ".byte" | Native -> ""

let build_lib_of_mode name = function
  | Bytecode -> [%string "%{name}ml.cma"]
  | Native -> [%string "%{name}ml.cmxa"]

let example_output_file ?(suffix = "") base mode =
  [%string "%{base}%{suffix}%{ext_of_mode mode}"]

let ocaml_cc_with_obj ~binding_lib_name ~example_file mode ~api_path ~target =
  let compiler = compiler_of_mode mode in
  let build_lib = build_lib_of_mode binding_lib_name mode in
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
  %{example_file}
|}]

let ocaml_cc_with_pkg ~package ~example_file mode ~target =
  let compiler = compiler_of_mode mode in
  [%string
    {|eval $(opam env)
ocamlfind %{compiler} -o %{target} \
  -package %{package} \
  -linkpkg \
  %{example_file}
|}]

let ocaml_run_cmd target mode =
  let target_s = example_output_file target mode in
  match mode with
  | Bytecode -> [%string {|eval $(opam env)
ocamlrun ./%{target_s}|}]
  | Native -> [%string "./%{target_s}"]

let default =
  {
    prefix_name = "Z3_PREFIX";
    prefix_var = "$Z3_PREFIX";
    prefix_envar = "${Z3_PREFIX}";
    libdir_name = "Z3_LIB_DIR";
    libdir_var = "$Z3_LIB_DIR";
    local_repo_name = "local-z3-dev";
    package_name = "z3";
    package_version = "dev";
    canary_src_var = "CANARY_Z3_SRC";
  }

let pkg_full (t : opam_spec) =
  [%string "%{t.package_name}.%{t.package_version}"]

let install_and_prefix_cmds t (os : Canary_basic.runner_os) pkg =
  let install_cmd, prefix_cmd =
    match os with
    | Ubuntu ->
        ( [%string "sudo apt install -y %{pkg}"],
          [%string "pkg-config --variable=prefix %{pkg}"] )
    | MacOS ->
        ([%string "brew install %{pkg}"], [%string "brew --prefix %{pkg}"])
  in
  let libdir_cmd =
    match os with
    | Ubuntu -> [%string "pkg-config --variable=libdir %{pkg}"]
    | MacOS -> [%string "echo \"$(%{prefix_cmd})/lib\""]
  in
  [
    install_cmd;
    prefix_cmd;
    [%string "export %{t.prefix_name}=$(%{prefix_cmd})"];
    [%string "export %{t.libdir_name}=$(%{libdir_cmd})"];
    [%string "echo \"%{t.prefix_name}=%{t.prefix_var}\" >> \"$GITHUB_ENV\""];
    [%string "echo \"%{t.libdir_name}=%{t.libdir_var}\" >> \"$GITHUB_ENV\""];
    [%string "echo \"Detected %{t.prefix_name}=%{t.prefix_var}\""];
    [%string "echo \"Detected %{t.libdir_name}=%{t.libdir_var}\""];
  ]
  |> String.concat ~sep:"\n"

let install_local_cmd t ~canary_contrib_rel =
  let pkg_full = pkg_full t in
  let repo_rel = canary_contrib_rel $/ "opam-local-repo" in
  let opam_rel =
    [%string "%{repo_rel}/packages/%{t.package_name}/%{pkg_full}/opam"]
  in
  [%string
    {|eval $(opam env)
OPAMVAR_%{t.canary_src_var}="git+file://$PWD" opam config subst %{opam_rel}
opam repo add %{t.local_repo_name} "file://$PWD/%{repo_rel}" --rank=1 || opam repo set-url %{t.local_repo_name} "file://$PWD/%{repo_rel}"
opam update %{t.local_repo_name}
opam remove -y %{pkg_full} || true
opam install -y %{pkg_full} --verbose|}]

let install_opam_package_step ~name package =
  [ run_step ~name [%string {|eval $(opam env)
opam install -y %{package}|}] ]

let install_system_dep_steps ~name opam_spec pkg1 pkg2 =
  mk_system_dep_steps ~name
    ~linux_cmd:(install_and_prefix_cmds opam_spec Ubuntu pkg1)
    ~macos_cmd:(install_and_prefix_cmds opam_spec MacOS pkg2)

let verify_system_install_steps ~name ~expectation pkg1 pkg2 =
  [
    run_step ~name:[%string "%{name} (Linux)"] ~guard:(On_runner_os Ubuntu)
      ~shell:"bash" ~expectation [%string "dpkg -s %{pkg1}"];
    run_step ~name:[%string "%{name} (macOS)"] ~guard:(On_runner_os MacOS)
      ~shell:"bash" ~expectation [%string "brew list %{pkg2}"];
  ]

let verify_opam_install_step ~name ~expectation package =
  [ run_step ~name ~expectation [%string {|eval $(opam env)
opam list %{package} --short|}] ]

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

let prebuilt_info_exn (config : ocaml_tool_config) =
  match config.prebuilt with
  | Some info -> info
  | None -> failwith "Expected prebuilt OCaml binding config"

let verb_of_probe_action = function
  | Compile_example -> "Compile"
  | Run_example -> "Run"

let display_suffix_of_mode = function
  | Bytecode -> ".byte"
  | Native -> " (native)"

let command_of_test_case (ctx : ocaml_test_context) = function
  | { probe_action = Compile_example; mode; binding_location; _ } -> (
      let target =
        example_output_file ~suffix:ctx.target_suffix ctx.ocaml.example_target
          mode
      in
      match binding_location with
      | Build_tree ->
          let api_path =
            Option.value_exn ctx.build_api_path
              ~message:"build_api_path is required for Build_tree compile"
          in
          ocaml_cc_with_obj ~binding_lib_name:ctx.ocaml.binding_lib_name
            ~example_file:ctx.ocaml.example_file mode ~api_path ~target
      | _ ->
          ocaml_cc_with_pkg ~package:ctx.package_name
            ~example_file:ctx.ocaml.example_file mode ~target)
  | { probe_action = Run_example; mode; binding_location; _ } -> (
      let target =
        example_output_file ~suffix:ctx.target_suffix ctx.ocaml.example_target
          mode
      in
      let from_source = is_source_location binding_location in
      match mode with
      | Bytecode -> run_example_bytecode_cmd from_source target
      | Native -> run_example_native_cmd from_source target)

let mk_ocaml_test_steps ~(ocaml : ocaml_tool_config) ~binding_location
    ?(test_expectation = Expect_success) () =
  let example_name = ocaml.ocaml.example_name in
  let from_source = is_source_location binding_location in
  let variant_suffix =
    if from_source then "" else "_with_pkg"
  in
  let package_name =
    match ocaml.prebuilt with
    | None -> ocaml.ocaml.binding_lib_name
    | Some info -> info.opam_package
  in
  let ctx =
    {
      ocaml = ocaml.ocaml;
      package_name;
      build_api_path = ocaml.ocaml.build_api_path;
      target_suffix = variant_suffix;
    }
  in
  List.map all_cc_and_modes ~f:(fun (mode, probe_action) ->
      let exp =
        match (probe_action, mode) with
        | Compile_example, Bytecode -> Expect_success
        | _ -> test_expectation
      in
      let verb = verb_of_probe_action probe_action in
      let suffix = display_suffix_of_mode mode in
      let name =
        [%string "%{verb} %{example_name}%{variant_suffix}%{suffix}"]
      in
      let tc = { probe_action; mode; binding_location; expectation = exp } in
      run_step ~name ~expectation:exp (command_of_test_case ctx tc))
