(** Symbol agreements — what a library exports, against a declaration
    and against a consumer's requirements.

    TWO agreements, not one with two cells (2026-09-12). They were
    [symbol_exported/solo] and [symbol_exported/pair] under a single id,
    which meant one implementation status and one attribution covered
    two different claims with two different references. Splitting them
    is what makes "the declaration comparison has no production caller"
    a fact the registry can state.

    One module per family: it holds both agreements' claims, the
    evidence records it reads, the comparators, and the counterexamples
    that falsify them. It refers only to [Canary_agreement_common]. *)

open Base
open Canary_agreement_common

(* ── the evidence this family reads ── *)

type stub_inspect = {
  path : string;
  requires : string list;
}

type native_inspect = {
  path : string;
  symbols : string list;  (* defined exports, prefix-filtered if emitted that way *)
  total : int;
      (** how many symbols the library actually defines, BEFORE the
          prefix filter ([counts.total]).

          It exists because the field above is a subset and every
          evaluator here treated it as the whole truth (found
          2026-09-17). zlib records five prefixes and declares
          [zlibVersion], which matches none of them: the library exports
          it, the inspection omits it, and the comparison called that a
          VIOLATION. An absence in a filtered list is not evidence of
          absence, and this is the field that says so. *)
}

(** Is this summary's symbol list a proper subset of what the library
    defines? Then a name's absence from it proves nothing.

    [total = 0] means the summary predates the field or carries no
    counts; treat that as unfiltered rather than refusing to decide,
    since every fixture and every existing summary is in that state and
    reading them as "cannot tell" would silently retire the agreement. *)
let symbols_are_filtered (n : native_inspect) : bool =
  n.total > 0 && List.length n.symbols < n.total

let filtered_note (n : native_inspect) : string =
  Printf.sprintf
    "the library's inspection is PREFIX-FILTERED (%d of %d defined symbols      recorded), so a declared name missing from it may simply be outside the      filter — %s. Widen the project's inspect prefixes to cover what it      declares, or narrow the declaration"
    (List.length n.symbols) n.total n.path

let load_stub path =
  let j = load path in
  let kind = get_string j "kind" in
  if not (String.equal kind "c_stub") then
    Fmt.epr "compat: warning — expected kind=c_stub, got %s (%s)@." kind path;
  { path = get_string j "path"; requires = get_string_list j "requires" }

let load_native path =
  let j = load path in
  let kind = get_string j "kind" in
  if not (String.equal kind "native") then
    Fmt.epr "compat: warning — expected kind=native, got %s (%s)@." kind path;
  let symbols = get_string_list j "symbols" in
  if List.is_empty symbols then
    Fmt.epr "compat: warning — native summary has no 'symbols' field; was \
             it produced with --emit-symbols? (%s)@." path;
  let total =
    match Option.bind (field j "counts") ~f:(fun c -> field c "total") with
    | Some (`Int n) -> n
    | _ -> 0
  in
  { path = get_string j "path"; symbols; total }

(* Selected BY KIND: the same relative name means different artifacts
   in different projects (the framework writes its compiled-stub
   summary to inspect_stub.json and tiny writes its to inspect.json),
   so a candidate that exists but holds an OCaml surface summary is not
   this family's evidence. *)
let native_path ~resolve inputs =
  List.find_map inputs ~f:(function
    | Native_lib ps -> pick_existing_of_kind ~resolve ~kinds:[ "native" ] ps
    | _ -> None)

let stub_path ~resolve inputs =
  List.find_map inputs ~f:(function
    | C_stub ps -> pick_existing_of_kind ~resolve ~kinds:[ "c_stub" ] ps
    | _ -> None)

let declared_exports inputs =
  List.find_map inputs ~f:(function Declared_exports d -> Some d | _ -> None)

(* ── the comparators ── *)

type compat_result =
  | Compatible
  | Compatible_lag of { required : int; provided : int }
      (** inclusion holds, but the consumer's required set covers only a
          small fraction of the provider's surface — the POSSIBLY
          OUT-OF-DATE signal (2026-08-17, user): set-inclusion alone
          can't tell wrapping-a-subset (by design) from a stale binding
          (by accident), so this is a WARNING, never a failure. *)
  | Missing of { symbols : string list }
  | Unknown   (* one side lacks the data needed to decide *)

(** Set-inclusion: every C symbol the consumer requires must be defined
    by the provider.

    - [binding_stub]: consumer-side undefined refs, from the compiled
      stub archive ([inspect_binding.py --kind stub]) or from a cext
      [.so] reshaped to [c_stub] form.
    - [native_lib]: provider-side defined symbols, from
      [inspect_native.py --emit-symbols].

    [Unknown] when either side carries no symbol data — an empty
    [requires] is not an inclusion that holds vacuously, it is an
    inspection that told us nothing. *)
let check_c_compat ~(binding_stub : stub_inspect) ~(native_lib : native_inspect)
    : compat_result =
  if List.is_empty binding_stub.requires then Unknown
  else if List.is_empty native_lib.symbols then Unknown
  else
    let provided = Set.of_list (module String) native_lib.symbols in
    let missing = List.filter binding_stub.requires
        ~f:(fun s -> not (Set.mem provided s)) in
    if List.is_empty missing then
      (* the coverage note: a consumer covering < 10% of the provider's
         surface passes inclusion but may be OUT-OF-DATE — the warning
         the result carries (by design or by accident; can't tell). *)
      let required = List.length binding_stub.requires in
      let provided_n = List.length native_lib.symbols in
      if required * 10 < provided_n then
        Compatible_lag { required; provided = provided_n }
      else Compatible
    else Missing { symbols = missing }

(** The lag's CONCRETE witnesses (2026-08-17, user): one required symbol
    (the consumer's surface — IN) and one provided-but-unrequired symbol
    (the rest of the provider — OUT), so the warning can show "some are
    in and some are out" instead of bare counts. *)
let lag_examples ~(binding_stub : stub_inspect) ~(native_lib : native_inspect)
    : (string * string) option =
  match binding_stub.requires with
  | [] -> None
  | in_example :: _ ->
      let required_set = Set.of_list (module String) binding_stub.requires in
      List.find_map native_lib.symbols ~f:(fun s ->
          if Set.mem required_set s then None else Some (in_example, s))

(** Declared exports minus actual exports. The tools that produce the
    library are black boxes, so this does not trust an exit code: it
    reads the library and compares it with what the project said. *)
let check_declared_exports ~(declared : string list)
    ~(native_lib : native_inspect) : compat_result =
  if List.is_empty declared then Unknown
  else if List.is_empty native_lib.symbols then Unknown
  else
    let provided = Set.of_list (module String) native_lib.symbols in
    match List.filter declared ~f:(fun f -> not (Set.mem provided f)) with
    | [] -> Compatible
    | missing -> Missing { symbols = missing }

(* ── the evaluators ── *)

let declared_exports_eval ~resolve inputs : outcome =
  match declared_exports inputs with
  | None ->
      Unavailable
        (Missing_declaration
           "this project declares no c_api export list, so there is nothing \
            to hold the library's exports against. A project to-do, not a \
            gap in canary: set [native_api.stable_symbols] and this decides")
  | Some declared -> (
      match native_path ~resolve inputs with
      | None ->
          Unavailable
            (Missing_evidence "no native library inspection in this world")
      | Some p -> (
          let lib = load_native p in
          match check_declared_exports ~declared ~native_lib:lib with
          | Compatible -> Holds
          (* AN ABSENCE IN A FILTERED LIST IS NOT EVIDENCE OF ABSENCE
             (2026-09-17). Presence still proves presence, so [Holds]
             above is sound either way; a MISSING name is only a finding
             when the list it is missing from is complete. *)
          | Missing _ when symbols_are_filtered lib ->
              Inconclusive (filtered_note lib)
          | Missing { symbols } -> Violated symbols
          | Compatible_lag _ -> Holds
          | Unknown ->
              Inconclusive
                "the declaration or the export list is empty; nothing to \
                 compare (an empty declaration is not coverage)"))

let required_symbols_eval ~resolve inputs : outcome =
  match (stub_path ~resolve inputs, native_path ~resolve inputs) with
  | None, _ ->
      Unavailable (Missing_evidence "no compiled-stub inspection in this world")
  | _, None ->
      Unavailable
        (Missing_evidence "no native library inspection in this world")
  | Some s, Some l -> (
      let stub = load_stub s and lib = load_native l in
      match check_c_compat ~binding_stub:stub ~native_lib:lib with
      | Compatible | Compatible_lag _ -> Holds
      (* same exposure as the declaration comparison above: a required
         symbol outside the provider's inspect prefixes would read as
         missing from a library that exports it *)
      | Missing _ when symbols_are_filtered lib ->
          Inconclusive (filtered_note lib)
      | Missing { symbols } -> Violated symbols
      | Unknown ->
          Inconclusive
            "one side carries no symbol data (an empty requires/symbols set \
             decides nothing)")

(** The c1 input pair: the existing C_stub + Native_lib summaries among
    [inputs], loaded. [None] = either side missing. Kept for the
    on-demand [canary compat] report, which prints the loaded records
    rather than an outcome. *)
let c1_pair ~resolve (inputs : inspect_input list) :
    (stub_inspect * native_inspect) option =
  match (stub_path ~resolve inputs, native_path ~resolve inputs) with
  | Some s, Some l -> Some (load_stub s, load_native l)
  | _ -> None

(** The coverage NOTE (2026-08-17, user): when the check passes but the
    consumer's required set covers a small fraction of the provider's
    surface, warn POSSIBLY OUT-OF-DATE. A WARNING, never a failure, and
    deliberately NOT an outcome — it is a note about a [Holds], not a
    weaker verdict. *)
let lag_note ~resolve (inputs : inspect_input list) : string option =
  match c1_pair ~resolve inputs with
  | Some (stub, lib) -> (
      match check_c_compat ~binding_stub:stub ~native_lib:lib with
      | Compatible_lag { required; provided } ->
          let witness =
            match lag_examples ~binding_stub:stub ~native_lib:lib with
            | Some (in_use, unused) ->
                Printf.sprintf " (e.g. %s in use; %s in the unused remainder)"
                  in_use unused
            | None -> ""
          in
          Some
            (Printf.sprintf
               "required_symbols_exported: consumer requires %d of the \
                provider's %d symbols%s — POSSIBLY OUT-OF-DATE (a small \
                consumer surface may be by design or lag)"
               required provided witness)
      | Compatible | Missing _ | Unknown -> None)
  | None -> None

(* ── what each agreement hands the registry ── *)

let declared_symbols_exported : agreement =
  { ag_subject = Symbols;
    ag_claim = Structural;
    ag_basis = Project_declaration;
    ag_says =
      "every function the project declares in c_api is exported by the built \
       lib";
    ag_expects =
      "the project's declared c_api export set; a name in the declaration \
       that the built library does not export is the falsifier";
    ag_rooted_in =
      rooted ~action:"build_lib" ~tool:"compiler + linker"
        ~artifact:"the library's exported symbols"
        ~note:
          "the compiler and linker turned declarations into definitions and \
           exported them. The declaration this checks against is the \
           project's rather than the header's, so it recovers a WEAKER rule \
           than the compiler's own: it asks whether what the project said it \
           ships is there, not whether every declaration agreed with its \
           definition"
        ();
    (* POST: it validates what build_lib exported. *)
    ag_slot = at_lib Canary_basic.Build_lib Post;
    ag_fault_tag = "sym_missing";
    ag_methods =
      [ checking_method ~name:"declared_exports_vs_library" ~kind:Compare
          ~reference:Declared_facts
          ~firing:firing_lib_declaration
          ~inputs:(fun { ac_declared = d; _ } ->
            (* the declaration half comes from the project's own c_api,
               routed onto the context since 2026-09-14 — before that it
               reached no action and this comparison had no reference to
               hold the artifact against. The artifact half is the copy
               BUILD_LIB made, not the world's library: this is a
               post-check, and in an Installed world those differ. *)
            declared_exports_input d
            @ [ Native_lib (built_lib_evidence_paths "inspect.json") ])
          ~eval:declared_exports_eval ~impl:"declared_exports_eval"
          ~limits:
            "only declared names are covered; signatures, versions and \
             behaviour are not. A name present says nothing about what it \
             does."
          ~counterexamples:
            [ { fx_method = "declared_exports_vs_library";
                fx_inputs =
                  [ Declared_exports [ "tiny_sum"; "tiny_diff"; "tiny_offset" ];
                    Native_lib [ "lib.json" ] ];
                fx_bodies =
                  [ ("lib.json",
                     {|{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum", "tiny_diff"]}|}) ];
                fx_outcome = "violated";
                fx_findings = [ "tiny_offset" ] };
              (* the missing-declaration case: the library is there and
                 the declaration is not, which must NOT read as a pass *)
              { fx_method = "declared_exports_vs_library";
                fx_inputs = [ Native_lib [ "lib.json" ] ];
                fx_bodies =
                  [ ("lib.json",
                     {|{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum", "tiny_diff"]}|}) ];
                (* the library is readable and lists its exports; the
                   project declared no c_api to hold them against — a
                   spec gap, and now a distinct word from a missing
                   inspection (2026-09-15) *)
                fx_outcome = "undeclared";
                fx_findings = [] };
              (* A FILTERED INSPECTION CANNOT CONVICT (2026-09-17). Same
                 shape as the first fixture — a declared name absent from
                 the recorded list — but the summary says it recorded 2
                 of 40 defined symbols, so the absence is the filter's
                 doing and not the library's. This reported `violated`
                 until the day it was written, on zlib, about a symbol
                 `nm -D` shows the library exporting. *)
              { fx_method = "declared_exports_vs_library";
                fx_inputs =
                  [ Declared_exports [ "tiny_sum"; "tiny_diff"; "tiny_offset" ];
                    Native_lib [ "lib.json" ] ];
                fx_bodies =
                  [ ("lib.json",
                     {|{"kind": "native", "path": "fx",
    "counts": {"total": 40},
    "symbols": ["tiny_sum", "tiny_diff"]}|}) ];
                fx_outcome = "inconclusive";
                fx_findings = [] } ]
          () ] }

let required_symbols_exported : agreement =
  { ag_subject = Symbols;
    ag_claim = Structural;
    ag_basis = Toolchain_rule;
    ag_says =
      "every symbol the binding's stub references is exported by the lib";
    ag_expects =
      "the consumer's own recorded requirements: the undefined references in \
       its compiled stub. A required symbol the provider does not export is \
       the falsifier, and the linker or loader would say the same";
    ag_rooted_in =
      rooted ~action:"build_binding_ocaml" ~tool:"linker"
        ~artifact:
          "the stub archive's undefined references. The link that made \
           them ran in whatever world built the consumer, which this \
           graph need not contain — so where the binding is fetched \
           rather than built, the check falls to the probe"
        ~note:
          "the linker's rule is that every referenced symbol has a \
           definition. It ran once, when the binding was built against some \
           library; this re-derives it, for names, against whichever library \
           THIS world actually holds"
        ();
    (* PRE: the link can only succeed if the lib defines them. Falls
       through to the probe where the binding is fetched rather than
       built, which is every Pattern A project and sqlite. *)
    ag_slot = before_binding;
    ag_fault_tag = "sym_missing";
    ag_methods =
      [ checking_method ~name:"stub_requirements_vs_library_exports"
          ~kind:Compare ~reference:Peer_artifact
          (* asks whether a STUB IS COMPILED, which is the actual
             question — not whether the discipline is dynamic, which
             happened to agree for every mechanism wired so far *)
          ~applicable:(fun m _ _ ->
            if compiles_a_stub m then Applicable
            else
              Inapplicable
                "this binding mechanism compiles no stub archive, so it \
                 records no requirement set; the probe's own failure is the \
                 evidence")
          ~firing:firing_default
          ~inputs:(fun { ac_mechanism = m; ac_lang = l; ac_world = w; _ } ->
            if not (compiles_a_stub m) then []
            else
              let tag = binding_evidence_tag w l in
              (* BOTH SPELLINGS, as for the user surface (2026-09-12).
                 The framework's [auto_binding_summaries] writes a
                 compiled-stub summary to [inspect_stub.json]; tiny
                 writes its stub to [inspect.json] and keeps
                 [inspect_mli.json] for the surface. Listing both is
                 safe because the reader selects on the declared
                 [kind], so a surface summary sitting at one of these
                 paths is simply not this method's evidence. *)
              [ C_stub [ tag ^ "/inspect_stub.json"; tag ^ "/inspect.json" ];
                Native_lib (lib_evidence_paths w "inspect.json") ])
          ~eval:required_symbols_eval ~impl:"required_symbols_eval"
          ~limits:
            "set inclusion only: it does not check signatures, symbol \
             versions, or which definition the loader will actually bind. \
             Inclusion over a very small requirement set may also mean the \
             binding is stale rather than deliberately narrow."
          ~counterexamples:
            [ { fx_method = "stub_requirements_vs_library_exports";
                fx_inputs = [ C_stub [ "stub.json" ]; Native_lib [ "lib.json" ] ];
                fx_bodies =
                  [ ("stub.json",
                     {|{"kind": "c_stub", "path": "fx",
    "requires": ["tiny_sum", "tiny_offset"]}|});
                    ("lib.json",
                     {|{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum", "tiny_diff"]}|}) ];
                fx_outcome = "violated";
                fx_findings = [ "tiny_offset" ] };
              (* requirements met — the outcome a substring list could
                 never express *)
              { fx_method = "stub_requirements_vs_library_exports";
                fx_inputs = [ C_stub [ "stub.json" ]; Native_lib [ "lib.json" ] ];
                fx_bodies =
                  [ ("stub.json",
                     {|{"kind": "c_stub", "path": "fx",
    "requires": ["tiny_sum", "tiny_diff"]}|});
                    ("lib.json",
                     {|{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum", "tiny_diff"]}|}) ];
                fx_outcome = "holds";
                fx_findings = [] };
              (* evidence absent: the library was never inspected *)
              { fx_method = "stub_requirements_vs_library_exports";
                fx_inputs =
                  [ C_stub [ "stub.json" ]; Native_lib [ "absent.json" ] ];
                fx_bodies =
                  [ ("stub.json",
                     {|{"kind": "c_stub", "path": "fx",
    "requires": ["tiny_sum"]}|}) ];
                fx_outcome = "unavailable";
                fx_findings = [] } ]
          () ] }

(** Every agreement this family owns. The registry gathers these; the
    module pattern pin keys on the binding's presence. *)
let checks : (agreement_id * agreement) list =
  [ (Declared_symbols_exported, declared_symbols_exported);
    (Required_symbols_exported, required_symbols_exported) ]
