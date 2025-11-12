open Base
open Interp
open Common
open Tola_std

(* let verbose = true *)

(* let managers = Hashtbl.create (module String) 
    Hashtbl.set managers ~key:"lt" ~data:pm;
*)

(* open Binding.Common *)

let _ = the_os

let _lang_world =
  [
    (* examples for extending pkgm *)
    "lambda_text";
    "markdown";
    "boat";
    "sh";
    (* for better enginnering *)
    (* * lang for envar *)
    "mantle";
    "cmake";
    (* for high-level ecology *)
    "sandpiper";
    (* for low-level binding study *)
    "land_record";
  ]

module Main_cmd = struct
  open Cmdliner

  (* terms ingredients *)
  let _pid = Arg.(value & pos 1 string "pid" & info [])
  let _pkg = Arg.(value & pos 2 string "pkg" & info [])
  let bin = Arg.(value & pos 0 string "bin" & info [])
  let input = Arg.(value & pos 1 string "input" & info [])
  let output = Arg.(opt (some string) None & info [ "output" ])
  let local_path = Arg.(opt (some string) None & info [ "local_path" ])
  let lang = Arg.(opt (some string) None & info [ "lang" ])
  let pkgm = Arg.(opt (some string) None & info [ "pkgm" ])
  (* let info_ _ = Printf.printf "%s\n" (Poly.info pkgm_state) *)

  (* cmds *)
  let run_file bin input output local_path lang pkgm =
    (* let cmd = String.concat " " [ bin; input ] in *)
    Fmt.(
      pr "[DEBUG]@.input=%s@.output=%a@.local_path=%a@.lang=%a@.pkgm=%a@." input
        (option string) output (option string) local_path (option string) lang
        (option string) pkgm);

    let cmd = Printf.sprintf "%s --version > /dev/null 2>&1" bin in
    Fmt.pr "[CMD] %s\n" cmd;
    let env_path = Sys.getenv "PATH" in
    (* Printf.printf "[PATH] %s\n" env_path; *)
    (match local_path with
    | Some local_path when not (Stdlib.Filename.is_relative local_path) ->
        Option.iter env_path ~f:(fun env_path ->
            Unix.putenv "PATH" (local_path ^ ":" ^ env_path))
        (* Printf.printf "[PATH] %s\n" (Sys.getenv "PATH") *)
    | _ -> ());
    (* TODO: use less Stdlib *)
    let status = Stdlib.Sys.command cmd in
    if status <> 0 then Fmt.pr "[Error] %d@." status

  let run_norm_cmd =
    let doc = "run normalized with poly package managing" in
    let info = Cmd.info "norm" ~doc in
    Cmd.v info
      Term.(
        const run_file $ bin $ input $ Arg.value output $ Arg.value local_path
        $ Arg.value lang $ Arg.value pkgm)

  let version =
    let doc = "show tola version" in
    let info = Cmd.info "version" ~doc in
    let version_f () = Fmt.pr "tola version %s\n" Tola_std.Std.version in
    Cmd.v info Term.(const version_f $ const ())

  let main_cmd =
    let doc = "doc" in
    let info = Cmd.info "tola" ~doc in
    Cmd.group info
      (Lt_P_Cmd.init_to_cmds ~interp:Lt_interp.interp_s lt_pm_config
      @ Md_P_Cmd.init_to_cmds ~interp:Md_expand.expand md_pm_config
      @ Boat_P_Cmd.init_to_cmds ~interp:Boat_interp.interp_s boat_pm_config
      @ Sh_P_cmd.init_to_cmds ~interp:Sh_interp.interp_s sh_pm_config
      (* self *)
      @ [ run_norm_cmd; version ])

  let main () =
    (* Fmt.pr "[DEBUG] args=%a@." (Fmt.Dump.list Fmt.string)
      (Array.to_list Sys.argv); *)
    match Array.to_list Stdlib.Sys.argv with
    | _tola :: "run" :: cmd :: cmd_argv ->
        let cmd' = String.concat ~sep:" " (cmd :: cmd_argv) in
        Fmt.pr "[DEBUG] run cmd: %s@." cmd';
        (* Fmt.pr "[DEBUG] run_raw mode@. %s" (String.concat " " (cmd :: argv')); *)
        let argv = Array.of_list cmd_argv in
        Unix.execvp cmd argv
    | _ -> Stdlib.exit (Cmd.eval main_cmd)
end

let () = Main_cmd.main ()

(* I cannot use Cmdliner to forward artibrary commands since I
    cannot know the syntax in advance.

  let all_args =
    let doc = "Capture all argument" in
    Arg.(value & pos_all string [] & info [] ~docv:"ARGS" ~doc)

  let all_flags =
    let doc = "Capture all options" in
    Arg.(value & flag & info [ "flags" ] ~docv:"OPTS" ~doc)

  let run_raw _ _ =
    let args = Array.to_list Sys.argv in
    Fmt.pr "[DEBUG] args=%a@." (Fmt.Dump.list Fmt.string) args;
    match args with
    | _tola :: _run :: cmd :: argv ->
        let argv = Array.of_list argv in
        Unix.execvp cmd argv
    | _ ->
        prerr_endline "Usage: run_raw <command> [args...]";
        exit 1
*)

(* 
let expand_file input =
  let raw_source = In_channel.read_all input in
  let source = raw_source in
  let expanded_filename = input ^ ".expanded" in
  Std.write_file expanded_filename source

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
   () *)
