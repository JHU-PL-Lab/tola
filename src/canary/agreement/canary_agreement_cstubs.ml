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

(** Is there a compiled artifact recording the C symbols the binding
    requires? Yes: [ocamlmklib] archives the stub objects into a [.a]
    whose undefined references ARE the requirement set, which is what
    c1 reads on the consumer side. A [Dynlink] binding has none — it
    resolves at runtime, and the probe's own failure is the evidence. *)
let produces_a_compiled_stub = true

(** Does that artifact record WHICH shared library it needs?

    No. A static archive carries no [DT_NEEDED] and no [SONAME]: those
    appear when the executable is linked, so there is no consumer-side
    artifact for the identity agreements (c4 soname, c5 version nodes)
    to read under this mechanism. Python's [Cext] answers yes to the
    same question — a cext is a [.so] — which is why those two fire
    there and not here.

    Inspecting the linked probe executable would change this answer,
    and the change would belong on this line. *)
let records_needed_in_a_readable_artifact = false

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
