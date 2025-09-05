open Ainterp

let%expect_test _ =
  Fmt.pr "%a" Just_sign.pp_set Just_sign.all;
  [%expect {| {+,0,-} |}]
