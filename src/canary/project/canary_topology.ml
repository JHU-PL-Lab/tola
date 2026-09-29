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

    {b (3) Four projects' gates were declared where this could not read
    them.} [Canary_opam_binding] sets [pr_binding_decls = []] and kept
    its gate on the template's own record, so cairo, libffi, zlib and
    zstd declared a [pm_gate] that no consumer reached. That is
    [project/issues.md] §2 — a mechanism declared in two places, one of
    them read — arriving at its SECOND consumer. For a while it was not
    worked around: {!gate_of} returned [None] and the table showed the
    gap as "undeclared", because a silently short table is worse than a
    visibly incomplete one. CLOSED 2026-09-24 (user: every package canary
    runs carries a cooperation, and it can be known before any run): the
    GATE alone is routed, through [pr_pm_gates], because nothing else
    reads it. The DECLARATION is still not routed — that would route its
    mechanism too, which flips four green libffi cells, a
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

(* ── THE COOPERATION TABLE (2026-09-23, user: "we can have pm-solo table,
   pm-coop table which canary covers") ─────────────────────────────────

   A KIND of cooperation is a row of canary's PM-cooperation table; a
   topology [t] is one instance of it. A chain is one binding mechanism
   between two package managers (two rows of the PM-solo table,
   [Canary_pm_solo]) joined by one of these.

   Canary's own table, not the layered-model draft's Table 3: its rows
   are the kinds this derivation can tell apart, and only those some
   project instantiates are drawn — the rest are listed as classified and
   not yet covered. The draft's names are carried beside canary's where
   one exists. *)

type coop =
  | Co_conf  (** a conf package between the binding package and the system's *)
  | Co_gated_local
      (** the native side is local — built, staged or vendored here — and
          the binding package's gate still checks the system *)
  | Co_unified  (** one package manager supplies both sides *)
  | Co_absorbed  (** the consumer package builds or bundles the library *)
  | Co_no_pm  (** no package manager stands between the two artifacts *)
  | Co_undeclared  (** the gate is declared where this cannot read it *)
  | Co_depext  (** the binding package names the system package directly *)
  | Co_capability  (** no bridge; a declared capability file is the join *)
  | Co_artifacts  (** no bridge and no capability file: artifacts only *)
  | Co_local  (** the native side is built here and nothing gates it *)
  | Co_incomplete  (** one side is declared absent *)

(** The kind of one topology. THE decision order — [character] reads it,
    so the table's rows and the instance names cannot disagree.

    ⚠ THE BRIDGE IS NOT SILENCED BY A LOCAL BUILD, and the first cut
    assumed it was — it matched the supplier before the join and so
    reported llvm's built-lib world as having no bridge while
    `conf-llvm-shared {= "19"}` was still in the package's depends. opam
    runs that predicate against the SYSTEM whatever this world built, so
    the bridge fires and validates something the world is not using —
    exactly the situation `gate_admits_the_world` names. *)
let coop_of (t : t) : coop =
  let bs = bridges_of_join t.tp_join in
  let has f = List.exists bs ~f:(fun g -> f g.gb_bridge) in
  let has_check = has Canary_bridge.has_check in
  let has_depext = has (fun b -> not (Canary_bridge.has_check b)) in
  let has_cap = not (List.is_empty t.tp_capability) in
  let built_side =
    match t.tp_sys with Built_here | Staged | Vendored -> true | _ -> false
  in
  match (t.tp_sys, t.tp_lang, t.tp_join) with
  | _, _, Undeclared_join -> Co_undeclared
  | _, _, No_pm_between _ -> Co_no_pm
  | _, _, Bridge_absorbed _ -> Co_absorbed
  | Unsupplied, _, _ | _, Unsupplied, _ -> Co_incomplete
  | By_pm a, By_pm b, _ when Poly.equal a b -> Co_unified
  | _ when built_side && has_check -> Co_gated_local
  | _ when built_side -> Co_local
  | _ when has_check -> Co_conf
  | _ when has_depext -> Co_depext
  | _ when has_cap -> Co_capability
  | _ -> Co_artifacts

(** One row of the cooperation table. *)
type coop_info = {
  co_kind : coop;
  co_label : string;  (** a button's worth of [co_name] *)
  co_name : string;  (** canary's name for it — the "character" *)
  co_draft : string;  (** the layered-model draft's name, where it has one *)
  co_package_join : string;  (** how the two package layers are joined *)
  co_artifact_join : string;  (** what, if anything, meets the artifacts *)
  co_versions : string;  (** how a version constraint travels, if at all *)
  co_recorded : string;  (** what canary records of it *)
}

let coop_catalogue : coop_info list =
  [ { co_kind = Co_conf;
      co_label = "conf package";
      co_name = "symbolic package bridge + artifact validation";
      co_draft = "the same name (opam conf/depext with apt or Homebrew)";
      co_package_join =
        "binding package → conf-* → depext → system package: identity \
         travels by NAME, through a package somebody wrote";
      co_artifact_join =
        "the conf package's check asks the system — pkg-config, or a \
         compile test — whether the capability is there";
      co_versions =
        "a bound on the conf package bounds the library only where its \
         check enforces a version (13 of 370 conf packages do); elsewhere \
         it bounds the check's packaging";
      co_recorded =
        "the bridge step runs the check in every world and records the \
         mapping, the capability file and pkg-config's answer (zarith so \
         far); opam's own run of the check is a placeholder" };
    (* the native side is built, staged or VENDORED here: sqlite's built
       worlds, and since the template's gates were routed (2026-09-24) the
       vendored worlds of cairo, libffi, zlib and zstd — a conda-forge
       prebuilt, while their opam packages' conf gate checks apt's copy *)
    { co_kind = Co_gated_local;
      co_label = "gated, local library";
      co_name = "⚠ bridge still gates, against a system this world does not use";
      co_draft =
        "a package-specific rewrite — replace(external_provider, \
         internal_build or a prebuilt) — that left the gate in place";
      co_package_join = "the binding package's conf dependency is still resolved";
      co_artifact_join =
        "the conf check asks the SYSTEM, while the binding links the \
         library this world built or was handed";
      co_versions =
        "none that reaches the library in use: the gate validates one the \
         world does not use";
      co_recorded =
        "the library's build or its prebuilt; the gate itself is not \
         recorded here" };
    { co_kind = Co_unified;
      co_label = "one package manager";
      co_name = "unified package universe";
      co_draft = "the same name (Conda)";
      co_package_join =
        "one package manager supplies both sides; the binding package \
         names the library's package in its own namespace";
      co_artifact_join = "the linker and the loader, over files one store holds";
      co_versions = "one solver: a bound on the library's package bounds the library";
      co_recorded = "both fetches, through the one package manager" };
    { co_kind = Co_absorbed;
      co_label = "absorbed";
      co_name = "absorbed by the consumer package";
      co_draft =
        "a package-specific rewrite — bundle(native_artifact) or \
         replace(external_provider, internal_build)";
      co_package_join =
        "none: the consumer package builds or ships the library, so there \
         is no second ecosystem";
      co_artifact_join = "inside the package: its own build, or the wheel";
      co_versions = "no pairing: the library's version is the package's";
      co_recorded = "the package's fetch; what it builds inside is a placeholder" };
    { co_kind = Co_no_pm;
      co_label = "no PM between";
      co_name = "no package manager between";
      co_draft = "not in the draft's tables";
      co_package_join =
        "none: whoever built the interpreter joined the extension to the \
         library";
      co_artifact_join = "the loader resolves the extension's recorded dependency";
      co_versions = "none is declared anywhere";
      co_recorded =
        "a dummy step holds the binding's place; the relations the \
         interpreter's build and install made read included" };
    { co_kind = Co_undeclared;
      co_label = "undeclared";
      co_name = "⚠ undeclared — cannot be classified";
      co_draft = "not a cooperation — a gap in canary's declarations";
      co_package_join =
        "unknown: the gate is declared on the opam-binding template's \
         record, which this derivation cannot read (project/issues.md §2)";
      co_artifact_join = "unknown";
      co_versions = "unknown";
      co_recorded = "the fetches, as for any project" };
    { co_kind = Co_depext;
      co_label = "direct depext";
      co_name = "direct depext — package identity, no conf hop";
      co_draft = "a package-specific bridge — add(custom_bridge)";
      co_package_join = "the binding package names the system package itself";
      co_artifact_join = "none of the bridge's own";
      co_versions = "the depext's bound names the system package's version";
      co_recorded = "the fetches" };
    { co_kind = Co_capability;
      co_label = "capability file";
      co_name = "artifact-centric, capability-mediated";
      co_draft = "declarative capability-mediated (Cabal with apt)";
      co_package_join = "none";
      co_artifact_join = "a declared capability file";
      co_versions = "the capability's own version, if it states one";
      co_recorded = "the fetches" };
    { co_kind = Co_artifacts;
      co_label = "artifacts only";
      co_name = "artifact-centric, no bridge";
      co_draft =
        "artifact-centric (Cargo *-sys with apt; pip sdists) — here, \
         canary's own bypass of the conf gate";
      co_package_join =
        "none: no package of the binding's is installed — the binding is \
         built from its source, and what is published from it (zarith's \
         zarith-no-conf) declares no gate";
      co_artifact_join =
        "the binding's own build finds the library — zarith's configure \
         asks pkg-config";
      co_versions = "whatever the binding's build logic enforces";
      co_recorded = "the binding's build, which is canary's own step" };
    { co_kind = Co_local;
      co_label = "local";
      co_name = "no provider ecosystem — the native side is local";
      co_draft = "a package-specific rewrite — vendor(native_source)";
      co_package_join = "none: neither side is installed by a package manager";
      co_artifact_join = "the builds here, one against the other";
      co_versions = "the source refs canary builds";
      co_recorded = "the builds, which are canary's own steps" };
    { co_kind = Co_incomplete;
      co_label = "incomplete";
      co_name = "incomplete — one side is absent";
      co_draft = "—";
      co_package_join = "—";
      co_artifact_join = "—";
      co_versions = "—";
      co_recorded = "—" } ]

let info_of_coop (k : coop) : coop_info =
  List.find_exn coop_catalogue ~f:(fun i -> Poly.equal i.co_kind k)

(** The stable word a run record carries for a kind; [co_name] is the
    sentence. *)
let code_of_coop : coop -> string = function
  | Co_conf -> "conf"
  | Co_gated_local -> "gated_local"
  | Co_unified -> "unified"
  | Co_absorbed -> "absorbed"
  | Co_no_pm -> "no_pm"
  | Co_undeclared -> "undeclared"
  | Co_depext -> "depext"
  | Co_capability -> "capability"
  | Co_artifacts -> "artifacts"
  | Co_local -> "local"
  | Co_incomplete -> "incomplete"

(** The doc's "topology character" — derived, never declared, so it
    cannot drift from the shape it names. It is the cooperation kind's
    name, except where the instance says WHY in its own words (an absorbed
    library, or no package manager at all).

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
  match t.tp_join with
  | No_pm_between why | Bridge_absorbed why -> why
  | Bridged _ | Artifacts_only | Undeclared_join -> (info_of_coop (coop_of t)).co_name

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
  let from_decl =
    List.find_map pr.Canary_project_run.pr_binding_decls ~f:(fun d ->
        let d_lang =
          (Canary_mechanism.info_of_mechanism d.BD.mechanism)
            .Canary_mechanism.mi_lang
        in
        if Poly.equal d_lang lang then Some d.BD.pm_gate else None)
  in
  (* a binding with no declaration yet may still route its PACKAGE GATE
     alone ([pr_pm_gates], 2026-09-24): the opam-binding template's four
     projects, whose gate reached nothing before *)
  match from_decl with
  | Some g -> Some g
  | None ->
      Option.map
        (List.Assoc.find pr.Canary_project_run.pr_pm_gates lang ~equal:Poly.equal)
        ~f:Option.some

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

(** Which package manager's side a node is on — the system side's, or the
    language side's. The layout draws the first on the left and the second
    on the right ([Canary_overview_page.layout_rules]). There is no third
    side: a bridge package is written in the language ecosystem, and a
    capability file ships inside the native package. *)
type side = S_sys | S_lang

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
    (* the language side's, not a third side between the two (user,
       2026-09-24: "it belongs to the language PM's side"): an opam
       maintainer writes conf-gmp, and opam resolves it *)
    { nd_id = "bridge"; nd_label = "bridge package"; nd_layer = L_package;
      nd_side = S_lang;
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
  | Included_for of string list
      (** a dummy fetch of a binding INCLUDED WITH ITS LANGUAGE
          (2026-09-29): the edges whose relation the language's own build
          and install made, before the run. It realizes none of them — it
          marks them [included] ({!included_edges}) *)
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

(** WHAT A BINDING INCLUDED WITH ITS LANGUAGE STANDS ON (2026-09-29, user:
    "fix `c` with `included`. it's a special case, and we can visit it
    later when similar cases appear"). CPython ships [sqlite3] in its
    standard library, so sqlite's Python fetch is a dummy: no action
    provisions the binding. The relations a fetched binding's package
    would bring still exist — the module and its surface installed, the
    stub built and the module linked against the library — and the
    interpreter's own build and install made them. Resolution is not
    among them: no package manager resolved anything, so [resolve_lang]
    stays absent.

    Recognised by two facts together: the fetch is a dummy, and the
    binding's declaration puts no package manager between it and the
    library ({!No_pm_between}). sqlite's Python binding is the one case,
    and [topology.every_step_has_a_place] lists it, so a second one is
    met there rather than drawn by a rule written for the first. *)
let included_edges = [ "install_lang"; "install_surf"; "build_stub"; "link_mod" ]

(** THE RULE. [location], [inspects], [dummy], [bridge] and
    [placeholder] are the step's own fields ([Canary_step_model.step]);
    the world and the project answer what the step alone cannot — where
    the library came from, and whether a bridge sits between the binding
    package and the system.

    [gone] is what the step's chain does not have ({!chain_gone}, which
    the caller computes — it is defined below). A PLACEHOLDER stands only
    on edges the chain has: it is a statement about what a package
    manager did inside our action, unseen, and a relation the chain does
    not have was not established there. torch is the case: opam builds
    its binding inside the install, and that build finds libtorch through
    opam rather than through a capability file, which the unified chain
    has none of. A step that RAN is evidence, not a statement, so it is
    never filtered — [overview.chain_absence_is_never_recorded] holds it
    against the chain instead. *)
let place_step ~(gone : string list) ~(pr : Canary_project_run.project_run)
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
  | None, Some _, _ -> (
      match action with
      | Canary_basic.Fetch (Canary_basic.Binding lang) -> (
          match join_of pr lang with
          | No_pm_between _ -> (
              match
                List.filter included_edges ~f:(fun id -> not (List.mem gone id ~equal:String.equal))
              with
              | [] -> Unplaced Does_no_work
              | kept -> Included_for kept)
          | _ -> Unplaced Does_no_work)
      | _ -> Unplaced Does_no_work)
  | None, None, Some ph -> (
      match placeholder_place ~pr ~world ~action ph with
      | Placeholder_for ids -> (
          match List.filter ids ~f:(fun id -> not (List.mem gone id ~equal:String.equal)) with
          | [] ->
              Unplaced (Unexpected "a placeholder whose edges this chain does not have")
          | kept -> Placeholder_for kept)
      | other -> other)
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

(* ── A WORLD'S COOPERATION (2026-09-23, status.md §2.7) ─────────────

   [topologies_of_project] is per declared native provision, and reads
   the binding side and the join from the PROJECT: the binding row's
   fetched provision and the declared gate. A world can do otherwise.
   zarith's built world compiles its binding from source and publishes
   zarith-no-conf, which drops conf-gmp; llvm's dev worlds build both
   sides. The project-level answer called both bridged. This is the
   answer for ONE world: both sides from its own placements, and the
   declared gate only where the world installs the package that declares
   it.

   World-level by the pass-2 membership rule: it needs a world, so it is
   computed beside firing, not in the analysis. The world-free half — the
   declared gate per language — stays [join_of]. *)

(** Who supplies one side of one world. *)
let supplier_of_world ~(pr : Canary_project_run.project_run)
    ~(world : Canary_artifact.assignment) (k : Canary_basic.artifact_kind) :
    supplier =
  match origin_of ~pr ~world k with
  | None -> Unsupplied
  | Some (prov, provider) -> (
      match prov with
      | Canary_store.Absent -> Unsupplied
      | Canary_store.Built -> Built_here
      | Canary_store.Installed -> Staged
      | Canary_store.Vendored -> Vendored
      | Canary_store.Fetched -> (
          match provider with
          | Some (SC.Sys_pkg _) ->
              By_pm (Canary_store.system_pm_of_platform (Canary_store.platform ()))
          | Some (SC.Lang_pkg { pm; _ }) -> By_pm pm
          | Some (SC.Vendored _ | SC.Cached _) -> Vendored
          | Some (SC.Repo _ | SC.Repo_axes _) -> Built_here
          | Some SC.Absent | None -> Unsupplied))

(** The topology of one binding language in one world. Where the binding
    comes from its package manager, the declared gate joins it; where the
    world builds it, stages it or is handed it, no package of the
    binding's is installed, so no gate stands between it and the library
    — its own build meets the library directly ([Artifacts_only]). *)
let topology_of_world ~(pr : Canary_project_run.project_run)
    ~(world : Canary_artifact.assignment) (lang : Canary_lang.lang) : t =
  let tp_lang = supplier_of_world ~pr ~world (Canary_basic.Binding lang) in
  let tp_join =
    match tp_lang with
    | By_pm _ -> join_of pr lang
    | Built_here | Staged | Vendored | Unsupplied -> Artifacts_only
  in
  normalize
    { tp_sys = supplier_of_world ~pr ~world Canary_basic.Lib;
      tp_join;
      tp_lang;
      tp_capability = capability_files pr }

(** One world's cooperation for one binding language. *)
let coop_of_world ~pr ~world lang : coop = coop_of (topology_of_world ~pr ~world lang)

(** Every (topology, instance) a project's WORLDS realize, once per
    distinct shape and language — what the page's cooperation table and
    chains are drawn from. *)
let topologies_of_worlds ((name, pr) : string * Canary_project_run.project_run) :
    (t * instance) list =
  List.concat_map (Canary_project_run.scenarios_of pr) ~f:(fun world ->
      List.map (binding_langs pr) ~f:(fun lang ->
          let t = topology_of_world ~pr ~world lang in
          ( t,
            { in_project = name;
              in_lang = lang;
              in_sys_provision = string_of_supplier t.tp_sys;
              in_gate_reachable =
                (match t.tp_join with Undeclared_join -> false | _ -> true) } )))
  |> List.dedup_and_sort ~compare:(fun ((a : t), (i : instance)) ((b : t), (j : instance)) ->
         Poly.compare
           (i.in_lang, string_of_supplier a.tp_lang, string_of_supplier a.tp_sys,
            string_of_join a.tp_join)
           (j.in_lang, string_of_supplier b.tp_lang, string_of_supplier b.tp_sys,
            string_of_join b.tp_join))

(* ── THE PACKAGE BAND IS ONE COOPERATION (2026-09-23, status.md §2.7;
   user: draw "the package-manager part of the diagram per cooperation,
   the way the artifact part is drawn per mechanism") ─────────────────

   The artifact band is drawn per binding mechanism below
   ([artifact_variant_of]: a ctypes binding has no stub node). This does
   the same for the band above it: which package-manager, package and
   source nodes EXIST in a topology. It is a function of the topology and
   not only of its kind, because the native side's provision decides the
   source nodes whatever the join is — a no-PM chain over a library built
   here has a source tree, one over apt's has not.

   The rules, one per node, and each is a statement about the chain:
   - the system PM and its package exist when a system package manager
     supplies the library, OR when a conf gate checks the system even
     though this world built its own (the gate's target is real, its
     payload unused — [band_dead]);
   - the capability file exists when that package does AND something
     reads it: a conf check, or a binding BUILD — ours, or the one a
     source-based package manager runs inside its install, whose
     configure asks pkg-config. CPython's stdlib extension reads nothing:
     it was linked when the interpreter was built;
   - the bridge exists when the join has one — and where the join could
     not be read at all, it is not hidden: unknown is not absent;
   - the language PM, the binding package and the program that names
     only that package exist when a language package manager supplies
     the binding, or when the world PUBLISHES the binding it built
     (zarith's zarith-no-conf);
   - the native source and the staged copy exist when the library is
     built or staged here, and the binding's source when the binding is —
     here, or by opam inside its install.

   UNKNOWN IS NOT ABSENT, and three rules say so. A join canary could not
   read keeps its bridge, its capability file and the system package the
   gate would name — the four opam-template projects' vendored worlds
   still fetch that package. A VENDORED side keeps its source: tiny-full
   builds its vendored tree from source, the conda-forge prebuilts do not,
   and the declaration cannot tell them apart. A library BUILT here keeps
   its staged copy: llvm's built worlds stage the build, sqlite's
   built-only worlds do not — that is the world's steps' business, and a
   recorded view dims what they did not touch.

   ⚠ TWO RULES WERE WRONG IN THE FIRST DRAFT. The binding's source existed
   only where WE build the binding — the hand-drawn conf case draws
   Zarith.git, and is right to: opam fetched that source and compiled it
   inside the install, where the build placeholder stands (a pip wheel has
   no such source). And the staged copy existed only where the library is
   Installed — llvm's recorded worlds stage a Built library, which
   [overview.chain_absence_is_never_recorded] caught. *)

(** The node ids the package band decides — the only ones
    {!band_hidden} can name. *)
let band_nodes : string list =
  [ "pm_sys"; "pkg_sys"; "cap"; "bridge"; "pm_lang"; "pkg_lang";
    "consumer_package"; "src_sys"; "staged_sys"; "src_lang" ]

(** A SYSTEM package manager, as its driver says ([Canary_pm.properties]'
    scope) rather than as a list here would. *)
let is_system_pm (pm : Canary_store.package_manager) : bool =
  match Canary_pm.properties pm with
  | Some p -> Poly.equal p.Canary_store.scope Canary_store.System
  | None -> false

(** Does installing a binding's package BUILD it on this machine? opam
    does — the stub is compiled and the module linked inside its install;
    a pip wheel arrives built. Read from the one list the placeholder steps are
    made from ([Canary_pm_action.inside_install]). *)
let builds_from_source (pm : Canary_store.package_manager) : bool =
  List.exists (Canary_pm_action.inside_install pm ~of_binding:true) ~f:(fun p ->
      Poly.equal p.Canary_pm_action.ph_does Canary_pm_action.Build_package)

(** Does this world PUBLISH the binding it did not fetch — pack it into a
    package of its own (zarith's zarith-no-conf, z3's z3.dev)? The
    project's wrapper declaration says so ([pr_wrapper_pkgs]), and
    [matrix.record_carries_each_worlds_chain] holds that answer to the
    world's steps: a pack step exists exactly where this says. *)
let publishes_of_world ~(pr : Canary_project_run.project_run)
    ~(world : Canary_artifact.assignment) (lang : Canary_lang.lang) : bool =
  List.Assoc.mem pr.Canary_project_run.pr_wrapper_pkgs lang ~equal:Poly.equal
  && not
       (Poly.equal
          (Option.map (origin_of ~pr ~world (Canary_basic.Binding lang)) ~f:fst)
          (Some Canary_store.Fetched))

let band_hidden ?(publishes = false) (t : t) : string list =
  let system_pm = match t.tp_sys with By_pm pm -> is_system_pm pm | _ -> false in
  let unknown = match t.tp_join with Undeclared_join -> true | _ -> false in
  let gated =
    List.exists (bridges_of_join t.tp_join) ~f:(fun g -> Canary_bridge.has_check g.gb_bridge)
  in
  let sys_package = system_pm || gated || unknown in
  let built_here = function Built_here | Staged -> true | _ -> false in
  let local = function Built_here | Staged | Vendored -> true | _ -> false in
  let pm_builds = match t.tp_lang with By_pm pm -> builds_from_source pm | _ -> false in
  let lang_package = publishes || match t.tp_lang with By_pm _ -> true | _ -> false in
  List.filter_map
    ~f:(fun (node, present) -> if present then None else Some node)
    [ ("pm_sys", sys_package);
      ("pkg_sys", sys_package);
      ("cap", sys_package && (gated || unknown || built_here t.tp_lang || pm_builds));
      ("bridge", unknown || not (List.is_empty (bridges_of_join t.tp_join)));
      ("pm_lang", lang_package);
      ("pkg_lang", lang_package);
      ("consumer_package", lang_package);
      ("src_sys", local t.tp_sys);
      ("staged_sys", built_here t.tp_sys);
      ("src_lang", local t.tp_lang || pm_builds) ]

(** Edges that EXIST and do not fire: where a conf gate checks a system
    package this world does not use, that package's payload is not what
    the chain links or compiles against. *)
let band_dead (t : t) : string list =
  let system_pm = match t.tp_sys with By_pm pm -> is_system_pm pm | _ -> false in
  let gated =
    List.exists (bridges_of_join t.tp_join) ~f:(fun g -> Canary_bridge.has_check g.gb_bridge)
  in
  if gated && not system_pm then [ "realize_sys"; "realize_hdr" ] else []

(** Why a kind has no band to draw, when it has none: it is not a
    cooperation — a join canary could not read, or a chain with one side
    absent. *)
let no_band_because : coop -> string option = function
  | Co_undeclared ->
      Some
        "its gate is declared where canary cannot read it, so which package \
         band it has is unknown"
  | Co_incomplete -> Some "one side is absent, so there is no chain to draw"
  | _ -> None

let has_band (k : coop) : bool = Option.is_none (no_band_because k)

(** ONE COOPERATION KIND'S PACKAGE BAND, from the worlds that realize it:
    a node is absent from the kind when NO world of it has the node, and
    an edge greyed when EVERY world greys it — so a kind never hides what
    one of its worlds has. DERIVED from the worlds rather than written per
    kind: no-PM-between says nothing about where the library comes from,
    and sqlite's Python worlds take it from apt, from a build and from a
    staged copy.

    NARROWED BY PACKAGE MANAGER (2026-09-24, user: "can we also make the
    pm itself as the choice?"). A kind's worlds can differ by package
    manager, and the intersection then draws what only some of them have:
    absorbed covers an opam package built from source and pip wheels that
    are not, so its band kept a binding source no wheel has. Choosing the
    package managers narrows the worlds first ({!band_over}). *)
type coop_band = {
  cb_kind : coop;
  cb_hidden : string list;  (** node ids *)
  cb_dead : string list;  (** edge ids *)
  cb_worlds : int;  (** how many (world, binding language) pairs realize it *)
}

(** One world through one binding language, as a band needs it: the
    world, the mechanism pass 2 gives its language, its topology, and what
    its package band hides and greys. *)
type band_instance = {
  bi_project : string;
  bi_pr : Canary_project_run.project_run;
  bi_world : Canary_artifact.assignment;
  bi_lang : Canary_lang.lang;
  bi_mechanism : Canary_mechanism.mechanism;
  bi_topology : t;
  bi_publishes : bool;
  bi_hidden : string list;
  bi_dead : string list;
}

let band_instances (projects : (string * Canary_project_run.project_run) list) :
    band_instance list =
  List.concat_map projects ~f:(fun (name, pr) ->
      let an = Canary_project_analysis.of_project_run pr in
      List.concat_map (Canary_project_run.scenarios_of pr) ~f:(fun world ->
          List.map (binding_langs pr) ~f:(fun lang ->
              let t = topology_of_world ~pr ~world lang in
              let publishes = publishes_of_world ~pr ~world lang in
              { bi_project = name;
                bi_pr = pr;
                bi_world = world;
                bi_lang = lang;
                bi_mechanism = Canary_project_analysis.mechanism_for an lang;
                bi_topology = t;
                bi_publishes = publishes;
                bi_hidden = band_hidden ~publishes t;
                bi_dead = band_dead t })))

(** A CHAIN'S ID: project, binding language and the two sides — the two
    sides decide the topology, since the join is the declared gate only
    where a package manager supplies the binding. ONE spelling, which the
    overview's concrete packages and its recorded worlds both use, so a
    recorded world finds its package by it. URL-safe. *)
let chain_id ~(project : string) ~(lang : Canary_lang.lang) ~(lang_side : string)
    ~(native_side : string) : string =
  String.concat ~sep:"-"
    [ project; Canary_lang.string_of_lang lang; lang_side; native_side ]

let chain_id_of ~project ~lang (t : t) : string =
  chain_id ~project ~lang ~lang_side:(string_of_supplier t.tp_lang)
    ~native_side:(string_of_supplier t.tp_sys)

(** THE TWO PACKAGE-MANAGER NODES of a chain. The native side is drawn
    with a package manager only when a SYSTEM one supplies it; a language
    package manager that supplies the library — torch's libtorch through
    opam, a wheel's bundled library — is the language side's, and the
    unified and absorbed bands draw no system PM at all. *)
let native_pm_of (t : t) : Canary_store.package_manager option =
  match t.tp_sys with By_pm pm when is_system_pm pm -> Some pm | _ -> None

let lang_pm_of (t : t) : Canary_store.package_manager option =
  match t.tp_lang with By_pm pm -> Some pm | _ -> None

let inter_all : string list list -> string list = function
  | [] -> []
  | x :: xs ->
      List.fold xs ~init:x ~f:(fun acc l ->
          List.filter acc ~f:(List.mem l ~equal:String.equal))

(** A kind's band over its chains with the chosen package managers
    ([None] = any): a node is absent when none of them has it, an edge
    greyed when every one greys it. [None] when no chain canary runs
    matches — the page says so rather than drawing a band nothing has. *)
(** The chains of a kind with the chosen package managers. *)
let instances_over ?native ?lang (is : band_instance list) (k : coop) :
    band_instance list =
  List.filter is ~f:(fun i ->
      Poly.equal (coop_of i.bi_topology) k
      && Option.for_all native ~f:(fun p -> Poly.equal (native_pm_of i.bi_topology) (Some p))
      && Option.for_all lang ~f:(fun p -> Poly.equal (lang_pm_of i.bi_topology) (Some p)))

(** The bridge kinds some of these chains join through, as terms
    ([Canary_bridge.kind_term]), once each. *)
let bridge_terms (is : band_instance list) : string list =
  List.concat_map is ~f:(fun i ->
      List.map (bridges_of_join i.bi_topology.tp_join) ~f:(fun g ->
          Canary_bridge.kind_term g.gb_bridge))
  |> List.fold ~init:[] ~f:(fun acc t ->
         if List.mem acc t ~equal:String.equal then acc else acc @ [ t ])

let band_over ?native ?lang (is : band_instance list) (k : coop) : coop_band option =
  match instances_over ?native ?lang is k with
  | [] -> None
  | xs ->
      Some
        { cb_kind = k;
          cb_hidden = inter_all (List.map xs ~f:(fun i -> i.bi_hidden));
          cb_dead = inter_all (List.map xs ~f:(fun i -> i.bi_dead));
          cb_worlds = List.length xs }

let coop_bands (projects : (string * Canary_project_run.project_run) list) :
    coop_band list =
  let is = band_instances projects in
  List.filter_map coop_catalogue ~f:(fun info ->
      if has_band info.co_kind then band_over is info.co_kind else None)

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

(* ── WHAT ONE CHAIN LACKS (2026-09-23, status.md §2.7) ────────────────

   A chain is one mechanism's artifact band joined with one cooperation's
   package band, and what it does NOT have is the union of what each
   lacks — closed over edges, because an edge goes when either end goes
   (the page's own drawing rule). This is structural absence: the relation
   does not exist in the chain. It is not the recorded view's dimming,
   which marks what exists and nothing in the run touched — and
   [overview.chain_absence_is_never_recorded] holds the two apart: nothing
   a chain lacks is ever realized, observed or placeheld by its run. *)

(** Node and edge ids, closed: every edge named, or with an end named. *)
let with_edges (ids : string list) : string list =
  let named id = List.mem ids id ~equal:String.equal in
  List.filter_map nodes ~f:(fun n -> if named n.nd_id then Some n.nd_id else None)
  @ List.filter_map edges ~f:(fun e ->
        if named e.eg_id || named e.eg_to || List.exists e.eg_from ~f:named then
          Some e.eg_id
        else None)

let chain_gone ~(mechanism : Canary_mechanism.mechanism) ?publishes (t : t) :
    string list =
  with_edges ((artifact_variant_of mechanism).av_hidden @ band_hidden ?publishes t)

(** What each chain of one world lacks, by binding language — pass 2's
    mechanism for the language, the world's own cooperation. Computed once
    per world by whoever places its steps and records its chains, so the
    two read one answer. *)
let world_gone ~(pr : Canary_project_run.project_run)
    ~(world : Canary_artifact.assignment) : (Canary_lang.lang * string list) list =
  let an = Canary_project_analysis.of_project_run pr in
  List.map (binding_langs pr) ~f:(fun lang ->
      ( lang,
        chain_gone
          ~mechanism:(Canary_project_analysis.mechanism_for an lang)
          ~publishes:(publishes_of_world ~pr ~world lang)
          (topology_of_world ~pr ~world lang) ))

(** What a step of [action] cannot stand on: its language's chain's lack
    — or, for a step that serves every binding (the library's), only what
    EVERY chain of the world lacks. *)
let gone_for_action (gones : (Canary_lang.lang * string list) list)
    (action : Canary_basic.action) : string list =
  match Canary_basic.lang_of_action action with
  | Some l -> Option.value (List.Assoc.find gones l ~equal:Poly.equal) ~default:[]
  | None -> (
      match gones with
      | [] -> []
      | (_, g) :: rest ->
          List.fold rest ~init:g ~f:(fun acc (_, g') ->
              List.filter acc ~f:(List.mem g' ~equal:String.equal)))

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

(* A claim site names an AGREEMENT — a registry row, or a candidate from
   [Canary_agreement.proposed_agreements] — and the edges it sits on.
   Whether the agreement is checked is NOT stated here: it is the
   registry's to say ({!implemented}). It was a hand-written flag until
   2026-09-24, and three sites said "implemented" for agreements whose
   every method is planned, so the page drew their edges' badges as
   checked while nothing checked them. *)
type claim_site = {
  cs_claim : string;
  cs_edges : string list;  (** edge ids — a SET, see above *)
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
    { cs_claim = "declared_symbols_exported"; cs_edges = [ "build_lib"; "realize_sys" ] };
    { cs_claim = "soname_matches_declaration"; cs_edges = [ "build_lib"; "realize_sys" ] };
    { cs_claim = "declared_versions_exported"; cs_edges = [ "build_lib"; "realize_sys" ] };
    { cs_claim = "exports_accounted_for"; cs_edges = [ "build_lib"; "realize_sys" ] };
    (* --- the binding against the library --- *)
    { cs_claim = "required_symbols_exported"; cs_edges = [ "link_mod" ] };
    { cs_claim = "soname_matches_requirement"; cs_edges = [ "link_mod" ] };
    { cs_claim = "required_versions_exported"; cs_edges = [ "link_mod" ] };
    { cs_claim = "dependencies_provided"; cs_edges = [ "link_mod" ] };
    { cs_claim = "signatures_agree"; cs_edges = [ "build_stub" ] };
    { cs_claim = "signatures_match_debug_info"; cs_edges = [ "build_stub" ] };
    (* --- the package against its own artifacts --- *)
    { cs_claim = "api_names_present"; cs_edges = [ "install_surf" ] };
    { cs_claim = "package_contains_declared_files"; cs_edges = [ "install_lang" ] };
    { cs_claim = "repack_preserves_api"; cs_edges = [ "pack" ] };
    { cs_claim = "repack_complete"; cs_edges = [ "pack" ] };
    (* --- staging --- *)
    { cs_claim = "staged_interface_preserved"; cs_edges = [ "stage" ] };
    { cs_claim = "no_build_paths_in_installed_library"; cs_edges = [ "stage" ] };
    (* --- source --- *)
    { cs_claim = "source_is_declared_ref"; cs_edges = [ "build_lib" ] };
    { cs_claim = "build_tree_configured_for_source"; cs_edges = [ "build_lib" ] };
    (* --- runtime: the only claims with a loader under them --- *)
    { cs_claim = "behavior_matches"; cs_edges = [ "run" ] };
    { cs_claim = "correspondence_holds_across_the_binding"; cs_edges = [ "run" ] };
    { cs_claim = "no_duplicate_implementation"; cs_edges = [ "run" ] };
    { cs_claim = "interposition_binds_build_target"; cs_edges = [ "run" ] };
    { cs_claim = "denotation_stable_across_worlds"; cs_edges = [ "run" ] };
    (* ⚠ THE FIRST END-TO-END CLAIM. Every claim site above sits on one
       edge — a per-layer invariant, in the network analogy. This one
       spans three: the PM resolved, the package realized what it
       promised, and the program built from the package alone did what
       the hand-resolved one did. It is the kind the asymmetry between
       apt and opam makes hard and the kind we had none of. *)
    { cs_claim = "package_resolution_suffices";
      cs_edges = [ "resolve_lang"; "run_packaged"; "same_program" ] };
    { cs_claim = "compatibility_version_satisfied"; cs_edges = [ "link_mod" ] };
    (* --- the diagonal: the first candidate on a cooperation edge --- *)
    { cs_claim = "discovery_matches_link"; cs_edges = [ "discover" ] };
    (* --- THE BRIDGE'S CLAIMS (2026-09-23, status.md §2.7 E): placeholders
       for what a bridge states, on the edges where it states it. Each has
       its evidence recorded for zarith and no comparator yet, so each is a
       candidate badge — the bridge edges stop reading as bare because the
       CLAIM is known, not because anything decides it. --- *)
    { cs_claim = "gate_admits_the_world"; cs_edges = [ "conf_probe" ] };
    { cs_claim = "declared_gate_matches_package"; cs_edges = [ "depends" ] };
    { cs_claim = "gate_bounds_the_library"; cs_edges = [ "depends"; "conf_probe" ] };
    { cs_claim = "depext_names_the_provided_package"; cs_edges = [ "depext" ] } ]

(** IS A PLACED AGREEMENT CHECKED ANYWHERE? The registry's answer: a row
    whose methods include one with an evaluator. A candidate (not a
    registry row) is not, and neither is a row whose every method is
    planned — [behavior_matches], [repack_preserves_api] and
    [repack_complete] today, which the retired flag called implemented. *)
let implemented (cs : claim_site) : bool =
  match Canary_agreement.agreement_named cs.cs_claim with
  | None -> false
  | Some r -> (
      match Canary_agreement.status_of_row r with
      | Canary_agreement.Evaluated | Canary_agreement.Partly -> true
      | Canary_agreement.Planned_only | Canary_agreement.Off_in_registry
      | Canary_agreement.Proposed ->
          false)

(** HOW A PLACED AGREEMENT STANDS FOR ONE BINDING MECHANISM (2026-09-24,
    user, on the badges' numbers). [Checked]: canary evaluates it for
    this mechanism — the same answer pass 2 gives a project
    ([Canary_project_analysis.carried_slugs]: a method with an evaluator
    that suits the mechanism and language). [Placeholder]: named, and
    nothing evaluates it here — a candidate, or a registry row with no
    evaluator that suits. [None]: the registry says it cannot apply to
    this mechanism at all (every method is inapplicable), e.g. a stub's
    signatures for a mechanism that compiles no stub. A candidate states
    no applicability, so it counts wherever its edge is drawn.

    The applicability predicates read the mechanism and the language
    only, never the declaration, so asking with [~declared:None] gives
    every project binding through this mechanism the same answer. *)
type claim_state = Checked | Placeholder

let string_of_claim_state = function Checked -> "checked" | Placeholder -> "placeholder"

let claim_state ~(mechanism : Canary_mechanism.mechanism) ~(lang : Canary_lang.lang)
    (cs : claim_site) : claim_state option =
  match Canary_agreement.agreement_named cs.cs_claim with
  | None -> Some Placeholder
  | Some r ->
      if
        List.mem
          (Canary_project_analysis.carried_slugs ~mechanism ~lang ~declared:None)
          cs.cs_claim ~equal:String.equal
      then Some Checked
      else if
        List.exists r.Canary_agreement.ag.Canary_agreement_common.ag_methods ~f:(fun m ->
            Canary_agreement.suits_here ~mechanism ~lang ~declared:None m)
      then Some Placeholder
      else None

(** The claims sitting on one edge. *)
let claim_sites_on (edge_id : string) : claim_site list =
  List.filter claim_sites ~f:(fun p ->
      List.mem p.cs_edges edge_id ~equal:String.equal)

(** WHAT AN EDGE'S BADGES COUNT, for one binding mechanism (2026-09-24):
    the agreements on the edge that can apply to it, each with how it
    stands — a filled badge counts the [Checked], a hollow one the
    [Placeholder]. An agreement placed on several edges is on each. *)
let edge_claims ~(mechanism : Canary_mechanism.mechanism) ~(lang : Canary_lang.lang)
    (edge_id : string) : (claim_site * claim_state) list =
  List.filter_map (claim_sites_on edge_id) ~f:(fun cs ->
      Option.map (claim_state ~mechanism ~lang cs) ~f:(fun st -> (cs, st)))

(** CLAIM APPLICABILITY, PER CHAIN (2026-09-23, status.md §2.7; user: a
    bridge's claim applies only where there is a bridge). A claim applies
    to a chain when one of its edges exists there. ONE, not all: the
    library's declaration claims sit on both edges that can produce a
    library, as alternatives, and a fetched library has only one of them.
    The end-to-end sites span edges that come and go together — every
    edge of [package_resolution_suffices] needs the binding package — so
    today "one" and "all" agree on them.

    WORLD-LEVEL by pass 2's membership rule: pass 2 answers which claims
    a MECHANISM can carry ([Canary_project_analysis.carries]); which a
    CHAIN can carry needs the world's cooperation, so it is computed beside
    firing, from {!chain_gone}. *)
let claim_applies ~(gone : string list) (cs : claim_site) : bool =
  List.exists cs.cs_edges ~f:(fun e -> not (List.mem gone e ~equal:String.equal))

(* ── WHERE AN AGREEMENT SITS ON THE CHAIN (2026-09-27) ───────────────

   A FOURTH AXIS FOR THE AGREEMENT TABLE, DERIVED (user, 2026-09-27: the
   agreement table was built before the layered diagram, and the target is
   to categorize every agreement by the diagram; "do 1 first" — derive
   where each sits, show it as a column and as a grouped view, then
   implement agreements where the grouping shows gaps). Beside kind (what
   a claim asserts), reference (what its second side is) and rooting
   (whose rule it recovers), this says where on the chain it sits: the
   edges of its claim site, the layers their ends lie in, and how far it
   reaches — along one side's own chain, across the two sides, or end to
   end, over edges that lead from one layer to another.

   It is derived from [claim_sites], so it is exactly as right as they
   are, and the first thing it shows is where one coordinate is not
   enough: [discovery_matches_link] sits on [discover], both of whose ends
   are on the system side, while what it compares — pkg-config's answer
   and the library the binding links — reaches the language side. *)
type reach = Own_side of side | Across_sides | End_to_end

type sitting = {
  st_edges : string list;  (** the claim site's edges *)
  st_layers : layer list;  (** the layers their ends lie in, top down *)
  st_reach : reach;
}

let layer_rank = function L_pm -> 0 | L_package -> 1 | L_artifact -> 2 | L_program -> 3

(** Where one claim site sits. END TO END: its edges lead to more than one
    node and their ends span more than one layer — a chain of relations,
    not alternatives for one (the library's declaration agreements sit on
    both of the library's producers, which is two ways to one node). *)
let sitting_of_site (cs : claim_site) : sitting =
  let es =
    List.filter_map cs.cs_edges ~f:(fun id ->
        List.find edges ~f:(fun e -> String.equal e.eg_id id))
  in
  let ns =
    List.concat_map es ~f:(fun e -> e.eg_to :: e.eg_from)
    |> List.dedup_and_sort ~compare:String.compare
    |> List.filter_map ~f:node_by_id
  in
  let layers =
    List.map ns ~f:(fun n -> n.nd_layer)
    |> List.dedup_and_sort ~compare:(fun a b -> Int.compare (layer_rank a) (layer_rank b))
  in
  let heads = List.map es ~f:(fun e -> e.eg_to) |> List.dedup_and_sort ~compare:String.compare in
  let reach =
    if List.length heads > 1 && List.length layers > 1 then End_to_end
    else
      match List.map ns ~f:(fun n -> n.nd_side) |> List.dedup_and_sort ~compare:Poly.compare with
      | [ s ] -> Own_side s
      | _ -> Across_sides
  in
  { st_edges = cs.cs_edges; st_layers = layers; st_reach = reach }

(** Where an agreement sits, by its name — [None] if nothing places it. *)
let sitting_of (slug : string) : sitting option =
  Option.map
    (List.find claim_sites ~f:(fun cs -> String.equal cs.cs_claim slug))
    ~f:sitting_of_site

let string_of_reach = function
  | Own_side S_sys -> "system side"
  | Own_side S_lang -> "language side"
  | Across_sides -> "across the sides"
  | End_to_end -> "end to end"

let string_of_layers (ls : layer list) : string =
  String.concat ~sep:"/" (List.map ls ~f:string_of_layer)

(** The claims one chain can carry, in [claim_sites] order, once each. *)
let claims_of_chain ~(gone : string list) : string list =
  List.filter_map claim_sites ~f:(fun cs ->
      if claim_applies ~gone cs then Some cs.cs_claim else None)
  |> List.fold ~init:[] ~f:(fun acc c ->
         if List.mem acc c ~equal:String.equal then acc else acc @ [ c ])

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
   {!no_capability_file_declared} rather than written as a sentence. *)
