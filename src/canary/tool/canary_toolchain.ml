open Base
open Tola_std
open Canary_store
open Canary_basic
open Canary_artifact_api

(* ── Type definitions ── *)

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
  system_package : system_package_spec;
  opam_package_spec : opam_package_spec;
}

and opam_package_spec = {
  install_name : string;
  version_tag : string option;
  switch_behavior : store_behavior;
  switch_name : string option;
  install_args : string list;
}

type ocaml_tool_config = {
  toolchain : opam_spec;
  ocaml : ocaml_binding;
  prebuilt : prebuilt_info option;
}

type binding_config =
  | Ocaml_config of ocaml_tool_config
  | Python_config of python_binding

type python_toolchain = {
  interpreter : string;
  pip_entries : (string * string) list;
  (* (check_cmd, install_prefix) pairs — generate if/elif fallback chain *)
}

let default_python_toolchain =
  {
    interpreter = "python3";
    pip_entries =
      [
        ("command -v pip >/dev/null 2>&1", "pip");
        ("python3 -m pip --version >/dev/null 2>&1", "python3 -m pip");
        ("command -v uv >/dev/null 2>&1", "uv pip");
      ];
  }

type ocaml_test_case = {
  probe_action : probe_action;
  mode : compile_mode;
  binding_location : location;
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

let pkg_full (t : opam_spec) =
  [%string "%{t.package_name}.%{t.package_version}"]

let mk_opam_package_spec ?version_tag ?switch_name
    ?(switch_behavior = Isolated_store "switch") ?(install_args = [])
    ~install_name () =
  { install_name; version_tag; switch_behavior; switch_name; install_args }

let opam_env_prefix (spec : opam_package_spec) =
  match spec.switch_name with
  | None -> "eval $(opam env)"
  | Some switch -> [%string "eval $(opam env --switch=%{switch})"]

let opam_install_cmd (spec : opam_package_spec) =
  let extra_args =
    if List.is_empty spec.install_args then ""
    else " " ^ String.concat ~sep:" " spec.install_args
  in
  [%string
    "%{opam_env_prefix spec} && opam install %{spec.install_name} -y%{extra_args}"]

let mk_prebuilt_info ?version_tag ?locator_hint
    ?(system_behavior = Stateful_global) ?(switch_behavior = Isolated_store "switch")
    ?switch_name ?opam_install_name ?(install_args = [ "--assume-depexts" ])
    ~opam_package ~system_package_linux ~system_package_macos () =
  let install_name = Option.value opam_install_name ~default:opam_package in
  {
    opam_package;
    system_package_linux;
    system_package_macos;
    system_package =
      mk_system_package_spec ?version_tag ?locator_hint
        ~behavior:system_behavior ~linux_pkg:system_package_linux
        ~macos_pkg:system_package_macos ();
    opam_package_spec =
      mk_opam_package_spec ?version_tag ?switch_name ~switch_behavior
        ~install_args ~install_name ();
  }

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
opam repo remove %{t.local_repo_name} 2>/dev/null || true
opam repo add %{t.local_repo_name} "file://$PWD/%{repo_rel}" --rank=1
opam update %{t.local_repo_name}
opam remove -y %{pkg_full} || true
opam install -y %{pkg_full} --verbose|}]

(* Shared opam pack_binding shell sequence used by project pack_binding closures.
   ~preamble:    shell lines after `eval $(opam env)`, before repo add — typically
                 mkdir+cp+opam-config-subst for template-based packages (e.g. z3).
   ~pre_install: shell lines between `opam update` and `opam remove` — typically
                 a conf-* dep install (e.g. conf-llvm-shared.dev for llvm).
   ~env_prefix:  space-terminated env-var assignments prepended to opam install
                 (e.g. "CANARY_BUILD_DIR=\"...\" "); use "" when not needed. *)
let opam_pack_cmd ~repo_name ~repo_abs ~pkg_full ?(preamble = "")
    ?(pre_install = "") ~env_prefix ~output_dir ~variant_key () =
  let pack_ok = Canary_output_path.variant_file ~variant_key "pack.ok" in
  let maybe s = if String.is_empty s then "" else s ^ "\n" in
  [%string
    {|eval $(opam env)
%{maybe preamble}printf 'opam-version: "2.0"\n' > "%{repo_abs}/repo"
opam repo remove %{repo_name} 2>/dev/null || true
opam repo add %{repo_name} "file://%{repo_abs}" --rank=1
opam update %{repo_name}
%{maybe pre_install}opam remove -y %{pkg_full} || true
%{env_prefix}opam install -y %{pkg_full} --verbose --keep-build-dir --assume-depexts \
  && echo 'ok' > %{output_dir}/%{pack_ok}|}]

let install_opam_package_step ~name package =
  let spec = mk_opam_package_spec ~install_name:package () in
  [ run_step ~name (opam_install_cmd spec) ]

let install_opam_package_spec_step ~name spec =
  [ run_step ~name (opam_install_cmd spec) ]

let install_system_dep_steps ~name opam_spec pkg1 pkg2 =
  mk_system_dep_steps ~name
    ~linux_cmd:(install_and_prefix_cmds opam_spec Ubuntu pkg1)
    ~macos_cmd:(install_and_prefix_cmds opam_spec MacOS pkg2)

let install_system_package_steps ~name opam_spec (spec : system_package_spec) =
  install_system_dep_steps ~name opam_spec spec.linux_pkg spec.macos_pkg

let verify_system_install_steps ~name pkg1 pkg2 =
  [
    run_step ~name:[%string "%{name} (Linux)"] ~guard:(On_runner_os Ubuntu)
      ~shell:"bash"
      (Canary_pm.verify_system_install_cmd Apt
         (mk_system_package_spec ~linux_pkg:pkg1 ~macos_pkg:pkg2 ()));
    run_step ~name:[%string "%{name} (macOS)"] ~guard:(On_runner_os MacOS)
      ~shell:"bash"
      (Canary_pm.verify_system_install_cmd Brew
         (mk_system_package_spec ~linux_pkg:pkg1 ~macos_pkg:pkg2 ()));
  ]

let verify_system_package_steps ~name (spec : system_package_spec) =
  [
    run_step ~name:[%string "%{name} (Linux)"] ~guard:(On_runner_os Ubuntu)
      ~shell:"bash"
      (Canary_pm.verify_system_install_cmd Apt spec);
    run_step ~name:[%string "%{name} (macOS)"] ~guard:(On_runner_os MacOS)
      ~shell:"bash"
      (Canary_pm.verify_system_install_cmd Brew spec);
  ]

let verify_opam_install_step ~name package =
  let spec = mk_opam_package_spec ~install_name:package () in
  [ run_step ~name
      [%string "%{opam_env_prefix spec} && opam list %{spec.install_name} --short"] ]

let verify_opam_install_spec_step ~name spec =
  [ run_step ~name
      [%string "%{opam_env_prefix spec} && opam list %{spec.install_name} --short"] ]

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

(* Pip install only — runs at Fetch (Binding Python) time so the summary
   step can attach a child that reads the just-installed package. Writes
   binding.ok marker on success (canary's standard fetch postcondition).
   When pip_package is None the binding is stdlib — no install needed. *)
let pip_install_cmd ?(toolchain = default_python_toolchain) (p : python_binding)
    ~output_dir ~variant_key =
  let binding_ok = Canary_output_path.variant_file ~variant_key "binding.ok" in
  let install_log = Canary_output_path.variant_file ~variant_key "install.log" in
  match p.pip_package with
  | None ->
      (* Stdlib (or pre-installed): just create the marker. *)
      [%string {|echo 'stdlib' > %{output_dir}/%{binding_ok}|}]
  | Some pkg ->
      let make_branch i (check, prefix) =
        let kw = if i = 0 then "if" else "elif" in
        kw ^ " " ^ check ^ "; then\n  " ^ prefix ^ " install --quiet " ^ pkg
        ^ " > \"$INSTALL_LOG\" 2>&1"
      in
      let branches = List.mapi toolchain.pip_entries ~f:make_branch in
      let names =
        String.concat ~sep:" / " (List.map toolchain.pip_entries ~f:snd)
      in
      [%string
        {|set -e
INSTALL_LOG=%{output_dir}/%{install_log}
%{String.concat ~sep:"\n" branches}
else
  echo "no %{names} available" > "$INSTALL_LOG"
  exit 1
fi
echo 'installed' > %{output_dir}/%{binding_ok}|}]

(* Probe only — runs at Probe (Binding Python) time, assuming pip install
   has already happened in the Fetch (Binding Python) step. *)
let python_probe_only_cmd ?(toolchain = default_python_toolchain)
    (p : python_binding) ~output_dir ~variant_key =
  let probe_log = Canary_output_path.variant_file ~variant_key "probe.log" in
  [%string
    {|set -e
%{toolchain.interpreter} -c "%{p.probe_snippet}" > %{output_dir}/%{probe_log} 2>&1 || { cat %{output_dir}/%{probe_log}; exit 1; }
cat %{output_dir}/%{probe_log}|}]

(* Backward-compatible single-step variant: install + probe in one go.
   Kept so projects that haven't migrated to the split form still work
   (and so canary_pattern_a / older specs compile). New code should
   prefer pip_install_cmd + python_probe_only_cmd. *)
let pip_probe_cmd ?(toolchain = default_python_toolchain) (p : python_binding)
    ~output_dir ~variant_key =
  let install = pip_install_cmd ~toolchain p ~output_dir ~variant_key in
  let probe = python_probe_only_cmd ~toolchain p ~output_dir ~variant_key in
  [%string {|%{install}
%{probe}|}]

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

let mk_ocaml_test_steps ~(ocaml : ocaml_tool_config) ~binding_location () =
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
      let verb = verb_of_probe_action probe_action in
      let suffix = display_suffix_of_mode mode in
      let name =
        [%string "%{verb} %{example_name}%{variant_suffix}%{suffix}"]
      in
      let tc = { probe_action; mode; binding_location } in
      run_step ~name (command_of_test_case ctx tc))


(* Generic build-tool primitives (mark_step_complete, with_marker,
   cmake_configure_cmd, cmake_build_cmd, ninja_build_cmd, dune_build_cmd)
   moved to tool/canary_build_cmd.ml on 2026-06-01 — they don't share
   concerns with opam/cc/python toolchain types. *)
