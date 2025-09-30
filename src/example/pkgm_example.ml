open Base
module M = Interp.Common.Lt_pkgm
module VL = M.VL
module P = M.P
module PN = P.PN

let parse = Langs.Lang_text.Parse.parse

let to_answer =
  List.map ~f:(fun (pname, version) ->
      (VL.P.str_to_pname pname, VL.V.of_str version))

let answer_result_to_opt = function
  | VL.Exact ans | Upgrade_local ans | Downgrade_local ans | Relaxed_install ans
    ->
      Some ans
  | _ -> None

type out_dep_config = {
  pkgs : (string * P.pkg) list;
  local_pkgs : string list;
  remote_pkgs : string list;
  to_install : string list;
}

let out_dep_config_to_dep_config out_dep : VL.dep_config =
  let mk_pkgs (pid_s, pkg) =
    let pid = P.str_to_pid pid_s in
    (P.pname_of_pid pid, P.version_of_pid pid, VL.And (P.meta_of_pkg pkg))
  in
  let to_name_and_ver pid_s =
    let pid = P.str_to_pid pid_s in
    (P.pname_of_pid pid, P.version_of_pid pid)
  in
  let pkgs = List.map ~f:mk_pkgs out_dep.pkgs in
  let local_pkgs = List.map ~f:to_name_and_ver out_dep.local_pkgs in
  let remote_pkgs = List.map ~f:to_name_and_ver out_dep.remote_pkgs in
  let to_install = List.map ~f:to_name_and_ver out_dep.to_install in
  VL.{ pkgs; local_pkgs; remote_pkgs; to_install }

let convert_to_solve config =
  config |> out_dep_config_to_dep_config |> VL.solve_dep_config
  |> answer_result_to_opt

let convert_to_answer answer_raw = Some (to_answer answer_raw)

let pkg_ac_1_0 =
  P.{ payload = parse "_Axioms_ of **Choices**"; meta = [ VL.True ] }

let pkg_ac_1_1 =
  P.{ payload = parse "_Axioms_ of **Choices** (V1.1)"; meta = [ VL.True ] }

let pkg_p_1_0 =
  P.
    {
      payload = parse "P1 believe @ac@ after 1.0.";
      meta = List.map ~f:VL.exp_of_str [ "(= ac 1.0)" ];
    }

let pkg_p_1_1 =
  P.
    {
      payload = parse "P1 believe @ac@ after 1.1.";
      meta = List.map ~f:VL.exp_of_str [ "(>= ac 1.1)" ];
    }

let pkg_q_1_0 =
  P.
    {
      payload = parse "Q1 believe a modern @ac@";
      meta = List.map ~f:VL.exp_of_str [ "(>= ac 1.1)" ];
    }

let pkg_q_1_1 =
  P.
    {
      payload = parse "Q2 believe a classic @ac@";
      meta = List.map ~f:VL.exp_of_str [ "(< ac 1.1)" ];
    }

let case_1, answer_1 =
  ( {
      pkgs = [ ("p-1.0", pkg_p_1_0); ("ac-1.0", pkg_ac_1_0) ];
      local_pkgs = [];
      to_install = [ "ac-1.0" ];
      remote_pkgs = [ "ac-1.0" ];
    },
    [ ("ac", "1.0") ] )

let case_2, answer_2 =
  ( {
      pkgs = [ ("ac-1.0", pkg_ac_1_0); ("ac-1.1", pkg_ac_1_1) ];
      local_pkgs = [];
      to_install = [ "ac-1.0" ];
      remote_pkgs = [ "ac-1.0"; "ac-1.1" ];
    },
    [ ("ac", "1.0") ] )

let case_3, answer_3 =
  ( {
      pkgs = [ ("p-1.0", pkg_p_1_0); ("ac-1.0", pkg_ac_1_0) ];
      local_pkgs = [];
      to_install = [ "p-1.0" ];
      remote_pkgs = [ "p-1.0"; "ac-1.0" ];
    },
    [ ("ac", "1.0"); ("p", "1.0") ] )

(* there should have a case_3 to fail this case *)

let case_4, answer_4 =
  ( {
      pkgs =
        [ ("p-1.0", pkg_p_1_0); ("p-1.1", pkg_p_1_1); ("ac-1.1", pkg_ac_1_1) ];
      local_pkgs = [ "p-1.0" ];
      to_install = [ "p-1.1" ];
      remote_pkgs = [ "p-1.0"; "p-1.1"; "ac-1.1" ];
    },
    [ ("ac", "1.1"); ("p", "1.1") ] )

let case_5, answer_5 =
  ( {
      pkgs =
        [
          ("q-1.0", pkg_q_1_0);
          ("q-1.1", pkg_q_1_1);
          ("ac-1.0", pkg_ac_1_0);
          ("ac-1.1", pkg_ac_1_1);
        ];
      local_pkgs = [ "q-1.0"; "ac-1.1" ];
      to_install = [ "q-1.1" ];
      remote_pkgs = [ "q-1.0"; "q-1.1"; "ac-1.0"; "ac-1.1" ];
    },
    [ ("ac", "1.0"); ("q", "1.1") ] )

let case_6, answer_6 =
  ( {
      pkgs =
        [
          ("q-1.0", pkg_q_1_0);
          ("q-1.1", pkg_q_1_1);
          ("ac-1.0", pkg_ac_1_0);
          ("ac-1.1", pkg_ac_1_1);
        ];
      local_pkgs = [];
      to_install = [ "q-1.1"; "ac-1.1" ];
      remote_pkgs = [ "q-1.0"; "q-1.1"; "ac-1.0"; "ac-1.1" ];
    },
    [ ("ac", "1.0"); ("q", "1.1") ] )

let all_tests =
  [
    ("no_dep_one_ver", convert_to_solve case_1, convert_to_answer answer_1);
    ("no_dep_two_vers", convert_to_solve case_2, convert_to_answer answer_2);
    ("dep_one_ver", convert_to_solve case_3, convert_to_answer answer_3);
    ("upgrade_one", convert_to_solve case_4, convert_to_answer answer_4);
    ( "upgrade_one_downgrade_one",
      convert_to_solve case_5,
      convert_to_answer answer_5 );
    ( "relaxed_install_version",
      convert_to_solve case_6,
      convert_to_answer answer_6 );
  ]

(* 
Now the question comes to is the solving one-step or step-wise.
`local` and `remote` provides data, `to_install` provides the goal.

Either, the solver is expected to satisfice
1. perfectly `to_install`
2. satisfying all packages in `to_install` but breaking `locals`.
3. satisfying some packages in `to_install` but keep `locals`.
4. relax what the satisfication means.
*)
