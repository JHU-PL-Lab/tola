open Cmdliner
open Tola_std

let make_cmd name doc f =
  let info = Cmd.info name ~doc in
  Cmd.v info Term.(const f $ const ())

(* The interface looks a bit weird to me. It shouldn't need two arguments.
  If this module is put inside of some manager's Make, we should eliminate the first argument.
*)

module Make (PM : Manager.S) = struct
  let pid_s = Arg.(value & pos 0 string "" & info [])

  (* let pkg = Arg.(value & pos 1 string "" & info []) *)
  let pkg = Arg.(required & pos 1 (some string) None & info [])

  let install pm pid_s pkg =
    if String.length pkg > 0 then (
      PM.install pm (PM.P.str_to_pid pid_s) (PM.P.str_to_pkg pkg);
      Printf.printf "installed %s %s\n" pid_s pkg)
    else ()

  let install_cmd pm name =
    let doc = "install" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const (install pm) $ pid_s $ pkg)

  let uninstall pm pid_s =
    PM.uninstall pm (PM.P.str_to_pid pid_s);
    Printf.printf "uninstalled %s\n" pid_s

  let uninstall_cmd pm name =
    let doc = "uninstall" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const (uninstall pm) $ pid_s)

  let reset_store pm () = PM.reset pm

  let reset_cmd pm name =
    let doc = "reset" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const (reset_store pm) $ const ())

  let info_ pm () = Printf.printf "%s\n" (PM.info pm)

  let info_cmd pm name =
    let doc = "info" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const (info_ pm) $ const ())

  let publish pm pid pkg =
    PM.publish pm (PM.P.str_to_pid pid) (PM.P.str_to_pkg pkg);
    Printf.printf "published %s %s\n" pid pkg

  let publish_cmd pm name =
    let doc = "publish" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const (publish pm) $ pid_s $ pkg)

  let unpublish pm pid =
    PM.unpublish pm (PM.P.str_to_pid pid);
    Printf.printf "unpublished %s\n" pid

  let unpublish_cmd pm name =
    let doc = "unpublish" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const (unpublish pm) $ pid_s)

  let fetch pm pid =
    PM.fetch pm (PM.P.str_to_pid pid);
    Printf.printf "fetch %s\n" pid

  let fetch_cmd pm name =
    let doc = "fetch" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const (fetch pm) $ pid_s)

  (* let remote_info _ = Printf.printf "%s\n" (PM.remote_info M.manager)

  let remote_info_cmd name =
    let doc = "doc" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const remote_info $ const ()) *)

  let interp_cmd pm interp =
    let cfg = PM.config pm in
    let interp_stdin () = Std.run_stdin (interp pm) in
    make_cmd "interp" ("interpreter " ^ cfg.lang_id) interp_stdin

  let main_cmd ?interp pm =
    let doc = "doc" in
    let info = Cmd.info (PM.config pm).pkgm_id ~doc in
    let interp_cmds =
      match interp with Some interp -> [ interp_cmd pm interp ] | None -> []
    in
    Cmd.group info
      ([
         install_cmd pm "install";
         install_cmd pm "i";
         uninstall_cmd pm "uninstall";
         uninstall_cmd pm "u";
         reset_cmd pm "reset";
         info_cmd pm "info";
         publish_cmd pm "publish";
         publish_cmd pm "p";
         unpublish_cmd pm "unpublish";
         unpublish_cmd pm "up";
         fetch_cmd pm "fetch";
         fetch_cmd pm "f";
         (* remote_info_cmd "remote-info";
        remote_info_cmd "rinfo"; *)
       ]
      @ interp_cmds)

  let main pm = exit (Cmd.eval (main_cmd pm))

  let init_to_cmds ?interp cfg =
    match PM.init cfg with Some pm -> [ main_cmd ?interp pm ] | None -> []
end
