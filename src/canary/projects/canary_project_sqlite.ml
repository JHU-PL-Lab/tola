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

let script_spec : Canary_action.script_spec =
  let pm = Canary_store.detect_pm () in
  let ocaml = sqlite_ocaml_config.ocaml in
  {
    Canary_action.empty_script_spec with
    fetch_lib = Some (Canary_action.fetch_lib_cmd pm prebuilt.system_package);
    fetch_binding =
      (Canary_artifact_api.OCaml, Canary_action.fetch_binding_cmd prebuilt.opam_package_spec)
      ::
      (match sqlite_python_config with
       | Python_config p ->
           [ (Canary_artifact_api.Python,
              fun ~output_dir ~variant_key -> Canary_toolchain.pip_install_cmd p ~output_dir ~variant_key) ]
       | Ocaml_config _ -> []);
    probe_binding =
      (Canary_artifact_api.OCaml,
       Canary_store.Pm (Canary_store.Lang_pm { lang = Canary_artifact_api.OCaml; pm = Canary_store.Opam }),
       fun ~output_dir ~variant_key ->
         Canary_action.probe_ocaml_cmd ~binding_lib:ocaml.binding_lib_name
           ~example:ocaml.example_file ~target:ocaml.example_target
           ~output_dir ~variant_key) ::
      (* Python sqlite3 is stdlib-bundled — install no-ops to a marker;
         this probe step just runs the import. *)
      (match sqlite_python_config with
       | Python_config p ->
           [ (Canary_artifact_api.Python,
              Canary_store.Pm (Canary_store.Lang_pm { lang = Canary_artifact_api.Python; pm = Canary_store.Pip }),
              fun ~output_dir ~variant_key ->
                Canary_toolchain.python_probe_only_cmd p ~output_dir ~variant_key) ]
       | Ocaml_config _ -> []);
    (* Sqlite has no api_source/binding_user_facing_pkg so auto-summary doesn't fire.
       Both OCaml and Python summaries are produced via this explicit
       override at probe time. (Python summary is at probe time rather than
       fetch step here — Phase 3d's pre-cache benefit only kicks in for
       projects that opt into the api_source flow.) *)
    inspect = (fun rule loc -> match rule, loc with
      | Probe (Binding _), Some (Canary_store.Pm (Canary_store.Lang_pm { lang = Canary_artifact_api.Python; _ })) ->
          Some (fun ~output_dir ~variant_key ->
            Canary_artifact_lang.python_inspect_cmd
              ~pkg:"sqlite3" ~watchlist:sqlite_python_watchlist ~output_dir ~variant_key ())
      | Probe (Binding _), _ ->
          Some (fun ~output_dir ~variant_key ->
            Canary_artifact_lang.inspect_opam_pkg_cmd
              ~pkg:"sqlite3" ~watchlist:sqlite_ocaml_watchlist ~output_dir ~variant_key ())
      | _ -> None);
    artifact_name = (function
      | Canary_basic.Lib -> Some "libsqlite3.so"
      | Canary_basic.Binding Canary_artifact_api.OCaml -> Some "sqlite3"
      | Canary_basic.Binding Canary_artifact_api.Python -> Some "sqlite3"
      | _ -> None);
  }
