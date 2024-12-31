(* It's a trimmed language for fish shell that focuses on the variable scope

   One motivation to do this is not so directly write a semantics for shell language e.g. bash or fish, but to have a triple structure like

   Shell interpretation: Syntax -> Fish
   Lambda intepretation: Syntax -> Lambda

   I want to reason Fish is isomorphic to Lambda in the way that after observing the state of Lambda, I can write a Fish function that does the same thing.

   Or maybe I can intergrate Syntax with Lambda. The point is to avoid seeing the internals of Fish.
*)

module Variable = struct
  type name = string
  type value = string
  type binding = name * value
  type bindings = binding list

  let array_of_bindings (bds : bindings) : string array =
    Array.of_list @@ List.map (fun (k, v) -> Printf.sprintf "%s=%s" k v) bds

  let string_of_bindings (bds : bindings) : string =
    String.concat " " @@ List.map (fun (k, v) -> Printf.sprintf "%s=%s" k v) bds

  let dump_bindings (bds : bindings) : unit =
    Printf.printf "[Binding]:\n";
    List.iter (fun (k, v) -> Printf.printf "  %s = %s\n" k v) bds
end

open Variable

type external_cmd = string

module Mantle = struct
  (* InheritEnv is the normal lexical scoping
    CustomEnv is like the dynamic scoping but with an explicit rebinding
  *)
  type env_type = InheritEnv | CustomEnv of bindings

  (* 
  The language seems a subset of a full lambda calculus as there is no lambda abstraction 
  a.k.a making a reusable function.
  It's like `App (Fun, ())`, a first-order

  letfun f1 = ... in
  f1 () ...

  *)
  type exp =
    | Set of binding
    | Export of binding
    | RunExp of env_type * exp
    | RunProcess of env_type * external_cmd
    | ExpList of exp list
end

open Mantle

let rec interpret (bds : bindings) (command : exp) : bindings =
  let open Printf in
  let bds' =
    match command with
    | Set (key, value) ->
        printf "[Set] %s = %s\n" key value;
        (key, value) :: bds
    | Export (key, value) ->
        printf "[Export] %s = %s\n" key value;
        (key, value) :: bds
    | RunExp (_, exp) ->
        printf "[RunExp]\n";
        let _ = interpret bds exp in
        bds
    | RunProcess (InheritEnv, _cmd) ->
        dump_bindings bds;
        bds
    | RunProcess (CustomEnv custom_env, _cmd) ->
        dump_bindings custom_env;
        bds
    | ExpList exps -> List.fold_left interpret bds exps
  in
  bds'

let interpret0 bds cmd = ignore @@ interpret bds cmd

[@@@ocamlformat "disable"]
(* https://ocaml.org/p/ocamlformat/0.26.2/doc/manpage_ocamlformat.html *)
let script_content = "
#!/bin/sh
printenv;
echo aaa$MY_VAR
"
[@@@ocamlformat "enable"]

(* let cmd = Printf.sprintf "echo foo$%s" name in *)

let () =
  let bds = [ ("MY_VAR", "12345"); ("OTHER_VAR", "test") ] in
  let bds_arr = array_of_bindings bds in
  let cmd =
    Printf.sprintf "%s sh -c \"echo foobar$%s\"" (string_of_bindings bds)
      "MY_VAR"
  in
  let s = Std.Sys_util.run_command_output cmd in
  Printf.printf "{%s}\n" s;
  let var_value =
    Std.Sys_util.run_command_output_full "/bin/echo $MY_VAR" script_content
      bds_arr
  in
  Printf.printf "{%s}\n" var_value;
  let var_value =
    Std.Sys_util.run_command_output_full "/bin/echo $MY_VAR" script_content
      bds_arr
  in
  Printf.printf "{%s}\n" var_value;
  let var_value =
    Std.Sys_util.run_command_output_full "cat | sh" script_content bds_arr
  in
  Printf.printf "{%s}\n" var_value

let () =
  let script =
    ExpList
      [
        Set ("x", "42");
        Set ("PATH", "/usr/bin");
        Set ("MY_VAR", "hello");
        Export ("MY_VAR2", "hello");
        RunProcess (InheritEnv, "echo $MY_VAR");
        RunProcess (CustomEnv [ ("CUSTOM_VAR", "custom_value") ], "printenv");
        RunExp (InheritEnv, Set ("x", "42"));
      ]
  in
  interpret0 [] script

(* let () =
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
