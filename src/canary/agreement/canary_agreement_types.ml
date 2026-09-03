(** Type agreements — the C signatures at the header/stub boundary

    One module per check family (design: the per-check module pattern).
    Each check states its CATEGORY (descriptive), its STANDING, and a
    falsifier-phrased sentence; the function keeps whatever signature
    suits it, and the caller supplies the inputs. *)

open Base
open Canary_agreement_common
module Cat = Canary_agreement_common

(* ── what this module is about ── *)

let signature : about =
  { cat = Cat.Types `Signature;
    standing = Cat.Declared;
    says = "the types a stub declares agree with the header it wraps" }

let checks : (string * about) list = [ ("c_types_agree", signature) ]

(* ── the evidence this family reads ── *)

(** Typed-signature view of an inspect JSON. The producing inspector
    ([canary/scripts/inspect_tiny_typed.py] today; AST-based
    replacements later) emits one [functions] dict keyed by name with
    typed return / arg lists. [layer] preserves which surface this
    came from (header / stub_ocaml / user_ocaml / stub_python /
    user_python) so c6/c7/c8 predicates can sanity-check the inputs
    they were handed.

    Provider and consumer sides share this shape — what differs is
    which file the inspector ran on. The diff happens in the
    comparator (c6 checks header vs stub agreement; c7 checks
    stub vs user repack consistency; c8 combines both). *)
type typed_signature = {
  return_type : string;
  arg_types : string list;
}

type typed_signatures_inspect = {
  path : string;
  layer : string;
  functions : (string * typed_signature) list;
}

let load_typed_signatures path : typed_signatures_inspect =
  let j = load path in
  let kind = get_string j "kind" in
  let layer =
    match String.chop_prefix kind ~prefix:"typed_" with
    | Some l -> l
    | None ->
        Fmt.epr "compat: warning — expected kind=typed_<layer>, got %s (%s)@."
          kind path;
        "unknown" in
  let functions =
    match field j "functions" with
    | Some (`Assoc entries) ->
        List.map entries ~f:(fun (name, sig_json) ->
          let return_type = get_string sig_json "return" in
          let arg_types =
            match field sig_json "args" with
            | Some (`List xs) ->
                List.filter_map xs ~f:(function `String s -> Some s | _ -> None)
            | _ -> [] in
          (name, { return_type; arg_types }))
    | _ -> [] in
  { path = get_string j "path"; layer; functions }

(** [c6 cmp_type] result type. Pins {i s1 native_header} ↔ {i s3
    binding_stub} at the function-signature level. Today's check is
    arity-only (compare number of args after applying the project's
    declared name mapping); full type-equivalence comparison is a
    later refinement. *)
type type_result =
  | Type_compatible
  | Type_arity_mismatch of {
      mismatches : (string * int * int) list;
        (** Each entry is [(binding_external_name, binding_arity, header_arity)]
            where the two arities disagree. *)
    }
  | Type_unmapped of { externals : string list }
        (** Binding externals that have no entry in the name mapping,
            i.e. we can't tell which header function they correspond to.
            Treated as a separate verdict (not "Unknown") so the caller
            can distinguish "no header function with that mapped name"
            from "mapping is incomplete." *)
  | Type_unknown
        (** One side is empty (no externals to check, or no header data). *)

(** [c6 cmp_type] implementation. For each binding external, look up
    its corresponding header function via [name_mapping], then compare
    arities.

    Inputs in tiny's vocabulary:
    - [header_functions]: list of [(name, arity)] from {i n3}'s
      [functions] field (e.g.
      [[("tiny_sum", 2); ("tiny_diff", 2)]] from tiny.h).
    - [binding_externals]: list of [(name, arity)] from {i bo1}'s
      [externals_detail] field (e.g.
      [[("sum", 2); ("diff", 2); ("get_offset", 1)]] from
      Tiny_raw.mli).
    - [name_mapping]: list of [(external_name, header_name)] pairs the
      project declares. For tiny this is
      [[("sum", "tiny_sum"); ("diff", "tiny_diff")]] —
      [get_offset] is intentionally excluded because it maps to an
      extern var (s1 vars, not s1 functions; outside c6's scope).

    Behavior:
    - Externals NOT in [name_mapping] go to [Type_unmapped]. The caller
      can either widen the mapping or accept that those externals
      aren't covered by c6.
    - Externals mapped to a header function name that doesn't exist
      in [header_functions] would be a different gap (binding claims a
      function the header doesn't declare) — currently we treat the
      mapping as authoritative and just record it as a 0-vs-binding-arity
      mismatch via [Type_arity_mismatch] with header_arity = -1.

    Returns:
    - [Type_compatible] — every mapped external's arity matches its
      header function's arity. [Type_unmapped] externals don't block
      [Type_compatible]; they're informational.
    - [Type_arity_mismatch] — at least one mapping where arities
      disagree.
    - [Type_unmapped] — emitted only when there are NO mapped
      externals at all (i.e. the mapping is empty for these
      bindings). Coexists with [Type_arity_mismatch] when both
      conditions apply (mismatches reported; unmapped externals
      listed as a separate sub-issue not currently expressed).
    - [Type_unknown] — empty inputs. *)
let check_type
    ~(header_functions : (string * int) list)
    ~(binding_externals : (string * int) list)
    ~(name_mapping : (string * string) list)
    : type_result =
  if List.is_empty header_functions && List.is_empty binding_externals then
    Type_unknown
  else
    let header_arity = Map.of_alist_exn (module String) header_functions in
    let mismatches = ref [] in
    let unmapped = ref [] in
    let mapped_any = ref false in
    List.iter binding_externals ~f:(fun (ext_name, ext_arity) ->
        match List.find name_mapping ~f:(fun (e, _) ->
            String.equal e ext_name) with
        | None -> unmapped := ext_name :: !unmapped
        | Some (_, hdr_name) ->
            mapped_any := true;
            let h_arity =
              Map.find header_arity hdr_name |> Option.value ~default:(-1) in
            if h_arity <> ext_arity then
              mismatches := (ext_name, ext_arity, h_arity) :: !mismatches);
    let mismatches = List.rev !mismatches in
    let unmapped = List.rev !unmapped in
    if not (List.is_empty mismatches) then
      Type_arity_mismatch { mismatches }
    else if not !mapped_any && not (List.is_empty unmapped) then
      Type_unmapped { externals = unmapped }
    else
      Type_compatible

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
let c6_predict ~resolve (inputs : inspect_input list) : string list =
  let header_path =
    List.find_map inputs
      ~f:(function Typed_header ps -> pick_existing ~resolve ps | _ -> None) in
  let stub_path =
    List.find_map inputs
      ~f:(function Typed_binding_stub ps -> pick_existing ~resolve ps
                 | _ -> None) in
  match header_path, stub_path with
  | Some hp, Some sp ->
      let h = load_typed_signatures hp in
      let s = load_typed_signatures sp in
      List.filter_map h.functions ~f:(fun (name, h_sig) ->
        match List.Assoc.find s.functions name ~equal:String.equal with
        | None -> None
        | Some s_sig ->
            if String.equal h_sig.return_type s_sig.return_type
               && List.equal String.equal h_sig.arg_types s_sig.arg_types
            then None
            else Some name)
  | _ -> []

(* Best-effort: ".ok" marker file alongside cmd success implies probe step
   succeeded. probe.log non-empty + no .ok marker implies cmd failed (which
   for Expect_failure cases is the GOAL — see step_expectation in
   canary_action.ml). We're not re-implementing the runner's verdict; just
   distinguishing "log has compile error text" from "log shows runtime ok". *)

let c6 : description =
  { about = signature;
    claim = Structural;
    evidence = Compare_several;
    provenance = Added;
    reads = [ ("Sf.1", "native"); ("Sf.3", "binding") ];
    fault_tags = [ "type_arity" ];
    firing = firing_default;
    inputs =
      (fun m l _ ->
        match (l, is_dynamic m) with
        | Canary_lang.OCaml, false ->
            (* the header is the NATIVE side and language-neutral; the
               stub surface is the MECHANISM's — [external] is how
               cstubs spells the boundary — and says so there *)
            [ Typed_header [ "scan_sources/inspect_typed_header.json" ];
              Canary_agreement_cstubs.typed_stub_surface ]
        | _ -> []);
    (* pends its fixture: the typed-signature JSON shape is the one
       loader with no synthetic body written for it yet *)
    counterexamples = [] }
