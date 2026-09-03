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

(* Its MECHANISMS' facts live with the mechanism: the typed stub
   surface and whether a compiled artifact records NEEDED are both
   properties of what cstubs BUILDS, and an OCaml Dynlink binding
   builds none of it. Both started here on 2026-09-03 and moved to
   [Canary_agreement_cstubs] the same day — the axis was wrong, not
   just the file. What stays is what every OCaml binding has whatever
   its mechanism: an .mli. *)
