open Packaging
open Langs.Text.With_string_pkg

module Make (PM : Manager.S with type P.payload = string) = struct
  let get_string_payload pid =
    pid |> PM.P.str_to_pid |> PM.lookup |> PM.P.payload_of_pkg

  let rec interp e =
    match e with
    | Lit s -> s
    | Pid pid -> get_string_payload pid
    | Con (e1, e2) -> interp e1 ^ interp e2
end

module Demo_config : Manager.CONFIG = struct
  let pkgm_id = "text"
  let local_root = Filename.concat (Sys.getcwd ()) ("_local_root_" ^ pkgm_id)
  let remote_root = Filename.concat (Sys.getcwd ()) ("_remote_root_" ^ pkgm_id)
end

module Basic_pkgm =
  Basic_manager.Make (Package.String_no_dep_pkg) (Store.Pkg_table) (Demo_config)

module Basic_interp = Make (Basic_pkgm)
