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

  let pid = Arg.(value & pos 1 string "pid" & info [])
  let pkg = Arg.(value & pos 2 string "pkg" & info [])
  let bin = Arg.(value & pos 0 string "bin" & info [])
  let input = Arg.(value & pos 1 string "input" & info [])
  let output = Arg.(opt (some string) None & info [ "output" ])
  let local_path = Arg.(opt (some string) None & info [ "local_path" ])
  let info_ _ = Printf.printf "%s\n" (Poly.info pkgm_state)

  let info_cmd name =
    let doc = "info" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const info_ $ const ())

  let run bin _input _output local_path =
    (* let cmd = String.concat " " [ bin; input ] in
       let raw_source = Std.read_file_all input in
       let source = raw_source in
       let expanded_filename = input ^ ".expanded" in
       Std.write_file_all expanded_filename source; *)
    let cmd = Printf.sprintf "%s --version > /dev/null 2>&1" bin in
    let env_path = Sys.getenv "PATH" in
    (match local_path with
    | Some local_path ->
        Printf.printf "[LOCAL_PATH] %s\n" local_path
        (* Sys.putenv "PATH" (local_path ^ ":" ^ env_path) *)
    | None -> ());

    Printf.printf "[PATH] %s\n" env_path;
    Printf.printf "[CMD] %s\n" cmd;
    let status = Sys.command cmd in
    if status <> 0 then Printf.printf "Error: %d\n" status

  let run_cmd name =
    let doc = "run" in
    let info = Cmd.info name ~doc in
    Cmd.v info
      Term.(const run $ bin $ input $ Arg.value output $ Arg.value local_path)

  let main_cmd =
    let doc = "doc" in
    let info = Cmd.info "top" ~doc in
    Cmd.group info [ info_cmd "info"; run_cmd "run" ]

  let main () = exit (Cmd.eval main_cmd)
end

let () =
  let extract_include str =
    let re = Str.regexp "include(\\([^)]*\\))" in
    if Str.string_match re str 0 then Some (Str.matched_group 1 str) else None
  in
  let () =
    match extract_include "include(foo)" with
    | Some foo -> Printf.printf "Matched: %s\n" foo
    | None -> Printf.printf "No match\n"
  in
  let extract_include str =
    let re = Str.regexp "#include \\([^)]*\\)\n" in
    if Str.string_match re str 0 then Some (Str.matched_group 1 str) else None
  in
  let () =
    match extract_include "#include foo\n" with
    | Some foo -> Printf.printf "Matched: %s\n" foo
    | None -> Printf.printf "No match\n"
  in
  ()

let () = Poly_cmd.main ()
