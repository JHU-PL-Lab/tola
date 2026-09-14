(** [Canary_agreement_common] — TIER 1: what every check family needs.

    The agreement layer is three tiers (2026-09-02, user): this module
    declares the common types; each [canary_agreement_<topic>] is one concrete
    family that uses those types to describe ITSELF; and
    [Canary_agreement] lists the families and derives the views
    others read. A family refers only to this module — pinned by
    [agreements.families_do_not_reach_sideways].

    {1 What an agreement is for: recovering agreement after information loss}

    Building establishes relations, and most of them are checked exactly
    once, by a tool, on one machine. A compiler checks the relations its
    own rules cover — that an [external] matches the stub it compiles,
    that an implementation matches its interface. It does not check that
    the library finally loaded is the one the header described, because
    at compile time there is no such library yet, and by the time there
    is, the compiler is gone.

    Distribution loses more. An artifact is packaged, staged, fetched,
    installed, and recombined with artifacts built somewhere else; what
    survives is the artifact plus whatever it happens to record about
    itself. The relations that were established are not carried along —
    a [.so] does not remember which headers it agreed with, and a
    consumer does not remember which [.so] it was linked against, only
    the NAME it recorded.

    An agreement names one such relation and says how to observe it
    again, from evidence that did survive. That is the whole model: not
    re-running the toolchain, but checking, against the artifacts a world
    actually contains, a relation the toolchain either never checked or
    checked in a world that no longer exists.

    {1 The three tiers}

    What lives here, and why each thing is common rather than a
    family's:

    - the DESCRIPTIVE types an agreement uses to describe itself —
      [subject], [claim], [basis], and the [agreement] record;
    - the CHECKING METHOD — [checking_method], [method_kind],
      [reference], [applicability], [evaluator] — an agreement's claim
      and the ways it can be observed are separate, and one agreement
      may carry several methods with different evidence, scope and
      implementation status;
    - the EVALUATION OUTCOME [outcome], which distinguishes the seven
      things an empty substring list used to mean;
    - the [inspect_input] ADT, which NAMES evidence (the records that
      parse it belong to the family that reads them);
    - the registry vocabulary — [agreement_id];
    - the shared derivations a family needs in order to state where it
      fires and what it reads: [firing_default],
      [firing_built_lib_only], [firing_probe_only], [uniform_world],
      [binding_evidence_tag];
    - the JSON primitives every loader is built from.

    The rule that decides membership: a family owns whatever is only
    about its own topic; this module owns what more than one family
    needs. *)

open Base

(* Static compatibility check between a binding's stub archive (consumer side:
   "what C symbols this binding requires from the native lib") and a native
   library's defined-symbols summary (provider side: "what this .so exports").

   Inputs are summary.json files produced by inspect_binding.py --kind stub
   and inspect_native.py --emit-symbols, respectively. Output is a verdict
   on `requires ⊆ provides`.

   See doc/canary/design/agreement_registry.md for the design. *)

(* ── Summary loaders ── *)

(** Reading an inspection.

    It RAISES on a missing or malformed file (2026-09-12). It used to
    call [Stdlib.exit 2], which is not an exception and therefore not
    catchable: a file that vanished between an evaluator's existence
    check and its read would have taken the whole run down rather than
    producing an [Error] outcome. Every evaluator goes through
    [evaluate_method] or the registry's equivalent, both of which turn
    an exception into [Error] — so a bad inspection is now a reported
    outcome for one method instead of a dead process.

    [canary compat] still wants the hard exit; it checks the path and
    exits itself, which is a CLI decision rather than an evaluator's. *)
exception Unreadable_inspection of string

let load path : Yojson.Basic.t =
  if not (Stdlib.Sys.file_exists path) then
    raise (Unreadable_inspection (path ^ ": not found"));
  try Yojson.Basic.from_file path
  with exn ->
    raise
      (Unreadable_inspection (path ^ ": " ^ Stdlib.Printexc.to_string exn))

let field (j : Yojson.Basic.t) name =
  match j with
  | `Assoc fields -> List.Assoc.find fields ~equal:String.equal name
  | _ -> None

let get_string j name =
  match field j name with Some (`String s) -> s | _ -> ""

let get_string_list j name =
  match field j name with
  | Some (`List xs) ->
      List.filter_map xs ~f:(function `String s -> Some s | _ -> None)
  | _ -> []

(* ── Typed views ── *)

(** [inspect_input] — what evidence feeds a checking method. Most
    constructors carry a {i list} of candidate paths (different action
    paths in the graph write the same logical artifact to different
    relative locations — [pack_binding_ocaml/inspect_stub.json] vs.
    [fetch_binding_ocaml/inspect_stub.json] for OCaml stub, for
    example). The runner picks the first existing path via [~resolve].

    The [Declared_*] constructors are the exception: a DECLARATION is
    evidence too, and it does not live in a file the run produced — it
    is what the project said. Carrying it in the same list is what lets
    a solo agreement (artifact vs declaration) have the same evaluator
    signature as a pair agreement (artifact vs peer artifact), instead
    of being reachable only through a partially-applied closure in a
    fixture. When no action supplies one, the method reports
    [Unavailable] rather than silently holding. *)
type inspect_input =
  | C_stub of string list
  | Native_lib of string list
  | Ocaml_mli of string list
  | Python_attrs of string list
  | Versioned_exports of string list  (** provider's exported version tags *)
  | Versioned_req of string list      (** consumer's required version tags *)
  | Abi_surface of string list        (** consumer's identity + NEEDED record *)
  | Typed_header of string list       (** provider's C signatures *)
  | Typed_binding_stub of string list (** consumer's C signatures *)
  | Typed_binding_user of string list (** consumer's language-level signatures *)
  (* ── declaration evidence: what the PROJECT said, not what a tool
     produced. Introduced 2026-09-12 with the solo/pair split. *)
  | Declared_exports of string list     (** the c_api functions declared *)
  | Declared_soname of string           (** the library identity declared *)
  | Declared_version_tags of string list(** the symbol-version tags declared *)
  (* the STAGED copy of a library, distinct from [Native_lib] because a
     staging check compares TWO native summaries and the pair has to be
     addressable (2026-09-12) *)
  | Staged_lib of string list

(* Each family's evidence RECORDS and their loaders live with the family
   that reads them (2026-09-02): [stub_inspect]/[native_inspect] in
   [Canary_agreement_symbols], the elf and version views in
   [Canary_agreement_identity], the typed signatures in
   [Canary_agreement_types]. What stays here is what more than one
   family needs — the JSON primitives, the [inspect_input] ADT that
   NAMES evidence, and the agreement vocabulary. *)

(* ── the descriptive vocabulary ──────────────────────────────────────
   These types say what an agreement IS. Nothing dispatches on them:
   selection is by applicability and firing site, evaluation by the
   method's own evaluator. They group the catalogue and the doc, and
   they are deliberately allowed to refine as agreements accumulate,
   because a descriptive type costs nothing to sharpen. *)

(** WHAT THE AGREEMENT IS ABOUT. Flat since 2026-09-12: the old
    two-level [cat] carried a refinement ([Symbols `Exported] vs
    [Symbols `Required]) that said exactly what the agreement's own
    name now says, so the refinement was a second spelling of the
    identity. *)
type subject =
  | Staging          (** what survives being copied out of the build tree *)
  | Symbols          (** which names an object defines or requires *)
  | Api_names        (** which names a binding's user-facing surface offers *)
  | Identity         (** what an object calls itself, and what a consumer
                         recorded needing *)
  | Symbol_versions  (** the version namespaces attached to symbols *)
  | Signatures       (** the types at a boundary *)
  | Behavior         (** what running it does *)
  | Dependencies     (** whether a recorded requirement has a provider *)
  | Repacking        (** the relation between a binding's two layers *)
  | Action_outcome
      (** the weakest claim available: the tool did not error, and its
          declared output appeared. No artifact is read — which is why
          the design says to inspect the product wherever one exists.
          Free at every action, and it is what a later blame step has
          to start from. *)
  | Framework        (** about canary's own declarations, not the tools' *)

let string_of_subject = function
  | Staging -> "staging"
  | Symbols -> "symbols"
  | Api_names -> "api-names"
  | Identity -> "identity"
  | Symbol_versions -> "symbol-versions"
  | Signatures -> "signatures"
  | Behavior -> "behavior"
  | Dependencies -> "dependencies"
  | Repacking -> "repacking"
  | Action_outcome -> "action-outcome"
  | Framework -> "framework"

(** WHAT A CHECK CLAIMS. A structural claim is about artifacts and
    their FIT; a behavioral claim is about what the program MEANS or
    does. The distinction is not "does it run": a link verdict is
    observed by running a tool and is still a structural finding, which
    is exactly the case that made this axis primary rather than the
    method one. *)
type claim =
  | Structural  (** about an artifact, or about two artifacts' fit *)
  | Behavioral  (** about what running it does *)
[@@deriving show, eq]

(** WHERE THE OBLIGATION COMES FROM — the authority an observation can
    disagree with. Replaces the [standing] / [provenance] pair
    (2026-09-12): those were two booleans over the same question, and
    neither could say that a compatibility policy and a behavioural
    specification are different authorities. *)
type basis =
  | Toolchain_rule
      (** the format or the toolchain requires it of every project,
          declared by nobody — a findlib META naming an archive that
          exists, an ELF consumer's NEEDED naming something loadable *)
  | Project_declaration
      (** the project said so — a watchlist, a declared soname, a
          declared export set *)
  | Compatibility_policy
      (** a stated preservation rule between versions or worlds *)
  | Behavioral_spec
      (** an expectation about what running it produces *)
[@@deriving show, eq]

let string_of_basis = function
  | Toolchain_rule -> "toolchain-rule"
  | Project_declaration -> "project-declaration"
  | Compatibility_policy -> "compatibility-policy"
  | Behavioral_spec -> "behavioral-spec"

(** WHAT THE OBSERVATION IS COMPARED AGAINST — the method's reference
    expectation. A method is only as strong as this: comparing an
    artifact against a declaration finds disagreements between artifact
    and declaration, which is not the same finding as a consumer
    requirement the provider does not meet. *)
type reference =
  | Artifact_itself  (** the artifact's own format rule; no second party *)
  | Declared_facts   (** what the project declared *)
  | Peer_artifact    (** the other artifact in this world *)
  | Sibling_world    (** corresponding evidence retained from another world *)
  | Test_suite       (** an upstream or translated suite's expected results *)

let string_of_reference = function
  | Artifact_itself -> "artifact"
  | Declared_facts -> "declaration"
  | Peer_artifact -> "peer"
  | Sibling_world -> "sibling-world"
  | Test_suite -> "test-suite"

(** HOW the claim is observed. It varies independently of [claim]:
    [Run_tool] carries structural claims (a compiler's verdict on a
    pairing), [Run_program] carries behavioral ones. Was [evidence]
    until 2026-09-12, which named the input rather than the act. *)
type method_kind =
  | Inspect      (** one artifact, an inspector *)
  | Compare      (** several artifacts, inspected then compared *)
  | Run_tool     (** a compiler/linker/loader verdict *)
  | Run_program  (** the program's own output *)
[@@deriving show, eq]

let string_of_method_kind = function
  | Inspect -> "inspect"
  | Compare -> "compare"
  | Run_tool -> "run-tool"
  | Run_program -> "run-program"

(* ── evaluation ──────────────────────────────────────────────────── *)

(** WHAT AN EVALUATION FOUND (2026-09-12). Before this, every method
    returned a substring list and an empty one meant, indistinguishably:
    the agreement holds; the evidence was missing; the comparator could
    not decide; nothing is implemented; the method does not apply here;
    it was switched off; the loader raised. Those are seven different
    things and only one of them is good news.

    [Holds] is bounded by the method's own stated scope ([m_limits]) —
    it says no counterexample was found within the properties that
    method inspects, never that the pairing is compatible. *)
type outcome =
  | Holds
  | Violated of string list
      (** the counterexample, as the names/messages that witness it *)
  | Unavailable of string   (** required evidence was not produced here *)
  | Inconclusive of string  (** evidence present, comparison cannot decide *)
  | Not_implemented of string (** a declared method with no evaluator yet *)
  | Not_applicable of string  (** this mechanism/world offers no such claim *)
  | Disabled of string        (** switched off for this run *)
  | Error of string           (** the evaluation itself failed *)

let outcome_label = function
  | Holds -> "holds"
  | Violated _ -> "violated"
  | Unavailable _ -> "unavailable"
  | Inconclusive _ -> "inconclusive"
  | Not_implemented _ -> "not_implemented"
  | Not_applicable _ -> "not_applicable"
  | Disabled _ -> "disabled"
  | Error _ -> "error"

let outcome_detail = function
  | Holds -> ""
  | Violated fs -> String.concat ~sep:"," fs
  | Unavailable r | Inconclusive r | Not_implemented r | Not_applicable r
  | Disabled r | Error r -> r

let string_of_outcome o =
  match outcome_detail o with
  | "" -> outcome_label o
  | d -> outcome_label o ^ ": " ^ d

(** The counterexample an outcome carries, if it is one. *)
let findings_of_outcome = function Violated fs -> fs | _ -> []

(** A VIOLATION WITHOUT A WITNESS IS NOT A VIOLATION (2026-09-12
    audit). Everything downstream of an outcome assumes a [Violated]
    names what refutes it: the diagnostics a failing run is greppable
    for, the confirmation split, and the acceptance policy that decides
    a step must fail "with that signature". An empty finding list would
    pass through all three as a disagreement nobody can observe —
    strengthening a step's requirement while supplying nothing to check
    it against.

    No evaluator produces one today. This is here so that none can:
    every path to an outcome goes through it, and the case is mapped to
    the honest answer instead. *)
let normalize_outcome = function
  | Violated [] ->
      Inconclusive
        "the comparison disagreed but produced no witness; there is nothing \
         to report or to check a run's output against"
  | o -> o

(** Does this outcome record an actual counterexample? The only
    predicate a caller should use to mean "a failure was found" —
    [not Holds] would also catch missing evidence. *)
let is_violation = function Violated _ -> true | _ -> false

(** Does this outcome establish anything at all? [Holds] and [Violated]
    are results; the rest are reasons there is none. *)
let is_decided = function Holds | Violated _ -> true | _ -> false

(** Whether a method APPLIES in a world. Separate from whether its
    evidence exists: a cstubs consumer offers no dependency record at
    all ([Not_applicable]), whereas a cext consumer that was never
    inspected has one canary did not read ([Unavailable]). Collapsing
    those two is how a missing inspector reads as a passing check. *)
type applicability = Applicable | Inapplicable of string

(** THE ACTION CONTEXT an agreement selection needs.

    Three facts the enumeration already knows by the time a step
    exists: which binding mechanism this chain uses, which language it
    is, and the world the scenario assigned. With the step's own action
    they are enough to select every applicable checking method, resolve
    what each reads, and evaluate it — with no project naming an
    agreement and no caller supplying an input list.

    It lives HERE rather than in the step model (2026-09-12) because
    two layers need it: [Canary_step_model.step] carries one, and the
    registry's selection consumes one. A type two layers share belongs
    in the lower of them. *)
type action_context = {
  ac_mechanism : Canary_mechanism.mechanism;
  ac_lang : Canary_lang.lang;
  ac_world : Canary_artifact.assignment;
  ac_declared : Canary_artifact.t option;
      (** WHAT THE PROJECT SAID IT SHIPS (2026-09-14) — the declared
          C API: the stable symbols, the library identity, the
          symbol-version tags.

          A DECLARATION IS EVIDENCE. It is the reference half of every
          [Declared_facts] comparison, and it was the one kind of
          evidence with nowhere to come from: a method's [m_inputs]
          saw the mechanism, the language and the world, and a
          declaration is none of those. So the three agreements at
          [build_lib_post] reported "the project's c_api declaration is
          not routed into the evidence" on every run of every project
          — the comparison's own reference was unreachable.

          [None] where the project declares no API. The agreements that
          want it then report [unavailable] with a reason naming the
          project rather than the plumbing, which is a to-do for
          somebody rather than a bug. *)
}

(** The candidate paths an evidence reference names. A declaration
    carries values rather than paths, so it names none. *)
let paths_of_input (i : inspect_input) : string list =
  match i with
  | C_stub ps | Native_lib ps | Ocaml_mli ps | Python_attrs ps
  | Versioned_exports ps | Versioned_req ps | Abi_surface ps | Typed_header ps
  | Typed_binding_stub ps | Typed_binding_user ps | Staged_lib ps ->
      ps
  | Declared_exports _ | Declared_soname _ | Declared_version_tags _ -> []

(** WHICH ARTIFACT AN EVIDENCE REFERENCE IS ABOUT (2026-09-14, user).

    A failing check should be able to point at what it was reading, and
    the evidence already says: a native summary is about the library, a
    stub or a surface is about the binding, a header signature set is
    about the headers.

    [None] FOR A DECLARATION, and that is the interesting case rather
    than a gap. A declaration is the project's word, not an artifact,
    and it has no column to colour. So the artifacts a violation
    implicates are exactly one for a [Declared_facts] comparison and
    exactly two for a [Peer_artifact] one — which means "red" means two
    different things, and the difference is readable off
    [m_reference]: this artifact is wrong, versus these two disagree.
    Seven of the thirteen agreements are declaration comparisons and
    six are peer ones, so both cases are live. *)
let artifact_of_input ~(lang : Canary_lang.lang) (i : inspect_input) :
    Canary_basic.artifact_kind option =
  match i with
  | Native_lib _ | Staged_lib _ | Versioned_exports _ -> Some Canary_basic.Lib
  | C_stub _ | Ocaml_mli _ | Python_attrs _ | Versioned_req _ | Abi_surface _
  | Typed_binding_stub _ | Typed_binding_user _ ->
      Some (Canary_basic.Binding lang)
  | Typed_header _ -> Some Canary_basic.Headers
  | Declared_exports _ | Declared_soname _ | Declared_version_tags _ -> None

(** THE DECLARED HALF, AS EVIDENCE (2026-09-14).

    Each returns [] when the project declares nothing of that kind,
    which is a different state from "the plumbing is missing" and now
    reads as one: the evaluator reports [unavailable] with a reason
    naming the project. sqlite declares its stable symbols and no
    version script, so its [build_lib_post] column honestly shows one
    claim decided and one inapplicable, rather than three claims
    blocked on canary. *)
let declared_exports_input (d : Canary_artifact.t option) : inspect_input list =
  match d with
  | Some a
    when not (List.is_empty a.Canary_artifact.native_api.stable_symbols) ->
      [ Declared_exports a.Canary_artifact.native_api.stable_symbols ]
  | _ -> []

let declared_soname_input (d : Canary_artifact.t option) : inspect_input list =
  match Option.bind d ~f:(fun a -> a.Canary_artifact.native_api.soname) with
  | Some s when not (String.is_empty s) -> [ Declared_soname s ]
  | _ -> []

let declared_version_tags_input (d : Canary_artifact.t option) :
    inspect_input list =
  match d with
  | Some a
    when not (List.is_empty a.Canary_artifact.native_api.versioned_symbols) ->
      [ Declared_version_tags a.Canary_artifact.native_api.versioned_symbols ]
  | _ -> []

(** The evaluator's signature: resolve a declared relative evidence
    path to an absolute one, read the inputs, decide. *)
type evaluator =
  resolve:(string -> string) -> inspect_input list -> outcome

(* ── where a check fires, and what it reads ──

   Both are DERIVED from mechanism × language × world, and both are
   things a check family states about itself, so the derivations live
   here rather than in the registry. *)

(** [produced_here p]: did this world make the artifact, or receive it?
    Installed groups with Built — its chain performed the real build and
    then staged the result, so the build-family agreements have their
    artifact. *)
let produced_here (p : Canary_store.provision) : bool =
  match p with
  | Canary_store.Built | Canary_store.Installed -> true
  | Canary_store.Fetched | Canary_store.Vendored | Canary_store.Absent -> false

let is_dynamic (m : Canary_mechanism.mechanism) : bool =
  Base.Poly.equal
    (Canary_mechanism.discipline_of_mechanism m)
    Canary_mechanism.Dynamic_ffi

(** The default firing: Static and the BINDING was built here → build
    then probe; Static and it arrived ready-made → probe (no build step
    exists); Dynamic → probe (probe-only chains).

    The world is an [assignment] rather than one provision because a
    world provisions each artifact separately — sqlite builds its lib
    and fetches its binding from opam — and the questions asked here are
    about different artifacts. *)
let firing_default (m : Canary_mechanism.mechanism) (l : Canary_lang.lang)
    (w : Canary_artifact.assignment) : Canary_basic.action list =
  let probe = Canary_basic.Probe_binding l in
  if is_dynamic m then [ probe ]
  else if produced_here (Canary_artifact.provision_of_binding w l) then
    [ Canary_basic.Build_binding l; probe ]
  else [ probe ]

(** A DECLARATION comparison is about the library alone, so it has
    evidence exactly where the library was produced — and nowhere else.

    Two things it deliberately does not consult (2026-09-12 audit).
    The LANGUAGE: whether the built library exports what the project
    declared is the same question whoever consumes it. And the
    MECHANISM: [firing_with_build_lib], which this replaced, carried a
    [not (is_dynamic m)] guard, so a project whose only binding was
    ctypes would have had no declaration check on its own library. The
    guard was inherited from the pair check it used to share an id
    with, where it does belong. *)
let firing_built_lib_only (_ : Canary_mechanism.mechanism)
    (_ : Canary_lang.lang) (w : Canary_artifact.assignment) :
    Canary_basic.action list =
  if produced_here (Canary_artifact.provision_of_lib w) then
    [ Canary_basic.Build_lib ]
  else []

(** Behaviour needs a run — probe only, in every world. *)
let firing_probe_only (_ : Canary_mechanism.mechanism) (l : Canary_lang.lang)
    (_ : Canary_artifact.assignment) : Canary_basic.action list =
  [ Canary_basic.Probe_binding l ]

(** The UNIFORM world: lib and binding both at one provision. It is what
    a single provision argument used to mean, kept for the views that
    want a hypothetical rather than a real world (the firing table, the
    fill list). A real caller passes the enumeration's own assignment. *)
let uniform_world ~(lang : Canary_lang.lang)
    ~(mechanism : Canary_mechanism.mechanism) (p : Canary_store.provision) :
    Canary_artifact.assignment =
  let at id =
    (id, { Canary_artifact.provision = p; version = Canary_basic.good Dev })
  in
  [ at Canary_artifact.a_lib; at (Canary_artifact.a_binding lang mechanism) ]

(** WHERE a binding's inspection sits. Measured across every project's
    run outputs rather than assumed, because the answer is three-way:

    - FETCHED (ssl's opam binding, z3's pip wheel) → the fetch step;
    - BUILT IN THE WORKSPACE (tiny, zarith) → the build step;
    - BUILT THEN PUBLISHED (llvm packs into opam and inspects the
      published package) → the pack step. NOT derived: the world says
      how an artifact was provisioned, not whether the project
      publishes it, and no declaration carries that bit. *)
let binding_evidence_tag (w : Canary_artifact.assignment)
    (l : Canary_lang.lang) : string =
  let a =
    match Canary_artifact.provision_of_binding w l with
    | Canary_store.Fetched -> Canary_basic.Fetch (Canary_basic.Binding l)
    (* Absent covers the callers that pass no world at all: the build
       tree is what they have always meant *)
    | Canary_store.Built | Canary_store.Installed | Canary_store.Vendored
    | Canary_store.Absent ->
        Canary_basic.Build_binding l
  in
  Canary_basic.string_of_action a

let build_lib_tag = Canary_basic.string_of_action Canary_basic.Build_lib

(** WHERE THE LIBRARY'S INSPECTION SITS — the lib-side twin of
    [binding_evidence_tag], and it was missing (2026-09-12).

    The binding side has read the world's provision since it was
    written; the library side was the constant [build_lib_tag] in every
    agreement that reads a library. So in any world whose library is
    not Built, the native summary was looked for where nothing writes
    it — and five projects (ssl, cairo, libffi, zstd, torch) write
    theirs at [probe_lib], which nothing read.

    Measured, not assumed, exactly as the binding's was:

    - BUILT / VENDORED → the build step inspects what it made
      ([tiny-full] writes [build_lib/inspect.json]), and the build-tree
      probe inspects the same file;
    - INSTALLED → the copy that matters is the STAGED one, which is
      read by its own probe ([probe_lib_staged]). The build tree is
      still there and still inspected, so it is the fallback — but
      naming it first would answer questions about the staged world
      with the build tree's evidence, which is the very drift
      [staged_interface_preserved] exists to detect;
    - FETCHED → there is no build step and nothing is staged. The
      system package is inspected by the PM probe, whose tag carries
      the package manager's name ([probe_lib_apt]) because a world can
      resolve a library through more than one.

    The PROBE TAGS are the part that was wrong until 2026-09-13. This
    returned the bare [probe_lib] for every non-Built world, and
    [probe_lib] is only the BUILD-TREE probe's tag — the staged and PM
    probes suffix themselves ([tag_of_probe_lib_location]). So an
    Installed or Fetched world looked for its library's summary at a
    path only a Built world writes, which is the same world-blindness
    the constant [build_lib_tag] had, one level further in.

    It returns a LIST rather than one tag, for the same reason the
    filename candidates are a list: a world can carry more than one,
    the order states which is preferred, and the reader selects by the
    inspector's declared [kind] so a wrong guess cannot be read as the
    right artifact. *)
let lib_evidence_tags (w : Canary_artifact.assignment) : string list =
  let build = build_lib_tag in
  let probe = Canary_basic.string_of_action Canary_basic.Probe_lib in
  (* the PM probe names the manager it resolved through — the same
     derivation [tag_of_probe_lib_location] uses, so the two cannot
     disagree about where the file went *)
  let pm_probe =
    probe ^ "_" ^ Canary_store.string_of_pm (Canary_store.detect_pm ())
  in
  let staged_probe = probe ^ "_staged" in
  match Canary_artifact.provision_of_lib w with
  | Canary_store.Fetched -> [ pm_probe; probe; build ]
  | Canary_store.Installed -> [ staged_probe; build; probe ]
  | Canary_store.Built | Canary_store.Vendored | Canary_store.Absent ->
      [ build; probe ]

(** THE COPY [build_lib] MADE, never the staged one (2026-09-14).

    {!lib_evidence_paths} answers "where is THIS WORLD's library", and
    for an Installed world the honest answer is the staged copy — which
    is right for every check that asks what a consumer will meet, and
    wrong for every check that asks what the build produced.

    A [build_lib_post] agreement is the second kind. Asking the
    world-aware derivation gave it the staged file and it reported
    [inconclusive: the library records no identity] on Installed
    worlds, because the staged copy was a stale pre-[-soname] build —
    a post-check answering a question about the wrong artifact, and
    only noticed because the two copies had drifted.

    The rule the [pre]/[post] slots make explicit: a PRE-check wants
    the world's library, a POST-check wants the copy its own action
    produced. [staged_interface_preserved] already names both sides
    positionally for the same reason. *)
let built_lib_evidence_paths (file : string) : string list =
  [ build_lib_tag ^ "/" ^ file;
    Canary_basic.string_of_action Canary_basic.Probe_lib ^ "/" ^ file ]

(** The library's inspection paths for one filename, in world order. *)
let lib_evidence_paths (w : Canary_artifact.assignment) (file : string) :
    string list =
  List.map (lib_evidence_tags w) ~f:(fun t -> t ^ "/" ^ file)

(* ── the agreements, by name ─────────────────────────────────────────

   DESCRIPTIVE IDENTIFIERS since 2026-09-12 (user). The c1..c9
   numbering said nothing, could not be read in a log, and — worse —
   made two different claims share one identity whenever a family
   checked an artifact both against a declaration and against a peer.
   Those were the "solo" and "pair" cells, and calling them cells
   hid that they have different references, different evidence and
   different attribution on failure. They are separate agreements with
   separate names now, and solo/pair is gone from the identity.

   The repacking pair keeps provisional names: what "preserves" and
   "loses nothing" permit is undecided (design §6.3.1), and a name
   should not settle a claim the catalogue has not. *)

type agreement_id =
  (* symbols *)
  | Declared_symbols_exported   (** lib vs the project's declared c_api *)
  | Required_symbols_exported   (** lib vs what a consumer's stub requires *)
  (* api names *)
  | Api_names_present           (** binding's user surface vs the watchlist *)
  (* behavior *)
  | Behavior_matches
  (* identity *)
  | Soname_matches_declaration  (** lib's own name vs the declared one *)
  | Soname_matches_requirement  (** lib's own name vs what a consumer recorded *)
  (* symbol versions *)
  | Declared_versions_exported
  | Required_versions_exported
  (* signatures *)
  | Signatures_agree
  (* dependencies *)
  | Dependencies_provided
  (* staging — the one DISTANCE-0 agreement: both copies still exist *)
  | Staged_interface_preserved
  (* repacking — PROVISIONAL names, see above *)
  | Repack_preserves_api
  | Repack_complete

let string_of_agreement_id = function
  | Declared_symbols_exported -> "declared_symbols_exported"
  | Required_symbols_exported -> "required_symbols_exported"
  | Api_names_present -> "api_names_present"
  | Behavior_matches -> "behavior_matches"
  | Soname_matches_declaration -> "soname_matches_declaration"
  | Soname_matches_requirement -> "soname_matches_requirement"
  | Declared_versions_exported -> "declared_versions_exported"
  | Required_versions_exported -> "required_versions_exported"
  | Signatures_agree -> "signatures_agree"
  | Dependencies_provided -> "dependencies_provided"
  | Staged_interface_preserved -> "staged_interface_preserved"
  | Repack_preserves_api -> "repack_preserves_api"
  | Repack_complete -> "repack_complete"

(** Every id, in catalogue order. Total by construction — a new
    agreement that is not added here fails [agreements.ids_are_total]. *)
let all_agreement_ids =
  [ Declared_symbols_exported; Required_symbols_exported; Api_names_present;
    Behavior_matches; Soname_matches_declaration; Soname_matches_requirement;
    Declared_versions_exported; Required_versions_exported; Signatures_agree;
    Dependencies_provided; Staged_interface_preserved; Repack_preserves_api;
    Repack_complete ]

(** Parse a canonical name back into an id. Case-insensitive on the
    name; nothing else is accepted, and in particular the retired
    [c1..c9] spellings are NOT — an id that no longer exists must not
    round-trip, or a stale cache entry would keep displaying it. *)
let agreement_id_of_string s =
  let s = String.lowercase (String.strip s) in
  List.find all_agreement_ids ~f:(fun id ->
      String.equal (string_of_agreement_id id) s)

(** Parse a comma-separated list like
    ["soname_matches_requirement,required_versions_exported"]. Returns
    the parsed ids and the words that did not parse, so a caller can
    report an unknown name instead of silently ignoring it (the old
    form dropped them). *)
let agreement_ids_of_csv s : agreement_id list * string list =
  let words =
    String.split s ~on:','
    |> List.map ~f:String.strip
    |> List.filter ~f:(fun w -> not (String.is_empty w))
  in
  let known =
    List.filter_map words ~f:agreement_id_of_string
  in
  let unknown =
    List.filter words ~f:(fun w -> Option.is_none (agreement_id_of_string w))
  in
  (known, unknown)

(** THE CACHE EPOCH for agreement-derived verdicts (2026-09-12).

    A verdict marker for a compat expectation records WHICH agreements
    confirmed the failure, by name. Renaming the agreements therefore
    invalidates the content of those markers and nothing else — not a
    build, not a fetch, not a probe whose expectation never consulted
    an agreement. [Canary_local_runner.expectation_form] mixes this
    into the step fingerprint for exactly the two compat variants, so
    the existing warm-skip gate re-runs the affected steps and leaves
    everything else warm. Bump it when the evaluation semantics change,
    not when a comparator's internals do.

    THE RULE FOR WHERE IT GOES: an expectation carries the epoch iff
    its ACCEPTANCE consults an agreement. That is still exactly the two
    compat variants. The context evaluation runs at more steps than
    those, but it only REPORTS there — an [Expect_success] step's
    verdict does not depend on any agreement, so invalidating it would
    discard a verdict this change says nothing about.

    - [named-agreements-1] (2026-09-12): descriptive names, which the
      markers record.
    - [named-agreements-2] (2026-09-12): ONE evaluation record per
      step. A compat step's predicted diagnostics are now the union of
      the declared-input evidence and the context-derived evidence, so
      a step that saw no prediction before can see one now — and for
      [Expect_compat_derived], whose polarity follows the prediction,
      that flips the verdict. A cache migration is required exactly
      because the meaning of the cached verdict changed. *)
let evaluation_schema = "named-agreements-2"

(* ── loader support shared by the check families ──
   These sit with the JSON primitives because that is what they are:
   reading an inspect JSON, and expanding a dotted name into the forms
   a log might show. *)

let pick_existing ~resolve paths =
  List.find_map paths ~f:(fun rel ->
    let abs = resolve rel in
    if Stdlib.Sys.file_exists abs then Some abs else None)

(** The [kind] an inspection declares about itself, or [None] if the
    file is unreadable or says nothing. *)
let read_kind path : string option =
  try
    match field (Yojson.Basic.from_file path) "kind" with
    | Some (`String k) -> Some k
    | _ -> None
  with _ -> None

(** THE FIRST CANDIDATE THAT IS THE RIGHT ARTIFACT (2026-09-12).

    Evidence used to be picked by filename: the first candidate path
    that existed won, whatever was in it. That is safe only while every
    project spells its inspections the same way, and they do not — the
    framework's OCaml surface lands in [inspect.json] and its compiled
    stub in [inspect_stub.json], while tiny's stub is the [inspect.json]
    and its surface is [inspect_mli.json]. One candidate list covering
    both conventions would, on the wrong project, hand a stub summary to
    the watchlist check and a surface summary to the symbol check.

    Selecting by the [kind] the inspector wrote makes the order of the
    candidates irrelevant and a wrong-artifact read impossible: a path
    that exists but holds something else is simply not this method's
    evidence, and the method reports [Unavailable] with the rest. *)
let pick_existing_of_kind ~resolve ~(kinds : string list) paths =
  List.find_map paths ~f:(fun rel ->
      let abs = resolve rel in
      if not (Stdlib.Sys.file_exists abs) then None
      else
        match read_kind abs with
        | Some k when List.mem kinds k ~equal:String.equal -> Some abs
        | _ -> None)

(** The watchlist a binding inspection recorded: (present, missing).
    Both empty means the inspection ran with no watchlist at all, which
    is NOT the same as a watchlist that was fully satisfied — the
    distinction the design insists on ("an empty declaration must not be
    interpreted as successful coverage"), and the reason this returns
    the pair rather than just the missing half.

    [None] means THIS FILE CARRIES NO WATCHLIST SECTION, and nothing
    else. A malformed file raises out of [load] and becomes an [Error]
    outcome; it used to be swallowed by a [with _ -> None] and read as
    "no watchlist", which is a different and much more comfortable
    answer than the truth (2026-09-12 audit). *)
let load_watchlist path : (string list * string list) option =
  if not (Stdlib.Sys.file_exists path) then None
  else
    let j = load path in
    match field j "watchlist" with
    | Some wl -> Some (get_string_list wl "present", get_string_list wl "missing")
    | None -> None

let load_watchlist_missing path =
  match load_watchlist path with Some (_, missing) -> missing | None -> []

let name_variants e =
  let parts = String.split e ~on:'.' in
  let suffix_no_top = match parts with
    | _ :: (_ :: _ as rest) -> [ String.concat ~sep:"." rest ]
    | _ -> []
  in
  let last = match List.last parts with Some l -> [ l ] | None -> [] in
  e :: suffix_no_top @ last

(* ── counterexamples ─────────────────────────────────────────────── *)

(** A COUNTEREXAMPLE: synthetic inspect JSON plus the outcome the
    method MUST reach on it. A method that cannot show one is not
    wired, whatever the registry says about it — which is why the
    firing table marks ✓ only where a fixture exists.

    It names the METHOD rather than carrying a closure (2026-09-12).
    The closure existed because a solo comparison took its declaration
    as a partially-applied argument and so could not be the row's own
    predict; declarations are [inspect_input]s now, so every fixture
    runs the real method the registry would run.

    The bodies are SYNTHETIC. They borrow names from real findings
    ([tiny_sum] and [libtiny.so.1] from the witness,
    [Llvm.Opcode.UncondBr] and [Solver.add] from the two live
    mismatches) so that a reader can see which case each one echoes,
    but nothing about the check depends on the spelling. *)
type fixture = {
  fx_method : string;                  (** which method it exercises *)
  fx_inputs : inspect_input list;
  fx_bodies : (string * string) list;  (** file name → synthetic JSON *)
  fx_outcome : string;                 (** expected [outcome_label] *)
  fx_findings : string list;           (** substrings the diagnostics must yield *)
}

(* ── the agreement, and its checking methods ─────────────────────── *)

(** ONE WAY OF OBSERVING AN AGREEMENT.

    An agreement is a claim; a method is a way to look. The two were
    one record until 2026-09-12, which is why "is c1 implemented?" had
    no answer: the symbol agreement's peer comparison runs in every
    project and its declaration comparison has never had a caller, and
    one [status] field had to stand for both.

    [m_eval = None] means PLANNED: the method is declared, it is
    selected wherever it applies, and it reports
    [Not_implemented m_planned]. It never reports [Holds]. *)
type checking_method = {
  m_name : string;
      (** unique within the agreement; the name that appears in a log *)
  m_kind : method_kind;
  m_reference : reference;
  m_applicable :
    Canary_mechanism.mechanism -> Canary_lang.lang ->
    Canary_artifact.assignment -> applicability;
      (** whether this world offers the claim at all — a mechanism
          question, answered before evidence is looked for *)
  m_firing :
    Canary_mechanism.mechanism -> Canary_lang.lang ->
    Canary_artifact.assignment -> Canary_basic.action list;
      (** WHERE it fires, over the ACTION catalogue (SSOT §6.5). *)
  m_inputs : action_context -> inspect_input list;
      (** WHAT it reads, as evidence references resolved against the
          world's own output tree.

          It takes the whole CONTEXT while [m_applicable] and
          [m_firing] still take the three fields, and the asymmetry is
          the point rather than an oversight: those two ask about the
          shape of the WORLD — does this mechanism carry the claim,
          which actions exist — and the world is exactly mechanism,
          language and provisioning. This one asks what EVIDENCE
          exists, and a project's declaration is evidence that belongs
          to none of those three. Widening all three would have been
          churn; widening the one that reads evidence is the
          distinction. *)
  m_eval : evaluator option;
  m_planned : string;
      (** why there is no evaluator; reported as the [Not_implemented]
          reason. Empty exactly when [m_eval] is [Some]. *)
  m_diagnostics : outcome -> string list;
      (** PREDICTION OF DIAGNOSTIC TEXT, deliberately separate from
          evaluation: the substrings a failing run's log is expected to
          contain. Usually the findings verbatim; api-name checks
          expand a dotted name into the forms a compiler actually
          prints. A caller that wants the verdict reads the outcome. *)
  m_limits : string;
      (** what a [Holds] from THIS method does not establish *)
  m_counterexamples : fixture list;
}

(** WHOSE RULE AN AGREEMENT RECOVERS, in parts (2026-09-13, user).

    It was one prose sentence, which read well and could not be put in
    a column. Splitting it keeps the sentence (as [rt_note]) and makes
    the three facts a reader sorts by — which action, which tool, about
    which artifact — available to a generated table.

    An UNROOTED agreement leaves [rt_action] empty. That is the whole
    point of the type: no toolchain enforces that a wrapper faithfully
    repacks what it wraps, so there is no rule to recover, only one to
    state. Three of the registry's agreements are like this, and they
    are exactly the three with no evaluator. *)
type rooting = {
  rt_action : string;
      (** THE ACTION whose rule this recovers, and it is an ACTION —
          one [Canary_basic.action_of_string] parses — or [""] for an
          agreement no tool's rule roots (2026-09-14, user: "the cell
          must be an action").

          It held prose at first: "the link that built the binding",
          "the link, then every load". True, and unusable as a column —
          half the cells named a step and half described one, so the
          column could not be sorted, matched against [canary paths],
          or read at a glance. The qualification moved to
          [rt_artifact], which is prose by nature.

          The lang-parameterised actions are spelled for OCaml, as
          [ag_slot] is in the same table: the claim is language-neutral
          but a column has to pick, and picking consistently is what
          lets the two columns be read together.

          Pinned by [agreements.rooting_names_an_action]. *)
  rt_tool : string;      (** what enforced it when it ran *)
  rt_artifact : string;
      (** what the rule is about — and where the action alone would
          mislead, why. This is the column that carries "it ran in
          whatever world built that consumer, which this graph need not
          contain". *)
  rt_note : string;      (** the qualifier a column cannot hold *)
}

let rooted ~action ~tool ~artifact ~note () =
  { rt_action = action; rt_tool = tool; rt_artifact = artifact; rt_note = note }

(** No action's rule roots this — it is a claim somebody makes, not a
    rule a tool applies. *)
let unrooted ~note () =
  { rt_action = ""; rt_tool = "—"; rt_artifact = "—"; rt_note = note }

let is_rooted (r : rooting) : bool = not (String.is_empty r.rt_action)

(** WHERE A CHECK BELONGS IN THE ACTION SEQUENCE (2026-09-14, user).

    Canary's chain alternates [action, artifact, action, artifact …],
    so every check has a slot even when the artifact it examines sits
    between two actions: a [Post] check validates what an action just
    MADE, a [Pre] check states a requirement the next action DEPENDS
    ON. Those read differently and attribute differently —
    [build_lib_post] failing blames the compiler, [build_binding_pre]
    failing blames the pair about to be combined.

    THIS IS NOT [m_firing], and the distinction is the whole point.
    Firing is where an outcome is physically produced, which is
    wherever the evidence happened to land and is an accident of
    inspector placement; [required_symbols_exported] fires at two
    actions and would occupy two cells. The SLOT is where a reader
    should look for it, and there is one.

    Nor is it derivable. The obvious rule — a [Declared_facts]
    reference is [Post] (artifact against its own declaration), a
    [Peer_artifact] one is [Pre] (artifact against what it will meet)
    — holds for nine of the thirteen and breaks in both directions:
    [staged_interface_preserved] compares two peers yet validates
    [install_lib]'s own output, and [api_names_present] compares
    against a declaration yet is a precondition for [build_app]. So
    each agreement states it. *)
type stage = Pre | Post

let string_of_stage = function Pre -> "pre" | Post -> "post"

(** A slot is a LIST of candidates, first present in this world's chain
    winning — the same shape as evidence paths and firing sites, and
    for the same reason. A world need not contain the action an
    agreement would most like to sit before: sqlite FETCHES its OCaml
    binding, so there is no [build_binding_ocaml] to precede, and
    [required_symbols_exported] falls through to the probe.

    It is a FUNCTION OF THE LANGUAGE because most of these actions are
    per-language ([Build_binding OCaml] and [Build_binding Python] are
    different columns), and a project with two bindings genuinely wants
    two cells: sqlite's [required_symbols_exported] holds on the OCaml
    side and is unavailable on the Python one, which is two facts. The
    mechanism is deliberately NOT a parameter — it changes what an
    agreement can claim, never where in the graph the claim sits. *)
type check_slot = Canary_lang.lang -> (Canary_basic.action * stage) list

let string_of_slot ((a, s) : Canary_basic.action * stage) : string =
  Canary_basic.string_of_action a ^ "_" ^ string_of_stage s

(** THE SHORT CODE a narrow column head can carry — the initial of each
    underscored word, so [declared_symbols_exported] is [dse]
    (2026-09-14, user).

    DERIVED, not declared, so it cannot drift from the name. The risk
    of deriving is collision, which is why
    [agreements.short_codes_are_unique] pins it: two agreements sharing
    a code would make one column silently stand for the other, and the
    thirteen happen to be distinct. A future name that collides fails
    the pin rather than the reader. *)
let short_code_of_slug (slug : string) : string =
  String.split slug ~on:'_'
  |> List.filter_map ~f:(fun w ->
         if String.is_empty w then None else Some (String.prefix w 1))
  |> String.concat

(** The slot this world's chain actually offers for one language.
    [None] = none of the candidates is in the chain, so the agreement
    has no column there. *)
let slot_in_chain (slot : check_slot) ~(lang : Canary_lang.lang)
    ~(chain : Canary_basic.action list) :
    (Canary_basic.action * stage) option =
  List.find (slot lang) ~f:(fun (a, _) ->
      List.exists chain ~f:(fun c -> Poly.equal c a))

(** The slot shorthands the families use. [at_lib] is for a claim about
    the library itself, which no language parameterizes. *)
let at_lib (a : Canary_basic.action) (s : stage) : check_slot =
 fun _ -> [ (a, s) ]

(** A consumer-side claim: it belongs before the action that BUILDS the
    binding, and before the one that PROBES it where the binding is
    fetched rather than built. *)
let before_binding : check_slot =
 fun l ->
  [ (Canary_basic.Build_binding l, Pre);
    (Canary_basic.Probe_binding l, Pre) ]

(** A claim about the binding artifact itself, rather than about what
    it will be combined with. *)
let after_binding : check_slot =
 fun l ->
  [ (Canary_basic.Build_binding l, Post);
    (Canary_basic.Probe_binding l, Post) ]

(** HOW AN AGREEMENT DESCRIBES ITSELF. Every field is a fact only the
    agreement knows, so every field is stated by the family's own
    module. The registry adds what is not self-knowledge — the doc
    anchor, the enabled flag, the position in the list — and derives
    the views. *)
type agreement = {
  ag_subject : subject;
  ag_claim : claim;
  ag_basis : basis;
  ag_says : string;
      (** falsifier-phrased: the sentence a counterexample refutes *)
  ag_expects : string;
      (** the reference expectation, in prose: what the observation is
          held against, and therefore what a failure attributes to *)
  ag_rooted_in : rooting;
      (** WHICH ACTION'S RULE THIS RECOVERS, and which tool enforced it
          — theory.md §2's central concept, made explicit in the code
          (2026-09-13, user).

          An action's implementation embodies a relation over its
          inputs, and running it is the only witness that a tuple
          satisfies that relation. Most agreements here re-derive a
          fragment of such a rule from what survived: the linker's
          "every reference is defined" becomes
          [required_symbols_exported], the C compiler's "the call
          matches the declaration" becomes [signatures_agree].

          Some have no such rule. Nothing in any toolchain enforces
          that a wrapper is a faithful repacking of what it wraps, or
          that a function returns what a project expected — those are
          claims a person makes, not rules a tool applies. Saying so
          here separates "waiting on wiring" from "waiting on somebody
          to state a specification", which are different kinds of
          unfinished and were previously both spelled "planned".

          [rt_action] is a STRING, not a [Canary_basic.action], and
          deliberately: the rule that roots
          [soname_matches_requirement] ran in whatever world built the
          consumer, an action this world's graph does not contain, and
          the one behind [required_symbols_exported] is "the link",
          which is several actions depending on who is linking. A typed
          reference would have to lie about both. Drawing this as a
          relation needs a different field; that is deferred in
          registry.md §7.4.3.

          The FIRING sites remain [m_firing]. An agreement is rooted
          where the rule ran and detected wherever evidence survives,
          and those are usually different actions. *)
  ag_slot : check_slot;
      (** WHERE A READER LOOKS FOR THIS — see {!check_slot}. The
          column in [canary result]; one per agreement however many
          actions it fires at. *)
  ag_fault_tag : string;
  ag_methods : checking_method list;
}

(** Always applicable — the default for a method whose claim exists
    wherever it fires. *)
let always_applicable _ _ _ = Applicable

(** Build a method. [eval] omitted ⇒ planned, and [planned] is then
    required to say why (an empty reason is a programming error the
    registry pin catches). *)
let checking_method ~name ~kind ~reference ?(applicable = always_applicable)
    ~firing ~inputs ?eval ?(planned = "") ?diagnostics ~limits
    ?(counterexamples = []) () : checking_method =
  { m_name = name;
    m_kind = kind;
    m_reference = reference;
    m_applicable = applicable;
    m_firing = firing;
    m_inputs = inputs;
    m_eval = eval;
    m_planned = planned;
    m_diagnostics =
      (match diagnostics with Some d -> d | None -> findings_of_outcome);
    m_limits = limits;
    m_counterexamples = counterexamples }

(** The method of [ag] with this name. *)
let method_of (ag : agreement) (name : string) : checking_method option =
  List.find ag.ag_methods ~f:(fun m -> String.equal m.m_name name)

(** Does the agreement have at least one method with an evaluator? *)
let has_evaluator (ag : agreement) : bool =
  List.exists ag.ag_methods ~f:(fun m -> Option.is_some m.m_eval)

(** Evaluate one method against a world, an action and the evidence it
    names. THE evaluation entry point: every caller goes through it, so
    the seven non-[Holds] outcomes cannot be produced by accident.

    Order matters, and each step answers a different question:
    disabled, then applicable, then implemented, then evaluate. A
    method that is switched off must not be reported as inapplicable,
    and one that does not apply must not be reported as unimplemented. *)
let evaluate_method ?(disabled = false) ~(mechanism : Canary_mechanism.mechanism)
    ~(lang : Canary_lang.lang) ~(world : Canary_artifact.assignment)
    ?(declared : Canary_artifact.t option)
    ~(resolve : string -> string) ?inputs (m : checking_method) : outcome =
  if disabled then Disabled "switched off for this run"
  else
    match m.m_applicable mechanism lang world with
    | Inapplicable why -> Not_applicable why
    | Applicable -> (
        match m.m_eval with
        | None ->
            Not_implemented
              (if String.is_empty m.m_planned then "no evaluator" else m.m_planned)
        | Some ev -> (
            let ins =
              match inputs with
              | Some i -> i
              | None ->
                  m.m_inputs
                    { ac_mechanism = mechanism; ac_lang = lang;
                      ac_world = world; ac_declared = declared }
            in
            try normalize_outcome (ev ~resolve ins)
            with exn -> Error (Exn.to_string exn)))
