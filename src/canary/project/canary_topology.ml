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

(* ── THE LAYERED GRAPH ────────────────────────────────────────────────

   The table above says WHICH topology. This says what a topology IS:
   the nodes a full chain passes through, the edges between them, and
   which of our actions realizes each edge.

   It is GENERAL MECHANISM — no project, no package, no version. A
   concrete case is this graph with its nodes named and its inapplicable
   edges greyed, which is why the two are one vocabulary rather than two
   drawings.

   ⚠ TWO THINGS THE THREE-LAYER PICTURE DOES NOT HAVE, and our claims
   need both:

   - THE DECLARATION. Four implemented agreements compare an artifact
     against canary's own spec — not against package metadata, not
     against another artifact. It is not a layer; it is an ORACLE
     attached to whatever node it speaks about, and drawing it as a
     layer would suggest it is produced by something below it.
   - THE SOURCE. [source_is_declared_ref] and
     [build_tree_configured_for_source] are about a node beneath the
     native artifact. The layered model has source only inside its
     package-rewrite cases, never in the base picture.

   ⚠ AND ONE EDGE RUNS BOTH WAYS. [Pkg_lang]—[Module_lang] is an
   INSTALL when the binding is fetched and a PACK when it is built here,
   and those are different actions establishing different relations. The
   direction is a function of the provision, which is exactly what our
   enumeration already ranges over — so the diagram has to read it from
   the world rather than draw one arrow and be wrong half the time. *)

type layer = L_pm | L_package | L_artifact | L_program | L_oracle

let string_of_layer = function
  | L_pm -> "pm"
  | L_package -> "package"
  | L_artifact -> "artifact"
  | L_program -> "program"
  | L_oracle -> "oracle"

type side = S_sys | S_bridge | S_lang

type node = {
  nd_id : string;
  nd_label : string;  (** the GENERIC name — never a package *)
  nd_layer : layer;
  nd_side : side;
  nd_gloss : string;
}

let nodes : node list =
  [ { nd_id = "pm_sys"; nd_label = "system PM"; nd_layer = L_pm;
      nd_side = S_sys;
      nd_gloss = "apt, brew, dnf — resolves and installs native packages" };
    { nd_id = "pkg_sys"; nd_label = "native package"; nd_layer = L_package;
      nd_side = S_sys;
      nd_gloss = "the unit the system PM ships: payload plus metadata" };
    { nd_id = "src_sys"; nd_label = "native source"; nd_layer = L_artifact;
      nd_side = S_sys;
      nd_gloss =
        "the library's own repository at a ref — present when the world \
         builds rather than fetches" };
    { nd_id = "hdr_sys"; nd_label = "headers"; nd_layer = L_artifact;
      nd_side = S_sys;
      nd_gloss = "the syntactic native surface a binding compiles against" };
    { nd_id = "lib_sys"; nd_label = "native library"; nd_layer = L_artifact;
      nd_side = S_sys;
      nd_gloss =
        "the link-time and runtime carrier: exported symbols, identity, \
         recorded dependencies" };
    { nd_id = "staged_sys"; nd_label = "staged copy"; nd_layer = L_artifact;
      nd_side = S_sys;
      nd_gloss =
        "the install-prefix face of the same library — a second copy, \
         which is why a claim can compare them" };
    { nd_id = "cap"; nd_label = "capability file"; nd_layer = L_package;
      nd_side = S_bridge;
      nd_gloss =
        "a .pc file, a CMake config, a *-config script: content inside \
         the provider whose purpose is to be read from outside. THE \
         ARTIFACT-FACING BRIDGE" };
    { nd_id = "bridge"; nd_label = "bridge package"; nd_layer = L_package;
      nd_side = S_bridge;
      nd_gloss =
        "a separate package existing only for cooperation (opam's \
         conf-*). Carries package IDENTITY and the depext mapping. THE \
         SYMBOLIC BRIDGE" };
    { nd_id = "pm_lang"; nd_label = "language PM"; nd_layer = L_pm;
      nd_side = S_lang;
      nd_gloss = "opam, pip, cargo — solves constraints and installs" };
    { nd_id = "pkg_lang"; nd_label = "binding package"; nd_layer = L_package;
      nd_side = S_lang;
      nd_gloss = "the unit the language PM ships, with its declared depends" };
    { nd_id = "src_lang"; nd_label = "binding source"; nd_layer = L_artifact;
      nd_side = S_lang;
      nd_gloss =
        "the binding's own repository — separate from the library's, and \
         often at a different ref" };
    { nd_id = "stub_lang"; nd_label = "compiled stub"; nd_layer = L_artifact;
      nd_side = S_lang;
      nd_gloss =
        "the C shim the binding compiles: what records the symbols it \
         requires of the library" };
    { nd_id = "mod_lang"; nd_label = "language module"; nd_layer = L_artifact;
      nd_side = S_lang;
      nd_gloss = "the compiled language-side artifact the consumer links" };
    { nd_id = "surf_lang"; nd_label = "user surface"; nd_layer = L_artifact;
      nd_side = S_lang;
      nd_gloss = "the names and types the binding offers its own users" };
    { nd_id = "app"; nd_label = "consumer program"; nd_layer = L_program;
      nd_side = S_lang;
      nd_gloss =
        "the only node where anything RUNS — everything above is static" };
    { nd_id = "decl"; nd_label = "declaration"; nd_layer = L_oracle;
      nd_side = S_bridge;
      nd_gloss =
        "what the experiment says should be true. NOT a layer: an oracle \
         attached to whatever node it speaks about" } ]

let node_by_id id = List.find nodes ~f:(fun n -> String.equal n.nd_id id)

(** An edge is a relation some tool establishes, and [eg_action] names
    the action of ours that realizes it. Where that is [None] the
    relation is real and we run nothing at it — which is itself the
    finding, not an omission. *)
type edge = {
  eg_id : string;
  eg_from : string list;  (** several inputs: an action is n-ary *)
  eg_to : string;
  eg_action : string option;
  eg_tool : string;  (** whose rule runs here *)
  eg_says : string;
  eg_diagonal : bool;  (** crosses layers rather than staying within one *)
  eg_observation : bool;
      (** TRUE when the step RECORDS evidence rather than establishing a
          relation between two things. [probe_lib] is the case: it runs
          `nm` and writes a summary, and nothing about that is a claim
          two parties could disagree on. Carrying no claim is therefore
          the expected state for it, and counting it among the gaps
          would inflate the one number on this page anybody will quote. *)
}

let edges : edge list =
  [ { eg_id = "resolve_sys"; eg_from = [ "pm_sys" ]; eg_to = "pkg_sys";
      eg_action = Some "fetch_lib"; eg_tool = "the system PM's solver";
      eg_says = "a package of this name and version is installable here";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "realize_sys"; eg_from = [ "pkg_sys" ];
      eg_to = "lib_sys"; eg_action = Some "fetch_lib";
      eg_tool = "the system PM's unpacker";
      eg_says = "the package's payload is on disk where it claims";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "realize_hdr"; eg_from = [ "pkg_sys" ]; eg_to = "hdr_sys";
      eg_action = Some "fetch_lib"; eg_tool = "the system PM's unpacker";
      eg_says = "the package ships the headers it claims";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "realize_cap"; eg_from = [ "pkg_sys" ]; eg_to = "cap";
      eg_action = None; eg_tool = "the packager";
      eg_says =
        "the capability file describes the payload beside it — and \
         nothing we run reads it";
      eg_diagonal = true; eg_observation = false };
    { eg_id = "build_lib"; eg_from = [ "src_sys" ]; eg_to = "lib_sys";
      eg_action = Some "build_lib"; eg_tool = "the C compiler and linker";
      eg_says = "this source produced this library";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "build_hdr"; eg_from = [ "src_sys" ]; eg_to = "hdr_sys";
      eg_action = Some "build_headers"; eg_tool = "the build system";
      eg_says = "the public headers are where the build puts them";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "stage"; eg_from = [ "lib_sys" ]; eg_to = "staged_sys";
      eg_action = Some "install_lib"; eg_tool = "the install tool";
      eg_says = "what survived being copied out of the build tree";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "depext"; eg_from = [ "bridge" ]; eg_to = "pkg_sys";
      eg_action = None; eg_tool = "the bridge package's depext table";
      eg_says =
        "this virtual capability corresponds to THAT system package — a \
         hand-maintained mapping, reviewed rather than computed";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "depends"; eg_from = [ "pkg_lang" ]; eg_to = "bridge";
      eg_action = Some "fetch_binding"; eg_tool = "the language PM's solver";
      eg_says =
        "the binding package's declared constraint on the bridge is \
         satisfiable";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "conf_probe"; eg_from = [ "bridge" ]; eg_to = "cap";
      eg_action = None; eg_tool = "the bridge package's build predicate";
      eg_says =
        "something on this system answers the capability query — THE \
         DIAGONAL, and the one place the symbolic path touches reality";
      eg_diagonal = true; eg_observation = false };
    { eg_id = "discover"; eg_from = [ "cap" ]; eg_to = "lib_sys";
      eg_action = None; eg_tool = "pkg-config, CMake, a *-config script";
      eg_says =
        "the capability query resolves to THIS library on disk — which \
         may not be the one the world provisioned";
      eg_diagonal = true; eg_observation = false };
    { eg_id = "resolve_lang"; eg_from = [ "pm_lang" ]; eg_to = "pkg_lang";
      eg_action = Some "fetch_binding"; eg_tool = "the language PM's solver";
      eg_says = "the whole dependency set is simultaneously satisfiable";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "install_lang"; eg_from = [ "pkg_lang" ]; eg_to = "mod_lang";
      eg_action = Some "fetch_binding"; eg_tool = "the language PM's installer";
      eg_says =
        "the package put its artifacts in the store — the FETCHED \
         direction of the one edge that runs both ways";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "install_surf"; eg_from = [ "pkg_lang" ]; eg_to = "surf_lang";
      eg_action = Some "fetch_binding"; eg_tool = "the language PM's installer";
      eg_says = "the user-facing surface is installed as the package claims";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "build_stub"; eg_from = [ "src_lang"; "hdr_sys" ];
      eg_to = "stub_lang"; eg_action = Some "build_binding";
      eg_tool = "the C compiler";
      eg_says =
        "the shim's types agree with the header — everything ABOVE the \
         types it did not establish";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "link_mod"; eg_from = [ "stub_lang"; "lib_sys" ];
      eg_to = "mod_lang"; eg_action = Some "build_binding";
      eg_tool = "the linker";
      eg_says = "every symbol the stub requires was resolved";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "pack"; eg_from = [ "mod_lang" ]; eg_to = "pkg_lang";
      eg_action = Some "pack_binding"; eg_tool = "the packaging tool";
      eg_says =
        "a package was assembled from what was built — the BUILT \
         direction of the same edge, and a different relation entirely";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "probe_lib"; eg_from = [ "lib_sys" ]; eg_to = "lib_sys";
      eg_action = Some "probe_lib"; eg_tool = "nm, and nothing else";
      eg_says =
        "the library exists and exports something — STATIC: nothing here \
         loads it";
      eg_diagonal = false; eg_observation = true };
    { eg_id = "run"; eg_from = [ "mod_lang"; "lib_sys" ]; eg_to = "app";
      eg_action = Some "probe_binding"; eg_tool = "the dynamic loader";
      eg_says =
        "it linked, loaded and ran — the only edge with a loader on it";
      eg_diagonal = false; eg_observation = false } ]

(** Every action our graph has, against whether an edge names it. An
    action with no edge is a hole in this model, not in the graph. *)
let actions_covered () : string list =
  List.filter_map edges ~f:(fun e -> e.eg_action)
  |> List.dedup_and_sort ~compare:String.compare

(* ── WHERE EVERY CLAIM SITS ───────────────────────────────────────────

   A placement is a SET of edges, not one, from the start (user,
   2026-09-22: "we can have more advanced agreement that spans several
   edges, so even for the diagram, I wish it can be a generic data
   structure"). Nothing spans two yet. Retrofitting a list onto a scalar
   would touch every row, and the cost of starting with the list is one
   pair of brackets.

   The network analogy is the user's and it is the right one, with one
   asymmetry worth stating. In a network stack both hosts implement the
   SAME protocol at each layer, so a per-layer invariant and an
   end-to-end invariant each have a stated contract to check against.
   Here the horizontal relation at the package layer is a bridge
   somebody wrote, or nothing — not a protocol, and not symmetric. A
   bridge may carry identity while dropping version, which in network
   terms is a layer that forwards the address and silently discards the
   checksum. That is why the end-to-end invariants are the ones we do
   not have. *)

type placement = {
  pl_claim : string;
  pl_edges : string list;  (** edge ids — a SET, see above *)
  pl_implemented : bool;
}

let placements : placement list =
  [ (* --- the library against what the experiment declared ---

       ⚠ TWO EDGES, and the first cut had one. These claims are about the
       LIBRARY NODE, and the node has two producers: a local build and a
       system package's payload. A fetched library is checked exactly as
       a built one is — what differs is whose rule is being recovered
       (our compiler, or a packager's build that happened on someone
       else's machine years ago). Placing them on [build_lib] alone made
       [realize_sys] look bare, which is what caught it: the page said
       nothing checks a package's payload, and something does.

       This is also the multi-edge structure paying for itself on its
       first day rather than hypothetically. *)
    { pl_claim = "declared_symbols_exported";
      pl_edges = [ "build_lib"; "realize_sys" ]; pl_implemented = true };
    { pl_claim = "soname_matches_declaration";
      pl_edges = [ "build_lib"; "realize_sys" ]; pl_implemented = true };
    { pl_claim = "declared_versions_exported";
      pl_edges = [ "build_lib"; "realize_sys" ]; pl_implemented = true };
    { pl_claim = "exports_accounted_for";
      pl_edges = [ "build_lib"; "realize_sys" ]; pl_implemented = false };
    (* --- the binding against the library --- *)
    { pl_claim = "required_symbols_exported"; pl_edges = [ "link_mod" ];
      pl_implemented = true };
    { pl_claim = "soname_matches_requirement"; pl_edges = [ "link_mod" ];
      pl_implemented = true };
    { pl_claim = "required_versions_exported"; pl_edges = [ "link_mod" ];
      pl_implemented = true };
    { pl_claim = "dependencies_provided"; pl_edges = [ "link_mod" ];
      pl_implemented = true };
    { pl_claim = "signatures_agree"; pl_edges = [ "build_stub" ];
      pl_implemented = true };
    { pl_claim = "signatures_match_debug_info"; pl_edges = [ "build_stub" ];
      pl_implemented = false };
    (* --- the package against its own artifacts --- *)
    { pl_claim = "api_names_present"; pl_edges = [ "install_surf" ];
      pl_implemented = true };
    { pl_claim = "package_contains_declared_files";
      pl_edges = [ "install_lang" ]; pl_implemented = false };
    { pl_claim = "repack_preserves_api"; pl_edges = [ "pack" ];
      pl_implemented = true };
    { pl_claim = "repack_complete"; pl_edges = [ "pack" ];
      pl_implemented = true };
    (* --- staging --- *)
    { pl_claim = "staged_interface_preserved"; pl_edges = [ "stage" ];
      pl_implemented = true };
    { pl_claim = "no_build_paths_in_installed_library"; pl_edges = [ "stage" ];
      pl_implemented = false };
    (* --- source --- *)
    { pl_claim = "source_is_declared_ref"; pl_edges = [ "build_lib" ];
      pl_implemented = false };
    { pl_claim = "build_tree_configured_for_source"; pl_edges = [ "build_lib" ];
      pl_implemented = false };
    (* --- runtime: the only claims with a loader under them --- *)
    { pl_claim = "behavior_matches"; pl_edges = [ "run" ];
      pl_implemented = true };
    { pl_claim = "correspondence_holds_across_the_binding";
      pl_edges = [ "run" ]; pl_implemented = false };
    { pl_claim = "no_duplicate_implementation"; pl_edges = [ "run" ];
      pl_implemented = false };
    { pl_claim = "interposition_binds_build_target"; pl_edges = [ "run" ];
      pl_implemented = false };
    { pl_claim = "denotation_stable_across_worlds"; pl_edges = [ "run" ];
      pl_implemented = false };
    { pl_claim = "compatibility_version_satisfied"; pl_edges = [ "link_mod" ];
      pl_implemented = false };
    (* --- the diagonal: the ONE candidate on a cooperation edge --- *)
    { pl_claim = "discovery_matches_link"; pl_edges = [ "discover" ];
      pl_implemented = false } ]

(** The claims sitting on one edge. *)
let placements_on (edge_id : string) : placement list =
  List.filter placements ~f:(fun p ->
      List.mem p.pl_edges edge_id ~equal:String.equal)

(** ⚠ THE CENSUS, and it is the reason this model was worth drawing.
    RELATIONS with no claim on them — each is something a real tool
    established and from which we recover nothing.

    Observations are excluded: [probe_lib] records evidence rather than
    relating two parties, so carrying no claim is its normal state and
    counting it would inflate the one number on this page anybody will
    quote. *)
let bare_edges () : edge list =
  List.filter edges ~f:(fun e ->
      (not e.eg_observation) && List.is_empty (placements_on e.eg_id))

(** ⚠ Claims named in [placements] that no registry row backs. Held at
    zero by a pin: this list is hand-written, so a renamed agreement
    would otherwise leave a placement pointing at nothing and the page
    would keep drawing a badge for a claim that no longer exists. *)
let unknown_placements ~(known : string list) : string list =
  List.filter_map placements ~f:(fun p ->
      if List.mem known p.pl_claim ~equal:String.equal then None
      else Some p.pl_claim)

(** ⚠ Placements naming an edge that does not exist. Same reason. *)
let dangling_placements () : string list =
  List.concat_map placements ~f:(fun p ->
      List.filter p.pl_edges ~f:(fun eid ->
          not (List.exists edges ~f:(fun e -> String.equal e.eg_id eid))))

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
