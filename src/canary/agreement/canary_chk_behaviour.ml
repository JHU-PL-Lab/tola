(** Behavioural agreements — claims about what running it does

    One module per check family (design: the per-check module pattern).
    Each check states its CATEGORY (descriptive), its STANDING, and a
    falsifier-phrased sentence; the function keeps whatever signature
    suits it, and the caller supplies the inputs.

    All three are UNWIRED: their predicts return [] by construction,
    which is why the registry marks them disabled rather than pretending
    they check something. *)

open Base
module Cat = Canary_agreement

(* c8 is a COMPOSITION of c6, c1 and c7, so this module depends on its
   two siblings. That is the domain relation, not an accident of
   layout: the registry records the same thing as [Blocked [C6; C7]]. *)
open Canary_chk_types
open Canary_chk_symbols

let trace_cat = Cat.Behaviour `Trace
let repack_cat = Cat.Api `Repacked
let standing = Cat.Declared
let trace_says = "the probe's trace matches what was recorded for it"
let repack_says = "the user-facing layer is a sound repacking of the stub-facing one"

(* ── c7: is the user-facing layer a sound repacking of the stub one ── *)

(** [c7 cmp_api_repack] result type. The contract pins {i s3
    binding_stub} ↔ {i s4 binding_header} within a single binding —
    every user-facing name should correspond to a stub-facing name
    (modulo declared renames), and vice versa. *)
type repack_result =
  | Repack_compatible
  | Repack_stub_orphan of { externals_not_exposed : string list }
  | Repack_user_phantom of { vals_without_external : string list }
  | Repack_unknown

(** [c7 cmp_api_repack] implementation. Compares the stub-facing
    externals against the user-facing vals (both from a single
    binding's two .mli files in tiny's setup, or wider in other
    bindings). Strict name-equality after filtering out declared
    rename pairs.

    Inputs in tiny's vocabulary:
    - [stub_externals] from {i bo1}'s [externals] field (e.g.
      [["sum"; "diff"; "get_offset"]] from Tiny_raw.mli)
    - [user_vals] from {i bo4}'s [vals] field (e.g.
      [["sum"; "diff"; "offset"]] from Tiny.mli)
    - [renames] declares allowed (external, val) pairs the binding
      author intentionally renamed. Empty list = strict match. Tiny
      passes [[("get_offset", "offset")]] so baseline reports
      [Repack_compatible] despite the asymmetric name.

    What c7 catches: stub-side orphan — a binding author wrote
    [external new_thing : ...] in Tiny_raw.mli (and the C stub) but
    forgot the corresponding [val new_thing : ...] in Tiny.mli.
    Tiny scenario {i e14 api_repack_stub_orphan} is the live witness:
    the patch adds [external alias_sum] to Tiny_raw without surfacing
    it in Tiny. Runtime probe is silent ({c3 cmp_behavior} sees
    nothing wrong); c1 cmp_symbol passes (no new tiny_* undef refs);
    c2 cmp_api_completeness passes (vals still cover the watchlist).
    Only c7 surfaces it.

    What c7 does NOT catch: tiny scenario {i e5 api_repack}. e5
    patches the [.ml] implementation (swaps [diff] arguments) but
    leaves both [.mli] files unchanged. c7 only sees [.mli] surfaces;
    the .ml repack drift is invisible to static check and is c3's
    territory.

    User-phantom shape: a val without any backing external. In
    well-typed OCaml this is unreachable (the .ml won't compile if
    no external/let backs the val). Kept as a result variant for
    Python parity later, where dir(pkg) can claim attrs without
    underlying bindings.

    Returns:
    - [Repack_compatible] — both sides agree (modulo renames).
    - [Repack_stub_orphan] — externals present in stub-facing but
      not exposed via user-facing.
    - [Repack_user_phantom] — vals present in user-facing without a
      backing external.
    - [Repack_unknown] — both sides empty. *)
let check_api_repack
    ~(stub_externals : string list)
    ~(user_vals : string list)
    ~(renames : (string * string) list)
    : repack_result =
  if List.is_empty stub_externals && List.is_empty user_vals then Repack_unknown
  else
    let renames_from =
      Set.of_list (module String) (List.map renames ~f:fst) in
    let renames_to =
      Set.of_list (module String) (List.map renames ~f:snd) in
    let externals = Set.of_list (module String) stub_externals in
    let vals = Set.of_list (module String) user_vals in
    (* Orphans: externals not in vals AND not declared as a rename source. *)
    let orphans = Set.diff (Set.diff externals vals) renames_from in
    (* Phantoms: vals not in externals AND not declared as a rename target. *)
    let phantoms = Set.diff (Set.diff vals externals) renames_to in
    match Set.is_empty orphans, Set.is_empty phantoms with
    | true, true -> Repack_compatible
    | false, _ ->
        Repack_stub_orphan { externals_not_exposed = Set.to_list orphans }
    | _, false ->
        Repack_user_phantom { vals_without_external = Set.to_list phantoms }

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

let c3_predict ~resolve:_ _ = []

let c7_predict ~resolve:_ _ = []

let c8_predict ~resolve:_ _ = []

(** c6 cmp_type (L2). Pairs a [Typed_header] input (provider's C
    signatures, n3) with a [Typed_binding_stub] input (consumer's
    stub-facing typed surface, bo1 / bpe1 — the binding's expectation
    of the C ABI). For each function present on both sides, checks
    whether the signatures agree (same return type, same arg type
    list). Mismatching names are returned as predicted substrings —
    the compiler error message for an arity / type clash mentions the
    function name verbatim (e.g.
    `error: too few arguments to function 'tiny_sum'`).

    Names present in only one side aren't c6 — they're c1
    (cmp_symbol's domain). c6 only fires when both sides claim the
    function but disagree on its signature. *)
(* ── decl-comparison predicts (2026-08-18) — the lib-only cells.
   The language TOOLS (compilers, linkers, version scripts) are black
   boxes with no bit-wise operational semantics — we inspect their
   ARTIFACTS and compare against the DECLARED facts. *)

(** c4 lib-only: the BUILT lib's own elf soname vs the declared soname
    (the linker's -Wl,-soname application is the black box; the
    artifact's elf is the evidence). *)
(** c1 lib-only: every DECLARED c_api function is exported by the
    built lib — the lib's own completeness falsifier, no binding
    involved. (The status-level watchlist verdict is this same
    comparison, currently recorded rather than predicted.) *)
