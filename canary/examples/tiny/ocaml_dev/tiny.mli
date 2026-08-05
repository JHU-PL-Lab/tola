(** User-facing layer — DEV variant of [tiny.mli]: same surface plus
    [scale], which requires the dev-only native [tiny_scale]. *)

val sum    : int -> int -> int
val diff   : int -> int -> int

(** Queries the C global [tiny_offset] on each call. *)
val offset : unit -> int

(** Dev-only: [scale a k] = [a * k] via the native [tiny_scale]
    (TINY_2.0; absent from a stable libtiny). *)
val scale  : int -> int -> int
