open Interp
open Interp.Portrait_interp
open Example.Portrait_example

let same_value = Alcotest.testable Portrait_interp.pp Portrait_val.equal

(* let mk_same_value expected actual =
   Alcotest.test_case "same value" `Quick (fun () ->
       Alcotest.(check same_value) "same value" expected @@ actual ()) *)

let same_result ?(prompt = "same result") e1 e2 =
  Alcotest.test_case prompt `Quick (fun () ->
      Alcotest.(check same_value) prompt (interp e1) (interp e2))

(* let expect_fail e =
   Alcotest.test_case "same interp" `Quick (fun () ->
       Alcotest.(check_raises "not found") Not_found (fun () ->
           ignore @@ interp e)) *)

let () =
  Alcotest.run "Portrait_interp"
    [
      ("basic", [ same_result n1 n1; same_result p12 n3 ]);
      ( "app",
        [
          same_result n1 ap_x;
          same_result plus_1_2 n3;
          (* same_result post_let_x n4; *)
          same_result ~prompt:"get x" get_x_1 n1;
          same_result ~prompt:"rebind x" rebind_x_2 n2;
        ] );
      (* ("fail", [ expect_fail plus_dyn_err_1_2 ]); *)
    ]
