(** Binding declaration vocabulary (M2 step 4, 2026-08-13) —
    [doc/canary/design/mechanism_payload.md].

    A project declares its binding as ONE record: mechanism label +
    payload. Everything in the record is a fact-level entity — what
    the binding IS (its wrapped C API, its files, its runtime
    coupling); binding/source/artifact are fact-level by construction,
    so no "fact" suffix. The analysis (watchlists, contract rows,
    probe choice) stays on canary's side, changeable — the split is
    the module boundary, not a name.

    The contracts are stated against the declaration, not against a
    mechanism name: c1 needs "where the consumer's symbol references
    live"; c2 needs "where the user surface lives"; c4 needs "how the
    runtime couples". Any glue that supplies this declaration is
    checkable — the mechanism name is just the label. *)

open Base

(* ── the payload ── *)

(** WHAT the binding wraps — the public C API. *)
type c_api = {
  functions : string list;
  enums     : string list;
}
[@@deriving show, eq]

(** Where the public headers live (L2 source). *)
type headers = {
  dir   : string;
  files : string list;
}
[@@deriving show, eq]

(** Scoping + ABI facts, shared by every mechanism. *)
type native = {
  prefix  : string;         (** nm scoping, e.g. "tiny_". EMPTY = no single
                               prefix — the c_api watchlist carries the FULL
                               scoping (multi-prefix APIs, e.g. GMP's
                               mpz_/mpq_/mpf_/mpn_). *)
  soname  : string;         (** L4 reference, e.g. "libtiny.so.1" *)
  headers : headers;        (** L2 source *)
}
[@@deriving show, eq]

(* ── the coupling — the ONE variant point ── *)

(** How the glue couples the two sides. The variant part of the
    declaration; a new binding mechanism adds a case here and supplies
    the same payload — the contracts apply unchanged.

    The build HOW is a SEPARATE stage (M2 step 5, 2026-08-15): the
    declaration identifies WHAT the binding is (products, surfaces,
    runtime coupling — what the project-agnostic checking reads); how
    to build it is project knowledge / a mechanism-model-derived
    recipe, living with the command derivation
    ([Canary_binding_templates.build_recipe]), not here. *)
type coupling =
  | Stub_archive of {       (** cstubs: the stub .c sources + their .a *)
      sources : string list;
      archive : string;
    }
  | Compiled_ext of {       (** cext: the .c source + the .so it builds *)
      source  : string;
      product : string;
    }
  | Dlopen of {             (** ctypes/dynlink: resolved at load *)
      name : string;
    }
[@@deriving show, eq]

(* ── the declaration ── *)

type binding_decl = {
  mechanism : Canary_mechanism.mechanism;
      (** identity label — matches the artifact's [Ext_mechanism];
          the payload rides with it, it is not part of identity *)
  c_api     : c_api;
  native    : native;
  coupling  : coupling;
  surface_path : string;
      (** the user-facing FILE — a declaration (where it lives), not
          the analysis that reads it (watchlist contents stay
          outside) *)
}
[@@deriving show, eq]
