(** API-surface agreements — the user-facing names a binding offers

    Two agreements: the watchlisted names are present on the surface a
    user imports ([api_names_present]), and the user-facing layer
    preserves the stub-facing one ([repack_preserves_api]). The second
    keeps a PROVISIONAL name: what "preserves" permits is undecided
    (design §6.3.1), and a name should not settle a claim the catalogue
    has not. *)

open Base
open Canary_agreement_common

(* ── the evidence this family reads ── *)

(** The kinds that ARE a user-facing surface. Three inspectors produce
    one: [inspect_binding.py --kind mli] (["ocaml_mli"]),
    [inspect_ocaml.py] over an installed findlib package (["ocaml"]),
    and [inspect_python.py] over an imported module (["python"]).
    Selecting by these rather than by filename is what lets one
    candidate list cover both the framework's spelling and tiny's
    without ever reading a compiled-stub summary as a surface. *)
let user_surface_kinds = [ "ocaml_mli"; "ocaml"; "python" ]

(** Every watchlist inspection among [inputs] that actually resolved.
    Plural because a project may hand both its OCaml and its Python
    surface to one step, and the claim is the same for each — only the
    surface differs, which is what the per-language modules own. *)
let watchlist_paths ~resolve inputs =
  List.filter_map inputs ~f:(function
    | Ocaml_mli ps | Python_attrs ps ->
        pick_existing_of_kind ~resolve ~kinds:user_surface_kinds ps
    | _ -> None)

(* ── is every watchlisted name present ── *)

let api_names_eval ~resolve inputs : outcome =
  match watchlist_paths ~resolve inputs with
  | [] ->
      Unavailable
        (Missing_evidence "no user-facing surface inspection in this world")
  | paths -> (
      let loaded = List.filter_map paths ~f:load_watchlist in
      if List.is_empty loaded then
        Inconclusive
          "the surface inspection carries no watchlist section (the inspector \
           ran without one)"
      else
        let present = List.concat_map loaded ~f:fst in
        let missing = List.concat_map loaded ~f:snd in
        match (present, missing) with
        | [], [] ->
            (* the distinction the design insists on: an empty
               declaration is not coverage *)
            Inconclusive
              "the watchlist is empty — nothing was asked of this surface"
        | _, [] -> Holds
        | _, missing -> Violated missing)

(** The names a failing run's log will actually print. An OCaml
    compiler says [Opcode.UncondBr] or [UncondBr] where the watchlist
    said [Llvm.Opcode.UncondBr], so the diagnostic prediction expands
    each finding into its observable spellings. Kept separate from the
    evaluation on purpose: the VERDICT is "these names are missing";
    how a tool spells them is a property of the tool. *)
let api_names_diagnostics o = List.concat_map (findings_of_outcome o) ~f:name_variants

(* ── the repacking relation ── *)

(** Result type for the name-based repacking helper. It pins the
    stub-facing layer against the user-facing one within a single
    binding — every user-facing name should correspond to a stub-facing
    name (modulo declared renames), and vice versa. *)
type repack_result =
  | Repack_compatible
  | Repack_stub_orphan of { externals_not_exposed : string list }
  | Repack_user_phantom of { vals_without_external : string list }
  | Repack_unknown

(** Compare the stub-facing externals against the user-facing vals.
    Strict name equality after filtering out declared rename pairs.

    What it catches: a stub-side orphan — the author wrote
    [external new_thing] and forgot the corresponding [val new_thing].
    What it does NOT catch: a repack whose [.ml] is wrong while both
    interfaces are unchanged. That drift is invisible to any name
    comparison, which is why this helper is not by itself the
    agreement's evaluator. *)
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

(* ── what each agreement hands the registry ── *)

let api_names_present : agreement =
  (* PAIRING, not promise, though its second side is a declaration. The
     claim is that the application's uses resolve on the binding's
     surface — could these two have been compiled together — and the
     watchlist is a hand-written stand-in for the application's actual
     uses (theory.md §5.8). Classifying it by its evidence rather than
     its claim is exactly the conflation `ag_kind` exists to undo. *)
  { ag_kind = Admissibility;
    ag_subject = Api_names;
    ag_claim = Structural;
    ag_basis = Project_declaration;
    ag_says =
      "every watchlisted name is present on the binding's user-facing surface";
    ag_expects =
      "the project's watchlist for this binding; a watched name absent from \
       the inspected surface is the falsifier. An empty watchlist asks \
       nothing and is reported as inconclusive, never as a pass";
    ag_rooted_in =
      rooted ~action:"build_app_ocaml" ~tool:"the language compiler"
        ~artifact:
          "the binding's user-facing interface. Most projects declare no \
           app, so the rule's own action is absent and the check falls to \
           the binding probe"
        ~note:
          "the compiler's rule is that every name a consumer uses resolves \
           on the interface it compiles against. The watchlist stands in for \
           the application's actual uses, which makes this a hand-written \
           APPROXIMATION of a real rule rather than a derivation of it"
        ();
    (* PRE, and of build_app rather than of the binding: the claim is
       that an APPLICATION compiling against this interface will
       resolve its names. Most projects have no build_app, so in
       practice it renders before the probe. *)
    ag_slot =
      (fun l ->
        [ (Canary_basic.Build_app { lang = l }, Pre);
          (Canary_basic.Probe_binding l, Pre) ]);
    ag_fault_tag = "api_drop";
    ag_methods =
      [ checking_method ~name:"watchlist_vs_user_surface" ~kind:Inspect
          ~reference:Declared_facts ~firing:firing_default
          ~inputs:(fun { ac_lang = l; ac_world = w; _ } ->
            let tag = binding_evidence_tag w l in
            match l with
            (* the CLAIM is identical across languages; only the surface
               differs, so each language says where its own is *)
            | Canary_lang.OCaml -> [ Canary_agreement_ocaml.user_surface tag ]
            | Canary_lang.Python ->
                (* both spellings, as for OCaml: the framework's
                   [inspect_python.py] writes inspect.json, tiny writes
                   inspect_attrs.json, and the kind decides *)
                [ Python_attrs
                    [ tag ^ "/inspect.json"; tag ^ "/inspect_attrs.json" ] ]
            | _ -> [])
          ~eval:api_names_eval ~impl:"api_names_eval" ~diagnostics:api_names_diagnostics
          ~limits:
            "coverage is bounded by the watchlist: names outside it are not \
             checked, and a name being present says nothing about the \
             signature or behaviour behind it. Obtaining the Python surface \
             already imports the module."
          ~counterexamples:
            [ (* the OCaml watchlist, echoing llvm's Opcode.UncondBr — the
                 expectation is the dotted-name expansion, which is what a
                 probe log actually prints *)
              { fx_method = "watchlist_vs_user_surface";
                fx_inputs = [ Ocaml_mli [ "mli.json" ] ];
                fx_bodies =
                  [ ("mli.json",
                     {|{"kind": "ocaml_mli", "path": "fx",
    "watchlist": {"present": [], "missing": ["Llvm.Opcode.UncondBr"]}}|}) ];
                fx_outcome = "violated";
                fx_findings =
                  [ "Llvm.Opcode.UncondBr"; "Opcode.UncondBr"; "UncondBr" ] };
              (* the Python one, echoing z3's wheel surface *)
              { fx_method = "watchlist_vs_user_surface";
                fx_inputs = [ Python_attrs [ "py.json" ] ];
                fx_bodies =
                  [ ("py.json",
                     {|{"kind": "python", "path": "fx",
    "watchlist": {"present": [], "missing": ["Solver.add", "BitVec"]}}|}) ];
                fx_outcome = "violated";
                fx_findings = [ "Solver.add"; "add"; "BitVec" ] };
              (* an EMPTY watchlist is not coverage *)
              { fx_method = "watchlist_vs_user_surface";
                fx_inputs = [ Ocaml_mli [ "empty.json" ] ];
                fx_bodies =
                  [ ("empty.json",
                     {|{"kind": "ocaml_mli", "path": "fx",
    "watchlist": {"present": [], "missing": []}}|}) ];
                fx_outcome = "inconclusive";
                fx_findings = [] } ]
          () ] }

let repack_preserves_api : agreement =
  { ag_kind = Preservation;
    ag_subject = Repacking;
    ag_claim = Behavioral;
    ag_basis = Behavioral_spec;
    ag_says = "the user-facing layer is a sound repacking of the stub-facing one";
    ag_expects =
      "an explicit statement of which transformations a wrapper may make. \
       Until the project supplies one, there is no reference to compare \
       against: a wrapper may rename, combine, restrict or extend, and none \
       of those is refuted by a name comparison";
    ag_rooted_in =
      unrooted
        ~note:
          "a binding's two layers are both written by the author, and \
           nothing compiles one against the other in a way that could reject \
           a rename, a merge or a deliberate omission. This is a claim about \
           INTENT, and it needs stating before it can be checked"
        ();
    (* POST: about the binding artifact itself — whether its two layers
       agree — not about anything it will be combined with. *)
    ag_slot = after_binding;
    ag_fault_tag = "api_repack";
    ag_methods =
      [ checking_method ~name:"declared_repacking_relation" ~kind:Run_program
          ~reference:Declared_facts ~firing:firing_probe_only
          ~inputs:(fun _ -> [])
          ~planned:
            "the repacking relation is not specified: \"preserves\" has no \
             agreed scope, so there is nothing to compare a binding against. \
             check_api_repack compares names and declared renames, which \
             refutes a stub-side orphan but not a wrapper whose \
             implementation drifted; the probe's own assertions carry that \
             case today"
          ~limits:
            "not evaluated. The name-based helper, when it is connected, \
             will refute orphaned externals only."
          () ] }

let checks : (agreement_id * agreement) list =
  [ (Api_names_present, api_names_present);
    (Repack_preserves_api, repack_preserves_api) ]
