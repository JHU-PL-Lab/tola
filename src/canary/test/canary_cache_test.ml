(** cache-test — regression guard for run-cache SOUNDNESS (cache.md / bug B).

    The local run cache decides "skip, this step already succeeded" from whether
    the step actually MET its expectation (a verdict marker the runner writes),
    NOT from mere output presence. This matters because a probe writes its
    [probe.log] even when it FAILS, so a [check_post] of "probe.log exists" would
    serve a failed probe as a cached success on rerun — silently inflating the
    detection metric (the warm-run "fake green" that hid behind the vendored
    tiny-full arc). These tests pin the invariant so it can't rot back. *)

open Base

module LR = Canary_local_runner
module SM = Canary_step_model
module B = Canary_basic

let root = "_out/canary/test/cache-test"

(* A probe-like step: always writes [probe.log] (its output), bumps a counter so
   a test can tell "ran" from "skipped", then exits [rc] (0 = met expectation,
   non-zero = failed). Its [check_post] is the WEAK "probe.log exists" predicate
   that caused bug B. *)
let mk_step ~(dir : string) ~(rc : int) : SM.step =
  { tag = "probe";
    cache_key = "cache-test:probe";
    output_tag = "probe";
    output_dir = dir;
    project_dir = dir;
    variant_id = "";
    action = B.Probe_lib;
    deps = [];
    cmd =
      (fun ~output_dir ~variant_key:_ ->
        Stdlib.Printf.sprintf
          "echo x >> %s/counter; echo out > %s/probe.log; exit %d" output_dir
          output_dir rc);
    check_pre = (fun () -> true);
    check_post =
      (fun ~output_dir ~variant_key:_ ->
        Stdlib.Sys.file_exists (output_dir ^ "/probe.log"));
    expectation = SM.Expect_success;
    symbol_check = None;
    disabled_contracts = [] }

(* How many times the step's command actually ran (one "x" line per run). *)
let run_count ~dir : int =
  let path = dir ^ "/counter" in
  if not (Stdlib.Sys.file_exists path) then 0
  else begin
    let ic = Stdlib.open_in path in
    let n = ref 0 in
    (try
       while true do
         ignore (Stdlib.input_line ic : string);
         Int.incr n
       done
     with Stdlib.End_of_file -> ());
    Stdlib.close_in ic;
    !n
  end

let run ~dir ~rc : bool =
  let logger = SM.create_logger ~log_path:(root ^ "/actions.log") in
  let r = LR.run_step logger ~root ~project:"cache-test" (mk_step ~dir ~rc) in
  logger.close ();
  match r with
  | SM.Step_done | SM.Step_done_xfail -> true
  | SM.Step_failed | SM.Step_skipped -> false

let reset dir = ignore (Stdlib.Sys.command (Stdlib.Printf.sprintf "rm -rf %s" dir) : int)

(* Case A — a FAILED step must NOT be served as a cached success on rerun, even
   though [probe.log] (the weak postcondition) is present. It must re-run. *)
let failed_probe_not_cached () : bool =
  let dir = root ^ "/failed" in
  reset dir;
  let r1 = run ~dir ~rc:1 in
  let r2 = run ~dir ~rc:1 in
  (not r1) && (not r2)
  (* the bug's fingerprint: probe.log present, yet the step ran BOTH times *)
  && Stdlib.Sys.file_exists (dir ^ "/probe.log")
  && run_count ~dir = 2
  && not (Stdlib.Sys.file_exists (dir ^ "/probe.verdict.ok"))

(* Case B — a SUCCEEDED step caches: second run is skipped, command not re-run. *)
let success_cached () : bool =
  let dir = root ^ "/ok" in
  reset dir;
  let r1 = run ~dir ~rc:0 in
  let r2 = run ~dir ~rc:0 in
  r1 && r2
  && run_count ~dir = 1
  && Stdlib.Sys.file_exists (dir ^ "/probe.verdict.ok")

let all = [ ("cache.failed_probe_not_cached", failed_probe_not_cached);
            ("cache.success_cached", success_cached) ]

let run_tests () : bool =
  ignore (Stdlib.Sys.command (Stdlib.Printf.sprintf "mkdir -p %s" root) : int);
  let results = List.map all ~f:(fun (n, f) -> (n, f ())) in
  List.iter results ~f:(fun (n, ok) ->
      Stdlib.Printf.printf "[%s] %s\n" (if ok then "PASS" else "FAIL") n);
  let passed = List.count results ~f:snd in
  let total = List.length results in
  Stdlib.Printf.printf "\nCache-soundness tests: %d/%d passed.\n" passed total;
  passed = total
