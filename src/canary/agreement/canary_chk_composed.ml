(** COMPOSED agreements — verdicts derived from other agreements.

    Not a check family. A family reads artifacts; this reads other
    families' VERDICTS, which is why it sits above them and why it is
    the one module here allowed to name its siblings (2026-09-02, from
    the user's tier model: a concrete family refers only to
    [Canary_agreement_common], so a composition cannot be one).

    The registry says the same thing in its own vocabulary — c8's
    status is [Blocked [C6; C7]] — and this module is where that
    blocking relation is executable rather than merely recorded. *)

open Base
open Canary_agreement_common
open Canary_chk_types
open Canary_chk_symbols
open Canary_chk_api_surface

(* ── c8: is the user-facing API faithful to the C one (the composition) ── *)

(** [c8 cmp_api_faithfulness] result type. The derived contract:
    "user-facing API is faithful to the underlying C API." By the
    decomposition in surface_draft/implementation.md §2.5:

      API-faithfulness ⇐ Type (c6) ∧ Symbol (c1) ∧ API-repacking (c7)

    Each constituent is checked separately; c8 reports the
    composition. [Faithful] iff all three are compatible.
    [Unfaithful] iff at least one disagrees, with each disagreement
    surfaced separately (so the caller can attribute blame).

    Catches tiny scenario {i e4 api_faithful}: C adds [tiny_max], the
    binding doesn't expose it. Today's e4 expected outcomes are all
    "ok" (silent). When c8 is wired into the action pipeline, the
    static check surfaces the unfaithfulness — `n3.functions`
    includes `tiny_max` (via the new c6 inspector path) but the
    binding's `bo1.externals` doesn't list a corresponding wrapper.
    The verdict materializes as a `Type_unmapped` issue carried by
    `Unfaithful`. *)
type faithfulness_result =
  | Faithful
  | Unfaithful of {
      type_issue : type_result option;
      symbol_issue : compat_result option;
      repack_issue : repack_result option;
    }
  | Faithfulness_unknown

(** [c8 cmp_api_faithfulness] — pure composition. Takes the three
    constituent verdicts (c6 [type_result], c1 [compat_result],
    c7 [repack_result]) and reports the worst-case verdict with
    per-constituent attribution. *)
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

(* c8 is UNWIRED: it can only compose verdicts, and two of the three it
   composes are themselves unwired. [] until they are not. *)
let c8_predict ~resolve:_ _ = []

let cat = Canary_agreement_common.Api `Repacked
let standing = Canary_agreement_common.Declared
let says = "the repack loses nothing the original had"

let c8 : description =
  { cat; standing; says;
    claim = Semantic;
    evidence = Run_program;
    provenance = Added;
    reads = [ ("Sf.4", "binding") ];
    fault_tags = [ "api_add" ];
    firing = firing_default;
    inputs = (fun _ _ _ -> []);
    counterexamples = [] }
