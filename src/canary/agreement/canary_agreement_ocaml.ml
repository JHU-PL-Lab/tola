(** OCaml — what this language's surfaces ARE, and where they land.

    TIER 1, and deliberately not a family (2026-09-03, the first of the
    per-language modules). Four families read it — symbols, api_surface,
    identity, types — so it has to sit below all of them, and it
    publishes no [checks], which is exactly what the family-detection
    rule keys on. Nothing about the pins changes to accommodate it.

    THE SPLIT IT MAKES. A family states a CLAIM; this states the
    EVIDENCE that claim reads when the consumer is OCaml. The two vary
    independently, and conflating them is what put five [match]
    expressions on language and mechanism inside four different
    families: c2's claim — every watchlisted name is present on the
    user-facing surface — is word for word the same for OCaml and
    Python, and only the surface differs, an [.mli] here and [dir()]
    there. The claim belongs to the category; the surface belongs
    here.

    What is NOT here: anything about a binding MECHANISM. Whether a
    compiled stub archive exists to inspect is a cstubs fact, not an
    OCaml fact — a ctypes binding is OCaml too and has none. That gets
    its own module. *)

open Canary_agreement_common

(** The USER-FACING surface (Sf.4): the installed [.mli], inspected
    into [inspect_mli.json] in the binding's install step — [tag] is
    that step, which the world decides ([binding_evidence_tag]). *)
let user_surface (tag : string) : inspect_input =
  Ocaml_mli [ tag ^ "/inspect_mli.json" ]

(** The STUB-FACING typed surface (Sf.3): the binding's [external]
    declarations with their C types, scanned from SOURCE rather than
    from a built artifact — which is why the path is [scan_sources] and
    not a per-world step. A typed surface is what the source says; the
    compiled artifact has already thrown the types away. *)
let typed_stub_surface : inspect_input =
  Typed_binding_stub [ "scan_sources/inspect_typed_binding_stub_ocaml.json" ]

(** Does a compiled OCaml binding record, in an artifact canary can
    read, WHICH shared library it needs?

    No. The [.cmxa] and the stub [.a] are archives: the [DT_NEEDED] and
    [SONAME] entries appear only on the final linked executable, so
    there is no consumer-side artifact for the identity agreements (c4
    soname, c5 version nodes) to read on this language. A Python cext
    is a [.so] and does record them, which is why those two fire for
    Python today and not for OCaml.

    Stated as a fact about the language rather than as [| Python -> …]
    inside the identity family, because it is the reason for that
    branch, not the branch itself. Reading the linked probe executable
    would change this answer, and the change would belong here. *)
let records_needed_in_a_readable_artifact = false
