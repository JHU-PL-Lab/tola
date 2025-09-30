(* It's a trimmed language for fish shell that focuses on the variable scope

   One motivation to do this is not so directly write a semantics for shell language e.g. bash or fish, but to have a triple structure like

   Shell interpretation: Syntax -> Fish
   Lambda intepretation: Syntax -> Lambda

   I want to reason Fish is isomorphic to Lambda in the way that after observing the state of Lambda, I can write a Fish function that does the same thing.

   Or maybe I can intergrate Syntax with Lambda. The point is to avoid seeing the internals of Fish.
*)

open Tola_std
open Langs.Lang_mantle
module Binding = Two_scoped_binding
open Two_scoped_binding

let _run_prefill_cmd env name =
  let script = Printf.sprintf Mantle_example.script_template name in
  Printf.printf "{{%s}} [%s]\n" script name;
  let command_out = Std.Sys_util.run_command_out ~env "cat | sh" script in
  (* Printf.printf "{%s}\n" command_out; *)
  command_out

let run_cmd bds cmd =
  let command_out =
    let _ = array_of_variables bds in
    Std.Sys_util.run_command_out ~env:[] "cat | sh" cmd
  in
  (* Printf.printf "{%s}\n" command_out; *)
  command_out

let rec interpret ?(debug = false) (bds : bindings) (command : exp) :
    bindings * exp =
  let open Printf in
  let bds', v =
    match command with
    | Unit -> (bds, Unit)
    | Str s -> (bds, Str s)
    | Get name -> (
        match Binding.get name bds with
        | Some bd -> (bds, Str bd.value)
        | None -> (bds, Unit))
    | Set (key, value) ->
        if debug then printf "[Set] %s = %s\n" key value;
        (set key value Controlled bds, Unit)
    | Export (key, value) ->
        if debug then printf "[Export] %s = %s\n" key value;
        (set key value Exported bds, Unit)
    | RunExp (_, exp) ->
        if debug then printf "[RunExp]\n";
        let _, v = interpret bds exp in
        (bds, v)
    | RunProcess (Inherit, cmd) ->
        dump_bindings bds;
        let command_out = run_cmd bds cmd in
        (bds, Str command_out)
    | RunProcess (Custom custom_env, cmd) ->
        dump_namevalue_list custom_env;
        let bds = from_namevalue_list custom_env Controlled in
        let command_out = run_cmd bds cmd in
        (bds, Str command_out)
    | ExpList exps ->
        List.fold_left (fun (bds, _) exp -> interpret bds exp) (bds, Unit) exps
  in
  (bds', v)

let interp_to_str exp =
  let _, v = interpret [] exp in
  str_of_exp v

let () =
  List.iter
    (fun e -> Fmt.pr "Interpreted: %s\n" @@ interp_to_str e)
    Mantle_example.all

(* let interpret0 bds exp = ignore @@ interpret bds exp *)

(* 
let test_shell () =
  let bds = [ ("MY_VAR", "12345"); ("OTHER_VAR", "test") ] in
  let bds_arr = Naive_binding.array_of_bindings bds in
  let cmd =
    Printf.sprintf "%s sh -c \"echo foobar$%s\""
      (Naive_binding.string_of_bindings bds)
      "MY_VAR"
  in
  let s = Std.Sys_util.run_command_output cmd in
  Printf.printf "{%s}\n" s;
  let var_value =
    Std.Sys_util.run_command_out ~env:bds_arr "/bin/echo $MY_VAR" script_content
  in
  Printf.printf "{%s}\n" var_value;
  let var_value =
    Std.Sys_util.run_command_out ~env:bds_arr "/bin/echo $MY_VAR" script_content
  in
  Printf.printf "{%s}\n" var_value;
  let var_value =
    Std.Sys_util.run_command_out ~env:bds_arr "cat | sh" script_content
  in
  Printf.printf "{%s}\n" var_value
*)

(* let () =s
  let env = [| "MY_VAR=123"; "OTHER_VAR=test" |] in
  match Unix.fork () with
  | 0 ->
      (* child process *)
      Unix.execve "/bin/echo" [| "echo"; "$MY_VAR" |] env
  | pid ->
      (* parent process *)
      Printf.printf "Child process PID: %d\n" pid *)

(* /bin/sh is already a new process, so I don't need explicitly 
  yet another *)
(* let reap_child_stdout env =
  let pipe_in, pipe_out = Unix.pipe () in
  let child_cmd = "/bin/sh" in
  let child_cmd_args = [| "sh"; "-c"; "echo $MY_VAR" |] in
  (* let child_cmd = "/bin/echo" in
  let child_cmd_args = [| "echo"; "$MY_VAR" |] in *)
  match Unix.fork () with
  | 0 ->
      (* child process *)
      Unix.close pipe_in;
      Unix.dup2 pipe_out Unix.stdout;
      Unix.close pipe_out;
      ignore @@ Unix.execve child_cmd child_cmd_args env;
      failwith "unreachable"
  | _pid ->
      (* parent process *)
      Unix.close pipe_out;
      let ic = Unix.in_channel_of_descr pipe_in in
      let output = input_line ic in
      close_in ic;
      output *)
