(* e13 fixture: an app built on tiny_helper which is built on tiny.
   The longest-interesting chain: app → tiny_helper → tiny → libtiny.so.
   Success here confirms intra-binding repacking composes across
   multiple library layers and the runtime dependency chain resolves. *)

let () =
  let r = Tiny_helper.sum_doubled 10 5 in
  let d = Tiny_helper.diff_doubled 10 5 in
  Printf.printf "app_helper: sum=%d/%d diff=%d/%d\n"
    r.value r.doubled d.value d.doubled;
  (* sum is 57, doubled 114; diff is 5, doubled 10. *)
  if r.value = 57 && r.doubled = 114 && d.value = 5 && d.doubled = 10 then
    print_endline "app_helper OK"
  else
    (prerr_endline "app_helper FAIL"; exit 1)
