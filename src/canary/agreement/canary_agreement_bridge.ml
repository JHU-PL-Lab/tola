(** Bridge agreements — what a bridge between two package managers states,
    and whether the world canary constructed honours it (2026-09-27,
    overview.md §6.1 E2).

    A bridge is packaging that exists so one package manager can
    reach another ([Canary_bridge]): opam's [conf-gmp] is an opam package
    whose build is a check against the system. The binding package
    depends on it, so opam admits the binding only where that check
    holds. canary installs with [--assume-depexts] into a switch that may
    already hold the bridge, and opam runs a conf package's check only
    when it first installs it — so in most worlds nobody asks.

    The bridge step asks. It dispatches the predicate's own query in the
    world and records the answer beside what the bridge is
    ([Canary_bridge_driver]; the record's fields are
    [Canary_bridge_driver.record_fields]). That record carries both sides
    of four claims (components.md §5.7); this family holds the first one
    checked. It is also the first agreement whose evidence is the rule
    RE-RUN rather than a projection the rule left: the recorder ran the
    check, and the family reads its verdict. *)

open Base
open Canary_agreement_common

(* ── the evidence this family reads ── *)

(** A bridge record, as far as this family reads it. The recorder writes
    more — the depext mapping, what pkg-config found and which package
    ships it, the installed versions — which is the evidence the
    bridge's other claims will read. *)
type bridge_view = {
  package : string;  (** the bridge — [conf-gmp] *)
  binding_package : string;  (** the package it gates — [zarith] *)
  names_bridge : bool option;
      (** does the binding package's [depends] name the bridge? [None]
          when the recorder was not told which package that is *)
  dispatched : bool;  (** did canary run the predicate's query here? *)
  holds : bool;  (** the query's answer, where it ran *)
  rc : int option;
  argv : string list;  (** the query, as dispatched *)
  output : string;  (** what it printed, as the recorder kept it *)
  fallback : string;
      (** what the predicate runs when the query fails, which canary does
          not dispatch — [conf-gmp] compiles against [gmp.h] *)
}

let load_bridge_view path : bridge_view =
  let j = load path in
  let check = Option.value (field j "check") ~default:`Null in
  let query = Option.value (field j "query") ~default:`Null in
  let bool_of = function Some (`Bool b) -> Some b | _ -> None in
  { package = get_string j "package";
    binding_package = get_string j "binding_package";
    names_bridge = bool_of (field j "binding_names_bridge");
    dispatched = Option.value (bool_of (field check "dispatched")) ~default:false;
    holds = Option.value (bool_of (field check "holds")) ~default:false;
    rc = (match field check "rc" with Some (`Int n) -> Some n | _ -> None);
    argv = get_string_list query "argv";
    output = get_string check "output";
    fallback = get_string query "fallback" }

let bridge_kinds = [ "bridge" ]

let record_path ~resolve inputs =
  List.find_map inputs ~f:(function
    | Bridge_record ps -> pick_existing_of_kind ~resolve ~kinds:bridge_kinds ps
    | _ -> None)

(* ── the comparator ── *)

(** WHAT THE RECORD SAYS ABOUT THE GATE. The comparison itself ran in the
    world — the recorder dispatched the bridge's query against the
    system — so this reads a verdict rather than computing one, and says
    which bridge, which query, and what it answered.

    A query that fails does not refute the claim when the predicate has a
    fallback: opam would run it, and [conf-gmp]'s compiles against
    [gmp.h], which a world with the header and no [.pc] file passes. The
    fallback's answer is evidence canary did not produce, so that case is
    [Missing_evidence], never [Violated]. *)
let gate_verdict (b : bridge_view) : outcome =
  let query = String.concat ~sep:" " b.argv in
  let rc = Option.value_map b.rc ~default:"?" ~f:Int.to_string in
  match b.names_bridge with
  | None ->
      Unavailable
        (Missing_evidence
           (Printf.sprintf
              "the record of %s does not say what the binding package \
               depends on: the recorder was not told which package that is"
              b.package))
  | Some false ->
      Unavailable
        (Nothing_to_check
           (Printf.sprintf "%s does not depend on %s, so it gates nothing here"
              b.binding_package b.package))
  | Some true ->
      if not b.dispatched then
        Unavailable
          (Missing_evidence
             (Printf.sprintf
                "canary cannot dispatch %s's check: its predicate makes no \
                 pkg-config query"
                b.package))
      else if b.holds then Holds
      else if not (String.is_empty b.fallback) then
        Unavailable
          (Missing_evidence
             (Printf.sprintf
                "%s's query `%s` exited %s here, and its predicate then runs \
                 `%s`, which canary does not dispatch"
                b.package query rc b.fallback))
      else
        let said =
          match String.split_lines b.output with
          | first :: _ when not (String.is_empty (String.strip first)) ->
              [ String.strip first ]
          | _ -> []
        in
        Violated (Printf.sprintf "%s: `%s` exited %s" b.package query rc :: said)

(** WHICH LANGUAGES' BINDINGS A BRIDGE CAN GATE. A bridge belongs to the
    package manager a binding comes from, and of those only opam defines
    bridge kinds ([Canary_bridge.kinds_defined]); canary's OCaml bindings
    come from opam and its Python ones from pip, which defines none — a
    wheel carries its native side or names nothing. Stated here because
    applicability is asked with no project in hand; each project states
    its own binding's package manager in its store config. *)
let binding_pm_of_lang : Canary_lang.lang -> Canary_store.package_manager option =
  function
  | Canary_lang.OCaml -> Some Canary_store.Opam
  | Canary_lang.Python -> Some Canary_store.Pip
  | Canary_lang.Cpp | Canary_lang.Rust | Canary_lang.CSharp | Canary_lang.Java ->
      None

let gate_applicable _ (l : Canary_lang.lang) _ : applicability =
  match binding_pm_of_lang l with
  | Some pm when not (List.is_empty (Canary_bridge.kinds_defined pm)) -> Applicable
  | Some pm ->
      Inapplicable
        (Printf.sprintf "%s defines no bridge to another package manager"
           (Canary_store.string_of_pm pm))
  | None ->
      Inapplicable
        (Printf.sprintf "canary knows no package manager for %s bindings"
           (Canary_lang.string_of_lang l))

(* ── the evaluator ── *)

let gate_admits_eval ~resolve inputs : outcome =
  match record_path ~resolve inputs with
  | None ->
      Unavailable
        (Missing_evidence
           "no bridge record here: no step dispatched a bridge for this \
            binding (a project asks for one in runner_spec.bridges)")
  | Some p -> gate_verdict (load_bridge_view p)

(** A synthetic record for the counterexamples: only the fields this
    family reads, the rest of the recorder's schema left out. *)
let fixture_record ?(names = "true") ?(dispatched = true) ?(holds = true)
    ?(rc = "0") ?(output = "null") ?(fallback = "null") () : string =
  Printf.sprintf
    {|{"kind": "bridge", "package": "conf-gmp", "binding_package": "zarith",
  "binding_names_bridge": %s,
  "query": {"argv": ["pkg-config", "--exists", "gmp"], "fallback": %s},
  "check": {"dispatched": %b, "holds": %b, "rc": %s, "output": %s}}|}
    names fallback dispatched holds rc output

(* ── the agreement ── *)

let gate_admits_the_world : agreement =
  { ag_kind = Admissibility;
    ag_subject = Bridges;
    ag_claim = Structural;
    ag_basis = Toolchain_rule;
    ag_says =
      "the world passes the binding package's gate: the bridge's own check, \
       dispatched against this world's system, holds";
    ag_expects =
      "the bridge's predicate as its package states it — the check opam runs \
       before it admits the binding package. canary installs the binding with \
       --assume-depexts into a switch that may already hold the bridge, so \
       the check is exercised in a world only when canary dispatches it";
    ag_rooted_in =
      rooted ~action:"fetch_binding_ocaml" ~tool:"opam, building the bridge"
        ~artifact:
          "the bridge's check against this world's system — the capability \
           file its predicate queries, standing for the library"
        ~note:
          "opam's rule is that a package installs only when its dependencies \
           do, and a conf package only when its check holds. That rule ran \
           when the switch first installed the bridge, in whatever world that \
           was; canary re-dispatches the check in this one, so what survives \
           is the rule's own answer rather than a projection of it"
        ();
    (* PRE: a requirement the install depends on. opam asks it before it
       admits the binding package, so a reader looks for it in front of
       the fetch — and a world with no fetched binding has no column *)
    ag_slot = (fun l -> [ (Canary_basic.Fetch (Canary_basic.Binding l), Pre) ]);
    ag_fault_tag = "gate_refuses";
    ag_methods =
      [ checking_method ~name:"bridge_check_in_this_world" ~kind:Run_tool
          ~reference:Peer_artifact ~applicable:gate_applicable
          ~firing:(fun _ l w ->
            (* only where the binding package was installed from its
               package manager: that install is the one the gate governs.
               The record is WRITTEN by the bridge step beside the install
               and READ at the probe, which the step builder orders after
               every bridge step of its language — so a cold run reads
               this run's record, not the last one's *)
            match Canary_artifact.provision_of_binding w l with
            | Canary_store.Fetched -> [ Canary_basic.Probe_binding l ]
            | _ -> [])
          ~inputs:(fun ctx ->
            [ Bridge_record [ bridge_record_tag ctx.ac_lang ^ "/inspect.json" ] ])
          ~eval:gate_admits_eval ~impl:"gate_admits_eval"
          ~limits:
            "a holding check says what the predicate asks — for conf-gmp, \
             that pkg-config knows a module named gmp. It does not say that \
             the library the module describes is the one the world \
             provisioned or the one the binding links \
             (discovery_matches_link); it evaluates no version bound the \
             binding package puts on the bridge (gate_bounds_the_library); \
             and where the query fails and the predicate falls back to \
             something else, it decides nothing, because canary does not \
             run the fallback."
          ~counterexamples:
            [ (* the world zarith's record describes *)
              { fx_method = "bridge_check_in_this_world";
                fx_inputs = [ Bridge_record [ "ok.json" ] ];
                fx_bodies = [ ("ok.json", fixture_record ()) ];
                fx_outcome = "holds";
                fx_findings = [] };
              (* the query fails and nothing else would be tried *)
              { fx_method = "bridge_check_in_this_world";
                fx_inputs = [ Bridge_record [ "refused.json" ] ];
                fx_bodies =
                  [ ("refused.json",
                     fixture_record ~holds:false ~rc:"1"
                       ~output:
                         {|"Package gmp was not found in the pkg-config search path.\nPerhaps you should add the directory containing `gmp.pc'"|}
                       ()) ];
                fx_outcome = "violated";
                fx_findings =
                  [ "conf-gmp: `pkg-config --exists gmp` exited 1";
                    "Package gmp was not found in the pkg-config search path." ]
              };
              (* the query fails and the predicate would compile against
                 the header next: opam might still admit this world *)
              { fx_method = "bridge_check_in_this_world";
                fx_inputs = [ Bridge_record [ "fallback.json" ] ];
                fx_bodies =
                  [ ("fallback.json",
                     fixture_record ~holds:false ~rc:"1"
                       ~fallback:{|"cc -c $CFLAGS test.c"|} ()) ];
                fx_outcome = "unavailable";
                fx_findings = [] };
              (* the bridge gates something else *)
              { fx_method = "bridge_check_in_this_world";
                fx_inputs = [ Bridge_record [ "elsewhere.json" ] ];
                fx_bodies = [ ("elsewhere.json", fixture_record ~names:"false" ()) ];
                fx_outcome = "vacuous";
                fx_findings = [] };
              (* a predicate that is a script, not a query: llvm's *)
              { fx_method = "bridge_check_in_this_world";
                fx_inputs = [ Bridge_record [ "script.json" ] ];
                fx_bodies =
                  [ ("script.json",
                     fixture_record ~dispatched:false ~holds:false ~rc:"null" ()) ];
                fx_outcome = "unavailable";
                fx_findings = [] };
              (* no step dispatched a bridge here *)
              { fx_method = "bridge_check_in_this_world";
                fx_inputs = [ Bridge_record [ "absent.json" ] ];
                fx_bodies = [];
                fx_outcome = "unavailable";
                fx_findings = [] } ]
          () ] }

let checks : (agreement_id * agreement) list =
  [ (Gate_admits_the_world, gate_admits_the_world) ]
