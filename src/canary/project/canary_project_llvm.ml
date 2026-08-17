open Base
open Canary_basic
open Canary_store
open Canary_artifact_source
open Canary_artifact
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
let llvm_api_source : Canary_artifact.t =
  let native_api : Canary_artifact.native_api =
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
  let ocaml_binding : Canary_artifact.binding_api =
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
  (* llvmlite bundles its own libLLVM (libllvmlite.so) and loads it via
     ctypes at runtime; out-of-tree (source_dir = None). No compiled
     extension the binding produces — the honest mechanism is Ctypes
     (the artifact table's previous Cext declaration was wrong, fixed
     2026-08-17). *)
  let python_binding : Canary_artifact.binding_api =
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

(* ── binding declarations (M2 step 4, 2026-08-17) ──
   - OCaml cstubs: the in-tree binding (llvm/bindings/ocaml) — llvm.ml
     + a family of submodules (analysis/bitreader/...); surface_path
     names the TOP module file. Built by the native build target
     (llvm.cmxa + libllvm.a).
   - Python: llvmlite — wheel-bundled libllvmlite.so loaded via
     ctypes — Dlopen, no compile stage. *)
let llvm_binding_decls : Canary_binding_decl.binding_decl list =
  let open Canary_binding_decl in
  let c_api =
    { functions =
        [ "LLVMContextCreate"; "LLVMModuleCreateWithName"; "LLVMCreateBuilder";
          "LLVMBuildAdd"; "LLVMBuildBr"; "LLVMBuildRetVoid";
          "LLVMVerifyModule"; "LLVMDisposeMessage" ];
      (* the declared stable subset (mirrors the api_source watch) *)
      enums = [] }
  in
  let native =
    { prefix = "LLVM";
      soname = "libLLVM.so";
      headers = { dir = "llvm/include/llvm-c"; files = [ "Core.h" ] } }
  in
  [ { mechanism = Canary_mechanism.Cstubs;
      c_api; native;
      coupling =
        Stub_archive
          { sources = [ "llvm_ocaml.c" ];
            archive = "libllvm.a" };
      surface_path = "llvm/bindings/ocaml/llvm/llvm.mli" };
    { mechanism = Canary_mechanism.Ctypes;
      c_api; native;
      coupling = Dlopen { name = "libllvmlite.so" };
      surface_path = "llvmlite/__init__.py" } ]

let llvm_source_dev : source_repo =
  {
    name = "llvm";
    remote = Some (Git "https://github.com/arbipher/llvm-project.git");
    locals =
      [
        { distro = Wsl;
          path = "/home/red/code/contrib/llvm-all/llvm-project";
          build_path = "/home/red/code/contrib/llvm-all/build" };
      ];
    (* C2 (2026-08-16): [id = "arbipher"] — identity-bearing, a marker-style
       id like "latest" (the fork tracks HEAD; the FORK ITSELF is the
       identity). The three-version report needs official-dev and
       forked-dev as DISTINCT scenarios (the 2026-08-13 finding: both
       declare ref_ = HEAD, ambient identity would collide them). *)
    version = Canary_basic.{ channel = Dev; id = "arbipher" };
    ref_ = "HEAD";
    official = false;
    build_sys_deps = [ "cmake"; "ninja-build" ];
    api_source = Some llvm_api_source;
    label = Some "arbipher";
    (* the repo builds the lib + the in-tree OCaml binding
       (llvm/bindings/ocaml); llvmlite (pip) is off-tree *)
    artifacts =
      [ a_lib; a_binding Canary_lang.OCaml Canary_mechanism.Cstubs ];
  }

let llvm_source_stable : source_repo =
  {
    name = "llvm";
    remote = Some (Git "https://github.com/llvm/llvm-project.git");
    (* Reuse the same local checkout as dev — fetch_source is a no-op (test -d).
       We don't build from it (has_build_lib=false, has_build_binding=false). *)
    locals =
      [
        { distro = Wsl;
          path = "/home/red/code/contrib/llvm-all/llvm-project";
          build_path = "/home/red/code/contrib/llvm-all/build" };
      ];
    version = Canary_basic.{ channel = Stable; id = "19" };
    ref_ = "llvmorg-19.1.7";
    official = true;
    (* No local build tree for stable — skip ninja, use fetch_binding (llvm.19-shared).
       probe_binding_pkg will compile llvm_example_dev.ml against the 19 binding
       and fail, demonstrating the version mismatch. *)
    build_sys_deps = [];
    (* Stable sources share the dev api_source — same project, same spec.
       Summary closures will warn when build_binding = false. *)
    api_source = Some llvm_api_source;
    label = None;
    (* the repo builds the lib + the in-tree OCaml binding
       (llvm/bindings/ocaml); llvmlite (pip) is off-tree *)
    artifacts =
      [ a_lib; a_binding Canary_lang.OCaml Canary_mechanism.Cstubs ];
  }

let llvm_source_latest : source_repo =
  {
    name = "llvm";
    remote = Some (Git "https://github.com/llvm/llvm-project.git");
    locals = [];
    version = Canary_basic.{ channel = Dev; id = "latest" };
    ref_ = "HEAD";
    official = true;
    build_sys_deps = [ "cmake"; "ninja-build" ];
    api_source = Some llvm_api_source;
    label = None;
    (* the repo builds the lib + the in-tree OCaml binding
       (llvm/bindings/ocaml); llvmlite (pip) is off-tree *)
    artifacts =
      [ a_lib; a_binding Canary_lang.OCaml Canary_mechanism.Cstubs ];
  }

(* Channel-keyed source lookup — the channel DEFAULT (C2 keeps it as the
   fallback + CI's tag lookup). [Dev] = the ARBIPHER fork (2026-08-12
   restored, same as z3's). The 2026-08-12 "official clone unusable"
   finding was MISDIAGNOSED — the clone was fine; the real bug was the
   realize-time cmake-source probe (fixed 2026-08-16, see the table
   rows). The per-SCENARIO dispatch ([llvm_source_for_assignment])
   selects the exact repo by the source placement's pinned id —
   [latest] is a real scenario now (C2, the three-version report). *)
let llvm_source_of (ch : Canary_basic.channel) : source_repo = match ch with Canary_basic.Dev -> llvm_source_dev | Canary_basic.Stable -> llvm_source_stable

(* The repo backing one scenario's source placement (C2): the [Repo_axes]
   store pins carry each repo's (channel, id), so match the placement's
   version against the three declared repos — exact (channel, id) first,
   then the channel default ([llvm_source_of] — CI's synthetic
   assignments carry no source placement). The realize ∘ dispatch idiom. *)
let llvm_source_for_assignment (a : Canary_artifact.assignment) : source_repo =
  let v = Canary_enumerate.version_of a Canary_artifact.a_source in
  let open Canary_basic in
  match
    List.find
      [ llvm_source_stable; llvm_source_latest; llvm_source_dev ]
      ~f:(fun r ->
        equal_channel r.Canary_artifact_source.version.channel v.channel
        && String.equal r.Canary_artifact_source.version.id v.id)
  with
  | Some r -> r
  | None -> llvm_source_of v.channel

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
  Canary_build_cmd.llvm_config_cmd ~locator_hint:llvm_locator_hint
    ~macos_pkg:prebuilt.system_package.macos_pkg

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
   assembled by [Canary_build_cmd.cmake_configure_cmd] in the runner_spec.

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

(** llvm's contract bindings (Task 2 Phase D, 2026-07-21; consulted in
    BOTH chains since A7 phase 3 — the agnostic lowering replaced the
    per-variant [has_manifest] knob, and the dev chain now derives an
    EMPTY prediction instead of being exempted).

    One binding: c2 (api completeness) at [At_probe_binding OCaml],
    firing anywhere (loc_filter = Any). The inputs bag intentionally
    includes C_stub + Native_lib + Ocaml_mli even though the
    "official" contract is c2 — the runner's per-contract iterator reads
    ALL contracts over the merged inputs, so declaring extra inputs lets
    c1/c6 also contribute predicted substrings (and the confirming
    contract is attributed per-id in the verdict since phase 2).

    ORDER IS LOAD-BEARING (the phase-3 dev-chain exemption): each input
    lists the pack-side (dev-built) artifact BEFORE the fetch-side one;
    the resolution's first-existing rule therefore reads the dev
    binding's inspects in the dev chain — empty prediction, success
    expected — even though the fetched 19 binding's inspects coexist in
    the same scenario dir.

    Python probe: no (C2, Python) binding — lookup falls through to
    Expect_success. Matches the "llvmlite bundles its own libLLVM"
    override without needing an explicit loc_filter. *)
let llvm_stable_contract_bindings
  : Canary_scenario.contract_binding list
  =
  let module CC = Canary_compat in
  let module CS = Canary_scenario in
  [
    { contract = CC.C2; lang = Canary_lang.OCaml;
      firings = [
        { site = CS.At_probe_binding Canary_lang.OCaml;
          loc_filter = CS.Any;
          source = CS.From_artifact {
            inputs = CC.[
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
          }};
      ]};
  ]

let llvm_python_provider =
  Canary_store_config.Lang_pkg
    { lang = Canary_lang.Python; pm = Canary_store.Pip; package = "llvmlite";
      self_contained = true; versions = None }

let llvm_artifacts : Canary_project_spec.artifact_row list =
  let open Canary_project_spec in
  [ artifact_row ~artifact:a_source
      ~universe:[ (Fetched, Canary_basic.[ Stable; Dev ]) ]
      (* C2 (2026-08-16): the 3-way — stable, official dev (latest), and
         the arbipher fork, as per-channel repo pins: one identity-bearing
         scenario per repo. *)
      ~provider:
        (Canary_store_config.Repo_axes
           [ llvm_source_stable; llvm_source_latest; llvm_source_dev ])
      ();
    artifact_row ~artifact:a_lib
      ~universe:[ (Fetched, [ Canary_basic.Stable ]);
                  (Built, [ Canary_basic.Dev ]) ]
      ~provider:(Canary_store_config.Sys_pkg prebuilt.system_package) ();
    artifact_row ~artifact:(a_binding Canary_lang.OCaml Canary_mechanism.Cstubs)
      ~follows:a_lib
      ~universe:[ (Built, [ Canary_basic.Dev ]);
                  (Fetched, [ Canary_basic.Stable ]) ]
      ~provider:
        (Canary_store_config.Lang_pkg
           { lang = Canary_lang.OCaml; pm = Canary_store.Opam;
             package = prebuilt.opam_package; self_contained = false;
             (* STORE PIN (2026-08-12): the stable chain's binding pins the
                opam package version (the store's own record — "19-shared";
                the standard install name llvm.19-shared fits, no custom
                install_name needed). The dev binding is BUILT and probes
                the build tree — no store read. *)
             versions =
               Some
                 [ { Canary_store_config.pin_version = "19-shared";
                     install_name = None } ] })
      ();
    artifact_row ~artifact:(a_binding Canary_lang.Python Canary_mechanism.Ctypes)
      ~universe:[ (Fetched, [ Canary_basic.Stable ]) ]
      ~provider:llvm_python_provider () ]

let llvm_table_rows ~(source : Canary_artifact_source.source_repo) ~distro =
  let open Canary_action_templates in
  (* C2: per-REPO rows — the scenario's source placement picks the repo,
     not a channel default; the repo's own version.channel drives the
     dev/stable row split below. *)
  let { version; ref_; name; remote; _ } : Canary_artifact_source.source_repo = source in
  let ver_str = Canary_basic.string_of_version version in
  let local = Canary_artifact_source.local_for distro source in
  let root =
    match local with
    | Some l -> l.path
    | None -> Printf.sprintf "_out/canary/projects/llvm/%s_%s/src" ver_str ref_
  in
  let build =
    match local with
    | Some l -> l.build_path
    | None -> Printf.sprintf "_out/canary/projects/llvm/%s_%s/build" ver_str ref_
  in
  let url =
    match remote with
    | Some (Canary_artifact_source.Git u | Canary_artifact_source.Hg u) -> u
    | Some (Canary_artifact_source.Tar u) -> u
    | None -> "https://local-only.invalid/"
  in
  (* ALWAYS the llvm/ subdir (2026-08-16, C2 cold-audit fix): every llvm
     repo (official + fork, stable + dev) is the MONOREPO — llvm/ is the
     cmake root. The old filesystem probe here evaluated at REALIZE time,
     BEFORE the fetch step runs, so a fresh _out clone always resolved to
     [root] (no llvm/) and the configure died with "source directory does
     not appear to contain CMakeLists.txt" — the 2026-08-12 "official
     clone is unusable" finding was this bug MISDIAGNOSED (the clone was
     always fine; only the local-checkout fork passed the probe). *)
  let cmake_source = root ^ "/llvm" in
  let shared =
    [ { ar_action = Canary_basic.Fetch Canary_basic.Source;
        ar_template = Source_fetch
                { name; ver_str; ref_; url;
                  local = Option.map local ~f:(fun l -> l.path) } };
      { ar_action = Canary_basic.Fetch Canary_basic.Lib;
        ar_template = Fetch_lib { linux_pkg = "llvm-19-dev"; macos_pkg = "llvm@19" } };
      { ar_action = Canary_basic.Fetch (Canary_basic.Binding Canary_lang.OCaml);
        ar_template = Fetch_binding_opam { pkg = "llvm.19-shared" } };
      { ar_action = Canary_basic.Fetch (Canary_basic.Binding Canary_lang.Python);
        ar_template = Pip_install { pkg = "llvmlite" } };
      { ar_action = Canary_basic.Probe_binding Canary_lang.OCaml;
        ar_template = Ocaml_probe { binding_lib = "llvm";
                example = "canary/examples/llvm/llvm_example_dev.ml";
                target = "llvm_example_dev" } };
      { ar_action = Canary_basic.Probe_binding Canary_lang.Python;
        ar_template = Python_probe
                { snippet =
                    "import llvmlite.binding as llvm; llvm.initialize(); \
                     llvm.initialize_native_target(); \
                     llvm.initialize_native_asmprinter(); \
                     print('llvmlite ok: ' + llvm.llvm_version_info)" } };
      { ar_action = Canary_basic.Probe_lib;
        ar_template = Raw (fun ~output_dir ~variant_key ->
            let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
            Printf.sprintf
              "LLVM_CONFIG=$(%s)\ntest -x \"$LLVM_CONFIG\"\n\"$LLVM_CONFIG\" --version > %s/%s 2>&1"
              (Canary_build_cmd.llvm_config_cmd ~locator_hint:"llvm-config-19"
                 ~macos_pkg:"llvm@19")
              output_dir probe_log) };
    ]
  in
  let dev =
    [ { ar_action = Canary_basic.Fetch Canary_basic.Source;
        ar_template = Source_fetch
                { name; ver_str; ref_; url;
                  local = Option.map local ~f:(fun l -> l.path) } };
      { ar_action = Canary_basic.Scan_sources;
        ar_template = Scan_source { root; hdr_file = "llvm/include/llvm-c/Core.h" } };
      { ar_action = Canary_basic.Build_headers;
        ar_template = Build_headers { root; hdr_dir = "llvm/include/llvm-c" } };
      { ar_action = Canary_basic.Configure;
        ar_template = Cmake_configure
                { cmake_exec = "cmake";
                  (* -G Ninja required: cmake defaults to Makefiles
                     and the ninja_build step finds no build.ninja. *)
                  flags =
                    [ "-G"; "Ninja"; "-DLLVM_ENABLE_BINDINGS=ON";
                      "-DLLVM_BUILD_LLVM_DYLIB=ON";
                      "-DLLVM_TARGETS_TO_BUILD=X86" ];
                  src = cmake_source; build } };
      { ar_action = Canary_basic.Build_lib;
        ar_template = Ninja_build { target = "LLVM"; build } };
      { ar_action = Canary_basic.Build_binding Canary_lang.OCaml;
        ar_template = Ninja_build_binding { target = "ocaml_all"; build; env_guard = None } };
      { ar_action = Canary_basic.Install_lib;
        ar_template = Cmake_install_component
                { build; prefix = build ^ "/../install"; component = "LLVM" } };
      { ar_action = Canary_basic.Probe_lib;
        ar_template = Native_lib_probe
                { location = Build_tree_glob { lib_glob = "libLLVM.so"; build };
                  prefix = "LLVM" } };
      { ar_action = Canary_basic.Probe_lib;
        ar_template = Native_lib_probe
                { location = Staged_lib { lib = build ^ "/../install/lib/libLLVM.so" };
                  prefix = "LLVM" } };
      { ar_action = Canary_basic.Probe_binding Canary_lang.OCaml;
        ar_template = Raw (fun ~output_dir ~variant_key ->
            let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
            let symbols_log = Canary_basic.variant_file ~variant_key "symbols.log" in
            (* No llvm-config indirection: `ninja LLVM` builds only the dylib,
               so build/bin/llvm-config does not exist (cold OR warm) — the
               build libdir is known, point at it directly. *)
            Printf.sprintf
              "eval $(opam env) && \
               python3 canary/scripts/assert_binary_symbols.py \
                 --provided-lib %s/lib/libLLVM.so \
                 --required-lib %s/lib/ocaml/llvm/libllvm.a \
                 --symbol-prefix LLVM > %s/%s 2>&1 && \
               ocamlopt -I %s/lib/ocaml/llvm %s/lib/ocaml/llvm/llvm.cmxa \
                 canary/examples/llvm/llvm_example_dev.ml -o %s/llvm_example_dev > %s/%s 2>&1 && \
               %s/llvm_example_dev >> %s/%s 2>&1 && \
               cat %s/%s"
              build build output_dir symbols_log
              build build output_dir output_dir probe_log
              output_dir output_dir probe_log output_dir probe_log) };
    ]
  in
  shared @ dev

let llvm_binding_art =
  Canary_artifact.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs

(* The STORE-PIN plumbing (2026-08-12, the ssl/z3 mechanism on llvm): the
   stable chain's binding is Fetched@pinned — its fetch is a pin operation
   and its probe asserts the world. The dev binding probes the build tree
   (no store read) and the table-era dev chain has no Publish row. *)
let llvm_world_check (pin : string) =
  [%string
    {|eval $(opam env)
INSTALLED_LLVM=$(opam list llvm --installed --short --columns=version 2>/dev/null)
test "$INSTALLED_LLVM" = "%{pin}" || { echo "WORLD MISMATCH: switch has llvm $INSTALLED_LLVM, scenario declares llvm %{pin}"; exit 1; }
|}]

let realize (a : Canary_artifact.assignment) : Canary_step_builder.runner_spec =
  (* C2: dispatch on the SOURCE placement (the lib channel was the pre-C2
     proxy — the source row now pins per-repo identities, so the scenario's
     repo IS the source placement's id). *)
  let source = llvm_source_for_assignment a in
  let rows = llvm_table_rows ~source ~distro:(detect_distro ()) in
  let spec = Canary_action_templates.realize_from_rows ~assignment:a  rows in
  let binding_fetched =
    Canary_enumerate.equal_provision
      (Canary_enumerate.provision_of a llvm_binding_art)
      Canary_artifact.Fetched
  in
  let pin =
    (Canary_enumerate.version_of a llvm_binding_art).Canary_basic.id
  in
  { spec with
    expectation = (fun action loc ->
        Canary_scenario.lower_expectation_agnostic
          ~bindings:llvm_stable_contract_bindings ~langs:[ Canary_lang.OCaml ] action loc);
    (* stable chain: pin-checked fetch (the warm-skip only fires when the
       switch provably holds "19-shared") — the fetch cmd itself is the
       existing standard llvm.19-shared row. *)
    check_post =
      (fun action ->
        match action with
        | Canary_basic.Fetch (Canary_basic.Binding Canary_lang.OCaml)
          when binding_fetched ->
            Some (Canary_step_builder.pin_check_post ~pkg:"llvm" ~pin
                    ~marker:"binding.ok")
        | _ -> spec.check_post action);
    (* stable probe: world assertion — a drifted switch (e.g. the
       dev-shared the old runs left) fails loudly instead of silently
       compiling against the dev binding. *)
    probe_binding =
      (if binding_fetched then
         [ (Canary_lang.OCaml,
            Canary_store.Pm
              (Canary_store.Lang_pm
                 { lang = Canary_lang.OCaml; pm = Canary_store.Opam }),
            fun ~output_dir ~variant_key ->
              let base =
                Canary_step_builder.probe_ocaml_cmd ~binding_lib:"llvm"
                  ~example:"canary/examples/llvm/llvm_example_dev.ml"
                  ~target:"llvm_example_dev" ~output_dir ~variant_key
              in
              llvm_world_check pin ^ base) ]
       else spec.probe_binding);
  }

(** llvm as a [Canary_project_run.project_run] (`action llvm` →
    [run_project_run]) — the z3 shape verbatim; see [Canary_project_z3.z3_run]
    for the shared rationale (workspace ignored — guarded external build
    trees; locations inside the realization).

    [pr_mismatch_probes] is EMPTY for the same reason as z3's: the stable
    demo (llvm_example_dev.ml requires [Opcode.UncondBr], LLVM 21+, against
    the fetched 19 binding) is PROBE CODE vs the BINDING — not a
    binding↔native-lib channel pairing, and the OCaml binding isn't an
    enumerated axis. It stays declared where consumed
    ([llvm_stable_contract_bindings] → Expect_compat_failure → xfail; the
    dev chain's [has_manifest=false] keeps it Expect_success there). Unlike
    z3's scenario-invariant wheel demo, this one is chain-LOCAL (fires only
    in the stable chain) — but the discriminating axis is the binding's
    provision, which only joins the universe with version propagation. *)
let llvm_ci_spec _tola_root distro =
  let rows = llvm_table_rows ~source:llvm_source_stable ~distro in
  let a = Canary_artifact.[ (Canary_artifact.a_lib, { provision = Canary_artifact.Fetched; version = Canary_basic.good Canary_basic.Stable }) ] in
  Canary_action_templates.realize_from_rows ~assignment:a rows

let llvm_run _distro : Canary_project_run.project_run =
  { pr_name = "llvm";
    pr_artifacts = llvm_artifacts;
    pr_runner_spec = (fun a ~workspace:_ -> realize a);
    pr_mismatch_probes = [];
    (* the table-era dev chain has no Publish row (known omission — the
       pre-table era published llvm.dev-shared + conf-llvm-shared.dev);
       declare it empty so spec-check flags the gap. *)
    pr_wrapper_pkgs = [];
    pr_api_source = None;
    (* C2: FIVE scenarios — 3 all-Fetched source worlds (stable 19 /
       official latest / arbipher fork) + 2 source-built dev chains
       (official latest + fork; the heaviest of all — the batch default
       runs llvm THIN, stable fetch chain only). *)
    pr_binding_decls = llvm_binding_decls;
    (* the OCaml binding builds via the project's own target — raw, respected
       as-is (the mechanism template would say Dune); the Python binding
       is Dlopen (no template to override). *)
    pr_raw_build_overrides = [ (Canary_lang.OCaml, Canary_mechanism.Cstubs) ];
    pr_tier = Canary_project_run.Heavy }
