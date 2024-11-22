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

  let dummy = Arg.(value & opt string "dummy" & info [ "dummy" ])
  let bin = Arg.(value & pos 0 string "bin" & info [])
  let pid = Arg.(value & pos 1 string "pid" & info [])
  let pkg = Arg.(value & pos 2 string "pkg" & info [])
  let info_ _ = Printf.printf "%s\n" (Poly.info pkgm_state)

  let info_cmd name =
    let doc = "info" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const info_ $ dummy)

  let run bin =
    let status = Sys.command bin in
    if status <> 0 then Printf.printf "Error: %d\n" status

  let run_cmd name =
    let doc = "run" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const run $ bin)

  let main_cmd =
    let doc = "doc" in
    let info = Cmd.info "top" ~doc in
    Cmd.group info [ info_cmd "info"; run_cmd "run" ]

  let main () = exit (Cmd.eval main_cmd)
end

let () = Poly_cmd.main ()
