open Base
open Tola_std
open Canary_basic

type ocaml_mode = Native | Bytecode

type ocaml_binding = {
  example_target : string;
  example_file : string;
  binding_lib_name : string;
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

type language_config = { opam : opam_spec; ocaml : ocaml_binding }

type prebuilt_ocaml_binding = {
  toolchain : opam_spec;
  opam_package : string;
  system_package_linux : string;
  system_package_macos : string;
  example_file : string;
  example_target : string;
  binding_lib_name : string;
}

type ocaml_tool_config =
  | Source_binding of language_config
  | Prebuilt_binding of prebuilt_ocaml_binding

type project_config = {
  canary : canary_paths;
  workflow_name : string;
  project : project_spec;
  ocaml : ocaml_tool_config;
  capabilities : project_capabilities;
  job_specs : job_spec list;
}

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

let pkg_full t = [%string "%{t.package_name}.%{t.package_version}"]

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
    [%string "echo \"%{t.prefix_name}=$(%{prefix_cmd})\" >> \"$GITHUB_ENV\""];
    [%string "echo \"%{t.libdir_name}=$(%{libdir_cmd})\" >> \"$GITHUB_ENV\""];
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

let install_opam_package_stage ?(name = "Install OCaml package") package =
  [ run_stage ~name [%string {|eval $(opam env)
opam install -y %{package}|}] ]

let install_system_dep_stages opam_spec pkg1 pkg2 =
  mk_system_dep_stages
    ~linux_cmd:(install_and_prefix_cmds opam_spec Ubuntu pkg1)
    ~macos_cmd:(install_and_prefix_cmds opam_spec MacOS pkg2)

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

type ocaml_step_desc = {
  code_step : code_step;
  mode : ocaml_mode;
  source : build_source;
  display_verb : string;
  display_suffix : string;
  expectation : stage_expectation;
}

type ocaml_step_resolved = {
  name : string;
  expectation : stage_expectation;
  requires : stage_artifact list;
  produces : stage_artifact list;
  step : ocaml_step_desc;
  command : string;
}

type context = {
  example_file : string;
  example_target : string;
  package_name : string;
  binding_lib_name : string;
  build_api_path : string option;
  target_suffix_of_source : build_source -> string;
}

let no_target_suffix _ = ""

let suffix_of_source ?(with_pkg_suffix = "_with_pkg") = function
  | From_build -> ""
  | With_pkg -> with_pkg_suffix

let mk_context ~example_file ~example_target ~package_name ~binding_lib_name
    ?build_api_path ?(target_suffix_of_source = no_target_suffix) () =
  {
    example_file;
    example_target;
    package_name;
    binding_lib_name;
    build_api_path;
    target_suffix_of_source;
  }

let context_of_language_config ?build_api_path ?target_suffix_of_source
    (config : language_config) =
  mk_context ~example_file:config.ocaml.example_file
    ~example_target:config.ocaml.example_target
    ~package_name:config.ocaml.binding_lib_name
    ~binding_lib_name:config.ocaml.binding_lib_name ?build_api_path
    ?target_suffix_of_source ()

let context_of_prebuilt_ocaml_binding ?build_api_path ?target_suffix_of_source
    (binding : prebuilt_ocaml_binding) =
  mk_context ~example_file:binding.example_file
    ~example_target:binding.example_target ~package_name:binding.opam_package
    ~binding_lib_name:binding.binding_lib_name ?build_api_path
    ?target_suffix_of_source ()

let context_of_ocaml_tool_config ?build_api_path ?target_suffix_of_source =
  function
  | Source_binding config ->
      context_of_language_config config ?build_api_path ?target_suffix_of_source
  | Prebuilt_binding binding ->
      context_of_prebuilt_ocaml_binding binding ?build_api_path
        ?target_suffix_of_source

let toolchain_of_ocaml_tool_config = function
  | Source_binding config -> config.opam
  | Prebuilt_binding binding -> binding.toolchain

let prebuilt_binding_exn = function
  | Prebuilt_binding binding -> binding
  | Source_binding _ -> failwith "Expected prebuilt OCaml binding config"

let default_ocaml_step_descs ~source =
  [
    {
      code_step = Compile;
      mode = Bytecode;
      source;
      display_verb = "Compile";
      display_suffix = ".byte";
      expectation = Expect_success;
    };
    {
      code_step = Run;
      mode = Bytecode;
      source;
      display_verb = "Run";
      display_suffix = ".byte";
      expectation = Expect_success;
    };
    {
      code_step = Compile;
      mode = Native;
      source;
      display_verb = "Compile";
      display_suffix = " (native)";
      expectation = Expect_success;
    };
    {
      code_step = Run;
      mode = Native;
      source;
      display_verb = "Run";
      display_suffix = " (native)";
      expectation = Expect_success;
    };
  ]

let example_name_of_case ~example_name ~variant_suffix (step : ocaml_step_desc) =
  [%string
    "%{step.display_verb} \
     %{example_name}%{variant_suffix}%{step.display_suffix}"]

let example_output_artifact (ctx : context) (step : ocaml_step_desc) =
  let suffix = ctx.target_suffix_of_source step.source in
  Artifact_file (example_output_file ~suffix ctx.example_target step.mode)

let compile_requires (ctx : context) (step : ocaml_step_desc) =
  let source_file = Artifact_file ctx.example_file in
  match step.source with
  | From_build ->
      let api_path =
        Option.value_exn ctx.build_api_path
          ~message:"build_api_path is required for From_build compile"
      in
      [
        source_file;
        Artifact_dir api_path;
        Artifact_file
          [%string
            "%{api_path}/%{build_lib_of_mode ctx.binding_lib_name step.mode}"];
      ]
  | With_pkg -> [ source_file; Artifact_package ctx.package_name ]

let requires_of_step (ctx : context) (step : ocaml_step_desc) =
  match step.code_step with
  | Compile -> compile_requires ctx step
  | Run -> [ example_output_artifact ctx step ]

let produces_of_step (ctx : context) (step : ocaml_step_desc) =
  match step.code_step with
  | Compile -> [ example_output_artifact ctx step ]
  | Run -> []

let command_of_step (ctx : context) = function
  | { code_step = Compile; mode; source; _ } -> (
      let suffix = ctx.target_suffix_of_source source in
      let target = example_output_file ~suffix ctx.example_target mode in
      match source with
      | From_build ->
          let api_path =
            Option.value_exn ctx.build_api_path
              ~message:"build_api_path is required for From_build compile"
          in
          ocaml_cc_with_obj ~binding_lib_name:ctx.binding_lib_name
            ~example_file:ctx.example_file mode ~api_path ~target
      | With_pkg ->
          ocaml_cc_with_pkg ~package:ctx.package_name
            ~example_file:ctx.example_file mode ~target)
  | { code_step = Run; mode; source; _ } -> (
      let suffix = ctx.target_suffix_of_source source in
      let target = example_output_file ~suffix ctx.example_target mode in
      match mode with
      | Bytecode ->
          run_example_bytecode_cmd (Poly.( = ) source From_build) target
      | Native -> run_example_native_cmd (Poly.( = ) source From_build) target)

let ocaml_step_resolved_of_spec ~(context : context)
    ~(name_of_case : ocaml_step_desc -> string) (step : ocaml_step_desc) =
  let name = name_of_case step in
  {
    name;
    expectation = step.expectation;
    requires = requires_of_step context step;
    produces = produces_of_step context step;
    step;
    command = command_of_step context step;
  }

let mk_stages ~(context : context) ~(name_of_case : ocaml_step_desc -> string)
    ~ocaml_step_descs () =
  List.map ocaml_step_descs ~f:(fun ocaml_step_desc ->
      let step = ocaml_step_resolved_of_spec ~context ~name_of_case ocaml_step_desc in
      run_stage ~name:step.name ~requires:step.requires ~produces:step.produces
        ~expectation:step.expectation step.command)

let prebuilt_setup_stages (binding : prebuilt_ocaml_binding) =
  install_system_dep_stages binding.toolchain binding.system_package_linux
    binding.system_package_macos
  @ install_opam_package_stage binding.opam_package

let job_of_spec ~(spec : job_spec) ~steps =
  {
    id = spec.id;
    if_disabled = spec.if_disabled;
    name = name_of_job_spec spec;
    runs_on = "${{ matrix.os }}";
    preamble = checkout_and_setup_preamble;
    steps;
  }

let mk_ocaml_test_stages ~(config : project_config) ~(spec : job_spec)
    ?ocaml_step_descs () =
  let example_name =
    Option.value_exn spec.example_name
      ~message:"job_spec.example_name is required for mk_ocaml_test_stages"
  in
  let source = build_source_of_location spec.binding_location in
  let variant_suffix =
    match source with From_build -> "" | With_pkg -> "_with_pkg"
  in
  let context =
    context_of_ocaml_tool_config config.ocaml ?build_api_path:spec.build_api_path
      ~target_suffix_of_source:(suffix_of_source ~with_pkg_suffix:variant_suffix)
  in
  let name_of_case = example_name_of_case ~example_name ~variant_suffix in
  let ocaml_step_descs =
    match ocaml_step_descs with
    | Some descs -> descs
    | None -> default_ocaml_step_descs ~source
  in
  mk_stages ~context ~name_of_case ~ocaml_step_descs ()
