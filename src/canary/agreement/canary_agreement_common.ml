(** [Canary_agreement_common] — TIER 1: what every check family needs.

    The agreement layer is three tiers (2026-09-02, user): this module
    declares the common types; each [canary_chk_<topic>] is one concrete
    family that uses those types to describe ITSELF; and
    [Canary_agreement_registry] lists the families and derives the views
    others read. A family refers only to this module — pinned by
    [agreements.families_do_not_reach_sideways].

    What lives here, and why each thing is common rather than a
    family's:

    - the DESCRIPTIVE types a check uses to describe itself — [cat],
      [standing], [claim], [evidence], [provenance], and the
      [description] record that gathers them;
    - the [inspect_input] ADT, which NAMES evidence (the records that
      parse it belong to the family that reads them);
    - the registry vocabulary — [agreement_id], [agreement_status],
      [agreement_check];
    - the shared derivations a family needs in order to state where it
      fires and what it reads: [firing_default],
      [firing_with_build_lib], [firing_probe_only], [uniform_world],
      [binding_evidence_tag];
    - the JSON primitives every loader is built from.

    The rule that decides membership: a family owns whatever is only
    about its own topic; this module owns what more than one family
    needs. Applying it moved the comparators, the result types and the
    evidence records OUT of here (755 → this), and moved [cat] and the
    firing derivations IN. *)

open Base

(* Static compatibility check between a binding's stub archive (consumer side:
   "what C symbols this binding requires from the native lib") and a native
   library's defined-symbols summary (provider side: "what this .so exports").

   Inputs are summary.json files produced by inspect_binding.py --kind stub
   and inspect_native.py --emit-symbols, respectively. Output is a verdict
   on `requires ⊆ provides`.

   See doc/canary/design/api_surface.md §13 for the design.
   The OCaml-level half is already covered by the mli summary's watchlist
   (e.g. Llvm.Opcode.UncondBr present/missing). Together they form the
   set-inclusion necessary-condition layer (L0/L1) of the compatibility
   lattice from api_surface.md §15. *)

(* ── Summary loaders ── *)

let load path : Yojson.Basic.t =
  if not (Stdlib.Sys.file_exists path) then (
    Fmt.epr "compat: %s not found@." path;
    Stdlib.exit 2);
  Yojson.Basic.from_file path

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

(** [inspect_input] — what inspector JSON kind feeds a comparator
    prediction. Carries a {i list} of candidate paths (different action
    paths in the graph write the same logical artifact to different
    relative locations — [pack_binding_ocaml/inspect_stub.json] vs.
    [fetch_binding_ocaml/inspect_stub.json] for OCaml stub, for example).
    The runner picks the first existing path via [~resolve].

    Unified on 2026-06-01 (Phase 4): previously this type lived twice,
    as [Canary.compat_inspect_input] (paths : string list) on the
    declaration side and as [typed_input] (single
    string) after resolution, with a manual 20-line translation in
    [Canary_action] and [Canary_gh]. Constructors map to surface
    roles:

    - [C_stub p]            ↔ {i bo7 compiled_binding_ocaml.stub-a}.
                              Feeds {i c1 cmp_symbol}.
    - [Native_lib p]        ↔ {i n4 lib_native.so}. Feeds {i c1 cmp_symbol}
                              and {i c4 cmp_abi} predictions.
    - [Ocaml_mli p]         ↔ {i bo4 user_binding_ocaml.mli}. Feeds the
                              {i c2 cmp_api_completeness} watchlist check.
    - [Python_attrs p]      ↔ {i bpe2 user_binding_cext.py} or
                              {i bpc2 user_binding_ctypes.py}. Same role
                              as [Ocaml_mli] for the Python flavour.
    - [Versioned_exports p] ↔ provider's {i n4}'s [versioned_exports].
                              Feeds {i c5 cmp_sym_version} (L1b).
    - [Versioned_req p]     ↔ consumer's [versioned_req]. Same.
    - [Abi_surface p]       ↔ {i n4}'s ELF SONAME/NEEDED/RPATH. Feeds
                              {i c4 cmp_abi} (L4). *)
type inspect_input =
  | C_stub of string list
  | Native_lib of string list
  | Ocaml_mli of string list
  | Python_attrs of string list
  | Versioned_exports of string list  (** provider side, n4's elf.versioned_exports *)
  | Versioned_req of string list      (** consumer side, e.g. cext's elf.versioned_req *)
  | Abi_surface of string list
  (* Typed-signature inputs for c6 / c7 / c8.
     Producer side ([Typed_header]) and consumer sides
     ([Typed_binding_stub], [Typed_binding_user]) all carry the same
     JSON shape — only the layer differs. See
     [canary/scripts/inspect_tiny_typed.py] for the (trivial-grep)
     inspector producing them; replace with real AST inspectors when
     they land. *)
  | Typed_header of string list         (* n3 — provider C sigs *)
  | Typed_binding_stub of string list   (* bo1/bpe1 — consumer C sigs *)
  | Typed_binding_user of string list   (* bo4/bpe2 — consumer language sigs *)

(* Each family's evidence RECORDS and their loaders moved to the family
   that reads them (2026-09-02): [stub_inspect]/[native_inspect] to
   [Canary_chk_symbols], the elf and version views to
   [Canary_chk_identity], the typed signatures to [Canary_chk_types].
   What stays here is what more than one family needs — the JSON
   primitives, the [inspect_input] ADT that NAMES evidence, and the
   agreement vocabulary. The rule: a family owns whatever is only about
   its own topic; this module owns what is common. *)

(* ── Cross-check ── *)

(* the c1 comparator and [compat_result] moved to [Canary_chk_symbols];
   the c4/c5 comparators and their result types moved to
   [Canary_chk_identity] (2026-09-02, user: "shall we put the checking
   into a corresponding canary_chk_ file rather than in this file") —
   a family's check, its result shape and its predict now sit together *)

(* the c6 comparator and [type_result] moved to [Canary_chk_types];
   the c7/c8 comparators and their result types to
   [Canary_chk_behaviour] *)


(* [check_c_compat] and [lag_examples] moved to [Canary_chk_symbols],
   with [compat_result] — see the note at that type's old site *)

(* ── Agreement registry vocabulary (Phase 12, 2026-06-02) ─────────────
   The c1..c8 surface-theory agreements as a registered collection. Each
   entry pairs an agreement id with its status, the action-graph layer it
   sits in (L0/L1b/L2/L3/L4), an enable flag, and the predicate that
   turns [inspect_input list] into expected failure substrings.

   The rows and the dispatch live in {!Canary_agreement_registry}; this
   file defines only the types, so they are available to every check
   family below the registry. That is also why the CATEGORY lives here
   (2026-09-02, user: "why do we need a check_cat file separately? can
   we merge it into registry?") — it cannot go in the registry, which
   reads each family's [cat] and would then depend on the modules that
   depend on it. This file is the one place below all of them. *)

(** The check CATEGORY — descriptive.

    A category says what kind of claim a check makes. Nothing dispatches
    on it: it groups the catalogue, the checking index and the doc, and
    it is deliberately allowed to refine as checks accumulate, because a
    descriptive type costs nothing to sharpen.

    It is NOT the check's signature. Checks keep whatever signature suits
    them — a symbol comparison and a repo-pin query have no reason to
    agree — and the caller supplies the inputs and decides where to dump
    the evidence on failure. *)
type cat =
  | Symbols   of [ `Exported | `Required | `Versioned | `Orphan ]
  | Api       of [ `Present | `Complete | `Repacked ]
  | Identity  of [ `Soname | `Version_node ]
  | Types     of [ `Signature | `Arity ]
  | Behaviour of [ `Trace | `Differential ]
  | Repo      of [ `Pin | `Freshness | `Contents ]
  | Staging   of [ `Completeness | `Parity | `Portability ]
  | Action_succeeded
      (** the weakest claim available: the tool did not error, and its
          declared output appeared. No artifact is read — which is why
          §1.1 says to inspect the product wherever one exists. Free at
          every action, and it is what a later blame step has to start
          from. *)
  | Meta      of [ `Spec | `Framework ]
      (** about canary's own declarations rather than the tools' *)

let string_of_cat = function
  | Symbols `Exported -> "symbols/exported"
  | Symbols `Required -> "symbols/required"
  | Symbols `Versioned -> "symbols/versioned"
  | Symbols `Orphan -> "symbols/orphan"
  | Api `Present -> "api/present"
  | Api `Complete -> "api/complete"
  | Api `Repacked -> "api/repacked"
  | Identity `Soname -> "identity/soname"
  | Identity `Version_node -> "identity/version-node"
  | Types `Signature -> "types/signature"
  | Types `Arity -> "types/arity"
  | Behaviour `Trace -> "behaviour/trace"
  | Behaviour `Differential -> "behaviour/differential"
  | Repo `Pin -> "repo/pin"
  | Repo `Freshness -> "repo/freshness"
  | Repo `Contents -> "repo/contents"
  | Staging `Completeness -> "staging/completeness"
  | Staging `Parity -> "staging/parity"
  | Staging `Portability -> "staging/portability"
  | Action_succeeded -> "action-succeeded"
  | Meta `Spec -> "meta/spec"
  | Meta `Framework -> "meta/framework"

(** Is this agreement a CONVENTION — true of every project using the
    toolchain, declared by nobody (a findlib META naming an archive that
    exists, a wheel's EXT_SUFFIX matching its interpreter)? A marker, not
    a separate source: conventions are agreements that happen to be
    obligatory and project-independent, which makes them the richest
    place to look for new checks. *)
type standing = Declared | Convention

(** WHAT A CHECK CLAIMS — the primary axis (design §1.6). A structural
    claim is about artifacts and their FIT; a semantic claim is about
    what the program MEANS or does. The distinction is not "does it
    run": a link verdict is observed by running a tool and is still a
    structural finding, which is exactly the case that made this axis
    primary rather than the evidence one. *)
type claim =
  | Structural  (** about an artifact, or about two artifacts' fit *)
  | Semantic    (** about behaviour — what running it means *)
[@@deriving show, eq]

(** HOW the claim is observed — the secondary axis (design §1.5). It
    varies independently of [claim]: [Run_tool] carries structural
    claims (a compiler's verdict on a pairing), [Run_program] carries
    semantic ones. *)
type evidence =
  | Inspect_one       (** one artifact, an inspector *)
  | Compare_several   (** several artifacts, inspected then compared *)
  | Run_tool          (** a compiler/linker/loader verdict *)
  | Run_program       (** the program's own output *)
[@@deriving show, eq]

(** WHERE the obligation comes from (design §1.6): [Intrinsic] holds of
    the toolchain whether or not canary exists; [Added] is an
    expectation canary states. *)
type provenance =
  | Intrinsic
  | Added
[@@deriving show, eq]

(* ── where a check fires, and what it reads ──

   Both are DERIVED from mechanism × language × world, and both are
   things a check family states about itself, so the derivations live
   here rather than in the registry (2026-09-02, user: "the type
   especially for category should be defined in common, then the
   concrete chk can use the type to describe itself"). *)

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

(** c4/c5's lib-only cell: a BUILT lib carries its own inspection — elf
    soname / versioned exports vs the DECLARED facts. The LIB's
    provenance decides this one and the binding's decides
    [Build_binding] inside the rest, which is the whole point of taking
    a world. The discipline gate is preserved as it stood; whether a
    soname check should also fire under a Dynamic_ffi binding (where
    dlopen resolves BY soname, so arguably it matters more) is a
    separate question. *)
let firing_with_build_lib (m : Canary_mechanism.mechanism)
    (l : Canary_lang.lang) (w : Canary_artifact.assignment) :
    Canary_basic.action list =
  let rest = firing_default m l w in
  if (not (is_dynamic m)) && produced_here (Canary_artifact.provision_of_lib w)
  then Canary_basic.Build_lib :: rest
  else rest

(** Behaviour needs a run — probe only, in every world. *)
let firing_probe_only (_ : Canary_mechanism.mechanism) (l : Canary_lang.lang)
    (_ : Canary_artifact.assignment) : Canary_basic.action list =
  [ Canary_basic.Probe_binding l ]

(** The UNIFORM world: lib and binding both at one provision. It is what
    a single provision argument used to mean, kept for the views that
    want a hypothetical rather than a real world (the belief matrix, the
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

(** A COUNTEREXAMPLE: synthetic inspect JSON plus the failure
    substrings the check MUST yield on it. A check that cannot show one
    is not wired, whatever the registry says about it — which is why
    the belief matrix marks ✓ only where a fixture exists.

    The bodies are SYNTHETIC. They borrow names from real findings
    ([tiny_sum] and [libtiny.so.1] from the witness,
    [Llvm.Opcode.UncondBr] and [Solver.add] from the two live
    mismatches) so that a reader can see which case each one echoes,
    but nothing about the check depends on the spelling — the fixture
    is a JSON string and an expected substring set, and it runs with no
    project anywhere near it. *)
type fixture = {
  fx_predict :
    (resolve:(string -> string) -> inspect_input list -> string list) option;
      (** the closure under test — [None] = the registered predict for
          this agreement. [Some] = a CELL predict, e.g. a solo cell's
          decl-comparison, which takes the declared facts as arguments
          and so cannot be the row's own closure. *)
  fx_inputs : inspect_input list;
  fx_bodies : (string * string) list;  (** file name → synthetic JSON *)
  fx_expect : string list;             (** substrings [predict] must yield *)
}

(** HOW AN AGREEMENT DESCRIBES ITSELF (2026-09-02, user: "the concrete
    chk can use the type to describe itself, and the registry just list
    the checked").

    Every field is a fact only the check knows, so every field is
    stated by the check's own module. The registry adds what is not
    self-knowledge — the slug, the doc anchor, the position in the
    list — and derives the views.

    The field this type exists for is [says]. It used to be written
    twice: as [~invariant] on the registry row and as [says] in the
    family, and all eight had drifted apart in wording by the time
    anyone compared them — c5's two read "versioned symbols carry the
    annotations the consumer expects" and "the provider exports every
    version node the consumer requires", which are not the same claim.
    One definition, one sentence. *)
type description = {
  cat : cat;
  standing : standing;
  says : string;
      (** falsifier-phrased: the sentence a counterexample refutes *)
  claim : claim;
  evidence : evidence;
  provenance : provenance;
  reads : (string * string) list;
      (** the artifact surfaces this grounds in: (Sf.n | Trace) × which
          artifact. The agreement IS a named relation over these. *)
  fault_tags : string list;
  firing :
    Canary_mechanism.mechanism -> Canary_lang.lang ->
    Canary_artifact.assignment -> Canary_basic.action list;
      (** WHERE it fires, over the ACTION catalogue (SSOT §6.5).
          Agreements are general for ALL artifacts, actions and
          mechanisms; a check returns [] for actions it does not fire
          at. *)
  inputs :
    Canary_mechanism.mechanism -> Canary_lang.lang ->
    Canary_artifact.assignment -> inspect_input list;
      (** WHAT it reads, as evidence references resolved against the
          world's own output tree. *)
  counterexamples : fixture list;
      (** the cases that prove it can FAIL — one per cell it covers
          (a solo cell and a pair cell are two). Empty = declared but
          never shown to fire, which the belief matrix renders [~].
          They live with the check for the same reason everything else
          here does: only the check knows what would falsify it
          (2026-09-02). *)
}

(** The eight contracts of surface theory. See
    [doc/canary/research/surface_draft/surface.md] Part C for definitions. *)
type agreement_id = C1 | C2 | C3 | C4 | C5 | C6 | C7 | C8

let string_of_agreement_id = function
  | C1 -> "c1" | C2 -> "c2" | C3 -> "c3" | C4 -> "c4"
  | C5 -> "c5" | C6 -> "c6" | C7 -> "c7" | C8 -> "c8"

(** Parse a string like ["c5"] back into a contract id. Accepts
    upper- or lower-case prefix; rejects anything else. Used by the
    CLI [--disable-contract] flag parser and by deserialisers. *)
let agreement_id_of_string s =
  match String.lowercase s with
  | "c1" -> Some C1 | "c2" -> Some C2 | "c3" -> Some C3 | "c4" -> Some C4
  | "c5" -> Some C5 | "c6" -> Some C6 | "c7" -> Some C7 | "c8" -> Some C8
  | _ -> None

(** Parse a comma-separated list like ["c4,c5"]. Silently drops
    anything that doesn't parse; the caller can re-validate the input
    if it cares about reporting unknown ids. *)
let agreement_ids_of_csv s =
  s
  |> String.split ~on:','
  |> List.filter_map ~f:(fun part ->
       let part = String.strip part in
       if String.is_empty part then None else agreement_id_of_string part)

(** Wiring status of a contract within canary's action graph.

    - [Wired] — full pipeline: inspect → predict → check, exercised by
      real projects.
    - [Inspect_only] — JSON output ready; the predict step reads it
      but no comparator runs (currently true of c5).
    - [Comparator_only] — pure [check_*] function exists in this file
      but isn't driven from the action graph.
    - [Blocked deps] — depends on these contracts being implemented
      first (e.g. c8 ⇐ [c6; c7]).
    - [Stubbed] — placeholder; the predict closure returns []. *)
type agreement_status =
  | Wired
  | Inspect_only
  | Comparator_only
  | Blocked of agreement_id list
  | Stubbed

(** Human label for a wiring status (the runner's [agreement_skipped]
    events name WHY a registry-disabled contract didn't fire). *)
let string_of_agreement_status = function
  | Wired -> "wired"
  | Inspect_only -> "inspect-only"
  | Comparator_only -> "comparator-only"
  | Blocked [] -> "blocked"
  | Blocked deps ->
      "blocked on "
      ^ String.concat ~sep:"," (List.map deps ~f:string_of_agreement_id)
  | Stubbed -> "stubbed"

(** One entry in the contract registry. [predict] consumes the same
    [inspect_input list + ~resolve] that {!Canary_agreement_run}'s top-
    level dispatcher does, and returns the substrings this contract
    predicts the probe.log will contain on failure. *)
type agreement_check = {
  id        : agreement_id;
  name      : string;        (* "cmp_symbol", "cmp_api_completeness", … *)
  layer     : string;        (* "L0", "L1b", "L3", "L4", … *)
  status    : agreement_status;
  enabled   : bool;
  predict   : resolve:(string -> string) -> inspect_input list -> string list;
}

(* ── loader support shared by the check families (2026-09-02) ──
   These sit with [load_stub] / [load_native] because that is what they
   are: reading an inspect JSON, and expanding a dotted name into the
   forms a log might show. They were briefly in a module of their own;
   "evidence" turned out not to be a category. *)

let pick_existing ~resolve paths =
  List.find_map paths ~f:(fun rel ->
    let abs = resolve rel in
    if Stdlib.Sys.file_exists abs then Some abs else None)

let load_watchlist_missing path =
  if not (Stdlib.Sys.file_exists path) then []
  else
    let j = Yojson.Basic.from_file path in
    match field j "watchlist" with
    | Some wl -> get_string_list wl "missing"
    | None -> []

let name_variants e =
  let parts = String.split e ~on:'.' in
  let suffix_no_top = match parts with
    | _ :: (_ :: _ as rest) -> [ String.concat ~sep:"." rest ]
    | _ -> []
  in
  let last = match List.last parts with Some l -> [ l ] | None -> [] in
  e :: suffix_no_top @ last
