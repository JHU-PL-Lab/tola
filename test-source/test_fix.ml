open Base
open Fix

module F =
  Fix.ForType
    (struct
      type t = int
    end)
    (Prop.Boolean)

let loop i = F.lfp (fun x f -> if x = 0 then f x else true) i
let test_loop () = Alcotest.(check bool) "same bool" true (loop 1)
let test_groups = [ ("loop", [ Alcotest.test_case "loop" `Quick test_loop ]) ]
let () = Alcotest.run "Fix" test_groups
