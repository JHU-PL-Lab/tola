(** [Canary_world] — is the machine in the world this scenario names?

    {1 The world, and why naming one is not having one}

    A scenario is one placement per artifact: {i this} lib, {i that}
    binding, at {i these} versions. That naming is canary's whole subject
    — a verdict means "the world described by row N behaves so". But the
    naming is a CLAIM about the machine at the moment a step runs, and
    between the claim and the step sit three ways for it to be false:

    - {b a shared store holds one state.} An opam switch is
      [Isolated_store "switch"] ({!Canary_store.store_behavior_of_pm}) —
      isolated from the system, and internally single-valued: it holds ONE
      version of a package. Scenario N's fetch re-pins it; scenario N+1
      inherits whatever is there.
    - {b resolution is ambient by default.} [LD_LIBRARY_PATH] expresses a
      preference, not a guarantee. A probe that finds the system copy
      instead of the world's runs a different world and reports success.
    - {b artifacts go stale.} A build tree keeps producing outputs after
      the thing they were made from has changed underneath them.

    Each of these produces the same shape of wrong answer: {b a green cell
    for a world nobody tested}. That is worse than a red one, because red
    gets investigated.

    {1 What an assertion is, mechanically}

    A world assertion is the step's own evidence that it is in the world
    it claims. Not a prediction of behaviour — a statement of identity.
    Two kinds, because the two failure modes need catching at different
    moments:

    - {!Opam_pin} runs BEFORE the command and aborts. It is the
      counterpart of the store's statefulness: the scenario's pin is an
      exclusive lock on the switch's state for the step's duration, and
      this checks the lock is actually held. It cannot be a post-hoc check
      — by then the wrong version has already been linked against.
    - {!Log_names} is read AFTER, from the step's own log. It is how a
      probe reports which artifact ANSWERED — a runtime version line, or
      the library path the loader actually mapped. Prefer the path when
      there is a choice: every library has one, and only some bindings
      expose a version accessor.

    {1 Who declares these, and who enforces them}

    {v
    a project spec  ──declares──▶  Canary_world.t list
       (per action × location, on runner_spec.asserts, or inline
        on a probe's ~log_grep)
                                          │
    Canary_step_builder ──routes──▶  pre_shell   → prefixed to the command
                                     log_substrings → greped from its log
    v}

    The routing is the point of having one type. A consumer that could
    only enforce one kind used to honour it and drop the other in silence
    — that is precisely how cairo's and libffi's vendored worlds ended up
    pointed at a prebuilt and never checked. Both kinds now travel
    together and {!is_pre} makes a partial consumer say so.

    Declared today by: sqlite (an amalgamation version line), ssl / z3 /
    llvm (switch pins), and the opam-binding template on behalf of cairo /
    libffi / zlib / zstd (the vendored libdir).

    {1 The scheduling consequence}

    Because {!Opam_pin} is a lock on a single-valued store, two scenarios
    wanting different pins cannot both be satisfied at once — and two
    wanting the SAME pin should be run together. Measured 2026-08-20:
    sqlite's ten scenarios alternate their binding pin every row, so one
    run performs {b ten} pin operations where grouping by pin would
    perform {b two}. Each is an uninstall + reinstall.

    So the assertion is the enforcement half of a property the enumeration
    should also exploit: {b order scenarios by the stateful-store state
    they need}. Nothing does that yet — the enumerated list IS the run
    order. Tracked in [doc/canary/project/store_switching.md].

    {1 What this is not}

    A world assertion is a POSITIVE-scenario invariant about identity. It
    is not a [step_expectation] (what a MISmatched world must do), not a
    [check_pre]/[check_post] (whether the step's inputs and outputs
    exist), and it does not belong to the contract/expectation
    unification. Those say what happens in a world; this says which world
    it is.

    {1 Why one type at all}

    The concept had five implementations, four of which had failed by
    2026-08-20: three byte-identical [<project>_world_check] copies,
    sqlite's [asserts] appended after [exit $RC] so it had never run, and
    the template's [world_check]/[log_grep] pair unwired for vendored
    worlds. Five places to fix, nowhere to test. History and evidence:
    [doc/canary/project/landing.md] §4 and
    [doc/canary/design/run_model_revisit.md] §3. *)

open Base

(** One assertion about the world a step runs in. Each carries [why]: the
    text a reader sees when it fires. Today's lesson was that a check with
    a message nobody can act on is barely a check — the prebuilt guard
    printed "run  first" because its own hint had been eaten by the
    shell. *)
type t =
  | Opam_pin of { pkg : string; version : string }
      (** BEFORE the command: the switch must hold [pkg] at exactly
          [version] — the scenario's exclusive lock on a single-valued
          store, verified rather than assumed. Scenario N can find
          scenario N-1's pin; this makes that loud instead of silent.

          Checked against the OPAM package version
          ([opam list --columns=version]), not the findlib META version:
          the two differ for locally published packages (z3.dev's META
          carries the source version, not the opam one). *)
  | Log_names of { text : string; why : string }
      (** AFTER the command: the step's own log must contain [text]. This
          is how a probe proves WHICH artifact answered — a runtime
          version line ([zstd version: 1.5.7]), or the library path the
          loader actually mapped ([zlib resolved: …/prebuilt/…]). Prefer
          a path when the binding exposes no version: a path exists for
          every library, a version accessor does not. *)
[@@deriving show, eq]

(** The shell that must pass BEFORE the step's command. Empty when no
    assertion is of the pre kind — callers concatenate it, so an empty
    string is the identity and needs no special case at the call site. *)
let pre_shell (ws : t list) : string =
  String.concat ~sep:""
    (List.filter_map ws ~f:(function
      | Opam_pin { pkg; version } ->
          Some
            (Printf.sprintf
               "eval $(opam env)\n\
                INSTALLED=$(opam list %s --installed --short \
                --columns=version 2>/dev/null)\n\
                test \"$INSTALLED\" = \"%s\" || { echo \"WORLD MISMATCH: \
                switch has %s $INSTALLED, scenario declares %s %s\"; exit \
                1; }\n"
               pkg version pkg pkg version)
      | Log_names _ -> None))

(** The substrings the step's own log must contain AFTER it runs. The
    caller knows where its log is; this only says what has to be in it. *)
let log_substrings (ws : t list) : string list =
  List.filter_map ws ~f:(function
    | Log_names { text; _ } -> Some text
    | Opam_pin _ -> None)

(** Why each log assertion exists, for a reader of the spec or a failure
    message. Kept beside [log_substrings] so the two cannot drift. *)
let reasons (ws : t list) : (string * string) list =
  List.filter_map ws ~f:(function
    | Log_names { text; why } -> Some (text, why)
    | Opam_pin { pkg; version } ->
        Some (pkg ^ "." ^ version, "the switch must hold the scenario's pin"))

(** Is this assertion checked before the command (vs after)? Exposed so a
    caller that can only enforce one kind says which, instead of silently
    dropping the other — the [log_grep:None] shape that let cairo's
    vendored world go unchecked. *)
let is_pre : t -> bool = function Opam_pin _ -> true | Log_names _ -> false
