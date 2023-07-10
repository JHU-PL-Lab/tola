open Feat
open Enum

type nist = Nil | Cons of int * nist

let cons (x, t) = Cons (x, t)
(* let rec nist () : nist enum = just Nil ++ pay (map cons (just 0 ** nist ())) *)

let compute_nist nist = just Nil ++ pay (map cons (just 0 ** nist))
let nist = Core.Memo.recursive ~hashable:Core.Int.hashable compute_nist

open IFSeq

let succ i = Num.add i Num.one

let rec subrange i j s accu =
  if Num.lt i j then
    let accu = get s i :: accu in
    subrange (succ i) j s accu
  else List.rev accu

let subrange i j s = subrange i j s []
let range s = subrange Num.zero (length s) s

open Printf

let test name s =
  printf "Testing %s...\n%!" name;
  (* Test [length]. *)
  printf "  Length: %s\n%!" (Num.to_string (length s));
  (* By calling [range s], test [get] at every index within range. *)
  assert (Num.equal (length s) (Num.of_int (List.length (range s))));
  printf "  Every random access succeeds.\n";
  (* Test [foreach]. We check that it produces the same elements as [get],
     in the same order, and that it produces neither too few nor too many
     elements. *)
  let i = ref Num.zero in
  foreach s (fun x1 ->
      assert (Num.lt !i (length s));
      let x2 = get s !i in
      assert (x1 = x2);
      (* element equality *)
      i := succ !i);
  assert (Num.equal !i (length s));
  printf "  Iteration via foreach is consistent with random access.\n"

let () =
  for s = 0 to 8 do
    test (sprintf "trees of size %d" s) (nist s)
  done
