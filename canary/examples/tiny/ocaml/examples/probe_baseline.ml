(* Baseline probe: exercises every wrapper in [Tiny] and checks the
   results against the values an unbroken native side should produce.
   Exit code is non-zero on the first mismatch, so the scenario harness
   can detect Behavior-contract failures by simply running this. *)

let check name expected actual =
  if expected <> actual then begin
    Printf.eprintf "FAIL %s: expected %d, got %d\n" name expected actual;
    exit 1
  end else
    Printf.printf "OK   %s = %d\n" name actual

let () =
  check "Tiny.offset ()"      42 (Tiny.offset ());
  check "Tiny.sum 2 3"        47 (Tiny.sum 2 3);     (* 2 + 3 + 42 *)
  check "Tiny.diff 5 2"        3 (Tiny.diff 5 2);
  check "Tiny.diff 2 5"      (-3) (Tiny.diff 2 5);   (* asymmetry matters for api_repack *)
  print_endline "all checks passed"
