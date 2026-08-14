open Canary_artifact
open Canary_project_spec
open Canary_toolchain

let sqlite_ocaml_config : ocaml_tool_config =
  {
    toolchain =
      {
        prefix_name = "SQLITE3_PREFIX";
        prefix_var = "$SQLITE3_PREFIX";
        prefix_envar = "${SQLITE3_PREFIX}";
        libdir_name = "SQLITE3_LIB_DIR";
        libdir_var = "$SQLITE3_LIB_DIR";
        local_repo_name = "canary-local";
        package_name = "sqlite3";
        package_version = "system";
        canary_src_var = "CANARY_SQLITE3_SRC";
      };
    ocaml =
      {
        example_file = "canary/examples/sqlite3/sqlite3_example.ml";
        example_target = "sqlite3_example";
        example_name = "sqlite3 example";
        binding_lib_name = "sqlite3";
        build_api_path = None;
      };
    prebuilt =
      Some
        (mk_prebuilt_info ~opam_package:"sqlite3"
           ~system_package_linux:"sqlite3" ~system_package_macos:"sqlite" ());
  }

(* ── Action steps ── *)

let prebuilt = prebuilt_info_exn sqlite_ocaml_config

(* Module-level watchlist for the sqlite3 opam package. Module names from
   ocamlobjinfo Name: fields; constructor-level drift is caught by compile probes. *)
let sqlite_ocaml_watchlist = [ "Sqlite3" ]

(* Top-level attribute watchlist for Python's stdlib sqlite3. Drift here
   reveals either CPython API changes or a bundled-libsqlite version bump
   that removed a wrapper. `sqlite_version_info` (not plain `version_info`,
   which doesn't exist) is the canonical libsqlite version accessor. *)
let sqlite_python_watchlist = [
  "connect";
  "sqlite_version";
  "sqlite_version_info";
  "Connection";
  "Cursor";
]

(* Modern-C-API watchlist on the NATIVE lib (the per-version symbol-watchlist
   primitive, status §B/§C): the Built-world lib inspect records, per built
   version, whether recent API additions are exported — all present in ≥3.44;
   a future ≤3.43 Built version would show them MISSING (the forward-mismatch
   axis, measured 2026-08-05: 3.45.1↔3.46.1 export identical sets). Also the
   LIB half of the binding-lag observation: the opam binding and Python
   stdlib wrap NONE of these — the full lib↔binding lag check (c7/c8) needs
   a declared native↔binding name correspondence (A5/A9 design). *)
let sqlite_native_modern_watchlist = [
  "sqlite3_get_clientdata";
  "sqlite3_set_clientdata";
  "sqlite3_error_offset";
  "sqlite3_value_encoding";
  "sqlite3_stmt_explain";
]

(* The C API declaration (2026-08-13, spec-check fulfillment): the
   amalgamation ships sqlite3.h at its root (the fetch unzips into
   <workspace>/src). The native watchlist carries the modern-API symbols;
   binding watchlists ride the existing declared lists. *)
let sqlite_api_source : Canary_artifact.t =
  { Canary_artifact.native_api =
      { kind = Canary_artifact.C;
        components = [ Canary_artifact.Headers; Canary_artifact.Runtime_lib ];
        headers = Some { Canary_artifact.dir = "."; files = [ "sqlite3.h" ] };
        symbol_prefixes = [ "sqlite3_" ];
        stable_symbols = sqlite_native_modern_watchlist;
        versioned_symbols = [];
        soname = None;
        c_runtime = None;
        cxx_abi = None };
    binding_apis =
      [ { Canary_artifact.lang = Canary_lang.OCaml;
          source_dir = None;
          module_watchlist = sqlite_ocaml_watchlist;
          type_watchlist = [] };
        { Canary_artifact.lang = Canary_lang.Python;
          source_dir = None;
          module_watchlist = sqlite_python_watchlist;
          type_watchlist = [] } ] }

(* sqlite's source is a remote git repo with two versions — a general mimic of
   z3 (dev / stable), but declared cleanly on the project_run spec. The STABLE
   tag (3.45.1 = the amalgamation 3450100 canary builds, and the libsqlite3 the
   opam `sqlite3` binding links against) is the one that "made the binding";
   dev is trunk. The native lib is buildable from source; the OCaml binding is
   NOT (it's the opam `sqlite3` package — [has_build_binding = false]). *)
let sqlite_source_stable : Canary_artifact_source.source_repo =
  { Canary_artifact_source.name = "sqlite";
    remote = Canary_artifact_source.Git_remote "https://github.com/sqlite/sqlite.git";
    locals = [];
    version = Canary_basic.{ channel = Stable; id = "3.45.1" };
    ref_ = "version-3.45.1";
    official = true;
    build_sys_deps = [];
    api_source = Some sqlite_api_source }

let sqlite_source_dev : Canary_artifact_source.source_repo =
  { sqlite_source_stable with version = Canary_basic.{ channel = Dev; id = "" }; ref_ = "master" }

(* Channel-keyed source lookup (2026-08-07): projects declare per-channel
   sources as DATA; the algorithm ranges over channels. *)
let sqlite_source_of (ch : Canary_basic.channel) : Canary_artifact_source.source_repo =
  match ch with Canary_basic.Dev -> sqlite_source_dev | Canary_basic.Stable -> sqlite_source_stable

(* THE artifact table (from the real [prebuilt] data): identity + provider
   per row — ONE source of truth (2026-08-06: the old separate
   [sqlite_providers] assoc merged into the artifact rows, user-directed).
   The runner's [store_config] (fetch commands) AND `spec`'s display both
   read THIS list, so the two can't drift. (The Built-from-amalgamation
   alt for the lib is the [lib=B:stable] scenario, not a baseline
   provider.) *)
let sqlite_python_provider =
  Canary_store_config.Lang_pkg
    { lang = Canary_lang.Python; pm = Canary_store.Pip;
      package = "sqlite3 (stdlib, pip no-op)"; self_contained = true; versions = None }

(* BINDING-LAG markers (2026-08-05; role split per status §B): canonical
   wrapper names for modern C APIs the lib exports (see
   [sqlite_native_modern_watchlist]) that the stdlib binding does NOT wrap.
   Declared in the EXPECTED-MISSING role — the inspect reports them as
   expected_missing.confirmed (the measured binding↔lib surface lag, an
   xfail-style pass in `status`), and a name that APPEARS reads as
   .violated (the binding caught up; this declaration is stale — alarming).
   They must NOT ride the expected-present watchlist: there, missing =
   drift and stays alarming (tiny's semantics). The OCaml-side analogue
   needs an mli inspect over the installed sqlite3.mli — c7/c8 territory.
   This role split is the seed of the c7/c8 lag contract. *)
let sqlite_python_expect_missing = [
  "get_clientdata";
  "error_offset";
]

(* The pre-action-table [runner_spec] / [built_spec] / [sqlite_python_config]
   trio retired 2026-08-12 (registry unification): the live path is
   [sqlite_table_rows] → [realize] → [sqlite_run] below. *)

(* Two REAL amalgamation versions so the lib's Built provision enumerates over a
   version axis (see [ps_versions_of] lib = [Stable; Dev]): Stable = 3.45.1 (the
   version the opam `sqlite3` binding links against), Dev = 3.46.1 (a newer
   release). Both are real sqlite amalgamation zips; the build/probe commands are
   version-independent (`sqlite3.c` + `sqlite3_open` exist in every release), so
   both worlds build + probe green. This is the honest "run more cases" for a
   positive project: the same chain over two source versions. *)
let sqlite_amalg (chan : Canary_basic.channel) :
    string * string * string =
  (* (dotted runtime version, numeric amalgamation id, zip URL). The dotted
     form is what the RUNTIME reports (sqlite3_libversion / Python
     sqlite3.sqlite_version) — the probes assert it, so the run verifiably
     exercises the world the enumeration declared. *)
  match chan with
  | Canary_basic.Stable ->
      ( "3.45.1", "3450100",
        "https://sqlite.org/2024/sqlite-amalgamation-3450100.zip" )
  | Canary_basic.Dev ->
      ( "3.46.1", "3460100",
        "https://sqlite.org/2024/sqlite-amalgamation-3460100.zip" )

(* The hand-written [sqlite_spec] + the duplicated [sqlite_artifacts] it
   served retired 2026-08-13 (spec-check fulfillment): the source row joined
   the artifact table, which made the old "self-contained Built omits
   a_source" shape wrong — the source is now a declared artifact
   (Fetched@[Stable;Dev], version-coupled to the Built lib by
   [assignment_ok]'s source@version rule; the amalgamation fetch is its
   fetch_source step). [sqlite_run]'s pr_artifacts below is the single
   table. *)

(* ── dispatch / realization split ──
   [scenario_case] is the PURE dispatch result — inspectable data computed
   from enumeration coordinates only (general reads:
   [Canary_enumerate.provision_of]/[channel_of]); the realizations
   ([runner_spec] / [built_spec]) are the command templates. [pr_runner_spec]
   is just their composition — no placement digging inside it. *)
(* dispatch is now universal: [Canary_action_templates.dispatch] *)

(* ── A9-step-2: action-variant table ── *)
let sqlite_table_rows ~(workspace : string) (chan : Canary_basic.channel) =
  let open Canary_action_templates in
  let ocaml = sqlite_ocaml_config.ocaml in
  let _, _, amalg_url = sqlite_amalg chan in
  [ { ar_action = Canary_basic.Fetch Canary_basic.Lib;
      ar_template = Fetch_lib { linux_pkg = "libsqlite3-dev"; macos_pkg = "sqlite3" } };
    { ar_action = Canary_basic.Fetch (Canary_basic.Binding Canary_lang.OCaml);
      ar_template = Fetch_binding_opam { pkg = "sqlite3" } };
    { ar_action = Canary_basic.Fetch (Canary_basic.Binding Canary_lang.Python);
      ar_template = Pip_install { pkg = "stdlib" } };
    { ar_action = Canary_basic.Probe_binding Canary_lang.OCaml;
      ar_template = Ocaml_probe { binding_lib = ocaml.binding_lib_name;
                example = ocaml.example_file;
                target = ocaml.example_target } };
    { ar_action = Canary_basic.Probe_binding Canary_lang.Python;
      ar_template = Python_probe
                { snippet =
                    "import sqlite3; print('sqlite_version=' + \
                     sqlite3.sqlite_version); \
                     sqlite3.connect(':memory:').execute('SELECT \
                     1').fetchone(); print('sqlite3 ok')" } };
    { ar_action = Canary_basic.Fetch Canary_basic.Source;
      ar_template = Curl_unzip { url = amalg_url; dest = workspace ^ "/src" } };
    (* Self-contained Build: the amalgamation is fetched inside build_lib
       (the Fetch Source row above is filtered — a_source not in ps_universe).
       Fold the fetch guard into the build command. *)
    { ar_action = Canary_basic.Build_lib;
      ar_template = Raw (fun ~output_dir ~variant_key ->
          let _, numeric, _ = sqlite_amalg chan in
          let amalg_dir = "sqlite-amalgamation-" ^ numeric in
          let src_dir = workspace ^ "/src" in
          let libdir = workspace ^ "/lib" in
          let libpath = libdir ^ "/libsqlite3.so" in
          let fetch =
            Canary_build_cmd.curl_unzip_cmd ~url:amalg_url ~dest:src_dir ()
          in
          Printf.sprintf
            "test -f %s || { test -d %s/%s || { %s ; } && mkdir -p %s && %s ; } && \
             ln -sfn libsqlite3.so %s/libsqlite3.so.0"
            libpath src_dir amalg_dir fetch libdir
            (Canary_build_cmd.cc_shared_lib_cmd
               ~c_src:(Printf.sprintf "%s/%s/sqlite3.c" src_dir amalg_dir)
               ~out:libpath ~ldlibs:[ "-lpthread"; "-ldl" ] ())
            libdir
          |> Canary_build_cmd.with_marker ~marker:"build.ok" ~output_dir ~variant_key) };
    { ar_action = Canary_basic.Probe_lib;
      ar_template = Native_lib_probe
                { location = Build_tree_lib { lib = workspace ^ "/lib/libsqlite3.so" };
                  prefix = "sqlite3_" } };
    (* PM probe with pkg-config-less fallback (dpkg -L + ldconfig).
       sqlite3 has no .pc file; the fallback chain resolves through the
       apt dev package list and the dynamic linker cache. *)
    { ar_action = Canary_basic.Probe_lib;
      ar_template = Native_lib_probe
                { location =
                    Pm_lib
                      { pm_pkg = "sqlite3"; lib_name = "libsqlite3.so";
                        dpkg_pkg = Some "libsqlite3-dev";
                        ldconfig_name = Some "libsqlite3.so";
                        brew_pkg = None };
                  prefix = "sqlite3_" } };
  ]

(* Shared project-level configuration — inspect, artifact names, stores.
   The action rows above provide the per-action closures on top. *)
let base_spec : Canary_step_builder.runner_spec =
  { Canary_step_builder.empty_runner_spec with
    stores =
      { Canary_store_config.empty_store_config with
        lib = Some
          { Canary_store_config.provider =
              Canary_store_config.Sys_pkg prebuilt.system_package;
            components = []; headers = None } };
    inspect = (fun action _loc -> match action with
      | Canary_basic.Probe_binding Canary_lang.Python ->
          Some (fun ~output_dir ~variant_key ->
              Canary_artifact_lang.python_inspect_cmd
                ~pkg:"sqlite3" ~watchlist:sqlite_python_watchlist
                ~expect_missing:sqlite_python_expect_missing
                ~output_dir ~variant_key ())
      | Canary_basic.Probe_binding _ ->
          Some (fun ~output_dir ~variant_key ->
              Canary_artifact_lang.inspect_opam_pkg_cmd
                ~pkg:"sqlite3" ~watchlist:sqlite_ocaml_watchlist
                ~output_dir ~variant_key ())
      | _ -> None);
    artifact_name = (function
      | Canary_basic.Lib -> Some "libsqlite3.so"
      | Canary_basic.Binding Canary_lang.OCaml -> Some "sqlite3"
      | Canary_basic.Binding Canary_lang.Python -> Some "sqlite3"
      | _ -> None);
  }

let realize (a : Canary_artifact.assignment) ~(workspace : string) :
    Canary_step_builder.runner_spec =
  let chan = match Canary_enumerate.provision_of a Canary_artifact.a_lib with
    | Canary_artifact.Built -> Canary_enumerate.channel_of a Canary_artifact.a_lib
    | _ -> Canary_basic.Stable
  in
  let spec = Canary_action_templates.realize (sqlite_table_rows ~workspace chan) a in
  let dotted, _, _ = sqlite_amalg chan in
  let version_line = "sqlite_version=" ^ dotted in
  let ocaml = sqlite_ocaml_config.ocaml in
  let probe_env =
    [ Printf.sprintf "LD_LIBRARY_PATH=$PWD/%s:$LD_LIBRARY_PATH"
        (workspace ^ "/lib") ]
  in
  { spec with
    probe_binding =
      [ ( Canary_lang.OCaml,
          Canary_store.Pm
            (Canary_store.Lang_pm
               { lang = Canary_lang.OCaml; pm = Canary_store.Opam }),
          fun ~output_dir ~variant_key ->
            Canary_step_builder.probe_ocaml_env_cmd ~env:probe_env
              ~log_grep:None ~binding_lib:ocaml.binding_lib_name
              ~example:ocaml.example_file ~target:ocaml.example_target
              ~output_dir ~variant_key ) ];
    asserts =
      [ ( Canary_basic.Probe_binding Canary_lang.OCaml,
          Some
            (Canary_store.Pm
               (Canary_store.Lang_pm
                  { lang = Canary_lang.OCaml; pm = Canary_store.Opam })),
          version_line ) ];
  }

let sqlite_ci_spec ~workspace =
  let rows = sqlite_table_rows ~workspace Canary_basic.Stable in
  let a = Canary_artifact.[ (Canary_artifact.a_lib, { provision = Canary_artifact.Fetched; version = Canary_basic.good Canary_basic.Stable }) ] in
  Canary_action_templates.realize_from_rows ~assignment:a ~base:base_spec rows

let sqlite_artifacts : Canary_project_spec.artifact_row list =
  [ (* The source row (2026-08-13, spec-check fulfillment): Fetched@
       [Stable;Dev] with [~follows:a_lib] — the amalgamation version IS the
       lib's version (the self-contained build fetches exactly the
       amalgamation it builds), so the source's channel locks to the lib's.
       That keeps the scenario set at exactly 3 (fetched-system,
       built@3.45.1, built@3.46.1): the follows filter removes the
       source@dev × lib@Fetched cross combos, and [assignment_ok]'s
       source@version coupling is satisfied by construction. The run's
       fetch_source step is the amalgamation curl_unzip that build_lib
       previously folded into itself (its inner fetch is now a no-op
       guard over the same workspace/src). *)
    artifact_row ~artifact:a_source ~follows:a_lib
      ~universe:[ (Fetched, Canary_basic.[ Stable; Dev ]) ]
      ~provider:(Canary_store_config.Source_repo sqlite_source_stable) ();
    artifact_row ~artifact:a_lib
      ~universe:[ (Fetched, [ Canary_basic.Stable ]);
                  (Built, Canary_basic.[ Stable; Dev ]) ]
      ~provider:(Canary_store_config.Sys_pkg prebuilt.system_package) ();
    artifact_row ~artifact:(a_binding Canary_lang.OCaml Canary_mechanism.Cstubs)
      ~runtime:Canary_store.Independent
      ~universe:[ (Fetched, [ Canary_basic.Stable ]) ]
      ~provider:
        (Canary_store_config.Lang_pkg
           { lang = Canary_lang.OCaml; pm = Canary_store.Opam;
             package = prebuilt.opam_package; self_contained = false; versions = None })
      ();
    artifact_row ~artifact:(a_binding Canary_lang.Python Canary_mechanism.Cext)
      ~universe:[ (Fetched, [ Canary_basic.Stable ]) ]
      ~provider:sqlite_python_provider () ]

(* Derived view for the legacy [construct] display — the artifact table is
   the source of truth; this is just [project_spec_of_rows] over it (the
   hand-written duplicate retired 2026-08-13 with the source-row wiring). *)
let sqlite_spec : Canary_artifact.project_spec =
  Canary_project_spec.project_spec_of_rows sqlite_artifacts

let sqlite_run : Canary_project_run.project_run =
  { pr_name = "sqlite";
    pr_artifacts = sqlite_artifacts;
    (* No pre-placement: sqlite builds/fetches into the runner-provided
       [workspace] (canary_main.scenario_dir_of — per-version for Built, so
       Built@Stable and Built@Dev get distinct dirs; Fetched collapses across
       versions there). The built_spec reads the version from the assignment. *)
    pr_runner_spec = (fun a ~workspace -> realize a ~workspace);
    (* No designed mismatch probes: sqlite is additive-only upstream (no
       backward breaks exist — measured, status §C) and no consumer here
       requires a version-sensitive API yet (a forward probe needs a ≤3.43
       lib version + a C-level consumer of sqlite3_get_clientdata). *)
    pr_mismatch_probes = [];
    pr_wrapper_pkgs = [];
    pr_api_source = None;
    pr_tier = Canary_project_run.Light }
