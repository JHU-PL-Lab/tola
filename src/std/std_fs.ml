open! Core
open Std_fn

(* The precedence in OCaml is (See https://v2.ocaml.org/manual/expr.html#ss:precedence-and-associativity for full):
  (functio application) > `/...` > `@...` > `^...` > `$/`.
  Therefore, if we have
  "1" ^ "a" // "a" ^ "2";;
  "1" ^ "b" @/ "b" ^ "2";;
  "1" ^ "b" $/ "b" ^ "2";;

  It should be equivalent to
  "1" ^ ("a" // "a") ^ "2";;
  "1" ^ ("b" @/ "b") ^ "2";;
  ("1" ^ "b") $/ ("b" ^ "2");;
*)

let ( $/ ) a b = Filename.concat a b

let is_sub ~parent ~child =
  if Filename.is_absolute parent && Filename.is_absolute child then
    String.is_prefix child ~prefix:parent
  else false

(* Stdio *)
let stdin_iter f = In_channel.input_all In_channel.stdin |> f |> Fmt.pr "%s@."

let stdin_iter_print f =
  In_channel.input_all In_channel.stdin |> f |> Fmt.pr "%s@."

(* Reading and writing to files *)
(* These two functions is provided by Core, rather than Base *)
let read_file path = In_channel.read_all path
let write_file path content = Out_channel.write_all path ~data:content

let write_marshal file v =
  Out_channel.with_file file ~f:(fun oc -> Marshal.to_channel oc v [])

let read_marshal file =
  In_channel.with_file file ~f:(fun ic -> Marshal.from_channel ic)

let files_and_dirs_flat ?(sort = true) ?(compare = String.Caseless.compare) dir
    =
  let (files : string list), (dirs : string list) =
    Sys_unix.ls_dir dir
    |> List.partition_map ~f:(fun sub ->
           let path = dir $/ sub in
           match (Sys_unix.is_file path, Sys_unix.is_directory path) with
           | `Yes, `No -> Either.First path
           | `No, `Yes -> Either.Second path
           | _, _ ->
               failwithf "Unknown file type: %s with %B, %B" path
                 (Sys_unix.is_file_exn path)
                 (Sys_unix.is_directory_exn path)
                 ())
  in
  if sort then (List.sort ~compare files, List.sort ~compare dirs)
  else (files, dirs)

(* sorted and depth-first 
  if ignored symbolic link, the fs is merely a tree
*)
let fold_dir ~f_file ?(f_dir_post = nop2) ~init dir =
  let rec walk acc dir =
    let files, dirs = files_and_dirs_flat dir in
    let acc = List.fold files ~init:acc ~f:f_file in
    let acc = List.fold dirs ~init:acc ~f:(fun acc d -> walk acc d) in
    f_dir_post acc dir
  in
  walk init dir

let ls_all dir =
  ignore @@ fold_dir ~f_file:(fun _acc path -> Fmt.pr "%s\n" path) ~init:() dir

let iter_dir ?(f_file = nop) ?(f_dir_post = nop) dir =
  let rec loop dir =
    Sys_unix.ls_dir dir
    |> List.iter ~f:(fun sub ->
           let subpath = dir $/ sub in
           if Sys_unix.is_directory_exn subpath then loop subpath
           else f_file subpath);
    f_dir_post dir
  in
  loop dir

(* File manipulation *)
let remove_dir path =
  if Sys_unix.file_exists_exn path && Sys_unix.is_directory_exn path then
    iter_dir ~f_file:Core_unix.remove ~f_dir_post:Core_unix.rmdir path

(* Shell *)
let expand_home_dir path =
  if String.is_prefix path ~prefix:"~/" then
    let home = Sys_unix.home_directory () in
    home ^ String.sub path ~pos:1 ~len:(String.length path - 1)
  else path
