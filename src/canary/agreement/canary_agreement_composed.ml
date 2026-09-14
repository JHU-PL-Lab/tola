(** COMPOSED agreements — verdicts derived from other agreements.

    Not a check family. A family reads artifacts; this reads other
    families' VERDICTS, which is why it sits above them and why it is
    the one module here allowed to name its siblings (from the user's
    tier model: a concrete family refers only to
    [Canary_agreement_common], so a composition cannot be one).

    [repack_complete] keeps a PROVISIONAL name and a PLANNED method.
    Its claim — "the repack loses nothing the original had" — has no
    agreed scope: a binding may deliberately expose only part of a
    provider, so "loses nothing" needs a statement of what it is
    allowed to omit before it can be checked. Two of the three
    agreements it would compose are themselves unevaluated. *)

open Base
open Canary_agreement_common

(** The families this composes — DECLARED, so the layering pin can tell
    a composition from a family that reached sideways by accident. A
    module that publishes [checks] and no [composes] is a family, and
    families may not name each other; this one says what it is. *)
let composes =
  [ "Canary_agreement_types"; "Canary_agreement_symbols";
    "Canary_agreement_api_surface" ]
open Canary_agreement_types
open Canary_agreement_symbols
open Canary_agreement_api_surface

(* ── the composition, as a pure function over three verdicts ── *)

(** The derived claim: "the user-facing API is faithful to the
    underlying C API", by the decomposition

      faithfulness ⇐ signatures ∧ symbols ∧ repacking

    Each constituent is checked separately; this reports the
    composition with per-constituent attribution, so a caller can say
    which part failed. *)
type faithfulness_result =
  | Faithful
  | Unfaithful of {
      type_issue : type_result option;
      symbol_issue : compat_result option;
      repack_issue : repack_result option;
    }
  | Faithfulness_unknown

let check_api_faithfulness
    ~(type_verdict : type_result)
    ~(symbol_verdict : compat_result)
    ~(repack_verdict : repack_result)
    : faithfulness_result =
  let type_bad = match type_verdict with
    | Type_compatible | Type_unknown -> None
    | (Type_arity_mismatch _ | Type_unmapped _) as t -> Some t in
  let symbol_bad = match symbol_verdict with
    | Compatible | Compatible_lag _ | Unknown -> None
    | Missing _ as s -> Some s in
  let repack_bad = match repack_verdict with
    | Repack_compatible | Repack_unknown -> None
    | (Repack_stub_orphan _ | Repack_user_phantom _) as r -> Some r in
  (* Unknown only when ALL three are Unknown (not enough data anywhere). *)
  let all_unknown =
    (match type_verdict with Type_unknown -> true | _ -> false)
    && (match symbol_verdict with Unknown -> true | _ -> false)
    && (match repack_verdict with Repack_unknown -> true | _ -> false) in
  if all_unknown then Faithfulness_unknown
  else match type_bad, symbol_bad, repack_bad with
    | None, None, None -> Faithful
    | _ ->
        Unfaithful
          { type_issue = type_bad
          ; symbol_issue = symbol_bad
          ; repack_issue = repack_bad }

let repack_complete : agreement =
  { ag_subject = Repacking;
    ag_claim = Behavioral;
    ag_basis = Behavioral_spec;
    ag_says = "the repack loses nothing the original had";
    ag_expects =
      "a statement of what the binding is allowed to omit. Without one there \
       is no reference: a binding that deliberately wraps a subset is \
       indistinguishable from one that dropped something";
    ag_rooted_in =
      unrooted
        ~note:
          "unrooted TWICE OVER: it composes one agreement that has a rule \
           (the linker's) with two that do not. A composition cannot be \
           better rooted than its weakest part"
        ();
    (* POST: it composes both pre- and post-claims, and what it asserts
       is a property of the finished binding, so it lands where the
       product does. *)
    ag_slot = after_binding;
    ag_fault_tag = "api_add";
    ag_methods =
      [ checking_method ~name:"composed_faithfulness" ~kind:Run_program
          ~reference:Declared_facts ~firing:firing_default
          ~inputs:(fun _ -> [])
          ~planned:
            "the claim's scope is unsettled (\"loses nothing\" needs an \
             allowed-omission policy), and two of the three agreements it \
             composes — repacking and behaviour — have no evaluator either. \
             check_api_faithfulness composes three verdicts and is ready for \
             the day they exist"
          ~limits:
            "not evaluated. The composition function exists and is pure; \
             what it would mean is the open decision."
          () ] }

let checks : (agreement_id * agreement) list =
  [ (Repack_complete, repack_complete) ]
