# conda-forge as a prebuilt-binary channel — feature, issue, experience

> 2026-08-19. A study, not a design: what conda-forge gives us, what it
> costs, and what we measured on this machine. Peer of
> [`opam.md`](opam.md) — that one surveys the ecosystem we CHECK, this one
> surveys a channel we CONSUME. The design that uses it is
> [`../design/multi_lib.md` §6](../design/multi_lib.md); the sourcing rule
> is [`../project/landing.md` §3](../project/landing.md).

## 1. The role it plays for canary

Every project needs a stable/latest pair per artifact. For the C lib the
stable side is the system PM. The latest side is a problem: **no Linux C
library in our set publishes an official prebuilt** (measured 2026-08-19 —
gmplib.org, openssl-library.org, cairographics.org ship source tarballs;
libffi's GitHub release ships source plus MSVC/Windows binaries only). On
Linux the distro *is* the binary channel, and it ships one version.

conda-forge is the fallback: a large, versioned, per-platform binary
channel we can fetch from without building and without a package manager
installed. We use it as an **archive host**, not as a package manager —
the artifact is declared `Vendored` (supplied), prepared before any run.

## 2. Feature — what it actually offers

**Discovery via a plain HTTP API** (no client needed):

| endpoint | yields |
| --- | --- |
| `api.anaconda.org/package/conda-forge/<name>` | the full version list + platform coverage |
| `api.anaconda.org/release/conda-forge/<name>/<version>` | the per-version files, including the **build string** |
| `conda.anaconda.org/conda-forge/linux-64/<name>-<ver>-<build>.conda` | the archive itself |

The build string (`h3435931_0`) cannot be guessed — it is a hash of the
build environment — so a declaration either carries the full URL or a
resolver step queries the release endpoint. This is the one place the
conda CLI (micromamba) would earn its keep.

**Version coverage, measured** (linux-64):

| lib | apt here | conda-forge | upstream newest |
| --- | --- | --- | --- |
| gmp | 6.3.0 | 5.1.2, 6.1.0–6.3.0 | 6.3.0 (2023-07-30) |
| openssl | 3.0.13 | 1.0.2h…u, 1.1.1a…w, 3.0.x–3.6.x, **4.0.1** | 4.0.1 (2026-06-09) |
| cairo | 1.18.0 | 1.12.18 … **1.18.4** | 1.18.4 (2025-03-08) |
| libffi | 3.4.6 | 3.2.1, 3.3, 3.4.2, 3.4.6, 3.5.2, **3.7.0** | 3.8.0 |
| sqlite | (built here) | 36 versions, 3.39.2 … 3.53.4 | — |

**Freshness**: current for openssl and cairo; **one release behind** for
libffi (3.7.0 vs upstream 3.8.0). Good enough as a fallback, not something
to assume — record what you actually vendored.

**Archive formats.** Modern packages are `.conda` = a **ZIP** whose
members are **zstd**-compressed tarballs; older ones are plain
`.tar.bz2`. The working recipe (both handled in `Canary_prebuilt`):

```sh
curl -sL <url> -o a.conda && unzip -oq a.conda && tar --zstd -xf pkg-*.tar.zst
# legacy:  curl -sL <url> -o a.tar.bz2 && tar -xf a.tar.bz2
```

`zstd` is a hard prerequisite for `.conda` (GNU tar's `--zstd` shells out
to it). It was missing on this box and `sudo` needed a password, so for a
few hours only the `.tar.bz2` era was reachable — worth knowing before
promising a version.

## 3. Issue — the dependency closure is NOT shipped

A conda package contains **one** library's files. Its dependencies are
separate packages, expressed in conda metadata that we do not resolve. So
an extracted lib must find its dependencies somewhere else — and it does,
through the ordinary ELF loader, because `DT_NEEDED` records **sonames,
not paths**.

Measured, this machine, single-package extractions:

| package | NEEDED | RPATH | `ldd` | `ldd -r` | `dlopen(RTLD_NOW)` |
| --- | --- | --- | --- | --- | --- |
| **libffi 3.7.0** | 1 (`libc`) | `$ORIGIN/.` | resolves | 0 undefined | OK |
| **cairo 1.18.4** | 13 — pthread, m, z, png16, fontconfig, freetype, X11, xcb, xcb-render, X11-xcb, xcb-shm, pixman-1, c | `$ORIGIN/.` | **all 13 → `/lib/x86_64-linux-gnu/…`**, 0 not found | **0 undefined** | **OK**, `cairo_version_string()` = `1.18.4` |
| **openssl 4.0.1** | `libcrypto.so.4`, pthread, c | `$ORIGIN/.` | libcrypto resolves **from the package's own dir** (it ships both) | 0 undefined | OK |

**So: yes, a downloaded prebuilt does implicitly link against
system-installed dependencies.** conda-forge sets `RPATH=$ORIGIN/.`, so it
prefers its own directory (empty for a single-package extraction) and then
falls through the normal search path to the system copies. cairo ran
against apt's pixman/freetype/fontconfig/X11 and bound every symbol
eagerly.

**The three conditions that make it work — and each is a way to fail:**

1. **Soname match.** `libfreetype.so.6` finds apt's `.so.6`; a `.so.7`
   would not exist and the load fails.
2. **System version ≥ what the prebuilt was built against, symbol by
   symbol.** conda-forge builds against its own (usually newer) deps, so
   an older system copy can be missing a symbol. With `RTLD_NOW` that
   fails at load; with lazy binding it fails at first call — much later,
   and blamed on the wrong thing.
3. **You get a MIX.** The loaded set is conda's library plus the system's
   dependencies. Nothing about that mixture was ever tested by anyone
   upstream. It is exactly the "which lib actually loaded" hazard in
   [`../design/contract_registry.md`](../design/contract_registry.md)
   §10b/§10c, and the reason the closure deserves a check of its own.

**Selection criterion that follows**: the NEEDED closure is measurable
before vendoring, so measure it. libffi (1 entry) is trivially safe;
openssl (self-contained, ships libssl+libcrypto together) is safe; cairo
(11 external) worked here but is the shape that will not travel.

## 4. Issue — a soname bump breaks the "just point at it" route

The sharpest finding, and it changes the plan for ssl:

```
system  libssl.so.3   (apt openssl 3.0.13)
conda   libssl.so.4   (openssl 4.0.1)
```

OpenSSL 3 → 4 is a **soname bump** — a deliberate ABI break. The opam
`ssl` binding was compiled against `libssl.so.3`, so *its* `DT_NEEDED`
names `.so.3`: pointing `LD_LIBRARY_PATH` at a directory containing
`libssl.so.4` changes nothing, the loader keeps finding the system's
`.so.3`. A pair across a soname bump therefore requires the CONSUMER to be
**rebuilt** against the new lib, not merely re-pointed.

That splits our three candidates into two kinds of work:

| pair | soname | what the consumer needs |
| --- | --- | --- |
| libffi 3.4.6 → 3.7.0 | `.so.8` both | nothing — `LD_LIBRARY_PATH` suffices (done) |
| cairo 1.18.0 → 1.18.4 | `.so.2` both | nothing — same (done) |
| **openssl 3.0.13 → 4.0.1** | `.so.3` → `.so.4` | **rebuild the binding** against openssl 4 (the no-conf wrapper + a build), which is also the strongest FORWARD test we could run |

## 5. Experience — what we did, and the two things that bit us

Landed 2026-08-19: `Canary_prebuilt` (declaration + version-stamped
prepare), `canary prebuilt`, the path scheme
`contrib/<project>-all/prebuilt/<tag>/`, and the pair on libffi and cairo
(`Vendored@Dev` beside `Fetched@Stable`). Both run 2/2.

**(a) The consumer silently tested the wrong lib.** The vendored world's
lib probe read the prebuilt correctly, but the binding probe was a plain
`ocamlfind -package <pkg>` run, which resolves the ambient copy — so the
consumer half of the vendored world was a duplicate of the fetched
world's, and both passed *because they tested the same library*. cairo is
the case that hides it best: its two versions export identical symbol
counts (420/420), so nothing in the verdict could reveal it. Found by
reading the emitted command. Now the world's libdir goes first on
`LD_LIBRARY_PATH`, and the pin asserts both probes name the prebuilt in
the Vendored world and neither does in the Fetched one.

**(b) The fix went into dead code first.** It was applied in
`runner_spec_with`, but `runner_spec_for` rebuilds `probe_binding` per
scenario and its version wins — even a cold run emitted the old command.
Two edits, one live. This is the third instance of the class in one day
(after z3's cross cells and sqlite's dead assert), which is why
[`../project/landing.md` §4](../project/landing.md) now says: make a new
check fail once on purpose.

## 6. To-do for correct use

- [ ] **A closure check as a rung-1 cell.** `readelf -d` + `ldd -r` +
  a `dlopen(RTLD_NOW)` smoke on every vendored artifact, compared against
  the declaration. It is cheap, it is static-plus-one-load, and it would
  have reported cairo's 11 external dependencies *before* a run instead of
  leaving us to wonder. This is also the concrete motivation for the
  postponed "C smoke probe" in
  [`../design/contract_registry.md` §15](../design/contract_registry.md):
  a lib can be perfectly formed and still fail to load.
- [ ] **Fetch the closure when the system cannot satisfy it.** For a
  cairo-shaped package on a machine lacking pixman/freetype, the honest
  move is to vendor the dependencies too — i.e. resolve conda's own
  dependency metadata (or shell out to micromamba) and extract the closure
  into the same `prebuilt/<tag>/` tree, where `RPATH=$ORIGIN/.` will find
  it. That turns the mixed load into a controlled one.
- [ ] **Resolve versions instead of hardcoding URLs.** The build string is
  unguessable; today it lives in the declaration. A resolver step (the
  release endpoint, or micromamba) would let a spec say "newest 3.x" and
  record what it got.
- [ ] **Record provenance.** channel + build string + checksum + fetch
  date, alongside the version. A vendored artifact with no provenance is
  the same problem as an ambient system lib.
- [ ] **Decide prepare vs action** (user's paused plan): treat the fetch
  as an ACTION (like a PM or git fetch) so it appears in the matrix with a
  verdict, rather than a separate `canary prebuilt` command. The tension:
  `Vendored` means *supplied*, so nothing in the action catalogue fetches
  it today. Either give `Fetch Lib` a Vendored firing, or keep prepare
  separate and let the matrix show a `prepared` postcondition.
- [ ] **openssl needs the rebuild path**, per §4 — schedule it with the
  no-conf wrapper work, not with the point-at-it work.
- [ ] **Eviction/size.** Prebuilts accumulate under `contrib/`; nothing
  prunes them. Ties into
  [`../design/artifact_cache.md`](../design/artifact_cache.md).
- [ ] **macOS parity.** `DYLD_LIBRARY_PATH` is stripped by SIP for
  protected binaries, and Mach-O uses `LC_ID_DYLIB`/`@rpath` instead of
  soname/RPATH. The vendored route needs its own measurement there before
  being claimed to work.
