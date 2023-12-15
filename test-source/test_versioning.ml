open Versioning.Algebra

let total_order_compare s1 s2 = Total_ordering.(compare (of_str s1) (of_str s2))

let total_order_less s1 s2 =
  let open Std.Ordering in
  match total_order_compare s1 s2 with Less -> true | _ -> false

let mk_lt_version s1 s2 =
  Alcotest.test_case "total-order cmp" `Quick (fun () ->
      Alcotest.(check @@ bool) "less_than" (total_order_less s1 s2) true)

let test_groups = [ ("total_ordering", [ mk_lt_version "1" "2" ]) ]
let () = Alcotest.run "Versioning" test_groups
