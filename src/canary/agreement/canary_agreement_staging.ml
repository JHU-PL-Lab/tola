(** Staging agreements — what survives being copied out of the build tree

    A DISTANCE-0 agreement, and the only one so far (theory §5.4). Both
    sides of the comparison are present at once: the build tree and the
    staged tree exist simultaneously, so nothing has been lost yet and
    the check can be nearly as strong as the action it recovers. Every
    other agreement in the registry compares an artifact against
    something that is gone — a declaration standing in for it, or a
    peer produced in another world.

    It is also a LIFT rather than a new comparator. The comparison has
    been running since 2026-08 as [Canary_status.install_diff_note], a
    line in the status report: symbol count, recorded identity, search
    paths and dependencies, build tree versus staged. Running and
    unregistered meant the coverage numbers understated what canary
    did — a row with no evidence is the usual failure, and this was the
    inverse. *)

open Base
open Canary_agreement_common

(* ── the evidence this family reads ── *)

(** The fields of a native summary that a relocation must preserve.
    Deliberately the same set [install_diff_note] compares, so the lift
    changes where the comparison is reported and not what it says. *)
type staged_view = {
  path : string;
  symbols : int;
  soname : string;
  needed : string;
  runpath : string;
  rpath : string;
}

let elf_field j k =
  match Option.bind (field j "elf") ~f:(fun e -> field e k) with
  | Some (`String s) -> s
  | Some (`List xs) ->
      String.concat ~sep:","
        (List.filter_map xs ~f:(function `String s -> Some s | _ -> None))
  | _ -> "-"

let load_staged_view path : staged_view =
  let j = load path in
  let symbols =
    match Option.bind (field j "counts") ~f:(fun c -> field c "total") with
    | Some (`Int n) -> n
    | _ -> -1
  in
  { path = get_string j "path";
    symbols;
    soname = elf_field j "soname";
    needed = elf_field j "needed";
    runpath = elf_field j "runpath";
    rpath = elf_field j "rpath" }

let native_kinds = [ "native" ]

let build_tree_path ~resolve inputs =
  List.find_map inputs ~f:(function
    | Native_lib ps -> pick_existing_of_kind ~resolve ~kinds:native_kinds ps
    | _ -> None)

let staged_path ~resolve inputs =
  List.find_map inputs ~f:(function
    | Staged_lib ps -> pick_existing_of_kind ~resolve ~kinds:native_kinds ps
    | _ -> None)

(* ── the comparator ── *)

(** What changed between the two copies. An EMPTY list is the finding
    worth having as much as a non-empty one: it says this project's
    install step is interface-preserving under these flags, which is
    not obvious and is exactly what a relocation can get wrong.

    Each difference is phrased as the loader would show it, so the
    finding reads the same whether it reaches a log or a report. *)
let diff_staged ~(build_tree : staged_view) ~(staged : staged_view) :
    string list =
  List.filter_map
    [ ("symbols", Int.to_string build_tree.symbols, Int.to_string staged.symbols);
      ("soname", build_tree.soname, staged.soname);
      ("needed", build_tree.needed, staged.needed);
      ("runpath", build_tree.runpath, staged.runpath);
      ("rpath", build_tree.rpath, staged.rpath) ]
    ~f:(fun (k, b, s) ->
      if String.equal b s then None
      else Some (Printf.sprintf "%s %s→%s" k b s))

(* ── the evaluator ── *)

let staged_interface_eval ~resolve inputs : outcome =
  match (build_tree_path ~resolve inputs, staged_path ~resolve inputs) with
  | None, _ -> Unavailable "no build-tree inspection of the library in this world"
  | _, None -> Unavailable "no inspection of the staged library in this world"
  | Some b, Some s -> (
      let build_tree = load_staged_view b and staged = load_staged_view s in
      if build_tree.symbols < 0 && staged.symbols < 0 then
        Inconclusive
          "neither inspection recorded a symbol count; there is nothing to \
           compare but the identity fields"
      else
        match diff_staged ~build_tree ~staged with
        | [] -> Holds
        | ds -> Violated ds)

(* ── the agreement ── *)

let staged_interface_preserved : agreement =
  { ag_subject = Staging;
    ag_claim = Structural;
    ag_basis = Toolchain_rule;
    ag_says =
      "the staged library presents the same interface as the build tree's";
    ag_expects =
      "the build-tree copy of the same library, which is still present. A \
       relocation is allowed to move files and rewrite embedded paths; it is \
       not allowed to change what the object exports, what it calls itself, \
       or what it depends on";
    ag_rooted_in =
      rooted ~action:"install_lib" ~tool:"the install tool"
        ~artifact:"the staged copy of the library"
        ~note:
          "the install tool's rule is that staging relocates without \
           altering the interface. Unusually, it can be checked almost as \
           strongly as it was applied: both copies are still on disk, so \
           nothing had to be inferred from a projection"
        ();
    (* POST, and it can be nothing else (2026-09-14, user asked
       whether it belonged before the install): before install_lib runs
       there is ONE copy of the library, and this agreement compares
       two. The question behind the question — "was the lib already
       wrong before we staged it?" — is a different agreement,
       [declared_symbols_exported], which sits at [build_lib_post] two
       columns to the left. That pair IS the diagnostic ladder. *)
    ag_slot = at_lib Canary_basic.Install_lib Post;
    ag_fault_tag = "staged_drift";
    ag_methods =
      [ checking_method ~name:"staged_vs_build_tree_summary" ~kind:Compare
          ~reference:Peer_artifact
          ~applicable:(fun _ _ w ->
            match Canary_artifact.provision_of_lib w with
            | Canary_store.Installed -> Applicable
            | _ ->
                Inapplicable
                  "this world does not stage the library — there is no second \
                   copy to compare against")
          ~firing:(fun _ _ w ->
            match Canary_artifact.provision_of_lib w with
            | Canary_store.Installed ->
                (* install_lib is where the staging happened, but the
                   staged inspection is produced at the probe that reads
                   it — so the pair is complete only from the probe
                   onwards. Both sites are named; the earlier one
                   reports [unavailable] until the inspection exists,
                   which is the honest answer rather than a silence. *)
                [ Canary_basic.Install_lib; Canary_basic.Probe_lib ]
            | _ -> [])
          ~inputs:(fun _ ->
            (* BOTH SIDES ARE NAMED, and neither goes through
               [lib_evidence_paths] (2026-09-13). That derivation
               answers "where is this world's library" and an Installed
               world's answer is the STAGED copy — which is the right
               answer for every other agreement and catastrophic here.
               It would resolve the build-tree side to the staged file,
               compare it against itself, and report `holds` on every
               relocation including a broken one.

               This is the one agreement whose two sides are two copies
               of the same artifact, so it is the one agreement that
               must address them positionally rather than by world. *)
            [ Native_lib [ "build_lib/inspect.json"; "probe_lib/inspect.json" ];
              Staged_lib
                [ "probe_lib_staged/inspect.json"; "install_lib/inspect.json" ]
            ])
          ~eval:staged_interface_eval
          ~limits:
            "it compares the summary fields an inspector records — export \
             count, recorded identity, dependencies, embedded search paths. \
             It does not compare the exported NAMES one by one, the contents \
             of the objects, or any file other than the library itself, so a \
             staging that drops a header or a data file passes."
          ~counterexamples:
            [ (* the relocation that changed what the object calls
                 itself — the shape a version-suffixed install gets
                 wrong *)
              { fx_method = "staged_vs_build_tree_summary";
                fx_inputs =
                  [ Native_lib [ "bt.json" ]; Staged_lib [ "st.json" ] ];
                fx_bodies =
                  [ ("bt.json",
                     {|{"kind": "native", "path": "fx", "counts": {"total": 12},
    "elf": {"soname": "libtiny.so.1", "needed": ["libc.so.6"]}}|});
                    ("st.json",
                     {|{"kind": "native", "path": "fx", "counts": {"total": 12},
    "elf": {"soname": "libtiny.so.2", "needed": ["libc.so.6"]}}|}) ];
                fx_outcome = "violated";
                fx_findings = [ "soname libtiny.so.1→libtiny.so.2" ] };
              (* the staging that lost exports *)
              { fx_method = "staged_vs_build_tree_summary";
                fx_inputs =
                  [ Native_lib [ "bt.json" ]; Staged_lib [ "thin.json" ] ];
                fx_bodies =
                  [ ("bt.json",
                     {|{"kind": "native", "path": "fx", "counts": {"total": 12},
    "elf": {"soname": "libtiny.so.1", "needed": ["libc.so.6"]}}|});
                    ("thin.json",
                     {|{"kind": "native", "path": "fx", "counts": {"total": 9},
    "elf": {"soname": "libtiny.so.1", "needed": ["libc.so.6"]}}|}) ];
                fx_outcome = "violated";
                fx_findings = [ "symbols 12→9" ] };
              (* IDENTICAL is a finding too: this project's install step
                 preserves the interface under these flags *)
              { fx_method = "staged_vs_build_tree_summary";
                fx_inputs =
                  [ Native_lib [ "bt.json" ]; Staged_lib [ "same.json" ] ];
                fx_bodies =
                  [ ("bt.json",
                     {|{"kind": "native", "path": "fx", "counts": {"total": 12},
    "elf": {"soname": "libtiny.so.1", "needed": ["libc.so.6"]}}|});
                    ("same.json",
                     {|{"kind": "native", "path": "fx", "counts": {"total": 12},
    "elf": {"soname": "libtiny.so.1", "needed": ["libc.so.6"]}}|}) ];
                fx_outcome = "holds";
                fx_findings = [] };
              (* the staged copy was never inspected *)
              { fx_method = "staged_vs_build_tree_summary";
                fx_inputs =
                  [ Native_lib [ "bt.json" ]; Staged_lib [ "absent.json" ] ];
                fx_bodies =
                  [ ("bt.json",
                     {|{"kind": "native", "path": "fx", "counts": {"total": 12},
    "elf": {"soname": "libtiny.so.1", "needed": []}}|}) ];
                fx_outcome = "unavailable";
                fx_findings = [] } ]
          () ] }

let checks : (agreement_id * agreement) list =
  [ (Staged_interface_preserved, staged_interface_preserved) ]
