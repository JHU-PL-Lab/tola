open Base
open Tola_std
open Canary_store
open Canary_artifact_source
open Canary_artifact
open Canary_lang
open Canary_basic
open Canary_toolchain
open Canary

(* API source spec for z3 — native_api for the C API surface and in-tree
   language binding_apis with explicit requires declarations. *)
let z3_api_source : Canary_artifact.t =
  let native_api : Canary_artifact.native_api =
    {
      kind = C;
      components = [ Headers; Runtime_lib; Link_lib ];
      headers =
        Some
          {
            dir = "src/api";
            files =
              [
                "z3.h";
                "z3_algebraic.h";
                "z3_api.h";
                "z3_ast_containers.h";
                "z3_fixedpoint.h";
                "z3_fpa.h";
                "z3_macros.h";
                "z3_optimization.h";
                "z3_polynomial.h";
                "z3_rcf.h";
                "z3_spacer.h";
                "z3_v1.h";
              ];
          };
      symbol_prefixes = [ "Z3_" ];
      stable_symbols =
        [
          "Z3_mk_solver";
          "Z3_mk_optimize";
          "Z3_mk_context";
          "Z3_solver_check";
          "Z3_mk_optimize_assert_soft";
          "Z3_mk_seq_replace_re_all";
        ];
      versioned_symbols = [];
      soname    = None;
      c_runtime = None;
      cxx_abi   = None;
    }
  in
  let ocaml_binding : Canary_artifact.binding_api =
    {
      lang = OCaml;
      source_dir = Some "src/api/ml";
      (* mli-level watchlist (resolved against vals + constructors + modules
         under the package's filename-derived top-level prefix). *)
      module_watchlist =
        [ "Z3"; "Z3.Solver.add"; "Z3.Optimize.minimize"; "Z3.Expr.mk_app" ];
      type_watchlist = [];
    }
  in
  (* z3-solver is a pre-compiled pip wheel; source_dir marks in-tree source
     but the wheel is not packaged by canary — installed directly via pip. *)
  let python_binding : Canary_artifact.binding_api =
    {
      lang = Python;
      source_dir = Some "src/api/python/z3";
      (* Drift signal: parser_context is in the Z3 4.15+ Python source but
         not exported from `z3` namespace in the bundled z3-solver pip wheel
         (4.16 as of 2026-05-01). Listed here so the Fetch (Binding Python)
         summary reports it as missing; an Expect_compat_failure with
         Python_attrs then predicts the probe failure. Parallel to LLVM's
         Opcode.UncondBr at the C/OCaml level. *)
      module_watchlist =
        [
          "Solver";
          "BitVec";
          "Optimize";
          "Tactic";
          "Context";
          "Int";
          "Real";
          "Bool";
          "parser_context";
        ];
      type_watchlist = [];
    }
  in
  { native_api; binding_apis = [ ocaml_binding; python_binding ] }

(* ── Version specs ──
   Version is the primary key. Each version identifies both the source
   and which prebuilt libs (if any) exist for it.

   | Version | Source            | PM lib? | build_lib | build_binding |
   |---------|-------------------|---------|-----------|---------------|
   | dev     | arbipher/z3 HEAD  | no      | yes       | yes           |
   | latest  | Z3Prover/z3 HEAD  | no      | yes       | yes           |
   | 4.15.2  | Z3Prover/z3 tag   | yes     | no        | yes           |

   dev must build lib (no PM ships HEAD of a fork).
   latest must build lib (no PM ships official HEAD).
   stable can skip lib build (PM has this version). *)

let z3_source_dev : source_repo =
  {
    name = "z3";
    remote = Git_remote "https://github.com/arbipher/z3.git";
    locals = mk_locals "contrib/z3-all/z3";
    version = Canary_basic.{ channel = Dev; id = "" };
    ref_ = "HEAD";
    official = false;
    build_sys_deps = [ "cmake"; "ninja-build"; "libgmp-dev"; "python3-dev" ];
    api_source = Some z3_api_source;
  }

let z3_source_latest : source_repo =
  {
    name = "z3";
    remote = Git_remote "https://github.com/Z3Prover/z3.git";
    locals = [];
    version = Canary_basic.{ channel = Dev; id = "latest" };
    ref_ = "HEAD";
    official = true;
    build_sys_deps = [ "cmake"; "ninja-build"; "libgmp-dev"; "python3-dev" ];
    api_source = Some z3_api_source;
  }

let z3_source_stable : source_repo =
  {
    name = "z3";
    remote = Git_remote "https://github.com/Z3Prover/z3.git";
    locals = mk_locals "contrib/z3-all/z3-stable";
    version = Canary_basic.{ channel = Stable; id = "4.15.2" };
    ref_ = "bd3e722";
    official = true;
    (* No build — use fetch_binding (opam install z3) for the stable path.
       probe_binding_pkg will compile the example against the installed binding. *)
    build_sys_deps = [];
    (* Stable sources share the dev api_source — same project, same spec.
       Summary closures will warn when build_binding = false. *)
    api_source = Some z3_api_source;
  }

(* Channel-keyed source lookup. [Dev] = official [z3_source_latest]
   (2026-08-13 restored — the "official HEAD binding broken" finding was
   WRONG: the failure was the opam switch's stale dllz3ml.so shadowing
   the fresh one in z3's POST_BUILD self-check (CAML_LD_LIBRARY_PATH
   beats the bytecode's -dllpath); the build_binding row now guards the
   env. The arbipher fork ([z3_source_dev]) stays declared as the
   forked-dev candidate for the three-version report.) *)
let z3_source_of (ch : Canary_basic.channel) : source_repo =
  match ch with Canary_basic.Dev -> z3_source_latest | Canary_basic.Stable -> z3_source_stable

let z3_opam_spec : Canary_toolchain.opam_spec =
  {
    prefix_name = "Z3_PREFIX";
    prefix_var = "$Z3_PREFIX";
    prefix_envar = "${Z3_PREFIX}";
    libdir_name = "Z3_LIB_DIR";
    libdir_var = "$Z3_LIB_DIR";
    local_repo_name = "canary-local";
    package_name = "z3";
    package_version = "dev";
    canary_src_var = "CANARY_Z3_SRC";
  }

let z3_ocaml_config : Canary_toolchain.ocaml_tool_config =
  {
    toolchain = z3_opam_spec;
    ocaml =
      {
        example_target = "z3_example";
        example_name = "z3_example";
        example_file = "canary/examples/z3/z3_example.ml";
        binding_lib_name = "z3";
        build_api_path = Some "build/src/api/ml";
      };
    prebuilt = None;
  }

(* Probe references parser_context — present in Z3 4.15+ Python source but
   not exported by the z3-solver pip wheel (4.16 as of 2026-05-01). Probe
   fails with AttributeError; Expect_compat_failure { Python_attrs } derives
   the predicted substring from the cached Fetch (Binding Python) summary.
   Demonstrates L3 forward-incompat detection for Python (parallel to the
   LLVM 19 OCaml/L0 case). *)
let z3_python_config : Canary_toolchain.binding_config =
  Python_config
    {
      pip_package = Some "z3-solver";
      probe_snippet =
        {|import z3; s = z3.Solver(); x = z3.Int('x'); s.add(x > 0); print('z3 ok:', s.check()); _ = z3.parser_context|};
    }

(* Canonical cmake build flags for Z3 — single source of truth.
   Excludes: -S/-B paths, -DZ3_BUILD_OCAML_BINDINGS (caller sets per context). *)
let z3_cmake_build_flags =
  [
    "-G Ninja";
    "-DCMAKE_VERBOSE_MAKEFILE=ON";
    "-DZ3_BUILD_LIBZ3_SHARED=ON";
    "-DZ3_BUILD_EXECUTABLE=OFF";
    "-DZ3_BUILD_TEST_EXECUTABLES=OFF";
    "-DZ3_LINK_TIME_OPTIMIZATION=ON";
    "-DZ3_BUILD_JAVA_BINDINGS=OFF";
    "-DZ3_BUILD_PYTHON_BINDINGS=OFF";
  ]

let z3_cmake_build_flags_str ~indent =
  String.concat ~sep:(" \\\n" ^ indent) z3_cmake_build_flags

let opam_in_tpl_path ~tola_root =
  tola_root ^ "/canary/templates/opam-local-repo/packages/z3/z3.dev/opam.in.tpl"

let opam_in_path ~tola_root =
  tola_root ^ "/canary/templates/opam-local-repo/packages/z3/z3.dev/opam.in"

let render_opam_in ~tola_root =
  let tpl = read_file (opam_in_tpl_path ~tola_root) in
  let flags = z3_cmake_build_flags_str ~indent:"      " in
  let rendered =
    String.substr_replace_all tpl ~pattern:"%%Z3_CMAKE_BUILD_FLAGS%%"
      ~with_:flags
  in
  write_file (opam_in_path ~tola_root) rendered

(* ── Action steps (derived from runner_spec) ── *)

(* Resolve the native lib path based on whether we built it or fetched it.
   build tree: {build}/libz3.so  (or .dylib)
   system PM:  discovered at runtime via pkg-config *)
let lib_cmd_of_source ~has_build_lib ~build =
  if has_build_lib then
    (* Static path — known at spec generation time *)
    [%string
      {|LIB_Z3=$(ls %{build}/libz3.so %{build}/libz3.dylib 2>/dev/null | head -1)
test -n "$LIB_Z3"|}]
  else
    (* Dynamic discovery — resolved at probe runtime *)
    {|LIB_Z3=$(pkg-config --variable=libdir z3 2>/dev/null)/libz3.so
test -f "$LIB_Z3" || LIB_Z3=$(pkg-config --variable=libdir z3 2>/dev/null)/libz3.dylib
test -f "$LIB_Z3"|}

(* Resolve the binding archive paths based on whether we built it.
   build tree: {build}/src/api/ml/
   opam-installed: $(ocamlfind query z3)/ *)
let binding_dir_cmd_of_source ~has_build_binding ~build =
  if has_build_binding then
    [%string {|BINDING_DIR="%{build}/src/api/ml"
test -d "$BINDING_DIR"|}]
  else
    {|eval $(opam env)
BINDING_DIR=$(ocamlfind query z3 2>/dev/null)
test -d "$BINDING_DIR"|}

(** z3's contract bindings — the data half of the expectation
    lowering (Task 2 Phase E, 2026-07-21). Shared across dev / latest
    / stable variants because the Python probe consistently runs
    against the z3-solver pip wheel (which lacks parser_context
    regardless of which native z3 lib the OCaml side built against).

    Only one contract wired: c2 for Python at Probe_binding Python.
    OCaml probes fall through to Expect_success (no OCaml compat
    failure declared for z3 today). *)
let z3_contract_bindings : Canary_scenario.contract_binding list =
  let module CC = Canary_compat in
  let module CS = Canary_scenario in
  [
    { contract = CC.C2; lang = Canary_lang.Python;
      firings = [
        { site = CS.At_probe_binding Canary_lang.Python;
          loc_filter = CS.At_pm_lang Canary_lang.Python;
          source = CS.From_artifact {
            inputs = CC.[
              Python_attrs [ "fetch_binding_python/inspect.json" ];
            ];
            version_info = Some {
              provider_version = "z3-solver pip wheel";
              consumer_requires = "z3.parser_context";
              since = Some "Z3 4.15+ Python source (not yet exported in pip wheel)";
              note = None;
            };
          }};
      ]};
  ]

let mk_runner_spec ~source
    ?(binding_configs = [ Ocaml_config z3_ocaml_config; z3_python_config ])
    ?(tola_root = Unix.getcwd ())
    ?(build_lib = false) ?(build_binding = false)
    ?(cmake_build_binding = build_binding) distro :
    Canary_step_builder.runner_spec =
  let { version; _ } : source_repo = source in
  let ver_str = Canary_basic.string_of_version version in
  let local = local_for distro source in
  let root =
    match local with
    | Some l -> l.path
    | None ->
        [%string "_out/canary/projects/z3/%{ver_str}_%{source.ref_}/src"]
  in
  let build =
    match local with
    | Some l -> l.build_path
    | None ->
        [%string
          "_out/canary/projects/z3/%{ver_str}_%{source.ref_}/build"]
  in
  (* When no local checkout, opam fetches from the remote git URL directly.
     When a local checkout exists, opam installs from the local file:// path. *)
  let pack_src_url =
    match local with
    | Some l -> [%string "git+file://%{l.path}"]
    | None ->
        let (Git_remote url) = source.remote in
        [%string "git+%{url}"]
  in
  let pm = Canary_store.detect_pm () in
  let ocaml_tc =
    List.find_map binding_configs ~f:(function
      | Ocaml_config c -> Some c
      | Python_config _ -> None)
    |> Option.value_exn
         ~message:"z3 mk_runner_spec: no Ocaml_config in binding_configs"
  in
  let example = tola_root ^ "/" ^ ocaml_tc.ocaml.example_file in
  let target = ocaml_tc.ocaml.example_target in
  let binding_lib = ocaml_tc.ocaml.binding_lib_name in
  let lib_resolve =
    lib_cmd_of_source ~has_build_lib:build_lib ~build
  in
  let binding_resolve =
    binding_dir_cmd_of_source ~has_build_binding:build_binding ~build
  in
  {
    Canary_step_builder.empty_runner_spec with
    api_source = source.api_source;
    (* Skip fetch_source when opam will handle source fetching (pack_binding remote flow) *)
    fetch_source =
      (if build_lib || cmake_build_binding then
         Some
           (fun ~output_dir ~variant_key ->
             Canary_artifact_source.source_fetch_cmd distro source ~output_dir ~variant_key)
       else None);
    scan_source =
      (if build_lib || cmake_build_binding then
         Option.map source.api_source ~f:(fun api ->
             fun ~output_dir ~variant_key ->
              Canary_artifact_source.scan_source_cmd ~source_root:root api
                ~output_dir ~variant_key)
       else None);
    build_headers =
      (if build_lib || cmake_build_binding then
         Some
           (fun ~output_dir ~variant_key ->
             let hdr_ok = Canary_basic.variant_file ~variant_key "headers.ok" in
             [%string
               "test -f %{root}/src/api/z3.h \
                && echo 'ok' > %{output_dir}/%{hdr_ok}"])
       else None);
    configure =
      (if build_lib || cmake_build_binding then
         let cmake_exec =
           if cmake_build_binding then "opam exec -- cmake" else "cmake"
         in
         let ocaml_flag = if cmake_build_binding then "ON" else "OFF" in
         let flags =
           z3_cmake_build_flags
           @ [ [%string "-DZ3_BUILD_OCAML_BINDINGS=%{ocaml_flag}"] ]
         in
         Some
           (fun ~output_dir ~variant_key ->
             Canary_build_cmd.cmake_configure_cmd
               ~cmake_exec ~flags ~src:root ~build ()
             |> Canary_build_cmd.with_marker
                  ~marker:"conf.ok" ~output_dir ~variant_key)
       else None);
    build_lib =
      (if build_lib then
         Some
           (fun ~output_dir ~variant_key ->
             Canary_build_cmd.ninja_build_cmd ~target:"libz3" ~build ()
             |> Canary_build_cmd.with_marker
                  ~marker:"build.ok" ~output_dir ~variant_key)
       else None);
    build_binding =
      (if cmake_build_binding then
         [ (OCaml,
            fun ~output_dir ~variant_key ->
              let ninja_cmd =
                Canary_build_cmd.ninja_build_cmd
                  ~target:"build_z3_ocaml_bindings" ~build ()
              in
              Printf.sprintf "eval $(opam env) && %s" ninja_cmd
              |> Canary_build_cmd.with_marker
                   ~marker:"build.ok" ~output_dir ~variant_key) ]
       else []);
    install_lib =
      (if build_lib then
         Some (fun ~output_dir ~variant_key ->
           let install_ok = Canary_basic.variant_file ~variant_key "install.ok" in
           (* REAL install (2026-08-06; was a fake `cp` — TODO #40 / status
              §B build-config divergence slice (i)): [cmake_install_cmd]
              exercises the install-time transformations (headers + z3.pc +
              the Z3Config/-Version files land in the prefix; versioned
              symlink chain; RPATH handling), so the Staged probe tests a
              genuinely
              transformed artifact, not a hand-copied one. Safe for z3: the
              OCaml binding has NO install() rules
              (ops/install_targets.md) — nothing touches the opam switch.
              Guarded (`test -f`) per the PHONY-target / opam-sandbox
              gotchas. llvm deliberately NOT migrated: its install() rules
              auto-install the OCaml binding into the switch — needs
              component filtering first. *)
           let install =
             Canary_build_cmd.cmake_install_cmd ~build ~prefix:"$PREFIX" ()
           in
           [%string
             {|PREFIX="%{build}/../install"
test -f "$PREFIX/lib/libz3.so" || %{install}
echo 'ok' > %{output_dir}/%{install_ok}|}])
       else None);
    fetch_lib =
      Some
        (Canary_step_builder.Raw
        (fun ~output_dir ~variant_key ->
          let lib_ok = Canary_basic.variant_file ~variant_key "lib.ok" in
          let install = Canary_pm.install_cmd pm ~pkg:"z3" in
          [%string "%{install} && echo 'installed' > %{output_dir}/%{lib_ok}"]));
    fetch_binding =
      (let python_entry =
         List.filter_map binding_configs ~f:(function
           | Python_config p ->
               Some (Canary_lang.Python,
                     Canary_step_builder.Raw
                     (fun ~output_dir ~variant_key ->
                       Canary_toolchain.pip_install_cmd p ~output_dir ~variant_key))
           | Ocaml_config _ -> None)
       in
       python_entry);
    pack_binding =
      (if build_binding then
         [ (OCaml,
            fun ~output_dir ~variant_key ->
              let pkg_full = Canary_toolchain.pkg_full ocaml_tc.toolchain in
              let pack_repo = [%string "%{output_dir}/pack-repo"] in
              let pkg_dir =
                [%string
                  "%{pack_repo}/packages/%{ocaml_tc.toolchain.package_name}/%{pkg_full}"]
              in
              let repo_name =
                [%string "%{ocaml_tc.toolchain.local_repo_name}-pack"]
              in
              let src_template =
                [%string
                  "%{tola_root}/canary/templates/opam-local-repo/packages/%{ocaml_tc.toolchain.package_name}/%{pkg_full}/opam.in"]
              in
              let src_var = ocaml_tc.toolchain.canary_src_var in
              let preamble =
                [%string
                  {|mkdir -p "%{pkg_dir}"
cp "%{src_template}" "%{pkg_dir}/opam.in"
(cd "%{pack_repo}" && OPAMVAR_%{src_var}="%{pack_src_url}" opam config subst "packages/%{ocaml_tc.toolchain.package_name}/%{pkg_full}/opam")|}]
              in
              (* When opam fetches from a remote URL, the source is in the opam
                 build dir (S=. by default). Don't pass CANARY_SRC/BUILD_DIR or
                 opam will try to use a relative path that doesn't exist there. *)
              let env_prefix =
                match local with
                | Some _ ->
                    [%string
                      {|OPAMVAR_%{ocaml_tc.toolchain.prefix_name}="%{build}" OPAMVAR_%{ocaml_tc.toolchain.libdir_name}="%{build}" CANARY_BUILD_DIR="%{build}" CANARY_SRC_DIR="%{root}" |}]
                | None -> ""
              in
              opam_pack_cmd ~repo_name ~repo_abs:pack_repo ~pkg_full ~preamble
                ~env_prefix ~output_dir ~variant_key ()) ]
       else []);
    probe_lib =
      List.filter_opt
        [
          (if build_lib then
             Some
               ( Build_tree,
                 fun ~output_dir ~variant_key ->
                   let resolve =
                     [%string
                       {|LIB_Z3=$(ls %{build}/libz3.so %{build}/libz3.dylib 2>/dev/null | head -1)
test -n "$LIB_Z3"|}]
                   in
                   [%string
                     "%{resolve}\n%{Canary_artifact_native.native_lib_probe_cmd ~lib:\"$LIB_Z3\" ~prefix:\"Z3_\" ~output_dir ~variant_key}"])
           else None);
          (if build_lib then
             Some
               ( Staged,
                 fun ~output_dir ~variant_key ->
                   let lib = [%string "%{build}/../install/lib/libz3.so"] in
                   Canary_artifact_native.native_lib_probe_cmd ~lib ~prefix:"Z3_"
                     ~output_dir ~variant_key )
           else None);
          Some
            ( Pm (Sys_pm { pm }),
              fun ~output_dir ~variant_key ->
                let resolve =
                  {|LIB_Z3=$(pkg-config --variable=libdir z3 2>/dev/null)/libz3.so
test -f "$LIB_Z3" || LIB_Z3=$(pkg-config --variable=libdir z3 2>/dev/null)/libz3.dylib
test -f "$LIB_Z3"|}
                in
                [%string
                  "%{resolve}\n%{Canary_artifact_native.native_lib_probe_cmd ~lib:\"$LIB_Z3\" ~prefix:\"Z3_\" ~output_dir ~variant_key}"] );
        ];
    probe_binding =
      List.filter_opt
        [
          (* Build_tree: probe against build tree artifacts (only when cmake built them) *)
          (if build_binding && cmake_build_binding then
             Some
               ( Canary_lang.OCaml, Build_tree,
                 fun ~output_dir ~variant_key ->
                   let script = "canary/scripts/assert_binary_symbols.py" in
                   let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
                   let symbols_log = Canary_basic.variant_file ~variant_key "symbols.log" in
                   [%string
                     {|%{lib_resolve}
%{binding_resolve}
STUB=$(ls "$BINDING_DIR"/libz3ml.a 2>/dev/null | head -1)
test -n "$STUB"
python3 %{script} --provided-lib "$LIB_Z3" --required-lib "$STUB" \
  --symbol-prefix Z3_ 2>&1 | tee %{output_dir}/%{symbols_log}
grep -q 'OK:' %{output_dir}/%{symbols_log}
eval $(opam env)
ocamlfind ocamlopt -package zarith -linkpkg \
  -I "$BINDING_DIR" "$BINDING_DIR"/z3ml.cmxa %{example} \
  -o %{output_dir}/%{target} > %{output_dir}/%{probe_log} 2>&1 || exit 1
%{output_dir}/%{target} >> %{output_dir}/%{probe_log} 2>&1|}]
               )
           else None);
          (* Lang_pm: probe against opam-installed package *)
          Some
            ( Canary_lang.OCaml, Pm (Lang_pm { lang = OCaml; pm = Opam }),
              fun ~output_dir ~variant_key ->
                let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
                [%string
                  {|eval $(opam env)
ocamlfind ocamlopt -package %{binding_lib} -linkpkg %{example} \
  -o %{output_dir}/%{target} > %{output_dir}/%{probe_log} 2>&1 || exit 1
%{output_dir}/%{target} >> %{output_dir}/%{probe_log} 2>&1|}]
            );
        ]
      @ List.filter_map binding_configs ~f:(function
        | Python_config p ->
            (* Install split off into Fetch (Binding Python); probe is
               import-only here so the cached summary from fetch is
               available to expectation evaluation. *)
            Some (Canary_lang.Python, Pm (Lang_pm { lang = Python; pm = Pip }),
                  fun ~output_dir ~variant_key ->
                    Canary_toolchain.python_probe_only_cmd p ~output_dir ~variant_key)
        | Ocaml_config _ -> None);
    check_post =
      (function
      | Fetch Source -> Some Canary_artifact_source.source_check_post
      | Configure ->
          Some
            (fun ~output_dir ~variant_key ->
              Canary_step_builder.check_markers [ "conf.ok" ] ~output_dir ~variant_key
              || Stdlib.Sys.file_exists [%string "%{build}/CMakeCache.txt"])
      | Build_lib ->
          Some
            (Canary_step_builder.check_build_lib ~marker:"build.ok"
               ~lib_path:[%string "%{build}/libz3.so"])
      | Build_binding _ ->
          Some
            (Canary_step_builder.check_build_binding ~marker:"build.ok"
               ~archive_path:[%string "%{build}/src/api/ml/z3ml.cmxa"])
      | Fetch (Binding _) when not build_binding ->
          let pkg = [%string "z3.%{ver_str}"] in
          Some
            (fun ~output_dir ~variant_key ->
              Canary_step_builder.check_markers [ "binding.ok" ] ~output_dir ~variant_key
              || Canary_pm_opam.is_installed ~pkg)
      | _ -> None);
    binding_user_facing_pkg = [ (OCaml, "z3"); (Python, "z3") ];
    (* A7 phase 3 (2026-08-05) — ORACLE → DERIVED. Was
       [lower_expectation ~violates:[C2] ~has_manifest:true] (the project
       TOLD the runner which contract breaks); now the agnostic lowering
       emits [Expect_compat_derived] at the declared firing site and the
       RUNNER decides by inspecting the cached wheel inspect: parser_context
       missing → must-fail with that signature (xfail [c2], both chains —
       the wheel is scenario-invariant); if a future wheel exports it, the
       prediction comes back empty and the probe is expected to SUCCEED
       (self-healing — no spec edit). Everything outside the declared
       firing site falls through to Expect_success as before. *)
    expectation =
      Canary_scenario.lower_expectation_agnostic
        ~bindings:z3_contract_bindings
        ~langs:[ Canary_lang.Python ];
    inspect_note =
      (if not build_binding then
         Some
           (Canary_artifact.stable_reuse_warning ~source_name:"z3"
              ~source_version:ver_str)
       else None);
    inspect =
      (fun action _loc ->
        let api =
          Option.value_exn source.api_source
            ~message:"z3 mk_runner_spec: api_source not set"
        in
        let warn =
          if not build_binding then
            Some
              (Canary_artifact.stable_reuse_warning ~source_name:"z3"
                 ~source_version:ver_str)
          else None
        in
        let prepend_warn cmd =
          match warn with None -> cmd | Some w -> [%string "%{w}\n%{cmd}"]
        in
        match action with
        | Probe_lib ->
            Some
              (fun ~output_dir ~variant_key ->
                let sum =
                  Canary_artifact_native.inspect_cmd ~lib:"$LIB_Z3"
                    ~prefixes:[ "Z3_"; "Z3_mk_"; "Z3_solver_" ]
                    ~watchlist:(Canary_artifact.native_watchlist api)
                    ~output_dir ~variant_key ()
                in
                prepend_warn [%string "%{lib_resolve}\n%{sum}"])
        | _ -> None);
    artifact_name = (function
      | Canary_basic.Lib -> Some "libz3.so"
      | Canary_basic.Binding Canary_lang.OCaml -> Some "z3"
      | Canary_basic.Binding Canary_lang.Python -> Some "z3-solver"
      | _ -> None);
  }

(* ── A5 phase 1: the DECLARED spec (stage 1, ssot §4.2) — no behavior change ──
   z3's static option space as ONE data table ([ps_universe], A8). The general
   enumerate ([full_policy]) + the source-primary filter ([assignment_ok]:
   a Built lib inherits the source's version) yield exactly the CURRENT two
   variants as scenarios:

     - dev    = source Fetched@Dev + lib Built@Dev        (the build chain)
     - stable = source Fetched@Stable + lib Fetched@Stable (the fetch chain)

   Three assignments survive the product-then-filter: the pruned one is
   (source@Stable × lib Built@Dev) — the incoherent build the source-primary
   filter exists for. The third, (source@Dev × lib Fetched@Stable), is the
   SAME world as stable under scenario identity: a Fetched artifact is
   version-ambient (the PM/opam picks), so its declared channel is dropped
   from the scenario id ([canary_main.scenario_dir_of]) and the two
   all-Fetched assignments dedup to ONE stable scenario. Order is meaningful
   (head = Free-level representative / baseline): Stable-first, so the
   baseline is the all-Fetched chain (as sqlite) and both surviving
   representatives are channel-coherent.

   The Python wheel (z3-solver) is Fetched@Stable in BOTH variants — a
   constant, variant-invariant row. (Declared with the lang's default
   mechanism [Cext], matching every existing view — `scenarios --engine`
   renders bindings via [default_mechanism_of_lang]; the wheel is really
   ctypes-based, so flipping this rides the deferred Dynamic_ffi round,
   ssot §4.2.1b.)

   The OCaml binding is deliberately NOT in the enumerated universe yet: its
   provision follows the chain (Built@Dev in dev, opam-fetched in stable),
   and the flat product cannot express "follows the built chain" — declaring
   both options would mint the two mixed worlds (dev binding over stable
   lib / opam binding over dev-built lib), i.e. mismatch scenarios that are
   NOT the current variant set. It joins the universe with graph-structural
   version propagation (build edges propagate source@v → lib@v → binding@v;
   cross-version pairing only on a declared mismatch edge — status §A),
   which is exactly the abstraction A5 is the forcing function for. Until
   then the binding rides INSIDE the realization (phase 2's
   dispatch/realize), like the probe locations (phase 3). *)
(* Per-artifact providers — declared once, shared by [pr_artifacts] and
   [ps_universe] so the runtime-edge mode is derivable (A5 residue (ii)). *)
let z3_python_provider =
  Canary_store_config.Lang_pkg
    { lang = Canary_lang.Python; pm = Canary_store.Pip; package = "z3-solver";
      self_contained = true; versions = None }

let z3_spec : Canary_artifact.project_spec =
  { ps_universe =
      Canary_enumerate.
        [ (a_source, axes [ (Fetched, Canary_basic.[ Stable; Dev ]) ]);
          ( a_lib,
            axes
              [ (Fetched, [ Canary_basic.Stable ]);
                (Built, [ Canary_basic.Dev ]) ] );
          ( a_binding Canary_lang.Python Canary_mechanism.Cext,
            (* self-contained pip wheel (co-provider, backlog #45): z3-solver
               bundles its own libz3 → Ambient derived from the provider. *)
            let runtime =
              Canary_store_config.dep_mode_of_provider z3_python_provider
            in
            axes ?runtime
              [ (Fetched, [ Canary_basic.Stable ]) ] );
          ( a_binding Canary_lang.OCaml Canary_mechanism.Cstubs,
            (* binding-follows-chain (A5 residue (iii), 2026-08-06): the
               OCaml binding's version follows the lib's — Built@Dev in the
               dev chain, Fetched@Stable in the stable chain. The follows
               constraint prunes the two cross-channel mismatch pairs. *)
            axes ~follows:a_lib
              [ (Built, [ Canary_basic.Dev ]);
                (Fetched, [ Canary_basic.Stable ]) ] ) ] }

(* ── A5 phase 2: dispatch / realization split + the [project_run] ── *)

(** THE artifact table (2026-08-06: identity + provider per row — the old
    separate [z3_providers] assoc merged in, user-directed). Wider than
    [z3_spec.ps_universe]: the OCaml binding row is display-only (no
    baseline placement → no drift check) — the opam `z3` package the
    stable chain's probe compiles against; it is not an enumerated axis
    yet (see the [z3_spec] comment — it follows the chain). Providers are
    the detail behind each artifact's BASELINE provision (the all-Fetched
    stable chain), which is what `spec`'s drift check compares against.
    Per-CHANNEL providers (the arbipher fork the dev chain fetches, the
    dev-built lib) are the realization's concern below; a provider keyed
    by (artifact × channel) — which would also let a project PIN a
    Fetched version — is the not-yet-wired provenance refinement
    (status §A / the Fetched-ambient gotcha). *)
let z3_artifacts : Canary_project_spec.artifact_row list =
  let open Canary_project_spec in
  [ artifact_row ~artifact:a_source
      ~universe:[ (Fetched, Canary_basic.[ Stable; Dev ]) ]
      ~provider:(Canary_store_config.Source_repo z3_source_stable) ();
    artifact_row ~artifact:a_lib
      ~universe:[ (Fetched, [ Canary_basic.Stable ]);
                  (Built, [ Canary_basic.Dev ]) ]
      ~provider:
        (Canary_store_config.Sys_pkg
           (Canary_store.mk_system_package_spec ~linux_pkg:"z3"
              ~macos_pkg:"z3" ())) ();
    artifact_row ~artifact:(a_binding Canary_lang.OCaml Canary_mechanism.Cstubs)
      ~follows:a_lib
      ~universe:[ (Built, [ Canary_basic.Dev ]);
                  (Fetched, [ Canary_basic.Stable ]) ]
      ~provider:
        (Canary_store_config.Lang_pkg
           { lang = Canary_lang.OCaml; pm = Canary_store.Opam;
             package = "z3"; self_contained = false;
             (* STORE PIN (2026-08-12): the Fetched binding pins the
                opam-repo version the stable chain probes against (the
                opam package version — the store's own record; the dev
                chain's z3.dev reports "dev"). The dev binding is BUILT —
                its Publish carries its own pin-check. *)
             versions =
               Some
                 [ { Canary_store_config.pin_version = "4.16.0";
                     install_name = None } ] })
      ();
    artifact_row ~artifact:(a_binding Canary_lang.Python Canary_mechanism.Cext)
      ~universe:[ (Fetched, [ Canary_basic.Stable ]) ]
      ~provider:z3_python_provider () ]

(* ── dispatch / realization split (the A9-step-1 structure) ──
   [scenario_case] is the PURE dispatch result — inspectable data computed
   from enumeration coordinates only ([Canary_enumerate.provision_of]);
   [realize] maps a case to its command templates, which are EXACTLY the
   existing [mk_runner_spec ~source:…] raw specs (command churn zero — the
   whole hand-written spec IS the realization; decomposing it into shared
   templates is A9-step-2). *)
(* dispatch is now universal: [Canary_action_table.dispatch] *)

(* ── A9-step-2: action-variant table ── *)
let z3_table_rows ~(chan : Canary_basic.channel) ~distro =
  let open Canary_action_table in
  let source = z3_source_of chan in
  let { version; ref_; name; remote; _ } : Canary_artifact_source.source_repo = source in
  let ver_str = Canary_basic.string_of_version version in
  let local = Canary_artifact_source.local_for distro source in
  let root =
    match local with
    | Some l -> l.path
    | None -> Printf.sprintf "_out/canary/projects/z3/%s_%s/src" ver_str ref_
  in
  let build =
    match local with
    | Some l -> l.build_path
    | None -> Printf.sprintf "_out/canary/projects/z3/%s_%s/build" ver_str ref_
  in
  let (Canary_artifact_source.Git_remote url) = remote in
  let cmake_build_binding =
    match version.Canary_basic.channel with Canary_basic.Dev -> true | _ -> false
  in
  let shared =
    [ { ar_action = Canary_basic.Fetch Canary_basic.Lib;
        ar_template = Primitive ("fetch_lib",
                        [ ("linux_pkg", "libz3-dev"); ("macos_pkg", "z3") ]) };
      { ar_action = Canary_basic.Fetch (Canary_basic.Binding Canary_lang.Python);
        ar_template = Primitive ("pip_install", [ ("pkg", "z3-solver") ]) };
      { ar_action = Canary_basic.Probe_binding Canary_lang.Python;
        ar_template = Primitive ("python_probe",
                        [ ("snippet", "import z3; s = z3.Solver(); s.add(z3.Int('x') > 0); \
                           print('z3 ok:' + str(s.check()))") ]) };
      { ar_action = Canary_basic.Probe_binding Canary_lang.OCaml;
        ar_template = Primitive ("ocaml_probe",
                        [ ("binding_lib", "z3");
                          ("example", "canary/examples/z3/z3_example.ml");
                          ("target", "z3_example") ]) };
      { ar_action = Canary_basic.Probe_lib;
        ar_template = Primitive ("native_lib_probe",
                        [ ("location", "pm"); ("pm_pkg", "z3"); ("prefix", "Z3_"); ("lib_name", "libz3.so") ]) };
    ]
  in
  let dev =
    [ { ar_action = Canary_basic.Fetch Canary_basic.Source;
        ar_template = Primitive ("source_fetch",
                        [ ("name", name); ("ver_str", ver_str);
                          ("ref_", ref_); ("url", url) ]) };
      { ar_action = Canary_basic.Scan_sources;
        ar_template = Primitive ("scan_source",
                        [ ("root", root); ("hdr_file", "src/api/z3.h") ]) };
      { ar_action = Canary_basic.Build_headers;
        ar_template = Primitive ("build_headers",
                        [ ("root", root); ("hdr_dir", "src/api") ]) };
      { ar_action = Canary_basic.Configure;
        ar_template = Primitive ("cmake_configure",
                        [ ("cmake_exec", if cmake_build_binding then "opam exec -- cmake" else "cmake");
                          (* -G Ninja is REQUIRED: without it cmake defaults to
                             Unix Makefiles and the ninja_build step finds no
                             build.ninja (the old mk_runner_spec's flags had
                             it; the table row dropped it). *)
                          ("flags", "-G Ninja -DZ3_BUILD_LIBZ3_SHARED=TRUE -DZ3_BUILD_OCAML_BINDINGS="
                                    ^ (if cmake_build_binding then "ON" else "OFF"));
                          ("src", root); ("build", build) ]) };
      { ar_action = Canary_basic.Build_lib;
        ar_template = Primitive ("ninja_build", [ ("target", "libz3"); ("build", build) ]) };
      { ar_action = Canary_basic.Install_lib;
        ar_template = Primitive ("cmake_install",
                        [ ("build", build); ("prefix", build ^ "/../install") ]) };
      { ar_action = Canary_basic.Build_binding Canary_lang.OCaml;
        ar_template = Primitive ("ninja_build_binding",
                        [ ("target", "build_z3_ocaml_bindings"); ("build", build);
                          (* The binding target's POST_BUILD self-check runs the
                             bytecode + native examples with AMBIENT dll search:
                             the switch's stale dllz3ml.so (pinned z3 / z3.dev)
                             shadows the fresh one (CAML_LD_LIBRARY_PATH beats the
                             bytecode's -dllpath — reproduced 2026-08-13 as
                             "unknown C primitive 'n_solver_register_on_clause'"),
                             and the native run's libz3.so needs LD_LIBRARY_PATH
                             (the CMakeLists' DYLD_LIBRARY_PATH is a macOS no-op).
                             Prefix the build dir so the self-check sees the
                             artifact it just built. *)
                          (* $(pwd): the guard paths must be ABSOLUTE — the
                             POST_BUILD self-check runs from <build>/src/api/ml,
                             so a relative entry resolves against the wrong cwd
                             and the stale stublibs dll wins again. *)
                          ("env_guard",
                           Printf.sprintf "CAML_LD_LIBRARY_PATH=$(pwd)/%s/src/api/ml:$CAML_LD_LIBRARY_PATH LD_LIBRARY_PATH=$(pwd)/%s"
                             build build) ]) };
      { ar_action = Canary_basic.Probe_lib;
        ar_template = Primitive ("native_lib_probe",
                        [ ("location", "build_tree"); ("build", build); ("lib_glob", "libz3.so");
                          ("prefix", "Z3_") ]) };
      { ar_action = Canary_basic.Probe_lib;
        ar_template = Primitive ("native_lib_probe",
                        [ ("location", "staged");
                          ("lib", build ^ "/../install/lib/libz3.so");
                          ("prefix", "Z3_") ]) };
      { ar_action = Canary_basic.Probe_binding Canary_lang.OCaml;
        ar_template = Raw (fun ~output_dir ~variant_key ->
            let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
            let symbols_log = Canary_basic.variant_file ~variant_key "symbols.log" in
            (* -cclib "$LIB_Z3": the cmxa embeds `-L<stublibs> -L<build> -lz3`
               — the STORE's stale libz3.so wins the -lz3 search (stublibs
               first) and the link dies on any API the store lacks (finite-set
               at official HEAD). The full-path arg precedes it, so the exe
               links the BUILT lib. Same shadowing class as the env_guard. *)
            Printf.sprintf
              "eval $(opam env) && \
               LIB_Z3=$(ls %s/libz3.so %s/libz3.dylib 2>/dev/null | head -1) && \
               test -n \"$LIB_Z3\" && \
               BINDING_DIR=%s/src/api/ml && \
               STUB=$(ls \"$BINDING_DIR\"/libz3ml.a 2>/dev/null | head -1) && \
               test -n \"$STUB\" && \
               python3 canary/scripts/assert_binary_symbols.py \
                 --provided-lib \"$LIB_Z3\" --required-lib \"$STUB\" \
                 --symbol-prefix Z3_ > %s/%s 2>&1 && \
               ocamlfind ocamlopt -package zarith -linkpkg \
                 -cclib \"$LIB_Z3\" \
                 -I \"$BINDING_DIR\" \"$BINDING_DIR\"/z3ml.cmxa \
                 canary/examples/z3/z3_example.ml -o %s/z3_example > %s/%s 2>&1 && \
               %s/z3_example >> %s/%s 2>&1 && \
               cat %s/%s"
              build build build output_dir symbols_log
              output_dir output_dir probe_log
              output_dir output_dir probe_log
              output_dir probe_log) };
      { ar_action = Canary_basic.Publish (Canary_basic.Binding Canary_lang.OCaml);
        ar_template = Raw (fun ~output_dir ~variant_key ->
            (* CANARY_* must be ABSOLUTE: the z3.dev package script runs from
               the opam sandbox build dir, where relative `_out/...` paths
               don't exist (the configure step dies). Local checkout paths
               are already absolute. *)
            let abs p = if String.is_prefix p ~prefix:"/" then p else "$(pwd)/" ^ p in
            Printf.sprintf
              "eval $(opam env) && \
               PREFIX=%s LIB_DIR=%s CANARY_BUILD_DIR=%s CANARY_SRC_DIR=%s opam install -y z3.dev \
                 --verbose --keep-build-dir --assume-depexts && \
               echo 'ok' > %s/%s"
              (abs build) (abs build) (abs build) (abs root) output_dir
              (Canary_basic.variant_file ~variant_key "pack.ok")) };
    ]
  in
  shared @ dev

let z3_binding_art =
  Canary_artifact.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs

(* The STORE-PIN plumbing (2026-08-12, the ssl mechanism on z3): the
   stable chain's binding is Fetched@pinned — its fetch is a pin
   operation and its probe asserts the world; the dev chain's Publish
   carries its own pin-check so a stale switch can't serve a silent
   wrong-version probe. *)
let z3_world_check (pin : string) =
  [%string
    {|eval $(opam env)
INSTALLED_Z3=$(opam list z3 --installed --short --columns=version 2>/dev/null)
test "$INSTALLED_Z3" = "%{pin}" || { echo "WORLD MISMATCH: switch has z3 $INSTALLED_Z3, scenario declares z3 %{pin}"; exit 1; }
|}]

let realize a =
  let chan = match Canary_enumerate.provision_of a Canary_artifact.a_lib with
    | Canary_artifact.Built -> Canary_enumerate.channel_of a Canary_artifact.a_lib | _ -> Canary_basic.Stable
  in
  let spec = Canary_action_table.realize (z3_table_rows ~chan ~distro:(detect_distro ())) a in
  let binding_fetched =
    Canary_enumerate.equal_provision
      (Canary_enumerate.provision_of a z3_binding_art)
      Canary_artifact.Fetched
  in
  let pin =
    (Canary_enumerate.version_of a z3_binding_art).Canary_basic.id
  in
  (* expectation stays hand-wired: contract bindings are project data *)
  { spec with
    expectation = (fun action loc ->
        Canary_scenario.lower_expectation_agnostic
          ~bindings:z3_contract_bindings ~langs:[ Canary_lang.Python ] action loc);
    (* stable chain: the pinned binding fetch (was ambient pre-install —
       unmodeled global state; now an explicit pin operation) + the
       pin-checked postcondition. *)
    fetch_binding =
      (if binding_fetched then
         [ (Canary_lang.OCaml,
            Canary_step_builder.Raw
              (Canary_step_builder.fetch_binding_cmd
                 (Canary_toolchain.mk_opam_package_spec
                    ~install_name:[%string "z3.%{pin}"] ()))) ]
       else spec.fetch_binding);
    check_post =
      (fun action ->
        match action with
        | Canary_basic.Fetch (Canary_basic.Binding Canary_lang.OCaml)
          when binding_fetched ->
            Some (Canary_step_builder.pin_check_post ~pkg:"z3" ~pin
                    ~marker:"binding.ok")
        | Canary_basic.Publish (Canary_basic.Binding Canary_lang.OCaml) ->
            (* the dev chain's store mutation is verified, not just "ran":
               a warm-skipped publish only fires when the switch provably
               holds the published state. *)
            Some (Canary_step_builder.pin_check_post ~pkg:"z3" ~pin:"dev"
                    ~marker:"pack.ok")
        | _ -> spec.check_post action);
    (* stable probe: world assertion (the switch must hold the pin) — a
       drifted switch fails loudly instead of silently compiling against
       the dev binding (the A7 finding (a) crossing). *)
    probe_binding =
      (if binding_fetched then
         [ (Canary_lang.OCaml,
            Canary_store.Pm
              (Canary_store.Lang_pm
                 { lang = Canary_lang.OCaml; pm = Canary_store.Opam }),
            fun ~output_dir ~variant_key ->
              let base =
                Canary_step_builder.probe_ocaml_cmd ~binding_lib:"z3"
                  ~example:"canary/examples/z3/z3_example.ml"
                  ~target:"z3_example" ~output_dir ~variant_key
              in
              z3_world_check pin ^ base) ]
       else spec.probe_binding);
    inspect = (fun action _loc ->
        match action with
        | Canary_basic.Probe_lib ->
            Some (fun ~output_dir ~variant_key ->
                let lib_resolve = "LIB_Z3=$(pkg-config --variable=libdir z3 2>/dev/null)/libz3.so" in
                Printf.sprintf "%s\n%s" lib_resolve
                  (Canary_artifact_native.inspect_cmd ~lib:"$LIB_Z3"
                     ~prefixes:[ "Z3_"; "Z3_mk_"; "Z3_solver_" ] ~output_dir ~variant_key ()))
        | _ -> None);
  }

(** z3 as a [Canary_project_run.project_run] — the generic path (`action z3`
    → [canary_main.run_project_run]: enumerate → runner_spec → run), same as
    sqlite/tiny-full. [z3_run] IS the project identity (ssot §6.1). A
    function of [distro] (the realizations resolve local checkouts + PM
    commands per distro); the closures stay lazy — nothing shells out until
    a step runs.

    The runner-provided [workspace] is IGNORED by the realizations: z3
    builds into its guarded external trees (the contrib checkout's
    build dir, `test -f`-guarded cmake — see the opam-sandbox gotcha), so a
    scenario-id change never forces a z3 rebuild. Probe LOCATIONS
    (build-tree / staged / sys-PM, 3 probe_lib steps in the dev chain) stay
    INSIDE the realization — the location sub-axis is deliberately not
    modeled (A5 phase 3; it is A9-step-2's acceptance test).

    [pr_mismatch_probes] is EMPTY, deliberately: the stable-wheel demo (the
    Python probe requires [z3.parser_context]; the z3-solver wheel doesn't
    export it) does NOT fit the (consumer × channel × direction-vs-lib)
    frame — its version-sensitive requirement is in the PROBE CODE against
    the BINDING (the wheel, which bundles its own libz3), not a
    binding↔native-lib channel pairing, and it is SCENARIO-INVARIANT (the
    wheel is Fetched@Stable everywhere, so the xfail fires in every world —
    the Ambient-edge finding). It stays declared where it is consumed:
    [z3_contract_bindings] → [lower_expectation_agnostic] →
    Expect_compat_derived → xfail [c2] in `action`/`status`/`spec` (A7
    phases 2+3). Folding probe-level roles into the design-intent table is
    A7 residue. *)
(* CI spec: same as Dev_chain but without cmake steps (build_lib=false,
   cmake_build_binding=false). The opam pack_binding step still runs. *)
let z3_ci_spec _tola_root distro =
  let open Canary_action_table in
  let rows = z3_table_rows ~chan:Canary_basic.Dev ~distro in
  let no_cmake (row : action_row) =
    match row.ar_action with
    | Configure | Build_lib | Build_headers | Install_lib -> false
    | Fetch Source | Scan_sources -> false
    | _ -> true
  in
  let filtered = List.filter rows ~f:no_cmake in
  let a = Canary_artifact.[ (Canary_artifact.a_lib, { provision = Canary_artifact.Built; version = Canary_basic.good Canary_basic.Dev }) ] in
  realize_from_rows ~assignment:a filtered

let z3_run _distro : Canary_project_run.project_run =
  { pr_name = "z3";
    pr_artifacts = z3_artifacts;
    pr_runner_spec = (fun a ~workspace:_ -> realize a);
    pr_mismatch_probes = [];
    (* the dev-source wrapper: the Publish row installs our z3.dev opam
       package over the built tree (pin-checked "dev" on the store). *)
    pr_wrapper_pkgs = [ (Canary_lang.OCaml, "z3.dev") ];
    pr_api_source = None;
    (* source-built dev chain (~15-40 min cold) — the batch default runs
       z3 THIN (stable fetch chain only). *)
    pr_tier = Canary_project_run.Heavy }
