(** Identity agreements — what an object calls itself, what a consumer
    recorded needing, and the version namespaces attached to symbols.

    FIVE agreements since 2026-09-12, where there were three ids with
    "solo" and "pair" cells inside them. Comparing a built library with
    the project's declaration and comparing it with a consumer's
    recorded requirement are different claims, with different
    references and different attribution on failure, so they are
    different agreements with different names. *)

open Base
open Canary_agreement_common

(* ── the evidence this family reads ── *)

(** ELF/Mach-O identity view of an inspect JSON. The producing
    inspector ([inspect_native.py] for the library;
    [inspect_binding.py --kind stub] for shared-object consumers) emits
    an [elf] sub-object with [soname] (string or null) and [needed]
    (list of strings). Either may be empty on archives or on platforms
    without readelf.

    The fields are normalized across formats; the resolution semantics
    behind them are NOT the same, which is why a name match here is
    never a statement about which object will be loaded. *)
type abi_surface_inspect = {
  path : string;
  soname : string option;
  needed : string list;
}

let load_abi_surface path =
  let j = load path in
  let elf = field j "elf" in
  let soname =
    match Option.bind elf ~f:(fun e -> field e "soname") with
    | Some (`String s) when not (String.is_empty s) -> Some s
    | _ -> None in
  let needed =
    match Option.bind elf ~f:(fun e -> field e "needed") with
    | Some (`List xs) ->
        List.filter_map xs ~f:(function `String s -> Some s | _ -> None)
    | _ -> [] in
  { path = get_string j "path"; soname; needed }

(** Versioned-symbol view of an inspect JSON. Produced by
    [inspect_native.py] (which reads [@@VER] / [@VER] suffixes from
    [nm -D]); fields are non-empty when the ELF artifact carries
    GNU symbol versioning.
    - [exports]: defined symbol → exported version tag (provider side).
    - [req_counts]: required version tag → reference count (consumer). *)
type versioned_symbols_inspect = {
  path : string;
  exports : (string * string) list;
  req_counts : (string * int) list;
}

let load_versioned_symbols path : versioned_symbols_inspect =
  let j = load path in
  let exports =
    match field j "versioned_exports" with
    | Some (`Assoc entries) ->
        List.filter_map entries ~f:(fun (sym, v) ->
          match v with `String ver -> Some (sym, ver) | _ -> None)
    | _ -> [] in
  let req_counts =
    match field j "versioned_req" with
    | Some (`Assoc entries) ->
        List.filter_map entries ~f:(fun (ver, v) ->
          match v with `Int n -> Some (ver, n) | _ -> None)
    | _ -> [] in
  { path = get_string j "path"; exports; req_counts }

(* Selected BY KIND — see the note in [Canary_agreement_symbols]. The
   identity and version records both live in a "native" summary, on the
   provider side and (for a shared-object consumer) on the consumer
   side, so both ask for the same kind from different paths. *)
let native_kinds = [ "native" ]

let native_path ~resolve inputs =
  List.find_map inputs ~f:(function
    | Native_lib ps -> pick_existing_of_kind ~resolve ~kinds:native_kinds ps
    | _ -> None)

let consumer_abi_path ~resolve inputs =
  List.find_map inputs ~f:(function
    | Abi_surface ps -> pick_existing_of_kind ~resolve ~kinds:native_kinds ps
    | _ -> None)

let versioned_exports_path ~resolve inputs =
  List.find_map inputs ~f:(function
    | Versioned_exports ps ->
        pick_existing_of_kind ~resolve ~kinds:native_kinds ps
    | _ -> None)

let versioned_req_path ~resolve inputs =
  List.find_map inputs ~f:(function
    | Versioned_req ps -> pick_existing_of_kind ~resolve ~kinds:native_kinds ps
    | _ -> None)

let declared_soname inputs =
  List.find_map inputs ~f:(function Declared_soname s -> Some s | _ -> None)

let declared_version_tags inputs =
  List.find_map inputs ~f:(function
    | Declared_version_tags t -> Some t
    | _ -> None)

(* ── the comparators ── *)

(** Provider exports a SONAME; consumer records a NEEDED list.
    Compatible iff [consumer_needed] contains [provider_soname].

    Catches the SONAME bump: the provider flips libtiny.so.1 →
    libtiny.so.2 while the consumer's NEEDED still names the old one —
    at static check time, before the loader fails the load. *)
type abi_result =
  | Abi_compatible
  | Abi_mismatch of { expected_soname : string; consumer_needed : string list }
  | Abi_unknown

let check_abi ~(provider_soname : string option) ~(consumer_needed : string list)
    : abi_result =
  match provider_soname with
  | None -> Abi_unknown
  | Some sn ->
      if List.is_empty consumer_needed then Abi_unknown
      else if List.mem consumer_needed sn ~equal:String.equal then Abi_compatible
      else Abi_mismatch { expected_soname = sn; consumer_needed }

(** Set inclusion on version tags: every version the consumer requires
    must be exported by the provider.

    End-to-end, this is the glibc case: a binary built on a newer
    distribution references [malloc@GLIBC_2.31]; on an older host the
    system libc exports only [@@GLIBC_2.17], so the required tag is
    missing from the provider's exported set. Exact string match on the
    tag — the linker normally records the specific version it built
    against, so floor comparison is a refinement, not a correction. *)
type sym_version_result =
  | Sym_version_compatible
  | Sym_version_missing of { missing_versions : string list }
  | Sym_version_unknown

let check_sym_version
    ~(provider_versioned_exports : (string * string) list)
    ~(consumer_required_versions : string list)
    : sym_version_result =
  if List.is_empty consumer_required_versions then Sym_version_unknown
  else if List.is_empty provider_versioned_exports then Sym_version_unknown
  else
    let provider_set =
      List.map provider_versioned_exports ~f:snd
      |> Set.of_list (module String) in
    let missing =
      List.filter consumer_required_versions ~f:(fun v ->
          not (Set.mem provider_set v))
      |> List.dedup_and_sort ~compare:String.compare in
    if List.is_empty missing then Sym_version_compatible
    else Sym_version_missing { missing_versions = missing }

(* ── dependency names and where they are answered from ── *)

(** The runtime libraries a world neither provides nor is asked to.
    They resolve from the ambient system — libc through the program
    interpreter that ships as its own sibling, the rest through
    [/etc/ld.so.cache] — so a consumer naming one of these says nothing
    about this world's artifacts.

    This is the DEFAULT exclusion, not a law, and it is currently CODE
    rather than a per-world policy parameter — the standing limitation
    recorded on the agreement. A world that ships its own C++ runtime
    should take [libstdc++] off this list, and then an ambient
    resolution IS a finding there. *)
let ambient_runtime =
  [ (* ELF *)
    "libc.so.6"; "libm.so.6"; "libdl.so.2"; "libpthread.so.0";
    "librt.so.1"; "libgcc_s.so.1"; "libstdc++.so.6";
    "ld-linux-x86-64.so.2"; "ld-linux-aarch64.so.1";
    (* Mach-O records an install name, so these are paths *)
    "/usr/lib/libSystem.B.dylib"; "/usr/lib/libc++.1.dylib" ]

(** Where a recorded name is answered from. Three-valued on purpose:
    which of the three counts as a violation is policy, and a run
    record that keeps the origin of every dependency is derivation
    data attribution can read later. *)
type needed_origin =
  | Provided_by_world of string    (** this world's provider exports it *)
  | Provided_by_ambient of string  (** a runtime library the system answers *)
  | Unprovided of string           (** nothing here offers it *)

let classify_needed ~(provider_soname : string option)
    ~(needed : string list) : needed_origin list =
  List.map needed ~f:(fun n ->
      match provider_soname with
      | Some sn when String.equal sn n -> Provided_by_world n
      | _ ->
          if List.mem ambient_runtime n ~equal:String.equal then
            Provided_by_ambient n
          else Unprovided n)

(* ── the evaluators ── *)

let soname_declaration_eval ~resolve inputs : outcome =
  match declared_soname inputs with
  | None ->
      Unavailable
        "this project declares no soname for its library, so there is \
         nothing to hold the artifact's recorded identity against. A \
         project to-do, not a gap in canary: set [native_api.soname] and \
         this decides"
  | Some declared -> (
      match native_path ~resolve inputs with
      | None -> Unavailable "no native library inspection in this world"
      | Some p -> (
          match (load_abi_surface p).soname with
          | None ->
              Inconclusive
                "the library records no identity (an archive, or a format \
                 without one)"
          | Some s when String.equal s declared -> Holds
          | Some s ->
              Violated
                [ Printf.sprintf "soname %s != declared %s" s declared ]))

let soname_requirement_eval ~resolve inputs : outcome =
  match (native_path ~resolve inputs, consumer_abi_path ~resolve inputs) with
  | None, _ -> Unavailable "no native library inspection in this world"
  | _, None -> Unavailable "no consumer dependency record in this world"
  | Some pp, Some cp -> (
      let prov = load_abi_surface pp in
      let cons = load_abi_surface cp in
      match check_abi ~provider_soname:prov.soname ~consumer_needed:cons.needed with
      | Abi_compatible -> Holds
      | Abi_unknown ->
          Inconclusive
            "the provider records no identity, or the consumer records no \
             dependency"
      | Abi_mismatch _ ->
          (* Stem = strip at the first dot so libtiny.so.1 and
             libtiny.so.2 share the stem "libtiny". At runtime the
             loader's error names the missing NEEDED entry verbatim, so
             the same-family entries are what a log will show. *)
          let stem name =
            match String.index name '.' with
            | None -> name
            | Some i -> String.sub name ~pos:0 ~len:i
          in
          let prov_stem =
            match prov.soname with None -> "" | Some sn -> stem sn
          in
          Violated
            (List.filter cons.needed ~f:(fun n ->
                 String.equal (stem n) prov_stem)))

let declared_versions_eval ~resolve inputs : outcome =
  match declared_version_tags inputs with
  | None ->
      Unavailable
        "this project declares no symbol-version tags. For most libraries \
         that is the truth rather than an omission — a library built \
         without a version script has no version nodes to check — so \
         setting [native_api.versioned_symbols] is right only where the \
         build really uses one"
  | Some [] ->
      Inconclusive "the declared tag list is empty; nothing to compare"
  | Some declared -> (
      match versioned_exports_path ~resolve inputs with
      | None -> Unavailable "no versioned-export inspection in this world"
      | Some p ->
          let vs = load_versioned_symbols p in
          let exported =
            List.map vs.exports ~f:snd
            |> List.dedup_and_sort ~compare:String.compare
          in
          if List.is_empty exported then
            Inconclusive
              "the library carries no symbol versioning, so no declared tag \
               can be located in it"
          else (
            match
              List.filter_map declared ~f:(fun tag ->
                  if List.mem exported tag ~equal:String.equal then None
                  else Some (Printf.sprintf "version %s not exported" tag))
            with
            | [] -> Holds
            | missing -> Violated missing))

(** WHOSE TAG IS IT (2026-09-15) — the version-node twin of
    {!ambient_runtime}, and it was missing.

    A consumer records one versioned reference per (symbol, tag), and
    most of them belong to some other library: ssl's probe executable
    requires [OPENSSL_3.0.0] and twenty-two [GLIBC_*] tags. Comparing
    the whole set against ONE provider reports every glibc tag as
    missing, which is not a finding about openssl — it is the same
    attribution error [ambient_runtime] prevents on the NEEDED side,
    and without it this agreement reports [violated] on every project
    whose consumer links libc, which is all of them.

    THE RULE IS DERIVED FROM THE PROVIDER, not from a list of system
    namespaces. A tag belongs to the NAMESPACE before its first
    underscore ([OPENSSL_3.0.0] → [OPENSSL]), and a required tag is
    this provider's concern exactly when the provider exports at least
    one tag in the same namespace. libssl participates in [OPENSSL] and
    not in [GLIBC], so the glibc tags are somebody else's; glibc itself
    participates in [GLIBC], so a consumer needing a NEWER glibc than
    the provider offers is still a finding — which a hardcoded
    "GLIBC_ is ambient" list would have thrown away, and which is one
    of this agreement's own counterexamples.

    Deriving it also means no list to maintain: a distro minting
    [GLIBC_2.41] changes nothing, and a project that ships its own libc
    is handled by the same rule rather than by an exception. *)
let namespace_of_version_tag (tag : string) : string =
  match String.lsplit2 tag ~on:'_' with Some (ns, _) -> ns | None -> tag

let provider_participates ~(provider_tags : string list) (tag : string) : bool =
  let ns = namespace_of_version_tag tag in
  List.exists provider_tags ~f:(fun t ->
      String.equal (namespace_of_version_tag t) ns)

let required_versions_eval ~resolve inputs : outcome =
  match
    (versioned_exports_path ~resolve inputs, versioned_req_path ~resolve inputs)
  with
  | None, _ -> Unavailable "no provider versioned-export inspection in this world"
  | _, None -> Unavailable "no consumer versioned-requirement record in this world"
  | Some pp, Some cp -> (
      let prov = load_versioned_symbols pp in
      let cons = load_versioned_symbols cp in
      let provider_tags =
        List.map prov.exports ~f:snd
        |> List.dedup_and_sort ~compare:String.compare
      in
      let consumer_required =
        List.map cons.req_counts ~f:fst
        |> List.filter ~f:(provider_participates ~provider_tags)
      in
      match
        check_sym_version ~provider_versioned_exports:prov.exports
          ~consumer_required_versions:consumer_required
      with
      | Sym_version_compatible -> Holds
      | Sym_version_missing { missing_versions } -> Violated missing_versions
      | Sym_version_unknown ->
          Inconclusive
            "one side carries no symbol versioning; an empty requirement set \
             decides nothing")

(** The falsifier for [dependencies_provided]: a recorded name with no
    provider. The unprovided names are exactly the strings the loader
    prints when it gives up ("libtinfo.so.6: cannot open shared object
    file"), so they are the right substrings to grep a probe log for.

    NOT the ncurses case. There, the name IS present in both worlds and
    denotes a different implementation in each — same soname, same
    symbols, same version nodes, and a segfault. This one is the other
    half of that story: the name is not there at all. *)
let dependencies_provided_eval ~resolve inputs : outcome =
  match (native_path ~resolve inputs, consumer_abi_path ~resolve inputs) with
  | None, _ -> Unavailable "no native library inspection in this world"
  | _, None -> Unavailable "no consumer dependency record in this world"
  | Some pp, Some cp -> (
      let prov = load_abi_surface pp in
      let cons = load_abi_surface cp in
      if List.is_empty cons.needed then
        Inconclusive "the consumer records no dependencies"
      else
        match
          classify_needed ~provider_soname:prov.soname ~needed:cons.needed
          |> List.filter_map ~f:(function
               | Unprovided n -> Some n
               | Provided_by_world _ | Provided_by_ambient _ -> None)
        with
        | [] -> Holds
        | unprovided -> Violated unprovided)

(* ── what a CONSUMER has to offer the pair agreements ──

   All three read the consumer's recorded dependency or version
   requirements, so they apply only where the consumer keeps those in
   an artifact canary can read. That is a MECHANISM fact, not a
   language one, which the two OCaml mechanisms show: cstubs archives a
   .a that records nothing, dynlink produces nothing at all, and
   Python's cext is a .so that records both.

   The mechanisms without a module of their own answer by discipline
   until they get one — dynamic means no compiled artifact, so nothing
   to read. *)
(* ONE FIELD LOOKUP, not a match (2026-09-14). This used to special-case
   Cstubs against its own module's constant and fall back to
   [not (is_dynamic m)] for everything else — which is wrong for cext:
   it shares Cstubs' discipline and DOES record NEEDED, being a shared
   object. The catalogue states it per mechanism, so a new mechanism is
   a row rather than another arm here. *)
let consumer_records_needed (m : Canary_mechanism.mechanism) : bool =
  (Canary_mechanism.info_of_mechanism m).Canary_mechanism
    .mi_consumer_records_needed

(** A pair check needs SOMETHING on the consumer side that records
    dependencies or symbol versions. A STATIC question — it is a
    property of the mechanism, not of a scenario, which is why it takes
    no world. *)
let needs_consumer_record m _ _ =
  if consumer_records_needed m then Applicable
  else
    Inapplicable
      "this binding mechanism produces no artifact carrying a dependency or \
       symbol-version record (a static archive has neither; a dynamic \
       binding compiles nothing)"

(** WHERE A PAIR CHECK FIRES: wherever the consumer artifact exists,
    and not before.

    These three used to fire at [Build_lib] as well, through a
    [firing_with_build_lib] derivation written when each shared one id
    with its declaration counterpart: the [Build_lib] cell WAS the
    declaration comparison, and it stayed behind when the ids split
    (2026-09-12 audit). At [Build_lib] there is no consumer record to
    compare against — the binding has not been built yet — so the cell
    could only ever report [unavailable]. The declaration agreements
    keep that site, which is theirs. *)
let pair_firing = firing_default

(** THE CONSUMER'S RECORD, wherever this mechanism keeps it
    (2026-09-15). Two spellings, in preference order:

    - the LINKED EXECUTABLE the probe built. For a static-archive
      mechanism this is the only consumer that records anything — the
      [.a] carries no NEEDED and no symbol versions, they appear when
      the executable is linked — so it is named first;
    - the BINDING artifact itself, which is the right answer for a
      mechanism whose binding IS a shared object (a Python cext).

    Listing both and letting the kind guard choose is the same
    arrangement the evidence paths use everywhere else; a wrong guess
    cannot be read as the right artifact because the summary declares
    its kind. *)
let consumer_record_inputs first m l w =
  if consumer_records_needed m then
    [ first;
      Abi_surface
        [ Canary_basic.string_of_action (Canary_basic.Probe_binding l)
          ^ "/inspect_abi.json";
          binding_evidence_tag w l ^ "/inspect.json" ] ]
  else []

(** The pair shape both dependency agreements read: the library's own
    native summary, located by the world ([lib_evidence_paths]), beside
    the consumer's recorded identity. The library half used to be the
    constant build-step path, which is wrong in every world whose
    library is not Built. *)
let consumer_record_inputs_native
    ({ ac_mechanism = m; ac_lang = l; ac_world = w; _ } : action_context) =
  consumer_record_inputs (Native_lib (lib_evidence_paths w "inspect.json")) m l w

(* ── the agreements ── *)

let soname_matches_declaration : agreement =
  { ag_subject = Identity;
    ag_claim = Structural;
    ag_basis = Project_declaration;
    ag_says = "the built lib's recorded identity is the soname the project declared";
    ag_expects =
      "the project's declared soname. The linker's -Wl,-soname application \
       is the black box; the artifact's own record is the evidence";
    ag_rooted_in =
      rooted ~action:"build_lib" ~tool:"linker (-Wl,-soname)"
        ~artifact:"the library's SONAME record"
        ~note:
          "the -soname flag is the only thing that puts an identity into the \
           object. The linker is a black box here: it either recorded what \
           was asked for or it did not, and the artifact is the evidence"
        ();
    (* POST: it validates the identity build_lib's linker recorded. *)
    ag_slot = at_lib Canary_basic.Build_lib Post;
    ag_fault_tag = "abi_soname";
    ag_methods =
      [ checking_method ~name:"declared_soname_vs_library" ~kind:Compare
          ~reference:Declared_facts ~firing:firing_built_lib_only
          ~inputs:(fun { ac_declared = d; _ } ->
            (* the DECLARED identity is the reference half; without it
               there is nothing to hold the artifact against. The
               artifact half is the copy BUILD_LIB made — see
               [built_lib_evidence_paths] for why not the world's. *)
            declared_soname_input d
            @ [ Native_lib (built_lib_evidence_paths "inspect.json") ])
          ~eval:soname_declaration_eval
          ~limits:
            "matching a name does not identify a unique implementation: two \
             objects can advertise one soname and mean different things \
             (the ncurses case)."
          ~counterexamples:
            [ { fx_method = "declared_soname_vs_library";
                fx_inputs =
                  [ Declared_soname "libtiny.so.1"; Native_lib [ "lib.json" ] ];
                fx_bodies =
                  [ ("lib.json",
                     {|{"kind": "native", "path": "fx",
    "symbols": ["tiny_sum"],
    "elf": {"soname": "libtiny.so.2", "needed": []}}|}) ];
                fx_outcome = "violated";
                fx_findings = [ "soname libtiny.so.2 != declared libtiny.so.1" ] };
              { fx_method = "declared_soname_vs_library";
                fx_inputs = [ Native_lib [ "lib.json" ] ];
                fx_bodies =
                  [ ("lib.json",
                     {|{"kind": "native", "path": "fx",
    "elf": {"soname": "libtiny.so.1", "needed": []}}|}) ];
                fx_outcome = "unavailable";
                fx_findings = [] } ]
          () ] }

let soname_matches_requirement : agreement =
  { ag_subject = Identity;
    ag_claim = Structural;
    ag_basis = Toolchain_rule;
    ag_says = "the lib's soname is the one the consumer recorded it needs";
    ag_expects =
      "the consumer's own recorded dependency list. A provider advertising a \
       name the consumer never recorded will not be selected for it";
    ag_rooted_in =
      rooted ~action:"build_binding_ocaml" ~tool:"linker"
        ~artifact:
          "the consumer's NEEDED record. The link that wrote it ran in \
           whatever world built that consumer, which this graph need not \
           contain"
        ~note:
          "the linker's rule is that a recorded dependency names something \
           it resolved against. It ran in whatever world built that \
           consumer; this asks whether the name it wrote down is the one \
           THIS world's provider answers to"
        ();
    (* PRE: the consumer can only be linked or loaded if the name it
       recorded is the one this world's library answers to. *)
    ag_slot = before_binding;
    ag_fault_tag = "abi_soname";
    ag_methods =
      [ checking_method ~name:"library_identity_vs_consumer_record" ~kind:Compare
          ~reference:Peer_artifact ~applicable:needs_consumer_record
          ~firing:pair_firing
          ~inputs:
            consumer_record_inputs_native
          ~eval:soname_requirement_eval
          ~limits:
            "name equality only. It does not establish which object the \
             loader will select, nor that the selected object means the same \
             thing as the one linked against."
          ~counterexamples:
            [ { fx_method = "library_identity_vs_consumer_record";
                fx_inputs =
                  [ Native_lib [ "lib.json" ]; Abi_surface [ "consumer.json" ] ];
                fx_bodies =
                  [ ("lib.json",
                     {|{"kind": "native", "path": "fx",
    "elf": {"soname": "libtiny.so.2", "needed": []}}|});
                    ("consumer.json",
                     {|{"kind": "native", "path": "fx",
    "elf": {"soname": null, "needed": ["libtiny.so.1", "libc.so.6"]}}|}) ];
                fx_outcome = "violated";
                fx_findings = [ "libtiny.so.1" ] } ]
          () ] }

let declared_versions_exported : agreement =
  { ag_subject = Symbol_versions;
    ag_claim = Structural;
    ag_basis = Project_declaration;
    ag_says =
      "every version tag the project declares appears among the built lib's \
       versioned exports";
    ag_expects =
      "the project's declared version-script tags. The version script's \
       application is the black box; the artifact's export annotations are \
       the evidence";
    ag_rooted_in =
      rooted ~action:"build_lib" ~tool:"linker (version script)"
        ~artifact:"the library's symbol-version nodes"
        ~note:
          "a version script is what attaches version nodes to exported \
           symbols. As with the soname, the tool is a black box and the \
           annotations it wrote are the evidence"
        ();
    (* POST: it validates the version nodes build_lib attached. *)
    ag_slot = at_lib Canary_basic.Build_lib Post;
    ag_fault_tag = "sym_version";
    ag_methods =
      [ checking_method ~name:"declared_tags_vs_library_exports" ~kind:Compare
          ~reference:Declared_facts ~firing:firing_built_lib_only
          ~inputs:(fun { ac_declared = d; _ } ->
            declared_version_tags_input d
            @ [ Versioned_exports (built_lib_evidence_paths "inspect.json") ])
          ~eval:declared_versions_eval
          ~limits:
            "presence of a tag says nothing about the symbols inside it, nor \
             about compatibility beyond the declared tags."
          ~counterexamples:
            [ { fx_method = "declared_tags_vs_library_exports";
                fx_inputs =
                  [ Declared_version_tags [ "TINY_2.0" ];
                    Versioned_exports [ "lib.json" ] ];
                fx_bodies =
                  [ ("lib.json",
                     {|{"kind": "native", "path": "fx",
    "versioned_exports": {"tiny_sum": "TINY_1.0"}}|}) ];
                fx_outcome = "violated";
                fx_findings = [ "version TINY_2.0 not exported" ] };
              { fx_method = "declared_tags_vs_library_exports";
                fx_inputs = [ Versioned_exports [ "lib.json" ] ];
                fx_bodies =
                  [ ("lib.json",
                     {|{"kind": "native", "path": "fx",
    "versioned_exports": {"tiny_sum": "TINY_1.0"}}|}) ];
                fx_outcome = "unavailable";
                fx_findings = [] } ]
          () ] }

let required_versions_exported : agreement =
  { ag_subject = Symbol_versions;
    ag_claim = Structural;
    ag_basis = Toolchain_rule;
    ag_says = "the provider exports every version node the consumer requires";
    ag_expects =
      "the consumer's own recorded version requirements. A required tag the \
       provider does not export is what the loader reports as \
       \"version `X' not found\"";
    ag_rooted_in =
      rooted ~action:"build_binding_ocaml" ~tool:"linker"
        ~artifact:
          "the consumer's versioned symbol references, written by the link \
           that produced it — in whatever world that was"
        ~note:
          "the linker's rule is that a versioned reference binds to a \
           version node the provider exports. The LOADER re-checks it at \
           every load, and says so verbatim when it fails — which is why \
           this agreement can predict its diagnostic text"
        ();
    (* PRE: a versioned reference must bind before the consumer runs. *)
    ag_slot = before_binding;
    ag_fault_tag = "sym_version";
    ag_methods =
      [ checking_method ~name:"required_tags_vs_provider_exports" ~kind:Compare
          ~reference:Peer_artifact ~applicable:needs_consumer_record
          ~firing:pair_firing
          ~inputs:(fun { ac_mechanism = m; ac_lang = l; ac_world = w; _ } ->
            if consumer_records_needed m then
              [ Versioned_exports (lib_evidence_paths w "inspect.json");
                (* the same two spellings [consumer_record_inputs]
                   uses: the linked executable first, since for a
                   static archive it is the only consumer that records
                   a versioned reference at all *)
                Versioned_req
                  [ Canary_basic.string_of_action
                      (Canary_basic.Probe_binding l)
                    ^ "/inspect_abi.json";
                    binding_evidence_tag w l ^ "/inspect.json" ] ]
            else [])
          ~eval:required_versions_eval
          ~limits:
            "exact tag match, direct requirements only. It does not model \
             version ordering, and a world without symbol versioning is \
             inconclusive rather than compatible."
          ~counterexamples:
            [ (* THE GLIBC SHAPE, which is the case this agreement was
                 written for: a consumer linked where malloc carried
                 @@GLIBC_2.31, deployed where the provider exports only
                 @@GLIBC_2.17. The loader prints the missing tag
                 verbatim ("version `GLIBC_2.31' not found"), so the
                 tag is both the finding and the diagnostic. *)
              { fx_method = "required_tags_vs_provider_exports";
                fx_inputs =
                  [ Versioned_exports [ "prov.json" ];
                    Versioned_req [ "cons.json" ] ];
                fx_bodies =
                  [ ("prov.json",
                     {|{"kind": "native", "path": "fx",
    "versioned_exports": {"malloc": "GLIBC_2.17", "memcpy": "GLIBC_2.17"}}|});
                    ("cons.json",
                     {|{"kind": "native", "path": "fx",
    "versioned_req": {"GLIBC_2.31": 3, "GLIBC_2.17": 5}}|}) ];
                fx_outcome = "violated";
                fx_findings = [ "GLIBC_2.31" ] };
              (* the consumer's requirements are a subset of what the
                 provider exports — the outcome the substring API could
                 not express *)
              { fx_method = "required_tags_vs_provider_exports";
                fx_inputs =
                  [ Versioned_exports [ "prov.json" ];
                    Versioned_req [ "ok.json" ] ];
                fx_bodies =
                  [ ("prov.json",
                     {|{"kind": "native", "path": "fx",
    "versioned_exports": {"malloc": "GLIBC_2.17", "memcpy": "GLIBC_2.17"}}|});
                    ("ok.json",
                     {|{"kind": "native", "path": "fx",
    "versioned_req": {"GLIBC_2.17": 5}}|}) ];
                fx_outcome = "holds";
                fx_findings = [] };
              (* NEITHER SIDE carries symbol versioning. An empty
                 requirement set is not an inclusion that holds
                 vacuously — the distinction that makes this
                 inconclusive rather than a pass. *)
              { fx_method = "required_tags_vs_provider_exports";
                fx_inputs =
                  [ Versioned_exports [ "prov.json" ];
                    Versioned_req [ "bare.json" ] ];
                fx_bodies =
                  [ ("prov.json",
                     {|{"kind": "native", "path": "fx",
    "versioned_exports": {"malloc": "GLIBC_2.17"}}|});
                    ("bare.json", {|{"kind": "native", "path": "fx"}|}) ];
                fx_outcome = "inconclusive";
                fx_findings = [] } ]
          () ] }

let dependencies_provided : agreement =
  { ag_subject = Dependencies;
    ag_claim = Structural;
    ag_basis = Toolchain_rule;
    ag_says =
      "every library name the consumer records as NEEDED has a provider in \
       this world";
    ag_expects =
      "this world's modeled provider plus the family's fixed ambient-runtime \
       list. A recorded name answered by neither is the falsifier — which is \
       what a consumer linked where an implementation was split out, and \
       deployed where it is folded in, produces";
    ag_rooted_in =
      rooted ~action:"probe_binding_ocaml"
        ~tool:"linker, then the dynamic loader"
        ~artifact:
          "the consumer's NEEDED list. The linker wrote it and the LOADER \
           re-checks it at every load, which is why the probe is the \
           action named here rather than the link"
        ~note:
          "the linker recorded a set of dependency names, and the loader's \
           rule is that each resolves to an object. This recovers the \
           LOADER'S rule statically, for the names recorded, against the \
           providers this world models"
        ();
    (* PRE, and of the PROBE specifically: this recovers the loader's
       rule, and the loader runs when the probe runs. Naming the build
       first anyway, because a world that builds its binding resolves
       the same names at link time. *)
    ag_slot = before_binding;
    ag_fault_tag = "needed_unprovided";
    ag_methods =
      [ checking_method ~name:"recorded_dependencies_vs_world_providers"
          ~kind:Compare ~reference:Peer_artifact
          ~applicable:needs_consumer_record ~firing:pair_firing
          ~inputs:
            consumer_record_inputs_native
          ~eval:dependencies_provided_eval
          ~limits:
            "ONE modeled provider, direct dependencies only, and an ambient \
             list that is code rather than a per-world policy. It does not \
             enumerate every provider, traverse transitive dependencies, \
             verify the ambient libraries exist, or run a loader — so a name \
             supplied by a second unmodeled library is reported unprovided."
          ~counterexamples:
            [ (* the closure-shape case: the consumer was linked where the
                 implementation was split out, the provider here folds it in
                 and ships no such object. libc is ambient and must NOT be
                 reported; the split-out name must be. *)
              { fx_method = "recorded_dependencies_vs_world_providers";
                fx_inputs =
                  [ Native_lib [ "lib.json" ]; Abi_surface [ "consumer.json" ] ];
                fx_bodies =
                  [ ("lib.json",
                     {|{"kind": "native", "path": "fx",
    "elf": {"soname": "libncursesw.so.6", "needed": []}}|});
                    ("consumer.json",
                     {|{"kind": "native", "path": "fx",
    "elf": {"soname": null,
            "needed": ["libncursesw.so.6", "libtinfo.so.6", "libc.so.6"]}}|}) ];
                fx_outcome = "violated";
                fx_findings = [ "libtinfo.so.6" ] } ]
          () ] }

let checks : (agreement_id * agreement) list =
  [ (Soname_matches_declaration, soname_matches_declaration);
    (Soname_matches_requirement, soname_matches_requirement);
    (Declared_versions_exported, declared_versions_exported);
    (Required_versions_exported, required_versions_exported);
    (Dependencies_provided, dependencies_provided) ]
