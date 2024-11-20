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

let () = Poly_cmd.main ()
