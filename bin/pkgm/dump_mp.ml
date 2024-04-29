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
module VL = Version_logic.Multi_part_logic

(* let dump_parse s =
     let pid, version, op = Multi_part.Logic.parse_exp s in
     Fmt.pr "%s %s %s" pid (Multi_part.to_str version) op

   let () = dump_parse "foo<=1-a-b" *)

let dump_parse s =
  let exp = s |> Sexplib.Sexp.of_string |> VL.exp_of_sexp in
  Fmt.pr "%s" (exp |> VL.sexp_of_exp |> Base.Sexp.to_string_hum)

let () = dump_parse "(<= foo 1.a.b)"

let dump_deps s =
  let deps = s |> Sexplib.Sexp.of_string |> VL.deps_of_sexp in
  List.iter
    ~f:(fun exp ->
      Fmt.pr "%s" (exp |> VL.sexp_of_exp |> Base.Sexp.to_string_hum))
    deps;
  Fmt.pr "@.";
  let result = VL.solve deps in
  (match result with
  | Some ans -> Fmt.pr "%a" VL.pp_answer ans
  | None -> Fmt.pr "none");
  Fmt.pr "@."

let () =
  dump_deps "((= foo 1) (in foo (1 2)))";
  dump_deps "((> foo 1) (in foo (1 2)))";
  dump_deps "((> foo 1) (< foo 3) (in foo (1 2 3)))";
  dump_deps "((>= foo 2) (<= foo 2) (in foo (1 2 3)))";
  dump_deps "((>= foo 2) (>= bar 3) (in foo (1 2 3)) (in bar (1 2 3)))";
  dump_deps
    "((~> foo 1.1 0) (~> bar 1.2 1) (~> baz 1.2 2) (in foo (1.1 1.2 1.3)) (in \
     bar (1.1 1.2 1.3)) (in baz (1.1 1.2 1.3)))";
  (* dump_deps
     "\n\
      ((<= foo 1.a.b)\n\
      (< foo 1.a.b.2)\n\
      (= bar 1.a.b.2)\n\
      (> baz 1.a.b.2)\n\
      (~> baz 1213123 2)\n\
      )\n"; *)
  ()
