open! Core

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

(* File manipulation *)
let remove_dir path =
  let rec loop path =
    Sys_unix.readdir path
    |> Array.iter ~f:(fun sub ->
           let subpath = path $/ sub in
           if Sys_unix.is_directory_exn subpath then loop subpath
           else Core_unix.remove subpath);
    Core_unix.rmdir path
  in
  if Sys_unix.file_exists_exn path && Sys_unix.is_directory_exn path then
    loop path

let group_dir ~filter dir =
  let rec loop dir =
    let acc_f, acc_p =
      Sys_unix.fold_dir ~init:([], [])
        ~f:(fun (acc_f, acc_p) path ->
          match String.get path 0 with
          | '.' (* including "." ".." *) | '_' -> (acc_f, acc_p)
          | _ -> (
              let fullpath = dir $/ path in
              match Sys_unix.is_directory fullpath with
              | `Yes -> (acc_f, loop fullpath @ acc_p)
              | `No when filter fullpath -> (fullpath :: acc_f, acc_p)
              | `No -> (acc_f, acc_p)
              | `Unknown -> (acc_f, acc_p)))
        dir
    in
    (dir, List.sort acc_f ~compare:String.compare) :: acc_p
  in
  loop dir
