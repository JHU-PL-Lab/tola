(** [Canary_scenario_coverage] — the store-lifecycle stage catalogue and
    per-project coverage marks (scenario_coverage.md / ssot §4.2, §4.2.1).

    The catalogue is the pipeline of **store transitions** an artifact
    passes through — source → Build (build-tree) → Publish (PM) → Fetch
    (local) → Probe — per artifact (lib, then binding per language).

    Each catalogue entry is a **logical stage** (§4.2.1a): a display label
    plus the concrete actions that *realize* it. A stage is [Covered] if
    the project runs **any** realization. Most stages have one; `run_app`
    has two — `Probe_app` (build path — a real app artifact) and
    `Probe_binding` (fetch path — the example *is* the app) — so tiny
    (`Probe_app`) and sqlite (`Probe_binding`) both map to the same stage
    instead of missing each other.

    Build vs Fetch stay *distinct* stages (they're a real provenance
    difference — the matrix shows which path); only the run realizations
    merge. Provision/mutation enumerator + `(lang × mechanism)` binding
    identity are the remaining §4.2.1 refinements. *)

open Base
open Canary_basic

type mark = Covered | Unspecified | Disabled

(* single-glyph marks so columns line up; see [legend]. *)
let string_of_mark = function
  | Covered -> "✓"
  | Unspecified -> "-"
  | Disabled -> "⊘"

let legend = "  ✓ covered   - unspec (no path)   ⊘ disabled (config)"

(* A logical stage: display label + the actions that realize it. *)
type stage = { label : string; realizations : action list }

(** The store-lifecycle catalogue, ordered source → build → publish →
    fetch → probe. Lib stages first, then each binding language's. *)
let catalogue ~(langs : Canary_lang.lang list) : stage list =
  let lib =
    [ { label = "fetch_source"; realizations = [ Fetch Source ] };
      { label = "build_lib"; realizations = [ Build_lib ] };
      { label = "publish_lib"; realizations = [ Publish Lib ] };
      { label = "fetch_lib"; realizations = [ Fetch Lib ] };
      { label = "probe_lib"; realizations = [ Probe_lib ] };
    ]
  in
  let binding l =
    let s = Canary_lang.string_of_lang l in
    (* [build_binding] exists only for a Static-C-ABI binding — a compiled
       stub (OCaml cstubs, Python cext). A Dynamic-FFI binding (ctypes,
       Dynlink) is pure source that dlopens the lib at probe time, so it has
       no compile stage (§4.2.1b). Round 1 wires only Static, so this guard
       is always true today; it pre-encodes the round-2 semantics. *)
    (if Canary_mechanism.is_static_binding_lang l then
       [ { label = "build_binding_" ^ s; realizations = [ Build_binding l ] } ]
     else [])
    @ [ { label = "publish_binding_" ^ s; realizations = [ Publish (Binding l) ] };
        { label = "fetch_binding_" ^ s; realizations = [ Fetch (Binding l) ] };
        (* run the app that uses the binding: build path (Probe_app) or
           fetch path (Probe_binding — the example is the app) *)
        { label = "run_app_" ^ s;
          realizations = [ Probe_binding l; Probe_app { lang = l } ] };
      ]
  in
  lib @ List.concat_map langs ~f:binding

(** Mark each logical stage. [covered] is the deduped action set the
    project exercises (union over variants / good_scenarios). [disabled]
    is the scenario-disable list, as stage labels; a disabled stage is
    [Disabled] even if covered (config overrides). Uncovered otherwise →
    [Unspecified] (no path in the definition). *)
let coverage ~(langs : Canary_lang.lang list) ~(covered : action list)
    ~(disabled : string list) : (stage * mark) list =
  List.map (catalogue ~langs) ~f:(fun st ->
      let m =
        if List.mem disabled st.label ~equal:String.equal then Disabled
        else if
          List.exists st.realizations ~f:(fun a ->
              List.mem covered a ~equal:Poly.equal)
        then Covered
        else Unspecified
      in
      (st, m))

(** The binding languages a project touches, inferred from its action
    set (so the catalogue lists only the relevant binding stages). *)
let langs_of_actions (acts : action list) : Canary_lang.lang list =
  List.filter_map acts ~f:(function
    | Build_binding l | Fetch (Binding l) | Publish (Binding l)
    | Probe_binding l | Build_app { lang = l } | Probe_app { lang = l } ->
        Some l
    | _ -> None)
  |> List.dedup_and_sort ~compare:Poly.compare

(** Pretty rows: "  <mark>  <stage label>". Each mark is exactly one
    display column, so a literal 2-space separator aligns the labels
    (byte-padding via [%-Ns] would not — the glyphs differ in byte width). *)
let pp_rows (rows : (stage * mark) list) : string =
  String.concat ~sep:"\n"
    (List.map rows ~f:(fun (st, m) ->
         Printf.sprintf "  %s  %s" (string_of_mark m) st.label))
