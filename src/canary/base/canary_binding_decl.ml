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

(* ── the PACKAGE-MANAGER gate (2026-08-19, user) ──
   A second, independent variant point: [coupling] above says how the two
   sides couple at LINK/RUN time; this says how the binding's PACKAGE
   declares its dependency on the native lib — the gate the package
   manager puts between them.

   Why it is spec data and not trivia: the study is the cooperation
   between opam and the outside world, so we must be able to force
   combinations opam would not pick itself. WHAT it takes to force one is
   a function of this gate, and nothing else. Measured from the real opam
   metadata 2026-08-19 (`opam show <pkg> --field=depends`):

     zarith         conf-gmp                      no constraint
     cairo2         conf-cairo                    no constraint
     ssl            conf-libssl                   no constraint
     sqlite3        conf-sqlite3 {build}          no constraint
     ctypes-foreign conf-libffi {>= "2.0.0"}      lower bound
     llvm           conf-llvm-shared {build & = "19"}   EXACT pin
     z3             (no conf for the lib)         the package builds libz3
     z3-solver/pip  —                             the wheel bundles libz3

   Recorded direction, NOT scheduled (user, 2026-08-19): the per-project
   conf-* usage could shrink to one global sys-PM package mapping, with any
   extra non-sys-PM work living inside the opam package. The gate below is
   the description of today's world, not an endorsement of it. *)

(** How the binding's PACKAGE declares its dependency on the native lib. *)
type pm_dep_gate =
  | Free_with_conf of string
      (** a conf-* package with NO version constraint (the conf only
          proves presence / compilability): [conf-gmp], [conf-cairo],
          [conf-libssl], [conf-sqlite3]. Any lib version the conf check
          accepts is already allowed — nothing to force. *)
  | Bounded_with_conf of {
      conf : string;
      lower : string option;  (** e.g. [Some "2.0.0"] *)
      upper : string option;
    }
      (** a conf-* package with a version RANGE — [ctypes-foreign]'s
          [conf-libffi {>= "2.0.0"}]. Note what is bounded: the CONF
          package's own version, which is opam packaging and need not
          track the C lib's. Combinations inside the bound are free. *)
  | Fixed_with_conf of { conf : string; version : string }
      (** a conf-* package pinned EXACTLY — [llvm]'s
          [conf-llvm-shared {build & = "19"}]. The hard case: opam will
          refuse any other lib generation, so forcing a combination needs
          a wrapper package that drops the conf dependency. *)
  | Pinned_depext of { depext : string; bound : string }
      (** the package declares its own depext with a version bound (no
          conf indirection) — Pattern B, e.g. torch's libtorch range. *)
  | Package_builds_lib
      (** the opam package builds the C lib itself (Pattern C — opam
          [z3]). There is no pairing to force: the lib IS the package's
          build output. *)
  | Bundled of string
      (** the package ships a prebuilt lib inside it (the z3-solver
          wheel, llvmlite). Same: no pairing to force. *)
[@@deriving show, eq]

(** What it takes to force a lib version this gate would not pick. The
    ONE derivation the gate exists for — a project's group tells you
    directly how hard its 2×2 is (user, 2026-08-19: "if heading on all of
    them is a bit difficult, we can pick one group"). *)
type combination_freedom =
  | Any_version
      (** trivial: the gate checks presence only, so every lib version we
          can obtain is already installable ([Free_with_conf]) *)
  | Within_bound of string
      (** free while the version satisfies the declared range — solvable
          whenever the dev version stays inside it ([Bounded_with_conf]) *)
  | Wrapper_needed of string
      (** the gate would refuse: publish a wrapper package that drops the
          named conf dependency ([Fixed_with_conf], [Pinned_depext]) *)
  | No_pairing
      (** the lib is the package's own output or is bundled — the lib
          axis does not exist on this side *)
[@@deriving show, eq]

let combination_freedom_of (g : pm_dep_gate) : combination_freedom =
  match g with
  | Free_with_conf _ -> Any_version
  | Bounded_with_conf { lower; upper; _ } ->
      Within_bound
        (match (lower, upper) with
        | Some l, Some u -> ">= " ^ l ^ " && <= " ^ u
        | Some l, None -> ">= " ^ l
        | None, Some u -> "<= " ^ u
        | None, None -> "any")
  | Fixed_with_conf { conf; _ } -> Wrapper_needed conf
  | Pinned_depext { depext; _ } -> Wrapper_needed depext
  | Package_builds_lib | Bundled _ -> No_pairing

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
  pm_gate : pm_dep_gate option;
      (** the package-manager gate between this binding and the lib
          (2026-08-19). [None] = not declared yet (tiny's in-tree
          bindings have no package manager between them at all). *)
}
[@@deriving show, eq]
