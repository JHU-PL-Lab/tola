# Enumerating a project's DEPENDENCIES — more than one C lib

**Stage:** see [README.md](README.md) (the stage map). **Kind: proposal.** **Landed when** `Canary_artifact.artifact_info`'s `A_lib` carries a name, so a project can declare more than one C lib with its own universe.

> 2026-08-19. Opened by the question "how shall we handle and enumerate
> their dependency" for the four candidate projects. Two of them (mpfr,
> bytesrw) cannot be expressed today; this note says why, what the options
> are, and which two projects can land without waiting.

## 1. The blocker, precisely

Artifact **identity** is `Canary_artifact.artifact_info`:

```
A_source | A_headers | A_lib
| A_binding of lang * mechanism | A_binding_source of lang | A_app of app_wiring
```

`A_lib` carries **no payload**, so `Canary_artifact.a_lib` is THE lib of a
project. One C library per project, by construction.

Two things this phrasing has to keep apart, since the 2026-08-24 refactor
split them. `Canary_basic.artifact_kind` (`Source | Headers | Lib |
Binding of lang | …`) is the coarse **role**, reached by `kind_of`; its
`Lib` is *supposed* to be nameless, the way `Binding of lang` is coarser
than `A_binding (lang, mechanism)`. The blocker is on the identity type,
not the role — naming the lib means `A_lib of string` with
`kind_of (A_lib _) = Lib` unchanged.

That refactor also supplies the **precedent**. Distinguishing
`binding-ocaml-cstubs` from `binding-ocaml-ctypes` was once a `{kind; ext}`
record whose `ext` carried a mechanism, not an identity; it is now a
payload on the constructor, under the rule *a constructor gains a payload
when the thing it names stops being unique*. A second C lib is the same
sentence about `A_lib`, so option (A) below is now a smaller and
better-localized change than it was when this note was written.

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

### 3a. What already exists, and where

**A third of the representation already exists** (2026-08-25). The
question "can two libs be represented before the runner?" has a better
answer than this note assumed, and it changes (A)'s cost.

`Canary_enumerate.runtime_pairing` is already the two-lib structure, built
at **pass 2** from spec data plus enumeration coordinates, with the runner's
realization explicitly not consulted:

```
type runtime_pairing = {
  rp_consumer : artifact_info;
  rp_mode     : dep_mode;         (* Ambient | Lockstep | Independent *)
  rp_run      : placement option; (* the lib the consumer RUNS over *)
  rp_deploy   : bool;             (* run-lib <> build-lib *)
}
```

`dep_mode` is declared per-artifact (`ax_runtime`) and already names the
relation: `Lockstep` = run provider is the build provider, `Independent` =
run-lib ranges free of it, `Ambient` = outside the enumeration.

So the **run** lib resolves to a placement. The **build** lib does not — it
is compressed into `rp_deploy : bool`, a *comparison* stored as a flag,
inferred by the v1 rule "the run-lib is canary-supplied while the consumer's
build-lib came from its provider". The type's own comment says it refines
*when a consumer's build-lib becomes declarable data*. It is a `bool`
precisely because `A_lib` is unique: there is only one lib placement to
point at, so the second slot has nowhere to resolve.

That decomposes (A) into three changes, all of them **before** stage 5:

1. `A_lib of string` — pass 1. Two rows, two universes. The row list is
   already keyed by `artifact_info`, so this part is nearly free.
2. `rp_run` gains a sibling `rp_build : placement option`, and `rp_deploy`
   stops being declared — it becomes *derived*, `rp_run <> rp_build`. A
   bool that encodes a comparison is replaced by the two things compared.
3. **The action catalogue needs a role per consumed slot**, and this is the
   one part naming does not fix. `action_sig.as_consumes : artifact_kind
   list` is *role*-typed, so `Lib` there means "a lib" and `[Lib; Lib]`
   would be two indistinguishable slots — no way to say which is linked and
   which is loaded.

On (3), link-vs-load **is** already encoded, but implicitly and across two
actions: `Build_app` consumes `[Binding lang; Lib]` (link time) and
`Probe_app` consumes `[App; Lib; Binding lang]` (load time) — the
divergence `artifacts_of_action`'s docstring calls out. The same nameless
`Lib` plays both roles, which is why they can never point at different
placements: within a scenario the assignment maps that one artifact to one
placement. An action that links against one lib and loads another is the
case this cannot express, and it is a *slot-role* gap, not a naming one.

The payoff for sequencing it this way: with 1-3 done, stage 5 is left with
"which path goes to `-l` and which to `LD_LIBRARY_PATH`" — a template
question, answerable per-project, and one the enumeration can already state
the answer to.

**Can (1) be lifted without disturbing today's scenarios?** Measured
2026-08-25: **yes, and it is a one-file change.** `A_lib` is matched as a
pattern in exactly six places and *all six are in `base/canary_artifact.ml`*
— its own defining module. The other 132 mentions across the tree are
`a_lib` used as a **value**, and a value they stay if `a_lib` remains bound.
The recipe:

```
| A_lib ""  -> base                 (* in string_of_id / pretty_id *)
| A_lib n   -> base ^ "-" ^ n
let a_lib = A_lib ""
```

`string_of_id` already has this exact shape for the payload-carrying
constructors (`base ^ "-" ^ refinement`), so the unnamed lib keeps printing
`lib`, and **every existing id string stays byte-identical** — scenario
dirs, dedup keys, run-cache markers and pinned expectations all untouched.
The compatibility guarantee this note owes existing projects is therefore
available whenever we want it.

**Which is an argument for not doing it yet.** (1) alone is a payload no
project can pass: every one of them would write `""`, and a distinguished
empty default is the payload rule inverted — the same sentinel smell the
2026-08-24 refactor deleted. Nor does (2) rescue it, because (2) cannot
precede a *real* second lib: with one lib artifact the consumer's build-lib
is outside the enumeration entirely, which is precisely why `rp_deploy` is a
bool and not a placement. There is nothing for `rp_build` to point at until
a project declares two.

So the natural unit is **(1) plus its first consumer in the same landing** —
mpfr under (A) rather than (B), or a synthetic two-lib tiny case. The news
from the measurement is that the lift is *not* the expensive part, so there
is no reason to pre-pay it.

### 3b. The three options

**(A) Name the lib artifact** — `A_lib of string`, so `a_lib "mpfr"` and
`a_lib "gmp"` are distinct artifacts with their own universes, providers and
channel pairs. (The alternative the note first floated — a name in an `ext`
side-field — is no longer available and was never right: `ext` is gone, and
identity belongs on the constructor.)
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

1. ~~**Land zlib and lmdb now** on today's machinery.~~ **zlib landed**
   (`canary_project_zlib.ml`, via `Canary_opam_binding.run`) — but with a
   *different* pair than recommended here. This note expected apt vs
   source-built, since zlib's source build takes seconds; what it got is
   apt 1.3 vs conda-forge 1.3.2 `Vendored@Dev`, because §6's prebuilt route
   landed first and prebuilt-shadows-source applies. zstd rode the same
   route. **lmdb has not landed.**
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

| requirement | zlib *(landed)* | lmdb | mpfr | bytesrw |
| --- | --- | --- | --- | --- |
| lib channel pair | ~~apt vs source-built~~ → apt vs conda-forge prebuilt | apt only → binding pins carry the pair | apt only → binding pins | per backend, needs (A) |
| binding channel pair | opam camlzip pins | opam lmdb pins | opam mlgmpidl pins | opam bytesrw pins |
| regression ref (additive) | if a zlib CVE/fix commit is worth pinning | — | — | — |
| fix fork (additive) | only if we find a bug to fix | — | — | — |

---

## 6. Prebuilt libs without a system PM — the `Vendored` route

**Landed and moved.** This section carried the 2026-08-19 design and the
conda-forge measurements for supplying a lib version no system PM ships.
It is built: `Canary_prebuilt` handles BOTH archive formats (`.conda` =
a ZIP of zstd-compressed tars, and the older `.tar.bz2`), the `prebuilt`
command prepares declared libs before a run, and four projects ride it
(cairo, libffi, zlib, zstd).

Its blocker is also gone: the section said `.conda` extraction was
impossible here because the `zstd` CLI was missing and could not be
installed without sudo. `zstd` is at `/usr/bin/zstd` now and the
`.conda` path is the one the code takes first.

The measurements live where conda-forge measurements belong —
[`../../surveys/conda_forge.md`](../../surveys/conda_forge.md), which has
the per-package availability and the measured dependency closures.
