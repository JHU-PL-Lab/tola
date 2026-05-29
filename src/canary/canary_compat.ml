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

(* ── Reporting ── *)

let print_result ~(stub : stub_inspect) ~(lib : native_inspect) result =
  Fmt.pr "stub:     %s (%d required symbols)@."
    stub.path (List.length stub.requires);
  Fmt.pr "lib:      %s (%d defined symbols)@.@."
    lib.path (List.length lib.symbols);
  match result with
  | Compatible ->
      Fmt.pr "PREDICTION: COMPATIBLE — every required symbol is provided.@."
  | Missing { symbols } ->
      Fmt.pr "PREDICTION: INCOMPATIBLE — %d required symbol(s) missing:@."
        (List.length symbols);
      List.iter symbols ~f:(fun s -> Fmt.pr "  - %s@." s)
  | Unknown ->
      Fmt.pr "PREDICTION: UNKNOWN — one side has no usable symbol data.@.";
      Fmt.pr "  stub.requires: %d, lib.symbols: %d@."
        (List.length stub.requires) (List.length lib.symbols)

let run ~stub_path ~lib_path =
  let stub = load_stub stub_path in
  let lib = load_native lib_path in
  let result = check_c_compat ~binding_stub:stub ~native_lib:lib in
  print_result ~stub ~lib result;
  match result with
  | Compatible | Unknown -> 0
  | Missing _ -> 1

(* ── Convenience: locate cached summaries for a (project, variant) pair ── *)

(* v3 layout: projects/{project}/{step_dir}/file_{variant_id}.ext
   step_dir = Canary_step_key.step_dir_of_tag (e.g. "pack_binding/ocaml").
   variant_id is a filename suffix, not a subdir.
   For single-variant projects (variant_id = ""), filenames have no suffix.

   Resolve a variant arg to (project_dir, resolved_variant_id).
   Expands prefix matches: "dev" → "dev_ab43cb8" (most-recent by mtime)
   by scanning for variant-suffixed summary files in known step dirs.
   Returns None only when project_dir does not exist. *)
let resolve_variant ~root ~project variant =
  let project_dir = [%string "%{root}/_out/canary/projects/%{project}"] in
  if not (Stdlib.Sys.file_exists project_dir && Stdlib.Sys.is_directory project_dir)
  then None
  else if String.is_empty variant then
    Some (project_dir, "")
  else begin
    let find_variant_in_step step_dir_name =
      let step_dir = [%string "%{project_dir}/%{step_dir_name}"] in
      if not (Stdlib.Sys.file_exists step_dir && Stdlib.Sys.is_directory step_dir)
      then None
      else begin
        let exact_file = [%string "summary_%{variant}.json"] in
        if Stdlib.Sys.file_exists [%string "%{step_dir}/%{exact_file}"] then
          Some variant
        else begin
          let prefix = [%string "summary_%{variant}_"] in
          let candidates =
            Stdlib.Sys.readdir step_dir
            |> Array.to_list
            |> List.filter_map ~f:(fun f ->
                if String.is_prefix f ~prefix && String.is_suffix f ~suffix:".json" then
                  let tail = String.chop_prefix_exn f ~prefix in
                  let id_part = String.chop_suffix_exn tail ~suffix:".json" in
                  Some ([%string "%{step_dir}/%{f}"], [%string "%{variant}_%{id_part}"])
                else None)
            |> List.filter ~f:(fun (p, _) -> Stdlib.Sys.file_exists p)
          in
          match candidates with
          | [] -> None
          | xs ->
              let with_mtime = List.map xs ~f:(fun (p, d) ->
                  ((Unix.stat p).st_mtime, d))
              in
              let sorted = List.sort with_mtime
                  ~compare:(fun (a, _) (b, _) -> Float.compare b a) in
              Some (snd (List.hd_exn sorted))
        end
      end
    in
    let step_candidates = [
      "probe_lib"; "pack_binding/ocaml"; "fetch_binding/ocaml";
      "fetch_binding/python"; "probe_binding/ocaml"; "probe_binding/python";
    ] in
    let resolved = List.find_map step_candidates ~f:find_variant_in_step in
    Some (project_dir, Option.value resolved ~default:variant)
  end

(* Build a step-output path in the v3 layout.
   step_dir_of_tag converts e.g. "probe_binding_ocaml" → "probe_binding/ocaml".
   variant_id is encoded as a filename suffix (e.g. "probe_19.log"). *)
let step_path ~project_dir ~variant_id step rel =
  let step_d = Canary_step_key.step_dir_of_tag step in
  let rel_vk = Canary_step_key.variant_file ~variant_key:variant_id rel in
  [%string "%{project_dir}/%{step_d}/%{rel_vk}"]

let step_dir ~project_dir step =
  let step_d = Canary_step_key.step_dir_of_tag step in
  [%string "%{project_dir}/%{step_d}"]

(* Pick the first existing probe_lib*/summary.json. *)
let find_lib_inspect ~project_dir ~variant_id =
  let candidates = [
    "probe_lib"; "probe_lib_apt"; "probe_lib_brew"; "probe_lib_staged"
  ] in
  List.find_map candidates ~f:(fun step ->
      let d = step_dir ~project_dir step in
      let fname = Canary_step_key.filename ~variant_key:variant_id ~base:"inspect" ~ext:"json" in
      let p = d ^ "/" ^ fname in
      if Stdlib.Sys.file_exists p then Some p else None)

(* OCaml binding summaries (mli + stub) are written by the install step —
   either Fetch (Binding OCaml) → fetch_binding/ocaml/, or
   Publish (Binding OCaml) → pack_binding/ocaml/. Try both. *)
let find_ocaml_install_dir ~project_dir =
  let candidates = [ "pack_binding_ocaml"; "fetch_binding_ocaml" ] in
  List.find_map candidates ~f:(fun step ->
      let p = step_dir ~project_dir step in
      if Stdlib.Sys.file_exists p && Stdlib.Sys.is_directory p
      then Some p else None)

(* Python binding summary is at fetch_binding/python/summary_{vk}.json. *)
let find_python_inspect ~project_dir ~variant_id =
  let d = step_dir ~project_dir "fetch_binding_python" in
  let fname = Canary_step_key.filename ~variant_key:variant_id ~base:"inspect" ~ext:"json" in
  let p = d ^ "/" ^ fname in
  if Stdlib.Sys.file_exists p then Some p else None

let find_stub_inspect ~project_dir ~variant_id =
  Option.bind (find_ocaml_install_dir ~project_dir) ~f:(fun dir ->
      let fname = Canary_step_key.filename ~variant_key:variant_id ~base:"inspect_stub" ~ext:"json" in
      let p = dir ^ "/" ^ fname in
      if Stdlib.Sys.file_exists p then Some p else None)

let find_mli_inspect ~project_dir ~variant_id =
  Option.bind (find_ocaml_install_dir ~project_dir) ~f:(fun dir ->
      let fname = Canary_step_key.filename ~variant_key:variant_id ~base:"inspect" ~ext:"json" in
      let p = dir ^ "/" ^ fname in
      if Stdlib.Sys.file_exists p then Some p else None)

let run_for_project ~root ~project ~variant =
  match resolve_variant ~root ~project variant with
  | None ->
      Fmt.epr "compat: no project dir for %s under _out/canary/projects/@." project;
      2
  | Some (project_dir, variant_id) ->
      let stub_path = find_stub_inspect ~project_dir ~variant_id in
      let lib_path = find_lib_inspect ~project_dir ~variant_id in
      (match stub_path, lib_path with
       | None, _ ->
           Fmt.epr "compat: no inspect_stub.json under %s/pack_binding/ocaml/@."
             project_dir;
           Fmt.epr "  (run `canary action %s` first to populate the cache)@." project;
           2
       | _, None ->
           Fmt.epr "compat: no probe_lib*/summary.json under %s/@." project_dir;
           2
       | Some stub_p, Some lib_p ->
           Fmt.pr "(using cached summaries for %s/%s)@." project variant_id;
           run ~stub_path:stub_p ~lib_path:lib_p)

(* ── Verification: prediction vs probe outcome ── *)

(* Match a watchlist-missing entry against a probe.log. Tries the full path,
   the path without the top-level package component, and the last component.
   Returns the matched substring (if any). *)
let match_in_log ~log entry =
  let parts = String.split entry ~on:'.' in
  let candidates =
    entry ::
    (match parts with
     | _ :: rest when List.length rest >= 1 ->
         [ String.concat ~sep:"." rest ]
     | _ -> [])
    @ (match List.last parts with Some last -> [ last ] | None -> [])
  in
  List.find candidates ~f:(fun c -> String.is_substring log ~substring:c)

let read_file_or_empty path =
  if Stdlib.Sys.file_exists path
  then Stdlib.In_channel.with_open_text path Stdlib.In_channel.input_all
  else ""

let load_mli_missing ~project_dir ~variant_id =
  match find_mli_inspect ~project_dir ~variant_id with
  | None -> []
  | Some p ->
      let j = Yojson.Basic.from_file p in
      match field j "watchlist" with
      | Some wl -> get_string_list wl "missing"
      | None -> []

(* Variants of a dotted name suitable for substring matching against a
   probe.log: full path, suffix without top-level package prefix, last
   component. Same logic for OCaml ("Llvm.Opcode.UncondBr" → also
   "Opcode.UncondBr" and "UncondBr") and Python ("z3.Solver" → also
   "Solver"). *)
let name_variants e =
  let parts = String.split e ~on:'.' in
  let suffix_no_top = match parts with
    | _ :: (_ :: _ as rest) -> [ String.concat ~sep:"." rest ]
    | _ -> []
  in
  let last = match List.last parts with Some l -> [ l ] | None -> [] in
  e :: suffix_no_top @ last

let load_watchlist_missing path =
  if not (Stdlib.Sys.file_exists path) then []
  else
    let j = Yojson.Basic.from_file path in
    match field j "watchlist" with
    | Some wl -> get_string_list wl "missing"
    | None -> []

(** Predict substrings that would appear in a failed [probe.log] given
    cached inspector JSON paths. Legacy positional API kept for back-
    compat; new call sites should use {!predicted_contains_any_v2}.

    Combines two prediction layers:
    - [stub_inspect_path] + [lib_inspect_path] → {i c1 cmp_symbol}
      missing-symbol prediction (set diff: stub requires \ lib defines).
      Driven by {i bo7} + {i n4} for OCaml or {i bpe3} + {i n4} for cext.
    - [mli_inspect_path] → {i c2 cmp_api_completeness} watchlist-missing
      prediction. Driven by {i bo4 user_binding_ocaml.mli}'s inspect JSON. *)
let predicted_contains_any
    ?stub_inspect_path ?lib_inspect_path ?mli_inspect_path () =
  let l3 = Option.value_map mli_inspect_path ~default:[] ~f:load_watchlist_missing in
  let l3_variants =
    List.concat_map l3 ~f:name_variants
    |> List.dedup_and_sort ~compare:String.compare
  in
  let l0 = match stub_inspect_path, lib_inspect_path with
    | Some s, Some l
      when Stdlib.Sys.file_exists s && Stdlib.Sys.file_exists l ->
        let stub = load_stub s in
        let lib = load_native l in
        (match check_c_compat ~binding_stub:stub ~native_lib:lib with
         | Missing { symbols } -> symbols
         | Compatible | Unknown -> [])
    | _ -> []
  in
  l3_variants @ l0
  |> List.dedup_and_sort ~compare:String.compare

(** Typed input for {!predicted_contains_any_v2}: each constructor names
    the artifact role whose cached inspect JSON sits at the carried path.

    Maps 1-to-1 with {!Canary.compat_inspect_input}'s constructors —
    that variant is the {i intent} (declared on a {!Canary.step_expectation}),
    this one is the {i resolved-path} form computed at run time once the
    inspector has produced its JSON. Aliases:

    - [C_stub p]            ↔ {i bo7 compiled_binding_ocaml.stub-a} or
                              {i bpe3 compiled_binding_cext.so} (stub-shape
                              coerced). Feeds {i c1 cmp_symbol}.
    - [Native_lib p]        ↔ {i n4 lib_native.so}. Feeds {i c1 cmp_symbol}
                              and {i c4 cmp_abi} predictions.
    - [Ocaml_mli p]         ↔ {i bo4 user_binding_ocaml.mli}. Feeds the
                              {i c2 cmp_api_completeness} watchlist check.
    - [Python_attrs p]      ↔ {i bpe2 user_binding_cext.py} or
                              {i bpc2 user_binding_ctypes.py}. Same role
                              as [Ocaml_mli] for the Python flavour.
    - [Versioned_symbols p] ↔ {i n4}'s [versioned_req]/[versioned_exports]
                              fields. Feeds {i c5 cmp_sym_version} (L1b).
    - [Abi_surface p]       ↔ {i n4}'s ELF SONAME/NEEDED/RPATH. Feeds
                              {i c4 cmp_abi} (L4) — currently coarser than
                              the SONAME-only check would be. *)
type typed_input =
  | C_stub of string
  | Native_lib of string
  | Ocaml_mli of string
  | Python_attrs of string
  | Versioned_symbols of string
  | Abi_surface of string

let predicted_contains_any_v2 (inputs : typed_input list) : string list =
  let stub_path = List.find_map inputs ~f:(function C_stub p -> Some p | _ -> None) in
  let lib_path = List.find_map inputs ~f:(function Native_lib p -> Some p | _ -> None) in
  let l0 = match stub_path, lib_path with
    | Some s, Some l
      when Stdlib.Sys.file_exists s && Stdlib.Sys.file_exists l ->
        let stub = load_stub s in
        let lib = load_native l in
        (match check_c_compat ~binding_stub:stub ~native_lib:lib with
         | Missing { symbols } -> symbols
         | Compatible | Unknown -> [])
    | _ -> []
  in
  let l1b =
    List.concat_map inputs ~f:(function
      | Versioned_symbols p ->
          if not (Stdlib.Sys.file_exists p) then []
          else
            let j = Yojson.Basic.from_file p in
            (match field j "versioned_req" with
             | Some (`Assoc entries) -> List.map entries ~f:fst
             | _ -> [])
      | _ -> [])
  in
  (* L4 is diagnostic: SONAME/NEEDED identify *which* library was loaded.
     Different SONAMEs don't cause runtime failure in canary's setup
     (each variant probes its own lib).  L4 helps blame, not predict. *)
  let l4 = [] in
  let l3 =
    List.concat_map inputs ~f:(function
      | Ocaml_mli p | Python_attrs p ->
          load_watchlist_missing p |> List.concat_map ~f:name_variants
      | _ -> [])
  in
  l1b @ l4 @ l3 @ l0
  |> List.dedup_and_sort ~compare:String.compare

(* Best-effort: ".ok" marker file alongside cmd success implies probe step
   succeeded. probe.log non-empty + no .ok marker implies cmd failed (which
   for Expect_failure cases is the GOAL — see step_expectation in
   canary_action.ml). We're not re-implementing the runner's verdict; just
   distinguishing "log has compile error text" from "log shows runtime ok". *)
let probe_log_inspect log =
  let lines = String.split_lines log in
  let line_count = List.length lines in
  let head = List.take lines 4 |> String.concat ~sep:"\n" in
  (line_count, head)

let verify_for_project ~root ~project ~variant =
  match resolve_variant ~root ~project variant with
  | None ->
      Fmt.epr "verify: no project dir for %s under _out/canary/projects/@." project;
      2
  | Some (project_dir, variant_id) ->
      Fmt.pr "=== Compat verification: %s/%s ===@.@." project variant_id;
      Fmt.pr "Project dir: %s  variant: %s@.@." project_dir
        (if String.is_empty variant_id then "(single-variant)" else variant_id);

      (* L3 (OCaml mli) prediction *)
      let mli_missing = load_mli_missing ~project_dir ~variant_id in
      Fmt.pr "L3 (OCaml mli) prediction:@.";
      if List.is_empty mli_missing then
        Fmt.pr "  watchlist missing: (none) — predicts SUCCESS at OCaml level@."
      else (
        Fmt.pr "  watchlist missing: %d entry/entries@."
          (List.length mli_missing);
        List.iter mli_missing ~f:(fun e -> Fmt.pr "    - %s@." e);
        Fmt.pr "  → predicts FAIL referencing one of these names@.");

      (* L3 (Python attrs) prediction *)
      let py_missing =
        match find_python_inspect ~project_dir ~variant_id with
        | None -> []
        | Some p -> load_watchlist_missing p
      in
      Fmt.pr "@.L3 (Python attrs) prediction:@.";
      (match find_python_inspect ~project_dir ~variant_id with
       | None -> Fmt.pr "  (no Python summary cached at fetch_binding_python/)@."
       | Some _ ->
           if List.is_empty py_missing then
             Fmt.pr "  watchlist missing: (none) — predicts SUCCESS at Python level@."
           else (
             Fmt.pr "  watchlist missing: %d entry/entries@."
               (List.length py_missing);
             List.iter py_missing ~f:(fun e -> Fmt.pr "    - %s@." e);
             Fmt.pr "  → predicts FAIL referencing one of these names@."));

      (* L0 (C symbols) prediction *)
      let stub_path = find_stub_inspect ~project_dir ~variant_id in
      let lib_path = find_lib_inspect ~project_dir ~variant_id in
      let c_result = match stub_path, lib_path with
        | Some s, Some l ->
            let stub = load_stub s in
            let lib = load_native l in
            Some (stub, lib, check_c_compat ~binding_stub:stub ~native_lib:lib)
        | _ -> None
      in
      Fmt.pr "@.L0 (C symbols) prediction:@.";
      let c_missing = match c_result with
        | None -> Fmt.pr "  (summaries unavailable)@."; []
        | Some (stub, lib, Compatible) ->
            Fmt.pr "  binding requires %d symbols, lib provides %d@."
              (List.length stub.requires) (List.length lib.symbols);
            Fmt.pr "  → predicts COMPATIBLE at C ABI level@.";
            []
        | Some (stub, lib, Missing { symbols }) ->
            Fmt.pr "  binding requires %d symbols, lib provides %d@."
              (List.length stub.requires) (List.length lib.symbols);
            Fmt.pr "  missing: %d C symbol(s)@." (List.length symbols);
            List.iter symbols ~f:(fun s -> Fmt.pr "    - %s@." s);
            Fmt.pr "  → predicts FAIL referencing one of these symbols@.";
            symbols
        | Some (_, _, Unknown) ->
            Fmt.pr "  (UNKNOWN — one side has no usable symbol data)@.";
            []
      in

      (* Probe.log analysis *)
      let read_log step =
        read_file_or_empty (step_path ~project_dir ~variant_id step "probe.log")
      in
      let ocaml_log = read_log "probe_binding_ocaml" in
      let python_log = read_log "probe_binding_python" in
      let print_log_section name log =
        let line_count, head = probe_log_inspect log in
        Fmt.pr "@.%s probe.log analysis (%d lines):@." name line_count;
        if String.is_empty log then Fmt.pr "  (empty or missing)@."
        else (
          Fmt.pr "  head:@.";
          List.iter (String.split_lines head) ~f:(fun l ->
              Fmt.pr "    | %s@." l))
      in
      print_log_section "OCaml" ocaml_log;
      if not (String.is_empty python_log) then
        print_log_section "Python" python_log;

      (* Cross-reference predictions vs log *)
      Fmt.pr "@.Verdict:@.";
      let confirmed_in log entries =
        List.filter_map entries ~f:(fun e ->
            Option.map (match_in_log ~log e) ~f:(fun m -> (e, m)))
      in
      let unconfirmed_in log entries =
        List.filter entries ~f:(fun e ->
            Option.is_none (match_in_log ~log e))
      in
      let l3_ocaml_confirmed = confirmed_in ocaml_log mli_missing in
      let l3_ocaml_unconfirmed = unconfirmed_in ocaml_log mli_missing in
      let l3_python_confirmed = confirmed_in python_log py_missing in
      let l3_python_unconfirmed = unconfirmed_in python_log py_missing in
      let l0_confirmed =
        List.filter c_missing ~f:(fun s ->
            String.is_substring ocaml_log ~substring:s)
      in
      let l0_unconfirmed =
        List.filter c_missing ~f:(fun s ->
            not (String.is_substring ocaml_log ~substring:s))
      in

      let print_verdict_layer layer ~log ~predicted ~confirmed ~unconfirmed =
        match predicted, confirmed, unconfirmed with
        | [], _, _ ->
            Fmt.pr "  %s: predicted COMPATIBLE — %s@." layer
              (if String.is_empty log then "(no probe log to verify against)"
               else "no failure expected at this layer")
        | _, [], _ ->
            Fmt.pr "  %s: prediction NOT visible in log — probe may have \
                    failed for a different reason, or didn't reach this layer@." layer
        | _, _, [] ->
            Fmt.pr "  %s: CONFIRMED — all predicted entries appear in probe.log@." layer
        | _ ->
            Fmt.pr "  %s: PARTIAL — %d/%d predicted entries confirmed@."
              layer (List.length confirmed)
              (List.length predicted)
      in
      print_verdict_layer "L3 (OCaml)" ~log:ocaml_log
        ~predicted:mli_missing ~confirmed:(List.map l3_ocaml_confirmed ~f:fst)
        ~unconfirmed:l3_ocaml_unconfirmed;
      print_verdict_layer "L3 (Python)" ~log:python_log
        ~predicted:py_missing ~confirmed:(List.map l3_python_confirmed ~f:fst)
        ~unconfirmed:l3_python_unconfirmed;
      print_verdict_layer "L0 (C ABI)" ~log:ocaml_log
        ~predicted:c_missing ~confirmed:l0_confirmed
        ~unconfirmed:l0_unconfirmed;
      List.iter (l3_ocaml_confirmed @ l3_python_confirmed) ~f:(fun (entry, matched) ->
          if not (String.equal entry matched) then
            Fmt.pr "    note: '%s' matched as substring '%s'@." entry matched);
      0
