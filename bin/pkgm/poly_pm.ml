open Packaging
module P = Packaging.Package.Basic_pkg
module V = Versioning.Multi_part
module Poly = Poly_manager.Make (P) (V)

let pkgm_config =
  Packaging.Store.Store_spec.mk_demo_config "lambda_text" "lt_multipart"
    "main.json"

let pkgm_state = Poly.init pkgm_config

module Poly_cmd = struct
  open Cmdliner

  let info_ _ = Printf.printf "%s\n" (Poly.info pkgm_state)
  let dummy = Arg.(value & opt string "dummy" & info [ "dummy" ])

  let info_cmd name =
    let doc = "doc" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const info_ $ dummy)

  let main_cmd =
    let doc = "doc" in
    let info = Cmd.info "top" ~doc in
    Cmd.group info [ info_cmd "info" ]

  let main () = exit (Cmd.eval main_cmd)
end

let () =
  let open Lwt.Syntax in
  let open Lwt.Infix in
  let run_command cmd =
    let* status = Lwt_process.exec (Lwt_process.shell cmd) in
    Lwt.return status
  in

  let _run_command_read cmd =
    let* result = Lwt_process.pread_line (Lwt_process.shell cmd) in
    Lwt.return result
  in

  (* Clone a GitHub repo to a temporary directory *)
  let clone_repo ~repo_url ~dest =
    (* git sparse-checkout *)
    let exist = Sys.file_exists dest && Sys.is_directory dest in
    if not exist then
      let cmd =
        Printf.sprintf "git clone --quiet --depth=1 %s %s" repo_url dest
      in
      let* () = Lwt_io.printl cmd in
      let* () = Lwt_io.printl ("Cloning repository: " ^ repo_url) in
      run_command cmd >>= fun _ ->
      Lwt_io.printl "Repository cloned successfully!"
    else Lwt.return_unit
  in

  (* List the files in a given directory *)
  let _list_directory path =
    let cmd = Printf.sprintf "ls %s" path in
    run_command cmd >>= fun _ -> Lwt_io.printl ("Listing directory: " ^ path)
  in

  let () =
    let repo_url = "https://github.com/arbipher/multiverse" in
    let dest_dir = "_cache/arbipher_multiverse" in
    Lwt_main.run
      (clone_repo ~repo_url
         ~dest:dest_dir (* >>= fun () -> list_directory dest_dir *))
  in
  ()

let () = Poly_cmd.main ()
