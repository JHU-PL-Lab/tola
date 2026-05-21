(** User-facing layer. Repacks [Tiny_raw] into the idiomatic interface
    we expose to applications. Today the repack is the identity (modulo
    a rename of [get_offset] to [offset]), but the layer is structurally
    distinct because it is where the binding author re-presents the C
    surface in idiomatic OCaml. *)

val sum    : int -> int -> int
val diff   : int -> int -> int

(** Queries the C global [tiny_offset] on each call. *)
val offset : unit -> int
