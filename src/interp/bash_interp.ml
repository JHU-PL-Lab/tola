open Base
open Packaging

type tokens = String of string | Pid of string

let regex = Str.regexp "#import"

let parse_import s =
  String.sub s ~pos:(String.length "#import")
    ~len:(String.length s - String.length "#import")
  |> String.strip
  |> String.split_on_chars ~on:[ ' ' ]
  |> List.map ~f:(fun x -> Pid x)

let parse file =
  let rec parse_aux = function
    | [] -> []
    | hd :: tl ->
        if Str.string_match regex hd 0 then parse_import hd @ parse_aux tl
        else String hd :: parse_aux tl
  in
  file
  |> String.split_on_chars ~on:[ '\n' ]
  |> List.filter ~f:(fun s -> not (String.is_empty s))
  |> parse_aux

module Make
    (PM : Manager.S with type P.payload = string)
    (M : Manager.One with type t = PM.t) =
struct
  let lookup_pkg_payload pname =
    pname |> PM.lookup_local M.manager |> PM.P.payload_of_pkg

  let rec expander ?(ret = "") e =
    match e with
    | [] -> ret
    | hd :: tl ->
        let x =
          match hd with
          | String s -> s
          | Pid pid -> lookup_pkg_payload pid |> parse |> expander
        in
        expander ~ret:(ret ^ x ^ "\n") tl
end
