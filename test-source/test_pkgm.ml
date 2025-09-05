open Base
open Example.Pkgm_example

let check_answer =
  Alcotest.option (Alcotest.testable VL.pp_answer VL.equal_answer)

let same_answer ?(prompt = "same asnwer") e1 e2 =
  Alcotest.test_case prompt `Quick (fun () ->
      Alcotest.(check check_answer) prompt e1 e2)

let () =
  Alcotest.run "Pkgm"
    [
      ( "basic",
        List.map
          ~f:(fun (prompt, case, answer) -> same_answer ~prompt answer case)
          all_tests );
    ]
