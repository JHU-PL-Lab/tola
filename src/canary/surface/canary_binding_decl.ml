(** Binding declaration vocabulary (M2 step 4, 2026-08-13) —
    [doc/canary/design/mechanism_payload.md].

    A project declares its binding as ONE record: mechanism label +
    facts. Facts are STABLE (what the binding IS — its wrapped C API,
    its files, its build, its runtime coupling). Analysis (watchlists,
    contract rows, probe choice) stays on canary's side, changeable.

    The contracts are stated against the FACTS, not against a mechanism
    name: c1 needs "where the consumer's symbol references live"; c2
    needs "where the user surface lives"; c4 needs "how the runtime
    couples". Any glue that supplies these facts is checkable — the
    mechanism name is just the label for the facts. *)

open Base

(* ── shared fact types ── *)

(** WHAT the binding wraps — the public C API. *)
type c_api = {
  functions : string list;
  enums     : string list;
}
[@@deriving show, eq]

(** Where the public headers live (L2 source). *)
type headers_facts = {
  dir   : string;
  files : string list;
}
[@@deriving show, eq]

(** Scoping + ABI facts, shared by every mechanism. *)
type native_facts = {
  prefix  : string;         (** nm scoping, e.g. "tiny_" *)
  soname  : string;         (** L4 reference, e.g. "libtiny.so.1" *)
  headers : headers_facts;  (** L2 source *)
}
[@@deriving show, eq]

(* ── the coupling — the ONE variant point ── *)

(** How the glue couples the two sides. The variant part of the
    facts; a new binding mechanism adds a case here and supplies the
    same facts — the contracts apply unchanged. *)
type coupling =
  | Stub_archive of {       (** cstubs: compile .c → .a (+ cmxa) *)
      sources : string list;
      archive : string;
      build   : dune_build;
    }
  | Compiled_ext of {       (** cext: compile .c → .so *)
      source  : string;
      product : string;
      build   : direct_cc_build;
    }
  | Dlopen of {             (** ctypes/dynlink: resolved at load *)
      name : string;
    }
[@@deriving show, eq]

and dune_build = Dune of { targets : string list }
and direct_cc_build = Direct_cc of {
  include_dirs : string list;
  library_dirs : string list;
  libs         : string list;
}

(* ── the declaration ── *)

type binding_facts = {
  c_api        : c_api;
  native       : native_facts;
  coupling     : coupling;
  surface_path : string;
      (** the user-facing FILE — a fact (where it lives), not the
          analysis that reads it (watchlist contents stay outside) *)
}
[@@deriving show, eq]

type binding_decl = {
  mechanism : Canary_mechanism.mechanism;
      (** identity label — matches the artifact's [Ext_mechanism];
          the payload rides with it, it is not part of identity *)
  facts     : binding_facts;
}
[@@deriving show, eq]
