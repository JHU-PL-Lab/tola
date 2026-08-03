(** [Canary_step_model] — the step model types shared between
    [Canary_action] (the runner), [Canary_diagram] (renderer), and
    [Canary_gh] (YAML emission).

    Split from [Canary] on 2026-06-01 (Phase 5). Holds:
    - [version_info]: human-readable provider/consumer version pair for
      diagnostic messages.
    - [symbol_entry] + [sym] / [sym_v]: a single C symbol with optional
      [@@VER] version tag.
    - [symbol_check]: a per-step "these symbols must be exported"
      assertion (currently informational only).
    - [step_expectation]: what should happen when the step runs
      ([Expect_success] / [Expect_failure] / [Expect_compat_failure]).
    - [step]: the per-step record the runner consumes.
    - [logger] + [step_status] + [ensure_dir] + [now] + [create_logger]:
      the runner's logging primitive. *)

open Base

type version_info = {
  provider_version : string;
  consumer_requires : string;
  since : string option;
  note : string option;
}

type symbol_entry = {
  sym_name : string;
  sym_version : string option;
}

let sym name = { sym_name = name; sym_version = None }
let sym_v name version = { sym_name = name; sym_version = Some version }

type symbol_check = {
  provided_lib : string;
  required : symbol_entry list;
  missing : symbol_entry list;
  version_info : version_info option;
}

(** What an action step's outcome should be when {!Canary_step_builder.run_step}
    runs it. Used by {!Canary_step_builder.derive_steps} and the GH backend.

    - [Expect_success]                       — step must exit 0.
    - [Expect_failure { contains_any; ... }] — step must fail; the
                                       failure output must contain at
                                       least one hand-written substring
                                       from [contains_any]. Brittle for
                                       multiline; use
                                       [Expect_compat_failure] when the
                                       prediction can be derived.
    - [Expect_compat_failure { inputs; version_info }] — step must
                                       fail; the expected failure
                                       substrings are {i derived} at
                                       run time by
                                       {!Canary_compat_run.predicted_contains_any_v2}
                                       from the cached inspector JSONs
                                       of [inputs]. Use when the
                                       surface delta between provider
                                       and consumer can predict the
                                       failure message. *)
type step_expectation =
  | Expect_success
  | Expect_failure of {
      contains_any : string list;
      version_info : version_info option;
    }
  | Expect_compat_failure of {
      inputs       : Canary_compat.inspect_input list;
      version_info : version_info option;
    }
  (* Like [Expect_compat_failure] (same payload), but the runtime PREDICTION
     decides: if the compat inspection over [inputs] predicts a failure, the
     step must fail with that signature; if it predicts NOTHING (a good
     artifact), the step must SUCCEED. This is the mutation-AGNOSTIC
     expectation — canary computes whether to expect a failure by inspecting
     the artifact, rather than being told (the oracle [Expect_compat_failure]
     always expects the failure). Emitted by
     [Canary_scenario.lower_expectation_agnostic]; only tiny-full uses it —
     z3/llvm keep the oracle variant. *)
  | Expect_compat_derived of {
      inputs       : Canary_compat.inspect_input list;
      version_info : version_info option;
    }

type step = {
  tag : string;
  cache_key : string;
  output_tag : string;
  output_dir : string;
  project_dir : string;
  variant_id : string;
  action : Canary_basic.action;
  deps : string list;
  cmd : output_dir:string -> variant_key:string -> string;
  check_pre : unit -> bool;
  check_post : output_dir:string -> variant_key:string -> bool;
  expectation : step_expectation;
  symbol_check : symbol_check option;
  (* Per-project surface-theory contract opt-outs (set by derive_steps
     from runner_spec.disabled_contracts). The runner combines this
     with the CLI's --disable-contract list before evaluating
     Expect_compat_failure. *)
  disabled_contracts : Canary_compat.contract_id list;
}

type logger = {
  log : tag:string -> event:string -> detail:string option -> unit;
  close : unit -> unit;
}

type step_status = Step_done | Step_failed | Step_skipped

let rec ensure_dir path =
  if not (Stdlib.Sys.file_exists path) then (
    ensure_dir (Stdlib.Filename.dirname path);
    Unix.mkdir path 0o755)

let now () =
  let t = Unix.gettimeofday () in
  let tm = Unix.localtime t in
  let frac = t -. Float.round_down t in
  Printf.sprintf "%04d-%02d-%02d %02d:%02d:%02d.%03d"
    (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday
    tm.tm_hour tm.tm_min tm.tm_sec
    (Float.to_int (frac *. 1000.0))

let create_logger ~log_path =
  let oc = Stdlib.open_out_gen
      [Open_creat; Open_append; Open_wronly] 0o644 log_path in
  let log ~tag ~event ~detail =
    let ts = now () in
    let detail_str = match detail with
      | Some d -> Printf.sprintf "  (%s)" d
      | None -> ""
    in
    let padded_tag =
      if String.length tag < 25 then
        tag ^ String.make (25 - String.length tag) ' '
      else tag
    in
    let line = Printf.sprintf "[%s] %s  %s%s" ts padded_tag event detail_str in
    Stdlib.output_string oc (line ^ "\n");
    Stdlib.flush oc
  in
  let close () = Stdlib.close_out oc in
  { log; close }
