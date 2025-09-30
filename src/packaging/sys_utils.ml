open Base
open Lwt.Syntax
open Lwt.Infix

let run_command cmd = Lwt_process.exec (Lwt_process.shell cmd)

let run_command' cmd =
  Lwt_process.exec (Lwt_process.shell cmd) >>= fun _ -> Lwt.return_unit

let _run_command_read cmd =
  let* result = Lwt_process.pread_line (Lwt_process.shell cmd) in
  Lwt.return result

let clone_repo repo_url dest =
  (* git sparse-checkout *)
  let exist = Sys_unix.file_exists_exn dest && Sys_unix.is_directory_exn dest in
  if not exist then
    let cmd =
      Printf.sprintf "git clone --quiet --depth=1 %s %s" repo_url dest
    in
    let* () = Lwt_io.printl cmd in
    let* () = Lwt_io.printl ("[DEBUG]Cloning repository: " ^ repo_url) in
    run_command cmd >>= fun _ -> Lwt.return_unit
  else Lwt.return_unit

let _list_directory path =
  let cmd = Printf.sprintf "ls %s" path in
  run_command cmd >>= fun _ -> Lwt_io.printl ("Listing directory: " ^ path)

let complete cmd = Lwt_main.run cmd

let extension_of filename =
  try
    let idx = String.rindex_exn filename '.' in
    String.sub filename ~pos:(idx + 1) ~len:(String.length filename - idx - 1)
  with Invalid_argument msg -> failwith msg

let split_extension filename =
  try
    let idx = String.rindex_exn filename '.' in
    Some
      ( String.sub filename ~pos:0 ~len:idx,
        String.sub filename ~pos:(idx + 1)
          ~len:(String.length filename - idx - 1) )
  with Invalid_argument msg -> failwith msg

let expand_middle_name filename middle ext0 =
  match split_extension filename with
  | Some (name, ext) ->
      if String.equal ext ext0 then String.concat ~sep:"." [ name; middle; ext ]
      else filename ^ ".gen"
  | None -> filename ^ ".gen"
