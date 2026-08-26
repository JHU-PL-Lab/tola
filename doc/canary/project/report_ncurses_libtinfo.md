# Bug report — `libtinfo.so.6` names two incompatible ABIs

**Reported by:** canary (dependency-checking framework), 2026-08-25.
**Shareable page:** https://claude.ai/code/artifact/a6574f2c-7998-49e4-bf5f-217392da9da4
**Status:** analysis complete, not filed. **Severity:** crash on load-time
deploy; no diagnostic.
**Affected:** any binary built against Debian/Ubuntu's `ncursesw` that
later runs with a conda-forge (or similarly laid-out) ncurses ahead of it
on the library path.

---

## 1. Summary

A program built against Debian's `ncursesw` records `libncursesw.so.6`
**and** `libtinfo.so.6` as direct dependencies — that is what Debian's
own `ncursesw.pc` tells it to link. Run the same binary against a
conda-forge ncurses prefix and it segfaults inside `newterm`.

Every check that is supposed to catch this passes. The two ncurses
builds have the **same soname**, the **same 463 exported symbols** (name
diff empty in both directions) and the **same ten `NCURSESW6_*` ELF
version nodes**. Nothing is missing, nothing is renamed, no version node
is unsatisfiable.

The cause is that `libtinfo.so.6` denotes a **different ABI** on the two
systems:

| | Debian / Ubuntu | conda-forge |
| --- | --- | --- |
| `libtinfo.so.6` | the **wide** build (Debian builds widec-only and keeps the historic name) | the **narrow** build |
| `libtinfow.so.6` | **not shipped at all** | the wide build |
| `ncursesw.pc` `Libs:` | `-lncursesw -ltinfo` | `-lncursesw -ltinfow` |

So a soname — the ELF mechanism whose entire purpose is to be a promise
of ABI — is keeping two different promises.

## 2. The exact bad object

**conda-forge's `libtinfo.so.6` (the narrow terminfo build).**

It is not defective in itself. It is fatal *in this process* because it
wins ELF symbol interposition for the terminal-state globals and then
hands a narrow-layout record to wide code.

## 3. Reproducer

```sh
# a program built in the Debian world (any ncursesw consumer; ours is an
# OCaml `curses` probe that calls newterm("dumb") over /dev/null)
readelf -d ./probe | grep NEEDED
#   NEEDED  libncursesw.so.6
#   NEEDED  libtinfo.so.6        <-- from Debian's ncursesw.pc

env LD_LIBRARY_PATH=<conda-prefix>/lib ./probe
#   Segmentation fault (core dumped)
```

Backtrace:

```
#0  termattrs_sp ()      from <conda>/lib/libncursesw.so.6
#1  _nc_setupscreen_sp () from <conda>/lib/libncursesw.so.6
#2  newterm_sp ()         from <conda>/lib/libncursesw.so.6
#3  newterm ()            from <conda>/lib/libncursesw.so.6
```

`termattrs_sp` reads the terminal record. It is the first thing to touch
it after setup.

## 4. Mechanism — measured, not inferred

**Three objects get loaded** (`LD_DEBUG=libs`):

```
libncursesw.so.6   <- the consumer needs it
libtinfow.so.6     <- pulled transitively by conda's libncursesw
libtinfo.so.6      <- pulled by the CONSUMER's own NEEDED
```

**One definition wins for all of them** (`LD_DEBUG=bindings`). This is
the key step, and it is the opposite of "two independent copies of the
state":

```
binding file libncursesw.so.6 to libtinfo.so.6: symbol `cur_term'
binding file libncursesw.so.6 to libtinfo.so.6: symbol `SP'
binding file libncursesw.so.6 to libtinfo.so.6: symbol `_nc_globals'
binding file libtinfow.so.6   to libtinfo.so.6: symbol `cur_term'
binding file libtinfow.so.6   to libtinfo.so.6: symbol `SP'
binding file libtinfow.so.6   to libtinfo.so.6: symbol `_nc_globals'
```

The **narrow** `libtinfo` supplies the terminal state to everybody,
because the consumer names it directly and it therefore precedes the
transitively-loaded `libtinfow` in the link map. Both tinfo objects
define the full set — verified:

```
libtinfo.so.6.6 : SP _nc_globals _nc_prescreen cur_term ttytype
libtinfow.so.6.6: SP _nc_globals _nc_prescreen cur_term ttytype
```

(On Debian exactly one object defines `cur_term`, so the situation cannot
arise there.)

**And the layouts differ.** The narrow and wide builds disagree about the
terminal record: `TERMTYPE` vs `TERMTYPE2`. That is precisely the
five-symbol delta between conda's two tinfo objects —

```
_nc_copy_termtype2  _nc_export_termtype2  _nc_fallback2
_nc_free_termtype2  _nc_read_entry2
```

— every one of them a `TERMTYPE2` operation. So the wide `libncursesw`
reads a narrow-layout `cur_term` as if it were wide, and dies in the
first function that dereferences it.

This is consistent with upstream's own position, stated during the
openSUSE ncurses 5→6 transition: *"All programs using libncursesw have to
use libtinfow now because libtinfo is now binary incompatible with
libtinfow."*

## 5. The fix, verified

Keep everything else identical and change only **which object the name
`libtinfo.so.6` resolves to** — point it at the wide build, i.e. adopt
Debian's meaning of the name:

```sh
cp -a <conda>/lib/*.so* /tmp/layout/
rm /tmp/layout/libtinfo.so.6
ln -s libtinfow.so.6.6 /tmp/layout/libtinfo.so.6

env LD_LIBRARY_PATH=/tmp/layout ./probe
#   ncurses resolved: /tmp/layout/libncursesw.so.6.6
#   ncurses tinfo:    /tmp/layout/libtinfow.so.6.6
#   ncurses window: 4x10
#   ncurses ok
```

Same libraries, same versions, no rebuild — green. **The two ncurses
versions (apt 6.4, conda-forge 6.6) are genuinely drop-in compatible.**
The sole obstacle is the name→ABI binding.

## 6. Who can fix it, and what it costs

The crash needs **both** halves; neither party is broken alone. On a pure
Debian system there is one tinfo. On a pure conda-forge system a consumer
records `-ltinfow` and there is likewise one. It is the *interaction* that
fails, so the report is addressed to whoever can make the two conventions
interoperate at least cost.

**Debian/Ubuntu (recommended, and strictly additive).** Ship
`libtinfow.so.6` as an alias of `libtinfo.so.6` and emit `-ltinfow` in
`ncursesw.pc`. Consumers then record the *portable* name for the wide
tinfo, which resolves correctly on Debian (via the alias) and on any
standard layout (to the real wide build). Nothing existing breaks: the
old name keeps working. This is the smallest change that makes
Debian-built binaries portable, and binaries move in that direction far
more often than the reverse.

**conda-forge.** Not shipping the narrow `libtinfo` in the default
package would also close it, but that penalises legitimate narrow
consumers to protect against a foreign convention. Weaker ask. A middle
option is to keep it out of the default `lib/` search path.

**Consumers.** Nothing reasonable. The consumer did the correct thing —
it asked pkg-config and used the answer.

## 7. Prior art — this is known ground

The *symptom* is long-standing folklore in the conda/distro ecosystem,
with scattered reports going back years (octave, htop, emacs, samtools,
mutt; the openSUSE 5→6 transition thread). We are not claiming to have
discovered that ncurses/tinfo mixing hurts.

Two things here that we did not find already written down:

1. **The precise mechanism**, end to end: interposition picks the narrow
   record, the layout delta is exactly the `TERMTYPE2` family, and the
   crash site is the first read of the record. Most existing reports stop
   at "remove libtinfo from the conda install", a workaround without a
   mechanism.
2. **That it defeats every standard compatibility check.** Same soname,
   same symbol set, same version nodes — the three things a packager or a
   tool would examine to certify a drop-in replacement — all agree, and
   the deploy still crashes. That is the part worth generalising, and it
   is §8.

## 8. Why canary is reporting it — the general lesson

The reason this survives every check is that all of them ask *what the
library presents at its boundary*. None asks **what the consumer
requires, by name, against how the provider divides its implementation
into files**.

A compiled consumer records a **list of library names**. That list is a
dependency, and two providers can agree on every symbol, soname and
version node while disagreeing about the partition. Restated as a
falsifiable invariant:

> The consumer's recorded library closure must be satisfiable by this
> provider without loading two objects that define the same
> implementation.

Two forms of violation, one instance of each measured:

- **alternative spelling** — two objects, one implementation, two names.
  ncurses: `libtinfo`/`libtinfow`, plus `libform`/`libformw`,
  `libmenu`/`libmenuw`, `libpanel`/`libpanelw`.
- **containment** — one object statically absorbed another. sundials
  7.8.0: 82 pairs, e.g. `libsundials_cvode` contains all 60 of
  `libsundials_nvecserial`'s symbols, so linking both yields two copies.

The check is static and cheap — `readelf -d` on the consumer, `nm -D` on
the provider's objects. Sweep script:
[`../raw/closure_shape_sweep.sh`](../raw/closure_shape_sweep.sh). Run
across every prebuilt canary tracks, cairo / libffi / zlib / zstd score
zero on both forms; only ncurses and sundials fire.

Design note: [`../design/closure_shape.md`](../design/closure_shape.md).

## 9. Environment

| | |
| --- | --- |
| OS | Ubuntu 24.04 (noble), x86-64, WSL2 |
| Debian ncurses | `libncurses-dev` 6.4+20240113-1ubuntu2.1 |
| conda-forge ncurses | 6.6, `linux-64/ncurses-6.6-hdb14827_1.conda` |
| consumer | opam `curses` 1.0.12 (OCaml), links via `pkg-config ncursesw` |

**Unrelated second defect in the same prefix**, noted for completeness:
conda-forge's `libtinfow` has its build directory compiled in as the
terminfo search path
(`/home/conda/feedstock_root/build_artifacts/ncurses_.../share/terminfo`),
which does not survive relocation. The package ships its own
`share/terminfo` but nothing points the library at it, so a relocated
prefix needs `TERMINFO_DIRS` set explicitly or every `newterm` fails.
