open Base
open Interp
module Dd_val = Dd_val.With_closure

let same_value = Alcotest.testable Dd_val.pp Dd_val.equal

let mk_same_value expected actual =
  Alcotest.test_case "same value" `Quick (fun () ->
      Alcotest.(check same_value) "same value" expected @@ actual ())

let same_exp = Alcotest.testable Langs.Dd.pp_exp Langs.Dd.equal_exp

let mk_same_exp expected actual =
  Alcotest.test_case "same exp" `Quick (fun () ->
      Alcotest.(check same_exp) "same exp" expected @@ actual ())

let () =
  let open Example.Dd_example in
  Alcotest.run "Dd_interp"
    [
      ("same int", [ mk_same_value (Int 3) (fun () -> Int 3) ]);
      ( "dd interp env",
        let eval e () = Dd_interp_env.interp e in
        [
          mk_same_value (Int 0) @@ eval n0;
          mk_same_value (Int 3) @@ eval n3;
          mk_same_value (Int (-3)) @@ eval ne3;
          mk_same_value (Int 7) @@ eval e1;
          mk_same_value (Int (-7)) @@ eval e2;
          mk_same_value (Int 3) @@ eval e3;
          mk_same_value (Int 3) @@ eval e4;
          mk_same_value (Int 7) @@ eval sum_3_4;
        ] );
      ( "dd interp subst",
        let eval e () = Dd_interp_subst.interp e in
        [
          mk_same_exp (Int 0) @@ eval n0;
          mk_same_exp (Int 3) @@ eval n3;
          mk_same_exp (Int (-3)) @@ eval ne3;
          mk_same_exp (Int 7) @@ eval e1;
          mk_same_exp (Int (-7)) @@ eval e2;
          mk_same_exp (Int 3) @@ eval e3;
          mk_same_exp (Int 3) @@ eval e4;
          mk_same_exp (Int 7) @@ eval sum_3_4;
        ] );
    ]
