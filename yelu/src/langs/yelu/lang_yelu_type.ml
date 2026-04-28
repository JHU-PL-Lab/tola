open Base

(* Yelu type universe — first-class type values that annotate the AST.
   Global definition for the first cut; future direction is compositional
   (each theory contributes its own type fragment, mirroring how each
   Make_xxx functor contributes its statement group). *)

type yelu_type =
  | Ty_string
  | Ty_bool
  | Ty_int
  | Ty_path
  | Ty_version
  | Ty_target
  | Ty_list of yelu_type
  | Ty_any (* untyped / unknown — compatible with any expected type *)
[@@deriving equal, sexp_of]

type type_error =
  | Type_mismatch of { expected : yelu_type; got : yelu_type; context : string }
[@@deriving sexp_of]
