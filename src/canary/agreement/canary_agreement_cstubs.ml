(** cstubs — OCaml's static C-ABI binding mechanism.

    TIER 1, per MECHANISM, and not a family: it publishes no [checks],
    so the family-detection rule passes over it exactly as it does the
    per-language modules.

    WHAT IS A MECHANISM FACT rather than a language one: everything
    about the compiled consumer artifact. The axis is easy to get wrong
    — I put "does the consumer record NEEDED" on the LANGUAGE yesterday,
    and it does not belong there. OCaml has two mechanisms whose
    artifacts have nothing in common, and this one has more in common
    with Python's [Cext] than with its own language's [Dynlink]:

      Cstubs  (OCaml)   a static archive (.a)   stub: yes   NEEDED: no
      Cext    (Python)  a shared object (.so)   stub: yes   NEEDED: yes
      Ctypes / Cffi / Dynlink   nothing compiled  no          no

    Read down the columns, not across the languages. That table is what
    the four [is_dynamic] guards in the families are approximating with
    one bit; each mechanism module states its own row as it lands. *)

open Canary_agreement_common

(* THE TWO BOOLEANS THAT USED TO LIVE HERE moved into the mechanism
   CATALOGUE on 2026-09-14 ([Canary_mechanism.mi_compiles_a_stub],
   [mi_consumer_records_needed]). They were facts about a mechanism
   stated in the module of ONE mechanism, so no other mechanism had
   them and the families approximated the whole table with
   [is_dynamic] — a guess that is right for cstubs and wrong for cext,
   which shares its discipline and records NEEDED where cstubs does
   not.

   What stays here is what the catalogue cannot hold: WHERE the
   evidence sits. "Does this mechanism expose a typed boundary" is
   base vocabulary; "it is at
   scan_sources/inspect_typed_binding_stub_ocaml.json" is a path into
   a world's output tree, which only the agreement layer can name. *)

(** The STUB-FACING typed surface (Sf.3): the binding's [external]
    declarations with their C types, scanned from SOURCE rather than
    from a built artifact — a compiled archive has already thrown the
    types away.

    A mechanism fact, not OCaml's: [external] is how cstubs spells the
    boundary. A ctypes binding is OCaml too and declares its types as
    values instead, so its typed surface — when it gets one — is a
    different shape read from a different place. *)
let typed_stub_surface : inspect_input =
  Typed_binding_stub [ "scan_sources/inspect_typed_binding_stub_ocaml.json" ]
