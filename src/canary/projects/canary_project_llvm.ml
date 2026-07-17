open Base
open Canary_basic
open Canary_store
open Canary_artifact_source
open Canary_artifact_api
open Canary_lang
open Canary_toolchain
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

(* API source spec for llvm — native_api for the C API surface and in-tree
   OCaml binding_api. llvmlite is out-of-tree (source_dir = None).
   All sources (dev and stable) share this spec. *)
let llvm_api_source : Canary_artifact_api.t =
  let native_api : Canary_artifact_api.native_api =
    {
      kind       = C;
      components = [ Headers; Runtime_lib; Link_lib ];
      headers    = Some { dir = "llvm/include/llvm-c";
                          files =
                            [ (* top-level *)
                              "Analysis.h"; "BitReader.h"; "BitWriter.h"; "Comdat.h"; "Core.h";
                              "DataTypes.h"; "DebugInfo.h"; "Deprecated.h"; "Disassembler.h";
                              "DisassemblerTypes.h"; "Error.h"; "ErrorHandling.h";
                              "ExecutionEngine.h"; "ExternC.h"; "IRReader.h"; "LLJIT.h";
                              "LLJITUtils.h"; "Linker.h"; "Object.h"; "Orc.h"; "OrcEE.h";
                              "Remarks.h"; "Support.h"; "Target.h"; "TargetMachine.h"; "Types.h";
                              "Visibility.h"; "blake3.h"; "lto.h";
                              (* Transforms/ subdir *)
                              "Transforms/AggressiveInstCombine.h"; "Transforms/IPO.h";
                              "Transforms/InstCombine.h"; "Transforms/PassBuilder.h";
                              "Transforms/Scalar.h"; "Transforms/Utils.h";
                              "Transforms/Vectorize.h" ] };
      symbol_prefixes = [ "LLVM" ];
      stable_symbols  =
        [ "LLVMContextCreate"; "LLVMModuleCreateWithName"; "LLVMCreateBuilder";
          "LLVMBuildAdd"; "LLVMBuildBr"; "LLVMBuildRetVoid";
          "LLVMVerifyModule"; "LLVMDisposeMessage" ];
      versioned_symbols = [];
      soname    = None;
      c_runtime = None;
      cxx_abi   = None;
    }
  in
  let ocaml_binding : Canary_artifact_api.binding_api =
    {
      lang = OCaml;
      source_dir = Some "llvm/bindings/ocaml";
      (* Drift signal: Llvm.Opcode.UncondBr added in v21 (Br split into
         UncondBr+CondBr). Lives in binding_api watchlist, not native_api
         stable_symbols — it's a C enum value, not a named export. *)
      module_watchlist =
        [ "Llvm"; "Llvm_analysis"; "Llvm_bitreader"; "Llvm_bitwriter";
          "Llvm_target"; "Llvm_executionengine";
          "Llvm.Opcode"; "Llvm.Opcode.UncondBr" ];
      type_watchlist = [];
    }
  in
  (* llvmlite bundles its own libLLVM; out-of-tree (source_dir = None). *)
  let python_binding : Canary_artifact_api.binding_api =
    {
      lang = Python;
      source_dir = None;
      module_watchlist =
        [ "initialize"; "initialize_native_target";
          "parse_assembly"; "create_mcjit_compiler"; "Target" ];
      type_watchlist = [];
    }
  in
  { native_api; binding_apis = [ ocaml_binding; python_binding ] }

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
    api_source = Some llvm_api_source;
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
    (* Stable sources share the dev api_source — same project, same spec.
       Summary closures will warn when source.has_build_binding = false. *)
    api_source = Some llvm_api_source;
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
    api_source = Some llvm_api_source;
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

let llvm_python_config : Canary_toolchain.binding_config =
  Python_config
    {
      pip_package = Some "llvmlite";
      probe_snippet =
        {|import llvmlite.binding as llvm; print('llvmlite ok:', llvm.llvm_version_info)|};
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

let llvm_python_probe ~output_dir ~variant_key =
  let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
  [%string
    {|(pip install --quiet llvmlite 2>/dev/null \
 || python3 -m pip install --quiet llvmlite 2>/dev/null \
 || uv pip install --quiet llvmlite)
python3 -c "import llvmlite.binding as llvm; print(llvm.llvm_version_info)" > %{output_dir}/%{probe_log} 2>&1|}]

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

(* cmake flag list for LLVM (no -S/-B). The actual configure command is
   assembled by [Canary_build_cmd.cmake_configure_cmd] in the project_spec.

   Speed flags:
   - mold: 5-10x faster linking than ld (available on this machine)
   - LLVM_OPTIMIZED_TABLEGEN: builds tablegen in Release even in Debug builds
   - ccache/sccache: compiler cache; no-op if not installed
     (CMAKE_*_COMPILER_LAUNCHER falls back gracefully when the binary is absent)
   - LLVM_PARALLEL_LINK_JOBS: limit concurrent linkers to avoid OOM;
     each LLVM link can use 4-8 GB — set to (RAM_GB / 8) conservatively *)
let llvm_cmake_flags =
  [
    "-G Ninja";
    "-DCMAKE_C_COMPILER=clang-23";
    "-DCMAKE_CXX_COMPILER=clang++-23";
    "-DCMAKE_BUILD_TYPE=Release";
    "-DCMAKE_C_COMPILER_LAUNCHER=sccache";
    "-DCMAKE_CXX_COMPILER_LAUNCHER=sccache";
    "-DLLVM_USE_LINKER=mold";
    "-DLLVM_OPTIMIZED_TABLEGEN=ON";
    "-DLLVM_PARALLEL_LINK_JOBS=8";
    "-DLLVM_ENABLE_BINDINGS=ON";
    "-DLLVM_BUILD_LLVM_DYLIB=ON";
    "-DLLVM_LINK_LLVM_DYLIB=ON";
    {|-DLLVM_TARGETS_TO_BUILD="X86"|};
    {|-DLLVM_ENABLE_PROJECTS=""|};
    {|-DLLVM_ENABLE_RUNTIMES=""|};
    "-DLLVM_BUILD_TOOLS=OFF";
    "-DLLVM_BUILD_EXAMPLES=OFF";
    "-DLLVM_INCLUDE_TESTS=OFF";
    "-DLLVM_INCLUDE_BENCHMARKS=OFF";
    "-DLLVM_INCLUDE_DOCS=OFF";
    "-DLLVM_BUILD_RUNTIME=OFF";
    "-DLLVM_ENABLE_ASSERTIONS=OFF";
  ]

let mk_project_spec ~source
    ?(binding_configs =
        [ Ocaml_config llvm_ocaml_config; llvm_python_config ])
    ?(tola_root = Unix.getcwd ()) distro : Canary_step_builder.project_spec =
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
  let ocaml_tc =
    List.find_map binding_configs ~f:(function
      | Ocaml_config c -> Some c
      | Python_config _ -> None)
    |> Option.value_exn
         ~message:"llvm mk_project_spec: no Ocaml_config in binding_configs"
  in
  let target = ocaml_tc.ocaml.example_target in
  (* llvm_example_dev.ml uses Opcode.UncondBr (LLVM 21+); it will fail to
     compile against LLVM 19 binding, which is the mismatch we want to detect. *)
  let example =
    tola_root ^ "/canary/examples/llvm/llvm_example_dev.ml"
  in
  let llvm_config = [%string "%{build}/bin/llvm-config"] in
  let binding_lib = ocaml_tc.ocaml.binding_lib_name in
  {
    Canary_step_builder.empty_project_spec with
    api_source = source.api_source;
    fetch_source =
      Some
        (fun ~output_dir ~variant_key ->
          Canary_artifact_source.source_fetch_cmd distro source ~output_dir ~variant_key);
    scan_source =
      Option.map source.api_source ~f:(fun api ->
        fun ~output_dir ~variant_key ->
          Canary_artifact_source.scan_source_cmd ~source_root:root api ~output_dir ~variant_key);
    build_headers =
      (if source.has_build_lib || source.has_build_binding then
         Some
           (fun ~output_dir ~variant_key ->
             let hdr_ok = Canary_basic.variant_file ~variant_key "headers.ok" in
             [%string
               "test -d %{root}/llvm/include/llvm-c \
                && echo 'ok' > %{output_dir}/%{hdr_ok}"])
       else None);
    configure =
      (if source.has_build_lib || source.has_build_binding then
         let cmake_source = cmake_source_of_root root in
         Some
           (fun ~output_dir ~variant_key ->
             let cmake_cmd =
               Canary_build_cmd.cmake_configure_cmd
                 ~cmake_exec:"cmake" ~flags:llvm_cmake_flags
                 ~src:cmake_source ~build ()
             in
             Printf.sprintf "eval $(opam env) && %s" cmake_cmd
             |> Canary_build_cmd.with_marker
                  ~marker:"conf.ok" ~output_dir ~variant_key)
       else None);
    build_lib =
      (if source.has_build_lib then
         Some
           (fun ~output_dir ~variant_key ->
             Canary_build_cmd.ninja_build_cmd ~target:"LLVM" ~build ()
             |> Canary_build_cmd.with_marker
                  ~marker:"build.ok" ~output_dir ~variant_key)
       else None);
    build_binding =
      (if source.has_build_binding then
         [ (OCaml,
            fun ~output_dir ~variant_key ->
              let ninja_cmd =
                Canary_build_cmd.ninja_build_cmd
                  ~target:"ocaml_all" ~build ()
              in
              Printf.sprintf "eval $(opam env) && %s" ninja_cmd
              |> Canary_build_cmd.with_marker
                   ~marker:"build.ok" ~output_dir ~variant_key) ]
       else []);
    install_lib =
      (if source.has_build_lib then
         Some (fun ~output_dir ~variant_key ->
           let install_ok = Canary_basic.variant_file ~variant_key "install.ok" in
           [%string
             {|PREFIX="%{build}/../install"
mkdir -p "$PREFIX/lib"
cp %{build}/lib/libLLVM*.so "$PREFIX/lib/" 2>/dev/null || true
echo 'ok' > %{output_dir}/%{install_ok}|}])
       else None);
    fetch_lib = Some (Canary_step_builder.fetch_lib_cmd pm prebuilt.system_package);
    fetch_binding =
      (Canary_lang.OCaml,
       Canary_step_builder.fetch_binding_cmd prebuilt.opam_package_spec)
      :: List.filter_map binding_configs ~f:(function
        | Python_config p ->
            Some (Canary_lang.Python,
                  fun ~output_dir ~variant_key ->
                    Canary_toolchain.pip_install_cmd p ~output_dir ~variant_key)
        | Ocaml_config _ -> None);
    pack_binding =
      (if source.has_build_binding then
         [ (OCaml,
            fun ~output_dir ~variant_key ->
              let repo_abs = tola_root ^ "/canary/templates/opam-local-repo" in
              let repo_name = ocaml_tc.toolchain.local_repo_name in
              (* llvm.dev-shared and conf-llvm-shared.dev read CANARY_BUILD_DIR
                 to locate the build tree. No opam config subst needed — these
                 packages use shell ${VAR:-default} directly. *)
              let env_prefix = [%string {|CANARY_BUILD_DIR="%{build}" |}] in
              let pre_install =
                [%string
                  {|CANARY_BUILD_DIR="%{build}" opam install -y conf-llvm-shared.dev --assume-depexts|}]
              in
              opam_pack_cmd ~repo_name ~repo_abs ~pkg_full:llvm_dev_opam_pkg
                ~pre_install ~env_prefix ~output_dir ~variant_key ()) ]
       else []);
    probe_lib =
      List.filter_opt
        [
          (if source.has_build_lib then
             Some
               ( Build_tree,
                 fun ~output_dir ~variant_key ->
                   Canary_artifact_native.native_lib_probe_cmd
                     ~lib:[%string "%{build}/lib/libLLVM.so"]
                     ~prefix:"LLVM" ~output_dir ~variant_key )
           else None);
          (if source.has_build_lib then
             Some
               ( Staged,
                 fun ~output_dir ~variant_key ->
                   Canary_artifact_native.native_lib_probe_cmd
                     ~lib:[%string "%{build}/../install/lib/libLLVM.so"]
                     ~prefix:"LLVM" ~output_dir ~variant_key )
           else None);
          Some
            ( Pm (Sys_pm { pm }),
              fun ~output_dir ~variant_key ->
                let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
                [%string
                  {|LLVM_CONFIG=$(%{find_llvm_config_cmd})
test -x "$LLVM_CONFIG"
"$LLVM_CONFIG" --version > %{output_dir}/%{probe_log} 2>&1|}] );
        ];
    probe_binding =
      List.filter_opt
        [
          (* Build_tree: probe source-built binding against source-built lib *)
          (if source.has_build_binding then
             Some
               (OCaml, Build_tree, fun ~output_dir ~variant_key ->
                 let script = "canary/scripts/assert_binary_symbols.py" in
                 let pkg_dir = [%string "%{build}/lib/ocaml/llvm"] in
                 let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
                 let symbols_log = Canary_basic.variant_file ~variant_key "symbols.log" in
                 [%string
                   {|eval $(opam env)
STUB=$(ls %{pkg_dir}/lib*.a 2>/dev/null | head -1)
test -n "$STUB"
python3 %{script} --provided-lib %{build}/lib/libLLVM.so --required-lib "$STUB" \
  --symbol-prefix LLVM 2>&1 | tee %{output_dir}/%{symbols_log}
grep -q 'OK:' %{output_dir}/%{symbols_log}
LLVM_CONFIG=%{llvm_config} ocamlopt \
  -I %{pkg_dir} %{pkg_dir}/llvm.cmxa %{example} \
  -o %{output_dir}/%{target} > %{output_dir}/%{probe_log} 2>&1 || exit 1
%{output_dir}/%{target} >> %{output_dir}/%{probe_log} 2>&1|}])
           else None);
          (* Lang_pm: probe opam-installed binding (llvm.19-shared) *)
          Some
            (OCaml, Pm (Lang_pm { lang = OCaml; pm = Opam }), fun ~output_dir ~variant_key ->
              let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
              [%string
                {|eval $(opam env)
ocamlfind ocamlopt -package %{binding_lib} -linkpkg %{example} \
  -o %{output_dir}/%{target} > %{output_dir}/%{probe_log} 2>&1 || exit 1
%{output_dir}/%{target} >> %{output_dir}/%{probe_log} 2>&1|}]);
        ]
      @ List.filter_map binding_configs ~f:(function
          | Python_config p ->
              (* Install moved to Fetch (Binding Python); this step is
                 import-only so summary from fetch is pre-cached. *)
              Some (Python, Pm (Lang_pm { lang = Python; pm = Pip }),
                    fun ~output_dir ~variant_key ->
                      Canary_toolchain.python_probe_only_cmd p ~output_dir ~variant_key)
          | Ocaml_config _ -> None);
    probe_app = Some llvm_python_probe;
    check_post =
      (function
      | Fetch Source -> Some Canary_artifact_source.source_check_post
      | Configure ->
          Some (fun ~output_dir ~variant_key ->
            Canary_step_builder.check_markers [ "conf.ok" ] ~output_dir ~variant_key
            || Stdlib.Sys.file_exists [%string "%{build}/CMakeCache.txt"])
      | Build_lib ->
          Some
            (Canary_step_builder.check_build_lib ~marker:"build.ok"
               ~lib_path:[%string "%{build}/lib/libLLVM.so"])
      | Build_binding _ ->
          Some
            (Canary_step_builder.check_build_binding ~marker:"build.ok"
               ~archive_path:[%string "%{build}/lib/ocaml/llvm/llvm.cmxa"])
      | Fetch (Binding _) ->
          let pkg = prebuilt.opam_package_spec.install_name in
          Some (fun ~output_dir ~variant_key ->
            Canary_step_builder.check_markers [ "binding.ok" ] ~output_dir ~variant_key
            || Canary_pm_opam.is_installed ~pkg)
      | Publish (Binding _) ->
          Some (fun ~output_dir ~variant_key ->
            Canary_step_builder.check_markers [ "pack.ok" ] ~output_dir ~variant_key
            || Canary_pm_opam.is_installed ~pkg:llvm_dev_opam_pkg)
      | _ -> None);
    expectation = (fun rule loc -> match rule, loc with
      | Probe_binding (_), Some (Pm (Lang_pm { lang = Python; _ })) ->
          (* llvmlite bundles its own libLLVM; independent of opam's LLVM
             version, so the pip probe is Expect_success regardless of
             has_build_binding. *)
          Expect_success
      | Probe_binding (_), _ when not source.has_build_binding ->
          (* llvm_example_dev.ml uses Opcode.UncondBr (LLVM 21+); fails against llvm.19-shared.
             contains_any is now DERIVED from cached compat summaries by the runner —
             reads mli watchlist's missing list (e.g. Llvm.Opcode.UncondBr →
             "Opcode.UncondBr" / "UncondBr" substrings) plus L0 missing C symbols.
             Hand-written list retained as fallback at the variant level via
             empty-derived → any-failure-with-probe.log. See api_interface.md §13. *)
          Expect_compat_failure {
            inputs = Canary_compat.[
              C_stub [ "pack_binding_ocaml/summary_stub.json";
                       "fetch_binding_ocaml/summary_stub.json" ];
              Native_lib [ "probe_lib/inspect.json";
                           "probe_lib_apt/inspect.json";
                           "probe_lib_staged/inspect.json" ];
              Ocaml_mli [ "pack_binding_ocaml/inspect.json";
                          "fetch_binding_ocaml/inspect.json" ];
            ];
            version_info = Some {
              provider_version = "llvm 19";
              consumer_requires = "Opcode.UncondBr";
              since = Some "LLVM 21 (dev, commit #186176)";
              note = None;
            };
          }
      | _ -> Expect_success);
    binding_user_facing_pkg = [ (OCaml, "llvm"); (Python, "llvmlite.binding") ];
    inspect_note =
      (if not source.has_build_binding then
         Some (Canary_artifact_api.stable_reuse_warning
                 ~source_name:"llvm" ~source_version:source.version)
       else None);
    inspect = (fun rule _loc ->
      let api = Option.value_exn source.api_source
          ~message:"llvm mk_project_spec: api_source not set" in
      let warn =
        if not source.has_build_binding then
          Some (Canary_artifact_api.stable_reuse_warning
                  ~source_name:"llvm" ~source_version:source.version)
        else None
      in
      let prepend_warn cmd =
        match warn with None -> cmd | Some w -> [%string "%{w}\n%{cmd}"]
      in
      match rule with
      | Probe_lib when source.has_build_lib ->
          Some (fun ~output_dir ~variant_key ->
            prepend_warn (Canary_artifact_native.inspect_cmd
              ~lib:[%string "%{build}/lib/libLLVM.so"]
              ~prefixes:[ "LLVM" ]
              ~watchlist:(Canary_artifact_api.native_watchlist api)
              ~output_dir ~variant_key ()))
      | Probe_lib ->
          Some (fun ~output_dir ~variant_key ->
            prepend_warn [%string {|LLVM_CONFIG=$(%{find_llvm_config_cmd})
LLVM_LIB=$(ls "$("$LLVM_CONFIG" --libdir)"/libLLVM*.so 2>/dev/null | head -1)
test -n "$LLVM_LIB"
%{Canary_artifact_native.inspect_cmd
    ~lib:"$LLVM_LIB"
    ~prefixes:[ "LLVM" ]
    ~watchlist:(Canary_artifact_api.native_watchlist api)
    ~output_dir ~variant_key ()}|}])
      | _ -> None);
    artifact_name = (function
      | Canary_basic.Lib -> Some "libLLVM.so"
      | Canary_basic.Binding Canary_lang.OCaml -> Some "llvm"
      | Canary_basic.Binding Canary_lang.Python -> Some "llvmlite"
      | _ -> None);
  }
