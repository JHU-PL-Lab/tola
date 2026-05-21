(* e12 fixture: a user-style app built on the [Tiny] OCaml binding.
   Distinct from probe_baseline so the harness can record "app over
   binding" as its own outcome. The app links transitively to
   libtiny.so via Tiny's stub.a; success here is what the s5 → app
   edge of "Table — Action grid" expects. *)

let () =
  let off = Tiny.offset () in
  let s = Tiny.sum 10 5 in
  let d = Tiny.diff 10 5 in
  Printf.printf "app_binding: offset=%d sum(10,5)=%d diff(10,5)=%d\n" off s d;
  (* sum is a+b+offset = 10+5+42 = 57; diff is a-b = 5. *)
  if off = 42 && s = 57 && d = 5 then
    print_endline "app_binding OK"
  else
    (prerr_endline "app_binding FAIL"; exit 1)
