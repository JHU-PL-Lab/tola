(** API-surface agreements — the user-facing names a binding promises

    One module per check family (design: the per-check module pattern).
    Each check states its CATEGORY (descriptive), its STANDING, and a
    falsifier-phrased sentence; the function keeps whatever signature
    suits it, and the caller supplies the inputs. *)

open Base
open Canary_agreement
module Cat = Canary_agreement

let cat = Cat.Api `Complete
let standing = Cat.Declared
let says = "every watchlisted name is present on the binding's user-facing surface"

let c2_predict ~resolve (inputs : inspect_input list) : string list =
  List.concat_map inputs ~f:(function
    | Ocaml_mli ps | Python_attrs ps ->
        (match pick_existing ~resolve ps with
         | None -> []
         | Some p -> load_watchlist_missing p |> List.concat_map ~f:name_variants)
    | _ -> [])
