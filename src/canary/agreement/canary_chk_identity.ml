(** Identity agreements — the soname a consumer records, and the version nodes it needs

    One module per check family (design: the per-check module pattern).
    Each check states its CATEGORY (descriptive), its STANDING, and a
    falsifier-phrased sentence; the function keeps whatever signature
    suits it, and the caller supplies the inputs. *)

open Base
open Canary_agreement_common
module Cat = Canary_agreement_common

let soname_cat = Cat.Identity `Soname
let version_cat = Cat.Identity `Version_node
let standing = Cat.Declared
let soname_says = "the lib's soname is the one the consumer recorded it needs"
let version_says = "the provider exports every version node the consumer requires"

(* ── the evidence this family reads ── *)

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

(* ── the SOLO cells: the lib against the DECLARATION ──

   Same two agreements as below, asked of ONE artifact instead of two:
   is the built lib's soname the declared one, are the declared version
   tags exported. They lived in [canary_chk_lib_declares] until
   2026-09-02 — a module split by evidence source rather than by
   category, which put two [Identity] checks outside the identity
   family. The version-script application and the linker are black
   boxes, so neither trusts an exit code: each reads the artifact. *)

let soname_matches_cat = Cat.Identity `Soname
let soname_matches_standing = Cat.Declared
let soname_matches_says =
  "the built lib's elf soname is the soname the project declared"

(** c4 lib-only: the BUILT lib's own elf soname vs the declared soname
    (the linker's -Wl,-soname application is the black box; the
    artifact's elf is the evidence). *)
let soname_matches ~declared_soname ~resolve
    (inputs : inspect_input list) : string list =
  let lib_path =
    List.find_map inputs ~f:(function
        | Native_lib ps -> pick_existing ~resolve ps
        | _ -> None)
  in
  match lib_path with
  | None -> []
  | Some p -> (
      match (load_abi_surface p).soname with
      | Some s when not (String.equal s declared_soname) ->
          [ Printf.sprintf "soname %s != declared %s" s declared_soname ]
      | _ -> [])

let version_tags_exported_cat = Cat.Identity `Version_node
let version_tags_exported_standing = Cat.Declared
let version_tags_exported_says =
  "every version tag the project declares appears among the built lib's \
   versioned exports"

let version_tags_exported ~declared_tags ~resolve
    (inputs : inspect_input list) : string list =
  let lib_path =
    List.find_map inputs ~f:(function
        | Versioned_exports ps -> pick_existing ~resolve ps
        | _ -> None)
  in
  match lib_path with
  | None -> []
  | Some p ->
      let vs = load_versioned_symbols p in
      let exported =
        List.map vs.exports ~f:snd |> List.dedup_and_sort ~compare:String.compare
      in
      List.filter_map declared_tags ~f:(fun tag ->
          if List.mem exported tag ~equal:String.equal then None
          else Some (Printf.sprintf "version %s not exported" tag))

(* ── c4: the soname ── *)

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

(* ── c5: the version nodes ── *)

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

(** c5 cmp_sym_version (L1b) — the PREDICT side. Reads provider's
    versioned_exports map from a [Versioned_exports] input and
    consumer's versioned_req map from a [Versioned_req] input; runs
    [check_sym_version] and on mismatch returns the version tags the
    consumer requires that the provider doesn't export. dyld's runtime
    error mentions those tags verbatim ("version `TINY_1.0' not
    found"), so they're the right substrings to grep probe.log for.
    (This comment was stranded in [Canary_chk_api_surface] by the
    per-family split; it belongs with the check it describes.) *)

let c5_predict ~resolve (inputs : inspect_input list) : string list =
  let provider_path =
    List.find_map inputs
      ~f:(function
        | Versioned_exports ps -> pick_existing ~resolve ps
        | _ -> None) in
  let consumer_path =
    List.find_map inputs
      ~f:(function
        | Versioned_req ps -> pick_existing ~resolve ps
        | _ -> None) in
  match provider_path, consumer_path with
  | Some pp, Some cp ->
      let prov = load_versioned_symbols pp in
      let cons = load_versioned_symbols cp in
      let consumer_required = List.map cons.req_counts ~f:fst in
      (match check_sym_version
               ~provider_versioned_exports:prov.exports
               ~consumer_required_versions:consumer_required with
       | Sym_version_missing { missing_versions } -> missing_versions
       | Sym_version_compatible | Sym_version_unknown -> [])
  | _ -> []

(** c4 cmp_abi (L4). Reads provider's SONAME from a [Native_lib]
    input's [elf.soname] and consumer's NEEDED list from an
    [Abi_surface] input's [elf.needed]. When [check_abi] returns
    [Abi_mismatch], the predicted substring set is the consumer's
    NEEDED entries that share the provider's family-stem
    (e.g. [libtiny] from [libtiny.so.1]) — at runtime, dyld's error
    mentions the missing NEEDED entry verbatim, so that's what we want
    to grep for. *)

let c4_predict ~resolve (inputs : inspect_input list) : string list =
  let provider_path =
    List.find_map inputs
      ~f:(function Native_lib ps -> pick_existing ~resolve ps | _ -> None) in
  let consumer_path =
    List.find_map inputs
      ~f:(function Abi_surface ps -> pick_existing ~resolve ps | _ -> None) in
  match provider_path, consumer_path with
  | Some pp, Some cp ->
      let prov = load_abi_surface pp in
      let cons = load_abi_surface cp in
      (match check_abi
               ~provider_soname:prov.soname
               ~consumer_needed:cons.needed with
       | Abi_mismatch _ ->
           (* Stem = strip trailing ".so.X" / ".so.X.Y" so libtiny.so.1
              and libtiny.so.2 share stem "libtiny". *)
           let stem name =
             match String.index name '.' with
             | None -> name
             | Some i -> String.sub name ~pos:0 ~len:i in
           (match prov.soname with
            | None -> []
            | Some sn ->
                let prov_stem = stem sn in
                List.filter cons.needed
                  ~f:(fun n -> String.equal (stem n) prov_stem))
       | Abi_compatible | Abi_unknown -> [])
  | _ -> []

(** c3 cmp_behavior is structurally different from c1/c2/c4/c5.
    There's no static input to predict over — behavioral truth lives
    in the {b running} binary, and expected values live inside the
    probe's source as embedded assertions. The comparator IS the
    probe's exit-code check; canary surfaces it via
    [Expect_failure { contains_any = ["FAIL "] }] on Probe steps (the
    tiny probe prints [FAIL …] on assertion mismatch).
    See [Canary_tiny_scenario.make_lib_behavior_broken_runner_spec]
    for the demo against harness scenario [e7 behavior_silent].
    [c3_predict] returns [] honestly: there's nothing static to
    predict. Status stays [Blocked []] to reflect the {b predict} side
    being a no-op; coverage is via the probe runner.

    c7 [api_sound_repack] is structurally analogous to c3 — same
    probe-runner mechanism, different Contract attribution (binding-
    repack-layer bug vs native-behavior bug). Variants declaring c7
    use [Expect_failure { contains_any = ["FAIL "] }] same as c3.
    [c7_predict] returns []; registry entry stays in place for
    documentation only (status = Stubbed, enabled = false). See
    [Canary_tiny_scenario.make_binding_repack_broken_runner_spec] and
    [make_binding_python_repack_broken_runner_spec] for live demos
    against scenarios [api_repack] and [api_repack_python].

    c8 is disabled — no Contract for canary to maintain. Each binding
    is independent; cross-binding consistency isn't a canary-side
    agreement. Candidate for removal in a future registry cleanup. *)

let c4 : description =
  { cat = soname_cat; standing; says = soname_says;
    claim = Structural;
    evidence = Compare_several;
    provenance = Added;
    reads = [ ("Sf.2", "native"); ("Sf.5", "binding") ];
    fault_tags = [ "abi_soname" ];
    firing = firing_with_build_lib;
    inputs =
      (fun m l w ->
        (* only the cext surfaces NEEDED today — an OCaml binding's
           NEEDED lives on the linked exe, not the .cmxa *)
        match (l, is_dynamic m) with
        | Canary_lang.Python, false ->
            [ Native_lib [ build_lib_tag ^ "/inspect.json" ];
              Abi_surface [ binding_evidence_tag w l ^ "/inspect.json" ] ]
        | _ -> []);
    counterexamples =
      [ (* the SOLO cell: the built lib's elf soname vs the declared
           one — the linker's -Wl,-soname is the black box, the elf is
           the evidence *)
        { fx_predict = Some (soname_matches ~declared_soname:"libtiny.so.1");
          fx_inputs = [ Native_lib [ "lib.json" ] ];
          fx_bodies =
            [ ("lib.json",
               {|{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum"],
    "elf": {"soname": "libtiny.so.2", "needed": []}}|}) ];
          fx_expect = [ "soname libtiny.so.2 != declared libtiny.so.1" ] } ] }

let c5 : description =
  { cat = version_cat; standing; says = version_says;
    claim = Structural;
    evidence = Compare_several;
    provenance = Added;
    reads = [ ("Sf.2", "native"); ("Sf.5", "binding") ];
    fault_tags = [ "sym_version" ];
    firing = firing_with_build_lib;
    inputs =
      (fun m l w ->
        match (l, is_dynamic m) with
        | Canary_lang.Python, false ->
            [ Versioned_exports [ build_lib_tag ^ "/inspect.json" ];
              Versioned_req [ binding_evidence_tag w l ^ "/inspect.json" ] ]
        | _ -> []);
    counterexamples =
      [ (* the SOLO cell: the version script applied — a declared tag
           must appear among the built lib's @@VER annotations *)
        { fx_predict =
            Some (version_tags_exported ~declared_tags:[ "TINY_2.0" ]);
          fx_inputs = [ Versioned_exports [ "lib.json" ] ];
          fx_bodies =
            [ ("lib.json",
               {|{"kind": "native", "path": "fx",
    "versioned_exports": {"tiny_sum": "TINY_1.0"}}|}) ];
          fx_expect = [ "version TINY_2.0 not exported" ] } ] }
