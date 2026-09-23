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
                                       {!Canary_agreement.predicted_contains_any}
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
      inputs       : Canary_agreement_common.inspect_input list;
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
      inputs       : Canary_agreement_common.inspect_input list;
      version_info : version_info option;
    }

(** THE ACTION CONTEXT an agreement selection needs (2026-09-12).

    Three facts the enumeration already knows by the time a step
    exists: which binding mechanism this chain uses, which language it
    is, and the world the scenario assigned. Together with
    [step.action] they are enough for {!Canary_agreement.evaluate_step}
    to select every applicable checking method, resolve what each
    reads, and evaluate it — with no project naming an agreement and no
    caller supplying an input list.

    The type is {!Canary_agreement_common.action_context}, declared
    there because the registry's selection consumes one too and a type
    two layers share belongs in the lower of them.

    [None] on a step means the derivation had no binding facts to
    attach (a source fetch, a configure). Such a step still runs its
    own postcondition; it just has no agreement to select. *)
type agreement_ctx = Canary_agreement_common.action_context

(* [cache_key : string] was here until 2026-09-16. It was
   "<cache_project>:<tag>", the key of the global CI cache, and when
   that was deleted the field became written-and-never-read. It is
   removed rather than kept because an artifact cache is the thing that
   WILL want a key field, and a dead one of the wrong shape sitting
   here is how it would get reused by mistake — the key that design
   needs is a content hash plus the world's toolchain, which this was
   not. See [Canary_local_runner]'s header. *)
type step = {
  tag : string;
  output_tag : string;
  output_dir : string;
  project_dir : string;
  variant_id : string;
  action : Canary_basic.action;
  deps : string list;
  cmd : output_dir:string -> variant_key:string -> string;
  (* THE PRECONDITION, AS DATA (2026-09-21). Was
     [check_pre : unit -> bool], a closure over the local filesystem.

     It never carried any project logic: no project ever supplied one,
     and every step's predicate was the same sentence — "every dep's
     output directory exists". What the closure captured was not a
     decision but an ADDRESS, and a resolved one: a dep's output_dir
     differs from its tag's directory when [output_tag] is set (a
     scan_source writes inside fetch_source/), so only [derive_steps],
     holding the whole step list, can resolve it.

     So the step carries the resolved directories and the runner spells
     the predicate. The point is not that a field was removed — one was
     exchanged — it is that what remains is data: it survives being
     written to disk and read back, it crosses to a machine this process
     is not running on, and any backend can render it (`test -d a && test
     -d b`) instead of dropping it, which is what the GH backend does
     with a closure. See doc/canary/design/action_model.md §§4-5. *)
  dep_dirs : string list;
  check_post : output_dir:string -> variant_key:string -> bool;
  expectation : step_expectation;
  symbol_check : symbol_check option;
  (* Per-project agreement opt-outs (set by derive_steps from
     runner_spec.disabled_agreements). The runner combines this with
     the CLI's --disable-agreement list before evaluating. *)
  disabled_agreements : Canary_agreement_common.agreement_id list;
  (* The action context, when the step has binding facts to attach.
     Drives the context-driven agreement evaluation in the runner. *)
  agreement_ctx : agreement_ctx option;
  (* A DUMMY step (2026-09-12): it holds a place in the action graph
     and performs no work; the string says why. Carried on the step
     rather than inferred from the command so that "what is real in
     this graph" stays a question the step list can answer — see
     [Canary_step_builder.Dummy]. *)
  dummy : string option;
  (* WHERE A PROBE LOOKS (2026-09-23, status.md §2.7 phase B1): the
     location of the artifact a probe step reads — and an inspection of
     that probe — as its entry declared it. [None] for every other step.

     The TAG cannot answer this. A lone probe entry keeps the canonical
     tag whatever its location, so zarith's `probe_binding_ocaml` is a
     [Build_tree] probe (`-I <build tree>`) in one world and a
     [Pm (Lang_pm opam)] probe (`-package zarith`) in the next, and only
     this field tells the artifact-linked consumer program from the
     package-linked one. *)
  location : Canary_store.location option;
  (* WHAT AN INSPECTION STEP INSPECTS (2026-09-23): the tag of the
     parent step whose artifact it summarizes. It carries the parent's
     action but realizes no relation of its own — it records evidence —
     so a reader that colours what an action DID must be able to tell it
     from the step that did it without reading a tag suffix. [None] for
     a step that performs its action. *)
  inspects : string option;
}

type logger = {
  log : tag:string -> event:string -> detail:string option -> unit;
  close : unit -> unit;
}

(* [Step_done_xfail]: the step PASSED via a CONFIRMED expected failure — the
   command failed and the failure matched the (declared or derived)
   prediction. A pass for run purposes, but the distinction is surfaced (the
   world lines / spec views show WHERE a mismatch was detected). *)
type step_status = Step_done | Step_done_xfail | Step_failed | Step_skipped

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
