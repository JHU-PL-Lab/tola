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
  let exist = Sys.file_exists dest && Sys.is_directory dest in
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
    let idx = String.rindex filename '.' in
    String.sub filename (idx + 1) (String.length filename - idx - 1)
  with Not_found -> ""

let split_extension filename =
  try
    let idx = String.rindex filename '.' in
    Some
      ( String.sub filename 0 idx,
        String.sub filename (idx + 1) (String.length filename - idx - 1) )
  with Not_found -> None

let expand_middle_name filename middle ext0 =
  match split_extension filename with
  | Some (name, ext) ->
      if ext = ext0 then String.concat "." [ name; middle; ext ]
      else filename ^ ".gen"
  | None -> filename ^ ".gen"
