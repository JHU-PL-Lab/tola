let version = "0.1.14"
(* Caution: DO NOT EDIT! The file is copied from outside. *)

[@@@warning "-32"]

open! Core

module Printing = struct
  let pp_b = Fmt.(using (function true -> "t" | false -> "f") string)
  let pp_bo = Fmt.(using (function true -> "#t" | false -> "#f") string)

  let pp_set pp_val oc =
    let set_iter f set = Set.iter set ~f in
    Fmt.pf oc "{%a}" Fmt.(iter ~sep:(any ",") set_iter pp_val)

  let dump_list s pp = Fmt.pr "@.@[<v>%a@]@;@." (Fmt.list pp) s

  let dump_list domain pp =
    Fmt.(pr "@.%d@.@[<v>%a@]@;@." (List.length domain) (list pp) domain)

  let list_split es =
    let rec loop p1 p2 =
      match p2 with
      | [] -> []
      | e :: es ->
          let p1' = p1 @ [ e ] in
          let p2' = es in
          (p1', p2') :: loop p1' p2'
    in
    ([], es) :: loop [] es

  (* let pp_set ?(name = "set") pp_elem oc s =
     let pp_name oc _ = Fmt.string oc name in
     let set_iter f set = Set.iter set ~f in
     (Fmt.Dump.iter set_iter pp_name pp_elem) oc s *)
  (*
     let mk_pp_set name pp_val =
        let pp_name oc _ = Fmt.string oc name in
        let set_iter f set = Set.iter set ~f in
        Fmt.Dump.iter set_iter pp_name pp_val *)

  (* let mk_pp_set pp_val =
     let set_iter f set = Set.iter set ~f in
     Fmt.(iter ~sep:(any ",") set_iter pp_val) *)

  let pp_tuple3 pp_a pp_b pp_c oc (a, b, c) =
    Fmt.pf oc "(%a, %a, %a)" pp_a a pp_b b pp_c c

  let string_of_opt_int_list ?(none = "-") inputs =
    String.concat ~sep:","
    @@ List.map ~f:(function Some i -> Int.to_string i | None -> none) inputs

  let iter_core_set f set = Set.iter set ~f

  let iteri_core_map f map =
    let core_f ~key ~data = f key data in
    Core.Map.iteri map ~f:core_f

  let iteri_core_hashtbl f map =
    let core_f ~key ~data = f key data in
    Core.Hashtbl.iteri map ~f:core_f
end

include Printing

module More_bool = struct
  (*
  type ternary = True | False | Unknown
  [@@deriving equal, show { with_path = false }]
  
  
     let bool_of_ternary_exn = function
       | True -> true
       | False -> false
       | Unknown -> failwith "ternary unknown"
  
     let bool_of_ternary = function
       | True -> Some true
       | False -> Some false
       | Unknown -> None
  
     let t_and tb1 tb2 =
       match (tb1, tb2) with
       | False, _ | _, False -> False
       | True, True -> True
       | _, _ -> Unknown
  
     let t_or tb1 tb2 =
       match (tb1, tb2) with
       | True, _ | _, True -> True
       | False, False -> False
       | _, _ -> Unknown
  *)

  let set_of_bool b = Set.singleton (module Bool) b
  let just_true = set_of_bool true
  let just_false = set_of_bool false
  let true_or_false = Set.of_list (module Bool) [ true; false ]
end

include More_bool
module Ordering = Core.Ordering

module PartialOrdering = struct
  type t = Less | Equal | Greater | Unknown
end

let compose_compare r1 th2 =
  match r1 with Less | Greater -> r1 | Equal -> th2 ()

module More_list = struct
  let list_split lst =
    let rec loop part1 part2 =
      match part2 with
      | [] -> []
      | e :: es ->
          let part1' = part1 @ [ e ] in
          let part2' = es in
          (part1', part2') :: loop part1' part2'
    in
    ([], lst) :: loop [] lst

  let list_sum = List.sum (module Int) ~f:Fn.id
end

include More_list

module File_utils = struct
  let group_dir ~filter dir =
    let rec loop dir =
      let acc_f, acc_p =
        Sys_unix.fold_dir ~init:([], [])
          ~f:(fun (acc_f, acc_p) path ->
            match String.get path 0 with
            | '.' (* including "." ".." *) | '_' -> (acc_f, acc_p)
            | _ -> (
                let fullpath = Filename.concat dir path in
                match Sys_unix.is_directory fullpath with
                | `Yes -> (acc_f, loop fullpath @ acc_p)
                | `No when filter fullpath -> (fullpath :: acc_f, acc_p)
                | `No -> (acc_f, acc_p)
                | `Unknown -> (acc_f, acc_p)))
          dir
      in
      (dir, List.sort acc_f ~compare:String.compare) :: acc_p
    in
    loop dir
end

module Sys_util = struct
  open Core_unix

  let home_dir : string =
    match Sys.getenv "HOME" with
    | Some dir -> dir
    | None -> (Passwd.getbyuid_exn (Core_unix.getuid ())).dir

  let expand_home path =
    if String.is_prefix path ~prefix:"~/" then
      let home = home_dir in
      home ^ String.sub path ~pos:1 ~len:(String.length path - 1)
    else path

  module Naive_binding = struct
    module Variable = struct
      type name = string
      type value = string
    end

    open Variable

    type binding = name * value
    type bindings = binding list

    let array_of_bindings (bds : bindings) : string array =
      Array.of_list
      @@ List.map ~f:(fun (k, v) -> Printf.sprintf "%s=%s" k v) bds

    let dump_bindings (bds : bindings) : unit =
      Stdio.printf "[Binding]:\n";
      List.iter ~f:(fun (k, v) -> Stdio.printf "  %s = %s\n" k v) bds

    let string_of_bindings (bds : bindings) : string =
      List.map ~f:(fun (k, v) -> Printf.sprintf "%s=%s" k v) bds
      |> String.concat ~sep:" "
  end

  (* BUGGY: buffer. 
    I also think both channels must be read or write only once *)
  (* "oc | (cat | sh)" *)
  (* let run_command_full ~env ?pipe_in cmd =
    let ({ stdin = oc; stdout = ic; stderr = ec } : Process_channels.t) =
      open_process_full ~env cmd
    in
    (match pipe_in with
    | None -> ()
    | Some pipe_in ->
        Out_channel.output_string oc pipe_in;
        Out_channel.close oc);
    let result = In_channel.input_all ic in
    In_channel.close ic;
    In_channel.close ec;
    result *)
  let run_command_full ~env ?pipe_in cmd =
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

  let run_command_out ~env pipe_in cmd =
    let cmd_out, _cmd_err, _errno = run_command_full ~env ~pipe_in cmd in
    cmd_out

  let dump_err_or_signal errsig =
    match errsig with
    | Error (`Exit_non_zero errno) ->
        Fmt.pr "Command failed with error: %s@."
          (Core_unix.Exit.to_string_hum (Error (`Exit_non_zero errno)))
    | Error (`Signal signal) ->
        Fmt.pr "Command was killed by signal: %s@." (Signal.to_string signal)
    | Ok () -> ()

  let run ?(env = []) cmd =
    let cmd_out, cmd_err, errno = run_command_full ~env cmd in
    Fmt.pr "[Stdout]%s" cmd_out;
    Fmt.pr "[Stderr]%s" cmd_err;
    dump_err_or_signal errno;
    ()

  let run_and_capture ?(env = []) cmd =
    let cmd_out, cmd_err, errno = run_command_full ~env cmd in
    if String.length cmd_err > 0 then Fmt.pr "[Stdout]%s" cmd_err;
    dump_err_or_signal errno;
    String.strip cmd_out

  let run_command_unix cmd =
    (match system cmd with
    | Ok () -> ()
    | Error (`Exit_non_zero errno) ->
        Fmt.pr "Command failed with error: %s@."
          (Core_unix.Exit.to_string_hum (Error (`Exit_non_zero errno)))
    | Error (`Signal signal) ->
        Fmt.pr "Command was killed by signal: %s@." (Signal.to_string signal));
    ()
end

module More_Command = struct
  let param_of_command (all_params : 't Command.Param.t) summary : 't =
    let store = ref None in
    let save_param : (unit -> unit) Command.Param.t =
      Command.Param.(all_params >>| fun params () -> store := Some params)
    in
    let command = Command.basic ~summary save_param in
    Command_unix.run command;
    Option.value_exn !store
end

include More_Command
include Std_vanilla
