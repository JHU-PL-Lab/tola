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
    version = "3.45.1";
    ref_ = "version-3.45.1";
    official = true;
    has_build_lib = true;
    has_build_binding = false;
    build_sys_deps = [];
    api_source = None }

let sqlite_source_dev : Canary_artifact_source.source_repo =
  { sqlite_source_stable with version = "dev"; ref_ = "master" }

(* THE single per-artifact provider declaration (from the real [prebuilt] data).
   ONE source of truth: the runner's [store_config] (fetch commands) AND `spec`'s
   [pr_provenance] both DERIVE from this, so the display and the runner can't
   drift. (The Built-from-amalgamation alt for the lib is the [lib=B:stable]
   scenario, not a baseline provider.) *)
let sqlite_provider (id : Canary_enumerate.artifact_id) :
    Canary_store_config.provider option =
  match Canary_enumerate.kind_of id with
  | Canary_basic.Source ->
      Some (Canary_store_config.Source_repo sqlite_source_stable)
  | Canary_basic.Lib ->
      Some (Canary_store_config.Sys_pkg prebuilt.system_package)
  | Canary_basic.Binding Canary_lang.OCaml ->
      Some
        (Canary_store_config.Lang_pkg
           { lang = Canary_lang.OCaml; pm = Canary_store.Opam;
             package = prebuilt.opam_package })
  | Canary_basic.Binding Canary_lang.Python ->
      Some
        (Canary_store_config.Lang_pkg
           { lang = Canary_lang.Python; pm = Canary_store.Pip;
             package = "sqlite3 (stdlib, pip no-op)" })
  | _ -> None

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
  let ocaml = sqlite_ocaml_config.ocaml in
  {
    Canary_step_builder.empty_runner_spec with
    (* Declarative lib store (S3/S4): fetch_lib is Derived from this. *)
    stores =
      { Canary_store_config.empty_store_config with
        lib = Some
          { Canary_store_config.provider =
              (match sqlite_provider Canary_enumerate.a_lib with
               | Some p -> p
               | None -> Canary_store_config.Absent);
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
    [ a_source;
      a_lib;
      a_binding Canary_lang.OCaml Canary_mechanism.Cstubs;
      a_binding Canary_lang.Python Canary_mechanism.Cext ]

(* ── Built-from-source variant (provision = Built for the lib) ──
   Fetch the sqlite amalgamation (a REAL source fetch) and compile a real
   libsqlite3.so with cc — the Built provision on a real project, so canary
   observes source-fetch + build as *actions* (unlike tiny's toy cc). Lib-only
   for now; a binding built against the Built lib is a follow-up. *)
(* Two REAL amalgamation versions so the lib's Built provision enumerates over a
   version axis (see [ps_versions_of] lib = [Stable; Dev]): Stable = 3.45.1 (the
   version the opam `sqlite3` binding links against), Dev = 3.46.1 (a newer
   release). Both are real sqlite amalgamation zips; the build/probe commands are
   version-independent (`sqlite3.c` + `sqlite3_open` exist in every release), so
   both worlds build + probe green. This is the honest "run more cases" for a
   positive project: the same chain over two source versions. *)
let sqlite_amalg (chan : Canary_basic.channel) : string * string =
  (* (numeric version, amalgamation zip URL) *)
  match chan with
  | Canary_basic.Stable ->
      ("3450100", "https://sqlite.org/2024/sqlite-amalgamation-3450100.zip")
  | Canary_basic.Dev ->
      ("3460100", "https://sqlite.org/2024/sqlite-amalgamation-3460100.zip")

(* A3b: the Built scenario UNIFIES the lib build with the bindings — extend the
   Fetched [runner_spec] (which carries fetch_binding/probe_binding), swapping the
   lib from fetched to built-from-source. The bindings run against the SYSTEM lib
   for now (Python sqlite3 is stdlib — can't be repointed; OCaml binding-over-
   BUILT-lib via LD_LIBRARY_PATH is a follow-up). This makes the run consistent
   with the enumeration ({lib=Built, bindings=Fetched}), not lib-only. *)
let built_spec ~(workspace : string) ~(chan : Canary_basic.channel) :
    Canary_step_builder.runner_spec =
  let numeric, amalg_url = sqlite_amalg chan in
  let amalg_dir = "sqlite-amalgamation-" ^ numeric in
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
            src amalg_url src src
          |> Canary_build_cmd.with_marker ~marker:"source.ok" ~output_dir ~variant_key);
    build_lib =
      Some
        (fun ~output_dir ~variant_key ->
          Printf.sprintf
            "test -f %s || { mkdir -p %s && gcc -shared -fPIC %s/%s/sqlite3.c \
             -o %s -lpthread -ldl ; }"
            libpath libdir src amalg_dir libpath
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
  { (* enumeration OMITS a_source: sqlite's Built lib is self-contained
       (build_lib fetches the amalgamation), so source is not a separately
       provisioned artifact here. a_source stays in [sqlite_artifacts] =
       [pr_artifacts] for the spec DISPLAY. Omitting it also lets the Built lib
       carry its own version axis without the unsatisfiable source@version chain
       constraint [assignment_ok] would otherwise impose. *)
    ps_artifacts =
      Canary_enumerate.
        [ a_lib;
          a_binding Canary_lang.OCaml Canary_mechanism.Cstubs;
          a_binding Canary_lang.Python Canary_mechanism.Cext ];
    ps_provisions_of =
      (fun id ->
        if Canary_enumerate.equal_artifact_id id Canary_enumerate.a_lib then
          Canary_enumerate.[ Fetched; Built ]
        else Canary_enumerate.[ Fetched ]);
    (* The lib carries a VERSION axis (Stable=3.45.1, Dev=3.46.1 amalgamations)
       so its Built provision enumerates two source versions; other artifacts are
       single-version. Fetched@Stable/@Dev both map to the system apt lib, so they
       dedup to one run — net worlds: fetched-system, built@3.45.1, built@3.46.1. *)
    ps_versions_of =
      (fun id ->
        if Canary_enumerate.equal_artifact_id id Canary_enumerate.a_lib then
          Canary_basic.[ Stable; Dev ]
        else [ Canary_basic.Stable ]) }

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
            (* per-VERSION workspace so Built@Stable and Built@Dev are distinct
               worlds (else they collapse to one dir + dedup to one run). *)
            let chan =
              (Canary_enumerate.version_of a Canary_enumerate.a_lib)
                .Canary_enumerate.channel
            in
            let numeric, _ = sqlite_amalg chan in
            Some ("_out/canary/materialized/sqlite/built-" ^ numeric)
        | _ -> Some "fetched-system");
    pr_runner_spec =
      (fun a ~workspace ->
        match Canary_enumerate.provision_of a Canary_enumerate.a_lib with
        | Canary_enumerate.Built ->
            let chan =
              (Canary_enumerate.version_of a Canary_enumerate.a_lib)
                .Canary_enumerate.channel
            in
            built_spec ~workspace ~chan
        | _ -> runner_spec);
    (* DERIVED from the single [sqlite_provider] declaration — same source the
       runner's store_config reads, so display and runner can't drift. *)
    pr_provenance = sqlite_provider }
