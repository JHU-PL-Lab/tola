(** OCaml — what this language's surfaces ARE, and where they land.

    TIER 1, and deliberately not a family (2026-09-03, the first of the
    per-language modules). Four families read it — symbols, api_surface,
    identity, types — so it has to sit below all of them, and it
    publishes no [checks], which is exactly what the family-detection
    rule keys on. Nothing about the harness checks changes to accommodate it.

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

(** The USER-FACING surface: what an OCaml consumer's installed package
    offers, inspected in the binding's install step — [tag] is that
    step, which the world decides ([binding_evidence_tag]).

    TWO SPELLINGS, because there are two inspectors and both are in use
    (2026-09-12). The framework's own binding summaries land in
    [inspect.json]: that is what [auto_binding_summaries] writes, what
    [inspect_ocaml.py] writes, and what ssl, llvm and sqlite all name by
    hand. Tiny writes [inspect_mli.json], to keep it apart from the
    compiled-stub summary it puts in [inspect.json].

    Listing both was previously unsafe — the first existing path won,
    so on tiny the stub summary could have been read as a surface. It is
    safe now because the reader selects by the [kind] the inspector
    declared, not by the name it happened to be written under. *)
let user_surface (tag : string) : inspect_input =
  Ocaml_mli [ tag ^ "/inspect.json"; tag ^ "/inspect_mli.json" ]

(* Its MECHANISMS' facts live with the mechanism: the typed stub
   surface and whether a compiled artifact records NEEDED are both
   properties of what cstubs BUILDS, and an OCaml Dynlink binding
   builds none of it. Both started here on 2026-09-03 and moved to
   [Canary_agreement_cstubs] the same day — the axis was wrong, not
   just the file. What stays is what every OCaml binding has whatever
   its mechanism: an .mli. *)
