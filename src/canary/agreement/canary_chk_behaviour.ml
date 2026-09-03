(** Behavioural agreements — claims about what running it does

    One module per check family (design: the per-check module pattern).
    Each check states its CATEGORY (descriptive), its STANDING, and a
    falsifier-phrased sentence; the function keeps whatever signature
    suits it, and the caller supplies the inputs.

    c3 is UNWIRED: its predict returns [] by construction, because
    behavioural truth lives in the running binary and there is nothing
    static to predict over. The registry marks it disabled rather than
    pretending it checks something.

    c7 moved to [Canary_chk_api_surface] and c8 to
    [Canary_chk_composed] (2026-09-02): c7's own declared category is
    [Api `Repacked], and c8 is a composition rather than a family. *)

open Canary_agreement_common
module Cat = Canary_agreement_common

let trace : about =
  { cat = Cat.Behaviour `Trace;
    standing = Cat.Declared;
    says = "the probe's trace matches what was recorded for it" }

(** Every check this family states, for the module-pattern pin and the
    catalogue. One entry per CHECK, not per agreement. *)
let checks : (string * about) list = [ ("behavior_matches", trace) ]

let c3_predict ~resolve:_ _ = []

let c3 : description =
  { about = trace;
    claim = Semantic;
    evidence = Run_program;
    provenance = Added;
    reads = [ ("Trace", "run") ];
    fault_tags = [ "behavior" ];
    firing = firing_probe_only;
    inputs = (fun _ _ _ -> []);
    (* nothing static to predict over, so nothing to falsify here *)
    counterexamples = [] }
