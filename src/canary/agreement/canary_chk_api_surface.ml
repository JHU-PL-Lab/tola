(** API-surface agreements — the user-facing names a binding promises

    One module per check family (design: the per-check module pattern).
    Each check states its CATEGORY (descriptive), its STANDING, and a
    falsifier-phrased sentence; the function keeps whatever signature
    suits it, and the caller supplies the inputs. *)

open Base
open Canary_agreement
module Cat = Canary_check_cat

let cat = Cat.Api `Complete
let standing = Cat.Declared
let says = "every watchlisted name is present on the binding's user-facing surface"

let c2_predict ~resolve (inputs : inspect_input list) : string list =
  List.concat_map inputs ~f:(function
    | Ocaml_mli ps | Python_attrs ps ->
        (match Canary_evidence.pick_existing ~resolve ps with
         | None -> []
         | Some p -> Canary_evidence.load_watchlist_missing p |> List.concat_map ~f:Canary_evidence.name_variants)
    | _ -> [])

(** c5 cmp_sym_version (L1b). Reads provider's versioned_exports map
    from a [Versioned_exports] input and consumer's versioned_req map
    from a [Versioned_req] input; runs [check_sym_version] and on
    mismatch returns the version tags the consumer requires that the
    provider doesn't export. dyld's runtime error mentions those tags
    verbatim ("version `TINY_1.0' not found"), so they're the right
    substrings to grep probe.log for. *)
