(** [Canary_compat] — pure surface-theory comparators (surface/).

    The theoretical half of the compat machinery: input types and the
    c1..c8 comparator functions. Pure; the only I/O is reading a JSON
    file from a path. Holds:

    - Input types: [stub_inspect], [native_inspect]
    - Comparator result types: [compat_result] (c1), [abi_result] (c4),
      [sym_version_result] (c5), [type_result] (c6), [repack_result] (c7),
      [faithfulness_result] (c8)
    - JSON loaders: [load], [field], [get_string], [get_string_list],
      [load_stub], [load_native]
    - Pure comparator functions: [check_c_compat], [check_abi],
      [check_sym_version], [check_type], [check_api_repack],
      [check_api_faithfulness]

    The companion {!Canary_compat_run} module (same dir) carries the
    action-graph integration half: [predicted_contains_any_v2] (the
    ADT-to-substring derivation that consumes [inspect_input] declared
    above) + the CLI commands [run] / [run_for_project] /
    [verify_for_project] + cached-summary lookup helpers
    ([find_*_inspect], [resolve_variant]). *)

open Base

(* Static compatibility check between a binding's stub archive (consumer side:
   "what C symbols this binding requires from the native lib") and a native
   library's defined-symbols summary (provider side: "what this .so exports").

   Inputs are summary.json files produced by inspect_binding.py --kind stub
   and inspect_native.py --emit-symbols, respectively. Output is a verdict
   on `requires ⊆ provides`.

   See doc/canary/design/api_surface.md §13 for the design.
   The OCaml-level half is already covered by the mli summary's watchlist
   (e.g. Llvm.Opcode.UncondBr present/missing). Together they form the
   set-inclusion necessary-condition layer (L0/L1) of the compatibility
   lattice from api_surface.md §15. *)

(* ── Summary loaders ── *)

let load path : Yojson.Basic.t =
  if not (Stdlib.Sys.file_exists path) then (
    Fmt.epr "compat: %s not found@." path;
    Stdlib.exit 2);
  Yojson.Basic.from_file path

let field (j : Yojson.Basic.t) name =
  match j with
  | `Assoc fields -> List.Assoc.find fields ~equal:String.equal name
  | _ -> None

let get_string j name =
  match field j name with Some (`String s) -> s | _ -> ""

let get_string_list j name =
  match field j name with
  | Some (`List xs) ->
      List.filter_map xs ~f:(function `String s -> Some s | _ -> None)
  | _ -> []

(* ── Typed views ── *)

(** [inspect_input] — what inspector JSON kind feeds a comparator
    prediction. Carries a {i list} of candidate paths (different action
    paths in the graph write the same logical artifact to different
    relative locations — [pack_binding_ocaml/inspect_stub.json] vs.
    [fetch_binding_ocaml/inspect_stub.json] for OCaml stub, for example).
    The runner picks the first existing path via [~resolve].

    Unified on 2026-06-01 (Phase 4): previously this type lived twice,
    as [Canary.compat_inspect_input] (paths : string list) on the
    declaration side and as [Canary_compat_run.typed_input] (single
    string) after resolution, with a manual 20-line translation in
    [Canary_action] and [Canary_gh]. Constructors map to surface
    roles:

    - [C_stub p]            ↔ {i bo7 compiled_binding_ocaml.stub-a}.
                              Feeds {i c1 cmp_symbol}.
    - [Native_lib p]        ↔ {i n4 lib_native.so}. Feeds {i c1 cmp_symbol}
                              and {i c4 cmp_abi} predictions.
    - [Ocaml_mli p]         ↔ {i bo4 user_binding_ocaml.mli}. Feeds the
                              {i c2 cmp_api_completeness} watchlist check.
    - [Python_attrs p]      ↔ {i bpe2 user_binding_cext.py} or
                              {i bpc2 user_binding_ctypes.py}. Same role
                              as [Ocaml_mli] for the Python flavour.
    - [Versioned_symbols p] ↔ {i n4}'s [versioned_req] /
                              [versioned_exports]. Feeds {i c5
                              cmp_sym_version} (L1b).
    - [Abi_surface p]       ↔ {i n4}'s ELF SONAME/NEEDED/RPATH. Feeds
                              {i c4 cmp_abi} (L4). *)
type inspect_input =
  | C_stub of string list
  | Native_lib of string list
  | Ocaml_mli of string list
  | Python_attrs of string list
  | Versioned_symbols of string list
      (** Deprecated single-side input for c5 — kept for callers that
          read `versioned_req` from one JSON without diffing against a
          provider. New variants should use
          [Versioned_exports] + [Versioned_req] instead. *)
  | Versioned_exports of string list  (** provider side, n4's elf.versioned_exports *)
  | Versioned_req of string list      (** consumer side, e.g. cext's elf.versioned_req *)
  | Abi_surface of string list
  (* Typed-signature inputs for c6 / c7 / c8.
     Producer side ([Typed_header]) and consumer sides
     ([Typed_binding_stub], [Typed_binding_user]) all carry the same
     JSON shape — only the layer differs. See
     [canary/scripts/inspect_tiny_typed.py] for the (trivial-grep)
     inspector producing them; replace with real AST inspectors when
     they land. *)
  | Typed_header of string list         (* n3 — provider C sigs *)
  | Typed_binding_stub of string list   (* bo1/bpe1 — consumer C sigs *)
  | Typed_binding_user of string list   (* bo4/bpe2 — consumer language sigs *)

type stub_inspect = {
  path : string;
  requires : string list;
}

type native_inspect = {
  path : string;
  symbols : string list;  (* defined exports, prefix-filtered if emitted that way *)
}

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
  { path = get_string j "path"; symbols }

(** ELF surface view of an inspect JSON — what {!check_abi} needs.
    The producing inspector ([inspect_native.py] for the lib;
    [inspect_binding.py --kind stub] for shared-lib consumers) emits an
    [elf] sub-object with [soname] (string or null) and [needed] (list
    of strings). Either may be empty/None on archives or platforms
    without readelf. *)
type abi_surface_inspect = {
  path : string;
  soname : string option;
  needed : string list;
}

let load_abi_surface path =
  let j = load path in
  let elf = field j "elf" in
  let soname =
    match Option.bind elf ~f:(fun e -> field e "soname") with
    | Some (`String s) when not (String.is_empty s) -> Some s
    | _ -> None in
  let needed =
    match Option.bind elf ~f:(fun e -> field e "needed") with
    | Some (`List xs) ->
        List.filter_map xs ~f:(function `String s -> Some s | _ -> None)
    | _ -> [] in
  { path = get_string j "path"; soname; needed }

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

(** Versioned-symbol view of an inspect JSON. Produced by
    [inspect_native.py] (which reads [@@VER] / [@VER] suffixes from
    [nm -D]); fields are non-empty when the ELF artifact carries
    GNU symbol versioning.
    - [exports] map: defined symbol → exported version tag (provider
      side, populated for libs built with a version script).
    - [req_counts] map: required version tag → reference count
      (consumer side, populated for binaries linked against a
      versioned provider). *)
type versioned_symbols_inspect = {
  path : string;
  exports : (string * string) list;
  req_counts : (string * int) list;
}

let load_versioned_symbols path : versioned_symbols_inspect =
  let j = load path in
  let exports =
    match field j "versioned_exports" with
    | Some (`Assoc entries) ->
        List.filter_map entries ~f:(fun (sym, v) ->
          match v with `String ver -> Some (sym, ver) | _ -> None)
    | _ -> [] in
  let req_counts =
    match field j "versioned_req" with
    | Some (`Assoc entries) ->
        List.filter_map entries ~f:(fun (ver, v) ->
          match v with `Int n -> Some (ver, n) | _ -> None)
    | _ -> [] in
  { path = get_string j "path"; exports; req_counts }

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

(* ── Cross-check ── *)

type compat_result =
  | Compatible
  | Missing of { symbols : string list }
  | Unknown   (* one side lacks the data needed to decide *)

(** [c4 cmp_abi] result type. Distinct from [compat_result] because the
    failure shape differs — mismatched SONAME (single name we expected)
    rather than missing symbols (a set). *)
type abi_result =
  | Abi_compatible
  | Abi_mismatch of { expected_soname : string; consumer_needed : string list }
  | Abi_unknown

(** [c4 cmp_abi] implementation. Provider exports a SONAME; consumer has
    a NEEDED list. Compatible iff [consumer_needed] contains
    [provider_soname].

    Inputs in tiny's vocabulary:
    - [provider_soname] from {i n4 lib_native.so}'s [elf.soname] field
      (produced by [inspect_native.py] + [readelf -d]).
    - [consumer_needed] from {i bpe3 compiled_binding_cext.so}'s
      [elf.needed] field (same script, different artifact). OCaml
      bindings don't surface NEEDED on their [.cmxa] / [.stub-a] — it
      lives on the final linked exe — so [check_abi] only handles the
      cext (and, generally, any [.so]-shaped consumer artifact) for
      now; OCaml-side ABI checks would need an inspect of the linked
      probe exe.

    Catches tiny scenario {i e2 abi_soname_bump}: provider's SONAME
    flips libtiny.so.1 → libtiny.so.2; consumer's NEEDED still lists
    libtiny.so.1. {check_abi} returns [Abi_mismatch] — at static check
    time, before the OS dynamic loader fails the load.

    Returns:
    - [Abi_compatible] — [provider_soname] ∈ [consumer_needed]
    - [Abi_mismatch] — provider exports a SONAME the consumer doesn't
      reference (or, by symmetry, the consumer requires a SONAME the
      provider doesn't export). The [consumer_needed] list is carried
      forward for diagnostic strings.
    - [Abi_unknown] — one side lacks the data. *)
let check_abi ~(provider_soname : string option) ~(consumer_needed : string list)
    : abi_result =
  match provider_soname with
  | None -> Abi_unknown
  | Some sn ->
      if List.is_empty consumer_needed then Abi_unknown
      else if List.mem consumer_needed sn ~equal:String.equal then Abi_compatible
      else Abi_mismatch { expected_soname = sn; consumer_needed }


(** [c5 cmp_sym_version] result type. The "missing versions" failure
    shape carries the version tags the consumer required that the
    provider doesn't export — typically [@@GLIBC_2.31] when running on
    an older glibc, or the deferred tiny scenario e9
    [symbol_version_floor]'s [TINY_FUTURE_99.0]. *)
type sym_version_result =
  | Sym_version_compatible
  | Sym_version_missing of { missing_versions : string list }
  | Sym_version_unknown

(** [c5 cmp_sym_version] implementation. Set-inclusion check on version
    tags: every version the consumer requires must be exported by the
    provider.

    Inputs from cached JSON ([inspect_native.py] emits both):
    - [provider_versioned_exports]: list of [(symbol, version)] pairs
      drawn from {i n4}'s [versioned_exports] field (defined symbols
      carrying [@@VER] suffixes, e.g. [malloc@@GLIBC_2.31]).
    - [consumer_required_versions]: list of version tags drawn from
      consumer-side [versioned_req] field keys (e.g.
      [{"GLIBC_2.31": 3, "GLIBC_2.17": 5}] → [["GLIBC_2.31"; "GLIBC_2.17"]]).

    Catches the deferred tiny scenario e9 [symbol_version_floor]
    and, end-to-end, the §4.2 glibc/musl case: binary built on
    Ubuntu 22.04 has [malloc@GLIBC_2.31] in its NEEDED references;
    running on a glibc-2.17 host the system libc only exports
    [@@GLIBC_2.17] — the version tag [GLIBC_2.31] is missing from the
    provider's exported set, hence [Sym_version_missing].

    Today's check is exact-match on the version tag string. A future
    refinement could parse version components and do floor-comparison
    (provider must export ≥ consumer's required version). Exact-match
    is the common case for [@@GLIBC_X.YY] annotations because the
    linker normally records the specific version it was built against.

    Returns:
    - [Sym_version_compatible] — every consumer-required version tag
      ∈ provider's exported version set.
    - [Sym_version_missing] — consumer requires tags the provider
      doesn't export. The list is the missing tags.
    - [Sym_version_unknown] — one side lacks the data (empty
      versioned_req on the consumer, or empty versioned_exports on the
      provider when we'd otherwise need to compare). *)
let check_sym_version
    ~(provider_versioned_exports : (string * string) list)
    ~(consumer_required_versions : string list)
    : sym_version_result =
  if List.is_empty consumer_required_versions then Sym_version_unknown
  else if List.is_empty provider_versioned_exports then Sym_version_unknown
  else
    let provider_set =
      List.map provider_versioned_exports ~f:snd
      |> Set.of_list (module String) in
    let missing =
      List.filter consumer_required_versions ~f:(fun v ->
          not (Set.mem provider_set v))
      |> List.dedup_and_sort ~compare:String.compare in
    if List.is_empty missing then Sym_version_compatible
    else Sym_version_missing { missing_versions = missing }


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


(** [c8 cmp_api_faithfulness] result type. The derived contract:
    "user-facing API is faithful to the underlying C API." By the
    decomposition in surface_theory.md §2.5:

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
    | Compatible | Unknown -> None
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


(** [c1 cmp_symbol] implementation. Set-inclusion check: every C symbol the
    consumer requires must be defined by the provider.

    {!check_c_compat} takes:
    - [binding_stub]: consumer-side undefined refs, from one of
      {ul
        {- {i bo7 compiled_binding_ocaml.stub-a} via
           [inspect_binding.py --kind stub] on [libtiny_stubs.a], or}
        {- {i bpe3 compiled_binding_cext.so} via [nm -u] on the cext [.so]
           reshaped to [c_stub] form (run.sh handles the coercion).}
      }
    - [native_lib]: provider-side defined symbols, from {i n4 lib_native.so}
      via [inspect_native.py] on the [.so].

    Returns:
    - [Compatible] — every required symbol present.
    - [Missing { symbols }] — at least one required symbol absent.
    - [Unknown] — one side has no symbol data (treat as inconclusive). *)
let check_c_compat ~(binding_stub : stub_inspect) ~(native_lib : native_inspect)
    : compat_result =
  if List.is_empty binding_stub.requires then Unknown
  else if List.is_empty native_lib.symbols then Unknown
  else
    let provided = Set.of_list (module String) native_lib.symbols in
    let missing = List.filter binding_stub.requires
        ~f:(fun s -> not (Set.mem provided s)) in
    if List.is_empty missing then Compatible
    else Missing { symbols = missing }

(* ── Contract registry vocabulary (Phase 12, 2026-06-02) ──────────────
   The c1..c8 surface-theory contracts as a registered collection. Each
   entry pairs a contract id with its status, the action-graph layer it
   sits in (L0/L1b/L2/L3/L4), an enable flag, and the predicate that
   turns [inspect_input list] into expected failure substrings.

   The concrete predicate implementations + registered list live in
   {!Canary_compat_run} (which has the dispatch entry
   [predicted_contains_any_v2]). This file defines only the types so
   they're available to anyone consuming the theory layer. *)

(** The eight contracts of surface theory. See
    [doc/canary/research/surface_theory.md] §2.4 for definitions. *)
type contract_id = C1 | C2 | C3 | C4 | C5 | C6 | C7 | C8

let string_of_contract_id = function
  | C1 -> "c1" | C2 -> "c2" | C3 -> "c3" | C4 -> "c4"
  | C5 -> "c5" | C6 -> "c6" | C7 -> "c7" | C8 -> "c8"

(** Parse a string like ["c5"] back into a contract id. Accepts
    upper- or lower-case prefix; rejects anything else. Used by the
    CLI [--disable-contract] flag parser and by deserialisers. *)
let contract_id_of_string s =
  match String.lowercase s with
  | "c1" -> Some C1 | "c2" -> Some C2 | "c3" -> Some C3 | "c4" -> Some C4
  | "c5" -> Some C5 | "c6" -> Some C6 | "c7" -> Some C7 | "c8" -> Some C8
  | _ -> None

(** Parse a comma-separated list like ["c4,c5"]. Silently drops
    anything that doesn't parse; the caller can re-validate the input
    if it cares about reporting unknown ids. *)
let contract_ids_of_csv s =
  s
  |> String.split ~on:','
  |> List.filter_map ~f:(fun part ->
       let part = String.strip part in
       if String.is_empty part then None else contract_id_of_string part)

(** Wiring status of a contract within canary's action graph.

    - [Wired] — full pipeline: inspect → predict → check, exercised by
      real projects.
    - [Inspect_only] — JSON output ready; the predict step reads it
      but no comparator runs (currently true of c5).
    - [Comparator_only] — pure [check_*] function exists in this file
      but isn't driven from the action graph.
    - [Blocked deps] — depends on these contracts being implemented
      first (e.g. c8 ⇐ [c6; c7]).
    - [Stubbed] — placeholder; the predict closure returns []. *)
type contract_status =
  | Wired
  | Inspect_only
  | Comparator_only
  | Blocked of contract_id list
  | Stubbed

(** One entry in the contract registry. [predict] consumes the same
    [inspect_input list + ~resolve] that {!Canary_compat_run}'s top-
    level dispatcher does, and returns the substrings this contract
    predicts the probe.log will contain on failure. *)
type contract_check = {
  id        : contract_id;
  name      : string;        (* "cmp_symbol", "cmp_api_completeness", … *)
  layer     : string;        (* "L0", "L1b", "L3", "L4", … *)
  status    : contract_status;
  enabled   : bool;
  predict   : resolve:(string -> string) -> inspect_input list -> string list;
}
