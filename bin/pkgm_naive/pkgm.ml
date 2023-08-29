module PM = Langs.Text.Pkgm_persisted

let info_ _ = Printf.printf "%s\n" (PM.info ())

open Cmdliner

let dummy = Arg.(value & opt string "dummy" & info [ "dummy" ])
let pid = Arg.(value & pos 0 string "" & info [])
let pkg = Arg.(value & pos 1 string "" & info [])

let install pid pkg =
  PM.install pid pkg;
  Printf.printf "installed %s %s\n" pid pkg

let install_cmd name =
  let doc = "doc" in
  let info = Cmd.info name ~doc in
  Cmd.v info Term.(const install $ pid $ pkg)

let uninstall pid =
  PM.uninstall pid;
  Printf.printf "uninstalled %s\n" pid

let uninstall_cmd name =
  let doc = "doc" in
  let info = Cmd.info name ~doc in
  Cmd.v info Term.(const uninstall $ pid)

let reset_store _ = PM.reset ()

let reset_cmd name =
  let doc = "doc" in
  let info = Cmd.info name ~doc in
  Cmd.v info Term.(const reset_store $ dummy)

let info_cmd name =
  let doc = "doc" in
  let info = Cmd.info name ~doc in
  Cmd.v info Term.(const info_ $ dummy)

let main_cmd =
  let doc = "doc" in
  let info = Cmd.info "top" ~doc in
  Cmd.group info
    [
      install_cmd "install";
      install_cmd "i";
      uninstall_cmd "uninstall";
      uninstall_cmd "u";
      reset_cmd "reset";
      info_cmd "info";
    ]

let main () = exit (Cmd.eval main_cmd)
let () = main ()
