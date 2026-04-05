open Canary_basic
open Canary_basic_ocaml
open Canary

let llvm_ocaml_config : ocaml_tool_config =
  {
    toolchain =
      {
        prefix_name = "LLVM_PREFIX";
        prefix_var = "$LLVM_PREFIX";
        prefix_envar = "${LLVM_PREFIX}";
        libdir_name = "LLVM_LIB_DIR";
        libdir_var = "$LLVM_LIB_DIR";
        local_repo_name = "local-llvm";
        package_name = "llvm";
        package_version = "system";
        canary_src_var = "CANARY_LLVM_SRC";
      };
    ocaml =
      {
        example_file = "canary/examples/llvm/llvm_example.ml";  (* renamed from llvm_canary.ml *)
        example_target = "llvm_example";
        example_name = "llvm example";
        binding_lib_name = "llvm";
        build_api_path = None;
      };
    prebuilt =
      Some
        (mk_prebuilt_info ~version_tag:"19" ~locator_hint:"llvm-config-19"
           ~opam_package:"llvm" ~opam_install_name:"llvm.19-static"
           ~system_package_linux:"llvm-19-dev" ~system_package_macos:"llvm@19"
           ());
  }

let prebuilt_prebuilt_spec distro : job_spec =
  {
    distro;
    id = "prebuilt-prebuilt";
    description =
      "Install system LLVM, install opam llvm binding and llvmlite, probe";
    phases =
      [
        {
          kind =
            Pm_install
              (Some
                 {
                   linux_pkg =
                     (prebuilt_info_exn llvm_ocaml_config).system_package_linux;
                   macos_pkg =
                     (prebuilt_info_exn llvm_ocaml_config).system_package_macos;
                 });
          location = System_pm;
          requires = [];
          produces = [ { kind = Lib; name = "llvm"; location = System_pm } ];
          expectation = Expect_success;
        };
        {
          kind = Pm_install None;
          location = Lang_pm;
          requires = [ { kind = Lib; name = "llvm"; location = System_pm } ];
          produces = [ { kind = Binding; name = "llvm"; location = Lang_pm } ];
          expectation = Expect_success;
        };
        {
          kind =
            Run_command
              {
                name = "Install llvmlite";
                command = "python3 -m pip install llvmlite";
              };
          location = Lang_pm;
          requires = [ { kind = Lib; name = "llvm"; location = System_pm } ];
          produces = [ { kind = App; name = "llvmlite"; location = Lang_pm } ];
          expectation = Expect_success;
        };
        {
          kind = Probe_test { lang = OCaml };
          location = Lang_pm;
          requires = [ { kind = Binding; name = "llvm"; location = Lang_pm } ];
          produces = [];
          expectation = Expect_success;
        };
        {
          kind = Probe_test { lang = Python };
          location = Lang_pm;
          requires = [ { kind = App; name = "llvmlite"; location = Lang_pm } ];
          produces = [];
          expectation = Expect_success;
        };
      ];
    if_disabled = false;
  }

let config distro =
  {
    canary = Canary_basic.mk_canary_config ();
    workflow_name = "Canary Testing for LLVM OCaml and Python";
    name = "llvm";
    project =
      {
        root = "";
        version = "system";
        commit = "";
        bindings = [ (OCaml, Opam); (Python, Unsupported) ];
        system_pm = Brew;
        has_source = false;
        has_system_pkg = true;
        has_lang_pkg = true;
        can_package = false;
      };
    ocaml = llvm_ocaml_config;
    job_specs = [ prebuilt_prebuilt_spec distro ];
    deploy = None;
    opam_template_bindings = [];
  }

let prebuilt = prebuilt_info_exn llvm_ocaml_config

let llvm_locator_hint =
  Option.value prebuilt.system_package.locator_hint ~default:"llvm-config"

let find_llvm_config_cmd =
  [%string
    "if command -v %{llvm_locator_hint} >/dev/null 2>&1; then command -v \
     %{llvm_locator_hint}; elif command -v llvm-config >/dev/null 2>&1; then \
     command -v llvm-config; elif command -v brew >/dev/null 2>&1; then printf \
     '%s\\n' \"$(brew --prefix \
     %{prebuilt.system_package.macos_pkg})/bin/%{llvm_locator_hint}\"; else \
     printf '%s\\n' %{llvm_locator_hint}; fi"]

let llvm_ocaml_probe ~output_dir ~binding_lib ~target =
  let example = llvm_ocaml_config.ocaml.example_file in
  [%string
    {|LLVM_CONFIG=$(%{find_llvm_config_cmd})
test -x "$LLVM_CONFIG"
eval $(opam env)
LLVM_CONFIG="$LLVM_CONFIG" ocamlfind ocamlopt -package %{binding_lib} -linkpkg %{example} -o %{output_dir}/%{target}
%{output_dir}/%{target} 2>&1 | tee %{output_dir}/probe.log|}]

let llvm_python_probe ~output_dir =
  [%string
    {|python3 -c "import llvmlite.binding as llvm; print(llvm.llvm_version_info)" 2>&1 | tee %{output_dir}/probe.log|}]

let script_spec : Canary_action.script_spec =
  let pm = Canary_basic_store.detect_pm () in
  let binding_lib = llvm_ocaml_config.ocaml.binding_lib_name in
  let target = llvm_ocaml_config.ocaml.example_target in
  {
    Canary_action.empty_script_spec with
    fetch_lib = Some (Canary_action.fetch_lib_cmd pm prebuilt.system_package);
    fetch_binding =
      Some (Canary_action.fetch_binding_cmd prebuilt.opam_package_spec);
    fetch_app =
      Some
        (fun ~output_dir ->
          [%string
            "(uv pip install llvmlite || pip install llvmlite || python3 -m \
             pip install llvmlite) && echo 'installed' > %{output_dir}/app.ok"]);
    probe_lib =
      Some
        (fun ~output_dir ->
          [%string
            {|LLVM_CONFIG=$(%{find_llvm_config_cmd}) && test -x "$LLVM_CONFIG" && "$LLVM_CONFIG" --version 2>&1 | tee %{output_dir}/probe.log|}]);
    probe_binding =
      Some
        (fun ~output_dir ->
          let script = "canary/scripts/assert_binary_symbols.py" in
          let example = llvm_ocaml_config.ocaml.example_file in
          (* Single integrated script: LLVM_CONFIG set once, shared across all steps.
             find_llvm_config_cmd is a multi-line if/elif expression — can't be
             safely nested inside $() inside a subcommand arg, so we set it up front. *)
          [%string
            {|eval $(opam env)
LLVM_CONFIG=$(%{find_llvm_config_cmd})
test -x "$LLVM_CONFIG"
PKG_DIR=$(ocamlfind query '%{binding_lib}' 2>/dev/null)
test -n "$PKG_DIR"
STUB=$(ls "$PKG_DIR"/lib*.a 2>/dev/null | head -1)
test -n "$STUB"
PROVIDED=$(ls "$("$LLVM_CONFIG" --libdir)"/libLLVM*.so 2>/dev/null | head -1)
test -n "$PROVIDED"
for f in "$PKG_DIR"/*.cmxa "$PKG_DIR"/*.cma; do
  [ -f "$f" ] && printf '\n=== %s ===\n' "$f" && ocamlobjinfo "$f"
done 2>&1 | tee %{output_dir}/archive.log
python3 %{script} --provided-lib "$PROVIDED" --required-lib "$STUB" \
  --symbol-prefix LLVM 2>&1 | tee %{output_dir}/symbols.log
grep -q 'OK:' %{output_dir}/symbols.log
LLVM_CONFIG="$LLVM_CONFIG" ocamlfind ocamlopt -package %{binding_lib} -linkpkg %{example} \
  -o %{output_dir}/%{target}
%{output_dir}/%{target} 2>&1 | tee %{output_dir}/probe.log|}]);
    probe_app = Some llvm_python_probe;
  }

let action_steps ~root ~project =
  Canary_action.derive_steps ~root ~project script_spec

let run_info steps =
  let ver =
    Option.value prebuilt.system_package.version_tag ~default:"system"
  in
  Canary_action.mk_run_info ~project:"llvm" ~version:ver ~ref_:""
    ~source:"prebuilt"
    ~extra:
      [
        ("system_package", prebuilt.system_package_linux);
        ("opam_package", prebuilt.opam_package);
      ]
    steps
