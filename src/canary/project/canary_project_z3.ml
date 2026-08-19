open Base
open Tola_std
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
     but the wheel is not packaged by canary — installed directly via pip.
     The wheel BUNDLES libz3 and loads it via ctypes at runtime — no
     compiled extension the binding produces — so the binding's honest
     mechanism is Ctypes (the artifact table's previous Cext declaration
     was wrong, fixed 2026-08-17). CODE-GEN caveat (explicit): parts of
     src/api/python are build-generated (scripts/update_api.py) — the
     faithful source exists only post-build. The static spec reads
     nothing from them (declaration only); the runtime probe uses the
     Fetched wheel, where the generated files exist. *)
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

(* ── binding declarations (M2 step 4, 2026-08-17) ──
   - OCaml cstubs: the FAITHFUL source is build-generated — api/ml
     carries z3native.ml.pre / z3native_stubs.c.pre TEMPLATES
     (scripts/update_api.py); the real z3native.ml/.c exist only in a
     built tree. The static spec reads nothing from them (declaration
     only); runtime inspect/probe uses the built products (z3ml.cmxa +
     libz3ml.a, built by the project's build target).
   - Python: wheel-bundled libz3 loaded via ctypes — Dlopen, no
     compile stage. *)
let z3_binding_decls : Canary_binding_decl.binding_decl list =
  let open Canary_binding_decl in
  let c_api =
    { functions =
        [ "Z3_mk_solver"; "Z3_mk_optimize"; "Z3_mk_context";
          "Z3_solver_check"; "Z3_mk_optimize_assert_soft";
          "Z3_mk_seq_replace_re_all" ];
      (* the declared stable subset (mirrors the api_source watch) *)
      enums = [] }
  in
  let native =
    { prefix = "Z3_";
      soname = "libz3.so";
      headers = { dir = "src/api"; files = [ "z3_api.h" ] } }
  in
  [ { mechanism = Canary_mechanism.Cstubs;
      c_api; native;
      coupling =
        Stub_archive
          { sources = [ "src/api/ml/z3native_stubs.c.pre" ];
            archive = "libz3ml.a" };
      surface_path = "src/api/ml/z3.mli" };
    { mechanism = Canary_mechanism.Ctypes;
      c_api; native;
      coupling = Dlopen { name = "libz3.so" };
      surface_path = "src/api/python/z3/__init__.py" } ]

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
    remote = Some (Git "https://github.com/arbipher/z3.git");
    locals = mk_locals "contrib/z3-all/z3";
    (* C2 (2026-08-16): [id = "arbipher"] — identity-bearing, a marker-style
       id like "latest" (the fork tracks HEAD; the FORK ITSELF is the
       identity). The three-version report needs official-dev and
       forked-dev as DISTINCT scenarios (the 2026-08-13 finding: both
       declare ref_ = HEAD, ambient identity would collide them). *)
    version = Canary_basic.{ channel = Dev; id = "arbipher" };
    ref_ = "HEAD";
    official = false;
    build_sys_deps = [ "cmake"; "ninja-build"; "libgmp-dev"; "python3-dev" ];
    api_source = Some z3_api_source;
    label = Some "arbipher";
    (* the repo builds the lib + both in-tree bindings (src/api/ml,
       src/api/python) — the all-on-tree shape *)
    artifacts =
      [ a_lib; a_binding Canary_lang.OCaml Canary_mechanism.Cstubs;
        a_binding Canary_lang.Python Canary_mechanism.Ctypes ];
  }

let z3_source_latest : source_repo =
  {
    name = "z3";
    remote = Some (Git "https://github.com/Z3Prover/z3.git");
    locals = [];
    version = Canary_basic.{ channel = Dev; id = "latest" };
    ref_ = "HEAD";
    official = true;
    build_sys_deps = [ "cmake"; "ninja-build"; "libgmp-dev"; "python3-dev" ];
    api_source = Some z3_api_source;
    label = None;
    (* the repo builds the lib + both in-tree bindings (src/api/ml,
       src/api/python) — the all-on-tree shape *)
    artifacts =
      [ a_lib; a_binding Canary_lang.OCaml Canary_mechanism.Cstubs;
        a_binding Canary_lang.Python Canary_mechanism.Ctypes ];
  }

let z3_source_stable : source_repo =
  {
    name = "z3";
    remote = Some (Git "https://github.com/Z3Prover/z3.git");
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
    label = None;
    (* the repo builds the lib + both in-tree bindings (src/api/ml,
       src/api/python) — the all-on-tree shape *)
    artifacts =
      [ a_lib; a_binding Canary_lang.OCaml Canary_mechanism.Cstubs;
        a_binding Canary_lang.Python Canary_mechanism.Ctypes ];
  }

(* Channel-keyed source lookup — the channel DEFAULT (C2 keeps it as the
   fallback + CI's tag lookup). [Dev] = official [z3_source_latest]
   (2026-08-13 restored — the "official HEAD binding broken" finding was
   WRONG: the failure was the opam switch's stale dllz3ml.so shadowing
   the fresh one in z3's POST_BUILD self-check (CAML_LD_LIBRARY_PATH
   beats the bytecode's -dllpath); the build_binding row now guards the
   env). The per-SCENARIO dispatch ([z3_source_for_assignment]) selects
   the exact repo by the source placement's pinned id — the arbipher
   fork is a real scenario now (C2, the three-version report). *)
let z3_source_of (ch : Canary_basic.channel) : source_repo =
  match ch with Canary_basic.Dev -> z3_source_latest | Canary_basic.Stable -> z3_source_stable

(* The bugfix-commit REGRESSION ref (2026-08-17, the z3 #10549 case):
   master at bc4585e0b — the commit immediately BEFORE 210994b "Add
   CMake install rules for OCaml bindings". At this ref [cmake
   --install] stages libz3 but NO OCaml package (the install rules were
   never added) — the world the regression check must FAIL on, pinned by
   the declared Install_lib expectation. A standalone checkout (the
   z3-stable precedent) with an ISOLATED build dir (mk_locals' TODO:
   per-variant builds must not share contrib/z3-all/build). The
   [--refs latest,pre-10549] run is the regression pair. *)
let z3_source_pre_10549 : source_repo =
  { z3_source_latest with
    locals =
      mk_locals ~build_dir:"../build-pre-10549" "contrib/z3-all/z3-pre-10549";
    version = Canary_basic.{ channel = Dev; id = "pre-10549" };
    ref_ = "bc4585e0b";
    label = Some "pre-10549" }

(* The repo backing one scenario's source placement (C2): the [Repo_axes]
   store pins carry each repo's (channel, id), so match the placement's
   version against the three declared repos — exact (channel, id) first,
   then the channel default ([z3_source_of] — CI's synthetic assignments
   carry no source placement). The realize ∘ dispatch idiom. *)
let z3_source_for_assignment (a : Canary_artifact.assignment) : source_repo =
  let v = Canary_enumerate.version_of a Canary_artifact.a_source in
  let open Canary_basic in
  match
    List.find
      [ z3_source_stable; z3_source_latest; z3_source_dev;
        z3_source_pre_10549 ]
      ~f:(fun r ->
        equal_channel r.Canary_artifact_source.version.channel v.channel
        && String.equal r.Canary_artifact_source.version.id v.id)
  with
  | Some r -> r
  | None -> z3_source_of v.channel

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

let z3_python_provider =
  Canary_store_config.Lang_pkg
    { lang = Canary_lang.Python; pm = Canary_store.Pip; package = "z3-solver";
      self_contained = true; versions = None }

let z3_artifacts : Canary_project_spec.artifact_row list =
  let open Canary_project_spec in
  [ artifact_row ~artifact:a_source ~follows:a_lib
      ~universe:[ (Fetched, Canary_basic.[ Stable; Dev ]) ]
      (* C2 (2026-08-16): the 3-way — stable, official dev (latest), and
         the arbipher fork, as per-channel repo pins: one identity-bearing
         scenario per repo.

         [~follows:a_lib] (2026-08-19): the source's channel LOCKS to the
         lib's — the phantom-ref-axis fix. Without it every declared repo
         crossed the Fetched lib, giving 4 all-Fetched worlds identical
         except a source ref nothing in them reads (lib=F:stable,
         binding=F:4.16.0 four times over: four runs, one world). With it
         the Fetched lib keeps only the Stable pin (ONE fetched world =
         4.15.2, the version the opam binding was built against) and the
         Dev refs stay with the chains that actually build from them. *)
      ~provider:
        (Canary_store_config.Repo_axes
           [ z3_source_stable; z3_source_latest; z3_source_dev;
             z3_source_pre_10549 ])
      ();
    artifact_row ~artifact:a_lib
      ~universe:[ (Fetched, [ Canary_basic.Stable ]);
                  (Built, [ Canary_basic.Dev ]);
                  (* the installed-consumer worlds (2026-08-19, the
                     provider-exclusive-rows model — the `--installed`
                     realization policy promoted to an ENUMERATION axis):
                     same channel axis as Built, so each built ref gets a
                     staged consumer face as its own world. The chain
                     builds like Built (the built family) and then stages;
                     the probe reads the install prefix. *)
                  (Installed, [ Canary_basic.Dev ]) ]
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
    artifact_row ~artifact:(a_binding Canary_lang.Python Canary_mechanism.Ctypes)
      ~universe:[ (Fetched, [ Canary_basic.Stable ]) ]
      ~provider:z3_python_provider () ]

let z3_table_rows ~(source : Canary_artifact_source.source_repo) ~distro
    ~(lib_prov : Canary_artifact.provision) =
  let open Canary_action_templates in
  (* C2: per-REPO rows — the scenario's source placement picks the repo,
     not a channel default; the repo's own version.channel drives the
     dev/stable row split below. *)
  let { version; ref_; name; remote; official; _ } :
      Canary_artifact_source.source_repo = source in
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
  let url =
    match remote with
    | Some (Canary_artifact_source.Git u | Canary_artifact_source.Hg u) -> u
    | Some (Canary_artifact_source.Tar u) -> u
    | None -> "https://local-only.invalid/"
  in
  let cmake_build_binding =
    match version.Canary_basic.channel with Canary_basic.Dev -> true | _ -> false
  in
  let shared =
    [ { ar_action = Canary_basic.Fetch Canary_basic.Lib; ar_needs = None;
        ar_template = Fetch_lib { linux_pkg = "libz3-dev"; macos_pkg = "z3" } };
      { ar_action = Canary_basic.Fetch (Canary_basic.Binding Canary_lang.Python); ar_needs = None;
        ar_template = Pip_install { pkg = "z3-solver" } };
      { ar_action = Canary_basic.Probe_binding Canary_lang.Python; ar_needs = None;
        ar_template = Python_probe
                { snippet =
                    "import z3; s = z3.Solver(); s.add(z3.Int('x') > 0); \
                     print('z3 ok:' + str(s.check()))" } };
      { ar_action = Canary_basic.Probe_binding Canary_lang.OCaml; ar_needs = None;
        ar_template = Ocaml_probe { binding_lib = "z3";
                example = "canary/examples/z3/z3_example.ml";
                target = "z3_example" } };
      { ar_action = Canary_basic.Probe_lib; ar_needs = None;
        ar_template = Native_lib_probe
                { location =
                    Pm_lib { pm_pkg = "z3"; lib_name = "libz3.so";
                             dpkg_pkg = None; ldconfig_name = None;
                             brew_pkg = None };
                  prefix = "Z3_" } };
    ]
  in
  let dev =
    [ { ar_action = Canary_basic.Fetch Canary_basic.Source; ar_needs = None;
        ar_template = Source_fetch
                { name; ver_str; ref_; url;
                  local = Option.map local ~f:(fun l -> l.path) } };
      { ar_action = Canary_basic.Scan_sources; ar_needs = None;
        ar_template = Scan_source { root; hdr_file = "src/api/z3.h" } };
      { ar_action = Canary_basic.Build_headers; ar_needs = None;
        ar_template = Build_headers { root; hdr_dir = "src/api" } };
      { ar_action = Canary_basic.Configure; ar_needs = None;
        ar_template = Cmake_configure
                { cmake_exec =
                    (if cmake_build_binding then "opam exec -- cmake" else "cmake");
                  (* -G Ninja is REQUIRED: without it cmake defaults to
                     Unix Makefiles and the ninja_build step finds no
                     build.ninja (the old mk_runner_spec's flags had
                     it; the table row dropped it). *)
                  (* The WHAT-is-built flags mirror the canonical
                     [z3_cmake_build_flags] (the opam template uses them) —
                     -DZ3_BUILD_EXECUTABLE=OFF is a FIX (2026-08-16, C2):
                     the A5 table migration dropped it, and the install
                     step (cmake --install) died on the missing z3
                     executable ("file INSTALL cannot find .../build/z3")
                     — masked until C2 renamed the scenario dirs and forced
                     a COLD run past the warm .ok markers. *)
                  flags =
                    String.split
                      ("-G Ninja -DZ3_BUILD_LIBZ3_SHARED=TRUE \
                        -DZ3_BUILD_OCAML_BINDINGS="
                       ^ (if cmake_build_binding then "ON" else "OFF")
                       ^ " -DZ3_BUILD_EXECUTABLE=OFF \
                          -DZ3_BUILD_TEST_EXECUTABLES=OFF \
                          -DZ3_BUILD_JAVA_BINDINGS=OFF \
                          -DZ3_BUILD_PYTHON_BINDINGS=OFF")
                      ~on:' ';
                  src = root; build } };
      { ar_action = Canary_basic.Build_lib; ar_needs = None;
        ar_template = Ninja_build { target = "libz3"; build } };
      (* the INSTALLED-consumer face (2026-08-19, the provider-exclusive-
         rows model): staging + the staged probe gate [Some Installed], so
         the Built world runs neither (it keeps the build-tree probe) and
         the Installed world runs both. The build steps above stay
         ungated — the built FAMILY fires them in either world, so one
         build serves both faces. *)
      { ar_action = Canary_basic.Install_lib;
        ar_needs = Some Canary_store.Installed;
        ar_template =
          Cmake_install
            { build; prefix = build ^ "/../install";
              (* the #10549 regression (2026-08-17): the install must
                 stage the OCaml PACKAGE (PR 93c609d's install rules);
                 the pre-10549 ref fails these — the declared
                 expectation below turns that failure into an xfail.
                 OFFICIAL repos only: a fork's in-flight tree is not
                 held to the merged fix's contract. *)
              assert_staged =
                (if official then
                   Some [ "lib/ocaml/z3/META"; "lib/ocaml/z3/z3ml.cmxa" ]
                 else None) } };
      { ar_action = Canary_basic.Build_binding Canary_lang.OCaml; ar_needs = None;
        ar_template = Ninja_build_binding
                { target = "build_z3_ocaml_bindings"; build;
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
                  env_guard =
                    Some
                      (Printf.sprintf
                         "CAML_LD_LIBRARY_PATH=$(pwd)/%s/src/api/ml:$CAML_LD_LIBRARY_PATH LD_LIBRARY_PATH=$(pwd)/%s"
                         build build) } };
      { ar_action = Canary_basic.Probe_lib; ar_needs = None;
        ar_template = Native_lib_probe
                { location = Build_tree_glob { lib_glob = "libz3.so"; build };
                  prefix = "Z3_" } };
      { ar_action = Canary_basic.Probe_lib;
        ar_needs = Some Canary_store.Installed;
        ar_template = Native_lib_probe
                { location = Staged_lib { lib = build ^ "/../install/lib/libz3.so" };
                  prefix = "Z3_" } };
      { ar_action = Canary_basic.Probe_binding Canary_lang.OCaml; ar_needs = None;
        ar_template =
          Raw
            (fun ~output_dir ~variant_key ->
              let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
              let symbols_log = Canary_basic.variant_file ~variant_key "symbols.log" in
              (* -cclib "$LIB_Z3": the cmxa embeds `-L<stublibs> -L<build> -lz3`
                 — the STORE's stale libz3.so wins the -lz3 search (stublibs
                 first) and the link dies on any API the store lacks (finite-set
                 at official HEAD). The full-path arg precedes it, so the exe
                 links the BUILT lib. Same shadowing class as the env_guard. *)
              (* the consumer's lib is the ENUMERATED one (2026-08-19):
                 the Installed world's probe reads the STAGED prefix, every
                 other world the build tree. Was the `--installed`
                 realization policy ([consumer_lib]); the two command
                 bodies are unchanged — only the key. *)
              match lib_prov with
              | Canary_artifact.Built | Canary_artifact.Fetched
              | Canary_artifact.Vendored | Canary_artifact.Absent ->
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
                    output_dir probe_log
              | Canary_artifact.Installed ->
                  (* the installed-consumer world (2026-08-18, user; an
                     enumeration axis since 2026-08-19):
                     the probe consumes the STAGED package — the install
                     prefix's lib + the installed OCaml package — the
                     REAL concrete artifact the install produced (the
                     #10549 class: pre-fix the prefix lacks the package
                     while the build tree has it; this probe reads the
                     prefix and fails where the build-tree probe passes).
                     One build cache serves both policies — the install
                     is a copy-out, nothing rebuilds. *)
                  let prefix = build ^ "/../install" in
                  (* the guard signatures feed the declared expectation
                     ([STAGED PACKAGE MISSING] — the pre-#10549 live
                     signature: the prefix lib stages, the OCaml package
                     does not). Written to a variant-keyed fail log —
                     [output_contains_any] scans the step's output dir,
                     and the cmd's own stderr is NOT captured there. *)
                  let staged_fail = Canary_basic.variant_file ~variant_key "probe_fail.log" in
                  Printf.sprintf
                    "eval $(opam env) && \
                     LIB_Z3=$(ls %s/lib/libz3.so %s/lib/libz3.dylib 2>/dev/null | head -1) && \
                     { test -n \"$LIB_Z3\" || { echo \"STAGED LIB MISSING: %s/lib/libz3.so\" >&2; exit 1; }; } && \
                     BINDING_DIR=%s/lib/ocaml/z3 && \
                     STUB=$(ls \"$BINDING_DIR\"/z3ml.a 2>/dev/null | head -1) && \
                     { test -n \"$STUB\" || { echo \"STAGED PACKAGE MISSING: $BINDING_DIR/z3ml.a\" >&2; echo \"STAGED PACKAGE MISSING: $BINDING_DIR/z3ml.a\" > %s/%s; exit 1; }; } && \
                     python3 canary/scripts/assert_binary_symbols.py \
                       --provided-lib \"$LIB_Z3\" --required-lib \"$STUB\" \
                       --symbol-prefix Z3_ > %s/%s 2>&1 && \
                     LD_LIBRARY_PATH=%s/lib:$LD_LIBRARY_PATH \
                     ocamlfind ocamlopt -package zarith -linkpkg \
                       -cclib \"$LIB_Z3\" \
                       -I \"$BINDING_DIR\" \"$BINDING_DIR\"/z3ml.cmxa \
                       canary/examples/z3/z3_example.ml -o %s/z3_example > %s/%s 2>&1 && \
                     LD_LIBRARY_PATH=%s/lib:$LD_LIBRARY_PATH \
                     %s/z3_example >> %s/%s 2>&1 && \
                     cat %s/%s"
                    prefix prefix prefix prefix
                    output_dir staged_fail output_dir symbols_log
                    prefix
                    output_dir output_dir probe_log
                    prefix output_dir output_dir probe_log
                    output_dir probe_log) };
      { ar_action = Canary_basic.Publish (Canary_basic.Binding Canary_lang.OCaml); ar_needs = None;
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
  (* C2: dispatch on the SOURCE placement (the lib channel was the pre-C2
     proxy — the source row now pins per-repo identities, so the scenario's
     repo IS the source placement's id). *)
  let source = z3_source_for_assignment a in
  (* the consumer's lib coordinate (2026-08-19): read off the assignment,
     not a run policy — the Installed world is enumerated. *)
  let lib_prov = Canary_enumerate.provision_of a Canary_artifact.a_lib in
  let lib_installed =
    Canary_enumerate.equal_provision lib_prov Canary_artifact.Installed
  in
  let spec =
    Canary_action_templates.realize
      (z3_table_rows ~source ~distro:(detect_distro ()) ~lib_prov)
      a
  in
  let binding_fetched =
    Canary_enumerate.equal_provision
      (Canary_enumerate.provision_of a z3_binding_art)
      Canary_artifact.Fetched
  in
  let pin =
    (Canary_enumerate.version_of a z3_binding_art).Canary_basic.id
  in
  let binding_built =
    Canary_enumerate.equal_provision
      (Canary_enumerate.provision_of a z3_binding_art)
      Canary_artifact.Built
  in
  (* expectation stays hand-wired: contract bindings are project data *)
  { spec with
    expectation = (fun action loc ->
        (* the #10549 regression (2026-08-17): at the pre-fix ref the
           install cannot stage the OCaml package (the install rules
           never existed) — a DECLARED expected failure, the
           historical-bug shape (xfail on confirm). Every other ref
           expects the install to succeed. *)
        match (source.Canary_artifact_source.version.Canary_basic.id, action) with
        | "pre-10549", Canary_basic.Install_lib ->
            Canary_step_model.Expect_failure
              { contains_any = [ "OCAML INSTALL MISSING" ];
                version_info =
                  Some
                    { provider_version = "z3 pre-10549 (bc4585e0b)";
                      consumer_requires = "installed OCaml package";
                      since = Some "PR #10549 (93c609d)";
                      note = None } }
        (* the installed-consumer world (2026-08-18; enumerated since
           2026-08-19): the Installed world's probe reads the STAGED
           prefix, which the pre-fix install never populated — the
           same #10549 bug made visible ON THE CONSUMER (the Built
           world's probe passes; the build tree has the package). The
           binding-Built guard is now implied by the world (the lib's
           Installed channel is Dev and the binding follows it) and kept
           explicit: the expectation reads its own preconditions. *)
        | "pre-10549", Canary_basic.Probe_binding Canary_lang.OCaml
          when binding_built && lib_installed ->
            Canary_step_model.Expect_failure
              { contains_any = [ "STAGED PACKAGE MISSING" ];
                version_info =
                  Some
                    { provider_version = "z3 pre-10549 (bc4585e0b)";
                      consumer_requires = "installed OCaml package";
                      since = Some "PR #10549 (93c609d)";
                      note =
                        Some
                          "Installed-consumer probe: the staged prefix \
                           lacks z3ml.a (the raw build tree has it)" } }
        | _ ->
            Canary_scenario.lower_expectation_agnostic
              ~bindings:z3_contract_bindings ~langs:[ Canary_lang.Python ]
              action loc);
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
  let open Canary_action_templates in
  (* CI tracks the OFFICIAL dev source (the fork is canary-local). *)
  let rows =
    z3_table_rows ~source:(z3_source_of Canary_basic.Dev) ~distro
      ~lib_prov:Canary_artifact.Built
  in
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
    pr_runner_spec = (fun a ~workspace:_ () -> realize a);
    pr_mismatch_probes = [];
    (* the dev-source wrapper: the Publish row installs our z3.dev opam
       package over the built tree (pin-checked "dev" on the store). *)
    pr_wrapper_pkgs = [ (Canary_lang.OCaml, "z3.dev") ];
    pr_api_source = None;
    (* C2: FIVE scenarios — 3 all-Fetched source worlds (stable 4.15.2 /
       official latest / arbipher fork) + 2 source-built dev chains
       (official latest + fork, ~15-40 min cold EACH) — the batch default
       runs z3 THIN (stable fetch chain only). *)
    pr_binding_decls = z3_binding_decls;
    (* the OCaml binding builds via the project's own target — raw, respected
       as-is (the mechanism template would say Dune); the Python binding
       is Dlopen (no template to override). *)
    pr_raw_build_overrides = [ (Canary_lang.OCaml, Canary_mechanism.Cstubs) ];
    pr_tier = Canary_project_run.Heavy }
