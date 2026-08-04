(** [Canary_detect] — the forecast-agnostic detection pass (seam S5a —
    [doc/canary/design/ssot.md] §6.1).

    Detection observes what a step actually did, independent of the
    hand-authored [step_expectation] verdict. This is the S5a skeleton:
    the {b plumbing} runs on every step of every project (including
    tiny), logging a [detect] finding, while the existing expectation
    still decides pass/fail. The verdict is untouched — detection only
    reports.

    The detector here is deliberately {b trivial} for now: did the
    command error, and is the step's output present. Integrating the
    real detection — running the c1..c8 contracts over the observed
    artifacts (surface + store_config) and classifying findings by
    severity/reaction — is postponed to a later seam. When it lands,
    [finding] grows (contract id, severity, discovered substrings); the
    call site and transport stay the same. *)

type finding = {
  tag : string; (* the step's tag *)
  errored : bool; (* the command exited non-zero *)
  output_present : bool; (* the step's output dir has a result *)
}

(** The trivial detector: classify a step by its raw outcome. No
    contracts, no expectation — just "errored?" and "expected output
    present?" (the two crude signals). *)
let simple_finding ~tag ~cmd_ok ~output_present : finding =
  { tag; errored = not cmd_ok; output_present }

let string_of_finding (f : finding) : string =
  Printf.sprintf "%s, output %s"
    (if f.errored then "error" else "ok")
    (if f.output_present then "present" else "absent")
