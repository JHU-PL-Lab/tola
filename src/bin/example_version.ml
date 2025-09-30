open Tola_std

module DL_map =
  Versioned_maps.Multi_alist_map.Make (Std_vanilla.IntPp) (Std_vanilla.StringPp)

let dm1 =
  DL_map.(create |> add "a" 1 2 |> add "a" 1 3 |> add "a" 2 4 |> add "d" 3 4)

let () = DL_map.dump Fmt.int dm1

module type S = sig
  type t
  type pair = { a1 : t; a2 : t }
end

module I : S = struct
  type t = int
  type pair = { a1 : int; a2 : int }
end

module With_string (M : S) : S = struct
  type t = M.t * string
  type pair = { a1 : t; a2 : t }
end

module Foo = With_string (I)
open Base
open Versioning
module PN = Packaging.Package.String_pname

module VL =
  Version_logic.Make
    (struct
      type pname = PN.t [@@deriving yojson]

      let pname_to_str = PN.t_to_str
      let str_to_pname = PN.str_to_t
      let compare = PN.compare
    end)
    (Multi_part)

(* module VL =
  Version_logic.Make
    (Packaging.Package.Legacy_string_pkg) *)
(* (Versioning.Multi_part) *)

(* let dump_parse s =
     let pid, version, op = Multi_part.Logic.parse_exp s in
     Fmt.pr "%s %s %s" pid (Multi_part.to_str version) op

   let () = dump_parse "foo<=1-a-b" *)

let dump_parse s =
  let exp = VL.exp_of_str s in
  Fmt.pr "%s" (exp |> VL.sexp_of_exp |> Base.Sexp.to_string_hum)

let () = dump_parse "(<= foo 1.a.b)"

let dump_deps ?(opt = false) s =
  let deps = VL.exp_of_str s in
  let result = VL.solve ~opt deps in
  (match result with
  | Some ans -> Fmt.pr "[SAT]%a" VL.pp_answer ans
  | None -> Fmt.pr "[UNSAT]");
  Fmt.pr "@."

let () =
  dump_deps "(and (= foo 1) (in foo (1 2)))";
  dump_deps "(and (> foo 1) (in foo (1 2)))";
  dump_deps "(and (> foo 1) (< foo 3) (in foo (1 2 3)))";
  dump_deps "(and (>= foo 2) (<= foo 2) (in foo (1 2 3)))";
  dump_deps "(and (>= foo 2) (>= bar 3) (in foo (1 2 3)) (in bar (1 2 3)))";
  dump_deps
    "(and (~> foo 1.1 0) (~> bar 1.2 1) (~> baz 1.2 2) (in foo (1.1 1.2 1.3)) \
     (in bar (1.1 1.2 1.3)) (in baz (1.1 1.2 1.3)))";
  ()

let () =
  let ac_1_0 = "(and (= ac 1.0) (>= p1 1.0))" in
  let ac_1_1 = "(and (= ac 1.1) (>= p1 1.1))" in
  let remote = Fmt.str "(or %s %s)" ac_1_0 ac_1_1 in
  let local_a = "(= p1 1.0)" in
  let deps_a = Fmt.str "(and %s %s)" local_a remote in
  dump_deps deps_a;
  let local_b = "(= p1 1.1)" in
  let deps_b = Fmt.str "(and %s %s)" local_b remote in
  dump_deps deps_b
