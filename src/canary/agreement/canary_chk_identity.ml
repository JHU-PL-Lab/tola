(** Identity agreements — the soname a consumer records, and the version nodes it needs

    One module per check family (design: the per-check module pattern).
    Each check states its CATEGORY (descriptive), its STANDING, and a
    falsifier-phrased sentence; the function keeps whatever signature
    suits it, and the caller supplies the inputs. *)

open Base
open Canary_agreement
module Cat = Canary_check_cat

let soname_cat = Cat.Identity `Soname
let version_cat = Cat.Identity `Version_node
let standing = Cat.Declared
let soname_says = "the lib's soname is the one the consumer recorded it needs"
let version_says = "the provider exports every version node the consumer requires"

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
      (match Canary_agreement.check_sym_version
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
      (match Canary_agreement.check_abi
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
