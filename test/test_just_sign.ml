open Ainterp
open Just_sign
open Std

let just_sign_set =
  Alcotest.testable (Std.pp_set Just_sign.pp_sign) Core.Set.equal

let bool_set = Alcotest.testable (Std.pp_set Core.Bool.pp) Core.Set.equal

let mk_same_signs expected actual =
  Alcotest.test_case "plus" `Quick (fun () ->
      Alcotest.(check @@ just_sign_set) "same signs" expected @@ actual ())

let mk_same_bools expected actual =
  Alcotest.test_case "plus" `Quick (fun () ->
      Alcotest.(check @@ bool_set) "same bools" expected @@ actual ())

let test_groups =
  [
    ( "all_signs",
      [
        mk_same_signs just_neg (fun () -> plus Neg Neg);
        mk_same_signs all (fun () -> plus Neg Pos);
        mk_same_signs just_pos (fun () -> minus Pos Neg);
        mk_same_signs all (fun () -> minus Pos Pos);
      ] );
    ( "all_bool",
      [
        mk_same_bools just_false (fun () -> eq Neg Zero);
        mk_same_bools true_or_false (fun () -> eq Neg Neg);
      ] );
  ]

let () = Alcotest.run "Fix" test_groups
