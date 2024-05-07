open Packaging
open Langs.Lang_text.With_string_pid
open Std.File_infix

module Make_interp (PM : Manager.S with type P.payload = string) = struct
  let get_string_payload pid =
    pid |> PM.P.str_to_pid |> PM.lookup |> PM.P.payload_of_pkg

  let rec interp e =
    match e with
    | Lit s -> s
    | Pid pid -> get_string_payload pid |> Parser.Text_with_pkg.parse |> interp
    | Con (e1, e2) -> interp e1 ^ interp e2
end

(* Naive pkgm, no deps *)

module Basic_config : Manager.CONFIG = struct
  let pkgm_id = "_no_dep_lt"
  let local_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_local"
  let remote_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_remote"
end

module Naive_pkgm =
  Basic_manager.Make
    (Package.Naive_pkg)
    (Versioning.Version_logic.Singleton_version)
    (Basic_config)
    (struct
      let file_name = "main.md"
    end)

module Naive_interp = Make_interp (Naive_pkgm)

(* Basic pkgm, with deps, no versioning *)

module Static_dep_config : Manager.CONFIG = struct
  let pkgm_id = "_static_dep_lt"
  let local_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_local"
  let remote_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_remote"
end

module Static_dep_pkgm =
  Basic_manager.Make
    (Package.Basic_pkg)
    (Versioning.Version_logic.Singleton_version)
    (Static_dep_config)
    (Manager.Pkg_in_json)

module Static_dep_interp = Make_interp (Static_dep_pkgm)

(* Versioned pkgm, with deps, with versioning *)

module Multipart_config = struct
  let pkgm_id = "lt_multipart"
  let local_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_local"
  let remote_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_remote"
end

module Versioned_pkg = Package.Extend_version (Package.Basic_pkg)
module With_string_versioned_pkg = Langs.Lang_text.Make (Versioned_pkg)

module This_table = Hashtbl.Make (struct
  type t = Versioned_pkg.pid

  let equal = Std.fn_lift2 String.equal Versioned_pkg.pid_to_str
  let hash = Hashtbl.hash
end)

module Make_interp_via_pname (PM : Manager.S with type P.payload = string) =
struct
  let get_string_payload pid = pid |> PM.lookup_pname |> PM.P.payload_of_pkg

  let rec interp e =
    match e with
    | Lit s -> s
    | Pid pid -> get_string_payload pid |> Parser.Text_with_pkg.parse |> interp
    | Con (e1, e2) -> interp e1 ^ interp e2
end

module Versioned_pkgm =
  Basic_manager.Make (Versioned_pkg) (Versioning.Multi_part) (Multipart_config)
    (Manager.Pkg_in_json)

module Dyn_interp = Make_interp_via_pname (Versioned_pkgm)
