# Proposal — closure shape, the agreement no c1..c8 states

**Kind: proposal.** **Landed when** a contract row exists whose
falsifier is *"the consumer's recorded library closure is satisfiable by
this provider without loading two implementations of one library"*, it
fires at `Probe_binding` over a `Vendored`/`Installed` lib, and ncurses'
vendored world is an `xfail[cN]` rather than an undeclared segfault.

> 2026-08-25, found while landing ncurses (D6, the queue's *cheapest
> remaining landing*). The lib pair passes every check canary has and the
> deploy still crashes. That gap is the note.

## 1. The measurement

apt 6.4 and conda-forge 6.6, the pair the sourcing rule
([`../project/landing.md`](../project/landing.md) §3) picks for ncurses:

| what canary can check | apt 6.4            | conda-forge 6.6    | verdict                         |
| --------------------- | ------------------ | ------------------ | ------------------------------- |
| soname                | `libncursesw.so.6` | `libncursesw.so.6` | same                            |
| exported `T` symbols  | 463                | 463                | same                            |
| symbol NAME set       | —                  | —                  | **diff empty, both directions** |
| ELF version nodes     | 10 × `NCURSESW6_*` | the same 10        | **identical sets**              |

There is no version skew, no missing symbol, no ABI tag difference, and
no symbol-version node a consumer could fail to find. c1 (`cmp_symbol`),
c4 (`cmp_abi`) and c5 (`cmp_sym_version`) all pass, correctly.

The vendored world segfaults.

```
$ env -u TERM LD_LIBRARY_PATH=<prebuilt>/lib TERMINFO_DIRS=<prebuilt>/share/terminfo ./ncurses_example
Segmentation fault (core dumped)
```

`LD_DEBUG=libs` names the cause:

```
calling init: <prebuilt>/lib/./libtinfow.so.6     ← pulled by the prebuilt's libncursesw
calling init: <prebuilt>/lib/libtinfo.so.6        ← pulled by the CONSUMER's own NEEDED
calling init: <prebuilt>/lib/libncursesw.so.6
```

Two terminfo implementations in one process — and the consequence is
sharper than "two copies of the state". ELF symbol interposition gives
the NARROW library's globals to everybody, because the consumer names it
directly and it therefore precedes the transitively-loaded wide one in
the link map (`LD_DEBUG=bindings`):

```
binding file libncursesw.so.6 to libtinfo.so.6: symbol `cur_term'
binding file libtinfow.so.6   to libtinfo.so.6: symbol `cur_term'
```

Narrow and wide disagree about the layout of that record (`TERMTYPE` vs
`TERMTYPE2` — exactly the five-symbol delta between conda's two tinfo
objects, every one a `termtype2` operation). So the wide `libncursesw`
reads a narrow-layout `cur_term` as if it were wide and dies in
`termattrs_sp`, the first function to dereference it.

**Verified by the fix**: point the name `libtinfo.so.6` at the WIDE build
and the same libraries run green. The two ncurses versions are genuinely
drop-in compatible; only the name→ABI binding is not. Full report with
reproducer, backtrace and remediation:
[`../project/report_ncurses_libtinfo.md`](../project/report_ncurses_libtinfo.md).

## 2. Why it happens, stated generally

The two packagers ship the same library in **differently shaped
closures**:

|                              | Debian/Ubuntu                          | conda-forge                                                                                 |
| ---------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------- |
| `pkg-config --libs ncursesw` | `-lncursesw -ltinfo`                   | `-lncursesw -ltinfow`                                                                       |
| tinfo objects shipped        | ONE — `libtinfo` **is** the wide build | TWO — `libtinfo` and `libtinfow`, distinct files (305016 vs 305368 bytes, distinct sonames) |

The consumer's link line is **frozen at build time in its provider's
shape**. `curses`'s `discover.ml` asks pkg-config and writes the answer
into `c_library_flags.sexp`, so a binding built in the Debian world
records `libtinfo.so.6` as a direct `NEEDED` — correct there, and in the
conda world it names conda's *narrow* tinfo, which sits beside the wide
one the provider's own `libncursesw` pulls.

Note what makes this different from a plain missing dependency: **every
name resolves**. The prebuilt is self-contained; nothing is absent. The
failure is that one library got loaded twice under two names.

So the general statement:

> A consumer records a set of library dependencies, not just a set of
> symbols. Two providers can agree on every symbol, soname and version
> node and still disagree about how the implementation is DIVIDED into
> objects — and a consumer built against one division is not deployable
> onto the other.

The existing contracts are all about what a boundary *presents* (c1
symbols, c2 binding surface, c4 ABI properties, c5 symbol versions).
None is about how the implementation is *partitioned*, which is a
property of the packaging, invisible in every artifact summary canary
takes today.

## 3. Why it is not c4

c4 (`cmp_abi`, L4) is the nearest home and the wrong one. Its inputs are
the declared runtime properties on `native_api` — `soname`, `c_runtime`,
`cxx_abi` — each a scalar the provider states about ITSELF. Closure shape
is a relation between the consumer's recorded `NEEDED` list and the
provider's file layout; neither side is a property of one artifact. It
reads two artifacts, which by
[`agreement_registry_audit.md`](agreement_registry.md)'s axis makes
it a **Meeting** contract, like c1 — but over the dependency list rather
than the symbol list.

The check itself is cheap and entirely static, which is the argument for
declaring it rather than discovering it by crash:

```
NEEDED(consumer stub) minus {the objects the provider ships}   → a plain missing dep
{objects the provider ships} that CLAIM the same implementation → the ncurses case
```

The second half needs one declared fact per lib — *these object names are
alternative spellings of one implementation* (`libtinfo` / `libtinfow`;
also `libncurses` / `libncursesw`) — because nothing in the ELF metadata
says so. That is the only new data the contract needs, and it belongs on
`native_api` beside `soname`.

## 4. The second, smaller finding — a prebuilt is not always self-sufficient

Before the segfault, the same world failed differently: `newterm` returned
NULL because conda-forge's `libtinfow` carries its build prefix compiled
in —

```
/home/conda/feedstock_root/build_artifacts/ncurses_.../share/terminfo
```

— and relocation to `contrib/ncurses-all/prebuilt/` does not rewrite it.
The prebuilt ships its own `share/terminfo`; nothing points the library at
it. `TERMINFO_DIRS=<prebuilt>/share/terminfo` fixes it.

`Canary_prebuilt` knows one thing about a prebuilt: `libdir_of`. The
vendored world's realization sets `LD_LIBRARY_PATH` from it and nothing
else. That is enough for a library whose behaviour depends only on its
own code (zlib, zstd), and not for one that reads a DATA directory it was
compiled to expect elsewhere. **A prebuilt may need env beyond the
library path**, and the declaration should carry it rather than each
project's realization inventing it — a `Canary_prebuilt.env : (string *
string) list` sized exactly to this.

This is the same lesson as
[`../project/landing.md`](../project/landing.md) §3c one level down:
pointing `LD_LIBRARY_PATH` is not enough to make a world, and now we know
it is not always enough to make the world *run*.

## 5. Why this is worth a contract and not a special case

Three reasons, in the order they matter:

1. **It is the failure mode the pair was chosen to have none of.** The
   sourcing rule picks stable = the system PM and latest = conda-forge
   precisely because they are the two channels real users have. Every
   project landed this way crosses the same packager boundary, and each
   was declared safe on the evidence that sonames and symbols matched.
   That evidence does not cover this.
2. **A crash is the worst possible detector.** It arrives at the
   consumer, two steps downstream, with a signal instead of a reason —
   the same shape as the `assert_staged = None` finding in
   [`../project/issues.md`](../project/issues.md), where an install
   reported success and the defect surfaced on the probe. The fix there
   is the fix here: check where the defect is.
3. **It is static.** `readelf -d` and `nm -D` on the shipped objects is
   all it takes, and canary already runs the inspectors that would carry
   it.

## 5a. The falsifier, RUN — and what it changed (2026-08-25)

> **Falsifier as stated**: if a sweep of the registry's existing prebuilt
> pairs turns up no second instance, closure shape is an ncurses
> peculiarity and deserves a per-project note, not a contract row.

Reproduce with
[`../raw/closure_shape_sweep.sh`](../raw/closure_shape_sweep.sh)
(`bash doc/canary/raw/closure_shape_sweep.sh`).

Run before writing any code, over every prepared prebuilt. The detector
is symbol-set overlap between each pair of shipped objects, and the first
attempt was **too coarse** — a bare "do they share a symbol" test fires
on incidental sharing and reported 82 hits for sundials and 3 for cairo,
which would have been read as confirmation. Discriminating by DIRECTION
splits it into two genuinely different things:

- **alternative spelling** — overlap covers ≥80% of *both* sides: one
  implementation shipped under two names;
- **containment** — ≥80% of the smaller only: a large object statically
  absorbed a small one.

| prebuilt           | alt-spelling | containment |
| ------------------ | ------------ | ----------- |
| cairo 1.18.4       | 0            | 0           |
| libffi 3.7.0       | 0            | 0           |
| zlib 1.3.2         | 0            | 0           |
| zstd 1.5.7         | 0            | 0           |
| **ncurses 6.6**    | **4**        | 1           |
| **sundials 7.8.0** | 0            | **82**      |

ncurses' four are the wide/narrow split, symmetric to the symbol:

```
libform.so.6.6(75)   <-> libformw.so.6.6(76)    overlap 75  = 100% / 98%
libmenu.so.6.6(65)   <-> libmenuw.so.6.6(65)    overlap 65  = 100% / 100%
libpanel.so.6.6(18)  <-> libpanelw.so.6.6(18)   overlap 18  = 100% / 100%
libtinfo.so.6.6(217) <-> libtinfow.so.6.6(222)  overlap 217 = 100% / 97%
libncurses.so.6.6(339) <-> libncursesw.so.6.6(463)  overlap 339 = 100% / 73%
```

(the last lands in the containment column only because the wide build
adds 124 wide-char entry points — it is the same phenomenon, which is why
the 80% threshold is a heuristic and the DECLARED fact in §6 step 2 is
what the contract should actually read.)

**Three things this settles.**

1. **Not falsified.** The hazard is real and not confined to one
   project — but the second instance is a *different form*. sundials has
   82 containments and zero alternative spellings: every solver library
   statically absorbs the helper objects (`libsundials_cvode` contains
   all 60 of `nvecserial`'s symbols, all 20 of `sunmatrixdense`'s, and so
   on). A consumer linking `-lsundials_cvode -lsundials_nvecserial` gets
   that implementation twice. Same class, found for free, and it lands in
   D3's lap.
2. **The four landed pairs are clean.** cairo, libffi, zlib and zstd
   score zero on both forms, so this note does NOT retroactively put
   their green cells in doubt — it says the check they passed was
   narrower than we thought, and that they would pass the wider one too.
   Worth stating plainly, because the opposite reading was available
   before the sweep was run.
3. **The coarse detector would have "confirmed" the proposal.** It fired
   on cairo, which is clean. A check that agrees with you for the wrong
   reason is the recurring bug class in
   [`../project/landing.md`](../project/landing.md) §4, and it showed up
   here inside the falsification itself.

## 6. Steps, cheapest first

1. ~~**Sweep the existing pairs.**~~ **DONE 2026-08-25 — see §5a.** Not
   falsified; two forms, one instance each; the four landed pairs clean.
2. **Declare the alternative-spelling fact** on `native_api` — the only
   new data — and give ncurses its `libtinfo`/`libtinfow` row. A declared
   fact, not the 80% heuristic: the heuristic is for FINDING candidates,
   the declaration is what a contract reads.
3. **Add the contract row** with the §3 falsifier, firing at
   `Probe_binding` over a non-`Fetched` lib provision, `source =
   Inspection`. Cover both forms — alternative spelling and containment —
   since the sweep found one instance of each.
4. **`Canary_prebuilt.env`** (§4), so the vendored realization stops
   being LD_LIBRARY_PATH-only.
5. Then ncurses' vendored world is `xfail[cN]` with a derived reason, and
   D6 lands at Level B instead of positive-only.

Tracked in [`../project/status_project.md`](../project/status_project.md)
§2; the ncurses instance is in
[`../project/issues.md`](../project/issues.md).
