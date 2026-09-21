(** Signature agreements — the types at the header/stub boundary

    One agreement, [signatures_agree], with one implemented method that
    compares signature SUMMARIES textually. The arity comparator below
    is a second, unregistered way of asking a related question; it is
    kept because the tiny factory uses it, and it is deliberately NOT
    the agreement's evaluator (they disagree about what they compare:
    one matches names that appear on both sides, the other applies a
    declared name mapping). *)

open Base
open Canary_agreement_common

(* ── the evidence this family reads ── *)

(** Typed-signature view of an inspect JSON. The producing inspector
    ([canary/scripts/inspect_tiny_typed.py] today; AST-based
    replacements later) emits one [functions] dict keyed by name with
    typed return / arg lists. [layer] preserves which surface this came
    from (header / stub_ocaml / user_ocaml / stub_python / user_python)
    so a comparator can sanity-check the inputs it was handed.

    Provider and consumer sides share this shape — what differs is
    which file the inspector ran on. *)
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

(* ── the comparators ── *)

(** Arity comparison under a project-declared name mapping. NOT the
    registered evaluator: it answers a different question from the
    textual signature comparison below (which compares names present on
    both sides and ignores the mapping), and conflating the two is one
    of the audit findings this split records. Consumed by tiny's
    factory. *)
type type_result =
  | Type_compatible
  | Type_arity_mismatch of {
      mismatches : (string * int * int) list;
        (** [(binding_external_name, binding_arity, header_arity)] *)
    }
  | Type_unmapped of { externals : string list }
        (** Binding externals with no entry in the name mapping: we
            cannot tell which header function they correspond to. *)
  | Type_unknown

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

(* ── the evaluator ── *)

(** Compare return-type strings and argument-type lists for every
    function name present on BOTH sides. A name on only one side is not
    a signature disagreement — that is the symbol agreements' question.

    On a mismatch the finding is the function name, because that is
    what the compiler's message names verbatim ("too few arguments to
    function 'tiny_sum'"). *)
let signatures_eval ~resolve inputs : outcome =
  let header_path =
    List.find_map inputs
      ~f:(function Typed_header ps -> pick_existing ~resolve ps | _ -> None) in
  let stub_path =
    List.find_map inputs
      ~f:(function Typed_binding_stub ps -> pick_existing ~resolve ps
                 | _ -> None) in
  match (header_path, stub_path) with
  | None, _ ->
      Unavailable (Missing_evidence "no header signature summary in this world")
  | _, None ->
      Unavailable
        (Missing_evidence "no binding signature summary in this world")
  | Some hp, Some sp ->
      let h = load_typed_signatures hp in
      let s = load_typed_signatures sp in
      let shared =
        List.filter h.functions ~f:(fun (name, _) ->
            Option.is_some (List.Assoc.find s.functions name ~equal:String.equal))
      in
      if List.is_empty shared then
        Inconclusive
          "no function name occurs in both summaries; there is no pair to \
           compare"
      else (
        match
          List.filter_map shared ~f:(fun (name, h_sig) ->
              match List.Assoc.find s.functions name ~equal:String.equal with
              | None -> None
              | Some s_sig ->
                  if
                    String.equal h_sig.return_type s_sig.return_type
                    && List.equal String.equal h_sig.arg_types s_sig.arg_types
                  then None
                  else Some name)
        with
        | [] -> Holds
        | names -> Violated names)

(* ── the agreement ── *)

let signatures_agree : agreement =
  { ag_kind = Admissibility;
    ag_subject = Signatures;
    ag_claim = Structural;
    ag_basis = Toolchain_rule;
    ag_says = "the types a stub declares agree with the header it wraps";
    ag_expects =
      "the provider's header signatures, for the function names the binding \
       also declares. A disagreeing return type or argument list is what the \
       C compiler would reject if it saw both";
    ag_rooted_in =
      rooted ~action:"build_binding_ocaml" ~tool:"the C compiler"
        ~artifact:"the stub's calls against the header's declarations"
        ~note:
          "the compiler's rule is that a call agrees with the declaration in \
           scope. It ran when the stub was compiled against some header; \
           this re-derives it from signature summaries, TEXTUALLY, for the \
           names both sides mention"
        ();
    (* PRE: the stub only compiles if the header agrees with it. *)
    ag_slot = before_binding;
    ag_fault_tag = "type_arity";
    ag_methods =
      [ checking_method ~name:"header_vs_stub_signature_summaries" ~kind:Compare
          ~reference:Peer_artifact
          (* TWO DIFFERENT NOES, and keeping them apart is the point
             (2026-09-14). "This mechanism has no typed boundary" is a
             fact about the mechanism and comes from the catalogue.
             "We have not written the extractor for this one" is a fact
             about CANARY, and saying so names a gap instead of
             implying the claim does not apply — a cext DOES call the C
             API and must match its declarations; nobody has written
             the scanner. *)
          ~applicable:(fun m l _ ->
            if not (exposes_typed_stub m) then
              Inapplicable
                "this mechanism declares its types as values rather than at a \
                 compiled boundary, so there are no stub signatures to read"
            else
              match l with
              | Canary_lang.OCaml -> Applicable
              | _ ->
                  Inapplicable
                    "no signature extractor for this language's stub surface \
                     yet — a gap in canary, not in the mechanism")
          ~firing:firing_default
          ~inputs:(fun { ac_mechanism = m; ac_lang = l; _ } ->
            match (l, not (exposes_typed_stub m)) with
            | Canary_lang.OCaml, false ->
                (* the header is the NATIVE side and language-neutral; the
                   stub surface is the MECHANISM's — [external] is how
                   cstubs spells the boundary — and says so there *)
                [ Typed_header [ "scan_sources/inspect_typed_header.json" ];
                  Canary_agreement_cstubs.typed_stub_surface ]
            | _ -> [])
          ~eval:signatures_eval ~impl:"signatures_eval"
          ~limits:
            "textual comparison of type SPELLINGS, not semantic type \
             equivalence, representation or ownership. Names on only one \
             side are skipped. The current extractor parses known C header \
             declarations and supplies fixed binding signatures where their \
             names occur in the binding source — general binding-signature \
             extraction is the next step."
          ~counterexamples:
            [ { fx_method = "header_vs_stub_signature_summaries";
                fx_inputs =
                  [ Typed_header [ "hdr.json" ];
                    Typed_binding_stub [ "stub.json" ] ];
                fx_bodies =
                  [ ("hdr.json",
                     {|{"kind": "typed_header", "path": "fx",
    "functions": {"tiny_sum": {"return": "int", "args": ["int", "int"]}}}|});
                    ("stub.json",
                     {|{"kind": "typed_stub_ocaml", "path": "fx",
    "functions": {"tiny_sum": {"return": "int", "args": ["int"]}}}|}) ];
                fx_outcome = "violated";
                fx_findings = [ "tiny_sum" ] };
              { fx_method = "header_vs_stub_signature_summaries";
                fx_inputs =
                  [ Typed_header [ "hdr.json" ];
                    Typed_binding_stub [ "agree.json" ] ];
                fx_bodies =
                  [ ("hdr.json",
                     {|{"kind": "typed_header", "path": "fx",
    "functions": {"tiny_sum": {"return": "int", "args": ["int", "int"]}}}|});
                    ("agree.json",
                     {|{"kind": "typed_stub_ocaml", "path": "fx",
    "functions": {"tiny_sum": {"return": "int", "args": ["int", "int"]}}}|}) ];
                fx_outcome = "holds";
                fx_findings = [] } ]
          () ] }

let checks : (agreement_id * agreement) list =
  [ (Signatures_agree, signatures_agree) ]
