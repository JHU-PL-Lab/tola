(** API-surface agreements — the user-facing names a binding promises

    One module per check family (design: the per-check module pattern). Each
    check states its CATEGORY (descriptive), its STANDING, and a
    falsifier-phrased sentence; the function keeps whatever signature suits it,
    and the caller supplies the inputs. *)

open Base
open Canary_agreement_common
module Cat = Canary_agreement_common

(* ── what this module is about ── *)

let complete : about =
  {
    cat = Cat.Api `Complete;
    standing = Cat.Declared;
    says =
      "every watchlisted name is present on the binding's user-facing surface";
  }

let repack : about =
  {
    cat = Cat.Api `Repacked;
    standing = Cat.Declared;
    says = "the user-facing layer is a sound repacking of the stub-facing one";
  }

let checks : (string * about) list =
  [ ("api_surface_complete", complete); ("repack_preserves_api", repack) ]

(* ── c2: is every watchlisted name present ── *)

let c2_predict ~resolve (inputs : inspect_input list) : string list =
  List.concat_map inputs ~f:(function
    | Ocaml_mli ps | Python_attrs ps -> (
        match pick_existing ~resolve ps with
        | None -> []
        | Some p -> load_watchlist_missing p |> List.concat_map ~f:name_variants
        )
    | _ -> [])

(* ── c7: is the user-facing layer a sound repacking of the stub one ── *)

(** [c7 cmp_api_repack] result type. The contract pins {i s3 binding_stub} ↔
    {i s4 binding_header} within a single binding — every user-facing name
    should correspond to a stub-facing name (modulo declared renames), and vice
    versa. *)
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
let check_api_repack ~(stub_externals : string list) ~(user_vals : string list)
    ~(renames : (string * string) list) : repack_result =
  if List.is_empty stub_externals && List.is_empty user_vals then Repack_unknown
  else
    let renames_from = Set.of_list (module String) (List.map renames ~f:fst) in
    let renames_to = Set.of_list (module String) (List.map renames ~f:snd) in
    let externals = Set.of_list (module String) stub_externals in
    let vals = Set.of_list (module String) user_vals in
    (* Orphans: externals not in vals AND not declared as a rename source. *)
    let orphans = Set.diff (Set.diff externals vals) renames_from in
    (* Phantoms: vals not in externals AND not declared as a rename target. *)
    let phantoms = Set.diff (Set.diff vals externals) renames_to in
    match (Set.is_empty orphans, Set.is_empty phantoms) with
    | true, true -> Repack_compatible
    | false, _ ->
        Repack_stub_orphan { externals_not_exposed = Set.to_list orphans }
    | _, false ->
        Repack_user_phantom { vals_without_external = Set.to_list phantoms }

(* c7 is UNWIRED on the predict side: the repack drift shows up by
   RUNNING the binding probe, not in any static input, so this returns
   [] honestly and the registry keeps the row disabled. *)
let c7_predict ~resolve:_ _ = []

(* ── what each agreement hands the registry ── *)

let c2 : description =
  {
    about = complete;
    claim = Structural;
    evidence = Inspect_one;
    provenance = Added;
    reads = [ ("Sf.4", "binding") ];
    fault_tags = [ "api_drop" ];
    firing = firing_default;
    inputs =
      (fun _ l w ->
        let tag = binding_evidence_tag w l in
        match l with
        | Canary_lang.OCaml -> [ Ocaml_mli [ tag ^ "/inspect_mli.json" ] ]
        | Canary_lang.Python -> [ Python_attrs [ tag ^ "/inspect_attrs.json" ] ]
        | _ -> []);
    counterexamples =
      [
        (* the OCaml watchlist, echoing llvm's Opcode.UncondBr — the
           expectation is the dotted-name expansion, which is what a
           probe log actually prints *)
        {
          fx_predict = None;
          fx_inputs = [ Ocaml_mli [ "mli.json" ] ];
          fx_bodies =
            [
              ( "mli.json",
                {|{"kind": "ocaml_mli", "path": "fx",
    "watchlist": {"present": [], "missing": ["Llvm.Opcode.UncondBr"]}}|}
              );
            ];
          fx_expect = [ "Llvm.Opcode.UncondBr"; "Opcode.UncondBr"; "UncondBr" ];
        };
        (* the Python one, echoing z3's wheel surface *)
        {
          fx_predict = None;
          fx_inputs = [ Python_attrs [ "py.json" ] ];
          fx_bodies =
            [
              ( "py.json",
                {|{"kind": "python", "path": "fx",
    "watchlist": {"present": [], "missing": ["Solver.add", "BitVec"]}}|}
              );
            ];
          fx_expect = [ "Solver.add"; "add"; "BitVec" ];
        };
      ];
  }

let c7 : description =
  {
    about = repack;
    claim = Semantic;
    evidence = Run_program;
    provenance = Added;
    reads = [ ("Sf.4", "binding") ];
    fault_tags = [ "api_repack" ];
    firing = firing_probe_only;
    inputs = (fun _ _ _ -> []);
    (* the repack drift shows up by RUNNING, so there is no static
       counterexample to write — the registry keeps c7 stubbed *)
    counterexamples = [];
  }
