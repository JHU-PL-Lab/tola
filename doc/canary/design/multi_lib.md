# Enumerating a project's DEPENDENCIES — more than one C lib

**Kind: proposal.** **Landed when** `Canary_basic.artifact_kind.Lib` carries a name, so a project can declare more than one C lib with its own universe.

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

---

## 6. Prebuilt libs without a system PM — the `Vendored` route (2026-08-19, user)

The four `Free_with_conf` projects are blocked on AVAILABILITY, not on
opam: apt ships exactly one gmp / openssl / libffi / cairo, so their lib
axis has one point. The user's route: fetch a prebuilt from somewhere
that is NOT the system PM and declare it **`Vendored`** — the provision
already exists, and a vendored artifact is *supplied*, so it is prepared
BEFORE any enumeration or checking run (tiny's precedent: a separate
prepare command materialises vendored artifacts; the run only consumes).

**Path scheme** (user): `contrib/<project>-all/prebuilt/<tag>/…`, e.g.
`contrib/gmp-all/prebuilt/gmp-6.1.2/`. Same shape as the per-ref build
and staging dirs (`build-<ref>` / `install-<ref>`), so one convention
covers checkouts, builds, staging areas and now prebuilts. The provider is
`Canary_store_config.Vendored <path>`; the universe entry is
`(Vendored, [Stable])` — no new provider kind is needed.

### 6a. What conda-forge actually has (measured 2026-08-19 via api.anaconda.org)

> The full study — discovery API, archive formats, the measured dependency
> closures, the openssl soname finding, and the to-do list for correct use —
> is [`../surveys/conda_forge.md`](../surveys/conda_forge.md).

| lib | apt here | conda-forge linux-64 versions | a pair worth running |
| --- | --- | --- | --- |
| gmp | 6.3.0 only | 5.1.2, 6.1.0, 6.1.1, 6.1.2, 6.2.0, 6.2.1, 6.3.0 | 6.3.0 vs 6.1.2 |
| openssl | 3.0.13 only | 1.0.2h…1.0.2u, 1.1.1a…1.1.1w, 3.0.0…3.0.21, 3.1.x, 3.2.x, 3.3.x, 3.4.x, 3.5.x, 3.6.x, **4.0.1** | 3.0.13 vs **4.0.1** — a MAJOR bump, which is where OpenSSL's breaks actually live (within 3.x the ABI is stable by policy, so my earlier "ABI churn" claim was wrong for the apt-only pair) |
| cairo | 1.18.0 only | 1.12.18, 1.14.6/10/12, 1.15.12, 1.16.0, 1.18.0, 1.18.2, 1.18.4 | 1.18.0 vs 1.14.12 |
| libffi | 3.4.6 only | 3.2.1, 3.3, 3.4.2, 3.4.6, 3.5.2, **3.7.0** | 3.4.6 vs 3.7.0 |
| sqlite | (built from amalgamation) | 36 versions, 3.39.2 … 3.53.4 | not needed — sqlite.org ships every amalgamation, and the 3.43.2 pair landed without any prebuilt |

So every one of the four has a real prebuilt pair available. Two look
especially promising: **openssl 3.0 vs 4.0** (a major bump against a
binding whose gate is `Free_with_conf`, so opam will not object) and
**libffi 3.4 vs 3.7** (whose Dynamic_ffi binding fails at `dlsym` time —
a failure mode nothing else in the registry exercises).

### 6b. The blocker: `zstd` is not installed, and cannot be installed here

Modern conda packages are `.conda` = a ZIP whose members are
**zstd**-compressed tarballs. On this box:

```
unzip  ✓      curl ✓      tar 1.35 ✓ (has --zstd, which shells out)
zstd   MISSING          sudo: a password is required  → cannot apt-get it
```

So `.conda` extraction is impossible today. What IS possible:

- **the `.tar.bz2` era** (pre-2023 conda-forge builds) — plain tar, works
  now. It covers the OLDER half of each pair, which is the half we want:
  gmp 6.2.1, cairo 1.14.12, libffi 3.3/3.4.2 are all `.tar.bz2`.
- **anything with `zstd` present** — one `apt-get install zstd` (or
  `pip install zstandard`) unlocks the whole table, including
  openssl 4.0.1 and libffi 3.7.0.

Recommendation: ask for `zstd` when the openssl-4.0 pair is wanted; start
with the `.tar.bz2` half meanwhile, since it already gives gmp/cairo/libffi
their second point.

### 6c. Shape of the prepare step

A `prebuilt` prepare command (peer of `tiny prepare-all`), NOT a run
action: resolve the archive URL, download into
`contrib/<project>-all/prebuilt/<tag>/`, unpack, and verify the expected
`lib/lib*.so*` appeared. The spec then declares
`(Vendored, [Stable])` with `~provider:(Vendored "<that path>")` and the
existing machinery does the rest — `shadow_filter` already treats
Vendored as prebuilt, `scenario_dir_of` renders `lib-vendored-<chan>`,
and the matrix's setting block prints `V:s`. Using the conda CLI
(micromamba) to resolve the exact build string is the natural refinement
once it is available; the first cut can carry the URL in the declaration.
