(** Behavioural agreements — claims about what running it does

    One module per check family (design: the per-check module pattern).
    Each check states its CATEGORY (descriptive), its STANDING, and a
    falsifier-phrased sentence; the function keeps whatever signature
    suits it, and the caller supplies the inputs.

    All three are UNWIRED: their predicts return [] by construction,
    which is why the registry marks them disabled rather than pretending
    they check something. *)

module Cat = Canary_check_cat

let trace_cat = Cat.Behaviour `Trace
let repack_cat = Cat.Api `Repacked
let standing = Cat.Declared
let trace_says = "the probe's trace matches what was recorded for it"
let repack_says = "the user-facing layer is a sound repacking of the stub-facing one"

let c3_predict ~resolve:_ _ = []

let c7_predict ~resolve:_ _ = []

let c8_predict ~resolve:_ _ = []

(** c6 cmp_type (L2). Pairs a [Typed_header] input (provider's C
    signatures, n3) with a [Typed_binding_stub] input (consumer's
    stub-facing typed surface, bo1 / bpe1 — the binding's expectation
    of the C ABI). For each function present on both sides, checks
    whether the signatures agree (same return type, same arg type
    list). Mismatching names are returned as predicted substrings —
    the compiler error message for an arity / type clash mentions the
    function name verbatim (e.g.
    `error: too few arguments to function 'tiny_sum'`).

    Names present in only one side aren't c6 — they're c1
    (cmp_symbol's domain). c6 only fires when both sides claim the
    function but disagree on its signature. *)
(* ── decl-comparison predicts (2026-08-18) — the lib-only cells.
   The language TOOLS (compilers, linkers, version scripts) are black
   boxes with no bit-wise operational semantics — we inspect their
   ARTIFACTS and compare against the DECLARED facts. *)

(** c4 lib-only: the BUILT lib's own elf soname vs the declared soname
    (the linker's -Wl,-soname application is the black box; the
    artifact's elf is the evidence). *)
(** c1 lib-only: every DECLARED c_api function is exported by the
    built lib — the lib's own completeness falsifier, no binding
    involved. (The status-level watchlist verdict is this same
    comparison, currently recorded rather than predicted.) *)
