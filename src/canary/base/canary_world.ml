(** [Canary_world] — WORLD ASSERTIONS (2026-08-20).

    THE QUESTION THIS TYPE ANSWERS: *did the step actually run in the
    world its scenario names?* A scenario declares a placement per
    artifact — "the lib is the vendored 1.3.2", "the binding is opam
    ssl.0.6.0" — but declaring it does not make it so. The switch is
    shared state, [LD_LIBRARY_PATH] is a preference not a guarantee, and
    a probe that resolves the ambient artifact instead of the declared one
    passes for the wrong reason and looks exactly like success.

    WHY IT IS ITS OWN TYPE. The concept existed in FIVE separate
    implementations, and by 2026-08-20 four of them had failed:

    - [ssl_world_check] / [z3_world_check] / [llvm_world_check] — three
      byte-identical shell builders differing only in the package name;
    - sqlite's [asserts] field, greped by [with_world_asserts] — which
      appended the check after `exit $RC`, so it had NEVER run;
    - the opam template's [world_check] prefix plus a separate [log_grep]
      argument — and neither was wired for the Vendored lib worlds, so
      cairo and libffi pointed the loader and never checked it obeyed;
    - z3's [assert_staged], whose [None] let an install claim success.

    Five implementations means five places to fix and no single place to
    test. This is the one place. See
    [doc/canary/project/landing.md] §4 for the failure class and
    [doc/canary/design/run_model_revisit.md] §3 for why declaring a world
    is not the same as being in it.

    POLARITY, because it is easy to confuse: a world assertion is a
    POSITIVE-scenario invariant ("the run really exercised the enumerated
    world"), the OPPOSITE of a [step_expectation] ("a mismatched world
    must fail this way"). Expectations say what a wrong world does; these
    say which world it is. They stay separate deliberately — the
    contract/expectation unification does not absorb them. *)

open Base

(** One assertion about the world a step runs in. Each carries [why]: the
    text a reader sees when it fires. Today's lesson was that a check with
    a message nobody can act on is barely a check — the prebuilt guard
    printed "run  first" because its own hint had been eaten by the
    shell. *)
type t =
  | Opam_pin of { pkg : string; version : string }
      (** BEFORE the command: the opam switch must hold [pkg] at exactly
          [version]. The switch is shared by every scenario in the run, so
          scenario N can find scenario N-1's pin — this is the guard that
          makes that loud rather than silent. Checked against the OPAM
          package version ([opam list --columns=version]), not the findlib
          META version: those differ for locally published packages
          (z3.dev's META carries the source version). *)
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
