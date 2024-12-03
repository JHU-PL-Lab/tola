open Packaging
module P = Packaging.Package.Basic_pkg
module V = Versioning.Multi_part
module Poly = Poly_manager.Make (P) (V)

let pkgm_config =
  Packaging.Spec.mk_demo_config "lambda_text" "lt_multipart" "main.json"

let pkgm_state = Poly.init pkgm_config

module Poly_cmd = struct
  open Cmdliner

  let pid = Arg.(value & pos 1 string "pid" & info [])
  let pkg = Arg.(value & pos 2 string "pkg" & info [])
  let bin = Arg.(value & pos 0 string "bin" & info [])
  let input = Arg.(value & pos 1 string "input" & info [])
  let output = Arg.(opt (some string) None & info [ "output" ])
  let local_path = Arg.(opt (some string) None & info [ "local_path" ])
  let lang = Arg.(opt (some string) None & info [ "lang" ])
  let pkgm = Arg.(opt (some string) None & info [ "pkgm" ])
  let info_ _ = Printf.printf "%s\n" (Poly.info pkgm_state)

  let info_cmd name =
    let doc = "info" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const info_ $ const ())

  let expand_file input =
    let raw_source = Std.read_file_all input in
    let source = raw_source in
    let expanded_filename = input ^ ".expanded" in
    Std.write_file_all expanded_filename source

  (* `lang` is used to find the _including_ syntax
     `pkgm` is used to find the correct pkgm root path *)
  let run bin input output local_path lang pkgm =
    (* let cmd = String.concat " " [ bin; input ] in
       ; *)
    Fmt.(
      pr "[DEBUG]@.input=%s@.output=%a@.local_path=%a@.lang=%a@.pkgm=%a@." input
        (option string) output (option string) local_path (option string) lang
        (option string) pkgm);

    let cmd = Printf.sprintf "%s --version > /dev/null 2>&1" bin in
    Fmt.pr "[CMD] %s\n" cmd;
    let env_path = Sys.getenv "PATH" in
    (* Printf.printf "[PATH] %s\n" env_path; *)
    (match local_path with
    | Some local_path when not (Filename.is_relative local_path) ->
        Unix.putenv "PATH" (local_path ^ ":" ^ env_path)
        (* Printf.printf "[PATH] %s\n" (Sys.getenv "PATH") *)
    | _ -> ());
    let status = Sys.command cmd in
    if status <> 0 then Fmt.pr "[Error] %d@." status

  let run_cmd name =
    let doc = "run" in
    let info = Cmd.info name ~doc in
    Cmd.v info
      Term.(
        const run $ bin $ input $ Arg.value output $ Arg.value local_path
        $ Arg.value lang $ Arg.value pkgm)

  let main_cmd =
    let doc = "doc" in
    let info = Cmd.info "top" ~doc in
    Cmd.group info [ info_cmd "info"; run_cmd "run" ]

  let main () = exit (Cmd.eval main_cmd)
end

(* let () =
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
   () *)

let () = Poly_cmd.main ()
