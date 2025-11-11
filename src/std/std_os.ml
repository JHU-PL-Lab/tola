open! Core
open OpamStd.Sys
open Std_datatype

let the_os = OpamStd.Sys.os ()

let detect_os os =
  let name =
    match os with
    | Linux -> "Linux"
    | Unix -> "Unix"
    | Darwin -> "Darwin"
    | _ -> "Others"
  in
  Fmt.pr "Detected OS: %s@." name

module Cmd = struct
  open Core_unix

  let dump_err errsig =
    match errsig with
    | Error (`Exit_non_zero errno) ->
        Fmt.pr "Command failed with error: %s@."
          (Core_unix.Exit.to_string_hum (Error (`Exit_non_zero errno)))
    | Error (`Signal signal) ->
        Fmt.pr "Command was killed by signal: %s@." (Signal.to_string signal)
    | Ok () -> ()

  (* 
  let run_command_output cmd =
    let ic = Unix.open_process_in cmd in
    let result = In_channel.input_all ic |> String.trim in
    close_in ic;
    result
  *)

  (* BUGGY?: buffer. 
    I also think both channels must be read or write only once *)
  (* "oc | (cat | sh)" *)
  let run_full ~env ?pipe_in cmd =
    let channels =
      (* TODO: inherit the envar from the current process for `opam init` doesn't look a great fix *)
      let envs = [ environment (); Naive_binding.array_of_bindings env ] in
      open_process_full ~env:(Array.concat envs) cmd
    in
    let ({ stdin = oc; stdout = ic; stderr = ec } : Process_channels.t) =
      channels
    in
    (match pipe_in with
    | None -> ()
    | Some pipe_in ->
        Out_channel.output_string oc pipe_in;
        Out_channel.close oc);
    let str_out = In_channel.input_all ic in
    In_channel.close ic;
    let str_err = In_channel.input_all ec in
    In_channel.close ec;
    (str_out, str_err, close_process_full channels)

  (* let run_command_out ~env pipe_in cmd =
    run_full ~env ~pipe_in cmd |> Tuple3.get1 *)

  let run_s ?(env = []) cmd =
    let cmd_out, cmd_err, errno = run_full ~env cmd in
    if String.length cmd_err > 0 then Fmt.pr "[Stdout]%s" cmd_err;
    dump_err errno;
    String.strip cmd_out

  let run0 ?(env = []) cmd = ignore @@ run_full ~env cmd

  let run_command_unix cmd =
    (match Core_unix.system cmd with
    | Ok () -> ()
    | Error (`Exit_non_zero errno) ->
        Fmt.pr "Command failed with error: %s@."
          (Core_unix.Exit.to_string_hum (Error (`Exit_non_zero errno)))
    | Error (`Signal signal) ->
        Fmt.pr "Command was killed by signal: %s@." (Signal.to_string signal));
    ()
end

(* core extension or hacks *)
(* let param_of_command (all_params : 't Command.Param.t) summary : 't =
  let store = ref None in
  let save_param : (unit -> unit) Command.Param.t =
    Command.Param.(all_params >>| fun params () -> store := Some params)
  in
  let command = Command.basic ~summary save_param in
  Command_unix.run command;
  Option.value_exn !store *)
