open Cmdliner

(* The interface looks a bit weird to me. It shouldn't need two arguments.
  If this module is put inside of some manager's Make, we should eliminate the first argument.
*)

module Make (PM : Manager.S) (M : Manager.One with type t = PM.t) = struct
  let pid = Arg.(value & pos 0 string "" & info [])

  (* let pkg = Arg.(value & pos 1 string "" & info []) *)
  let pkg = Arg.(required & pos 1 (some string) None & info [])

  let install pid pkg =
    if String.length pkg > 0 then (
      PM.install M.manager (PM.P.str_to_pid pid) (PM.P.str_to_pkg pkg);
      Printf.printf "installed %s %s\n" pid pkg)
    else ()

  let install_cmd name =
    let doc = "doc" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const install $ pid $ pkg)

  let uninstall pid =
    PM.uninstall M.manager (PM.P.str_to_pid pid);
    Printf.printf "uninstalled %s\n" pid

  let uninstall_cmd name =
    let doc = "doc" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const uninstall $ pid)

  let reset_store _ = PM.reset M.manager

  let reset_cmd name =
    let doc = "doc" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const reset_store $ const ())

  let info_ _ = Printf.printf "%s\n" (PM.info M.manager)

  let info_cmd name =
    let doc = "doc" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const info_ $ const ())

  let publish pid pkg =
    PM.publish M.manager (PM.P.str_to_pid pid) (PM.P.str_to_pkg pkg);
    Printf.printf "published %s %s\n" pid pkg

  let publish_cmd name =
    let doc = "doc" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const publish $ pid $ pkg)

  let unpublish pid =
    PM.unpublish M.manager (PM.P.str_to_pid pid);
    Printf.printf "unpublished %s\n" pid

  let unpublish_cmd name =
    let doc = "doc" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const unpublish $ pid)

  let fetch pid =
    PM.fetch M.manager (PM.P.str_to_pid pid);
    Printf.printf "fetch %s\n" pid

  let fetch_cmd name =
    let doc = "doc" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const fetch $ pid)

  (* let remote_info _ = Printf.printf "%s\n" (PM.remote_info M.manager)

  let remote_info_cmd name =
    let doc = "doc" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const remote_info $ const ()) *)

  let main_cmd =
    let doc = "doc" in
    let info = Cmd.info (PM.config M.manager).pkgm_id ~doc in
    Cmd.group info
      [
        install_cmd "install";
        install_cmd "i";
        uninstall_cmd "uninstall";
        uninstall_cmd "u";
        reset_cmd "reset";
        info_cmd "info";
        publish_cmd "publish";
        publish_cmd "p";
        unpublish_cmd "unpublish";
        unpublish_cmd "up";
        fetch_cmd "fetch";
        fetch_cmd "f";
        (* remote_info_cmd "remote-info";
        remote_info_cmd "rinfo"; *)
      ]

  let main () = exit (Cmd.eval main_cmd)
end
