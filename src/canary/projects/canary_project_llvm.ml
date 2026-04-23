open Base
open Canary_basic
open Canary_store
open Canary_artifact_source
open Canary_toolchain_ocaml
open Canary

(* ── Version specs ──
   LLVM versions map to system PM packages (llvm-N-dev) and opam
   packages (llvm.N-static). Unlike z3, LLVM lib is almost always
   prebuilt (building LLVM from source is expensive).

   | Version | Source                   | PM lib? | build_lib | build_binding |
   |---------|--------------------------|---------|-----------|---------------|
   | dev     | arbipher/llvm-project    | no      | false*    | true          |
   | 19      | llvm/llvm-project tag    | yes     | false     | true          |
   | latest  | llvm/llvm-project HEAD   | no      | false*    | true          |

   *build_lib=false for dev/latest because LLVM lib build is very
   expensive; the common use case is building only the OCaml binding
   against a prebuilt system lib. Set has_build_lib=true to also
   build libLLVM from source. *)

(* Module-level watchlist for the LLVM opam binding. *)
let llvm_ocaml_watchlist = [ "Llvm"; "Llvm_target"; "Llvm_executionengine" ]

(* Native symbol watchlist for libLLVM.so. *)
let llvm_native_watchlist = [
  "LLVMContextCreate";
  "LLVMModuleCreateWithName";
  "LLVMCreateBuilder";
]

let llvm_source_dev : source_repo =
  {
    name = "llvm";
    remote = Git_remote "https://github.com/arbipher/llvm-project.git";
    locals =
      [
        { distro = Wsl;
          path = "/home/red/code/contrib/llvm-all/llvm-project";
          build_path = "/home/red/code/contrib/llvm-all/build" };
      ];
    version = "dev";
    ref_ = "HEAD";
    official = false;
    has_build_lib = true;
    has_build_binding = true;
    build_sys_deps = [ "cmake"; "ninja-build" ];
  }

let llvm_source_stable : source_repo =
  {
    name = "llvm";
    remote = Git_remote "https://github.com/llvm/llvm-project.git";
    (* Reuse the same local checkout as dev — fetch_source is a no-op (test -d).
       We don't build from it (has_build_lib=false, has_build_binding=false). *)
    locals =
      [
        { distro = Wsl;
          path = "/home/red/code/contrib/llvm-all/llvm-project";
          build_path = "/home/red/code/contrib/llvm-all/build" };
      ];
    version = "19";
    ref_ = "llvmorg-19.1.7";
    official = true;
    has_build_lib = false;
    (* No local build tree for stable — skip ninja, use fetch_binding (llvm.19-shared).
       probe_binding_pkg will compile llvm_example_dev.ml against the 19 binding
       and fail, demonstrating the version mismatch. *)
    has_build_binding = false;
    build_sys_deps = [];
  }

let llvm_source_latest : source_repo =
  {
    name = "llvm";
    remote = Git_remote "https://github.com/llvm/llvm-project.git";
    locals = [];
    version = "latest";
    ref_ = "HEAD";
    official = true;
    has_build_lib = false;
    has_build_binding = true;
    build_sys_deps = [ "cmake"; "ninja-build" ];
  }

let llvm_sources = [ llvm_source_dev; llvm_source_stable; llvm_source_latest ]

(* Opam package names used in pack_binding and check_post *)
let llvm_dev_opam_pkg = "llvm.dev-shared"

(* cmake source dir: the llvm/ subdir of the monorepo *)
let cmake_source_of_root root = root ^ "/llvm"

let llvm_ocaml_config : ocaml_tool_config =
  {
    toolchain =
      {
        prefix_name = "LLVM_PREFIX";
        prefix_var = "$LLVM_PREFIX";
        prefix_envar = "${LLVM_PREFIX}";
        libdir_name = "LLVM_LIB_DIR";
        libdir_var = "$LLVM_LIB_DIR";
        local_repo_name = "canary-local";
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
           ~opam_package:"llvm" ~opam_install_name:"llvm.19-shared"
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

        };
        {
          kind = Pm_install None;
          location = Lang_pm;
          requires = [ { kind = Lib; name = "llvm"; location = System_pm } ];
          produces = [ { kind = Binding; name = "llvm"; location = Lang_pm } ];

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

        };
        {
          kind = Probe_test { lang = OCaml };
          location = Lang_pm;
          requires = [ { kind = Binding; name = "llvm"; location = Lang_pm } ];
          produces = [];

        };
        {
          kind = Probe_test { lang = Python };
          location = Lang_pm;
          requires = [ { kind = App; name = "llvmlite"; location = Lang_pm } ];
          produces = [];

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

let llvm_python_probe ~output_dir =
  [%string
    {|python3 -m pip install --quiet llvmlite
python3 -c "import llvmlite.binding as llvm; print(llvm.llvm_version_info)" > %{output_dir}/probe.log 2>&1|}]

(* ── Source build script spec (build LLVM + OCaml bindings from source) ── *)

(* cmake flags for LLVM.
   LLVM_ENABLE_BINDINGS=ON is the default and enables OCaml bindings
   when ocamlfind + ctypes are available. The cmake source dir is
   llvm-project/llvm (not the monorepo root).

   Key differences from z3:
   - cmake source is a subdir: -S <root>/llvm -B <build>
   - Build dir is a sibling of the source tree, not inside it
   - Binding build is part of the main build (no separate target)
   - lib output: <build>/lib/libLLVM*.so
   - binding output: <build>/lib/ocaml/llvm.cmxa *)

let cmake_configure_cmd ~source_root ~build_dir =
  let cmake_source = cmake_source_of_root source_root in
  (* Speed flags:
     - mold: 5-10x faster linking than ld (available on this machine)
     - LLVM_OPTIMIZED_TABLEGEN: builds tablegen in Release even in Debug builds
     - ccache: compiler cache; no-op if not installed (CMAKE_*_COMPILER_LAUNCHER
       falls back gracefully when the binary is absent)
     - LLVM_PARALLEL_LINK_JOBS: limit concurrent linkers to avoid OOM;
       each LLVM link can use 4-8 GB — set to (RAM_GB / 8) conservatively *)
  [%string
    {|eval $(opam env) && cmake \
  -S %{cmake_source} -B %{build_dir} -G Ninja \
  -DCMAKE_C_COMPILER=clang-23 \
  -DCMAKE_CXX_COMPILER=clang++-23 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER_LAUNCHER=sccache \
  -DCMAKE_CXX_COMPILER_LAUNCHER=sccache \
  -DLLVM_USE_LINKER=mold \
  -DLLVM_OPTIMIZED_TABLEGEN=ON \
  -DLLVM_PARALLEL_LINK_JOBS=8 \
  -DLLVM_ENABLE_BINDINGS=ON \
  -DLLVM_BUILD_LLVM_DYLIB=ON \
  -DLLVM_LINK_LLVM_DYLIB=ON \
  -DLLVM_TARGETS_TO_BUILD="X86" \
  -DLLVM_ENABLE_PROJECTS="" \
  -DLLVM_ENABLE_RUNTIMES="" \
  -DLLVM_BUILD_TOOLS=OFF \
  -DLLVM_BUILD_EXAMPLES=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_BUILD_RUNTIME=OFF \
  -DLLVM_ENABLE_ASSERTIONS=OFF|}]

let mk_script_spec ~source ?(tola_root = Unix.getcwd ()) distro : Canary_action.script_spec =
  let local = local_for distro source in
  let root =
    match local with
    | Some l -> l.path
    | None ->
        [%string "_out/canary/projects/llvm/%{source.version}_%{source.ref_}/src"]
  in
  let build =
    match local with
    | Some l -> l.build_path
    | None ->
        [%string "_out/canary/projects/llvm/%{source.version}_%{source.ref_}/build"]
  in
  let pm = Canary_store.detect_pm () in
  let target = llvm_ocaml_config.ocaml.example_target in
  (* llvm_example_dev.ml uses Opcode.UncondBr (LLVM 21+); it will fail to
     compile against LLVM 19 binding, which is the mismatch we want to detect. *)
  let example =
    tola_root ^ "/canary/examples/llvm/llvm_example_dev.ml"
  in
  let llvm_config = [%string "%{build}/bin/llvm-config"] in
  let binding_lib = llvm_ocaml_config.ocaml.binding_lib_name in
  {
    Canary_action.empty_script_spec with
    fetch_source =
      Some
        (fun ~output_dir ->
          Canary_artifact_source.source_fetch_cmd distro source ~output_dir);
    configure =
      (if source.has_build_lib || source.has_build_binding then
         Some
           (fun ~output_dir ->
             [%string
               "%{cmake_configure_cmd ~source_root:root ~build_dir:build} \
                && echo 'ok' > %{output_dir}/conf.ok"])
       else None);
    build_lib =
      (if source.has_build_lib then
         Some
           (fun ~output_dir ->
             [%string
               "ninja -C %{build} LLVM && echo 'ok' > %{output_dir}/build.ok"])
       else None);
    build_binding =
      (if source.has_build_binding then
         Some
           (fun ~output_dir ->
             [%string
               "eval $(opam env) && ninja -C %{build} ocaml_all \
                && echo 'ok' > %{output_dir}/build.ok"])
       else None);
    fetch_lib = Some (Canary_action.fetch_lib_cmd pm prebuilt.system_package);
    fetch_binding =
      Some (Canary_action.fetch_binding_cmd prebuilt.opam_package_spec);
    pack_binding =
      (if source.has_build_binding then
         Some
           (fun ~output_dir ->
             let repo_abs = tola_root ^ "/canary/templates/opam-local-repo" in
             let repo_name = llvm_ocaml_config.toolchain.local_repo_name in
             (* llvm.dev-shared and conf-llvm-shared.dev read CANARY_LLVM_BUILD
                to locate the build tree. No opam config subst needed — these
                packages use shell ${VAR:-default} directly. *)
             [%string
               {|eval $(opam env)
opam repo add %{repo_name} "file://%{repo_abs}" --rank=1 \
  || opam repo set-url %{repo_name} "file://%{repo_abs}"
opam update %{repo_name}
CANARY_BUILD_DIR="%{build}" opam install -y conf-llvm-shared.dev --assume-depexts
opam remove -y llvm.dev-shared || true
CANARY_BUILD_DIR="%{build}" opam install -y %{llvm_dev_opam_pkg} \
  --verbose --keep-build-dir --assume-depexts \
  && echo 'ok' > %{output_dir}/pack.ok|}])
       else None);
    probe_lib =
      (if source.has_build_lib then
         Some
           (fun ~output_dir ->
             Canary_artifact_native.native_lib_probe_cmd
               ~lib:[%string "%{build}/lib/libLLVM.so"]
               ~prefix:"LLVM" ~output_dir)
       else
         Some
           (fun ~output_dir ->
             [%string
               {|LLVM_CONFIG=$(%{find_llvm_config_cmd})
test -x "$LLVM_CONFIG"
"$LLVM_CONFIG" --version > %{output_dir}/probe.log 2>&1|}]));
    probe_binding =
      List.filter_opt
        [
          (* Build_tree: probe source-built binding against source-built lib *)
          (if source.has_build_binding then
             Some
               (Build_tree, fun ~output_dir ->
                 let script = "canary/scripts/assert_binary_symbols.py" in
                 let pkg_dir = [%string "%{build}/lib/ocaml/llvm"] in
                 [%string
                   {|eval $(opam env)
STUB=$(ls %{pkg_dir}/lib*.a 2>/dev/null | head -1)
test -n "$STUB"
python3 %{script} --provided-lib %{build}/lib/libLLVM.so --required-lib "$STUB" \
  --symbol-prefix LLVM 2>&1 | tee %{output_dir}/symbols.log
grep -q 'OK:' %{output_dir}/symbols.log
LLVM_CONFIG=%{llvm_config} ocamlopt \
  -I %{pkg_dir} %{pkg_dir}/llvm.cmxa %{example} \
  -o %{output_dir}/%{target} > %{output_dir}/probe.log 2>&1 || exit 1
%{output_dir}/%{target} >> %{output_dir}/probe.log 2>&1|}])
           else None);
          (* Lang_pm: probe opam-installed binding (llvm.19-shared) *)
          Some
            (Lang_pm, fun ~output_dir ->
              [%string
                {|eval $(opam env)
ocamlfind ocamlopt -package %{binding_lib} -linkpkg %{example} \
  -o %{output_dir}/%{target} > %{output_dir}/probe.log 2>&1 || exit 1
%{output_dir}/%{target} >> %{output_dir}/probe.log 2>&1|}]);
        ];
    probe_app = Some llvm_python_probe;
    check_post =
      (function
      | Fetch Source -> Some Canary_artifact_source.source_check_post
      | Configure ->
          Some (fun ~output_dir ->
            Canary_artifact_check.check_markers [ "configure.ok" ] ~output_dir
            || Stdlib.Sys.file_exists [%string "%{build}/CMakeCache.txt"])
      | Build_lib ->
          Some
            (Canary_artifact_check.check_build_lib ~marker:"build.ok"
               ~lib_path:[%string "%{build}/lib/libLLVM.so"])
      | Build_binding ->
          Some
            (Canary_artifact_check.check_build_binding ~marker:"build.ok"
               ~archive_path:[%string "%{build}/lib/ocaml/llvm/llvm.cmxa"])
      | Fetch Binding ->
          let pkg = prebuilt.opam_package_spec.install_name in
          Some (fun ~output_dir ->
            Canary_artifact_check.check_markers [ "binding.ok" ] ~output_dir
            || Canary_pm_opam.is_installed ~pkg)
      | Publish Binding ->
          Some (fun ~output_dir ->
            Canary_artifact_check.check_markers [ "pack.ok" ] ~output_dir
            || Canary_pm_opam.is_installed ~pkg:llvm_dev_opam_pkg)
      | _ -> None);
    expectation =
      (function
      | Probe Binding when not source.has_build_binding ->
          (* llvm_example_dev.ml uses Opcode.UncondBr (LLVM 21+); fails against llvm.19-shared *)
          (* OCaml 5.2+ quotes constructor names: "Opcode.UncondBr"; match both forms *)
          Expect_failure {
            contains_any = [ "Unbound constructor Opcode.UncondBr";
                             {|Unbound constructor "Opcode.UncondBr"|} ];
            version_info = Some {
              provider_version = "llvm 19";
              consumer_requires = "Opcode.UncondBr";
              since = Some "LLVM 21 (dev, commit #186176)";
              note = None;
            };
          }
      | _ -> Expect_success);
    summary = (function
      | Probe Lib when source.has_build_lib ->
          Some (fun ~output_dir ->
            Canary_artifact_native.summary_cmd
              ~lib:[%string "%{build}/lib/libLLVM.so"]
              ~prefixes:[ "LLVM" ]
              ~watchlist:llvm_native_watchlist
              ~output_dir ())
      | Probe Lib ->
          Some (fun ~output_dir ->
            [%string {|LLVM_CONFIG=$(%{find_llvm_config_cmd})
LLVM_LIB=$(ls "$("$LLVM_CONFIG" --libdir)"/libLLVM*.so 2>/dev/null | head -1)
test -n "$LLVM_LIB"
%{Canary_artifact_native.summary_cmd
    ~lib:"$LLVM_LIB"
    ~prefixes:[ "LLVM" ]
    ~watchlist:llvm_native_watchlist
    ~output_dir ()}|}])
      | Probe Binding ->
          (* ocamlfind package is "llvm" regardless of opam variant suffix
             (llvm.dev-shared / llvm.19-shared are opam-only names). *)
          Some (fun ~output_dir ->
            Canary_artifact_ocaml.summary_opam_pkg_cmd
              ~pkg:"llvm" ~watchlist:llvm_ocaml_watchlist ~output_dir ())
      | _ -> None);
  }

(* ── Action steps ── *)

let action_steps ?(source = llvm_source_dev) ~root ~project distro =
  let spec = mk_script_spec ~source distro in
  Canary_action.derive_steps ~root ~project spec

let run_info ?(source_repo : source_repo option) steps =
  match source_repo with
  | Some src ->
      let source_str =
        let (Git_remote url) = src.remote in
        "git:" ^ url
      in
      Canary_action.mk_run_info ~project:"llvm" ~version:src.version
        ~ref_:src.ref_ ~source:source_str
        ~extra:
          [
            ("official", if src.official then "true" else "false");
            ( "remote",
              let (Git_remote url) = src.remote in
              url );
          ]
        steps
  | None ->
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
