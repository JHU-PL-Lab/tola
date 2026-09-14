(** Behavioural agreements — claims about what running it does

    [behavior_matches] has no registry-side evaluator and says so. Its
    single method is PLANNED: behavioural truth lives in the running
    binary, and the expected values live inside the probe's own source
    as embedded assertions, so there is nothing static to compare. The
    probe's exit code is the observation today.

    The point of registering it anyway is that it is APPLICABLE at
    every probe action, and a selection that omitted it would report
    full coverage of a probe step while saying nothing about
    behaviour. It reports [not_implemented] with its reason instead. *)

open Canary_agreement_common

let behavior_matches : agreement =
  { ag_subject = Behavior;
    ag_claim = Behavioral;
    ag_basis = Behavioral_spec;
    ag_says = "the probe's trace matches what was recorded for it";
    ag_expects =
      "the probe's own embedded assertions. There is no project-independent \
       statement of what a binding should compute, so the expectation is \
       whatever the probe asserts — which bounds this agreement to the \
       inputs that probe exercises";
    ag_rooted_in =
      unrooted
        ~note:
          "no toolchain enforces that a function returns what a project \
           expected — a compiler checks types, a linker checks names, and \
           neither has an opinion about results. There is no relation here \
           to recover, only one to STATE, which is why this is unimplemented \
           in a different sense from an agreement that merely lacks evidence"
        ();
    ag_fault_tag = "behavior";
    ag_methods =
      [ checking_method ~name:"probe_assertions" ~kind:Run_program
          ~reference:Declared_facts ~firing:firing_probe_only
          ~inputs:(fun _ _ _ -> [])
          ~planned:
            "the expected values live inside the probe's source as embedded \
             assertions, and the observation is the probe's own exit code; \
             the registry has no evaluator that could read them. Wiring one \
             means giving the project a place to state expected results \
             outside the probe"
          ~limits:
            "not evaluated here. The probe's assertions cover the inputs \
             that probe runs and nothing else."
          () ] }

let checks : (agreement_id * agreement) list =
  [ (Behavior_matches, behavior_matches) ]
