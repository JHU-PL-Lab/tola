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

module Make (PM : Manager.S with type P.payload = string) = struct
  let lookup_pkg_payload pm pname =
    pname |> PM.lookup_local pm |> PM.P.payload_of_pkg

  let rec expander ?(acc = "") pm e =
    match e with
    | [] -> acc
    | hd :: tl ->
        let x =
          match hd with
          | String s -> s
          | Pid pid ->
              let payload_raw = lookup_pkg_payload pm pid in
              let payload = Fmt.str "%s=\"%s\"\n" pid payload_raw in
              payload |> parse |> expander pm
        in
        expander ~acc:(acc ^ x ^ "\n") pm tl

  let interp_s pm s =
    let src = s |> parse |> expander pm in
    src |> Stdlib.Sys.command |> ignore;
    src
end
