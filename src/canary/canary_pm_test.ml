open Base

(* PM primitive testing: generate and run tests for PM ops.
   Tests are derived from the canary_pm_* modules, ensuring
   the commands we emit in project specs actually work.

   Each test is a (name, cmd, expected_rc) triple.
   Run sequentially, results logged to output_dir. *)

type test_case = {
  name : string;
  cmd : string;
  expected_rc : int;
}

type test_result = { test : test_case; actual_rc : int; output : string }

let run_test (t : test_case) : test_result =
  let ic = Unix.open_process_in (t.cmd ^ " 2>&1") in
  let buf = Buffer.create 256 in
  (try
     while true do
       Buffer.add_char buf (Stdlib.input_char ic)
     done
   with End_of_file -> ());
  let status = Unix.close_process_in ic in
  let actual_rc =
    match status with
    | WEXITED n -> n
    | WSIGNALED _ | WSTOPPED _ -> 128
  in
  { test = t; actual_rc; output = Buffer.contents buf }

let is_pass r = r.actual_rc = r.test.expected_rc

(* ── Test generators per PM ── *)

let apt_tests ~pkg =
  [
    { name = "apt.check_available"; cmd = Canary_pm_apt.check_available_cmd ~pkg; expected_rc = 0 };
    { name = "apt.list_versions"; cmd = Canary_pm_apt.list_available_versions_cmd ~pkg; expected_rc = 0 };
    { name = "apt.install"; cmd = Canary_pm_apt.install_cmd ~pkg; expected_rc = 0 };
    { name = "apt.verify_installed"; cmd = Canary_pm_apt.verify_installed_cmd ~pkg; expected_rc = 0 };
    { name = "apt.query_version"; cmd = Canary_pm_apt.query_version_cmd ~pkg; expected_rc = 0 };
    { name = "apt.check_available(bad)";
      cmd = Canary_pm_apt.check_available_cmd ~pkg:"canary-nonexistent-pkg";
      expected_rc = 100 };
  ]

let brew_tests ~pkg =
  [
    { name = "brew.check_available"; cmd = Canary_pm_brew.check_available_cmd ~pkg; expected_rc = 0 };
    { name = "brew.query_version"; cmd = Canary_pm_brew.query_version_cmd ~pkg; expected_rc = 0 };
    { name = "brew.verify_installed"; cmd = Canary_pm_brew.verify_installed_cmd ~pkg; expected_rc = 0 };
  ]

let pip_tests ~pkg =
  [
    { name = "pip.check_available"; cmd = Canary_pm_pip.check_available_cmd ~pkg; expected_rc = 0 };
    { name = "pip.verify_installed"; cmd = Canary_pm_pip.verify_installed_cmd ~pkg; expected_rc = 0 };
    { name = "pip.query_version"; cmd = Canary_pm_pip.query_version_cmd ~pkg; expected_rc = 0 };
    { name = "pip.active_venv"; cmd = Canary_pm_pip.active_venv_cmd; expected_rc = 0 };
    { name = "pip.verify_installed(bad)";
      cmd = Canary_pm_pip.verify_installed_cmd ~pkg:"canary-nonexistent-pkg";
      expected_rc = 1 };
  ]

let opam_tests ~pkg =
  [
    { name = "opam.current_switch"; cmd = Canary_pm_opam.current_switch_cmd; expected_rc = 0 };
    { name = "opam.list_switches"; cmd = Canary_pm_opam.list_switches_cmd; expected_rc = 0 };
    { name = "opam.list_repos"; cmd = Canary_pm_opam.list_repos_cmd; expected_rc = 0 };
    { name = "opam.check_available"; cmd = Canary_pm_opam.check_available_cmd ~pkg; expected_rc = 0 };
    { name = "opam.query_version"; cmd = Canary_pm_opam.query_version_cmd ~pkg; expected_rc = 0 };
    { name = "opam.verify_installed"; cmd = Canary_pm_opam.verify_installed_cmd ~pkg; expected_rc = 0 };
    { name = "opam.list_depexts"; cmd = Canary_pm_opam.list_depexts_cmd ~pkg; expected_rc = 0 };
    { name = "opam.check_available(bad)";
      cmd = Canary_pm_opam.check_available_cmd ~pkg:"canary-nonexistent-pkg";
      expected_rc = 5 };
  ]

(* ── Runner ── *)

let run_tests ?(output_dir = "_out/canary/_local/pm-test") () =
  ignore (Stdlib.Sys.command [%string "mkdir -p %{output_dir}"] : int);
  let pm = Canary_store.detect_pm () in
  let tests =
    (match pm with
     | Canary_store.Apt -> apt_tests ~pkg:"cowsay"
     | Canary_store.Brew -> brew_tests ~pkg:"cowsay"
     | Canary_store.Opam | Canary_store.Unsupported -> [])
    @ (if Stdlib.Sys.command "which opam > /dev/null 2>&1" = 0
       then opam_tests ~pkg:"fmt" else [])
    @ (if Stdlib.Sys.command "which pip > /dev/null 2>&1" = 0
       then pip_tests ~pkg:"pip" else [])
  in
  let pass = ref 0 in
  let fail = ref 0 in
  let results = List.map tests ~f:(fun t ->
      let r = run_test t in
      let status = if is_pass r then (Int.incr pass; "PASS") else (Int.incr fail; "FAIL") in
      let snippet = String.prefix (String.rstrip r.output) 60 in
      Fmt.pr "  %-40s %s  (rc=%d) %s@." t.name status r.actual_rc snippet;
      r)
  in
  (* Write log *)
  let log_path = output_dir ^ "/pm_test.log" in
  let oc = Stdlib.open_out log_path in
  List.iter results ~f:(fun r ->
      let status = if is_pass r then "PASS" else "FAIL" in
      Stdlib.Printf.fprintf oc "[%s] %s (expected=%d, actual=%d)\n  cmd: %s\n  out: %s\n\n"
        status r.test.name r.test.expected_rc r.actual_rc r.test.cmd
        (String.prefix r.output 200));
  Stdlib.close_out oc;
  Fmt.pr "@.Summary: %d passed, %d failed. Log: %s@." !pass !fail log_path;
  !fail = 0
