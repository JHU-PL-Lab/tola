(* Small probe: exercise zarith's Z (arbitrary-precision integer) API.
   Computes 42! and prints it. Verifies the OCaml binding loads, links to
   libgmp, and a few common operations (multiplication, comparison, conversion)
   round-trip correctly. *)

let () =
  let n = 42 in
  let fact = ref Z.one in
  for i = 1 to n do
    fact := Z.mul !fact (Z.of_int i)
  done;
  Printf.printf "%d! = %s\n" n (Z.to_string !fact);
  (* Sanity: 42! has 52 digits (including any leading "-"). Wikipedia value
     is 1405006117752879898543142606244511569936384000000000. *)
  let expected =
    Z.of_string "1405006117752879898543142606244511569936384000000000"
  in
  if Z.equal !fact expected then print_endline "zarith ok"
  else (
    Printf.printf "MISMATCH: got %s, expected %s\n"
      (Z.to_string !fact) (Z.to_string expected);
    exit 1)
