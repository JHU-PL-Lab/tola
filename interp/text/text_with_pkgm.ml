open Packaging
open Langs.Text.With_string_pkg

(* TODO: the problem is lambda_text requires a string-based PM.
   If we have to feed it an arbitrary PM, we have to convert it to a string
*)
(*
   module Make (PM : Manager.S with type P.payload = string ) = struct
     let get_string_payload pid =
       pid |> PM.P.str_to_pid |> PM.lookup |> PM.P.payload_of_pkg
*)
(* module Make (PM : Manager.S with type P.payload = string) = struct *)
module Make (PM : Manager.S) = struct
  let get_string_payload pid =
    pid |> PM.P.str_to_pid |> PM.lookup |> PM.P.pkg_to_str
  (* PM.P.payload_of_pkg *)

  let rec interp e =
    match e with
    | Lit s -> s
    | Pid pid -> get_string_payload pid
    | Con (e1, e2) -> interp e1 ^ interp e2
end

module Demo_config : Manager.CONFIG = struct
  open Std.File_infix

  let pkgm_id = "text"
  let local_root = Sys.getcwd () $/ "_local_root_" ^ pkgm_id
  let remote_root = Sys.getcwd () $/ "_remote_root_" ^ pkgm_id
end

(* module Basic_pkgm : Manager.S with type P.payload = string = *)
module Basic_pkgm =
  Basic_manager.Make (Package.String_no_dep_pkg) (Store.Pkg_table) (Demo_config)

module Basic_interp = Make (Basic_pkgm)
