open Packaging
open Std.File_infix

type tokens = String of string | Pid of string

let regex = Str.regexp "#import"

let parse_import s = String.sub s (String.length "#import") 
  (String.length s - String.length "#import") |> String.trim |> 
    String.split_on_char ' ' |> List.map (fun x -> Pid x)


let parse file = 
  let rec parse_aux = function 
    | [] -> []
    | hd::tl -> if Str.string_match regex hd 0 then (parse_import hd)@parse_aux tl
            else (String hd)::parse_aux tl
in file |> String.split_on_char '\n' |> List.filter (fun s -> s <> String.empty) |> parse_aux

module Make (PM : Manager.S with type P.payload = string) = struct
  let get_string_payload pid = 
    pid |> PM.P.str_to_pid |> PM.lookup |> PM.P.payload_of_pkg
 

  let rec expander ?(ret = "") e = 
    match e with 
    | [] -> ret
    | hd::tl -> let x =
      match hd with
      | String s -> s
      | Pid pid -> (get_string_payload pid |> parse |> expander)
      in expander ~ret:(ret^x^"\n") tl

end    

module Basic_config : Manager.CONFIG = struct
  let pkgm_id = "_static_shell"
  let local_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_local"
  let remote_root = Sys.getcwd () $/ "_pm_root" $/ pkgm_id ^ "_remote"
  let store_name = "main.sh"
end

module Basic_pkgm =
  Basic_manager.Make (Package.String_no_dep_pkg) (Store.Pkg_table)
    (Basic_config)

module Basic_interp = Make (Basic_pkgm)
