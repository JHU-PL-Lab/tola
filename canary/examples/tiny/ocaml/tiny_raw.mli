(** Stub-facing layer. One [external] per C function. Maps 1-to-1 with
    [tiny.h]. Belief about the C side is concentrated here. *)

external sum        : int -> int -> int = "caml_tiny_sum"
external diff       : int -> int -> int = "caml_tiny_diff"
external get_offset : unit -> int       = "caml_tiny_get_offset"
