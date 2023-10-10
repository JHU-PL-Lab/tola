open Packaging
open Std.File_infix

(* parser goes here *)
(* TODO *)
type tokens = String of string | Pid of string

let regex = Str.regexp "#import"

let parse_import s = String.sub s (String.length "#import") 
  (String.length s - String.length "#import") |> String.trim |> 
    String.split_on_char ' ' |> List.map (fun x -> Pid x)

(* let rec parse = function *)
(*   | [] -> [] *)
(*   | hd::tl -> if Str.string_match regex hd 0 then (parse_import hd)@parse tl *)
(*               else (String hd)::parse tl *)

  let parse file = 
    let rec parse_aux = function 
      | [] -> []
      | hd::tl -> if Str.string_match regex hd 0 then (parse_import hd)@parse_aux tl
              else (String hd)::parse_aux tl
  in file |> String.split_on_char '\n' |> List.filter (fun s -> s <> String.empty) |> parse_aux

module Make (PM : Manager.S with type P.payload = string) = struct
  let get_string_payload pid = 
    pid |> PM.P.str_to_pid |> PM.lookup |> PM.P.payload_of_pkg
  
  let expander e = 
    let rec expander_aux ret e =
    match e with 
    | [] -> ret
    | hd::tl -> let x =
      match hd with
      | String s -> s
      | Pid pid -> (get_string_payload pid |> parse |> expander_aux "")
      in expander_aux (ret^x^"\n") tl
    in expander_aux "" e
end    

module Basic_config : Manager.CONFIG = struct
  let pkgm_id = "_no_dep_shell"
  let local_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_local"
  let remote_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_remote"
  let store_name = "main.shell"
end

module Basic_pkgm =
  Basic_manager.Make (Package.String_no_dep_pkg) (Store.Pkg_table)
    (Basic_config)

module Basic_interp = Make (Basic_pkgm)
