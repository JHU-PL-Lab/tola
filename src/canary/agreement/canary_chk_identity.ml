(** Identity agreements — the soname a consumer records, and the version nodes it needs

    One module per check family (design: the per-check module pattern).
    Each check states its CATEGORY (descriptive), its STANDING, and a
    falsifier-phrased sentence; the function keeps whatever signature
    suits it, and the caller supplies the inputs. *)

open Base
open Canary_agreement
module Cat = Canary_agreement

let soname_cat = Cat.Identity `Soname
let version_cat = Cat.Identity `Version_node
let standing = Cat.Declared
let soname_says = "the lib's soname is the one the consumer recorded it needs"
let version_says = "the provider exports every version node the consumer requires"

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
      let prov = Canary_agreement.load_versioned_symbols pp in
      let cons = Canary_agreement.load_versioned_symbols cp in
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
      let prov = Canary_agreement.load_abi_surface pp in
      let cons = Canary_agreement.load_abi_surface cp in
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
