(** A downstream library built on top of the [Tiny] binding. It does
    *not* talk to libtiny.so directly — it consumes the user-facing
    [Tiny] module and re-presents the results inside a small record.

    This is the second repack layer: native C ↔ [Tiny_raw] (stub) ↔
    [Tiny] (user-facing) ↔ [Tiny_helper] (downstream). Used by
    scenario e13 to confirm that the longest-interesting chain
    resolves all the way down to libtiny.so at load time. *)

type result = { value : int; doubled : int }

val sum_doubled  : int -> int -> result
val diff_doubled : int -> int -> result
