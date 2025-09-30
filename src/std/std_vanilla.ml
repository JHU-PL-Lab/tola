module More_fn = struct
  let rec naive_fix step e = step (naive_fix step) e

  (* let chain_compare f1 f2 =
       let r1 = f1 () in
       if r1 = 0 then f2 () else r1

     let just_side_effect = ignore

     let ignore2 _ _ = () *)

  let fn_lift2 f fl a b = f (fl a) (fl b)
end

include More_fn

module type OrderedTypePp = sig
  include Map.OrderedType

  val pp : t Fmt.t
end

module IntPp = struct
  include Int

  let pp = Fmt.int
end

module StringPp = struct
  include String

  let pp = Fmt.string
end

let pp_std_set set_iter pp_elem oc s =
  Fmt.(vbox @@ iter ~sep:nop set_iter pp_elem) oc s

let pp_std_table table_iter pp_key pp_elem oc s =
  Fmt.(vbox @@ iter_bindings ~sep:nop table_iter (pair pp_key pp_elem)) oc s
(* let pp_dump_std_table ?(name = "set") iter pp_elem oc s =
   let pp_name oc _ = Fmt.string oc name in
   (Fmt.Dump.iter_bindings iter pp_name Fmt.(string ++ cut) pp_elem) oc s *)

module File_util = struct
  open Stdlib

  module File_infix = struct
    (* The precedence in OCaml is (See https://v2.ocaml.org/manual/expr.html#ss:precedence-and-associativity for full):
       (functio application) > `/...` > `@...` > `^...` > `$/`.
       Therefore, if we have
       "1" ^ "a" // "a" ^ "2";;
       "1" ^ "b" @/ "b" ^ "2";;
       "1" ^ "b" $/ "b" ^ "2";;

       It should be equivalent to
       "1" ^ ("a" // "a") ^ "2";;
       "1" ^ ("b" @/ "b") ^ "2";;
       ("1" ^ "b") $/ ("b" ^ "2");;
    *)
    let ( $/ ) a b = Filename.concat a b
  end

  open File_infix

  let read_file_all path = In_channel.with_open_text path In_channel.input_all

  let write_file_all path content =
    Out_channel.with_open_text path (fun c ->
        Out_channel.output_string c content)

  let write_marshal file v =
    let oc = open_out file in
    Marshal.to_channel oc v [];
    close_out oc

  let read_marshal file =
    let ic = open_in file in
    let v = Marshal.from_channel ic in
    close_in ic;
    v

  let remove_dir path =
    let rec loop path =
      Sys.readdir path
      |> Array.iter (fun sub ->
             let subpath = path $/ sub in
             if Sys.is_directory subpath then loop subpath
             else Sys.remove subpath);
      Sys.rmdir path
    in
    if Sys.file_exists path && Sys.is_directory path then loop path
end

include File_util
(* 
module Sys_util_not_used = struct
  let run_command_output cmd =
    let ic = Unix.open_process_in cmd in
    let result = In_channel.input_all ic |> String.trim in
    close_in ic;
    result

  (* BUGGY: buffer *)
  let run_command_out cmd pipe_in bds =
    (* "oc | (cat | sh)" *)
    let ic, oc, ec = Unix.open_process_full cmd bds in
    close_in ec;
    output_string oc pipe_in;
    close_out oc;
    let result = In_channel.input_all ic |> String.trim in
    close_in ic;
    result

  let run_command_unix cmd =
    let status = Unix.system cmd in
    match status with
    | Unix.WEXITED code -> code
    | Unix.WSIGNALED signal -> -signal
    | Unix.WSTOPPED signal -> -signal
end *)

module Make_compares (S : sig
  type t

  val compare : t -> t -> Core.Ordering.t
end) =
struct
  open S

  let eq v1 v2 =
    match compare v1 v2 with Less -> false | Equal -> true | Greater -> false

  let lt v1 v2 =
    match compare v1 v2 with Less -> true | Equal -> false | Greater -> false

  let le v1 v2 =
    match compare v1 v2 with Less -> true | Equal -> true | Greater -> false

  let gt v1 v2 =
    match compare v1 v2 with Less -> false | Equal -> false | Greater -> true

  let ge v1 v2 =
    match compare v1 v2 with Less -> false | Equal -> true | Greater -> true
end

module Id = struct
  type t = Id of string [@@deriving eq, ord]

  let str s = Id s
  let pp oc (Id x) = Fmt.string oc x
  let str_of (Id s) = s

  module With_compare = struct
    type nonrec t = t

    let compare = compare
  end

  module Set = struct
    include Set.Make (With_compare)

    let pp = pp_std_set iter pp
  end

  module Map = struct
    include Map.Make (With_compare)

    let pp pp_ele = pp_std_table iter pp pp_ele
    let keys map = map |> to_seq |> Seq.map fst |> Set.of_seq
  end
end
