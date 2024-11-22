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
