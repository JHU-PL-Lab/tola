open Canary_basic
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

let sqlite_python_config : Canary_toolchain.binding_config =
  Python_config
    {
      pip_package = None;
      probe_snippet =
        {|import sqlite3; sqlite3.connect(':memory:').execute('SELECT 1').fetchone(); print('sqlite3 ok')|};
    }

let runner_spec : Canary_step_builder.runner_spec =
  let pm = Canary_store.detect_pm () in
  let ocaml = sqlite_ocaml_config.ocaml in
  {
    Canary_step_builder.empty_runner_spec with
    (* Declarative lib store (S3/S4): fetch_lib is Derived from this. *)
    stores =
      { Canary_store_config.empty_store_config with
        lib = Some
          { Canary_store_config.location =
              Canary_store.Pm (Canary_store.Sys_pm { pm });
            system_pkg = Some prebuilt.system_package;
            components = []; headers = None } };
    fetch_lib = Some (Canary_step_builder.Derived Canary_step_builder.Fetch_lib);
    (* fetch_binding stays Raw: Derived can't yet reproduce opam
       install_args (--assume-depexts) — store_config carries pkg_name
       only (PM-spec detail deferred). *)
    fetch_binding =
      (Canary_lang.OCaml, Canary_step_builder.Raw (Canary_step_builder.fetch_binding_cmd prebuilt.opam_package_spec))
      ::
      (match sqlite_python_config with
       | Python_config p ->
           [ (Canary_lang.Python,
              Canary_step_builder.Raw (fun ~output_dir ~variant_key -> Canary_toolchain.pip_install_cmd p ~output_dir ~variant_key)) ]
       | Ocaml_config _ -> []);
    probe_binding =
      (Canary_lang.OCaml,
       Canary_store.Pm (Canary_store.Lang_pm { lang = Canary_lang.OCaml; pm = Canary_store.Opam }),
       fun ~output_dir ~variant_key ->
         Canary_step_builder.probe_ocaml_cmd ~binding_lib:ocaml.binding_lib_name
           ~example:ocaml.example_file ~target:ocaml.example_target
           ~output_dir ~variant_key) ::
      (* Python sqlite3 is stdlib-bundled — install no-ops to a marker;
         this probe step just runs the import. *)
      (match sqlite_python_config with
       | Python_config p ->
           [ (Canary_lang.Python,
              Canary_store.Pm (Canary_store.Lang_pm { lang = Canary_lang.Python; pm = Canary_store.Pip }),
              fun ~output_dir ~variant_key ->
                Canary_toolchain.python_probe_only_cmd p ~output_dir ~variant_key) ]
       | Ocaml_config _ -> []);
    (* Sqlite has no api_source/binding_user_facing_pkg so auto-summary doesn't fire.
       Both OCaml and Python summaries are produced via this explicit
       override at probe time. (Python summary is at probe time rather than
       fetch step here — Phase 3d's pre-cache benefit only kicks in for
       projects that opt into the api_source flow.) *)
    inspect = (fun action loc -> match action, loc with
      | Probe_binding (_), Some (Canary_store.Pm (Canary_store.Lang_pm { lang = Canary_lang.Python; _ })) ->
          Some (fun ~output_dir ~variant_key ->
            Canary_artifact_lang.python_inspect_cmd
              ~pkg:"sqlite3" ~watchlist:sqlite_python_watchlist ~output_dir ~variant_key ())
      | Probe_binding (_), _ ->
          Some (fun ~output_dir ~variant_key ->
            Canary_artifact_lang.inspect_opam_pkg_cmd
              ~pkg:"sqlite3" ~watchlist:sqlite_ocaml_watchlist ~output_dir ~variant_key ())
      | _ -> None);
    artifact_name = (function
      | Canary_basic.Lib -> Some "libsqlite3.so"
      | Canary_basic.Binding Canary_lang.OCaml -> Some "sqlite3"
      | Canary_basic.Binding Canary_lang.Python -> Some "sqlite3"
      | _ -> None);
  }

(* ── sqlite as a [project_run] — the real-world instance of the §4.2.5 model ──
   Same shape as tiny-full (a [Canary_project_run.project_run] the generic
   `run_project_run` consumes), but real-world: everything is **Fetched** —
   canary fetches the lib (system PM) + the OCaml binding (opam) as ACTIONS
   (the [runner_spec] above); Python sqlite3 is stdlib. So [pr_materialize]
   places NOTHING (canary's role is to perform the fetch/build actions) — a
   nominal per-scenario dir just labels the output. Positive-only (a real
   project isn't mutated); the [runner_spec]'s default expectation is success. *)
let project : Canary_project.project =
  { name = "sqlite"; contract_bindings = [] }

let sqlite_artifacts =
  Canary_enumerate.
    [ a_lib;
      a_binding Canary_lang.OCaml Canary_mechanism.Cstubs;
      a_binding Canary_lang.Python Canary_mechanism.Cext ]

(* ── Built-from-source variant (provision = Built for the lib) ──
   Fetch the sqlite amalgamation (a REAL source fetch) and compile a real
   libsqlite3.so with cc — the Built provision on a real project, so canary
   observes source-fetch + build as *actions* (unlike tiny's toy cc). Lib-only
   for now; a binding built against the Built lib is a follow-up. *)
let sqlite_amalg_url = "https://sqlite.org/2024/sqlite-amalgamation-3450100.zip"
let sqlite_amalg_dir = "sqlite-amalgamation-3450100"

(* A3b: the Built scenario UNIFIES the lib build with the bindings — extend the
   Fetched [runner_spec] (which carries fetch_binding/probe_binding), swapping the
   lib from fetched to built-from-source. The bindings run against the SYSTEM lib
   for now (Python sqlite3 is stdlib — can't be repointed; OCaml binding-over-
   BUILT-lib via LD_LIBRARY_PATH is a follow-up). This makes the run consistent
   with the enumeration ({lib=Built, bindings=Fetched}), not lib-only. *)
let built_spec ~(workspace : string) : Canary_step_builder.runner_spec =
  let src = workspace ^ "/src" in
  let libdir = workspace ^ "/lib" in
  let libpath = libdir ^ "/libsqlite3.so" in
  { runner_spec with
    fetch_lib = None;   (* built from source, not fetched *)
    fetch_source =
      Some
        (fun ~output_dir ~variant_key ->
          Printf.sprintf
            "mkdir -p %s && curl -sL %s -o %s/a.zip && (cd %s && unzip -oq a.zip)"
            src sqlite_amalg_url src src
          |> Canary_build_cmd.with_marker ~marker:"source.ok" ~output_dir ~variant_key);
    build_lib =
      Some
        (fun ~output_dir ~variant_key ->
          Printf.sprintf
            "test -f %s || { mkdir -p %s && gcc -shared -fPIC %s/%s/sqlite3.c \
             -o %s -lpthread -ldl ; }"
            libpath libdir src sqlite_amalg_dir libpath
          |> Canary_build_cmd.with_marker ~marker:"build.ok" ~output_dir
               ~variant_key);
    probe_lib =
      [ ( Canary_store.Build_tree,
          fun ~output_dir ~variant_key ->
            Printf.sprintf
              "nm -D %s | grep -q sqlite3_open && echo 'built libsqlite3 ok (%s)'"
              libpath libpath
            |> Canary_build_cmd.with_marker ~marker:"probe.log" ~output_dir
                 ~variant_key ) ];
  }

(* A3b: sqlite DECLARES its static axes (stage 1: [project_spec]); the generic
   runner ENUMERATES via [enumerate ~policy] (stage 2) under [full_policy] —
   retiring the hand-built pr_enumerate list. Positive-only (no mutations — the
   policy injects none). Per-artifact provisions: the lib may be Fetched
   (system PM) or Built (source); bindings Fetched. Self-contained Built (no
   a_source artifact — the amalgamation is fetched inside build_lib). *)
let sqlite_spec : Canary_enumerate.project_spec =
  { ps_artifacts = sqlite_artifacts;
    ps_provisions_of =
      (fun id ->
        if Canary_enumerate.equal_artifact_id id Canary_enumerate.a_lib then
          Canary_enumerate.[ Fetched; Built ]
        else Canary_enumerate.[ Fetched ]);
    ps_versions_of = (fun _ -> [ Canary_basic.Stable ]) }

let sqlite_run : Canary_project_run.project_run =
  { pr_name = "sqlite";
    pr_artifacts = sqlite_artifacts;
    (* ENUMERATE from the declared spec, not a hand-built list *)
    pr_enumerate =
      (fun () ->
        Canary_enumerate.enumerate ~tag:(fun () -> "")
          ~policy:(Canary_enumerate.full_policy ()) sqlite_spec);
    pr_materialize =
      (fun a ->
        match Canary_enumerate.provision_of a Canary_enumerate.a_lib with
        | Canary_enumerate.Built ->
            Some "_out/canary/materialized/sqlite/built-3450100"
        | _ -> Some "fetched-system");
    pr_runner_spec =
      (fun a ~workspace ->
        match Canary_enumerate.provision_of a Canary_enumerate.a_lib with
        | Canary_enumerate.Built -> built_spec ~workspace
        | _ -> runner_spec);
    (* Static provenance (from the real spec data — [prebuilt] + [built_spec]). *)
    pr_provenance =
      (fun id ->
        match Canary_enumerate.kind_of id with
        | Canary_basic.Lib ->
            Some
              (Printf.sprintf
                 "sys-pm linux:%s macos:%s (fetch_lib); or Built from %s"
                 prebuilt.system_package_linux prebuilt.system_package_macos
                 sqlite_amalg_url)
        | Canary_basic.Binding Canary_lang.OCaml ->
            Some (Printf.sprintf "opam:%s (fetch_binding)" prebuilt.opam_package)
        | Canary_basic.Binding Canary_lang.Python ->
            Some "python stdlib sqlite3 (bundled — no pip package)"
        | _ -> None) }
