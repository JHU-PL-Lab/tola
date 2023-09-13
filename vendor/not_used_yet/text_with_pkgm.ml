open Packaging
open Langs.Text.With_string_pkg

module Make (PM : Naive_manager.NAIVE_MANAGER) = struct
  let rec interp e =
    match e with
    | Lit s -> s
    | Pid pid -> PM.P.pkg_to_str (PM.lookup (PM.P.str_to_pid pid))
    | Con (e1, e2) -> interp e1 ^ interp e2
end

module Global_config : Naive_manager.NAIVE_CONFIG = struct
  let home = Sys.getenv "HOME"
  let super_root = home ^ "/.pkgm"
  let pkgm_id = "text"
end

module Naive_pkgm =
  Naive_manager.Make (Package.String_pkg) (Store.Pkg_table) (Global_config)

module Demo_config : Basic_manager.BASIC_CONFIG = struct
  let pkgm_id = "text"
  let local_root = Filename.concat (Sys.getcwd ()) ("_local_root_" ^ pkgm_id)
  let remote_root = Filename.concat (Sys.getcwd ()) ("_remote_root_" ^ pkgm_id)
end

module Basic_pkgm =
  Basic_manager.Make (Package.String_pkg) (Store.Pkg_table) (Demo_config)

module Basic_interp = Make (Basic_pkgm)
