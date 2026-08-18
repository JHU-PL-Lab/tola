(** [Canary_local_runner] — the local execution backend.

    Consumes an [step list] (built by {!Canary_step_builder}'s
    [derive_steps]) and {i executes} the steps' shell commands directly,
    in-process. Sibling of:
    - {!Canary_gh} — emits GitHub Actions YAML for the same step list.
    - {!Canary_html} — renders the result viewer.
    - {!Canary_diagram} — renders Mermaid + the view machinery.

    Where the YAML/HTML/Mermaid backends produce a file for someone else
    to consume, this backend produces a [run_status] table by actually
    running the commands and recording each step's verdict
    (Done/Failed/Skipped) plus log lines into [actions.log].

    Split from [Canary_runner] on 2026-06-01: the execute-half functions
    moved here ({!run_step}, {!run_graph}, {!exec_step},
    {!run_cmd_logged}, {!output_contains_any}, {!merge_step_statuses}),
    keeping the build-half (runner_spec + derive_steps + shared command
    templates + check_post compositors + defaults + dep helpers) in
    {!Canary_step_builder}.

    Communicates with the build half through the closure firewall on
    [step]: this module only invokes [step.cmd] / [step.check_pre]
    / [step.check_post] and never reads [runner_spec] directly.
    Symmetric design with the other backends. *)

open Base
open Canary_step_model

(* ── Cross-run cache (inlined from canary_step_cache.ml on 2026-06-01,
   Phase 10b) ─────────────────────────────────────────────────────────
   Maps cache_key → entry, where cache_key = "<project>:<step_tag>"
   (e.g. "sqlite:fetch_lib", "llvm-19:probe_binding_pkg"). Populated by
   the `cache-sync` CLI subcommand reading GH CI results back into a
   local JSON; consulted by run_step below to skip steps a previous CI
   run has already certified as successful.

   FUTURE: if the GH backend grows its own cache (e.g. CI-side artifact
   caching with a different schema), revisit and extract a shared
   cache abstraction. For now this lives next to its only consumer
   (run_step's `?global_cache`). *)

type cache_entry = {
  status : string;   (* "success" or "failure" *)
  run_id : int;      (* GH Actions run database ID; 0 = local *)
  at : string;       (* date recorded, e.g. "2026-04-22" *)
}

type step_cache = (string, cache_entry) Hashtbl.t

let make_cache () : step_cache = Hashtbl.create (module String)

let cache_entry_of_json fields =
  let get_s name =
    match List.Assoc.find fields ~equal:String.equal name with
    | Some (`String s) -> s
    | _ -> ""
  in
  let get_i name =
    match List.Assoc.find fields ~equal:String.equal name with
    | Some (`Int i) -> i
    | _ -> 0
  in
  { status = get_s "status"; run_id = get_i "run_id"; at = get_s "at" }

let cache_of_json (json : Yojson.Basic.t) : step_cache =
  let tbl = make_cache () in
  (match json with
   | `Assoc pairs ->
     List.iter pairs ~f:(fun (key, v) ->
         match v with
         | `Assoc fields -> Hashtbl.set tbl ~key ~data:(cache_entry_of_json fields)
         | _ -> ())
   | _ -> ());
  tbl

let cache_to_json (tbl : step_cache) : Yojson.Basic.t =
  let pairs =
    Hashtbl.to_alist tbl
    |> List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b)
    |> List.map ~f:(fun (key, e) ->
           ( key,
             `Assoc
               [ ("status", `String e.status);
                 ("run_id", `Int e.run_id);
                 ("at", `String e.at) ] ))
  in
  `Assoc pairs

let load_cache ~path : step_cache =
  if Stdlib.Sys.file_exists path then
    (try Yojson.Basic.from_file path |> cache_of_json
     with _ -> make_cache ())
  else make_cache ()

let save_cache ~path (tbl : step_cache) =
  let oc = Stdlib.open_out path in
  Yojson.Basic.pretty_to_channel oc (cache_to_json tbl);
  Stdlib.output_char oc '\n';
  Stdlib.close_out oc

let cache_record (tbl : step_cache) ~key (e : cache_entry) =
  Hashtbl.set tbl ~key ~data:e

let cache_is_success tbl ~key =
  match Hashtbl.find tbl key with
  | Some { status = "success"; _ } -> true
  | _ -> false

(* ── Execution ─────────────────────────────────────────────────────── *)

(* Run one shell command, log it, return whether it exit-zeroed. *)
let run_cmd_logged logger ~tag cmd =
  logger.log ~tag ~event:"cmd" ~detail:(Some cmd);
  let rc = Stdlib.Sys.command cmd in
  if rc <> 0 then
    logger.log ~tag ~event:"cmd_fail" ~detail:(Some [%string "exit %{Int.to_string rc}"]);
  rc = 0

(* Execute a step's shell command, ensuring output_dir exists. *)
let exec_step logger ~tag ~output_dir (step : step) =
  ignore (Stdlib.Sys.command [%string "mkdir -p \"%{output_dir}\""] : int);
  let shell_cmd = step.cmd ~output_dir ~variant_key:step.variant_id in
  run_cmd_logged logger ~tag shell_cmd

(* Check if any file in output_dir contains any of the expected strings.
   Used by Expect_failure / Expect_compat_failure expectation evaluation. *)
let output_contains_any ~output_dir strings =
  try
    let files = Stdlib.Sys.readdir output_dir in
    Array.exists files ~f:(fun f ->
        let path = output_dir ^ "/" ^ f in
        try
          let ic = Stdlib.open_in path in
          let content = Stdlib.really_input_string ic (Stdlib.in_channel_length ic) in
          Stdlib.close_in ic;
          List.exists strings ~f:(fun s -> String.is_substring content ~substring:s)
        with _ -> false)
  with _ -> false

(* A step's VERDICT marker: written by the runner only when the step actually
   MET its expectation (a build/fetch succeeded, or a probe's predicted/expected
   outcome held). The local cache keys on this — NOT on [check_post], which for
   a probe is merely "probe.log exists" and is satisfied by a FAILED probe too
   (a failed probe still writes its log). Without this, a rerun serves the
   failed probe as a cached success and the detection metric silently inflates
   (cache.md; the warm-run "fake green"). Tag-prefixed + variant-keyed so it is
   unique even where steps share an output_dir (build_binding + its inspect). *)
let verdict_marker (step : step) : string =
  step.output_dir ^ "/"
  ^ Canary_basic.variant_file ~variant_key:step.variant_id
      (step.tag ^ ".verdict.ok")

(* ── the spec fingerprint (2026-08-17, the warm-mask fix) ──
   The warm skip trusts a verdict marker when it exists + [check_post]
   holds — but [check_post] proves the POSTCONDITION, not that the step
   is still the RIGHT step for the current spec. The cache key was
   [variant_id] only; a spec edit under a warm cache silently served
   the OLD world's verdict (three strikes this arc: z3's dying install
   as PASS, the forward cell's never-paired c1, the pre-merge clone's
   install.ok skipping the new assert). The marker now records a
   fingerprint of the step's cmd + expectation; the warm skip requires
   it to match — spec drift invalidates exactly the affected steps. *)

(** The expectation's FORM for the fingerprint: the variant + (for the
    hand-written greps) the substrings — a change to either invalidates
    the marker. The compat-derived variants name themselves only: their
    greps are computed at runtime from the inputs (whose paths ride the
    cmd, which the fingerprint also covers). *)
let expectation_form (e : step_expectation) : string =
  match e with
  | Expect_success -> "success"
  | Expect_failure { contains_any; _ } ->
      "failure:" ^ String.concat ~sep:"," contains_any
  | Expect_compat_failure _ -> "compat_failure"
  | Expect_compat_derived _ -> "compat_derived"

(** The step's spec fingerprint: the FULL realized cmd (it embeds every
    spec-derived bit — the assert_staged tests, prefixes, row order)
    plus the expectation form. MD5 (drift detection, not security). *)
let step_fingerprint (step : step) : string =
  let cmd = step.cmd ~output_dir:step.output_dir ~variant_key:step.variant_id in
  Stdlib.Digest.to_hex
    (Stdlib.Digest.string (cmd ^ "\x00" ^ expectation_form step.expectation))

(* The marker's CONTENT records how the expectation was met: "xfail" = a
   confirmed expected failure, "" (or "ok") = plain success — so a warm run
   re-seeds [Step_done_xfail] rather than flattening it into [Step_done].
   A7 phase 2: an xfail line also names the CONFIRMING contract ids —
   "xfail c2" (space-separated after the keyword; prefix-compatible with
   the [verdict_is_xfail] parser). [] = confirmed without a contract
   attribution (a hand-written Expect_failure, or the empty-prediction
   fallback).

   V2 (2026-08-17): the SECOND line is the spec fingerprint (see
   [step_fingerprint]) — the warm skip requires it to match the current
   spec. *)
let write_verdict (step : step) ~(ok : bool) ~(xfail : bool)
    ~(xfail_contracts : string list) : unit =
  let path = verdict_marker step in
  if ok then (
    try
      ignore (Stdlib.Sys.command [%string "mkdir -p \"%{step.output_dir}\""] : int);
      let oc = Stdlib.open_out path in
      if xfail then (
        let ids = match xfail_contracts with
          | [] -> ""
          | ids -> " " ^ String.concat ~sep:" " ids
        in
        Stdlib.output_string oc ("xfail" ^ ids ^ "\n"))
      else Stdlib.output_string oc "ok\n";
      Stdlib.output_string oc (step_fingerprint step ^ "\n");
      Stdlib.close_out oc
    with _ -> ())
  else if Stdlib.Sys.file_exists path then
    (try Stdlib.Sys.remove path with _ -> ())

(** Whether [step]'s verdict marker was written by the CURRENT spec
    (line 2 = the fingerprint). A missing line 2 (old-format marker) is
    STALE — landing the fingerprint forces one cold refresh per step. *)
let verdict_matches_spec (step : step) : bool =
  let path = verdict_marker step in
  try
    Stdlib.In_channel.with_open_text path (fun ic ->
        let _first = Stdlib.In_channel.input_line ic in
        match Stdlib.In_channel.input_line ic with
        | Some l -> String.equal (String.strip l) (step_fingerprint step)
        | None -> false)
  with _ -> false

let verdict_is_xfail (path : string) : bool =
  try
    Stdlib.In_channel.with_open_text path (fun ic ->
        match Stdlib.In_channel.input_line ic with
        | Some l -> String.is_prefix (String.strip l) ~prefix:"xfail"
        | None -> false)
  with _ -> false

(** The contract ids a marker's xfail line names ("xfail c2" → ["c2"]);
    [] for a plain / non-xfail / absent marker. *)
let verdict_xfail_contracts (path : string) : string list =
  try
    Stdlib.In_channel.with_open_text path (fun ic ->
        match Stdlib.In_channel.input_line ic with
        | Some l -> (
            match String.split (String.strip l) ~on:' ' with
            | "xfail" :: ids ->
                List.filter ids ~f:(fun s -> not (String.is_empty s))
            | _ -> [])
        | None -> [])
  with _ -> []

(** Display form of a contract-id list: " [c2,c5]", "" when empty. *)
let xfail_id_suffix (ids : string list) : string =
  match ids with
  | [] -> ""
  | ids -> " [" ^ String.concat ~sep:"," ids ^ "]"

(** The confirming-contract ids recorded for [step]'s xfail verdict — the
    read display layers use (`action`'s xfail list → scenarios.tsv → `spec`;
    warm and cold runs alike, since the marker is the persistence). *)
let step_xfail_contracts (step : step) : string list =
  verdict_xfail_contracts (verdict_marker step)

(* Run a single action step; returns its [step_status] ([Step_done_xfail] =
   passed via a confirmed expected failure).
   Skip priority: (1) global cache hit, (2) prior run met its expectation
   (verdict marker present — NOT mere output presence). *)
let run_step logger ~root:_ ~project:_ ?global_cache (step : step) : step_status =
  let tag = step.tag in
  let out = step.output_dir in
  let log = logger.log ~tag in
  (* set when the met expectation was a CONFIRMED failure (declared or derived) *)
  let xfail = ref false in
  (* A7 phase 2: the contract ids whose predicted substrings the failing
     output actually matched — persisted in the verdict marker so every
     display layer can name WHICH contract confirmed. [] = no attribution
     (hand-written Expect_failure / empty-prediction fallback). *)
  let xfail_ids : string list ref = ref [] in
  (* Global cache: skip if a previous CI run recorded success for this key *)
  let global_hit = match global_cache with
    | Some cache -> cache_is_success cache ~key:step.cache_key
    | None -> false
  in
  (* Warm-skip gate (VISIBLE, 2026-08-17, the warm-mask fix): a verdict
     marker is trusted only when the fingerprint matches the current
     spec AND the postcondition still holds. Each failing gate logs its
     reason and REMOVES the stale marker (it no longer represents a met
     expectation in the current world), then the step EXECUTES below —
     the state change lands in actions.log and surfaces in status/result. *)
  let marker_path = verdict_marker step in
  (if Stdlib.Sys.file_exists marker_path then
     if not (verdict_matches_spec step) then (
       log ~event:"marker_stale"
         ~detail:(Some "spec changed since the marker — re-running");
       (try Stdlib.Sys.remove marker_path with _ -> ()))
     else if
       not (step.check_post ~output_dir:out ~variant_key:step.variant_id)
     then (
       log ~event:"warm_check_post"
         ~detail:(Some "FAIL — the postcondition no longer holds; re-running");
       (try Stdlib.Sys.remove marker_path with _ -> ())));
  if global_hit then (
    log ~event:"skip" ~detail:(Some [%string "global cache hit (%{step.cache_key})"]);
    Step_done)
  (* Local cache: skip only if a PRIOR run recorded a met expectation here
     (verdict marker), so a failed probe is never served as cached success.
     AND the postcondition must still hold (2026-08-17, the Publish case
     study's finding — the code had drifted from the documented contract:
     a store-mutating world's warm skip must re-verify the store, e.g. a
     pin-checked fetch/publish whose [check_post] asserts the switch
     provably holds the pinned state — a stale marker over a changed
     store is otherwise a silent PASS for the wrong world). *)
  else if Stdlib.Sys.file_exists marker_path
          && verdict_matches_spec step
          && step.check_post ~output_dir:out ~variant_key:step.variant_id then
    (log ~event:"warm_gate"
       ~detail:(Some "marker + fingerprint + check_post passed");
     if verdict_is_xfail marker_path then (
       log ~event:"skip"
         ~detail:(Some ("verdict marker (prior xfail)"
                        ^ xfail_id_suffix (step_xfail_contracts step)));
       Step_done_xfail)
     else (
       log ~event:"skip" ~detail:(Some "verdict marker (prior success)");
       Step_done))
  else (
    let pre_ok = step.check_pre () in
    log ~event:"check_pre" ~detail:(Some (if pre_ok then "pass" else "FAIL"));
    let result =
      (if not pre_ok then (
        log ~event:"blocked" ~detail:(Some "precondition failed");
        false)
    else
      try
        let cmd_ok = exec_step logger ~tag ~output_dir:out step in
        (* S5a: forecast-agnostic detection runs alongside the verdict and
           only reports. Trivial detector for now (errored? / output
           present?); contract integration is postponed. The expectation
           below still decides pass/fail — detection does not affect it. *)
        let output_present =
          try Stdlib.Sys.file_exists out && Array.length (Stdlib.Sys.readdir out) > 0
          with _ -> false
        in
        let finding = Canary_detect.simple_finding ~tag ~cmd_ok ~output_present in
        log ~event:"detect" ~detail:(Some (Canary_detect.string_of_finding finding));
        (* Resolve a declared relative input path (e.g.
           "pack_binding_ocaml/inspect_stub.json") to its
           project-dir-absolute form, applying v3 layout's step_dir mapping
           and variant-key suffix. The comparator runner picks the first
           existing path per input. Shared by both compat branches below. *)
        let resolve_input rel =
          match String.lsplit2 rel ~on:'/' with
          | Some (step_tag, file) ->
              let step_dir = Canary_basic.step_dir_of_tag step_tag in
              let vk_file = Canary_basic.variant_file
                  ~variant_key:step.variant_id file in
              step.project_dir ^ "/" ^ step_dir ^ "/" ^ vk_file
          | None ->
              let vk_rel = Canary_basic.variant_file
                  ~variant_key:step.variant_id rel in
              step.project_dir ^ "/" ^ vk_rel
        in
        (* A7 phase 1 (was plan.md Step 6c): per-contract prediction — one
           [compat_predicted] event per FIRED contract row ("c1 cmp_symbol:
           3 substring(s)") + one [contract_skipped] per disabled/stubbed
           entry, instead of a single collapsed count. Returns the fired
           rows; [flat_predictions] is the substring union the expectation
           check greps for (identical to the old
           [predicted_contains_any_v2] result). *)
        let derived_predictions inputs =
          let fired =
            Canary_compat_run.predicted_by_contract_v2
              ~disabled:step.disabled_contracts ~resolve:resolve_input inputs
          in
          List.iter fired
            ~f:(fun ((c : Canary_compat.contract_check), subs) ->
              log ~event:"compat_predicted"
                ~detail:(Some (Printf.sprintf "%s %s: %d substring(s)"
                                 (Canary_compat.string_of_contract_id c.id)
                                 c.name (List.length subs))));
          if List.is_empty fired then
            log ~event:"compat_predicted" ~detail:(Some "no contract fired");
          (* the c1 coverage WARNING (2026-08-17): a passing c1 whose
             consumer surface covers a small fraction of the provider's
             may be out-of-date — a note, never a failure *)
          (match Canary_compat_run.c1_lag_note ~resolve:resolve_input inputs with
           | Some note -> log ~event:"compat_note" ~detail:(Some note)
           | None -> ());
          List.iter
            (Canary_compat_run.skipped_checks
               ~disabled:step.disabled_contracts ())
            ~f:(fun ((c : Canary_compat.contract_check), reason) ->
              log ~event:"contract_skipped"
                ~detail:(Some (Printf.sprintf "%s %s: %s"
                                 (Canary_compat.string_of_contract_id c.id)
                                 c.name reason)));
          fired
        in
        let flat_predictions fired =
          List.concat_map fired ~f:snd
          |> List.dedup_and_sort ~compare:String.compare
        in
        (* A7 phase 2: which fired contracts does the failing output
           actually match? Those are the CONFIRMING contracts — recorded in
           the verdict + named in the done event. Evaluated only on a
           confirmed expected failure. *)
        let confirming_contracts fired =
          List.filter_map fired
            ~f:(fun ((c : Canary_compat.contract_check), subs) ->
              if output_contains_any ~output_dir:out subs then
                Some (Canary_compat.string_of_contract_id c.id)
              else None)
        in
        let expectation_ok = match step.expectation with
          | Expect_success ->
              let ok = cmd_ok && step.check_post ~output_dir:out ~variant_key:step.variant_id in
              log ~event:"check_post" ~detail:(Some (if ok then "pass" else "FAIL"));
              log ~event:(if ok then "done" else "failed")
                ~detail:(if ok then None else Some "postcondition failed");
              ok
          | Expect_failure { contains_any; version_info } ->
              if cmd_ok then (
                log ~event:"unexpected_success"
                  ~detail:(Some "expected failure but command succeeded");
                false)
              else
                let found = output_contains_any ~output_dir:out contains_any in
                let confirmed_msg = match version_info with
                  | None -> "expected failure confirmed"
                  | Some vi ->
                      let since = Option.value_map vi.since ~default:"" ~f:(fun s -> Printf.sprintf ", added in %s" s) in
                      Printf.sprintf "expected failure confirmed: %s predates %s%s"
                        vi.provider_version vi.consumer_requires since
                in
                if found then xfail := true;
                log ~event:(if found then "done" else "failed")
                  ~detail:(Some (if found then confirmed_msg
                    else "command failed but output didn't match expected strings"));
                found
          | Expect_compat_failure { inputs; version_info } ->
              if cmd_ok then (
                log ~event:"unexpected_success"
                  ~detail:(Some "expected failure (derived) but command succeeded");
                false)
              else
                let fired = derived_predictions inputs in
                let derived = flat_predictions fired in
                let found =
                  if List.is_empty derived then
                    (* No prediction available — fall back to "any failure
                       that left a probe log is acceptable". v3 layout keys
                       log names by variant (probe_<vk>.log), so resolve
                       via [variant_file], with the bare name as the legacy
                       fallback (fixed 2026-08-05 — the literal "probe.log"
                       check never matched v3 names, so an empty-prediction
                       must-fail could not confirm; surfaced by type_wrong
                       once its build-site over-strengthening was removed). *)
                    Stdlib.Sys.file_exists
                      (out ^ "/"
                       ^ Canary_basic.variant_file
                           ~variant_key:step.variant_id "probe.log")
                    || Stdlib.Sys.file_exists (out ^ "/probe.log")
                  else output_contains_any ~output_dir:out derived
                in
                let confirmed_msg = match version_info with
                  | None -> "expected failure confirmed (derived)"
                  | Some vi ->
                      let since = Option.value_map vi.since ~default:""
                          ~f:(fun s -> Printf.sprintf ", added in %s" s) in
                      Printf.sprintf
                        "expected failure confirmed (derived): %s predates %s%s"
                        vi.provider_version vi.consumer_requires since
                in
                if found then begin
                  xfail := true;
                  xfail_ids := confirming_contracts fired
                end;
                log ~event:(if found then "done" else "failed")
                  ~detail:(Some (if found
                    then confirmed_msg ^ xfail_id_suffix !xfail_ids
                    else "command failed but output didn't match derived predictions"));
                found
          | Expect_compat_derived { inputs; version_info = _ } ->
              (* Mutation-AGNOSTIC: the inspection decides. Compute the
                 prediction FIRST; if it is empty the artifact is fine here, so
                 a SUCCESS is correct (unlike the oracle variant, which always
                 expects the failure). If non-empty, the step must fail with
                 that signature. Lets tiny-full run without being told which
                 contract breaks — canary discovers it. *)
              let fired = derived_predictions inputs in
              let derived = flat_predictions fired in
              if List.is_empty derived then begin
                (* inspection predicts no failure. BUT the command failed —
                   this is a behavioral failure (c3/c7) where artifact
                   inspection is clean yet the probe crashes with a
                   behavioral signal. Fall back: if probe.log exists, the
                   failure is confirmed (same fallback as Expect_compat_failure
                   line 374). Otherwise it's unexpected. *)
                if cmd_ok then begin
                  log ~event:"done"
                    ~detail:(Some "no compat failure predicted; success expected");
                  true
                end
                else
                  let probe_exists =
                    Stdlib.Sys.file_exists
                      (out ^ "/"
                       ^ Canary_basic.variant_file
                           ~variant_key:step.variant_id "probe.log")
                    || Stdlib.Sys.file_exists (out ^ "/probe.log")
                  in
                  if probe_exists then begin
                    xfail := true;
                    (* No specific contract confirmed — the artifact
                       inspection was clean, but the probe left a log.
                       Record it as a behavioral catch. *)
                    log ~event:"done"
                      ~detail:(Some "expected failure confirmed (behavioral: probe.log present despite clean artifact inspection)");
                    true
                  end
                  else begin
                    log ~event:"failed"
                      ~detail:(Some "no compat failure predicted but command failed (no probe.log)");
                    false
                  end
              end
              else if cmd_ok then begin
                log ~event:"unexpected_success"
                  ~detail:(Some "compat failure predicted (derived) but command succeeded");
                false
              end
              else begin
                let found = output_contains_any ~output_dir:out derived in
                if found then begin
                  xfail := true;
                  xfail_ids := confirming_contracts fired
                end;
                log ~event:(if found then "done" else "failed")
                  ~detail:(Some (if found
                    then "expected failure confirmed (derived)"
                         ^ xfail_id_suffix !xfail_ids
                    else "command failed but output didn't match derived predictions"));
                found
              end
        in
        (* Symbol check runs independently after command expectation is met. *)
        let symbol_ok = match step.symbol_check with
          | None -> true
          | Some sc ->
              let check_sym syms expect_found =
                List.for_all syms ~f:(fun entry ->
                    let pattern = match entry.sym_version with
                      | None -> entry.sym_name
                      | Some v -> [%string "%{entry.sym_name}@@%{v}"]
                    in
                    let rc = Stdlib.Sys.command
                      (Printf.sprintf "nm -D %s 2>/dev/null | grep -qF '%s'" sc.provided_lib pattern) in
                    let found = (rc = 0) in
                    if Bool.( <> ) found expect_found then
                      log ~event:"symbol_mismatch"
                        ~detail:(Some (Printf.sprintf "%s: %s, expected %s" pattern
                            (if found then "found" else "missing")
                            (if expect_found then "found" else "missing")));
                    Bool.equal found expect_found)
              in
              let ok = check_sym sc.required true && check_sym sc.missing false in
              log ~event:(if ok then "symbols_ok" else "symbols_failed")
                ~detail:(Some (if ok then "symbol check passed" else "symbol mismatch"));
              ok
        in
        expectation_ok && symbol_ok
      with exn ->
        let msg = Exn.to_string exn in
        log ~event:"error" ~detail:(Some msg);
        false)
    in
    (* record the verdict so the local cache can key on a MET expectation, not
       mere output presence (a failed probe still leaves probe.log). *)
    write_verdict step ~ok:result ~xfail:!xfail ~xfail_contracts:!xfail_ids;
    if result then (if !xfail then Step_done_xfail else Step_done)
    else Step_failed)

(* Merge multiple per-variant status tables. Done > xfail > Failed > Skipped. *)
let merge_step_statuses (all : (string, step_status) Hashtbl.t list)
    : (string, step_status) Hashtbl.t =
  let priority = function
    | Step_done -> 4 | Step_done_xfail -> 3 | Step_failed -> 2 | Step_skipped -> 1
  in
  let out = Hashtbl.create (module String) in
  List.iter all ~f:(fun tbl ->
      Hashtbl.iteri tbl ~f:(fun ~key ~data ->
          Hashtbl.update out key ~f:(function
            | None -> data
            | Some prev -> if priority data > priority prev then data else prev)));
  out

(* Run all steps in dependency order. Returns status per tag.
   ~failfast:true stops on the first failure (useful for debugging). *)
let run_graph ?(failfast = false) ?global_cache logger ~project ~root (steps : step list) =
  logger.log ~tag:"*" ~event:"graph_start"
    ~detail:(Some [%string "%{Int.to_string (List.length steps)} steps"]);
  let status = Hashtbl.create (module String) in
  (* Seed with steps a PRIOR run recorded as meeting their expectation
     (verdict marker) — not mere output presence, so a failed probe isn't
     seeded as done. Marker content preserves the xfail distinction. Each
     seed is LOGGED (a seeded step never reaches [run_step], so without this
     a warm run leaves no per-step trace and `canary status` can't
     reconstruct the variant's matrix). *)
  List.iter steps ~f:(fun s ->
      (* the warm-skip GATE (2026-08-17, the warm-mask fix): the marker
         is trusted only when the fingerprint matches the current spec
         AND the postcondition still holds (the Publish case study's
         finding — a store-mutating step's check_post re-verifies the
         world). Each failing gate logs its reason and REMOVES the
         stale marker; the step runs fresh below. The gate is VISIBLE:
         [warm_gate] / [marker_stale] / [warm_check_post] land in
         actions.log and surface in status/result. *)
      let marker_path = verdict_marker s in
      if Stdlib.Sys.file_exists marker_path then
        if not (verdict_matches_spec s) then (
          logger.log ~tag:s.tag ~event:"marker_stale"
            ~detail:(Some "spec changed since the marker — re-running");
          (try Stdlib.Sys.remove marker_path with _ -> ()))
        else if
          not (s.check_post ~output_dir:s.output_dir ~variant_key:s.variant_id)
        then (
          logger.log ~tag:s.tag ~event:"warm_check_post"
            ~detail:
              (Some
                 "FAIL — the postcondition no longer holds; re-running");
          (try Stdlib.Sys.remove marker_path with _ -> ()))
        else begin
          let xf = verdict_is_xfail marker_path in
          logger.log ~tag:s.tag ~event:"warm_gate"
            ~detail:(Some "marker + fingerprint + check_post passed");
          logger.log ~tag:s.tag ~event:"skip"
            ~detail:(Some (if xf then
                             "verdict marker (prior xfail)"
                             ^ xfail_id_suffix (step_xfail_contracts s)
                           else "verdict marker (prior success)"));
          Hashtbl.set status ~key:s.tag
            ~data:(if xf then Step_done_xfail else Step_done)
        end);
  (* Iterate until no progress (or first failure in failfast mode) *)
  let changed = ref true in
  let aborted = ref false in
  while !changed && not !aborted do
    changed := false;
    List.iter steps ~f:(fun s ->
        if (not !aborted) && not (Hashtbl.mem status s.tag) then
          let deps_ok =
            List.for_all s.deps ~f:(fun dep ->
                match Hashtbl.find status dep with
                | Some (Step_done | Step_done_xfail) -> true
                | _ -> false)
          in
          if deps_ok then (
            let st = run_step logger ~project ~root ?global_cache s in
            Hashtbl.set status ~key:s.tag ~data:st;
            match st with
            | Step_done | Step_done_xfail -> changed := true
            | _ ->
                if failfast then (
                  logger.log ~tag:"*" ~event:"failfast"
                    ~detail:(Some [%string "stopped after %{s.tag}"]);
                  aborted := true)))
  done;
  if failfast && !aborted then (
    logger.close ();
    Stdlib.exit 1);
  (* Mark unreached as skipped *)
  List.iter steps ~f:(fun s ->
      if not (Hashtbl.mem status s.tag) then
        Hashtbl.set status ~key:s.tag ~data:Step_skipped);
  (* Report *)
  let total = List.length steps in
  let done_count =
    Hashtbl.count status ~f:(function
      | Step_done | Step_done_xfail -> true
      | _ -> false)
  in
  logger.log ~tag:"*" ~event:"graph_end"
    ~detail:(Some [%string "%{Int.to_string done_count}/%{Int.to_string total} completed"]);
  if done_count < total then
    List.iter steps ~f:(fun s ->
        match Hashtbl.find status s.tag with
        | Some Step_failed ->
            logger.log ~tag:s.tag ~event:"failed" ~detail:None
        | Some Step_skipped ->
            logger.log ~tag:s.tag ~event:"skipped" ~detail:None
        | _ -> ());
  status
