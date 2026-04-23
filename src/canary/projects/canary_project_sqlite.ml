open Canary_basic
open Canary_toolchain_ocaml
open Canary

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

let prebuilt_prebuilt_spec distro : job_spec =
  {
    distro;
    id = "prebuilt-prebuilt";
    description = "Install system sqlite, install opam sqlite3 binding, probe";
    phases =
      [
        {
          kind =
            Pm_install
              (Some
                 {
                   linux_pkg =
                     (prebuilt_info_exn sqlite_ocaml_config)
                       .system_package_linux;
                   macos_pkg =
                     (prebuilt_info_exn sqlite_ocaml_config)
                       .system_package_macos;
                 });
          location = System_pm;
          requires = [];
          produces = [ { kind = Lib; name = "sqlite3"; location = System_pm } ];

        };
        {
          kind = Pm_install None;
          location = Lang_pm;
          requires = [ { kind = Lib; name = "sqlite3"; location = System_pm } ];
          produces = [ { kind = App; name = "sqlite3"; location = Lang_pm } ];

        };
        {
          kind = Probe_test { lang = OCaml };
          location = Lang_pm;
          requires = [ { kind = App; name = "sqlite3"; location = Lang_pm } ];
          produces = [];

        };
      ];
    if_disabled = false;
  }

let config distro =
  {
    canary = Canary_basic.mk_canary_config ();
    workflow_name = "Canary Testing for SQLite3 OCaml";
    name = "sqlite";
    project =
      {
        root = "";
        version = "system";
        commit = "";
        bindings = [ (OCaml, Opam) ];
        system_pm = Brew;
        has_source = false;
        has_system_pkg = true;
        has_lang_pkg = true;
        can_package = false;
      };
    ocaml = sqlite_ocaml_config;
    job_specs = [ prebuilt_prebuilt_spec distro ];
    deploy = None;
    opam_template_bindings = [];
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

let script_spec : Canary_action.script_spec =
  let pm = Canary_store.detect_pm () in
  let ocaml = sqlite_ocaml_config.ocaml in
  {
    Canary_action.empty_script_spec with
    fetch_lib = Some (Canary_action.fetch_lib_cmd pm prebuilt.system_package);
    fetch_binding =
      Some (Canary_action.fetch_binding_cmd prebuilt.opam_package_spec);
    probe_binding =
      [
        (Canary_store.Lang_pm,
         (fun ~output_dir ->
           Canary_action.probe_ocaml_cmd ~binding_lib:ocaml.binding_lib_name
             ~example:ocaml.example_file ~target:ocaml.example_target
             ~output_dir));
        (* Python sqlite3 is stdlib-bundled — no install, just verify import
           and a minimal connect. Depends on nothing except python3; the
           deps_of_split_probe `Pkg default requires fetch_binding but that's
           a no-op for this stdlib case. If it proves awkward we may need a
           dedicated stdlib-binding location tag. *)
        (Canary_store.Wild "pip",
         (fun ~output_dir ->
           [%string {|python3 -c "import sqlite3; sqlite3.connect(':memory:').execute('SELECT 1').fetchone(); print('sqlite3 ok')" > %{output_dir}/probe.log 2>&1 && cat %{output_dir}/probe.log|}]));
      ];
    summary = (fun rule loc -> match rule, loc with
      | Probe Binding, Some (Canary_store.Wild "pip") ->
          Some (fun ~output_dir ->
            Canary_artifact_python.summary_cmd
              ~pkg:"sqlite3" ~watchlist:sqlite_python_watchlist ~output_dir ())
      | Probe Binding, _ ->
          Some (fun ~output_dir ->
            Canary_artifact_ocaml.summary_opam_pkg_cmd
              ~pkg:"sqlite3" ~watchlist:sqlite_ocaml_watchlist ~output_dir ())
      | _ -> None);
  }

let action_steps ~root ~project =
  Canary_action.derive_steps ~root ~project script_spec

let run_info steps =
  Canary_action.mk_run_info ~project:"sqlite" ~version:"system" ~ref_:""
    ~source:"prebuilt" steps
