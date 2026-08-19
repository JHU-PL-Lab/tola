# Enumerating a project's DEPENDENCIES — more than one C lib

> 2026-08-19. Opened by the question "how shall we handle and enumerate
> their dependency" for the four candidate projects. Two of them (mpfr,
> bytesrw) cannot be expressed today; this note says why, what the options
> are, and which two projects can land without waiting.

## 1. The blocker, precisely

`Canary_basic.artifact_kind` is

```
Source | Headers | Lib | Binding of lang | Binding_source of lang | App
```

`Lib` carries **no name**, so `Canary_artifact.a_lib` is THE lib of a
project. One C library per project, by construction. The `ext` field that
distinguishes `binding:ocaml:cstubs` from `binding:ocaml:ctypes` carries a
*mechanism*, not an identity.

Consequences for the candidates:

| project | dependency shape | expressible today? |
| --- | --- | --- |
| zlib / camlzip | one C lib (zlib) | **yes** |
| lmdb | one C lib (liblmdb), declared by depexts not conf-* | **yes** |
| mpfr / mlgmpidl | mpfr **requires gmp** — a C lib depending on a C lib | only by demoting gmp to an unenumerated depext |
| bytesrw | FIVE optional C libs (xxhash, zlib, zstd, libmd, libblake3) | **no** |

## 2. Two other things bytesrw needs

**(a) Optional means `Absent`.** The provision vocabulary already has
`Absent`, and the enumeration already ranges over provisions — so "the
backend is not installed" is a placement, not a new concept. No project
declares an `Absent` universe today, so this path is unused: `assignment_ok`
currently requires a binding's lib to be provided
(`equal_provision pl.provision Absent || provided a a_lib`), which is right
for a mandatory dep and wrong for an optional one. The rule has to become
per-artifact: mandatory libs must be provided, optional ones may be absent.

**(b) A combination policy.** Five independent on/off backends is 2⁵ = 32
worlds, and that is not a useful thing to run. The meaningful slice is
small: all-off (the pure-OCaml path), each backend alone (does it build and
work in isolation), and all-on (do they coexist). That is 1 + 5 + 1 = 7 —
and it is a POLICY over the free product, exactly like `thin`/`refs`, not a
new axis type.

## 3. Options for multiple libs

**(A) Name the lib artifact** — `Lib of string`, or a `Lib` id whose `ext`
carries a name, so `a_lib "mpfr"` and `a_lib "gmp"` are distinct artifacts
with their own universes, providers and channel pairs.
- Buys: mpfr's 2×2×2 (mpfr pair × gmp pair × binding pair), bytesrw's
  optional backends, and the recorded multi-provider axis, all at once.
- Costs: `a_lib` is referenced across `assignment_ok`, `source_is_read`,
  the matrix's setting block, the action catalogue's consumes/produces, the
  templates, `store_config`, and every project spec. Mechanical but wide —
  the kind of change that wants its own arc and a pin per invariant it
  touches.

**(B) One enumerated lib + declared depexts** — the project's headline lib
is the enumerated `Lib`; its own C dependencies are declared for install
but never varied.
- Buys: mpfr lands now, honestly labelled. On this platform apt ships
  exactly one GMP and the prebuilt-shadows-source rule says we would not
  build a second, so gmp's "channel pair" does not exist here anyway — (B)
  is not a compromise for mpfr today, it is the truth.
- Costs: nothing for mpfr; bytesrw stays blocked (its five deps are the
  point, not a detail).

**(C) One project per backend** — bytesrw-zlib, bytesrw-zstd, …
- Buys: bytesrw's per-backend coverage without touching the model.
- Costs: loses the combination question (do two backends coexist?), which
  is the interesting half; and it lies about the project boundary — they
  are one package.

## 4. Recommendation

1. **Land zlib and lmdb now** on today's machinery. zlib is the more
   valuable of the two: its source build takes seconds, so it gets a real
   lib channel pair (apt vs source-built) and becomes the third project
   with a 2×2 — and the first where BOTH sides of the pair are cheap.
2. **Land mpfr under (B)**, with gmp declared as a depext and a note that
   its stacked pair awaits (A). This also gives the first project whose C
   lib depends on another C lib we already cover, which is worth having as
   a data point before designing (A).
3. **Do (A) as its own arc**, then bytesrw. Not before: bytesrw would drag
   the model change, the optional-dep rule, and a combination policy into
   one landing.

## 5. What the model owes each candidate

Independent of the above, every new project needs the 2×2 minimum (user,
2026-08-19: "the minimum meaningful requirement for any project, like a
lower bound"), plus the additives it happens to have:

| requirement | zlib | lmdb | mpfr | bytesrw |
| --- | --- | --- | --- | --- |
| lib channel pair | apt vs source-built | apt only → binding pins carry the pair | apt only → binding pins | per backend, needs (A) |
| binding channel pair | opam camlzip pins | opam lmdb pins | opam mlgmpidl pins | opam bytesrw pins |
| regression ref (additive) | if a zlib CVE/fix commit is worth pinning | — | — | — |
| fix fork (additive) | only if we find a bug to fix | — | — | — |
