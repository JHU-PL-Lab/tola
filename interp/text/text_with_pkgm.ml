open Packaging
open Langs.Text.With_string_pkg
open Std.File_infix

module Make (PM : Manager.S with type P.payload = string) = struct
  let get_string_payload pid =
    pid |> PM.P.str_to_pid |> PM.lookup |> PM.P.payload_of_pkg

  let rec interp e =
    match e with
    | Lit s -> s
    | Pid pid -> get_string_payload pid |> Parser.Text_with_pkg.parse |> interp
    | Con (e1, e2) -> interp e1 ^ interp e2
end

module Basic_config : Manager.CONFIG = struct
  let pkgm_id = "_no_dep_lt"
  let local_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_local"
  let remote_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_remote"
  let store_name = "main.md"
end

module Basic_pkgm =
  Basic_manager.Make (Package.String_no_dep_pkg) (Store.Pkg_table)
    (Basic_config)

module Basic_interp = Make (Basic_pkgm)

module Static_dep_config : Manager.CONFIG = struct
  let pkgm_id = "_static_dep_lt"
  let local_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_local"
  let remote_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_remote"
  let store_name = "main.json"
end

module Static_dep_pkgm =
  Basic_manager.Make (Package.String_static_dep_pkg) (Store.Pkg_table)
    (Static_dep_config)

module Static_dep_interp = Make (Static_dep_pkgm)
