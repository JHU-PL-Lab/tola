(** Stub-facing layer — DEV variant. Adds [scale], binding the dev-only C
    entry point [tiny_scale] (present only in a -DTINY_DEV build, exported at
    version node TINY_2.0 — see c/tiny.dev.map). A consumer built from this
    variant deployed over a STABLE libtiny fails at link: the forward deploy
    mismatch (status §B), tiny's analogue of llvm_example_dev.ml. *)

external sum        : int -> int -> int = "caml_tiny_sum"
external diff       : int -> int -> int = "caml_tiny_diff"
external get_offset : unit -> int       = "caml_tiny_get_offset"
external scale      : int -> int -> int = "caml_tiny_scale"
