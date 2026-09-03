(** [Canary_agreement] — pure surface-theory comparators (surface/).

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

    The companion {!Canary_agreement_run} module (same dir) carries the
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
    declaration side and as [typed_input] (single
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
    - [Versioned_exports p] ↔ provider's {i n4}'s [versioned_exports].
                              Feeds {i c5 cmp_sym_version} (L1b).
    - [Versioned_req p]     ↔ consumer's [versioned_req]. Same.
    - [Abi_surface p]       ↔ {i n4}'s ELF SONAME/NEEDED/RPATH. Feeds
                              {i c4 cmp_abi} (L4). *)
type inspect_input =
  | C_stub of string list
  | Native_lib of string list
  | Ocaml_mli of string list
  | Python_attrs of string list
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

(* the c1 comparator and [compat_result] moved to [Canary_chk_symbols];
   the c4/c5 comparators and their result types moved to
   [Canary_chk_identity] (2026-09-02, user: "shall we put the checking
   into a corresponding canary_chk_ file rather than in this file") —
   a family's check, its result shape and its predict now sit together *)

(* the c6 comparator and [type_result] moved to [Canary_chk_types];
   the c7/c8 comparators and their result types to
   [Canary_chk_behaviour] *)


(* [check_c_compat] and [lag_examples] moved to [Canary_chk_symbols],
   with [compat_result] — see the note at that type's old site *)

(* ── Agreement registry vocabulary (Phase 12, 2026-06-02) ─────────────
   The c1..c8 surface-theory agreements as a registered collection. Each
   entry pairs an agreement id with its status, the action-graph layer it
   sits in (L0/L1b/L2/L3/L4), an enable flag, and the predicate that
   turns [inspect_input list] into expected failure substrings.

   The rows and the dispatch live in {!Canary_agreement_registry}; this
   file defines only the types, so they are available to every check
   family below the registry. That is also why the CATEGORY lives here
   (2026-09-02, user: "why do we need a check_cat file separately? can
   we merge it into registry?") — it cannot go in the registry, which
   reads each family's [cat] and would then depend on the modules that
   depend on it. This file is the one place below all of them. *)

(** The check CATEGORY — descriptive.

    A category says what kind of claim a check makes. Nothing dispatches
    on it: it groups the catalogue, the checking index and the doc, and
    it is deliberately allowed to refine as checks accumulate, because a
    descriptive type costs nothing to sharpen.

    It is NOT the check's signature. Checks keep whatever signature suits
    them — a symbol comparison and a repo-pin query have no reason to
    agree — and the caller supplies the inputs and decides where to dump
    the evidence on failure. *)
type cat =
  | Symbols   of [ `Exported | `Required | `Versioned | `Orphan ]
  | Api       of [ `Present | `Complete | `Repacked ]
  | Identity  of [ `Soname | `Version_node ]
  | Types     of [ `Signature | `Arity ]
  | Behaviour of [ `Trace | `Differential ]
  | Repo      of [ `Pin | `Freshness | `Contents ]
  | Staging   of [ `Completeness | `Parity | `Portability ]
  | Action_succeeded
      (** the weakest claim available: the tool did not error, and its
          declared output appeared. No artifact is read — which is why
          §1.1 says to inspect the product wherever one exists. Free at
          every action, and it is what a later blame step has to start
          from. *)
  | Meta      of [ `Spec | `Framework ]
      (** about canary's own declarations rather than the tools' *)

let string_of_cat = function
  | Symbols `Exported -> "symbols/exported"
  | Symbols `Required -> "symbols/required"
  | Symbols `Versioned -> "symbols/versioned"
  | Symbols `Orphan -> "symbols/orphan"
  | Api `Present -> "api/present"
  | Api `Complete -> "api/complete"
  | Api `Repacked -> "api/repacked"
  | Identity `Soname -> "identity/soname"
  | Identity `Version_node -> "identity/version-node"
  | Types `Signature -> "types/signature"
  | Types `Arity -> "types/arity"
  | Behaviour `Trace -> "behaviour/trace"
  | Behaviour `Differential -> "behaviour/differential"
  | Repo `Pin -> "repo/pin"
  | Repo `Freshness -> "repo/freshness"
  | Repo `Contents -> "repo/contents"
  | Staging `Completeness -> "staging/completeness"
  | Staging `Parity -> "staging/parity"
  | Staging `Portability -> "staging/portability"
  | Action_succeeded -> "action-succeeded"
  | Meta `Spec -> "meta/spec"
  | Meta `Framework -> "meta/framework"

(** Is this agreement a CONVENTION — true of every project using the
    toolchain, declared by nobody (a findlib META naming an archive that
    exists, a wheel's EXT_SUFFIX matching its interpreter)? A marker, not
    a separate source: conventions are agreements that happen to be
    obligatory and project-independent, which makes them the richest
    place to look for new checks. *)
type standing = Declared | Convention

(** The eight contracts of surface theory. See
    [doc/canary/research/surface_draft/surface.md] Part C for definitions. *)
type agreement_id = C1 | C2 | C3 | C4 | C5 | C6 | C7 | C8

let string_of_agreement_id = function
  | C1 -> "c1" | C2 -> "c2" | C3 -> "c3" | C4 -> "c4"
  | C5 -> "c5" | C6 -> "c6" | C7 -> "c7" | C8 -> "c8"

(** Parse a string like ["c5"] back into a contract id. Accepts
    upper- or lower-case prefix; rejects anything else. Used by the
    CLI [--disable-contract] flag parser and by deserialisers. *)
let agreement_id_of_string s =
  match String.lowercase s with
  | "c1" -> Some C1 | "c2" -> Some C2 | "c3" -> Some C3 | "c4" -> Some C4
  | "c5" -> Some C5 | "c6" -> Some C6 | "c7" -> Some C7 | "c8" -> Some C8
  | _ -> None

(** Parse a comma-separated list like ["c4,c5"]. Silently drops
    anything that doesn't parse; the caller can re-validate the input
    if it cares about reporting unknown ids. *)
let agreement_ids_of_csv s =
  s
  |> String.split ~on:','
  |> List.filter_map ~f:(fun part ->
       let part = String.strip part in
       if String.is_empty part then None else agreement_id_of_string part)

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
type agreement_status =
  | Wired
  | Inspect_only
  | Comparator_only
  | Blocked of agreement_id list
  | Stubbed

(** Human label for a wiring status (the runner's [agreement_skipped]
    events name WHY a registry-disabled contract didn't fire). *)
let string_of_agreement_status = function
  | Wired -> "wired"
  | Inspect_only -> "inspect-only"
  | Comparator_only -> "comparator-only"
  | Blocked [] -> "blocked"
  | Blocked deps ->
      "blocked on "
      ^ String.concat ~sep:"," (List.map deps ~f:string_of_agreement_id)
  | Stubbed -> "stubbed"

(** One entry in the contract registry. [predict] consumes the same
    [inspect_input list + ~resolve] that {!Canary_agreement_run}'s top-
    level dispatcher does, and returns the substrings this contract
    predicts the probe.log will contain on failure. *)
type agreement_check = {
  id        : agreement_id;
  name      : string;        (* "cmp_symbol", "cmp_api_completeness", … *)
  layer     : string;        (* "L0", "L1b", "L3", "L4", … *)
  status    : agreement_status;
  enabled   : bool;
  predict   : resolve:(string -> string) -> inspect_input list -> string list;
}

(* ── loader support shared by the check families (2026-09-02) ──
   These sit with [load_stub] / [load_native] because that is what they
   are: reading an inspect JSON, and expanding a dotted name into the
   forms a log might show. They were briefly in a module of their own;
   "evidence" turned out not to be a category. *)

let pick_existing ~resolve paths =
  List.find_map paths ~f:(fun rel ->
    let abs = resolve rel in
    if Stdlib.Sys.file_exists abs then Some abs else None)

let load_watchlist_missing path =
  if not (Stdlib.Sys.file_exists path) then []
  else
    let j = Yojson.Basic.from_file path in
    match field j "watchlist" with
    | Some wl -> get_string_list wl "missing"
    | None -> []

let name_variants e =
  let parts = String.split e ~on:'.' in
  let suffix_no_top = match parts with
    | _ :: (_ :: _ as rest) -> [ String.concat ~sep:"." rest ]
    | _ -> []
  in
  let last = match List.last parts with Some l -> [ l ] | None -> [] in
  e :: suffix_no_top @ last
