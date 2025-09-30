open Base
open Langs
open Interp
open Tola_std
open Interp.Boat_interp
open Example.Boat_example

let testable_same_value = Alcotest.testable Boat_interp.pp Lang_boat.equal_exp

(* let mk_same_value expected actual =
   Alcotest.test_case "same value" `Quick (fun () ->
       Alcotest.(check same_value) "same value" expected @@ actual ()) *)

let same_exp ?(prompt = "same exp") e1 e2 =
  Alcotest.test_case prompt `Quick (fun () ->
      Alcotest.(check testable_same_value) prompt (interp e1) (interp e2))

let testable_same_id_set = Alcotest.testable Std.Id.Set.pp Std.Id.Set.equal

let same_id_set ?(prompt = "same_id_set") exp expected =
  Alcotest.test_case prompt `Quick (fun () ->
      Alcotest.(check testable_same_id_set) prompt (free_vars exp) expected)

let valid_free_vars ?(prompt = "free_vars_in") exp later_vars =
  Alcotest.test_case prompt `Quick (fun () ->
      Alcotest.(check bool) prompt (free_vars_in exp later_vars) true)

(* let expect_fail e =
   Alcotest.test_case "same interp" `Quick (fun () ->
       Alcotest.(check_raises "not found") Not_found (fun () ->
           ignore @@ interp e)) *)

let ids_of_str_list strs = strs |> List.map ~f:Std.Id.str |> Std.Id.Set.of_list

let () =
  (* let open Lang_boat.Tagless in *)
  Alcotest.run "Boat_interp"
    [
      ("basic", [ same_exp n1 n1; same_exp p12 n3 ]);
      ( "app",
        [
          same_exp n1 ap_x;
          same_exp plus_1_2 n3;
          same_exp open_x open_x;
          same_exp use_open_x n1;
          same_exp (lib_z (lib_y dynamic_yz)) (Int 49);
          (* same_exp post_let_x n4; *)
          (* same_exp ~prompt:"get x" get_x_1 n1; *)
          (* same_exp ~prompt:"rebind x" rebind_x_2 n2; *)
        ] );
      ( "free vars",
        [
          same_id_set n1 Std.Id.Set.empty;
          same_id_set id_x Std.Id.Set.empty;
          same_id_set open_x (ids_of_str_list [ "x" ]);
          same_id_set use_open_x (ids_of_str_list []);
          same_id_set plus_x_y_body (ids_of_str_list [ "x"; "y" ]);
          same_id_set plus_x_y_z_body (ids_of_str_list [ "x"; "y"; "z" ]);
          same_id_set dynamic_yz (ids_of_str_list [ "y"; "z" ]);
        ] );
      ( "free_vars_in",
        [
          valid_free_vars n1 Std.Id.Set.empty;
          valid_free_vars dynamic_yz (ids_of_str_list [ "y"; "z" ]);
          valid_free_vars (lib_y dynamic_yz) (ids_of_str_list [ "z" ]);
          valid_free_vars (lib_z dynamic_yz) (ids_of_str_list [ "y" ]);
          valid_free_vars (lib_z (lib_y dynamic_yz)) (ids_of_str_list []);
        ] )
      (* ("fail", [ expect_fail plus_dyn_err_1_2 ]); *);
    ]
