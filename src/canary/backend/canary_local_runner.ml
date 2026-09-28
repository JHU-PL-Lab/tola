(** [Canary_local_runner] — the local execution backend.

    Consumes an [step list] (built by {!Canary_step_builder}'s
    [derive_steps]) and {i executes} the steps' shell commands directly,
    in-process. Sibling of:
    - {!Canary_gh} — emits GitHub Actions YAML for the same step list.
    - {!Canary_diagram} — renders Mermaid + the view machinery.

    Where the YAML/Mermaid backends produce a file for someone else
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
    [step]: this module only invokes [step.cmd] / [step.check_post],
    evaluates [step.dep_dirs], and never reads [runner_spec] directly.
    Symmetric design with the other backends.

    The firewall is one closure thinner since 2026-09-21: the
    precondition is [step.dep_dirs], data, spelled into a predicate
    here. A firewall made of closures is also a wall no other backend
    can see through, which is why the GH renderer drops what it cannot
    call — doc/canary/design/action_model.md §§4-5. *)

open Base
open Canary_step_model

(* ── THE GLOBAL CACHE IS GONE (deleted 2026-09-16, user) ─────────────
   It mapped "<cache_project>:<step_tag>" → a GH Actions step
   conclusion, was populated by a `cache-sync` subcommand reading CI
   results into a JSON file, and was consulted by [run_step] to skip
   steps CI had certified. Four findings, and the first alone is fatal:

   1. IT COULD NOT HIT, and had not been able to since A5
      (2026-08-05). `cache-sync` recorded keys built from the CI job
      specs, which are the only callers that override [cache_project]
      ("sqlite", "llvm-19", "z3-dev"). A local run leaves the default,
      which is the per-SCENARIO project name — so it computed
      "sqlite/lib-fetched_ocaml_binding-fetched:fetch_lib" and looked
      it up in a table keyed "sqlite:fetch_lib". Disjoint key spaces.
   2. It was UNREACHABLE anyway. `--cache` was parsed on `canary
      action` and threaded only into [run_tiny_scenario]; passing it to
      any registry project was silently ignored.
   3. It BYPASSED EVERY GATE. The hit short-circuited above the warm
      gate — no fingerprint, no [check_post], no switch, no platform —
      and those gates exist because a stale marker reading as a silent
      PASS is the bug the local cache was hardened against.
   4. Nothing fed it: the default file never existed, and no CI step or
      Makefile target created one.

   The LOCAL cross-run cache below is unaffected: verdict marker +
   fingerprint + [check_post], which is the sound one and the one
   `canary cache-test` covers.

   If a cross-machine cache is wanted, the design is an ARTIFACT store
   (`doc/canary/artifact_cache.md`): markers record verdicts, a store
   records what EXISTS, keyed on a declared key plus a recorded content
   hash, with a mismatch as a finding — and the key has to carry the
   world's toolchain, which nothing records today. That is a different
   thing from this, which is why this was deleted rather than repaired. *)

(* ── Execution ─────────────────────────────────────────────────────── *)

(* How many trailing output lines a failing step contributes to
   actions.log. Enough to carry a compiler error or a ninja FAILED block;
   small enough that a long build's tail does not bury the run. The whole
   output is always on disk — the [cmd_log] event names the file. *)
let fail_tail_lines = 25

(* THE EVIDENCE MARKER (2026-08-20, plan item A1). A step that learns
   something worth keeping prints a line beginning with this prefix, and
   the runner lifts it into actions.log as a [note] event — whether the
   step passed or failed.

   The need: z3's forward cell computes exactly the evidence a reader
   wants — `required(776), provided(705), missing(85)` and the names —
   into `symbols_<variant>.log`, which nothing reads. actions.log recorded
   only `check_post (FAIL)`. And on a PASS the numbers never surfaced at
   all, though "provided ⊇ required" is evidence too.

   A marker rather than a per-project hook because any step can have
   something to say, and because it keeps the knowledge in the command
   that computed it instead of in a parser that has to guess. *)
let note_marker = "CANARY-NOTE:"

(* At most this many notes per step — a runaway loop printing the marker
   should not be able to bury actions.log. *)
let max_notes = 12

(* Lines a step marked as evidence, marker stripped, in order. *)
let note_lines path =
  match Stdlib.Sys.file_exists path with
  | false -> []
  | true -> (
      try
        let ic = Stdlib.open_in path in
        let acc = ref [] in
        (try
           while List.length !acc < max_notes do
             let line = Stdlib.input_line ic in
             match String.substr_index line ~pattern:note_marker with
             | Some i ->
                 acc :=
                   String.strip
                     (String.subo line ~pos:(i + String.length note_marker))
                   :: !acc
             | None -> ()
           done
         with End_of_file -> ());
        Stdlib.close_in ic;
        List.rev !acc
      with _ -> [])

(* Read the last [n] lines of a file, oldest first. Bounded read: a build
   log can be large and we only ever want its tail. *)
let tail_lines ~n path =
  match Stdlib.Sys.file_exists path with
  | false -> []
  | true -> (
      try
        let ic = Stdlib.open_in path in
        let q = Queue.create () in
        (try
           while true do
             Queue.enqueue q (Stdlib.input_line ic);
             if Queue.length q > n then ignore (Queue.dequeue q : string option)
           done
         with End_of_file -> ());
        Stdlib.close_in ic;
        Queue.to_list q
      with _ -> [])

(* Run one shell command, CAPTURE its output, log it, return whether it
   exit-zeroed.

   Why the capture (2026-08-20, user: "I wish that we can just check the
   log to retrieve that information"). This used to be a bare
   [Sys.command], so a step's stdout and stderr went to the terminal and
   nowhere else: on failure actions.log recorded `cmd_fail (exit 1)` and
   the reason was gone the moment the scrollback was. Diagnosing z3's
   pre-10549 binding failure that day took three run/diagnose cycles
   because the error had to be reproduced by re-running ninja by hand.

   The shell form streams AND captures. A plain `cmd | tee f` would lose
   the exit status (the pipeline reports tee's), and `pipefail` is not
   POSIX — dash does not have it. So the status is parked in a file
   inside the group and re-raised after the pipe:

     { ( cmd ) ; echo $? > RC ; } 2>&1 | tee LOG ; exit $(cat RC)

   [echo $? > RC] writes to a file rather than the pipe, so it never
   pollutes LOG. The INNER parentheses are load-bearing and were missing
   in the first cut: many probe commands end in `exit $RC` (they capture
   the status, cat their log, then exit), and without a nested subshell
   that `exit` ends the whole group — [echo $?] never runs, the rc file
   never appears, and every such step reports failure. That is the same
   trap [with_world_asserts] hit on 2026-08-19, found again here within
   the hour by running zstd. *)
let run_cmd_logged logger ~tag ~output_dir ~variant_key cmd =
  logger.log ~tag ~event:"cmd" ~detail:(Some cmd);
  (* WHICH STORE THIS MUTATED (2026-08-26). The prologue is added below,
     after the [cmd] event, so the logged command does not show it — and
     actions.log is what gets attached to an issue. Record it explicitly
     rather than making a reader reconstruct it from the environment. *)
  logger.log ~tag ~event:"opam_switch"
    ~detail:(Some (Canary_store.opam_switch_label ()));
  (* AND WHICH PLATFORM IT WAS BUILT FOR (2026-08-26): the same command
     text means different things per platform — DYLD_ vs LD_, nm -g vs
     -D, brew vs apt — so a log line without it cannot be replayed or
     compared against the other machine's. *)
  logger.log ~tag ~event:"platform"
    ~detail:(Some (Canary_store.string_of_platform (Canary_store.platform ())));
  let out_log = Canary_basic.variant_file ~variant_key (tag ^ ".out.log") in
  let out_path = output_dir ^ "/" ^ out_log in
  let rc_path = output_dir ^ "/." ^ out_log ^ ".rc" in
  (* capture to the file AND mirror to the terminal, so a long build still
     shows progress while the evidence lands on disk *)
  let wrapped =
    Printf.sprintf
      "%srm -f %s\n{ (\n%s\n)\n  echo $? > %s\n} 2>&1 | tee %s\nexit $(cat %s \
       2>/dev/null || echo 1)"
      (* THE SWITCH (2026-08-26): exported here rather than threaded
         through 48 command templates, because every one of them already
         runs [eval $(opam env)] and opam env honours OPAMSWITCH. Outside
         the inner subshell so it applies to the whole group. *)
      (Canary_store.opam_switch_prologue () ^ Canary_store.run_id_prologue ())
      (Stdlib.Filename.quote rc_path) cmd (Stdlib.Filename.quote rc_path)
      (Stdlib.Filename.quote out_path) (Stdlib.Filename.quote rc_path)
  in
  let rc = Stdlib.Sys.command wrapped in
  (* the rc file is scaffolding for the pipeline, not a witness — leaving
     it behind puts a `.rc` line in every `status -v` step *)
  (try Stdlib.Sys.remove rc_path with _ -> ());
  (* the log points at its own evidence: the full output is always on
     disk, whether the step passed or failed *)
  logger.log ~tag ~event:"cmd_log" ~detail:(Some out_log);
  (* evidence the step chose to keep, pass or fail (A1) *)
  List.iter (note_lines out_path) ~f:(fun n ->
      logger.log ~tag ~event:"note" ~detail:(Some n));
  if rc <> 0 then begin
    logger.log ~tag ~event:"cmd_fail"
      ~detail:(Some [%string "exit %{Int.to_string rc}"]);
    (* THE POINT OF ALL THIS: the reason lands in actions.log itself, one
       event per line so the "[ts] tag event detail" shape survives and
       `grep cmd_out` gives a reader the failure directly. Everything that
       already parses actions.log — status, result, the HTML page — picks
       it up with no further work. *)
    List.iter
      (tail_lines ~n:fail_tail_lines out_path
      (* a marked line is already a [note] event; repeating it here would
         print the same evidence twice in `status -v` and double it in
         the log *)
      |> List.filter ~f:(fun l ->
             not (String.is_substring l ~substring:note_marker)))
      ~f:(fun line -> logger.log ~tag ~event:"cmd_out" ~detail:(Some line))
  end;
  rc = 0

(* Execute a step's shell command, ensuring output_dir exists. *)
let exec_step logger ~tag ~output_dir (step : step) =
  ignore (Stdlib.Sys.command [%string "mkdir -p \"%{output_dir}\""] : int);
  let shell_cmd = step.cmd ~output_dir ~variant_key:step.variant_id in
  run_cmd_logged logger ~tag ~output_dir ~variant_key:step.variant_id shell_cmd

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
  (* THE AGREEMENT EPOCH (2026-09-12). The two compat variants are the
     only expectations whose verdict is decided by the agreement
     registry, and the only markers whose CONTENT names agreements (the
     confirming ids on the xfail line). Renaming the agreements
     therefore invalidates exactly these, which is what mixing the
     schema tag in here does: the existing warm-skip gate re-runs the
     affected steps and leaves every build, fetch and hand-written
     Expect_failure warm. The alternative — deleting output trees —
     would throw away verdicts the rename says nothing about. *)
  let epoch = Canary_agreement_common.evaluation_schema in
  match e with
  | Expect_success -> "success"
  | Expect_failure { contains_any; _ } ->
      "failure:" ^ String.concat ~sep:"," contains_any
  | Expect_compat_failure _ -> "compat_failure/" ^ epoch
  | Expect_compat_derived _ -> "compat_derived/" ^ epoch

(** The step's spec fingerprint: the FULL realized cmd (it embeds every
    spec-derived bit — the assert_staged tests, prefixes, row order)
    plus the expectation form. MD5 (drift detection, not security). *)
let step_fingerprint (step : step) : string =
  let cmd = step.cmd ~output_dir:step.output_dir ~variant_key:step.variant_id in
  (* THE SWITCH IS PART OF THE WORLD (2026-08-26). The prologue is added
     at execution, so it is not in [cmd] — but a verdict earned in one
     switch says nothing about another, and serving it across a switch
     change would be exactly the stale-hit class the fingerprint exists
     to close (landing.md §4: a cache entry that does not encode the
     identity of what it ran is a lie). *)
  (* SO IS THE PLATFORM (2026-08-26). Much of the difference IS in [cmd]
     already (DYLD_ vs LD_, nm -g vs -D), so most cross-platform pairs
     would separate anyway — but not all: a step whose command is
     byte-identical on both (an opam install, a dune build) still earned
     its verdict against a different loader, a different libc and a
     different object format. Naming the platform in the digest makes
     that independent of how much of it the command happens to spell.
     Matters most under [--platform], where the command text changes
     while the machine does not. *)
  (* SO IS THE ACCEPTANCE POLICY (2026-09-15). Under [--strict] an
     [Expect_success] step also has to find no disagreement, so its
     verdict answers a strictly stronger question — serving a
     permissive marker to a strict run would report PASS for a step
     that was never asked the strict question. The suffix is EMPTY in
     the default mode on purpose: landing this must not invalidate a
     warm tree that is still being asked the same thing. *)
  let strict_suffix =
    if Canary_agreement_common.strict_mode () then "\x00strict" else ""
  in
  Stdlib.Digest.to_hex
    (Stdlib.Digest.string
       (cmd ^ "\x00" ^ expectation_form step.expectation ^ "\x00"
      ^ Canary_store.opam_switch_label () ^ "\x00"
      ^ Canary_store.string_of_platform (Canary_store.platform ())
      ^ strict_suffix))

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

(** The agreement names a marker's xfail line records
    ("xfail api_names_present" → ["api_names_present"]); [] for a
    plain / non-xfail / absent marker.

    Names that no longer PARSE are dropped (2026-09-12). A marker
    written before the rename says "xfail c2", and c2 is not an
    agreement any more — displaying it would attribute a verdict to
    something that does not exist. The fingerprint epoch already
    invalidates these markers, so the filter only covers the window
    between reading one and re-running its step. *)
let verdict_xfail_agreements (path : string) : string list =
  try
    Stdlib.In_channel.with_open_text path (fun ic ->
        match Stdlib.In_channel.input_line ic with
        | Some l -> (
            match String.split (String.strip l) ~on:' ' with
            | "xfail" :: ids ->
                List.filter ids ~f:(fun s ->
                    (not (String.is_empty s))
                    && Option.is_some
                         (Canary_agreement_common.agreement_id_of_string s))
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
  verdict_xfail_agreements (verdict_marker step)

(* Run a single action step; returns its [step_status] ([Step_done_xfail] =
   passed via a confirmed expected failure).
   Skipped only when a prior run met its expectation here — a verdict
   marker, NOT mere output presence — and the fingerprint and the
   postcondition both still hold. That is the whole skip rule since the
   global cache was deleted (2026-09-16); it used to be checked second,
   after a hit that consulted none of it. *)
let run_step logger ~root:_ ~project:_ (step : step) : step_status =
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
  (* Skip only if a PRIOR run recorded a met expectation here (verdict
     marker), so a failed probe is never served as cached success.
     AND the postcondition must still hold (2026-08-17, the Publish case
     study's finding — the code had drifted from the documented contract:
     a store-mutating world's warm skip must re-verify the store, e.g. a
     pin-checked fetch/publish whose [check_post] asserts the switch
     provably holds the pinned state — a stale marker over a changed
     store is otherwise a silent PASS for the wrong world). *)
  if Stdlib.Sys.file_exists marker_path
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
    (* A DUMMY step says so in the log. It succeeds, it writes its
       marker, and nothing about that is interesting — what IS
       interesting is that a place in the graph is deliberately empty,
       and a reader scanning a log for real work should be able to tell
       without reading the command. *)
    (match step.dummy with
     | Some why -> log ~event:"dummy" ~detail:(Some why)
     | None -> ());
    (* A PLACEHOLDER says what it stands for (2026-09-23): a piece of a
       package manager's action that this run does not record, and why —
       the log's own line for "not implemented yet" or "out of reach",
       which a reader of actions.log alone should be able to see *)
    (match step.placeholder with
     | Some ph ->
         log ~event:"placeholder"
           ~detail:
             (Some
                (Canary_pm_action.code_of_unseen ph.Canary_pm_action.ph_unseen
                ^ ": " ^ Canary_pm_action.describe ph))
     | None -> ());
    (* THE PRECONDITION IS SPELLED HERE, over data the step carries
       (2026-09-21). It used to be [step.check_pre ()], a closure the
       step builder captured; the step now carries the resolved
       directories and the predicate lives at the one place that
       evaluates it. Same sentence, same verdict, same log event — but a
       step list read back from disk, or handed to a backend that is not
       this runner, still says what its precondition was. *)
    let pre_ok = List.for_all step.dep_dirs ~f:Stdlib.Sys.file_exists in
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
        (* ── ONE EVALUATION RECORD PER STEP (2026-09-12) ──
           action context → selection → evidence resolution →
           evaluation → the record BOTH reporting and acceptance read.

           It used to be two evaluations: the context path to report
           and the input path to decide, each re-running the same
           comparators over (usually) the same files. Two evaluations
           of one question is how a log comes to say one thing while a
           verdict says another, so there is now one.

           The step carries the three facts the registry needs
           ([agreement_ctx], set by [derive_steps] from the scenario's
           world); the action is the step's own; and a compat
           expectation may ALSO name evidence, for the layouts whose
           routing is not derived yet (llvm's packed binding, z3's
           fetch-step attribute inspection). [evaluate_step] merges the
           two routes. *)
        let declared_inputs = match step.expectation with
          | Expect_compat_failure { inputs; _ }
          | Expect_compat_derived { inputs; _ } -> inputs
          | Expect_success | Expect_failure _ -> []
        in
        let step_eval =
          if Option.is_none step.agreement_ctx && List.is_empty declared_inputs
          then Canary_agreement.empty_step_evaluation
          else
            Canary_agreement.evaluate_step
              ~disabled:step.disabled_agreements ?context:step.agreement_ctx
              ~action:step.action ~declared_inputs ~resolve:resolve_input ()
        in
        (* REPORTING — every selected method, whatever its outcome. A
           step whose log showed only the checks that found something
           would read as full coverage; a planned method logs
           [not_implemented] with its reason. *)
        (if Option.is_some step.agreement_ctx || not (List.is_empty declared_inputs)
         then
           if List.is_empty step_eval.Canary_agreement.sv_all then
             log ~event:"agreement_outcome"
               ~detail:(Some "no agreement fires at this action")
           else
             List.iter step_eval.Canary_agreement.sv_all
               ~f:(fun (e : Canary_agreement.evaluation) ->
                 log ~event:"agreement_outcome"
                   ~detail:(Some (Canary_agreement.pp_evaluation e))));
        (* the symbol coverage WARNING (2026-08-17): a passing
           required_symbols_exported whose consumer surface covers a
           small fraction of the provider's may be out-of-date — a
           note, never a failure, and deliberately not an outcome. It
           re-reads the record's own evidence rather than riding the
           evaluation, because it qualifies a [holds] rather than
           replacing it. *)
        (match
           Canary_agreement_symbols.lag_note ~resolve:resolve_input
             step_eval.Canary_agreement.sv_inputs
         with
         | Some note -> log ~event:"compat_note" ~detail:(Some note)
         | None -> ());
        (if Option.is_some step.agreement_ctx || not (List.is_empty declared_inputs)
         then
           List.iter
             (Canary_agreement.skipped_checks
                ~disabled:step.disabled_agreements ())
             ~f:(fun ((r : Canary_agreement.agreement_row), reason) ->
               log ~event:"agreement_skipped"
                 ~detail:(Some (Printf.sprintf "%s: %s"
                                  r.Canary_agreement.ag_slug reason))));
        (* ACCEPTANCE — the same record, read for what this step must
           do. [sv_diagnostics] is the union of the detected
           disagreements' predicted output text; the expectation forms
           below decide what to make of it, because the POLICY is the
           project's (oracle: must fail regardless; agnostic: follow
           the prediction) while the FINDING is the artifacts'. *)
        let derived = step_eval.Canary_agreement.sv_diagnostics in
        (* A DETECTED DISAGREEMENT AND A CONFIRMED EXPECTED FAILURE ARE
           DIFFERENT FACTS. Confirmed = the artifacts disagree AND this
           run's output shows it; those are what the verdict marker
           records, because they are what the expected-failure test
           observed. Unconfirmed = the artifacts disagree and this
           action did not surface it — the finding stands, the step was
           simply not where it shows. Logged either way, so neither can
           be read off the other. *)
        let confirmed, unconfirmed =
          Canary_agreement.partition_confirmation step_eval
            ~matches:(fun subs -> output_contains_any ~output_dir:out subs)
        in
        let report_confirmation () =
          List.iter confirmed ~f:(fun (e : Canary_agreement.evaluation) ->
              log ~event:"agreement_confirmed"
                ~detail:(Some (e.Canary_agreement.ev_slug
                               ^ ": predicted text present in this run's output")));
          List.iter unconfirmed ~f:(fun (e : Canary_agreement.evaluation) ->
              log ~event:"agreement_unconfirmed"
                ~detail:(Some (e.Canary_agreement.ev_slug
                               ^ ": disagreement detected, not surfaced by this \
                                  action")))
        in
        let confirming_agreements () =
          List.map confirmed ~f:(fun (e : Canary_agreement.evaluation) ->
              e.Canary_agreement.ev_slug)
          |> List.dedup_and_sort ~compare:String.compare
        in
        let expectation_ok = match step.expectation with
          | Expect_success ->
              let post = cmd_ok && step.check_post ~output_dir:out ~variant_key:step.variant_id in
              log ~event:"check_post" ~detail:(Some (if post then "pass" else "FAIL"));
              (* A DETECTED DISAGREEMENT DOES NOT DECIDE THIS STEP —
                 UNLESS THE RUN ASKED IT TO. The step's acceptance
                 policy is "the command succeeds and its postcondition
                 holds"; a violated agreement here is a finding about
                 artifacts that this action was never asked to fail on.
                 It is reported (above, and as an unconfirmed
                 disagreement below) and not turned into a failure,
                 because doing so by default would change what every
                 existing project's steps accept.

                 [--strict] is that choice, made by the invocation
                 (Canary_agreement_common.strict_mode): while an
                 agreement is being landed, a finding should stop the
                 run at the step that read the evidence rather than
                 leave `canary result` printing ✗ beside a scenario
                 that says PASS. The violations are the SAME ones
                 reported above — strict mode adds no evaluation, it
                 only decides what an existing one means. *)
              report_confirmation ();
              let strict_violations =
                if Canary_agreement_common.strict_mode () then
                  step_eval.Canary_agreement.sv_violations
                else []
              in
              let ok = post && List.is_empty strict_violations in
              (match strict_violations with
               | [] -> ()
               | vs ->
                   log ~event:"strict_violation"
                     ~detail:(Some
                       (String.concat ~sep:"; "
                          (List.map vs ~f:Canary_agreement.pp_evaluation))));
              log ~event:(if ok then "done" else "failed")
                ~detail:
                  (if ok then None
                   else if not post then Some "postcondition failed"
                   else
                     Some
                       (Printf.sprintf
                          "--strict: %d disagreement(s) detected at a step \
                           that otherwise passed"
                          (List.length strict_violations)));
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
                (* a HAND-WRITTEN expected failure: the project stated
                   the substrings itself, so the step's acceptance does
                   not consult an agreement and the marker records no
                   attribution. Any disagreement the record found is
                   still reported. *)
                report_confirmation ();
                if found then xfail := true;
                log ~event:(if found then "done" else "failed")
                  ~detail:(Some (if found then confirmed_msg
                    else "command failed but output didn't match expected strings"));
                found
          | Expect_compat_failure { inputs = _; version_info } ->
              if cmd_ok then (
                log ~event:"unexpected_success"
                  ~detail:(Some "expected failure (derived) but command succeeded");
                false)
              else
                (* the ORACLE policy: this world was declared a
                   mismatch, so the step must fail whatever the
                   evaluation found. [derived] is the record's
                   diagnostics — the inputs were already read into it. *)
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
                report_confirmation ();
                if found then begin
                  xfail := true;
                  xfail_ids := confirming_agreements ()
                end;
                log ~event:(if found then "done" else "failed")
                  ~detail:(Some (if found
                    then confirmed_msg ^ xfail_id_suffix !xfail_ids
                    else "command failed but output didn't match derived predictions"));
                found
          | Expect_compat_derived { inputs = _; version_info = _ } ->
              (* Mutation-AGNOSTIC: the evaluation decides. If the
                 record found no disagreement the artifacts are fine
                 here, so a SUCCESS is correct (unlike the oracle
                 variant, which always expects the failure). If it
                 found one, the step must fail with that signature.
                 Lets tiny-full run without being told which agreement
                 breaks — canary discovers it. *)
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
                report_confirmation ();
                if found then begin
                  xfail := true;
                  xfail_ids := confirming_agreements ()
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
let run_graph ?(failfast = false) logger ~project ~root (steps : step list) =
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
            let st = run_step logger ~project ~root s in
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
