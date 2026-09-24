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
      somebody wrote. The type is {!Canary_bridge.t}, in base, a variant
      per package manager (user, 2026-09-23);
    - it lives in neither the pure native side nor the pure language
      side, which is exactly why the binding-level view cannot see it;
    - it is OPTIONAL. Two ecosystems may cooperate through a bridge, or
      through nothing but the artifacts themselves — a language package
      that links whatever native library is installed globally has no
      bridge and is not thereby broken.

    ⚠ A CAPABILITY FILE IS NOT A BRIDGE (user, 2026-09-23). It was one
    here — a third constructor beside the conf package and the depext
    field — on the reasoning that the opam/apt topology has two things
    between the ecosystems:

    {v
      conf-gmp   a separate opam package   carries package IDENTITY
                                           (+ the depext mapping)
      gmp.pc     content inside libgmp-dev carries CAPABILITY
                                           (name, version, cflags, libs)
    v}

    Both are real and they can disagree, but they are not the same kind
    of thing. [gmp.pc] belongs to the package that ships it, like a
    META file belongs to its OCaml package; it records how the artifacts
    beside it are built against, and it is a source of claims. conf-gmp's
    own check reads it ([pkg-config --exists gmp]), so what validates the
    symbolic path against artifacts is the BRIDGE's check, not the file.
    The file stays on the topology as {!t.tp_capability}, beside the
    join, and a Cargo [*-sys] topology — no bridge, a capability file —
    is what makes one artifact-centric rather than bridgeless.

    {1 Three findings this derivation surfaced}

    {b (1) The capability file has a name and no instances.}
    [Canary_artifact.Pc_file] is a declared [api_component] and NO
    project declares one — the fourth "declared with no reader" of the
    month, and the most pointed, because its own doc comment says it
    "isn't itself a surface canary checks". That was the right call under
    the surface theory, which is about the BINDING relation: a [.pc] file
    is not binding material. It is cooperation material, and the frame
    that would check it did not exist. So {!capability_files} returns
    what is declared, which is [] everywhere today, and the rendering
    says "undeclared" rather than "none" — an empty list that means
    nobody looked must not read as an answer. (A run now RECORDS the
    [.pc] a conf package's check reads — status.md §2.7 E — which is
    evidence, not a declaration.)

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

(** One bridge as a join carries it: the THING ({!Canary_bridge.t}) and
    whether the binding's constraint on it reaches the C LIBRARY, or only
    the packaging of the check. That second fact is about the [depends]
    edge, not the bridge — [conf-libffi {>= "2.0.0"}] bounds conf-libffi's
    own revision — which is why it rides beside the bridge rather than
    inside it. Measured across the repository at 13 of 370
    (surveys/conf_packages.md §G1a), and carried per project as
    [pm_gate]'s [tracks_lib]. Which version domain a bound reaches is
    the open question status.md §2.7 E defers. *)
type gated = { gb_bridge : Canary_bridge.t; gb_reaches_lib : bool }

let string_of_gated (g : gated) : string =
  match g.gb_bridge with
  | Canary_bridge.Opam (Canary_bridge.Conf_package pkg) ->
      pkg ^ if g.gb_reaches_lib then " (bounds the lib)" else " (presence only)"
  | Canary_bridge.Opam (Canary_bridge.Depext_field _) ->
      Canary_bridge.to_string g.gb_bridge

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
  | Bridged of gated list  (** non-empty, by construction *)
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

(** One cooperation's shape: the two stacks, what joins them, and the
    capability files the native side declares — beside the join rather
    than in it, because a capability file is not a bridge (module
    header). *)
type t = {
  tp_sys : supplier;
  tp_join : joining;
  tp_lang : supplier;
  tp_capability : string list;
}

let bridges_of_join = function Bridged bs -> bs | _ -> []

let string_of_join = function
  | Bridged bs -> String.concat ~sep:" + " (List.map bs ~f:string_of_gated)
  | Artifacts_only -> "(none — artifacts only)"
  | Bridge_absorbed why -> "(absorbed: " ^ why ^ ")"
  | No_pm_between why -> "(no PM between: " ^ why ^ ")"
  | Undeclared_join -> "⚠ UNDECLARED HERE"

(** The short form for a table cell. The long form stays available for
    the row's own detail — a column that silently truncates its own key
    is how two different topologies come to look like one. *)
let short_of_join = function
  | Bridged bs -> String.concat ~sep:" + " (List.map bs ~f:string_of_gated)
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
    cannot drift from the shape it names.

    ⚠ "+ ARTIFACT VALIDATION" COMES FROM THE BRIDGE'S CHECK, not from a
    declared capability file (2026-09-23, the capability file stopped
    being a bridge). The first cut said a conf bridge was "unvalidated
    against artifacts" unless a [.pc] was declared beside it, and no
    project declares one — so every conf row read "unvalidated", while
    every conf package's own predicate is exactly the check that meets
    the artifacts: conf-gmp's is [pkg-config --exists gmp || cc -c
    test.c]. Whether a given RUN saw that check hold is the overview's
    recorded worlds, not this word. *)
let character (t : t) : string =
  let bs = bridges_of_join t.tp_join in
  let has f = List.exists bs ~f:(fun g -> f g.gb_bridge) in
  let has_check = has Canary_bridge.has_check in
  let has_depext = has (fun b -> not (Canary_bridge.has_check b)) in
  let has_cap = not (List.is_empty t.tp_capability) in
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
  | _ when built_side && has_check ->
      "⚠ bridge still gates, against a system this world does not use"
  | _ when built_side -> "no provider ecosystem — the native side is local"
  | _ when has_check -> "symbolic package bridge + artifact validation"
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

(** The bridge a gate names, with whether its constraint reaches the
    library. The two structural cases return [] and that is the right
    answer, not a gap: [Package_builds_lib] and [Bundled] do not weaken a
    bridge, they delete the provider ecosystem, which {!character}
    reports from the supplier instead. *)
let gated_of_gate (g : BD.pm_dep_gate) : gated list =
  match Canary_bridge.of_gate g with
  | None -> []
  | Some b ->
      let reaches_lib =
        match g with
        | BD.Free_with_conf _ -> false
        | BD.Bounded_with_conf { tracks_lib; _ } -> tracks_lib
        (* an exact pin always reaches the library: opam refuses every
           other generation, which is what makes it the hard case — and a
           depext bound names the system package's own version *)
        | BD.Fixed_with_conf _ | BD.Pinned_depext _ -> true
        | BD.Package_builds_lib | BD.Bundled _ -> false
      in
      [ { gb_bridge = b; gb_reaches_lib = reaches_lib } ]

(** The CAPABILITY FILES a project declares: the [Pc_file] components of
    the C API it declares, read through pass 2
    ({!Canary_project_analysis.declared_api_of}). A source of claims,
    beside the join — not a bridge (module header).

    ⚠ THIS WAS WRITTEN AND NEVER CALLED until 2026-09-23 — it and its
    companion were the "declared with no reader" pattern the overview
    page exists to point at, sitting in the module that draws the page.
    What finally wired it was deleting `checks --topology`, whose footer
    was the only place the capability finding was stated, and stated as
    a hand-written sentence. Now the page computes it.

    Empty everywhere today: projects declare [Headers], [Runtime_lib],
    [Link_lib], and no project declares a [Pc_file]. *)
let capability_files (pr : Canary_project_run.project_run) : string list =
  match Canary_project_analysis.declared_api_of pr with
  | None -> []
  | Some api ->
      List.filter_map api.Canary_artifact.native_api.Canary_artifact.components
        ~f:(function
        | Canary_artifact.Pc_file -> Some "pkg-config (.pc)"
        | Canary_artifact.Headers | Canary_artifact.Runtime_lib
        | Canary_artifact.Link_lib ->
            None)

(** TRUE while no project declares a capability file. A view must say
    "undeclared" rather than "none" while this holds: pkg-config is
    demonstrably in use — conf packages' build predicates run it, and our
    own [Pm_lib] locator does — so an empty answer records that nobody
    declared one, not that nothing is there. *)
let no_capability_file_declared
    (projects : (string * Canary_project_run.project_run) list) : bool =
  List.for_all projects ~f:(fun (_, pr) -> List.is_empty (capability_files pr))

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
  (* a declared capability file is NOT part of the join any more: it is
     not a bridge, and it rides on the topology beside the join
     ({!t.tp_capability}) *)
  match gate_of pr lang with
  | None -> Undeclared_join
  | Some None ->
      No_pm_between "no package manager stands between these two artifacts"
  | Some (Some g) -> (
      match gated_of_gate g with
      | [] -> (
          match g with
          | BD.Package_builds_lib ->
              Bridge_absorbed "the consumer package builds the native lib"
          | BD.Bundled what -> Bridge_absorbed ("bundled: " ^ what)
          | BD.Free_with_conf _ | BD.Bounded_with_conf _ | BD.Fixed_with_conf _
          | BD.Pinned_depext _ ->
              Artifacts_only)
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
                        tp_lang = lang_supplier pr lang;
                        tp_capability = capability_files pr },
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
        (* the capability files are part of the shape: they used to ride
           inside the join's string, and a key without them would merge a
           capability-mediated row into a bare one *)
        let key =
          Printf.sprintf "%s|%s|%s|%s" (string_of_supplier t.tp_sys)
            (string_of_join t.tp_join)
            (string_of_supplier t.tp_lang)
            (String.concat ~sep:"," t.tp_capability)
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

(** LAYER keeps its name (user, 2026-09-23, terminology step 0) although
    canary already uses the word for its CODE layers — base/ → agreement/
    → tool/ → … — and `agreement/` is literally "the agreement layer".
    The collision was put to the user and accepted: in the model a layer
    is PM · package · artifact · program, the network sense the layered
    diagram was drawn from.

    [L_oracle] is GONE (2026-09-23). It existed for the declaration node,
    and the declaration stopped being a node — it is a badge on the
    artifacts it speaks about (see [declared_on]) — so a layer for it
    would be a place nothing can be. *)
type layer = L_pm | L_package | L_artifact | L_program

let string_of_layer = function
  | L_pm -> "pm"
  | L_package -> "package"
  | L_artifact -> "artifact"
  | L_program -> "program"

type side = S_sys | S_bridge | S_lang

type node = {
  nd_id : string;
  nd_label : string;  (** the GENERIC name — never a package *)
  nd_layer : layer;
  nd_side : side;
  nd_gloss : string;
}

(** ⚠ THE DECLARATION IS NOT A NODE (user, 2026-09-23: "I still don't get
    the declaration, where will we use it... is it a random place?").
    It was one, and the position WAS arbitrary — it sat between two bands
    because that was the only gap where its box did not cover an edge,
    which is a layout reason wearing a semantic costume.

    What it actually is: the experiment's own statement about ONE
    artifact. Nothing in the chain produces it, it participates in no
    action, and no tool ever enforced it — drawing it as a peer of the
    library implied all three. So it is an ANNOTATION on the nodes it
    speaks about, and this is that annotation: node id → what the spec
    declares there.

    Only two nodes carry one, and between them they account for all four
    declaration-facing claims. That is the whole answer to "where will we
    use it".

    It also explains why those claims behave differently. A claim against
    a declaration cannot fail because two tools disagreed — it fails
    because the world differs from what the experiment SAID it would be,
    which is a defect in the spec exactly as often as in the software.
    That is why [Missing_declaration] is its own [unavailable_cause] and
    why `blame: declaration` exists in the result table. *)
let declared_on : (string * string) list =
  [ ("lib_sys",
     "the c_api's exported functions, the soname, and the symbol-version \
      tags — read by declared_symbols_exported, soname_matches_declaration \
      and declared_versions_exported");
    ("surf_lang",
     "the watchlist of names the binding must offer — read by \
      api_names_present") ]

let declaration_at (id : string) : string option =
  List.Assoc.find declared_on id ~equal:String.equal

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
    (* NOT A BRIDGE (user, 2026-09-23): the package that ships it owns
       it, so it sits on the native side *)
    { nd_id = "cap"; nd_label = "capability file"; nd_layer = L_package;
      nd_side = S_sys;
      nd_gloss =
        "a .pc file, a CMake config, a *-config script: content inside \
         the provider, owned by the package that ships it, recording how \
         the artifacts beside it are built against. Not a bridge — a \
         source of claims, and what a conf package's check reads" };
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
    (* ⚠ THERE ARE TWO CONSUMER PROGRAMS, NOT ONE (user, 2026-09-23),
       and collapsing them lost the more interesting of the two.

       The LOW-LEVEL one lives in the artifact world: it is handed the
       language module and the native library by path, and every input is
       named explicitly. It answers "is the CODE right".

       The HIGH-LEVEL one talks only to the binding PACKAGE, and
       everything else — the module's location, the native library, the
       transitive dependencies — is resolved indirectly by the package
       manager. It answers "is the RECIPE right", which is a different
       question with a different failure mode: an install can omit a file
       the consumer needs, a META can be wrong, a conf chain can fail to
       resolve, and not one of those is visible to the low-level probe.

       THE TWO SHOULD BE THE SAME PROGRAM. That is what makes the pair
       informative rather than merely two tests, and it is already true
       by accident: z3's build-tree probe and its opam-package probe
       both compile `canary/examples/z3/z3_example.ml`. Nothing holds
       them to it. *)
    { nd_id = "consumer_artifact"; nd_label = "consumer (artifact-linked)";
      nd_layer = L_program; nd_side = S_sys;
      nd_gloss =
        "every input named by path — the language module and the native \
         library. Says the CODE is right" };
    { nd_id = "consumer_package"; nd_label = "consumer (package-linked)";
      nd_layer = L_program; nd_side = S_lang;
      nd_gloss =
        "names only the binding package and lets the PM resolve the rest. \
         Says the RECIPE is right — which is the half a build-tree probe \
         cannot see" } ]

let node_by_id id = List.find nodes ~f:(fun n -> String.equal n.nd_id id)

(** An EDGE points from components to a component, and its meaning is
    deliberately left OPEN (user, 2026-09-23, terminology step 0: "the
    backbone meaning is action, but for agreement use case, we just need
    an edge to point to two components, so use edge and leave it meaning
    open").

    So: most edges here are a relation some tool establishes, and their
    annotation names the action of ours that realizes it — that is the
    backbone. But an edge is not REQUIRED to be an action. Where we run
    nothing, the relation is still real, which is itself a finding; and
    [same_program] is an edge between two consumers that no tool
    establishes at all — it exists because a claim needs something to
    point at. The word also means a step-graph dependency elsewhere in
    canary (`step.deps`); the two are not the same thing and nothing here
    converts one into the other. *)

(** WHAT AN EDGE CARRIES (2026-09-23, user: "the edge in the diagram can
    be used to annotate either action, or agreement, or customized
    information"). It was [eg_action : string option] — the name of an
    action or nothing — which could say neither why a relation with no
    action of ours still belongs on the page, nor that one edge is there
    only because of a claim.

    The ACTION is a family ({!Canary_action_family}), because the page is
    language-free and a step is not: [run] is realized by
    [probe_binding_ocaml] in one world and [probe_binding_python] in
    another. *)
type annotation =
  | Action of Canary_action_family.t
      (** an action of ours realizes the relation *)
  | Agreement of string
      (** nothing realizes it but a claim of ours: the agreement's slug *)
  | Info of string
      (** someone else's relation, annotated with what we know about it —
          today a short name for whatever establishes it; what a run
          records about it is phase E's *)

type edge = {
  eg_id : string;
  eg_from : string list;  (** several inputs: an action is n-ary *)
  eg_to : string;
  eg_annotation : annotation;
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
      eg_annotation = Action Canary_action_family.Fetch_lib; eg_tool = "the system PM's solver";
      eg_says = "a package of this name and version is installable here";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "realize_sys"; eg_from = [ "pkg_sys" ];
      eg_to = "lib_sys"; eg_annotation = Action Canary_action_family.Fetch_lib;
      eg_tool = "the system PM's unpacker";
      eg_says = "the package's payload is on disk where it claims";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "realize_hdr"; eg_from = [ "pkg_sys" ]; eg_to = "hdr_sys";
      eg_annotation = Action Canary_action_family.Fetch_lib; eg_tool = "the system PM's unpacker";
      eg_says = "the package ships the headers it claims";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "realize_cap"; eg_from = [ "pkg_sys" ]; eg_to = "cap";
      eg_annotation = Info "packager"; eg_tool = "the packager";
      eg_says =
        "the capability file describes the payload beside it — and \
         nothing we run reads it";
      eg_diagonal = true; eg_observation = false };
    { eg_id = "build_lib"; eg_from = [ "src_sys" ]; eg_to = "lib_sys";
      eg_annotation = Action Canary_action_family.Build_lib;
      eg_tool = "the C compiler and linker";
      eg_says = "this source produced this library";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "build_hdr"; eg_from = [ "src_sys" ]; eg_to = "hdr_sys";
      eg_annotation = Action Canary_action_family.Build_headers;
      eg_tool = "the build system";
      eg_says = "the public headers are where the build puts them";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "stage"; eg_from = [ "lib_sys" ]; eg_to = "staged_sys";
      eg_annotation = Action Canary_action_family.Install_lib;
      eg_tool = "the install tool";
      eg_says = "what survived being copied out of the build tree";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "depext"; eg_from = [ "bridge" ]; eg_to = "pkg_sys";
      eg_annotation = Info "depext table";
      eg_tool = "the bridge package's depext table";
      eg_says =
        "this virtual capability corresponds to THAT system package — a \
         hand-maintained mapping, reviewed rather than computed";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "depends"; eg_from = [ "pkg_lang" ]; eg_to = "bridge";
      eg_annotation = Action Canary_action_family.Fetch_binding; eg_tool = "the language PM's solver";
      eg_says =
        "the binding package's declared constraint on the bridge is \
         satisfiable";
      eg_diagonal = false; eg_observation = false };
    (* AN ACTION SINCE 2026-09-23 (user: an edge is an action when the
       package manager dispatches a separate, observable action). opam
       builds a conf package as a package of its own, and its build IS
       the check — part of installing the binding, which is why the
       family is the install's. A step that drives the bridge realizes
       it; the install itself does not, because in a switch that already
       holds the bridge opam dispatches nothing. *)
    { eg_id = "conf_probe"; eg_from = [ "bridge" ]; eg_to = "cap";
      eg_annotation = Action Canary_action_family.Fetch_binding;
      eg_tool =
        "the bridge package's check — dispatched by the language PM when \
         it installs the bridge, and by canary in every world";
      eg_says =
        "something on this system answers the capability query — THE \
         DIAGONAL, and the one place the symbolic path touches reality";
      eg_diagonal = true; eg_observation = false };
    { eg_id = "discover"; eg_from = [ "cap" ]; eg_to = "lib_sys";
      eg_annotation = Info "pkg-config";
      eg_tool = "pkg-config, CMake, a *-config script";
      eg_says =
        "the capability query resolves to THIS library on disk — which \
         may not be the one the world provisioned";
      eg_diagonal = true; eg_observation = false };
    { eg_id = "resolve_lang"; eg_from = [ "pm_lang" ]; eg_to = "pkg_lang";
      eg_annotation = Action Canary_action_family.Fetch_binding; eg_tool = "the language PM's solver";
      eg_says = "the whole dependency set is simultaneously satisfiable";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "install_lang"; eg_from = [ "pkg_lang" ]; eg_to = "mod_lang";
      eg_annotation = Action Canary_action_family.Fetch_binding; eg_tool = "the language PM's installer";
      eg_says =
        "the package put its artifacts in the store — the FETCHED \
         direction of the one edge that runs both ways";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "install_surf"; eg_from = [ "pkg_lang" ]; eg_to = "surf_lang";
      eg_annotation = Action Canary_action_family.Fetch_binding; eg_tool = "the language PM's installer";
      eg_says = "the user-facing surface is installed as the package claims";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "build_stub"; eg_from = [ "src_lang"; "hdr_sys" ];
      eg_to = "stub_lang"; eg_annotation = Action Canary_action_family.Build_binding;
      eg_tool = "the C compiler";
      eg_says =
        "the shim's types agree with the header — everything ABOVE the \
         types it did not establish";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "link_mod"; eg_from = [ "stub_lang"; "lib_sys" ];
      eg_to = "mod_lang"; eg_annotation = Action Canary_action_family.Build_binding;
      eg_tool = "the linker";
      eg_says = "every symbol the stub requires was resolved";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "pack"; eg_from = [ "mod_lang" ]; eg_to = "pkg_lang";
      eg_annotation = Action Canary_action_family.Pack_binding;
      eg_tool = "the packaging tool";
      eg_says =
        "a package was assembled from what was built — the BUILT \
         direction of the same edge, and a different relation entirely";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "probe_lib"; eg_from = [ "lib_sys" ]; eg_to = "lib_sys";
      eg_annotation = Action Canary_action_family.Probe_lib;
      eg_tool = "nm, and nothing else";
      eg_says =
        "the library exists and exports something — STATIC: nothing here \
         loads it";
      eg_diagonal = false; eg_observation = true };
    { eg_id = "run"; eg_from = [ "mod_lang"; "lib_sys" ];
      eg_to = "consumer_artifact"; eg_annotation = Action Canary_action_family.Probe_binding;
      eg_tool = "the linker and the dynamic loader";
      eg_says =
        "it linked, loaded and ran when we named every input ourselves";
      eg_diagonal = false; eg_observation = false };
    { eg_id = "run_packaged"; eg_from = [ "pkg_lang" ];
      eg_to = "consumer_package"; eg_annotation = Action Canary_action_family.Probe_binding;
      eg_tool =
        "the language PM's RESOLUTION — ocamlfind and META, pip's \
         metadata — and then the loader";
      eg_says =
        "naming only the package was enough to build and run the same \
         program: the recipe resolves to everything the code needs";
      eg_diagonal = false; eg_observation = false };
    (* THE AGREEMENT EDGE, and the reason for splitting the node. Two
       programs from ONE source, resolved two ways, must agree. Where
       they do not, the package is at fault and the code is not — which
       no other edge in this graph can tell you. *)
    { eg_id = "same_program"; eg_from = [ "consumer_artifact" ];
      eg_to = "consumer_package";
      (* the one edge a CLAIM carries: the end-to-end candidate that the
         package-linked program does what the hand-resolved one did *)
      eg_annotation = Agreement "package_resolution_suffices";
      eg_tool = "nobody — this is ours to check";
      eg_says =
        "the same source, resolved through the package instead of by \
         hand, does the same thing";
      eg_diagonal = false; eg_observation = false } ]

(** The action families some edge carries, in edge order. *)
let families_on_edges () : Canary_action_family.t list =
  List.filter_map edges ~f:(fun e ->
      match e.eg_annotation with Action f -> Some f | Agreement _ | Info _ -> None)
  |> List.fold ~init:[] ~f:(fun acc f ->
         if List.mem acc f ~equal:Canary_action_family.equal then acc
         else acc @ [ f ])

(** THE CATALOGUE'S ACTIONS WITH NO EDGE (2026-09-23, status.md §2.6 step
    1: "COMPUTE which actions have no edge from the catalogue — the
    missing-steps list, derived rather than asserted"). An action the
    catalogue can run and this graph cannot place is a hole in the MODEL,
    not in the graph. The page prints this list; it used to print a
    sentence naming two of them. *)
let families_without_edge () : Canary_action_family.t list =
  let placed = families_on_edges () in
  List.filter (Canary_action_family.of_catalogue ()) ~f:(fun f ->
      not (List.mem placed f ~equal:Canary_action_family.equal))

(* ── WHERE A RECORDED STEP SITS (2026-09-23, status.md §2.7 phase B2) ──

   The join from a run's steps onto this graph. The rule is short: a
   step realizes the edges annotated with its action FAMILY, narrowed by
   what the step and the world say. Only an [Action] annotation can be
   realized — [Info] names someone else's rule, which our step may set
   off (installing an opam package runs its conf predicate) but does not
   perform.

   Every step lands somewhere, and "nowhere" carries a reason, so a step
   the page cannot place is a listed gap rather than a silent omission. *)

(** Why a step has no edge. Typed so the guard can LIST the gaps and fail
    on a new kind — each one is a page error or a model gap, and deciding
    which is the work. *)
type unplaced =
  | No_edge_for_family
      (** no edge on the page is annotated with this action family *)
  | Observes_staged_copy
      (** a probe of the install-prefix copy: that node has no
          observation edge *)
  | Observes_unused_system_copy
      (** a probe of the system package's library in a world whose
          library is not that package's *)
  | Lib_from_language_pm
      (** the library arrived through a language package manager — the
          unified case, which has no edge from that side to the library *)
  | Does_no_work
      (** a dummy step: it holds a place in the graph and performs nothing *)
  | Unexpected of string
      (** a combination the rules do not cover — the guard fails on it *)

(* the stable word a record carries for each; [string_of_unplaced] is
   the sentence *)
let code_of_unplaced = function
  | No_edge_for_family -> "no_edge"
  | Observes_staged_copy -> "staged_copy"
  | Observes_unused_system_copy -> "unused_system_copy"
  | Lib_from_language_pm -> "lib_from_language_pm"
  | Does_no_work -> "dummy"
  | Unexpected _ -> "unexpected"

let string_of_unplaced = function
  | No_edge_for_family -> "no edge for this action on the page"
  | Observes_staged_copy -> "observes the staged copy, which has no observation edge"
  | Observes_unused_system_copy ->
      "observes the system package's library, which this world does not use"
  | Lib_from_language_pm ->
      "the library comes from a language package manager: no edge from there"
  | Does_no_work -> "a dummy step: it performs nothing"
  | Unexpected why -> "UNEXPECTED: " ^ why

type place =
  | On of string list  (** the edges this step realizes, by id *)
  | Evidence_for of string
      (** an inspection: it records evidence about the step named and
          realizes no relation of its own — its outcomes belong to claim
          badges, not to an edge's colour *)
  | Placeholder_for of string list
      (** a placeholder step (2026-09-23): the edges whose relation a
          package manager established INSIDE the parent action, unseen by
          canary. It realizes nothing either — it marks, on those edges,
          what is not recorded and why *)
  | Unplaced of unplaced

(** The world's artifact of one kind: its provision there, and the
    provider its row declares for a fetch. *)
let origin_of ~(pr : Canary_project_run.project_run)
    ~(world : Canary_artifact.assignment) (k : Canary_basic.artifact_kind) :
    (Canary_store.provision * SC.provider option) option =
  List.find_map world ~f:(fun (id, (pl : Canary_artifact.placement)) ->
      if Poly.equal (Canary_artifact.kind_of id) k then
        Some (pl.Canary_artifact.provision, Canary_project_run.provenance_of pr id)
      else None)

(* WHAT A FETCH ASKED — the provider — which is not the same question as
   where the world's artifact comes from. A vendored world still runs its
   fetch: zstd's installs libzstd-dev beside the prebuilt it uses, and
   that install realizes the system package's edges all the same. The
   first cut read the world's provision here and called the fetch a
   supplied copy. *)
let fetched_from ~pr ~world k : SC.provider option =
  Option.bind (origin_of ~pr ~world k) ~f:snd

(** WHERE A PLACEHOLDER SITS: on the edges whose relation the package
    manager established inside the fetch. Resolving a system package is
    [resolve_sys]; resolving a binding's package is [resolve_lang]; and
    building a binding's package from source inside the package manager
    is where the stub was compiled against the headers, the module linked
    against the library, and pkg-config asked by the package's configure
    — the edges a world that FETCHES its binding otherwise has nothing
    on, although every one of those relations was established. *)
let placeholder_place ~pr ~world ~(action : Canary_basic.action)
    (ph : Canary_pm_action.placeholder) : place =
  match (action, ph.Canary_pm_action.ph_does) with
  | Canary_basic.Fetch Canary_basic.Lib, Canary_pm_action.Resolve -> (
      match fetched_from ~pr ~world Canary_basic.Lib with
      | Some (SC.Sys_pkg _) -> Placeholder_for [ "resolve_sys" ]
      | Some (SC.Lang_pkg _) -> Unplaced Lib_from_language_pm
      | _ -> Unplaced (Unexpected "a library fetch from no package"))
  | Canary_basic.Fetch (Canary_basic.Binding _), Canary_pm_action.Resolve ->
      Placeholder_for [ "resolve_lang" ]
  | Canary_basic.Fetch (Canary_basic.Binding _), Canary_pm_action.Build_package ->
      Placeholder_for [ "build_stub"; "link_mod"; "discover" ]
  | _ -> Unplaced (Unexpected "a placeholder for an action the graph does not place")

(** THE RULE. [location], [inspects], [dummy], [bridge] and
    [placeholder] are the step's own fields ([Canary_step_model.step]);
    the world and the project answer what the step alone cannot — where
    the library came from, and whether a bridge sits between the binding
    package and the system. *)
let place_step ~(pr : Canary_project_run.project_run)
    ~(world : Canary_artifact.assignment) ~(action : Canary_basic.action)
    ~(location : Canary_store.location option) ~(inspects : string option)
    ~(dummy : string option) ~(bridge : Canary_bridge.t option)
    ~(placeholder : Canary_pm_action.placeholder option) : place =
  let fam = Canary_action_family.of_action action in
  let candidates =
    List.filter_map edges ~f:(fun e ->
        match e.eg_annotation with
        | Action f when Canary_action_family.equal f fam -> Some e.eg_id
        | Action _ | Agreement _ | Info _ -> None)
  in
  let keep ids =
    List.filter candidates ~f:(fun c -> List.mem ids c ~equal:String.equal)
  in
  match (inspects, dummy, placeholder) with
  | Some parent, _, _ -> Evidence_for parent
  | None, Some _, _ -> Unplaced Does_no_work
  | None, None, Some ph -> placeholder_place ~pr ~world ~action ph
  | None, None, None -> (
      if List.is_empty candidates then Unplaced No_edge_for_family
      else
        match (bridge, action) with
        (* a step that drives a bridge realizes the bridge's check and
           nothing of the install whose action it carries *)
        | Some b, _ ->
            if Canary_bridge.has_check b then On (keep [ "conf_probe" ])
            else Unplaced (Unexpected "a bridge step for a bridge with no check")
        | None, _ ->
        match action with
        | Canary_basic.Probe_binding _ -> (
            (* THE CONSUMER PROGRAM IS THE LOCATION: named by package, or
               handed every input by path (status.md §2.7, B1) *)
            match location with
            | Some (Canary_store.Pm (Canary_store.Lang_pm _)) ->
                On (keep [ "run_packaged" ])
            | Some (Canary_store.Build_tree | Canary_store.Staged) ->
                On (keep [ "run" ])
            | Some (Canary_store.Pm (Canary_store.Sys_pm _)) | None ->
                Unplaced (Unexpected "a binding probe with no binding location"))
        | Canary_basic.Probe_lib -> (
            match location with
            | Some Canary_store.Staged -> Unplaced Observes_staged_copy
            | Some (Canary_store.Pm (Canary_store.Sys_pm _)) -> (
                match origin_of ~pr ~world Canary_basic.Lib with
                | Some (Canary_store.Fetched, _) -> On candidates
                | _ -> Unplaced Observes_unused_system_copy)
            | _ -> On candidates)
        | Canary_basic.Fetch Canary_basic.Lib -> (
            match fetched_from ~pr ~world Canary_basic.Lib with
            | Some (SC.Sys_pkg _) -> On candidates
            | Some (SC.Lang_pkg _) -> Unplaced Lib_from_language_pm
            | _ -> Unplaced (Unexpected "a library fetch from no package"))
        | Canary_basic.Fetch (Canary_basic.Binding lang) -> (
            match fetched_from ~pr ~world (Canary_basic.Binding lang) with
            | Some (SC.Lang_pkg _) ->
                (* the constraint on a bridge is resolved only where a
                   bridge is declared: a conf package, or a depext bound
                   inside the package *)
                let symbolic =
                  not (List.is_empty (bridges_of_join (join_of pr lang)))
                in
                On
                  (keep
                     ((if symbolic then [ "depends" ] else [])
                     @ [ "resolve_lang"; "install_lang"; "install_surf" ]))
            | _ -> Unplaced (Unexpected "a binding fetch from no language package"))
        | _ -> On candidates)

(* ── THE ARTIFACT BAND IS ONE BINDING MECHANISM ───────────────────────

   (user, 2026-09-22: "for the artifact layer, this is actually one
   binding mechanism, so it opens one choice of table 2".) Correct, and
   it is the structural point the first drawing hid: the band as drawn —
   headers, a compiled stub, a language module — is the C-SHIM shape.
   A ctypes binding compiles nothing and has no stub node at all; its
   library is not linked but dlopen'd at import, so two of the edges do
   not merely go quiet, they do not exist.

   So the whole diagram is the JOIN of one artifact-layer row (a
   mechanism — the binding table) with one package-and-PM row (a
   topology — the cooperation table). Neither table alone draws a
   chain; the pair does.

   Every field below is read from [Canary_mechanism.mechanism_catalogue]
   rather than restated: [mi_compiles_a_stub] is exactly the question
   "is there a stub node", and it is already answered there. *)

type artifact_variant = {
  av_mechanism : Canary_mechanism.mechanism;
  av_lang : Canary_lang.lang;
  av_hidden : string list;  (** node and edge ids this shape does not have *)
  av_note : string;
  av_wired : bool;  (** does a live project bind through it today *)
}

let artifact_variant_of (m : Canary_mechanism.mechanism) : artifact_variant =
  let i = Canary_mechanism.info_of_mechanism m in
  let base =
    { av_mechanism = m;
      av_lang = i.Canary_mechanism.mi_lang;
      av_hidden = [];
      av_note = "";
      av_wired = i.Canary_mechanism.mi_wired }
  in
  if not i.Canary_mechanism.mi_compiles_a_stub then
    { base with
      (* nothing is compiled on the consumer side, so there is no stub
         artifact, nothing links, and the library is bound at IMPORT by
         name. [build_stub] and [link_mod] do not exist here — and the
         claims that sat on them have nothing to read, which is why a
         dynamic binding's coverage is thin for a reason rather than by
         neglect *)
      av_hidden = [ "stub_lang"; "build_stub"; "link_mod" ];
      av_note =
        "Nothing is compiled on the consumer side. The library is opened \
         by name at import and symbols resolve per call, so there is no \
         stub artifact to read and no link step to recover anything \
         from — the probe's own failure is the evidence."
        ^
        if i.Canary_mechanism.mi_exposes_typed_stub then
          " A cdef still RE-DECLARES the C surface, so a typed boundary \
           exists as a declaration even though no object carries it."
        else "" }
  else
    { base with
      av_note =
        "A compiled artifact sits between the language and the library, \
         so it records what it requires — which is what makes the \
         link-time claims decidable at all."
        ^
        if i.Canary_mechanism.mi_consumer_records_needed then
          " It also records NEEDED and its version requirements."
        else
          " Its archive records no NEEDED or SONAME — those appear when \
           the consumer executable is linked." }

let artifact_variants () : artifact_variant list =
  List.map Canary_mechanism.mechanism_catalogue
    ~f:(fun (i : Canary_mechanism.mechanism_info) ->
      artifact_variant_of i.Canary_mechanism.mi_mechanism)

(* ── WHERE EVERY CLAIM SITS ───────────────────────────────────────────

   A CLAIM SITE — where on the layered graph a claim sits. Named so on
   2026-09-23 (user, terminology step 0); it was called a "placement",
   which is base vocabulary for something else entirely:
   [Canary_artifact.placement] is an artifact's provision and version in
   one world, and the test file used both senses a few hundred lines
   apart.

   A claim site is a SET of edges, not one, from the start (user,
   2026-09-22: "we can have more advanced agreement that spans several
   edges, so even for the diagram, I wish it can be a generic data
   structure"). Retrofitting a list onto a scalar would touch every row,
   and the cost of starting with the list is one pair of brackets.

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

type claim_site = {
  cs_claim : string;
  cs_edges : string list;  (** edge ids — a SET, see above *)
  cs_implemented : bool;
}

let claim_sites : claim_site list =
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
    { cs_claim = "declared_symbols_exported";
      cs_edges = [ "build_lib"; "realize_sys" ]; cs_implemented = true };
    { cs_claim = "soname_matches_declaration";
      cs_edges = [ "build_lib"; "realize_sys" ]; cs_implemented = true };
    { cs_claim = "declared_versions_exported";
      cs_edges = [ "build_lib"; "realize_sys" ]; cs_implemented = true };
    { cs_claim = "exports_accounted_for";
      cs_edges = [ "build_lib"; "realize_sys" ]; cs_implemented = false };
    (* --- the binding against the library --- *)
    { cs_claim = "required_symbols_exported"; cs_edges = [ "link_mod" ];
      cs_implemented = true };
    { cs_claim = "soname_matches_requirement"; cs_edges = [ "link_mod" ];
      cs_implemented = true };
    { cs_claim = "required_versions_exported"; cs_edges = [ "link_mod" ];
      cs_implemented = true };
    { cs_claim = "dependencies_provided"; cs_edges = [ "link_mod" ];
      cs_implemented = true };
    { cs_claim = "signatures_agree"; cs_edges = [ "build_stub" ];
      cs_implemented = true };
    { cs_claim = "signatures_match_debug_info"; cs_edges = [ "build_stub" ];
      cs_implemented = false };
    (* --- the package against its own artifacts --- *)
    { cs_claim = "api_names_present"; cs_edges = [ "install_surf" ];
      cs_implemented = true };
    { cs_claim = "package_contains_declared_files";
      cs_edges = [ "install_lang" ]; cs_implemented = false };
    { cs_claim = "repack_preserves_api"; cs_edges = [ "pack" ];
      cs_implemented = true };
    { cs_claim = "repack_complete"; cs_edges = [ "pack" ];
      cs_implemented = true };
    (* --- staging --- *)
    { cs_claim = "staged_interface_preserved"; cs_edges = [ "stage" ];
      cs_implemented = true };
    { cs_claim = "no_build_paths_in_installed_library"; cs_edges = [ "stage" ];
      cs_implemented = false };
    (* --- source --- *)
    { cs_claim = "source_is_declared_ref"; cs_edges = [ "build_lib" ];
      cs_implemented = false };
    { cs_claim = "build_tree_configured_for_source"; cs_edges = [ "build_lib" ];
      cs_implemented = false };
    (* --- runtime: the only claims with a loader under them --- *)
    { cs_claim = "behavior_matches"; cs_edges = [ "run" ];
      cs_implemented = true };
    { cs_claim = "correspondence_holds_across_the_binding";
      cs_edges = [ "run" ]; cs_implemented = false };
    { cs_claim = "no_duplicate_implementation"; cs_edges = [ "run" ];
      cs_implemented = false };
    { cs_claim = "interposition_binds_build_target"; cs_edges = [ "run" ];
      cs_implemented = false };
    { cs_claim = "denotation_stable_across_worlds"; cs_edges = [ "run" ];
      cs_implemented = false };
    (* ⚠ THE FIRST END-TO-END CLAIM. Every claim site above sits on one
       edge — a per-layer invariant, in the network analogy. This one
       spans three: the PM resolved, the package realized what it
       promised, and the program built from the package alone did what
       the hand-resolved one did. It is the kind the asymmetry between
       apt and opam makes hard and the kind we had none of. *)
    { cs_claim = "package_resolution_suffices";
      cs_edges = [ "resolve_lang"; "run_packaged"; "same_program" ];
      cs_implemented = false };
    { cs_claim = "compatibility_version_satisfied"; cs_edges = [ "link_mod" ];
      cs_implemented = false };
    (* --- the diagonal: the first candidate on a cooperation edge --- *)
    { cs_claim = "discovery_matches_link"; cs_edges = [ "discover" ];
      cs_implemented = false };
    (* --- THE BRIDGE'S CLAIMS (2026-09-23, status.md §2.7 E): placeholders
       for what a bridge states, on the edges where it states it. Each has
       its evidence recorded for zarith and no comparator yet, so each is a
       candidate badge — the bridge edges stop reading as bare because the
       CLAIM is known, not because anything decides it. --- *)
    { cs_claim = "gate_admits_the_world"; cs_edges = [ "conf_probe" ];
      cs_implemented = false };
    { cs_claim = "declared_gate_matches_package"; cs_edges = [ "depends" ];
      cs_implemented = false };
    { cs_claim = "gate_bounds_the_library"; cs_edges = [ "depends"; "conf_probe" ];
      cs_implemented = false };
    { cs_claim = "depext_names_the_provided_package"; cs_edges = [ "depext" ];
      cs_implemented = false } ]

(** The claims sitting on one edge. *)
let claim_sites_on (edge_id : string) : claim_site list =
  List.filter claim_sites ~f:(fun p ->
      List.mem p.cs_edges edge_id ~equal:String.equal)

(** ⚠ THE CENSUS, and it is the reason this model was worth drawing.
    RELATIONS with no claim on them — each is something a real tool
    established and from which we recover nothing.

    Observations are excluded: [probe_lib] records evidence rather than
    relating two parties, so carrying no claim is its normal state and
    counting it would inflate the one number on this page anybody will
    quote. *)
let bare_edges () : edge list =
  List.filter edges ~f:(fun e ->
      (not e.eg_observation) && List.is_empty (claim_sites_on e.eg_id))

(** ⚠ Claims named in [claim_sites] that no registry row backs. Held at
    zero by a pin: this list is hand-written, so a renamed agreement
    would otherwise leave a claim site pointing at nothing and the page
    would keep drawing a badge for a claim that no longer exists. *)
let unknown_claim_sites ~(known : string list) : string list =
  List.filter_map claim_sites ~f:(fun p ->
      if List.mem known p.cs_claim ~equal:String.equal then None
      else Some p.cs_claim)

(** ⚠ Claim sites naming an edge that does not exist. Same reason. *)
let dangling_claim_sites () : string list =
  List.concat_map claim_sites ~f:(fun p ->
      List.filter p.cs_edges ~f:(fun eid ->
          not (List.exists edges ~f:(fun e -> String.equal e.eg_id eid))))

(* The terminal view [pp_topologies] was DELETED 2026-09-23 (user: it
   printed facts the overview page already shows). Its two footnotes —
   the unreachable gates and the undeclared capability bridge — were the
   only things it said that the page did not, and both moved to the
   page's topology section, the second now computed by
   {!no_capability_bridge_declared} rather than written as a sentence. *)
