(** [Canary_topology] — PM COOPERATION, derived (2026-09-22).

    THE THIRD VIEW. The agreement overview answers "what claim, over
    which artifacts, recovered from whose rule" — which is the artifact
    and binding material. It says nothing about HOW the two package
    ecosystems on either side of a binding are joined, because until now
    nothing typed that join. This module does.

    A TOPOLOGY is the shape of one cooperation: who supplies the native
    side, who supplies the language side, and what — if anything — sits
    between them. Every field is DERIVED from declarations the projects
    already carry ([ar_universe]'s provisions and [pm_gate]); nothing new
    is declared, because a second place to state the topology is a second
    place to get it wrong.

    {1 The bridge}

    A BRIDGE is a concrete, separate piece of package content whose
    PURPOSE is package-manager cooperation (user, 2026-09-22). Three
    things follow from that definition and all three matter:

    - it is a THING, not a relation — [conf-gmp] is an opam package
      somebody wrote, [gmp.pc] is a file inside [libgmp-dev];
    - it lives in neither the pure native side nor the pure language
      side, which is exactly why the binding-level view cannot see it;
    - it is OPTIONAL. Two ecosystems may cooperate through a bridge, or
      through nothing but the artifacts themselves — a language package
      that links whatever native library is installed globally has no
      bridge and is not thereby broken.

    ⚠ THERE ARE USUALLY TWO BRIDGES, NOT ONE, and conflating them was the
    error this module exists to stop. In the opam/apt topology:

    {v
      conf-gmp   a separate opam package   carries package IDENTITY
                                           (+ the depext mapping)
      gmp.pc     content inside libgmp-dev carries CAPABILITY
                                           (name, version, cflags, libs)
    v}

    They can disagree, and that disagreement is the check. Cargo's
    [*-sys] topology has only the second, which is what makes it
    artifact-centric rather than bridgeless.

    {1 Three findings this derivation surfaced}

    {b (1) The capability bridge has a name and no instances.}
    [Canary_artifact.Pc_file] is a declared [api_component] and NO
    project declares one — the fourth "declared with no reader" of the
    month, and the most pointed, because its own doc comment says it
    "isn't itself a surface canary checks". That was the right call under
    the surface theory, which is about the BINDING relation: a [.pc] file
    is not binding material. It is cooperation material, and the frame
    that would check it did not exist. So {!capability_bridges} returns
    what is declared, which is [] everywhere today, and the rendering
    says "undeclared" rather than "none" — an empty list that means
    nobody looked must not read as an answer.

    {b (2) A topology is per PROVISION, not per project.} z3 is the
    specimen: its dev worlds build libz3 from source (no system PM in the
    picture at all) while its FORWARD cell takes apt's libz3 4.8.12. Same
    project, same binding, two genuinely different cooperations. So the
    derivation ranges over each row's declared provisions and one project
    contributes several topologies — which is also what makes a topology
    row orthogonal to the project roster, as a row of this table should
    be.

    {b (3) Four projects' gates are declared where this cannot read
    them.} [Canary_opam_binding] sets [pr_binding_decls = []] and keeps
    its gate on the template's own record, so cairo, libffi, zlib and
    zstd declare a [pm_gate] that no consumer reaches. That is
    [project/issues.md] §2 — a mechanism declared in two places, one of
    them read — arriving at its SECOND consumer. It is deliberately NOT
    worked around here: {!gate_of} returns [None] for those projects and
    the table shows the gap, because a silently short table is worse than
    a visibly incomplete one. Routing the gate alone would be safe
    (nothing reads it), but routing the DECLARATION means routing its
    mechanism too, and that flips four green libffi cells — a
    mechanism-catalogue question, not this module's. *)

open Base
module SC = Canary_store_config
module BD = Canary_binding_decl
module PS = Canary_project_spec

(** WHO supplies one side's artifact in a given world. Not "which PM" —
    the honest answer is often that no package manager is involved, and
    a type that could only name PMs would have to invent one. *)
type supplier =
  | By_pm of Canary_store.package_manager
      (** an apt/brew/opam/pip package provides it *)
  | Built_here  (** compiled from source in this world *)
  | Staged  (** the install-prefix face of this world's own build *)
  | Vendored  (** a path that pre-existed the run *)
  | Unsupplied  (** declared [Absent] *)

let string_of_supplier = function
  | By_pm pm -> Canary_store.string_of_pm pm
  | Built_here -> "built"
  | Staged -> "staged"
  | Vendored -> "vendored"
  | Unsupplied -> "absent"

(** A concrete, separate piece of package content that exists for
    cooperation. See the module header for why this is a thing rather
    than a relation, and why there are usually two. *)
type bridge =
  | Conf_package of { pkg : string; reaches_lib : bool }
      (** opam's [conf-*] indirection. [reaches_lib] is the ONE question
          worth asking of it: does a version bound on this package bound
          the C LIBRARY, or only the packaging of the check? Measured
          across the repository at 13 of 370 (surveys/conf_packages.md
          §G1a), and carried per project as [pm_gate]'s [tracks_lib]. *)
  | Depext_field of string
      (** the language package names the system package directly, with no
          conf hop — a bridge that is metadata inside the consumer rather
          than a package of its own. *)
  | Capability_file of string
      (** a [.pc] file, a CMake package config, a [*-config] script:
          content shipped INSIDE the provider whose purpose is to be read
          from outside. The artifact-facing bridge. See finding (1). *)

let string_of_bridge = function
  | Conf_package { pkg; reaches_lib } ->
      pkg ^ if reaches_lib then " (bounds the lib)" else " (presence only)"
  | Depext_field d -> "depext:" ^ d
  | Capability_file f -> f

(** HOW the two sides are joined. Five constructors because the first
    cut of this module had one — an empty [bridge list] — and that one
    value was carrying four incompatible meanings at once: cairo's gate
    is unreachable, sqlite's Python side has no package manager between
    the artifacts at all, llvm's Python side declares a gate that DELETES
    the bridge, and a genuine artifact-centric join has looked and found
    nothing. Rendered together they read as one answer and three of them
    are wrong.

    This is the same collapse [unavailable_cause] undid for outcomes in
    2026-09-15 — one word for "missing evidence", "missing declaration"
    and "nothing to check" — and it reappeared here within an hour of
    the type being written, which says the shape is easy to fall into
    rather than that it was careless. *)
type joining =
  | Bridged of bridge list  (** non-empty, by construction *)
  | Artifacts_only
      (** declared, and there is no bridge: the language side consumes
          whatever the system installed. A real topology, not a gap. *)
  | Bridge_absorbed of string
      (** the consumer package took the native side inside itself —
          [Package_builds_lib], [Bundled]. There is no cooperation left
          to bridge, which is a different statement from having none. *)
  | No_pm_between of string
      (** no package manager stands between the two artifacts at all.
          sqlite's Python binding is the specimen: CPython's stdlib
          extension was joined to libsqlite3 by whoever built the
          interpreter, outside any PM we can observe. *)
  | Undeclared_join
      (** ⚠ we could not read the declaration — finding (3). Never
          rendered as any of the four above. *)

(** One cooperation's shape: the two stacks and what joins them. *)
type t = {
  tp_sys : supplier;
  tp_join : joining;
  tp_lang : supplier;
}

let bridges_of_join = function Bridged bs -> bs | _ -> []

let string_of_join = function
  | Bridged bs -> String.concat ~sep:" + " (List.map bs ~f:string_of_bridge)
  | Artifacts_only -> "(none — artifacts only)"
  | Bridge_absorbed why -> "(absorbed: " ^ why ^ ")"
  | No_pm_between why -> "(no PM between: " ^ why ^ ")"
  | Undeclared_join -> "⚠ UNDECLARED HERE"

(** The short form for a table cell. The long form stays available for
    the row's own detail — a column that silently truncates its own key
    is how two different topologies come to look like one. *)
let short_of_join = function
  | Bridged bs -> String.concat ~sep:" + " (List.map bs ~f:string_of_bridge)
  | Artifacts_only -> "— artifacts only —"
  | Bridge_absorbed _ -> "— absorbed by the consumer —"
  | No_pm_between _ -> "— no PM between —"
  | Undeclared_join -> "⚠ UNDECLARED"

(** ⚠ AN ABSORBED JOIN HAS NO SECOND ECOSYSTEM, so the native side's
    declared provision does not participate in it. The first cut ranged
    over that provision anyway and produced three identical rows for
    z3's OCaml binding — one each for apt, built and staged — which is
    not three topologies, it is one topology counted three times because
    a field that does not apply was still varying.

    When the consumer package contains the native artifact (a bundled
    wheel) or builds it ([Package_builds_lib]), the supplier of the
    native side IS the language package manager. Saying so collapses
    the duplicates and states the truth: there is one ecosystem here. *)
let normalize (t : t) : t =
  match t.tp_join with
  | Bridge_absorbed _ -> { t with tp_sys = t.tp_lang }
  | _ -> t

(** The doc's "topology character" — derived, never declared, so it
    cannot drift from the shape it names. *)
let character (t : t) : string =
  let bs = bridges_of_join t.tp_join in
  let has f = List.exists bs ~f in
  let has_conf = has (function Conf_package _ -> true | _ -> false) in
  let has_cap = has (function Capability_file _ -> true | _ -> false) in
  let has_depext = has (function Depext_field _ -> true | _ -> false) in
  (* ⚠ THE BRIDGE IS NOT SILENCED BY A LOCAL BUILD, and the first cut of
     this function assumed it was — it matched the supplier before the
     join and so reported llvm's built-lib world as having no bridge
     while `conf-llvm-shared {= "19"}` was still in the package's
     depends. opam runs that predicate against the SYSTEM whatever this
     world built, so the bridge fires and validates something the world
     is not using. That is not a wording problem; it is exactly the
     situation `gate_admits_the_world` names, and the character has to
     say it rather than hide it behind the supplier. *)
  let built_side =
    match t.tp_sys with Built_here | Staged | Vendored -> true | _ -> false
  in
  match (t.tp_sys, t.tp_lang, t.tp_join) with
  | _, _, Undeclared_join -> "⚠ undeclared — cannot be classified"
  | _, _, No_pm_between why -> why
  | _, _, Bridge_absorbed why -> why
  | Unsupplied, _, _ | _, Unsupplied, _ -> "incomplete — one side is absent"
  | By_pm a, By_pm b, _ when Poly.equal a b -> "unified package universe"
  | _ when built_side && has_conf ->
      "⚠ bridge still gates, against a system this world does not use"
  | _ when built_side -> "no provider ecosystem — the native side is local"
  | _ when has_conf && has_cap -> "symbolic package bridge + artifact validation"
  | _ when has_conf -> "symbolic package bridge, unvalidated against artifacts"
  | _ when has_depext -> "direct depext — package identity, no conf hop"
  | _ when has_cap -> "artifact-centric, capability-mediated"
  | _ -> "artifact-centric, no bridge"

(* ── deriving a supplier from a declared provision ────────────────── *)

let supplier_of_provision (p : SC.provision_spec) : supplier =
  match p with
  | SC.Absent -> Unsupplied
  | SC.Built_from _ -> Built_here
  | SC.Installed -> Staged
  | SC.Vendored_at _ -> Vendored
  | SC.Fetched provider -> (
      match provider with
      | SC.Sys_pkg _ ->
          (* the system PM is derived from the platform, never declared —
             see [Canary_store.system_pm_of_platform] *)
          By_pm (Canary_store.system_pm_of_platform (Canary_store.platform ()))
      | SC.Lang_pkg { pm; _ } -> By_pm pm
      | SC.Vendored _ -> Vendored
      | SC.Cached _ -> Vendored
      | SC.Repo _ | SC.Repo_axes _ -> Built_here
      | SC.Absent -> Unsupplied)

(* ── deriving bridges from a declared gate ───────────────────────── *)

(** The SYMBOLIC bridge a gate names, if it names one. The two
    structural cases return [] and that is the right answer, not a gap:
    [Package_builds_lib] and [Bundled] do not weaken a bridge, they
    delete the provider ecosystem, which {!character} reports from the
    supplier instead. *)
let symbolic_bridges_of_gate (g : BD.pm_dep_gate) : bridge list =
  match g with
  | BD.Free_with_conf pkg -> [ Conf_package { pkg; reaches_lib = false } ]
  | BD.Bounded_with_conf { conf; tracks_lib; _ } ->
      [ Conf_package { pkg = conf; reaches_lib = tracks_lib } ]
  | BD.Fixed_with_conf { conf; _ } ->
      (* an exact pin always reaches the library: opam refuses every other
         generation, which is what makes it the hard case *)
      [ Conf_package { pkg = conf; reaches_lib = true } ]
  | BD.Pinned_depext { depext; _ } -> [ Depext_field depext ]
  | BD.Package_builds_lib | BD.Bundled _ -> []

(** The ARTIFACT-FACING bridges a project declares, read from the lib
    row's components. Empty everywhere today — see finding (1). The
    caller must distinguish this [] from "we looked and there is none";
    {!capability_bridges_are_undeclared} is that distinction. *)
let capability_bridges (components : Canary_artifact.api_component list) :
    bridge list =
  List.filter_map components ~f:(function
    | Canary_artifact.Pc_file -> Some (Capability_file "pkg-config (.pc)")
    | Canary_artifact.Headers | Canary_artifact.Runtime_lib
    | Canary_artifact.Link_lib ->
        None)

(** TRUE while no project has declared a [Pc_file] component. A view must
    say "undeclared" rather than "none" while this holds: pkg-config is
    demonstrably in use — conf packages' build predicates run it, and our
    own [Pm_lib] locator does — so an empty list here records that nobody
    declared it, not that nothing is there. *)
let capability_bridges_are_undeclared (bs : bridge list) : bool =
  not (List.exists bs ~f:(function Capability_file _ -> true | _ -> false))

(* ── the project-level derivation ─────────────────────────────────── *)

(** The gate declared for one language's binding. The OUTER [None] means
    no declaration was reachable at all (finding (3)); the inner one
    means a declaration exists and states that there is no gate.

    ⚠ THE TWO [None]s ARE DIFFERENT and the first cut conflated them.
    A decl that EXISTS carrying [pm_gate = None] is a project saying
    "no package manager stands between these two artifacts" — sqlite's
    CPython stdlib binding and all of tiny's in-tree bindings say
    exactly that, deliberately. A decl that does not exist at all is the
    routing bug. Collapsing them put four honest projects under the same
    ⚠ as four broken ones. *)
let gate_of (pr : Canary_project_run.project_run) (lang : Canary_lang.lang) :
    BD.pm_dep_gate option option =
  List.find_map pr.Canary_project_run.pr_binding_decls ~f:(fun d ->
      let d_lang =
        (Canary_mechanism.info_of_mechanism d.BD.mechanism)
          .Canary_mechanism.mi_lang
      in
      if Poly.equal d_lang lang then Some d.BD.pm_gate else None)

(** The join, from whatever the project managed to declare. The one
    place the five constructors are chosen, so a caller cannot invent a
    sixth meaning for an empty list. *)
let join_of (pr : Canary_project_run.project_run) (lang : Canary_lang.lang) :
    joining =
  match gate_of pr lang with
  | None -> Undeclared_join
  | Some None ->
      No_pm_between "no package manager stands between these two artifacts"
  | Some (Some g) -> (
      match symbolic_bridges_of_gate g with
      | [] -> (
          match g with
          | BD.Package_builds_lib ->
              Bridge_absorbed "the consumer package builds the native lib"
          | BD.Bundled what -> Bridge_absorbed ("bundled: " ^ what)
          | _ -> Artifacts_only)
      | bs -> Bridged bs)

(** One instance: the (project, language, world-class) that realizes a
    topology. A project appears several times — once per declared native
    provision — which is finding (2). *)
type instance = {
  in_project : string;
  in_lang : Canary_lang.lang;
  in_sys_provision : string;  (** how the native side is provisioned here *)
  in_gate_reachable : bool;  (** false = finding (3), the gate is unrouted *)
}

let lib_rows (pr : Canary_project_run.project_run) : PS.artifact_row list =
  List.filter pr.Canary_project_run.pr_artifacts ~f:(fun r ->
      match r.PS.ar_artifact with Canary_artifact.A_lib _ -> true | _ -> false)

let binding_langs (pr : Canary_project_run.project_run) : Canary_lang.lang list =
  List.filter_map pr.Canary_project_run.pr_artifacts ~f:(fun r ->
      match r.PS.ar_artifact with
      | Canary_artifact.A_binding (l, _) -> Some l
      | _ -> None)
  |> List.dedup_and_sort ~compare:Poly.compare

(** The binding's own supplier, for one language: the provision its row
    declares. A binding fetched from opam and one built here and packed
    are different language-side stacks, so this is not a constant. *)
let lang_supplier (pr : Canary_project_run.project_run)
    (lang : Canary_lang.lang) : supplier =
  let row =
    List.find pr.Canary_project_run.pr_artifacts ~f:(fun r ->
        match r.PS.ar_artifact with
        | Canary_artifact.A_binding (l, _) -> Poly.equal l lang
        | _ -> false)
  in
  match row with
  | None -> Unsupplied
  | Some r -> (
      (* the FETCHED provision is the one that names an ecosystem; a row
         that is only built has no language-PM stack to speak of and is
         reported as built *)
      match
        List.find_map r.PS.ar_universe ~f:(fun (spec, _) ->
            match spec with SC.Fetched _ -> Some spec | _ -> None)
      with
      | Some spec -> supplier_of_provision spec
      | None -> (
          match r.PS.ar_universe with
          | (spec, _) :: _ -> supplier_of_provision spec
          | [] -> Unsupplied))

(** Every topology one project realizes, with the instance that names
    each. The product is (native provision × binding language), because
    both sides vary independently and a topology is a fact about the
    PAIR. *)
let topologies_of_project ((name, pr) : string * Canary_project_run.project_run)
    : (t * instance) list =
  let langs = binding_langs pr in
  List.concat_map (lib_rows pr) ~f:(fun lib_row ->
      List.concat_map lib_row.PS.ar_universe ~f:(fun (lib_spec, _) ->
          match lib_spec with
          | SC.Absent -> []
          | _ ->
              List.map langs ~f:(fun lang ->
                  let join = join_of pr lang in
                  ( normalize
                      { tp_sys = supplier_of_provision lib_spec;
                        tp_join = join;
                        tp_lang = lang_supplier pr lang },
                    { in_project = name;
                      in_lang = lang;
                      in_sys_provision =
                        Canary_store.string_of_provision
                          (SC.provision_of_spec lib_spec);
                      in_gate_reachable =
                        (match join with
                        | Undeclared_join -> false
                        | _ -> true) } ))))

(** THE TABLE: one entry per distinct topology, with every instance that
    realizes it. Sorted so the rendering is stable. *)
let topologies (projects : (string * Canary_project_run.project_run) list) :
    (t * instance list) list =
  let all = List.concat_map projects ~f:topologies_of_project in
  let keyed =
    List.map all ~f:(fun (t, i) ->
        let key =
          Printf.sprintf "%s|%s|%s" (string_of_supplier t.tp_sys)
            (string_of_join t.tp_join)
            (string_of_supplier t.tp_lang)
        in
        (key, t, i))
  in
  List.dedup_and_sort keyed ~compare:(fun (a, _, _) (b, _, _) ->
      String.compare a b)
  |> List.map ~f:(fun (key, t, _) ->
         let insts =
           List.filter_map keyed ~f:(fun (k, _, i) ->
               if String.equal k key then Some i else None)
         in
         (t, insts))

(** ⚠ Instances whose gate could not be read — finding (3). Non-empty
    today (cairo, libffi, zlib, zstd) and the table must SAY so, because
    those four sit in a no-bridge row while declaring a conf package. *)
let unreachable_gates (rows : (t * instance list) list) : instance list =
  List.concat_map rows ~f:(fun (_, insts) ->
      List.filter insts ~f:(fun i -> not i.in_gate_reachable))

(** The terminal view. One row per topology; the instances beneath it are
    what realizes it, and a project appears under several rows. *)
let pp_topologies (projects : (string * Canary_project_run.project_run) list) :
    string =
  let rows = topologies projects in
  let buf = Buffer.create 4096 in
  let add fmt = Printf.ksprintf (Buffer.add_string buf) fmt in
  add
    "PM COOPERATION — one row per topology, derived from the declared \
     provisions and gates\n\n";
  add
    "  a BRIDGE is concrete, separate package content that exists for \
     cooperation.\n\
    \  No bridge is a real answer: the language side may link whatever the \
     system\n\
    \  installed. Two bridges is the common case — a conf package carries \
     package\n\
    \  IDENTITY, a .pc file carries CAPABILITY, and they can disagree.\n\n";
  (* pad by CODEPOINTS, not bytes: the join column holds em-dashes and a
     warning sign, and [%-34s] counts the bytes of those, so every row
     carrying one shifted the two columns after it *)
  let pad n s =
    let width =
      String.fold s ~init:0 ~f:(fun acc c ->
          if Char.to_int c land 0xC0 = 0x80 then acc else acc + 1)
    in
    if width >= n then s else s ^ String.make (n - width) ' '
  in
  add "%s %s %s %s\n" (pad 10 "native") (pad 34 "bridge(s)") (pad 9 "language")
    "character";
  add "%s\n" (String.make 108 '-');
  List.iter rows ~f:(fun (t, insts) ->
      add "%s %s %s %s\n"
        (pad 10 (string_of_supplier t.tp_sys))
        (pad 34 (short_of_join t.tp_join))
        (pad 9 (string_of_supplier t.tp_lang))
        (character t);
      let named =
        List.map insts ~f:(fun i ->
            Printf.sprintf "%s/%s%s" i.in_project
              (Canary_lang.string_of_lang i.in_lang)
              (if i.in_gate_reachable then "" else " ⚠"))
        |> List.dedup_and_sort ~compare:String.compare
      in
      add "             %s\n" (String.concat ~sep:", " named));
  let unreachable = unreachable_gates rows in
  add "\n";
  if not (List.is_empty unreachable) then (
    add
      "⚠ %d instance(s) marked ⚠ declare a gate this view cannot read \
       (project/issues.md §2):\n"
      (List.length unreachable);
    add
      "  the opam-binding template keeps its gate on its own record and \
       leaves\n\
      \  pr_binding_decls empty, so those rows show NO bridge while \
       declaring a conf\n\
      \  package. They are in the wrong row until the gate is routed.\n\n");
  add
    "⚠ no project declares a Pc_file component, so no CAPABILITY bridge \
     appears\n\
    \  above. pkg-config is demonstrably in use — conf predicates run it \
     and our\n\
    \  own lib locator does — so that column is UNDECLARED, not empty.\n";
  Buffer.contents buf
