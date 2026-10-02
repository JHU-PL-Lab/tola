(** THE TOOL LAYER'S DRIVER FOR A BRIDGE (2026-09-23, status.md §2.7 E).

    [Canary_pm_opam] and its siblings answer what every package manager
    answers: install, remove, which version. A bridge ([Canary_bridge])
    exists for cooperation between two package managers, so the questions
    it answers belong to no single driver — which system packages a conf
    package maps to, what its check asks of the system, and what the
    system says back. This module is that model, and its first consumer
    is the step that records what a bridge did in one world.

    It DISPATCHES the check rather than looking for a record of one. opam
    runs a conf package's check only when it installs the package, so in
    a switch that already holds conf-gmp nothing is dispatched in this
    world and there is nothing to observe. canary therefore runs the same
    query itself, in every world (user, 2026-09-23: an edge is an action
    when the package manager dispatches a separate, observable action).
    What it runs is the predicate's OWN pkg-config invocation, selected
    for this platform by evaluating the predicate's filters against
    [opam var] ([canary/scripts/inspect_bridge.py]). A predicate that
    makes no such query — conf-llvm-shared's is a script — is recorded
    and reported as not dispatchable, never as holding.

    Every package-manager question the recording asks is built here or
    in the per-PM drivers and handed to the script as a command template,
    so how to ask opam or apt is spelled in OCaml, in one place. The
    script only parses, dispatches the predicate, and writes the record. *)

open Base

let script = "canary/scripts/inspect_bridge.py"

(** The record's base name. It is [inspect], like every summary a step
    writes into its own directory, so a reader that names nodes from what
    a world recorded finds it the same way. The record's [kind] is
    ["bridge"]. *)
let record_base = "inspect"

(** The exit status that means the predicate makes no query canary can
    dispatch — distinct from 1, the check was run and did not hold. *)
let not_dispatchable = 3

(** The system package manager's two questions a bridge record asks, as
    templates with [{}] where the package or the path goes: which version
    of a package is installed, and which package ships a file. *)
let sys_pm_queries (pm : Canary_store.package_manager) : (string * string) option
    =
  match pm with
  | Canary_store.Apt ->
      Some
        ( Canary_pm_apt.installed_version_cmd ~pkg:"{}",
          Canary_pm_apt.owner_of_file_cmd ~path:"{}" )
  | Canary_store.Brew ->
      Some
        ( Canary_pm_brew.installed_version_cmd ~pkg:"{}",
          Canary_pm_brew.owner_of_file_cmd ~path:"{}" )
  | Canary_store.Opam | Canary_store.Pip | Canary_store.Unsupported -> None

(** THE QUESTIONS a bridge record asks, each a shell command, with [{}]
    where a name or a path goes. {!record_cmd} fills them from the
    package managers' drivers; a framework test fills them with fixtures,
    which is how the script is tested without depending on what a machine
    has installed. *)
type questions = {
  q_installed : string;  (** the bridge's installed version *)
  q_depexts : string;  (** the system packages it maps to, here *)
  q_predicate : string;  (** its check, as its package states it *)
  q_var : string option;  (** an opam variable's value; [{}] = its name *)
  q_depends : string option;
      (** what the binding package depends on — the [depends] edge *)
  q_sys_version : string option;
      (** a system package's installed version; [{}] = the package *)
  q_owner : string option;
      (** the system package that ships a file; [{}] = the path *)
}

(** The fields of a bridge record a reader may rely on. The framework
    test asserts the script writes every one, so a reader and the
    producer cannot drift apart silently — the lesson the native
    summary's schema test records. *)
let record_fields =
  [ "kind"; "pm"; "bridge_kind"; "package"; "installed_version"; "depexts";
    "depext_versions"; "sys_pm"; "binding_package"; "binding_depends";
    "binding_names_bridge"; "predicate"; "query"; "check"; "capability" ]

(** The recorder's invocation, printing the record on stdout. [vars]
    fixes opam variables instead of asking ([os=linux]) — for a test. *)
let invocation ~(package : string) ~(kind : string) ~(pm : string)
    ~(sys_pm : string) ?binding_pkg ?(vars = []) (q : questions) : string =
  let quote = Stdlib.Filename.quote in
  let opt flag = function Some v -> [ flag; quote v ] | None -> [] in
  let args =
    [ "--package"; quote package; "--kind"; quote kind; "--pm"; quote pm;
      "--sys-pm"; quote sys_pm;
      "--installed-cmd"; quote q.q_installed;
      "--depexts-cmd"; quote q.q_depexts;
      "--predicate-cmd"; quote q.q_predicate ]
    @ opt "--var-cmd" q.q_var
    @ List.concat_map vars ~f:(fun v -> [ "--var"; quote v ])
    @ opt "--binding-package" binding_pkg
    @ opt "--depends-cmd" q.q_depends
    @ opt "--sys-version-cmd" q.q_sys_version
    @ opt "--owner-cmd" q.q_owner
  in
  Printf.sprintf "python3 %s %s" script (String.concat ~sep:" " args)

(** The command that dispatches the bridge's check in this world and
    records what the bridge is and did, into the step's [inspect.json].

    It SUCCEEDS WHEN THE RECORD IS WRITTEN, whatever the check said
    (2026-09-27). The script exits with the verdict — 0 holds, 1 does
    not, 3 ({!not_dispatchable}) the predicate makes no query canary can
    run — and until then the step failed on a check that did not hold.
    The verdict is [gate_admits_the_world]'s now, read from the record's
    [check] like every other agreement's evidence, so a gate that refuses
    the world is a finding the step reports rather than a step that
    breaks the run; [--strict] turns it back into a failure, at the step
    that reads it. Any other status, or an empty record, is the recorder
    failing, and fails the step.

    [binding_pkg] is the package whose [depends] names the bridge; the
    record keeps what that package declares, which is the evidence the
    [depends] edge's claims will need. [None] for a bridge with no check
    to dispatch — a depext field is a mapping and nothing else. *)
let record_cmd (b : Canary_bridge.t) ~(binding_pkg : string option)
    ~(sys_pm : Canary_store.package_manager) :
    (output_dir:string -> variant_key:string -> string) option =
  match b with
  | Canary_bridge.Opam (Canary_bridge.Depext_field _) -> None
  | Canary_bridge.Opam (Canary_bridge.Conf_package pkg) ->
      let sys_version, owner =
        match sys_pm_queries sys_pm with
        | Some (v, o) -> (Some v, Some o)
        | None -> (None, None)
      in
      let q =
        { q_installed = Canary_pm_opam.version_of_cmd ~pkg;
          q_depexts = Canary_pm_opam.show_field_cmd ~pkg ~field:"depexts";
          q_predicate = Canary_pm_opam.show_field_cmd ~pkg ~field:"build";
          q_var = Some (Canary_pm_opam.var_cmd ~name:"{}");
          q_depends =
            Option.map binding_pkg ~f:(fun p ->
                Canary_pm_opam.show_field_cmd ~pkg:p ~field:"depends");
          q_sys_version = sys_version;
          q_owner = owner }
      in
      Some
        (fun ~output_dir ~variant_key ->
          let out =
            Stdlib.Filename.quote
              (output_dir ^ "/"
              ^ Canary_basic.filename ~variant_key ~base:record_base ~ext:"json")
          in
          Printf.sprintf
            "%s > %s; rc=$?; test -s %s && { test $rc -le 1 || test $rc -eq %d; }"
            (invocation ~package:pkg ~kind:"conf_package" ~pm:"opam"
               ~sys_pm:(Canary_store.string_of_pm sys_pm) ?binding_pkg q)
            out out not_dispatchable)
