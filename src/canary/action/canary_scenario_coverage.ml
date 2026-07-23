(** [Canary_scenario_coverage] — the store-lifecycle stage catalogue and
    per-project coverage marks (scenario_coverage.md / ssot §4.2).

    The catalogue is the pipeline of **store transitions** an artifact
    passes through — source → Build (build-tree) → Publish (PM) → Fetch
    (local) → Probe — per artifact (lib, then binding per language). A
    project covers the *segment* its provision-path uses; the rest is
    [Na], symmetrically (tiny's N/A on Publish/Fetch is the same cell as a
    `Fetched` project's N/A on Build).

    This module is the pure core: catalogue + `covered → marks`. The
    provision/mutation enumerator (SSOT §4.2) and the N/A-definition vs
    N/A-config split are follow-ups; for now every uncovered stage is one
    [Na] bucket. *)

open Base
open Canary_basic

(* Three marks (scenario_coverage.md §3):
   - Covered      — a variant runs this stage.
   - Unspecified  — N/A by *definition*: the project's dimensions provide
                    no path (origin=System ⇒ build_lib unspecified).
   - Disabled     — N/A by *config*: applicable, but turned off. *)
type mark = Covered | Unspecified | Disabled

let string_of_mark = function
  | Covered -> "✓"
  | Unspecified -> "unspec"
  | Disabled -> "disabled"

(** The store-lifecycle stage catalogue, ordered source → build → publish
    → fetch → probe. Lib stages first, then each binding language's. *)
let catalogue ~(langs : Canary_lang.lang list) : action list =
  [ Fetch Source; Build_lib; Publish Lib; Fetch Lib; Probe_lib ]
  @ List.concat_map langs ~f:(fun l ->
        [ Build_binding l; Publish (Binding l); Fetch (Binding l);
          Probe_binding l ])

(** Mark each catalogue stage. [covered] is the deduped action set the
    project exercises (its derived steps, unioned over variants).
    [disabled] is the per-project scenario-disable list, as action-name
    strings (e.g. ["build_lib"]); a disabled stage is [Disabled] even if a
    variant could cover it (config overrides). Everything else uncovered
    is [Unspecified] (no path in the definition). *)
let coverage ~(langs : Canary_lang.lang list) ~(covered : action list)
    ~(disabled : string list) : (action * mark) list =
  List.map (catalogue ~langs) ~f:(fun a ->
      let m =
        if List.mem disabled (string_of_action a) ~equal:String.equal then
          Disabled
        else if List.mem covered a ~equal:Poly.equal then Covered
        else Unspecified
      in
      (a, m))

(** The binding languages a project touches, inferred from its action
    set (so the catalogue lists only the relevant binding stages). *)
let langs_of_actions (acts : action list) : Canary_lang.lang list =
  List.filter_map acts ~f:(function
    | Build_binding l | Fetch (Binding l) | Publish (Binding l)
    | Probe_binding l -> Some l
    | _ -> None)
  |> List.dedup_and_sort ~compare:Poly.compare

(** Pretty rows: "  <mark>  <action>". *)
let pp_rows (rows : (action * mark) list) : string =
  String.concat ~sep:"\n"
    (List.map rows ~f:(fun (a, m) ->
         Printf.sprintf "  %-9s %s" (string_of_mark m) (string_of_action a)))
