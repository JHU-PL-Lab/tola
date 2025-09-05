#load "unix.cma"
(* require "unix.cma" *)

open Unix

(* Abstract Types for Package and Package Managers *)

(* Notes on language enhancement and packaging models *)

(***
We can classify packaging units for a language in two ways:

  type packaging_unit =
    | NativeModule  (* module, class, etc. *)
    | WholeSource   (* script, file, document *)

To support package management in languages without modules, we may enhance the language with constructs like:

  type lang_enhancement =
    | IncludeDirective      (* e.g., `include "foo.md"`, or enhanced to `include-pkg foo` *)
    | MacroSystem           (* e.g., TeX macros, shell functions *)
    | ScriptingHost         (* e.g., embedding a scripting engine *)
    | StagedExecution       (* e.g., preprocess, compile, run *)
    | ImportHook            (* e.g., `importpkg foo` for loading from pkgm *)

We may further define:

  type language_profile = {
    name : string;
    native_unit : packaging_unit;
    enhancements : lang_enhancement list;
  }

Examples:
  let markdown_profile = {
    name = "Markdown";
    native_unit = WholeSource;
    enhancements = [IncludeDirective];
  }

  let tex_profile = {
    name = "TeX";
    native_unit = WholeSource;
    enhancements = [IncludeDirective; MacroSystem];
  }
***)

(* Core store abstraction *)
type local_pkg_store = LocalStore
type remote_pkg_store = RemoteStore

(* Basic package metadata and identification *)
type pkg_name = string
type version = string
type pkg_id = pkg_name * version

(* Abstract type for a package payload *)
type packaging_unit = NativeModule | WholeSource

type 'content pkg = {
  id : pkg_id;
  manifest : string;
  content : 'content;
  unit : packaging_unit;
}

(* Package kinds *)
type kind = Library | Application | Toolchain | Resource

(* Agent roles involved in the system *)
type actor = Author of string | User of string | RemoteAdmin of string

(* Containers or processing phases *)
type stage =
  | FileSystem
  | StaticChecker
  | Runtime
  | RemoteRegistry
  | LocalStore

(* Unified payloads *)
type payload =
  | PkgID of pkg_id
  | Text of string
  | File of string
  | Code of string
  | Binary of string

(* Unified checkpoint: actor + stage + payload *)
type checkpoint = { actor : actor; stage : stage; payload : payload }

(* Epistemic model: observable checks *)
type query =
  | CheckFile of pkg_id
  | CheckRemote of pkg_id
  | CheckInstalled of pkg_id
  | CheckUsable of pkg_id

(* Epistemic belief state *)
type belief_state = {
  known_files : pkg_id list;
  known_remotes : pkg_id list;
  known_installed : pkg_id list;
  known_usable : pkg_id list;
}

(* Refined action structure *)
type action =
  | Create of checkpoint * checkpoint
  | Publish of checkpoint * checkpoint
  | Deliver of checkpoint * checkpoint
  | Install of checkpoint * checkpoint
  | Load of checkpoint * checkpoint
  | Use of checkpoint * checkpoint

let shell_check (q : query) : bool =
  let cmd =
    match q with
    | CheckFile (n, v) -> Printf.sprintf "echo CheckFile %s-%s" n v
    | CheckRemote (n, v) -> Printf.sprintf "echo CheckRemote %s-%s" n v
    | CheckInstalled (n, v) -> Printf.sprintf "echo CheckInstalled %s-%s" n v
    | CheckUsable (n, v) -> Printf.sprintf "echo CheckUsable %s-%s" n v
  in
  match Unix.system cmd with WEXITED 0 -> true | _ -> false

let queries_of_action (a : action) : query list * query list =
  match a with
  | Create _ -> ([], [])
  | Publish (_, to_cp) ->
      ( [ CheckFile (match to_cp.payload with PkgID id -> id | _ -> ("", "")) ],
        [
          CheckRemote
            (match to_cp.payload with PkgID id -> id | _ -> ("", ""));
        ] )
  | Deliver (_, to_cp) ->
      ( [
          CheckRemote (match to_cp.payload with PkgID id -> id | _ -> ("", ""));
        ],
        [
          CheckFile (match to_cp.payload with PkgID id -> id | _ -> ("", ""));
        ] )
  | Install (_, to_cp) ->
      ( [ CheckFile (match to_cp.payload with PkgID id -> id | _ -> ("", "")) ],
        [
          CheckInstalled
            (match to_cp.payload with PkgID id -> id | _ -> ("", ""));
        ] )
  | Load (_, to_cp) ->
      ( [
          CheckInstalled
            (match to_cp.payload with PkgID id -> id | _ -> ("", ""));
        ],
        [
          CheckUsable
            (match to_cp.payload with PkgID id -> id | _ -> ("", ""));
        ] )
  | Use (_, to_cp) ->
      ( [
          CheckUsable (match to_cp.payload with PkgID id -> id | _ -> ("", ""));
        ],
        [] )

let perform (a : action) (s : belief_state) : belief_state =
  let pre, post = queries_of_action a in
  let _ = List.iter (fun q -> ignore (shell_check q)) pre in
  let _, post = queries_of_action a in
  let update field id = if List.mem id field then field else id :: field in
  List.fold_left
    (fun acc q ->
      ignore (shell_check q);
      match q with
      | CheckFile id -> { acc with known_files = update acc.known_files id }
      | CheckRemote id ->
          { acc with known_remotes = update acc.known_remotes id }
      | CheckInstalled id ->
          { acc with known_installed = update acc.known_installed id }
      | CheckUsable id -> { acc with known_usable = update acc.known_usable id })
    s post

(* Example scenarios *)

let opam_actions =
  [
    Create
      ( {
          actor = Author "a1";
          stage = FileSystem;
          payload = Text "opam+dune metadata with source";
        },
        {
          actor = Author "a1";
          stage = StaticChecker;
          payload = Text "opam+dune metadata with source";
        } );
    Publish
      ( {
          actor = Author "a1";
          stage = StaticChecker;
          payload = PkgID ("std", "1.1");
        },
        {
          actor = RemoteAdmin "r1";
          stage = RemoteRegistry;
          payload = PkgID ("std", "1.1");
        } );
    Deliver
      ( {
          actor = Author "a1";
          stage = FileSystem;
          payload = PkgID ("std", "1.1");
        },
        {
          actor = User "u1";
          stage = FileSystem;
          payload = PkgID ("std", "1.1");
        } );
    Install
      ( { actor = User "u1"; stage = FileSystem; payload = PkgID ("std", "1.1") },
        {
          actor = User "u1";
          stage = LocalStore;
          payload = PkgID ("std", "1.1");
        } );
    Load
      ( { actor = User "u1"; stage = LocalStore; payload = PkgID ("std", "1.1") },
        {
          actor = User "u1";
          stage = StaticChecker;
          payload = PkgID ("std", "1.1");
        } );
    Use
      ( {
          actor = User "u1";
          stage = StaticChecker;
          payload = PkgID ("std", "1.1");
        },
        { actor = User "u1"; stage = Runtime; payload = PkgID ("std", "1.1") }
      );
  ]

let pip_actions =
  [
    Create
      ( {
          actor = Author "a1";
          stage = FileSystem;
          payload = Text "setup.py + wheel";
        },
        {
          actor = Author "a1";
          stage = StaticChecker;
          payload = Text "setup.py + wheel";
        } );
    Publish
      ( {
          actor = Author "a1";
          stage = StaticChecker;
          payload = PkgID ("std", "1.1");
        },
        {
          actor = RemoteAdmin "r1";
          stage = RemoteRegistry;
          payload = PkgID ("std", "1.1");
        } );
    Deliver
      ( {
          actor = Author "a1";
          stage = FileSystem;
          payload = PkgID ("std", "1.1");
        },
        {
          actor = User "u1";
          stage = FileSystem;
          payload = PkgID ("std", "1.1");
        } );
    Install
      ( { actor = User "u1"; stage = FileSystem; payload = PkgID ("std", "1.1") },
        {
          actor = User "u1";
          stage = LocalStore;
          payload = PkgID ("std", "1.1");
        } );
    Load
      ( { actor = User "u1"; stage = LocalStore; payload = PkgID ("std", "1.1") },
        { actor = User "u1"; stage = Runtime; payload = PkgID ("std", "1.1") }
      );
    Use
      ( { actor = User "u1"; stage = Runtime; payload = PkgID ("std", "1.1") },
        { actor = User "u1"; stage = Runtime; payload = PkgID ("std", "1.1") }
      );
  ]

let debian_actions =
  [
    Create
      ( {
          actor = Author "a2";
          stage = FileSystem;
          payload = Text "debian control + source layout";
        },
        {
          actor = Author "a2";
          stage = StaticChecker;
          payload = Text "debian control + source layout";
        } );
    Publish
      ( {
          actor = Author "a2";
          stage = StaticChecker;
          payload = PkgID ("coreutils", "9.0");
        },
        {
          actor = RemoteAdmin "r2";
          stage = RemoteRegistry;
          payload = PkgID ("coreutils", "9.0");
        } );
    Deliver
      ( {
          actor = Author "a2";
          stage = FileSystem;
          payload = PkgID ("coreutils", "9.0");
        },
        {
          actor = User "u2";
          stage = FileSystem;
          payload = PkgID ("coreutils", "9.0");
        } );
    Install
      ( {
          actor = User "u2";
          stage = FileSystem;
          payload = PkgID ("coreutils", "9.0");
        },
        {
          actor = User "u2";
          stage = LocalStore;
          payload = PkgID ("coreutils", "9.0");
        } );
    Load
      ( {
          actor = User "u2";
          stage = LocalStore;
          payload = PkgID ("coreutils", "9.0");
        },
        {
          actor = User "u2";
          stage = Runtime;
          payload = PkgID ("coreutils", "9.0");
        } );
    Use
      ( {
          actor = User "u2";
          stage = Runtime;
          payload = PkgID ("coreutils", "9.0");
        },
        {
          actor = User "u2";
          stage = Runtime;
          payload = PkgID ("coreutils", "9.0");
        } );
  ]

let perform_list (actions : action list) (initial : belief_state) : belief_state
    =
  List.fold_left
    (fun acc_state action -> perform action acc_state)
    initial actions

let () =
  let initial =
    {
      known_files = [];
      known_remotes = [];
      known_installed = [];
      known_usable = [];
    }
  in
  let _ = print_endline "\n--- Running debian_actions ---" in
  let _ = perform_list debian_actions initial in
  let initial =
    {
      known_files = [];
      known_remotes = [];
      known_installed = [];
      known_usable = [];
    }
  in
  let _ = print_endline "\n--- Running opam_actions ---" in
  let _ = perform_list opam_actions initial in
  let _ = print_endline "\n--- Running pip_actions ---" in
  let _ = perform_list pip_actions initial in
  ()
