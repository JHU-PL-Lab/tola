#### Intrinsic vs. extrinsic versioning

A version assertion is **intrinsic** if the artifact carries it
(the version is part of the artifact's surface), or **extrinsic**
if some external authority records it (the artifact doesn't know
it; you have to ask elsewhere).

**Table — Versioning sites.** Six sites where a version can be asserted; intrinsic ones (visible on the artifact surface) are checkable by surface theory, extrinsic ones belong to packaging theory.

| Site                         | Example                                               | Asserted at  | Read by                               | Kind                                                     |
| ---------------------------- | ----------------------------------------------------- | ------------ | ------------------------------------- | -------------------------------------------------------- |
| Source-repo tag              | `git tag v4.15.0`                                     | repo time    | release engineer, package maintainer  | **extrinsic**                                            |
| Package manifest             | opam `version: "4.15.0"`, pip `Metadata-Version: 2.1` | package time | PM resolver (apt, opam, pip)          | **extrinsic**                                            |
| Filesystem name              | `libz3.so.4.15.0` + symlink chain                     | install time | OS loader (ld.so), `find_library`     | **extrinsic**                                            |
| Artifact metadata (SONAME)   | `DT_SONAME = libz3.so.4`                              | link time    | OS loader (identity check)            | **intrinsic** (c4 ABI)                                   |
| Artifact symbol annotations  | `tiny_sum@@TINY_2.0`, `malloc@@GLIBC_2.31`            | link time    | OS loader (symbol-version resolution) | **intrinsic** (c5 SymbolVersion)                         |
| Artifact contents (constant) | embedded `Z3_VERSION = "4.15.0"`                      | build time   | application code at runtime           | **intrinsic** (c2 API-completeness — name + value in s4) |

The intrinsic / extrinsic line is also the **surface theory /
packaging theory** line.

- **Intrinsic versioning is what surface theory checks.** SONAME,
  `@@VER`, and embedded version constants are part of an artifact's
  surface. Disagreements between provider and consumer at the
  intrinsic level are contract violations (c4 ABI, c5
  SymbolVersion, c2 watchlist on a version constant).
- **Extrinsic versioning is what packaging theory checks.** Filename
  resolution, package-manifest constraints, source-tag selection —
  these decide *which artifact fills s2*, not whether the artifact
  itself is well-formed.

#### Reflecting extrinsic versioning through wrong-artifact loading

Even though tiny doesn't model packaging directly (§3), it
*demonstrates the effect* of extrinsic-versioning failures by
hacking the wrong artifact into the file resolution path. The
canonical example is **e2 `abi_soname_bump`**: we rename
`libtiny.so.1` → `libtiny.so.2.0` so that ld.so can't find the
file the binding asks for. That's an *extrinsic* (filesystem) layer
problem made visible as a load failure. The same pattern would
apply to apt downgrading a package, opam pinning to an old version,
or a pip wheel shadowing a system library.

This indirection is the right level of abstraction for the
foundational paper: surface theory doesn't need to model the
package manager's resolver, only the *artifact mismatch* that
results from a wrong resolution.

#### Belief-vs-reality warnings

Programmers and users often hold beliefs about extrinsic versions
that are wrong:

- "I'm running `libz3 4.15.0`" — but `4.15.0` is the package
  manifest version. The installed `libz3.so` has its own SONAME
  (intrinsic c4) and `Z3_VERSION` constant (intrinsic in s4) that
  may disagree if the build was patched.
- "My pip install of z3-solver is up to date" — but pip's metadata
  version doesn't speak to the bundled `libz3.so`'s `@@VER`
  annotations, which the actual runtime resolution uses.
- "The opam package says it depends on z3 ≥ 4.13" — but opam's
  constraint is purely extrinsic; the binding's *baked-in NEEDED
  + `@VER` requirements* are the real runtime gate.

Each of these is a place where a future canary mode could *alert on
disagreement* between an extrinsic claim and the corresponding
intrinsic surface. Not a contract violation per se, but a
diagnostic worth emitting. Deferred to the packaging-theory layer.

#### Where each versioning site sits in the contract grid

**Table — Versioning sites × contracts.** Same six sites as above, joined with the contract that compares each.

| Site               | Contract that compares it (if any)          | Status                                         |
| ------------------ | ------------------------------------------- | ---------------------------------------------- |
| Source-repo tag    | (none directly — drives provider selection) | extrinsic; out of scope                        |
| Package manifest   | (none directly — drives provider selection) | extrinsic; out of scope                        |
| Filesystem name    | (none directly — drives loader resolution)  | extrinsic; indirectly visible via load failure |
| SONAME             | c4 ABI                                      | intrinsic; comparator gap                      |
| Symbol annotations | c5 SymbolVersion                            | intrinsic; comparator gap                      |
| Embedded constants | c2 API-completeness (when watchlisted)      | intrinsic; partly checked                      |

A project's "version" is a tuple over these sites; canary today
checks the intrinsic c4 and c5 entries via inspectors but doesn't
yet have the comparators wired (see §2.7).

### 2.8 Versioning is cross-cutting

Versioning is not a single contract — versions appear at multiple
*sites*, asserted by different agents, and consumed by different
checks. A holistic project-versioning model that ties them together
is still TODO; this subsection enumerates the sites and where each
fits in the surface model.