open Packaging
open Langs.Text.With_string_pkg

module Make (PM : Packaging.Naive.NAIVE_MANAGER) = struct
  let rec interp e =
    match e with
    | Lit s -> s
    | Pid pid -> PM.P.pkg_to_str (PM.lookup (PM.P.str_to_pid pid))
    | Con (e1, e2) -> interp e1 ^ interp e2
end

module Global_config : Naive.NAIVE_CONFIG = struct
  let home = Sys.getenv "HOME"
  let pkgm_root = home ^ "/.pkgm"
  let pkgm_id = "text"
end

module Pkgm_marshal =
  Naive_manager_marshal.Make (Package.String_pkg) (Shared.Pkg_table)
    (Global_config)

module Local_demo_config : Packaging.Naive.NAIVE_CONFIG = struct
  let pkgm_root = Filename.concat (Sys.getcwd ()) "demo"
  let pkgm_id = "text"
end

module Pkgm =
  Naive_manager.Make (Package.String_pkg) (Shared.Pkg_table) (Local_demo_config)

module Interp = Make (Pkgm)
