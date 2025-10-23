open Packaging
open Interp

(* we first make *)
let pm_config = Spec.mk_config "_pm/root" "_pm/cache"

module The_lt_manager = struct
  type t = Common.Lt_pkgm.t

  let manager = Common.Lt_pkgm.init (pm_config "lt" "lt" "main.json")
end

module Lt_P_Cmd = Pkgm_cmd.Make (Common.Lt_pkgm) (The_lt_manager)

module Lt_interp =
  Text_interp.Make_interp_via_pname (Common.Lt_pkgm) (The_lt_manager)

module The_md_manager = struct
  type t = Common.String_pkgm.t

  let manager = Common.String_pkgm.init (pm_config "markdown" "md" "main.json")
end

module Md_P_Cmd = Pkgm_cmd.Make (Common.String_pkgm) (The_md_manager)
module Expand = Md_expand.Make (Common.String_pkgm) (The_md_manager)

module The_boat_manager = struct
  type t = Common.Boat_pkgm.t

  let manager = Common.Boat_pkgm.init (pm_config "boat" "boat" "main.json")
end

module Boat_interp =
  Boat_interp.Make_interp (Common.Boat_pkgm) (The_boat_manager)
    (Manager.Default_options)

module Boat_P_Cmd = Pkgm_cmd.Make (Common.Boat_pkgm) (The_boat_manager)

module The_bash_manager = struct
  type t = Common.String_pkgm.t

  let manager = Common.String_pkgm.init (pm_config "bash" "sh" "main.json")
end

module Sh_P_cmd = Pkgm_cmd.Make (Common.String_pkgm) (The_bash_manager)
module Sh_interp = Bash_interp.Make (Common.String_pkgm) (The_bash_manager)

module Main_cmd = struct
  open Cmdliner

  (* terms ingridients *)

  let _pid = Arg.(value & pos 1 string "pid" & info [])
  let _pkg = Arg.(value & pos 2 string "pkg" & info [])
  let bin = Arg.(value & pos 0 string "bin" & info [])
  let input = Arg.(value & pos 1 string "input" & info [])
  let output = Arg.(opt (some string) None & info [ "output" ])
  let local_path = Arg.(opt (some string) None & info [ "local_path" ])
  let lang = Arg.(opt (some string) None & info [ "lang" ])
  let pkgm = Arg.(opt (some string) None & info [ "pkgm" ])
  (* let info_ _ = Printf.printf "%s\n" (Poly.info pkgm_state) *)

  let all_args =
    let doc = "Capture all argument" in
    Arg.(value & pos_all string [] & info [] ~docv:"ARGS" ~doc)

  let all_flags =
    let doc = "Capture all options" in
    Arg.(value & flag_all & info [ "--al" ] ~docv:"OPTS" ~doc)

  let run_raw _ _ =
    let args = Array.to_list Sys.argv in
    Fmt.pr "[DEBUG] args=%a@." (Fmt.Dump.list Fmt.string) args;
    match args with
    | _tola :: _run :: cmd :: argv ->
        let argv = Array.of_list argv in
        Unix.execvp cmd argv
    | _ ->
        prerr_endline "Usage: my_bin <command> [args...]";
        exit 1

  let run_cmd =
    let doc = "Run with all arguments." in
    let info = Cmd.info "run" ~doc in
    Cmd.v info Term.(const run_raw $ all_args $ all_flags)

  (* cmds *)
  let make_cmd name doc f =
    let open Cmdliner in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const f $ const ())
  (* let info_cmd name =
    let doc = "info" in
    let info = Cmd.info name ~doc in
    Cmd.v info Term.(const info_ $ const ()) *)

  (* `lang` is used to find the _including_ syntax
     `pkgm` is used to find the correct pkgm root path *)
  let run_file bin input output local_path lang pkgm =
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

  let run_norm_cmd name =
    let doc = "run normalized with poly package managing" in
    let info = Cmd.info name ~doc in
    Cmd.v info
      Term.(
        const run_file $ bin $ input $ Arg.value output $ Arg.value local_path
        $ Arg.value lang $ Arg.value pkgm)

  let run_lt () =
    In_channel.input_all In_channel.stdin
    |> Langs.Lang_text.Parse.parse |> Lt_interp.interp |> Fmt.pr "%s@."

  let _run_md () =
    In_channel.input_all In_channel.stdin |> Expand.expand |> Fmt.pr "%s@."

  let run_boat () =
    In_channel.input_all In_channel.stdin
    |> Langs.Boat_parse.of_string_no_eol_opt |> Option.get |> Boat_interp.interp
    |> Fmt.pr "%a@." Langs.Lang_boat.pp_exp

  let run_shell () =
    let src =
      In_channel.input_all In_channel.stdin
      |> Bash_interp.parse |> Sh_interp.expander
    in
    (* Fmt.pr "%s@." src; *)
    src |> Sys.command |> ignore

  let main_cmd =
    let doc = "doc" in
    let info = Cmd.info "tola" ~doc in
    Cmd.group info
      [
        Lt_P_Cmd.main_cmd;
        make_cmd "lti" "interpreter lambda_text" run_lt;
        Md_P_Cmd.main_cmd;
        make_cmd "mdi" "interpreter markdown" run_lt;
        Boat_P_Cmd.main_cmd;
        make_cmd "boati" "interpreter boat" run_boat;
        Sh_P_cmd.main_cmd;
        make_cmd "shelli" "interpreter boat" run_shell;
        run_norm_cmd "norm";
        run_cmd;
        (* self *)
      ]

  let main () = exit (Cmd.eval main_cmd)
end

(* 
let expand_file input =
  let raw_source = Std.read_file_all input in
  let source = raw_source in
  let expanded_filename = input ^ ".expanded" in
  Std.write_file_all expanded_filename source

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

let () = Main_cmd.main ()
